@tool
extends Node
## Renders one screenshot offscreen and saves it.
##
## The job owns a temporary SubViewport that shares the World3D shown by the
## editor viewport, plus a Camera3D that duplicates the camera the viewport is
## looking through. Nothing is read back from the editor viewport itself, so
## the output size is independent of the viewport and of the screen.
##
## Outputs larger than one render target are rendered as N x N interleaved
## passes. Every pass renders the whole view at 1/N of the output size, with
## the projection shifted by a fraction of a pixel so that its pixel centres
## fall on a different pixel of each N x N block of the output; weaving the
## passes together gives the full-resolution image.
##
## Why not tiles: a tile needs an off-centre frustum, and Godot fits
## directional shadow cascades to a centred one, so off-axis tiles lose their
## shadows. Screen-space effects (SSAO, glow, SSR) also show seams at tile
## borders. Interleaved passes all look at the whole frame, so neither happens.
##
## Usage: add the job to the tree, [code]await job.run(request)[/code], then
## free it. Freeing the job frees the viewport and camera with it.

signal progress_changed(passes_done: int, pass_count: int)

## Render layers 1-20 belong to the project; 21-32 are reserved by the editor
## for gizmos, the grid and selection boxes.
const USER_LAYERS_MASK := 0x000FFFFF
## The Compatibility renderer does not expose GL_MAX_TEXTURE_SIZE to scripts.
const COMPATIBILITY_MAX_TEXTURE_SIZE := 8192
const MIN_RENDER_SIZE := 256


class Request extends RefCounted:
	## Editor viewport to mirror (world, anti-aliasing, debug draw mode...).
	var source_viewport: SubViewport
	## Camera that viewport is currently looking through.
	var source_camera: Camera3D
	var output_size := Vector2i(1920, 1080)
	## Absolute path, including the extension.
	var output_path := ""
	var image_format := "PNG"
	var jpg_quality := 0.92
	var transparent_background := false
	var msaa := "Viewport"
	var include_gizmos := false
	var warmup_frames := 0
	var max_render_size := 4096


class Result extends RefCounted:
	var ok := false
	var error := ""
	var path := ""
	var size := Vector2i.ZERO
	var pass_count := 0
	var duration_msec := 0


var _viewport: SubViewport
var _camera: Camera3D
var _base_transform := Transform3D.IDENTITY
var _base_projection := Camera3D.PROJECTION_PERSPECTIVE
var _base_keep_aspect := Camera3D.KEEP_HEIGHT
var _base_fov := 75.0
var _base_size := 1.0
var _base_frustum_offset := Vector2.ZERO
var _time_frozen := false
var _saved_time_scale := 1.0


## Largest render target side the GPU accepts.
static func get_gpu_max_texture_size() -> int:
	var device := RenderingServer.get_rendering_device()
	if device == null:
		return COMPATIBILITY_MAX_TEXTURE_SIZE
	var limit := int(device.limit_get(RenderingDevice.LIMIT_MAX_TEXTURE_SIZE_2D))
	for viewport_limit: RenderingDevice.Limit in [
		RenderingDevice.LIMIT_MAX_VIEWPORT_DIMENSIONS_X,
		RenderingDevice.LIMIT_MAX_VIEWPORT_DIMENSIONS_Y,
	]:
		var value := int(device.limit_get(viewport_limit))
		if value > 0:
			limit = mini(limit, value)
	return limit if limit > 0 else COMPATIBILITY_MAX_TEXTURE_SIZE


## How an output of [param size] pixels is rendered. "limit" is the largest
## render target side allowed ([param max_render_size] capped by the GPU),
## "grid" the N of the N x N passes (1 = a single ordinary render),
## "pass_size" the render target size and "pass_count" N * N.
static func compute_layout(size: Vector2i, max_render_size: int) -> Dictionary:
	var limit := maxi(mini(max_render_size, get_gpu_max_texture_size()), MIN_RENDER_SIZE)
	var grid := maxi(ceili(float(maxi(size.x, size.y)) / float(limit)), 1)
	var pass_size := Vector2i(ceili(float(size.x) / float(grid)), ceili(float(size.y) / float(grid)))
	return {"limit": limit, "grid": grid, "pass_size": pass_size, "pass_count": grid * grid}


func run(request: Request) -> Result:
	var result := Result.new()
	var start_msec := Time.get_ticks_msec()
	result.size = request.output_size
	result.path = request.output_path

	var image: Image = await _render(request, result)
	_restore_time()
	_free_viewport()
	if image != null:
		result.error = _save(image, request)
		result.ok = result.error.is_empty()
	result.duration_msec = Time.get_ticks_msec() - start_msec
	return result


func _exit_tree() -> void:
	_restore_time()
	_free_viewport()


func _render(request: Request, result: Result) -> Image:
	if not is_instance_valid(request.source_viewport) or not is_instance_valid(request.source_camera):
		result.error = "The editor 3D viewport or its camera is no longer available."
		return null
	var world := request.source_viewport.find_world_3d()
	if world == null:
		result.error = "The editor 3D viewport has no World3D to render."
		return null

	var output_size := request.output_size
	var layout := compute_layout(output_size, request.max_render_size)
	var grid: int = layout["grid"]
	var pass_size: Vector2i = layout["pass_size"]
	var pass_count: int = layout["pass_count"]
	result.pass_count = pass_count

	_create_viewport(request, world, pass_size, grid)
	_create_camera(request)
	if grid > 1:
		_frame_pass(Vector2i.ZERO, grid, pass_size, output_size)

	# A new viewport starts with empty history buffers. The warm-up frames let
	# auto exposure, SDFGI, volumetric fog and friends settle; they are needed
	# once only, because every pass looks at the same view.
	for frame in maxi(request.warmup_frames, 0):
		await _render_frame()

	if grid == 1:
		await _render_frame()
		return _read_pass(pass_size, result)

	# The passes are rendered on consecutive frames but must show the same
	# instant, or anything animated (shader TIME, particles) would be combed.
	_freeze_time()
	var woven: Image = null
	var row_width := mini(pass_size.x * grid, output_size.x)

	for sub_y in grid:
		# Columns first: the passes of this row of the grid, side by side
		# pixel by pixel. "strip" holds every grid-th row of the output.
		var strip: Image = null
		for sub_x in grid:
			_frame_pass(Vector2i(sub_x, sub_y), grid, pass_size, output_size)
			await _render_frame()
			var pass_image := _read_pass(pass_size, result)
			if pass_image == null:
				return null
			if strip == null:
				strip = Image.create_empty(pass_size.x * grid, pass_size.y, false, pass_image.get_format())
			for x in pass_size.x:
				strip.blit_rect(pass_image, Rect2i(x, 0, 1, pass_size.y), Vector2i(x * grid + sub_x, 0))
			progress_changed.emit(sub_y * grid + sub_x + 1, pass_count)

		# Then rows: each strip row goes to every grid-th row of the output.
		if woven == null:
			woven = Image.create_empty(output_size.x, output_size.y, false, strip.get_format())
			if woven == null or woven.is_empty():
				result.error = "Not enough memory for a %d x %d image." % [output_size.x, output_size.y]
				return null
		for y in pass_size.y:
			woven.blit_rect(strip, Rect2i(0, y, row_width, 1), Vector2i(0, y * grid + sub_y))

	return woven


func _render_frame() -> void:
	# Asking for one update also wakes the editor up, which otherwise only
	# redraws when something changed.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw


func _read_pass(pass_size: Vector2i, result: Result) -> Image:
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != pass_size:
		result.error = "The GPU returned no image for a %d x %d render target. Lower \"Max render size\" or the MSAA level and try again." % [pass_size.x, pass_size.y]
		return null
	return image


func _create_viewport(request: Request, world: World3D, render_size: Vector2i, grid: int) -> void:
	var source := request.source_viewport
	_viewport = SubViewport.new()
	_viewport.name = "HighResScreenshotViewport"
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.size = render_size
	_viewport.own_world_3d = false
	_viewport.world_3d = world
	_viewport.disable_3d = false
	_viewport.gui_disable_input = true
	_viewport.transparent_bg = request.transparent_background and request.image_format != "JPG"
	# EXR keeps linear half-float colour; the 8-bit formats take the regular sRGB target.
	_viewport.use_hdr_2d = request.image_format == "EXR"

	match request.msaa:
		"Disabled":
			_viewport.msaa_3d = Viewport.MSAA_DISABLED
		"2x":
			_viewport.msaa_3d = Viewport.MSAA_2X
		"4x":
			_viewport.msaa_3d = Viewport.MSAA_4X
		"8x":
			_viewport.msaa_3d = Viewport.MSAA_8X
		_:
			_viewport.msaa_3d = source.msaa_3d

	# Same look as the editor viewport, at native resolution. Temporal
	# upscalers and TAA need a frame history a one-shot render does not have.
	_viewport.screen_space_aa = source.screen_space_aa
	_viewport.use_taa = false
	_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	_viewport.scaling_3d_scale = 1.0
	_viewport.use_debanding = source.use_debanding
	_viewport.use_occlusion_culling = source.use_occlusion_culling
	_viewport.debug_draw = source.debug_draw
	_viewport.anisotropic_filtering_level = source.anisotropic_filtering_level
	# A pass has 1/grid of the output's pixels per axis: pick texture mipmaps
	# and mesh LODs for the output resolution, not for the pass.
	_viewport.texture_mipmap_bias = source.texture_mipmap_bias - log(float(grid)) / log(2.0)
	_viewport.mesh_lod_threshold = source.mesh_lod_threshold / float(grid)
	_viewport.positional_shadow_atlas_size = source.positional_shadow_atlas_size
	_viewport.positional_shadow_atlas_16_bits = source.positional_shadow_atlas_16_bits
	_viewport.positional_shadow_atlas_quad_0 = source.positional_shadow_atlas_quad_0
	_viewport.positional_shadow_atlas_quad_1 = source.positional_shadow_atlas_quad_1
	_viewport.positional_shadow_atlas_quad_2 = source.positional_shadow_atlas_quad_2
	_viewport.positional_shadow_atlas_quad_3 = source.positional_shadow_atlas_quad_3
	add_child(_viewport)


func _create_camera(request: Request) -> void:
	var source := request.source_camera
	_base_transform = source.global_transform.orthonormalized()
	_base_projection = source.projection
	_base_keep_aspect = source.keep_aspect
	_base_fov = source.fov
	_base_size = source.size
	_base_frustum_offset = source.frustum_offset

	_camera = Camera3D.new()
	_camera.name = "HighResScreenshotCamera"
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_viewport.add_child(_camera)
	_camera.global_transform = _base_transform
	_camera.keep_aspect = _base_keep_aspect
	match _base_projection:
		Camera3D.PROJECTION_ORTHOGONAL:
			_camera.set_orthogonal(_base_size, source.near, source.far)
		Camera3D.PROJECTION_FRUSTUM:
			_camera.set_frustum(_base_size, _base_frustum_offset, source.near, source.far)
		_:
			_camera.set_perspective(_base_fov, source.near, source.far)
	_camera.h_offset = source.h_offset
	_camera.v_offset = source.v_offset
	_camera.cull_mask = source.cull_mask if request.include_gizmos else source.cull_mask & USER_LAYERS_MASK
	_camera.environment = source.environment
	_camera.attributes = source.attributes
	_camera.compositor = source.compositor
	_camera.make_current()


## Sets the projection for one of the grid x grid interleaved passes.
##
## Pass pixel (px, py) must be centred on output pixel
## (px * grid + sub_pixel.x, py * grid + sub_pixel.y). Measured in output
## pixels, the pass therefore covers a rectangle of pass_size * grid starting
## at sub_pixel + 0.5 - grid / 2: the whole view, shifted by less than one
## pass pixel.
func _frame_pass(sub_pixel: Vector2i, grid: int, pass_size: Vector2i, output_size: Vector2i) -> void:
	var view := _get_view_plane(float(output_size.x) / float(output_size.y))
	var units_per_pixel := view.size / Vector2(output_size)
	var origin := Vector2(sub_pixel) + Vector2.ONE * (0.5 - grid * 0.5)
	var extent := Vector2(pass_size * grid)

	var left := view.position.x + units_per_pixel.x * origin.x
	var right := left + units_per_pixel.x * extent.x
	var top := view.end.y - units_per_pixel.y * origin.y
	var bottom := top - units_per_pixel.y * extent.y
	var center := Vector2((left + right) * 0.5, (top + bottom) * 0.5)

	# With KEEP_HEIGHT, "size" is the height of the pass; its width follows
	# from the render target aspect because output pixels are square.
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	if _base_projection == Camera3D.PROJECTION_ORTHOGONAL:
		_camera.set_orthogonal(top - bottom, _camera.near, _camera.far)
		_camera.global_transform = _base_transform.translated_local(Vector3(center.x, center.y, 0.0))
	else:
		_camera.set_frustum(top - bottom, center, _camera.near, _camera.far)


## Rectangle covered by the whole output on the camera's view plane, in camera
## space: on the near plane for perspective and frustum cameras, in world units
## for orthographic ones. Mirrors how the renderer builds its projection.
func _get_view_plane(aspect: float) -> Rect2:
	var half_extents := Vector2.ZERO
	var center := Vector2.ZERO
	if _base_projection == Camera3D.PROJECTION_PERSPECTIVE:
		var half := tan(deg_to_rad(_base_fov * 0.5)) * _camera.near
		half_extents = Vector2(half * aspect, half) if _base_keep_aspect == Camera3D.KEEP_HEIGHT \
				else Vector2(half, half / aspect)
	else:
		half_extents = Vector2(_base_size * aspect, _base_size) * 0.5 if _base_keep_aspect == Camera3D.KEEP_HEIGHT \
				else Vector2(_base_size, _base_size / aspect) * 0.5
		if _base_projection == Camera3D.PROJECTION_FRUSTUM:
			center = _base_frustum_offset
	return Rect2(center - half_extents, half_extents * 2.0)


func _freeze_time() -> void:
	if not _time_frozen:
		_time_frozen = true
		_saved_time_scale = Engine.time_scale
		Engine.time_scale = 0.0


func _restore_time() -> void:
	if _time_frozen:
		_time_frozen = false
		Engine.time_scale = _saved_time_scale


func _save(image: Image, request: Request) -> String:
	var directory := request.output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		var make_error := DirAccess.make_dir_recursive_absolute(directory)
		if make_error != OK:
			return "Cannot create the folder \"%s\" (%s)." % [directory, error_string(make_error)]

	var error := OK
	var keep_alpha := request.transparent_background
	match request.image_format:
		"EXR":
			if image.get_format() == Image.FORMAT_RGBA8 or image.get_format() == Image.FORMAT_RGB8:
				image.srgb_to_linear()
			image.convert(Image.FORMAT_RGBAH if keep_alpha else Image.FORMAT_RGBH)
			error = image.save_exr(request.output_path, false)
		"JPG":
			image.convert(Image.FORMAT_RGB8)
			error = image.save_jpg(request.output_path, clampf(request.jpg_quality, 0.01, 1.0))
		_:
			image.convert(Image.FORMAT_RGBA8 if keep_alpha else Image.FORMAT_RGB8)
			error = image.save_png(request.output_path)
	if error != OK:
		return "Cannot write \"%s\" (%s)." % [request.output_path, error_string(error)]
	return ""


func _free_viewport() -> void:
	if is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = null
	_camera = null

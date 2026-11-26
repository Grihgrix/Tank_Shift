@tool
extends EditorPlugin
## HighResScreenshot: a photo button in the 3D viewport toolbar that re-renders
## what the viewport shows into an offscreen SubViewport at any resolution.
##
## This script owns the toolbar controls and works out which editor viewport
## and camera to mirror. The rendering is in capture_job.gd, the options in
## settings.gd (stored in EditorSettings) and their UI in settings_popup.gd.

const Settings := preload("res://addons/high_res_screenshot/settings.gd")
const SettingsPopup := preload("res://addons/high_res_screenshot/settings_popup.gd")
const CaptureJob := preload("res://addons/high_res_screenshot/capture_job.gd")

const LOG_PREFIX := "[HighResScreenshot] "
## The 3D editor always has four viewports; the layout decides which are visible.
const EDITOR_VIEWPORT_COUNT := 4
const SAVE_DELAY_SEC := 1.0

var _toolbar: HBoxContainer
var _capture_button: Button
var _settings_button: Button
var _popup: SettingsPopup
var _directory_dialog: EditorFileDialog
var _save_timer: Timer
var _job: CaptureJob

## Index of the editor viewport the user last interacted with.
var _active_viewport_index := 0
## See _get_shown_camera().
var _probe_event: InputEvent
var _probe_camera: Camera3D


func _enter_tree() -> void:
	Settings.register()
	_build_toolbar()

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY_SEC
	_save_timer.timeout.connect(_save_editor_settings)
	add_child(_save_timer)
	EditorInterface.get_editor_settings().settings_changed.connect(_on_editor_settings_changed)

	# Lets _forward_3d_gui_input() see the input of every 3D viewport whatever
	# is selected. It is how the plugin learns which viewport is in use and
	# which camera it is looking through.
	set_input_event_forwarding_always_enabled()


func _exit_tree() -> void:
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.settings_changed.is_connected(_on_editor_settings_changed):
		editor_settings.settings_changed.disconnect(_on_editor_settings_changed)
	if is_instance_valid(_save_timer):
		if not _save_timer.is_stopped():
			_save_editor_settings()
		_save_timer.queue_free()
	_save_timer = null

	if is_instance_valid(_job):
		_job.queue_free()
	_job = null

	# The popup and the folder dialog are children of the toolbar.
	if is_instance_valid(_toolbar):
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
	_toolbar = null
	_capture_button = null
	_settings_button = null
	_popup = null
	_directory_dialog = null


func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if event == _probe_event:
		_probe_camera = viewport_camera
		return AFTER_GUI_INPUT_STOP

	# Hovering does not make a viewport the active one: the pointer crosses
	# other viewports on its way to the toolbar.
	var motion := event as InputEventMouseMotion
	if motion == null or motion.button_mask != 0:
		var index := _find_viewport_index(viewport_camera)
		if index >= 0:
			_active_viewport_index = index
	return AFTER_GUI_INPUT_PASS


# --- Toolbar ---------------------------------------------------------------

func _build_toolbar() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.name = "HighResScreenshot"
	# No gap between the two buttons, so they read as one split button. The
	# editor puts its own separator in front of controls added to this menu.
	_toolbar.add_theme_constant_override("separation", 0)

	_capture_button = Button.new()
	_capture_button.theme_type_variation = &"FlatButton"
	_capture_button.pressed.connect(capture)
	_capture_button.mouse_entered.connect(_update_capture_tooltip)
	_toolbar.add_child(_capture_button)

	_settings_button = Button.new()
	_settings_button.theme_type_variation = &"FlatButton"
	_settings_button.tooltip_text = "High-res screenshot settings."
	_settings_button.pressed.connect(_show_popup)
	_toolbar.add_child(_settings_button)

	_popup = SettingsPopup.new()
	_popup.viewport_size_provider = _get_active_viewport_size
	_popup.capture_requested.connect(capture)
	_popup.browse_requested.connect(_show_directory_dialog)
	_toolbar.add_child(_popup)

	_directory_dialog = EditorFileDialog.new()
	_directory_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_directory_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_directory_dialog.title = "Screenshot Folder"
	_directory_dialog.dir_selected.connect(_on_directory_selected)
	_directory_dialog.canceled.connect(_show_popup)
	_toolbar.add_child(_directory_dialog)

	_toolbar.theme_changed.connect(_update_icons)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)
	_update_icons()
	_update_capture_tooltip()


func _update_icons() -> void:
	var editor_theme := EditorInterface.get_editor_theme()
	for icon_name: StringName in [&"Camera", &"Camera3D", &"Image"]:
		if editor_theme.has_icon(icon_name, &"EditorIcons"):
			_capture_button.icon = editor_theme.get_icon(icon_name, &"EditorIcons")
			break

	# The three-dots icon is a full-size square with a lot of empty space
	# around the dots. Showing only its middle strip makes the settings button
	# narrower than the photo button it belongs to.
	var dots := editor_theme.get_icon(&"GuiTabMenuHl", &"EditorIcons")
	if dots != null and dots.get_width() > 0:
		var strip_width := ceilf(dots.get_width() * 0.375)
		var strip := AtlasTexture.new()
		strip.atlas = dots
		strip.region = Rect2(floorf((dots.get_width() - strip_width) * 0.5), 0.0, strip_width, dots.get_height())
		_settings_button.icon = strip


func _update_capture_tooltip() -> void:
	var size: Vector2i = Settings.resolve_output(_get_active_viewport_size())["size"]
	_capture_button.tooltip_text = "Take a high-resolution screenshot of the 3D viewport.\n%d x %d px, saved to %s" % [
		size.x, size.y, Settings.get_save_directory()]


func _show_popup() -> void:
	if _popup.visible:
		return
	_popup.reset_size()
	var anchor := _settings_button.get_screen_position() + Vector2(_settings_button.size.x * 0.5, _settings_button.size.y)
	var popup_size := _popup.get_contents_minimum_size()
	_popup.popup(Rect2i(Vector2i(anchor - Vector2(popup_size.x * 0.5, 0.0)), Vector2i(popup_size)))


func _show_directory_dialog() -> void:
	# A popup closes as soon as another window takes the focus; hide it up
	# front and bring it back once a folder was picked.
	_popup.hide()
	var directory := Settings.get_save_directory()
	while not directory.is_empty() and not DirAccess.dir_exists_absolute(directory):
		var parent := directory.get_base_dir()
		if parent == directory:
			break
		directory = parent
	_directory_dialog.current_dir = directory
	_directory_dialog.popup_file_dialog()


func _on_directory_selected(directory: String) -> void:
	Settings.set_value(Settings.SAVE_DIRECTORY, directory)
	_show_popup()


# --- Settings persistence --------------------------------------------------

func _on_editor_settings_changed() -> void:
	# The options can also be edited in the Editor Settings dialog.
	if is_instance_valid(_popup) and _popup.visible:
		_popup.refresh()
	# The editor only writes its settings file when it quits (or when its own
	# dialogs change something), so changes made by this plugin are saved here.
	if Settings.take_unsaved_changes():
		_save_timer.start()


func _save_editor_settings() -> void:
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.resource_path.is_empty():
		return
	var error := ResourceSaver.save(editor_settings)
	if error != OK:
		push_warning(LOG_PREFIX + "Could not save the editor settings (%s)." % error_string(error))


# --- Capture ---------------------------------------------------------------

## Renders the active 3D viewport with the current settings and saves it.
func capture() -> void:
	if is_instance_valid(_job):
		return

	var viewport := _get_active_viewport()
	if viewport == null:
		_report_failure("No editor 3D viewport is available.")
		return
	var camera := _get_shown_camera(viewport)
	if camera == null:
		_report_failure("The editor 3D viewport has no camera.")
		return

	var output := Settings.resolve_output(viewport.size)
	var request := CaptureJob.Request.new()
	request.source_viewport = viewport
	request.source_camera = camera
	request.output_size = output["size"]
	request.output_path = Settings.build_output_path(request.output_size)
	request.image_format = Settings.get_string(Settings.IMAGE_FORMAT)
	request.jpg_quality = Settings.get_float(Settings.JPG_QUALITY)
	request.transparent_background = Settings.get_bool(Settings.TRANSPARENT_BACKGROUND)
	request.msaa = Settings.get_string(Settings.MSAA)
	request.include_gizmos = Settings.get_bool(Settings.INCLUDE_GIZMOS)
	request.warmup_frames = Settings.get_int(Settings.WARMUP_FRAMES)
	request.max_render_size = Settings.get_int(Settings.MAX_RENDER_SIZE)

	var warnings := PackedStringArray()
	if bool(output["clamped"]):
		var requested: Vector2i = output["requested"]
		warnings.append("%d x %d px exceeds the maximum image size; rendering %d x %d px instead." % [
			requested.x, requested.y, request.output_size.x, request.output_size.y])
	if request.transparent_background and request.image_format == Settings.FORMAT_JPG:
		warnings.append("JPG has no alpha channel; the background is not transparent.")
	for warning: String in warnings:
		push_warning(LOG_PREFIX + warning)

	_job = CaptureJob.new()
	_job.progress_changed.connect(_on_job_progress)
	add_child(_job)
	_set_busy(true)
	var result: CaptureJob.Result = await _job.run(request)
	_set_busy(false)
	if is_instance_valid(_job):
		_job.queue_free()
	_job = null

	if not result.ok:
		_report_failure(result.error)
		return

	var summary := "%d x %d px" % [result.size.x, result.size.y]
	if result.pass_count > 1:
		summary += ", %d passes" % result.pass_count
	print(LOG_PREFIX + "Saved %s (%s, %s s)." % [result.path, summary, String.num(result.duration_msec / 1000.0, 1)])
	var toast := "Screenshot saved: %s (%s)" % [result.path.get_file(), summary]
	if warnings.is_empty():
		EditorInterface.get_editor_toaster().push_toast(toast, EditorToaster.SEVERITY_INFO, result.path)
	else:
		EditorInterface.get_editor_toaster().push_toast(toast, EditorToaster.SEVERITY_WARNING, "%s\n%s" % [result.path, "\n".join(warnings)])
	if Settings.get_bool(Settings.OPEN_FOLDER_AFTER_CAPTURE):
		OS.shell_show_in_file_manager(result.path)


func _set_busy(busy: bool) -> void:
	if is_instance_valid(_capture_button):
		_capture_button.disabled = busy
	if is_instance_valid(_popup):
		_popup.set_busy(busy)


func _on_job_progress(passes_done: int, pass_count: int) -> void:
	if is_instance_valid(_capture_button):
		_capture_button.tooltip_text = "Rendering pass %d of %d..." % [mini(passes_done + 1, pass_count), pass_count]


func _report_failure(message: String) -> void:
	push_error(LOG_PREFIX + "Screenshot failed: " + message)
	EditorInterface.get_editor_toaster().push_toast("Screenshot failed: " + message, EditorToaster.SEVERITY_ERROR)


# --- Editor viewport lookup ------------------------------------------------

func _get_active_viewport() -> SubViewport:
	var fallback: SubViewport = null
	for index in EDITOR_VIEWPORT_COUNT:
		var viewport := EditorInterface.get_editor_viewport_3d(index)
		if viewport == null or not _is_viewport_visible(viewport):
			continue
		if index == _active_viewport_index:
			return viewport
		if fallback == null:
			fallback = viewport
	return fallback if fallback != null else EditorInterface.get_editor_viewport_3d(0)


func _get_active_viewport_size() -> Vector2i:
	var viewport := _get_active_viewport()
	return viewport.size if viewport != null else Vector2i.ZERO


func _is_viewport_visible(viewport: SubViewport) -> bool:
	var container := viewport.get_parent() as Control
	return container != null and container.is_visible_in_tree()


## Which editor viewport an input event forwarded with [param camera] came from.
func _find_viewport_index(camera: Camera3D) -> int:
	var camera_viewport := camera.get_viewport() if is_instance_valid(camera) else null
	var hovered := -1
	for index in EDITOR_VIEWPORT_COUNT:
		var viewport := EditorInterface.get_editor_viewport_3d(index)
		if viewport == null:
			continue
		if viewport == camera_viewport:
			return index
		# A previewed scene camera lives in the scene, not in the editor
		# viewport showing it: fall back to the viewport under the pointer.
		var container := viewport.get_parent() as Control
		if hovered < 0 and container != null and container.is_visible_in_tree() \
				and container.get_global_rect().has_point(container.get_global_mouse_position()):
			hovered = index
	return hovered


## The camera [param viewport] is rendering with: its own editor camera, or the
## scene camera shown by "Preview" / "Cinematic Preview".
##
## The editor does not expose which one is in use, but it hands exactly that
## camera to _forward_3d_gui_input() with every input event. So a private dummy
## event is emitted on the viewport's input surface and swallowed again in
## _forward_3d_gui_input(), which records the camera that came with it.
func _get_shown_camera(viewport: SubViewport) -> Camera3D:
	var surface := _find_input_surface(viewport)
	if surface != null:
		var probe := InputEventAction.new()
		probe.action = &"high_res_screenshot_probe"
		_probe_event = probe
		_probe_camera = null
		surface.gui_input.emit(probe)
		_probe_event = null
		var shown := _probe_camera
		_probe_camera = null
		if is_instance_valid(shown) and shown.is_inside_tree():
			return shown
	return viewport.get_camera_3d()


## The control of a 3D editor viewport that receives its input: a sibling of
## the SubViewportContainer whose gui_input is handled by their common parent.
func _find_input_surface(viewport: SubViewport) -> Control:
	var container := viewport.get_parent()
	var editor_viewport := container.get_parent() if container != null else null
	if editor_viewport == null:
		return null
	for child: Node in editor_viewport.get_children():
		var control := child as Control
		if control == null or control == container:
			continue
		for connection: Dictionary in control.gui_input.get_connections():
			var callable: Callable = connection["callable"]
			if callable.get_object() == editor_viewport:
				return control
	return null

@tool
extends RefCounted
## Every HighResScreenshot option, in one place.
##
## Values live in EditorSettings (the per-user editor_settings-4.x.tres in the
## Godot editor data folder), never in ProjectSettings, so they follow the user
## across projects and never end up in version control.
##
## How the output resolution is defined:
##   scale      = DPI / 96                (96 DPI is the reference, i.e. 1x)
##   short edge = base_size * scale       (base_size defaults to 1080 px)
##   long edge  = short edge * aspect ratio
## Example: 16:9, base 1080, 192 DPI -> scale 2 -> 3840 x 2160 px.
## The size of the editor viewport only matters for the "Viewport" aspect
## ratio, where it supplies the ratio (never the pixel count).

const PREFIX := "plugins/high_res_screenshot/"

const ASPECT_RATIO := "aspect_ratio"
const CUSTOM_ASPECT_WIDTH := "custom_aspect_width"
const CUSTOM_ASPECT_HEIGHT := "custom_aspect_height"
const DPI_PRESET := "dpi_preset"
const CUSTOM_DPI := "custom_dpi"
const BASE_SIZE := "base_size"
const SAVE_DIRECTORY := "save_directory"
const FILE_NAME_PATTERN := "file_name_pattern"
const IMAGE_FORMAT := "image_format"
const JPG_QUALITY := "jpg_quality"
const TRANSPARENT_BACKGROUND := "transparent_background"
const MSAA := "msaa"
const INCLUDE_GIZMOS := "include_gizmos"
const OPEN_FOLDER_AFTER_CAPTURE := "open_folder_after_capture"
const WARMUP_FRAMES := "warmup_frames"
const MAX_RENDER_SIZE := "max_render_size"

const ASPECT_VIEWPORT := "Viewport"
const ASPECT_CUSTOM := "Custom"
const ASPECT_OPTIONS: PackedStringArray = [
	"Viewport", "16:9", "16:10", "4:3", "3:2", "1:1", "21:9", "9:16", "Custom",
]

## DPI that corresponds to a scale of 1.0.
const REFERENCE_DPI := 96.0
const DPI_CUSTOM := "Custom"
const DPI_OPTIONS: PackedStringArray = ["72", "96", "144", "192", "300", "384", "600", "Custom"]

const FORMAT_PNG := "PNG"
const FORMAT_JPG := "JPG"
const FORMAT_EXR := "EXR"
const FORMAT_OPTIONS: PackedStringArray = ["PNG", "JPG", "EXR"]

const MSAA_VIEWPORT := "Viewport"
const MSAA_OPTIONS: PackedStringArray = ["Viewport", "Disabled", "2x", "4x", "8x"]

const RENDER_SIZE_OPTIONS: PackedInt32Array = [2048, 4096, 8192, 16384]

## Hard limits of Godot's Image class (16384 x 16384 pixels in total) and of
## the file formats (JPG stops at 65535 px per side).
const MAX_OUTPUT_PIXELS := 16384 * 16384
const MAX_OUTPUT_SIDE := 32768
const MIN_OUTPUT_SIDE := 16

const FILE_NAME_TOKENS_HELP := "{project}  project name\n{scene}  edited scene name\n{datetime}  2026-01-31_14-05-09\n{date}  2026-01-31\n{time}  14-05-09\n{timestamp}  Unix time\n{width} {height}  output size in pixels\n{dpi}  DPI setting"

static var _definitions: Array[Dictionary] = []
static var _defaults: Dictionary = {}
static var _has_unsaved_changes := false


## Registers every setting with its default value and property hint. Safe to
## call on every plugin load: existing values are kept, and values equal to the
## default are not written to the settings file by the editor.
static func register() -> void:
	var editor_settings := EditorInterface.get_editor_settings()
	for definition: Dictionary in get_definitions():
		var setting_name: String = PREFIX + String(definition["key"])
		var default_value: Variant = definition["default"]
		if not editor_settings.has_setting(setting_name) \
				or not _is_type_compatible(editor_settings.get_setting(setting_name), default_value):
			editor_settings.set_setting(setting_name, default_value)
		editor_settings.set_initial_value(setting_name, default_value, false)
		editor_settings.add_property_info({
			"name": setting_name,
			"type": typeof(default_value),
			"hint": definition["hint"],
			"hint_string": definition["hint_string"],
		})


static func get_definitions() -> Array[Dictionary]:
	if _definitions.is_empty():
		_definitions = [
			_define(ASPECT_RATIO, ASPECT_VIEWPORT, PROPERTY_HINT_ENUM, ",".join(ASPECT_OPTIONS)),
			_define(CUSTOM_ASPECT_WIDTH, 16.0, PROPERTY_HINT_RANGE, "0.01,1000,0.01,or_greater"),
			_define(CUSTOM_ASPECT_HEIGHT, 9.0, PROPERTY_HINT_RANGE, "0.01,1000,0.01,or_greater"),
			_define(DPI_PRESET, "192", PROPERTY_HINT_ENUM, ",".join(DPI_OPTIONS)),
			_define(CUSTOM_DPI, 240.0, PROPERTY_HINT_RANGE, "12,4800,0.1"),
			_define(BASE_SIZE, 1080, PROPERTY_HINT_RANGE, "64,8640,1"),
			_define(SAVE_DIRECTORY, _get_default_save_directory(), PROPERTY_HINT_GLOBAL_DIR, ""),
			_define(FILE_NAME_PATTERN, "{scene}_{datetime}", PROPERTY_HINT_NONE, ""),
			_define(IMAGE_FORMAT, FORMAT_PNG, PROPERTY_HINT_ENUM, ",".join(FORMAT_OPTIONS)),
			_define(JPG_QUALITY, 0.92, PROPERTY_HINT_RANGE, "0.01,1,0.01"),
			_define(TRANSPARENT_BACKGROUND, false, PROPERTY_HINT_NONE, ""),
			_define(MSAA, MSAA_VIEWPORT, PROPERTY_HINT_ENUM, ",".join(MSAA_OPTIONS)),
			_define(INCLUDE_GIZMOS, false, PROPERTY_HINT_NONE, ""),
			_define(OPEN_FOLDER_AFTER_CAPTURE, false, PROPERTY_HINT_NONE, ""),
			_define(WARMUP_FRAMES, 2, PROPERTY_HINT_RANGE, "0,64,1"),
			_define(MAX_RENDER_SIZE, 4096, PROPERTY_HINT_ENUM, "2048:2048,4096:4096,8192:8192,16384:16384"),
		]
		for definition: Dictionary in _definitions:
			_defaults[definition["key"]] = definition["default"]
	return _definitions


static func get_default(key: String) -> Variant:
	get_definitions()
	return _defaults.get(key)


static func get_value(key: String) -> Variant:
	var default_value: Variant = get_default(key)
	var editor_settings := EditorInterface.get_editor_settings()
	var setting_name := PREFIX + key
	if editor_settings.has_setting(setting_name):
		var value: Variant = editor_settings.get_setting(setting_name)
		if _is_type_compatible(value, default_value):
			return value
	return default_value


static func set_value(key: String, value: Variant) -> void:
	var current: Variant = get_value(key)
	if typeof(current) != typeof(value) or current != value:
		_has_unsaved_changes = true
	EditorInterface.get_editor_settings().set_setting(PREFIX + key, value)


## True once after set_value() changed something, so the caller can schedule a
## save of the editor settings file.
static func take_unsaved_changes() -> bool:
	var had_changes := _has_unsaved_changes
	_has_unsaved_changes = false
	return had_changes


static func reset_all() -> void:
	for definition: Dictionary in get_definitions():
		set_value(String(definition["key"]), definition["default"])


static func get_string(key: String) -> String:
	return String(get_value(key))


static func get_int(key: String) -> int:
	return int(get_value(key))


static func get_float(key: String) -> float:
	return float(get_value(key))


static func get_bool(key: String) -> bool:
	return bool(get_value(key))


## Width / height of the output. [param viewport_size] is only used by the
## "Viewport" option.
static func get_aspect(viewport_size: Vector2i) -> float:
	var option := get_string(ASPECT_RATIO)
	var aspect := 16.0 / 9.0
	if option == ASPECT_VIEWPORT:
		if viewport_size.x > 0 and viewport_size.y > 0:
			aspect = float(viewport_size.x) / float(viewport_size.y)
	elif option == ASPECT_CUSTOM:
		aspect = maxf(get_float(CUSTOM_ASPECT_WIDTH), 0.01) / maxf(get_float(CUSTOM_ASPECT_HEIGHT), 0.01)
	else:
		var parts := option.split(":")
		if parts.size() == 2 and parts[1].to_float() > 0.0 and parts[0].to_float() > 0.0:
			aspect = parts[0].to_float() / parts[1].to_float()
	return clampf(aspect, 0.01, 100.0)


static func get_dpi() -> float:
	var preset := get_string(DPI_PRESET)
	var dpi := get_float(CUSTOM_DPI) if preset == DPI_CUSTOM else preset.to_float()
	return dpi if dpi > 0.0 else REFERENCE_DPI


## The multiplier applied to the base size: DPI / 96.
static func get_scale() -> float:
	return get_dpi() / REFERENCE_DPI


## Resolves the output size in pixels for the current settings. Returns:
## "requested": what the settings ask for, "size": what will be rendered after
## applying the image limits, "clamped": whether the two differ.
static func resolve_output(viewport_size: Vector2i) -> Dictionary:
	var aspect := get_aspect(viewport_size)
	var short_edge := maxf(float(get_int(BASE_SIZE)) * get_scale(), 1.0)
	var requested := Vector2(short_edge * aspect, short_edge) if aspect >= 1.0 \
			else Vector2(short_edge, short_edge / aspect)

	var limit := minf(1.0, float(MAX_OUTPUT_SIDE) / maxf(requested.x, requested.y))
	limit = minf(limit, sqrt(float(MAX_OUTPUT_PIXELS) / (requested.x * requested.y)))
	var size := Vector2i((requested * limit).round()) if limit >= 1.0 else Vector2i((requested * limit).floor())
	size = size.maxi(MIN_OUTPUT_SIDE)

	var requested_size := Vector2i(requested.round()).maxi(1)
	return {
		"requested": requested_size,
		"size": size,
		"clamped": size != requested_size,
		"aspect": aspect,
		"dpi": get_dpi(),
		"scale": get_scale(),
	}


## Absolute OS path of the save directory (res:// and user:// are accepted).
static func get_save_directory() -> String:
	var directory := get_string(SAVE_DIRECTORY).strip_edges()
	if directory.is_empty():
		directory = _get_default_save_directory()
	if directory.begins_with("res://") or directory.begins_with("user://"):
		directory = ProjectSettings.globalize_path(directory)
	return directory.simplify_path()


static func get_file_extension() -> String:
	match get_string(IMAGE_FORMAT):
		FORMAT_JPG:
			return "jpg"
		FORMAT_EXR:
			return "exr"
	return "png"


## Expands the file name pattern (without directory or extension).
static func format_file_name(output_size: Vector2i) -> String:
	var now := Time.get_datetime_dict_from_system()
	var date := "%04d-%02d-%02d" % [now["year"], now["month"], now["day"]]
	var time := "%02d-%02d-%02d" % [now["hour"], now["minute"], now["second"]]
	var pattern := get_string(FILE_NAME_PATTERN).strip_edges()
	if pattern.is_empty():
		pattern = String(get_default(FILE_NAME_PATTERN))
	var file_name := pattern.format({
		"project": String(ProjectSettings.get_setting("application/config/name", "project")),
		"scene": _get_scene_name(),
		"datetime": date + "_" + time,
		"date": date,
		"time": time,
		"timestamp": str(int(Time.get_unix_time_from_system())),
		"width": str(output_size.x),
		"height": str(output_size.y),
		"dpi": String.num(get_dpi(), 2),
	})
	file_name = file_name.validate_filename().strip_edges()
	return file_name if not file_name.is_empty() else "screenshot"


## Full path for the next screenshot. Never points at an existing file.
static func build_output_path(output_size: Vector2i) -> String:
	var base := get_save_directory().path_join(format_file_name(output_size))
	var extension := get_file_extension()
	var path := "%s.%s" % [base, extension]
	var counter := 2
	while FileAccess.file_exists(path):
		path = "%s_%d.%s" % [base, counter, extension]
		counter += 1
	return path


static func _define(key: String, default_value: Variant, hint: PropertyHint, hint_string: String) -> Dictionary:
	return {"key": key, "default": default_value, "hint": hint, "hint_string": hint_string}


static func _is_type_compatible(value: Variant, default_value: Variant) -> bool:
	if typeof(value) == typeof(default_value):
		return true
	# A hand-edited settings file can turn 16.0 into 16.
	return typeof(default_value) == TYPE_FLOAT and typeof(value) == TYPE_INT


static func _get_default_save_directory() -> String:
	var pictures := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures.is_empty():
		return "user://screenshots"
	return pictures.path_join("Godot Screenshots")


static func _get_scene_name() -> String:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return "untitled"
	if scene_root.scene_file_path.is_empty():
		return String(scene_root.name)
	return scene_root.scene_file_path.get_file().get_basename()

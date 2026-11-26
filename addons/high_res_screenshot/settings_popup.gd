@tool
extends PopupPanel
## Settings popup opened by the three-dots button. Every control reads from and
## writes to EditorSettings through settings.gd; the popup holds no state.

signal capture_requested
signal browse_requested

const Settings := preload("res://addons/high_res_screenshot/settings.gd")
const CaptureJob := preload("res://addons/high_res_screenshot/capture_job.gd")

## Returns the size of the editor 3D viewport that would be captured (Vector2i).
var viewport_size_provider := Callable()

var _updating := false
var _storing := false
var _shown := false
var _grid: GridContainer
var _aspect_option: OptionButton
var _custom_aspect_label: Label
var _custom_aspect_box: HBoxContainer
var _custom_aspect_width: SpinBox
var _custom_aspect_height: SpinBox
var _dpi_option: OptionButton
var _custom_dpi_label: Label
var _custom_dpi: SpinBox
var _base_size: SpinBox
var _output_label: Label
var _output_note: Label
var _directory_edit: LineEdit
var _browse_button: Button
var _open_folder_button: Button
var _pattern_edit: LineEdit
var _pattern_preview: Label
var _format_option: OptionButton
var _quality_label: Label
var _quality: SpinBox
var _msaa_option: OptionButton
var _transparent_check: CheckBox
var _gizmos_check: CheckBox
var _open_folder_check: CheckBox
var _warmup: SpinBox
var _render_size_option: OptionButton
var _capture_button: Button


func _init() -> void:
	_build_ui()
	# Controls must never hold anything but the stored values: a stray
	# value_changed would otherwise write a control's initial state back.
	refresh()
	about_to_popup.connect(_on_about_to_popup)
	popup_hide.connect(_apply_pending_edits)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_READY:
		_update_theme()


func _on_about_to_popup() -> void:
	_shown = true
	refresh()


## Loads every control from EditorSettings.
func refresh() -> void:
	if _storing:
		return
	_updating = true
	_select_metadata(_aspect_option, Settings.get_string(Settings.ASPECT_RATIO))
	_custom_aspect_width.value = Settings.get_float(Settings.CUSTOM_ASPECT_WIDTH)
	_custom_aspect_height.value = Settings.get_float(Settings.CUSTOM_ASPECT_HEIGHT)
	_select_metadata(_dpi_option, Settings.get_string(Settings.DPI_PRESET))
	_custom_dpi.value = Settings.get_float(Settings.CUSTOM_DPI)
	_base_size.value = Settings.get_int(Settings.BASE_SIZE)
	_set_text_if_changed(_directory_edit, Settings.get_string(Settings.SAVE_DIRECTORY))
	_set_text_if_changed(_pattern_edit, Settings.get_string(Settings.FILE_NAME_PATTERN))
	_select_metadata(_format_option, Settings.get_string(Settings.IMAGE_FORMAT))
	_quality.value = roundf(Settings.get_float(Settings.JPG_QUALITY) * 100.0)
	_select_metadata(_msaa_option, Settings.get_string(Settings.MSAA))
	_transparent_check.button_pressed = Settings.get_bool(Settings.TRANSPARENT_BACKGROUND)
	_gizmos_check.button_pressed = Settings.get_bool(Settings.INCLUDE_GIZMOS)
	_open_folder_check.button_pressed = Settings.get_bool(Settings.OPEN_FOLDER_AFTER_CAPTURE)
	_warmup.value = Settings.get_int(Settings.WARMUP_FRAMES)
	_select_metadata(_render_size_option, Settings.get_int(Settings.MAX_RENDER_SIZE))
	_updating = false
	_update_derived()


func set_busy(busy: bool) -> void:
	_capture_button.disabled = busy


func _build_ui() -> void:
	var editor_scale := EditorInterface.get_editor_scale()

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, roundi(6.0 * editor_scale))
	add_child(margin)

	var root := VBoxContainer.new()
	root.custom_minimum_size.x = roundf(400.0 * editor_scale)
	margin.add_child(root)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", roundi(10.0 * editor_scale))
	root.add_child(_grid)

	# --- Resolution -------------------------------------------------------
	_add_header("Resolution")

	_aspect_option = OptionButton.new()
	for option: String in Settings.ASPECT_OPTIONS:
		_add_option(_aspect_option, option, option)
	_aspect_option.item_selected.connect(_on_option_selected.bind(_aspect_option, Settings.ASPECT_RATIO))
	_add_row("Aspect ratio", _aspect_option,
			"Viewport: same ratio as the editor 3D viewport being captured.\nThe vertical field of view is always the one you see; a wider or narrower ratio shows more or less on the sides.")

	_custom_aspect_box = HBoxContainer.new()
	_custom_aspect_width = _make_spin_box(0.01, 1000.0, 0.01, Settings.CUSTOM_ASPECT_WIDTH)
	_custom_aspect_width.allow_greater = true
	_custom_aspect_box.add_child(_custom_aspect_width)
	var colon := Label.new()
	colon.text = ":"
	_custom_aspect_box.add_child(colon)
	_custom_aspect_height = _make_spin_box(0.01, 1000.0, 0.01, Settings.CUSTOM_ASPECT_HEIGHT)
	_custom_aspect_height.allow_greater = true
	_custom_aspect_box.add_child(_custom_aspect_height)
	_custom_aspect_label = _add_row("Custom ratio", _custom_aspect_box, "Width : height. Only the ratio matters, e.g. 2.39 : 1.")

	var dpi_tooltip := "Scale = DPI / %d, so %d DPI is 1x.\nShort edge of the image = Base size x scale; the long edge follows the aspect ratio.\nExample: 16:9, base 1080 px, 192 DPI -> 2x -> 3840 x 2160 px." % [int(Settings.REFERENCE_DPI), int(Settings.REFERENCE_DPI)]
	_dpi_option = OptionButton.new()
	for option: String in Settings.DPI_OPTIONS:
		if option == Settings.DPI_CUSTOM:
			_add_option(_dpi_option, "Custom", option)
		else:
			_add_option(_dpi_option, "%s DPI  (%sx)" % [option, String.num(option.to_float() / Settings.REFERENCE_DPI, 3)], option)
	_dpi_option.item_selected.connect(_on_option_selected.bind(_dpi_option, Settings.DPI_PRESET))
	_add_row("Resolution", _dpi_option, dpi_tooltip)

	_custom_dpi = _make_spin_box(12.0, 4800.0, 0.1, Settings.CUSTOM_DPI)
	_custom_dpi.suffix = "DPI"
	_custom_dpi_label = _add_row("Custom DPI", _custom_dpi, dpi_tooltip)

	_base_size = _make_spin_box(64.0, 8640.0, 1.0, Settings.BASE_SIZE, true)
	_base_size.suffix = "px"
	_add_row("Base size", _base_size, "Length of the short edge of the image at %d DPI (1x)." % int(Settings.REFERENCE_DPI))

	var output_box := VBoxContainer.new()
	output_box.add_theme_constant_override("separation", 0)
	_output_label = Label.new()
	output_box.add_child(_output_label)
	_output_note = Label.new()
	_output_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_output_note.custom_minimum_size.x = roundf(240.0 * editor_scale)
	output_box.add_child(_output_note)
	_add_row("Output", output_box, "Final image size in pixels with the current settings.")

	# --- File -------------------------------------------------------------
	_add_header("File")

	var directory_box := HBoxContainer.new()
	_directory_edit = LineEdit.new()
	_directory_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_directory_edit.text_changed.connect(_on_text_changed.bind(Settings.SAVE_DIRECTORY))
	directory_box.add_child(_directory_edit)
	_browse_button = Button.new()
	_browse_button.tooltip_text = "Choose a folder..."
	_browse_button.pressed.connect(func() -> void: browse_requested.emit())
	directory_box.add_child(_browse_button)
	_open_folder_button = Button.new()
	_open_folder_button.tooltip_text = "Open this folder in the file manager."
	_open_folder_button.pressed.connect(_on_open_folder_pressed)
	directory_box.add_child(_open_folder_button)
	_add_row("Save to", directory_box, "Folder the screenshots are written to. Absolute paths, res:// and user:// are accepted; the folder is created on first capture.")

	var pattern_box := VBoxContainer.new()
	pattern_box.add_theme_constant_override("separation", 0)
	_pattern_edit = LineEdit.new()
	_pattern_edit.text_changed.connect(_on_text_changed.bind(Settings.FILE_NAME_PATTERN))
	pattern_box.add_child(_pattern_edit)
	_pattern_preview = Label.new()
	_pattern_preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_pattern_preview.custom_minimum_size.x = roundf(240.0 * editor_scale)
	pattern_box.add_child(_pattern_preview)
	_add_row("File name", pattern_box, "File name without extension. Available tokens:\n" + Settings.FILE_NAME_TOKENS_HELP + "\nA number is appended if the file already exists.")

	_format_option = OptionButton.new()
	_add_option(_format_option, "PNG  (lossless, 8-bit)", Settings.FORMAT_PNG)
	_add_option(_format_option, "JPG  (lossy, 8-bit)", Settings.FORMAT_JPG)
	_add_option(_format_option, "EXR  (linear, 16-bit float)", Settings.FORMAT_EXR)
	_format_option.item_selected.connect(_on_option_selected.bind(_format_option, Settings.IMAGE_FORMAT))
	_add_row("Format", _format_option, "EXR stores the tonemapped image in linear light as half floats.")

	_quality = SpinBox.new()
	_quality.min_value = 1.0
	_quality.max_value = 100.0
	_quality.step = 1.0
	_quality.suffix = "%"
	_quality.value_changed.connect(func(value: float) -> void: _store(Settings.JPG_QUALITY, value / 100.0))
	_quality_label = _add_row("JPG quality", _quality, "")

	# --- Rendering --------------------------------------------------------
	_add_header("Rendering")

	_msaa_option = OptionButton.new()
	_add_option(_msaa_option, "Same as viewport", Settings.MSAA_VIEWPORT)
	_add_option(_msaa_option, "Disabled", "Disabled")
	_add_option(_msaa_option, "MSAA 2x", "2x")
	_add_option(_msaa_option, "MSAA 4x", "4x")
	_add_option(_msaa_option, "MSAA 8x", "8x")
	_msaa_option.item_selected.connect(_on_option_selected.bind(_msaa_option, Settings.MSAA))
	_add_row("Anti-aliasing", _msaa_option,
			"MSAA level of the offscreen render. \"Same as viewport\" uses the project's 3D MSAA setting.\nFXAA/SMAA follow the project setting; TAA and FSR 2 are never used.")

	_transparent_check = _make_check_box("Transparent background", Settings.TRANSPARENT_BACKGROUND,
			"Leaves the sky and background out and writes an alpha channel (PNG and EXR).")
	_add_row("", _transparent_check, "")
	_gizmos_check = _make_check_box("Include editor gizmos", Settings.INCLUDE_GIZMOS,
			"Also renders the 3D gizmos, grid and selection boxes the viewport shows.\n2D overlays of the viewport are never part of the capture.")
	_add_row("", _gizmos_check, "")
	_open_folder_check = _make_check_box("Open folder after capture", Settings.OPEN_FOLDER_AFTER_CAPTURE,
			"Shows the saved file in the file manager.")
	_add_row("", _open_folder_check, "")

	_warmup = _make_spin_box(0.0, 64.0, 1.0, Settings.WARMUP_FRAMES, true)
	_add_row("Warm-up frames", _warmup,
			"Frames rendered and thrown away before the capture.\nGives auto exposure, SDFGI, volumetric fog and other effects that build up over time a chance to settle.")

	_render_size_option = OptionButton.new()
	for render_size: int in Settings.RENDER_SIZE_OPTIONS:
		_add_option(_render_size_option, "%d px" % render_size, render_size)
	_render_size_option.item_selected.connect(_on_option_selected.bind(_render_size_option, Settings.MAX_RENDER_SIZE))
	_add_row("Max render size", _render_size_option,
			"Largest render target the capture allocates, per side. It is capped by the GPU's maximum texture size.\nBigger outputs are rendered as N x N interleaved passes of this size at most and woven together:\nslower, and anti-aliasing gets softer, but video memory use stays bounded.\nRaise it for the best quality if your GPU has the memory; lower it if captures fail.")

	# --- Actions ----------------------------------------------------------
	root.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	root.add_child(actions)
	var reset_button := Button.new()
	reset_button.text = "Reset to Defaults"
	reset_button.pressed.connect(_on_reset_pressed)
	actions.add_child(reset_button)
	actions.add_spacer(false)
	_capture_button = Button.new()
	_capture_button.text = "Capture"
	_capture_button.tooltip_text = "Capture the 3D viewport with these settings."
	_capture_button.pressed.connect(func() -> void: capture_requested.emit())
	actions.add_child(_capture_button)


func _update_theme() -> void:
	if _browse_button == null:
		return
	var editor_theme := EditorInterface.get_editor_theme()
	_browse_button.icon = editor_theme.get_icon(&"FolderBrowse", &"EditorIcons")
	_open_folder_button.icon = editor_theme.get_icon(&"ShowInFileSystem", &"EditorIcons")
	_capture_button.icon = editor_theme.get_icon(&"Camera", &"EditorIcons")
	var dimmed := editor_theme.get_color(&"font_disabled_color", &"Editor")
	_pattern_preview.add_theme_color_override("font_color", dimmed)
	_output_note.add_theme_color_override("font_color", editor_theme.get_color(&"warning_color", &"Editor"))


## Updates everything that is computed from the settings: row visibility, the
## resulting resolution and the file name preview.
func _update_derived() -> void:
	var is_custom_aspect := Settings.get_string(Settings.ASPECT_RATIO) == Settings.ASPECT_CUSTOM
	_custom_aspect_label.visible = is_custom_aspect
	_custom_aspect_box.visible = is_custom_aspect
	var is_custom_dpi := Settings.get_string(Settings.DPI_PRESET) == Settings.DPI_CUSTOM
	_custom_dpi_label.visible = is_custom_dpi
	_custom_dpi.visible = is_custom_dpi
	var format := Settings.get_string(Settings.IMAGE_FORMAT)
	_quality_label.visible = format == Settings.FORMAT_JPG
	_quality.visible = format == Settings.FORMAT_JPG
	_transparent_check.disabled = format == Settings.FORMAT_JPG

	var viewport_size := Vector2i.ZERO
	if viewport_size_provider.is_valid():
		viewport_size = viewport_size_provider.call()
	var output := Settings.resolve_output(viewport_size)
	var size: Vector2i = output["size"]
	var requested: Vector2i = output["requested"]
	var layout := CaptureJob.compute_layout(size, Settings.get_int(Settings.MAX_RENDER_SIZE))
	var megapixels := float(size.x) * float(size.y) / 1000000.0
	_output_label.text = "%d x %d px  (%s MP, %sx)" % [size.x, size.y, String.num(megapixels, 1), String.num(float(output["scale"]), 3)]

	var notes := PackedStringArray()
	if bool(output["clamped"]):
		notes.append("Limited from %d x %d: an image cannot exceed %d megapixels or %d px per side." % [
			requested.x, requested.y, roundi(Settings.MAX_OUTPUT_PIXELS / 1000000.0), Settings.MAX_OUTPUT_SIDE])
	if int(layout["grid"]) > 1:
		var pass_size: Vector2i = layout["pass_size"]
		notes.append("Rendered as %d x %d interleaved passes of %d x %d px." % [layout["grid"], layout["grid"], pass_size.x, pass_size.y])
	if Settings.get_int(Settings.MAX_RENDER_SIZE) > int(layout["limit"]):
		notes.append("Render size limited to %d px by the GPU." % int(layout["limit"]))
	_output_note.text = "\n".join(notes)
	_output_note.visible = not notes.is_empty()

	_pattern_preview.text = "%s.%s" % [Settings.format_file_name(size), Settings.get_file_extension()]
	_pattern_preview.tooltip_text = Settings.get_save_directory().path_join(_pattern_preview.text)

	# Rows appear and disappear: let the popup shrink back to its content.
	if visible:
		reset_size.call_deferred()


func _store(key: String, value: Variant) -> void:
	if _updating:
		return
	_storing = true
	Settings.set_value(key, value)
	_storing = false
	_update_derived()


func _on_option_selected(index: int, option: OptionButton, key: String) -> void:
	_store(key, option.get_item_metadata(index))


func _on_text_changed(text: String, key: String) -> void:
	_store(key, text)


func _on_open_folder_pressed() -> void:
	var directory := Settings.get_save_directory()
	if DirAccess.dir_exists_absolute(directory) or DirAccess.make_dir_recursive_absolute(directory) == OK:
		OS.shell_open(directory)


func _on_reset_pressed() -> void:
	Settings.reset_all()
	refresh()


## A SpinBox only commits typed text on Enter or focus loss; closing the popup
## must not drop a half-entered value.
func _apply_pending_edits() -> void:
	if not _shown:
		return
	_shown = false
	for spin_box: SpinBox in [_custom_aspect_width, _custom_aspect_height, _custom_dpi, _base_size, _quality, _warmup]:
		spin_box.apply()


func _add_header(text: String) -> void:
	var header := Label.new()
	header.text = text
	header.theme_type_variation = &"HeaderSmall"
	_grid.add_child(header)
	var line := HSeparator.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_grid.add_child(line)


func _add_row(label_text: String, control: Control, tooltip: String) -> Label:
	var label := Label.new()
	label.text = label_text
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.tooltip_text = tooltip
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if control.tooltip_text.is_empty():
		control.tooltip_text = tooltip
	_grid.add_child(control)
	return label


func _add_option(option: OptionButton, text: String, metadata: Variant) -> void:
	option.add_item(text)
	option.set_item_metadata(option.item_count - 1, metadata)


func _make_spin_box(min_value: float, max_value: float, step: float, key: String, is_integer := false) -> SpinBox:
	var spin_box := SpinBox.new()
	spin_box.min_value = min_value
	spin_box.max_value = max_value
	spin_box.step = step
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_integer:
		spin_box.rounded = true
		spin_box.value_changed.connect(func(value: float) -> void: _store(key, roundi(value)))
	else:
		spin_box.value_changed.connect(func(value: float) -> void: _store(key, value))
	return spin_box


func _make_check_box(text: String, key: String, tooltip: String) -> CheckBox:
	var check_box := CheckBox.new()
	check_box.text = text
	check_box.tooltip_text = tooltip
	check_box.toggled.connect(func(pressed: bool) -> void: _store(key, pressed))
	return check_box


func _select_metadata(option: OptionButton, value: Variant) -> void:
	for index in option.item_count:
		if option.get_item_metadata(index) == value:
			option.select(index)
			return
	option.select(0)


func _set_text_if_changed(line_edit: LineEdit, text: String) -> void:
	# Assigning text resets the caret, which must not happen while typing.
	if line_edit.text != text:
		line_edit.text = text

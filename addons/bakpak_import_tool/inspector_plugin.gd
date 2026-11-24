@tool
extends EditorInspectorPlugin

const METADATA_GENERATED = "bakpak_generated"
const METADATA_LOD_GROUP = "bakpak_lod_group"

func _can_handle(object: Object) -> bool:
	if object is Node3D and object.has_meta(METADATA_GENERATED):
		return true
	if object is MeshInstance3D:
		# Check if parent is generated or if it has the meta itself
		if object.has_meta(METADATA_GENERATED):
			return true
		var parent = object.get_parent()
		if parent and parent.has_meta(METADATA_GENERATED):
			return true
	return false

func _parse_begin(object: Object) -> void:
	add_custom_control(Label.new()) # Spacing
	var label = Label.new()
	label.text = "BakPak Import Settings"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(0.5, 0.8, 1.0) # Light blueish
	add_custom_control(label)

	add_property_editor("LOD Group", BakPakLODGroupEditor.new(object))

class BakPakLODGroupEditor extends EditorProperty:
	var _option_button: OptionButton
	var _object: Object

	func _init(obj: Object) -> void:
		_object = obj
		label = "LOD Group"

		_option_button = OptionButton.new()
		add_child(_option_button)
		add_focusable(_option_button)
		_option_button.item_selected.connect(_on_item_selected)

		_update_items()
		_update_selection()

	func _update_property() -> void:
		_update_items()
		_update_selection()

	func _update_items() -> void:
		var current_selected_text = ""
		if _option_button.get_selected_id() >= 0:
			current_selected_text = _option_button.get_item_text(_option_button.get_selected_id())

		_option_button.clear()
		var groups = ProjectSettings.get_setting("BakPak/ImportTool/lod_groups", {})
		var keys = groups.keys()
		keys.sort()
		for key in keys:
			_option_button.add_item(key)

		# Try to restore selection
		for i in range(_option_button.item_count):
			if _option_button.get_item_text(i) == current_selected_text:
				_option_button.select(i)
				break

	func _update_selection() -> void:
		var target_obj = _object
		if not target_obj.has_meta(METADATA_GENERATED):
			var parent = target_obj.get_parent()
			if parent and parent.has_meta(METADATA_GENERATED):
				target_obj = parent

		var current_val = target_obj.get_meta(METADATA_LOD_GROUP, "")
		for i in range(_option_button.item_count):
			if _option_button.get_item_text(i) == current_val:
				_option_button.select(i)
				return

		# If not found, maybe it's using the default or is empty
		if current_val == "":
			var default_group = ProjectSettings.get_setting("BakPak/ImportTool/default_lod_group", "default")
			for i in range(_option_button.item_count):
				if _option_button.get_item_text(i) == default_group:
					_option_button.select(i)
					return

		# Still not selected? Maybe it was some custom string that no longer exists
		if _option_button.get_selected_id() == -1 and _option_button.item_count > 0:
			_option_button.select(0)

	func _on_item_selected(index: int) -> void:
		var new_text = _option_button.get_item_text(index)
		_apply_change(new_text)

	func _apply_change(new_text: String) -> void:
		var target_obj = _object
		if not target_obj.has_meta(METADATA_GENERATED):
			var parent = target_obj.get_parent()
			if parent and parent.has_meta(METADATA_GENERATED):
				target_obj = parent

		var old_text = target_obj.get_meta(METADATA_LOD_GROUP, "")
		if new_text == old_text:
			return

		emit_changed(METADATA_LOD_GROUP, new_text)
		target_obj.set_meta(METADATA_LOD_GROUP, new_text)

		# Apply LOD bias immediately
		var groups = ProjectSettings.get_setting("BakPak/ImportTool/lod_groups", {})
		if groups.has(new_text):
			var group_data = groups[new_text]
			var bias = group_data.get("bias", 1.0)

			# If it's a Node3D (generated root), apply to all child MeshInstance3Ds
			if target_obj is Node3D:
				_apply_bias_recursive(target_obj, bias, new_text)
			elif target_obj is MeshInstance3D:
				target_obj.lod_bias = bias
				_regenerate_lods(target_obj, new_text)

		# Update property list in inspector
		target_obj.notify_property_list_changed()

		# Ensure the scene is marked as changed
		if target_obj is Node:
			var scene_root = target_obj.get_tree().edited_scene_root
			if scene_root:
				EditorInterface.mark_scene_as_unsaved()

	func _apply_bias_recursive(node: Node, bias: float, lod_group: String) -> void:
		if node is MeshInstance3D:
			node.lod_bias = bias
			_regenerate_lods(node, lod_group)

		# If the node itself was handled, we still want to check its children
		for child in node.get_children():
			_apply_bias_recursive(child, bias, lod_group)

	func _regenerate_lods(mi: MeshInstance3D, lod_group: String) -> void:
		if not mi.mesh or not (mi.mesh is ArrayMesh):
			return

		var mesh_path = mi.mesh.resource_path
		if mesh_path == "" or "::" in mesh_path:
			# If it's an internal resource or has no path, we look for the _merged.res file in the same directory
			# We need to find the scene path. For an edited scene, we can try to find it via its owner or just assume standard naming.
			var scene_path = mi.get_tree().edited_scene_root.scene_file_path if mi.get_tree() and mi.get_tree().edited_scene_root else ""
			if scene_path == "" or not scene_path.ends_with(".generated.tscn"):
				print("[BakPakImportTool] Mesh is internal and could not determine scene path. Cannot regenerate.")
				return

			var base_dir = scene_path.get_base_dir()
			var base_name = scene_path.get_file().replace(".generated.tscn", "")
			mesh_path = base_dir.path_join(base_name + "_merged.res")

			if not FileAccess.file_exists(mesh_path):
				print("[BakPakImportTool] Mesh is internal and no external _merged.res found at: ", mesh_path)
				return

			# Load the external mesh to use it
			mi.mesh = ResourceLoader.load(mesh_path, "", ResourceLoader.CACHE_MODE_REPLACE)
			if not mi.mesh or not (mi.mesh is ArrayMesh):
				return

		# Show a simple progress dialog for single mesh as well if it's slow
		var dialog = AcceptDialog.new()
		dialog.title = "Regenerating LODs"
		dialog.exclusive = false
		dialog.get_ok_button().hide()

		var vb = VBoxContainer.new()
		dialog.add_child(vb)

		var label = Label.new()
		label.text = "Regenerating LODs for: %s" % mesh_path.get_file()
		vb.add_child(label)

		var progress = ProgressBar.new()
		progress.indeterminate = true # Indeterminate because it's just one file but we don't know how long it takes
		vb.add_child(progress)

		EditorInterface.get_base_control().add_child(dialog)
		dialog.popup_centered()

		await mi.get_tree().process_frame

		print("[BakPakImportTool] Regenerating LODs for: ", mesh_path)

		var base_mesh = mi.mesh
		var lod_result = BakPakUtils.generate_mesh_lods(base_mesh, lod_group)

		# Writes the file and refreshes the mesh object already in use for this path
		# (keeping its UID), so every scene showing the mesh updates.
		var live_mesh = BakPakUtils.save_resource_in_place(lod_result.mesh, mesh_path)
		if live_mesh:
			print("[BakPakImportTool] Successfully regenerated LODs and saved to: ", mesh_path)
			mi.mesh = live_mesh
		else:
			printerr("[BakPakImportTool] Failed to save regenerated mesh: ", mesh_path)

		dialog.queue_free()

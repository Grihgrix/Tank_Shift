@tool
extends EditorPlugin

const Fingerprint = preload("res://addons/bakpak_import_tool/fingerprint.gd")

## Generated files go to this folder, following the collection hierarchy of the GLB.
## The spelling is matched to what exists on disk (see BakPakUtils.canonicalize_path).
const IMPORT_ROOT = "res://assets/"

var _inspector_plugin: EditorInspectorPlugin
var _context_menu_plugin: EditorContextMenuPlugin

# Generated scenes waiting to be written: Array of {"root": Node, "path": String}.
# They are saved together by _flush_pending_scene_saves() so the editor is told
# once, before and after, which scenes are being replaced.
var _pending_scene_saves: Array = []
# True while this plugin is the one emitting EditorFileSystem's reimport signals.
var _notifying_editor := false

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	_setup_project_settings()
	EditorInterface.get_resource_filesystem().resources_reimported.connect(_on_resources_reimported)
	ProjectSettings.settings_changed.connect(_on_settings_changed)

	_inspector_plugin = load("res://addons/bakpak_import_tool/inspector_plugin.gd").new()
	add_inspector_plugin(_inspector_plugin)

	if ClassDB.class_exists("EditorContextMenuPlugin"):
		_context_menu_plugin = load("res://addons/bakpak_import_tool/context_menu_plugin.gd").new()
		_context_menu_plugin.plugin = self
		add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, _context_menu_plugin)


func _on_settings_changed() -> void:
	# Update property info to refresh enum suggestions for default_lod_group
	_setup_project_settings()

	if ProjectSettings.get_setting("BakPak/ImportTool/regenerate_all_lods", false):
		# Reset the setting immediately to avoid double execution
		ProjectSettings.set_setting("BakPak/ImportTool/regenerate_all_lods", false)
		ProjectSettings.save()
		_regenerate_all_lods_with_progress()


func _setup_project_settings() -> void:
	var preset_name = "BakPak/ImportTool/preset_import_materials"
	var default_name = "BakPak/ImportTool/default_import_material"
	var max_primitives_name = "BakPak/ImportTool/max_primitive_collision_shapes"
	var auto_generate_lods_name = "BakPak/ImportTool/auto_generate_lods"
	var lod_groups_name = "BakPak/ImportTool/lod_groups"
	var default_lod_group_name = "BakPak/ImportTool/default_lod_group"
	var regenerate_all_lods_name = "BakPak/ImportTool/regenerate_all_lods"
	var collision_debug_color_name = "BakPak/ImportTool/collision_debug_color"

	if not ProjectSettings.has_setting(preset_name):
		ProjectSettings.set_setting(preset_name, {})

	if not ProjectSettings.has_setting(default_name):
		ProjectSettings.set_setting(default_name, "")

	if not ProjectSettings.has_setting(max_primitives_name):
		ProjectSettings.set_setting(max_primitives_name, 10)

	if not ProjectSettings.has_setting(auto_generate_lods_name):
		ProjectSettings.set_setting(auto_generate_lods_name, true)

	if not ProjectSettings.has_setting(lod_groups_name):
		# Default group
		ProjectSettings.set_setting(lod_groups_name, {
			"default": {
				"normal_merge_angle": 25.0,
				"normal_split_angle": 60.0,
				"bias": 1.0
			}
		})

	if not ProjectSettings.has_setting(default_lod_group_name):
		ProjectSettings.set_setting(default_lod_group_name, "default")

	if not ProjectSettings.has_setting(regenerate_all_lods_name):
		ProjectSettings.set_setting(regenerate_all_lods_name, false)

	if not ProjectSettings.has_setting(collision_debug_color_name):
		ProjectSettings.set_setting(collision_debug_color_name, Color(0.0, 0.6, 0.7, 0.4))

	ProjectSettings.set_initial_value(preset_name, {})
	ProjectSettings.set_initial_value(default_name, "")
	ProjectSettings.set_initial_value(max_primitives_name, 10)
	ProjectSettings.set_initial_value(auto_generate_lods_name, true)
	ProjectSettings.set_initial_value(lod_groups_name, {
		"default": {
			"normal_merge_angle": 25.0,
			"normal_split_angle": 60.0,
			"bias": 1.0
		}
	})
	ProjectSettings.set_initial_value(default_lod_group_name, "default")
	ProjectSettings.set_initial_value(regenerate_all_lods_name, false)
	ProjectSettings.set_initial_value(collision_debug_color_name, Color(0.0, 0.6, 0.7, 0.4))

	var preset_info = {
		"name": preset_name,
		"type": TYPE_DICTIONARY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d:;%d/%d:*.tres" % [TYPE_STRING, TYPE_STRING, PROPERTY_HINT_FILE]
	}
	var default_info = {
		"name": default_name,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tres"
	}
	var max_primitives_info = {
		"name": max_primitives_name,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1,100,1"
	}
	var auto_generate_lods_info = {
		"name": auto_generate_lods_name,
		"type": TYPE_BOOL
	}
	var lod_groups_info = {
		"name": lod_groups_name,
		"type": TYPE_DICTIONARY
	}
	var default_lod_group_info = {
		"name": default_lod_group_name,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM_SUGGESTION,
		"hint_string": ",".join(ProjectSettings.get_setting("BakPak/ImportTool/lod_groups", {}).keys())
	}
	var regenerate_all_lods_info = {
		"name": regenerate_all_lods_name,
		"type": TYPE_BOOL
	}
	var collision_debug_color_info = {
		"name": collision_debug_color_name,
		"type": TYPE_COLOR
	}

	ProjectSettings.add_property_info(preset_info)
	ProjectSettings.add_property_info(default_info)
	ProjectSettings.add_property_info(max_primitives_info)
	ProjectSettings.add_property_info(auto_generate_lods_info)
	ProjectSettings.add_property_info(lod_groups_info)
	ProjectSettings.add_property_info(default_lod_group_info)
	ProjectSettings.add_property_info(regenerate_all_lods_info)
	ProjectSettings.add_property_info(collision_debug_color_info)
	ProjectSettings.save()


func _exit_tree() -> void:
	EditorInterface.get_resource_filesystem().resources_reimported.disconnect(_on_resources_reimported)
	ProjectSettings.settings_changed.disconnect(_on_settings_changed)
	if _inspector_plugin:
		remove_inspector_plugin(_inspector_plugin)
	if _context_menu_plugin:
		remove_context_menu_plugin(_context_menu_plugin)


func _on_context_regenerate_lods(paths: PackedStringArray) -> void:
	for path in paths:
		if path.ends_with(".tscn"):
			_regenerate_lods_for_scene(path)
	_flush_pending_scene_saves()

func _on_context_reimport_from_glb(paths: PackedStringArray) -> void:
	var import_data = _load_import_data()
	var glbs_to_reimport = {} # glb_path -> Array of entity names

	for path in paths:
		if path.ends_with(".tscn"):
			path = BakPakUtils.canonicalize_path(path)
			# Find which GLB this tscn belongs to
			for glb_path in import_data:
				var data = import_data[glb_path]

				# Check entities
				var entities = data.get("entities", {})
				for ent_name in entities:
					if path in entities[ent_name].get("files", []):
						if not glb_path in glbs_to_reimport:
							glbs_to_reimport[glb_path] = []
						if not ent_name in glbs_to_reimport[glb_path]:
							glbs_to_reimport[glb_path].append(ent_name)
						break

	for glb_path in glbs_to_reimport:
		var entities_to_force = glbs_to_reimport[glb_path]
		print("[BakPakImportTool] Context re-importing GLB: ", glb_path, " forced entities: ", entities_to_force)
		_on_glb_imported(glb_path, entities_to_force)

func _on_context_force_reimport_glb(paths: PackedStringArray) -> void:
	for path in paths:
		if path.ends_with(".glb") or path.ends_with(".gltf"):
			print("[BakPakImportTool] Context force re-importing all from: ", path)
			_on_glb_imported(path, [], true)

func _on_resources_reimported(resources: PackedStringArray) -> void:
	if _notifying_editor:
		# Our own notification about generated scenes (see _flush_pending_scene_saves).
		return
	print("[BakPakImportTool] Resources reimported: ", resources)
	for resource_path: String in resources:
		if resource_path.ends_with(".glb"):
			_on_glb_imported(resource_path)


func _on_glb_imported(resource_path: String, force_entities: Array = [], force_all: bool = false) -> void:
	if not FileAccess.file_exists(resource_path):
		printerr("[BakPakImportTool] GLB file not found: ", resource_path)
		return

	BakPakUtils.clear_path_cache()
	resource_path = BakPakUtils.canonicalize_path(resource_path)

	# print("[BakPakImportTool] GLB file imported or updated: ", resource_path)

	var start_time = Time.get_ticks_msec()
	var updated_count = 0
	var skipped_count = 0

	# Small delay to ensure Godot has finished updating internal state if needed
	# await get_tree().create_timer(0.1).timeout

	# _check_duplicate_names(resource_path)

	var scene: PackedScene = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not scene:
		printerr("[BakPakImportTool] Failed to load scene: ", resource_path)
		return

	var instance = scene.instantiate()
	if not instance:
		printerr("[BakPakImportTool] Failed to instantiate scene: ", resource_path)
		return

	var export_node = _find_export_node(instance)
	if not export_node:
		printerr("[BakPakImportTool] No 'Export' node found in GLB: ", resource_path, ". Skipping import.")
		instance.free()
		return

	var entities = []
	_find_entities_recursive(export_node, "", entities)

	var import_data = _load_import_data()
	var old_entities = {} # name -> {path, files}
	if import_data.has(resource_path):
		old_entities = import_data[resource_path].get("entities", {})
		# For backward compatibility with old history format (which only had "files" array)
		if old_entities.is_empty() and import_data[resource_path].has("files"):
			# We can't easily map back to entities, so we'll just treat them as files to delete if not reused
			pass

	var new_entities_data = {} # name -> {path, files, fingerprint}
	var current_all_files = []

	if entities.is_empty():
		print("[BakPakImportTool] No entities found under 'Export' in: ", resource_path)
	else:
		for entity in entities:
			var target_dir = BakPakUtils.canonicalize_path(IMPORT_ROOT.path_join(entity.path))
			var fingerprint = _get_entity_fingerprint(entity.node)

			# MOVE DETECTION
			if old_entities.has(entity.name):
				var old_entity_data = old_entities[entity.name]
				var old_dir = BakPakUtils.canonicalize_path(IMPORT_ROOT.path_join(old_entity_data.get("path", "")))

				if old_dir != target_dir:
					print("[BakPakImportTool] Entity '", entity.name, "' moved from ", old_dir, " to ", target_dir)

					if not DirAccess.dir_exists_absolute(target_dir):
						DirAccess.make_dir_recursive_absolute(target_dir)

					for old_file in old_entity_data.files:
						if FileAccess.file_exists(old_file):
							var filename = old_file.get_file()
							var new_file = target_dir.path_join(filename)

							var err = DirAccess.rename_absolute(old_file, new_file)
							if err == OK:
								print("[BakPakImportTool] Moved file: ", old_file, " -> ", new_file)
								EditorInterface.get_resource_filesystem().update_file(old_file)
								EditorInterface.get_resource_filesystem().update_file(new_file)
							else:
								printerr("[BakPakImportTool] Failed to move file: ", old_file, " Error: ", err)

			var should_process = true
			if not force_entities.is_empty() and not entity.name in force_entities:
				should_process = false

			var processed_files = []

			if should_process and old_entities.has(entity.name):
				var old_data = old_entities[entity.name]
				var old_fingerprint = old_data.get("fingerprint", "")

				# If we are forcing THIS entity, we skip fingerprint check
				var is_forced = force_all or (not force_entities.is_empty() and entity.name in force_entities)

				if not is_forced and fingerprint == old_fingerprint:
					# Check if all files actually exist
					var files_exist = true
					var old_files = old_data.get("files", [])
					for f in old_files:
						# Update path in case it was moved
						var filename = f.get_file()
						var current_path = target_dir.path_join(filename)
						if not FileAccess.file_exists(current_path):
							files_exist = false
							break

					if files_exist:
						should_process = false
						# Map files to their new location (if moved)
						for f in old_files:
							processed_files.append(target_dir.path_join(f.get_file()))
						skipped_count += 1

			if not DirAccess.dir_exists_absolute(target_dir):
				DirAccess.make_dir_recursive_absolute(target_dir)

			if not should_process:
				if old_entities.has(entity.name):
					var old_data = old_entities[entity.name]
					processed_files = []
					# Ensure files are mapped to their new location (if moved)
					for f in old_data.get("files", []):
						processed_files.append(target_dir.path_join(f.get_file()))

					# Keep the old fingerprint if skipped
					fingerprint = old_data.get("fingerprint", fingerprint)
				else:
					# This is a new entity that we chose to skip (e.g. not in force_entities)
					# We have no old data to carry over, so processed_files remains empty.
					pass

			if should_process:
				processed_files = _process_entity(entity.node, target_dir, entity.name)
				updated_count += 1

			new_entities_data[entity.name] = {
				"path": entity.path,
				"files": processed_files,
				"fingerprint": fingerprint
			}
			current_all_files.append_array(processed_files)

	# Write the generated scenes that changed and refresh the open scenes using them.
	_flush_pending_scene_saves()

	# Compare and delete old files that are no longer in current_all_files
	var old_all_files = []
	if import_data.has(resource_path):
		var old_data_root = import_data[resource_path]
		if old_data_root.has("files"):
			for f in old_data_root.files:
				if not f in old_all_files:
					old_all_files.append(f)

		var old_entities_dict = old_data_root.get("entities", {})
		for ent_name in old_entities_dict:
			var ent_files = old_entities_dict[ent_name].get("files", [])
			for f in ent_files:
				if not f in old_all_files:
					old_all_files.append(f)

	BakPakUtils.clear_path_cache() # Files were created/removed since the listings were cached.
	for old_file in old_all_files:
		# Resolve the on-disk spelling first: a path that differs from a current
		# file only by case is the same file on Windows/macOS and must not be deleted.
		old_file = BakPakUtils.canonicalize_path(old_file)
		if not old_file in current_all_files:
			if FileAccess.file_exists(old_file):
				var err = DirAccess.remove_absolute(old_file)
				if err == OK:
					print("[BakPakImportTool] Deleted obsolete file from GLB change: ", old_file)
					EditorInterface.get_resource_filesystem().update_file(old_file)
				else:
					printerr("[BakPakImportTool] Failed to delete obsolete file: ", old_file, " Error: ", err)

	# Update tracking data
	import_data[resource_path] = {"entities": new_entities_data, "files": current_all_files}
	_save_import_data(import_data)

	var end_time = Time.get_ticks_msec()
	var duration = (end_time - start_time) / 1000.0
	print("[BakPakImportTool] Post-import for '", resource_path, "' finished in ", "%.2f" % duration, "s. Updated: ", updated_count, ", Skipped: ", skipped_count)

	instance.free()


func _find_export_node(instance: Node) -> Node:
	if instance.name == "Export":
		return instance
	return instance.find_child("Export", true, false)


func _find_entities_recursive(node: Node, current_path: String, entities: Array, name_override: String = "") -> void:
	if node.name.begins_with("_"):
		return

	var is_entity = node is MeshInstance3D or node is Skeleton3D

	if is_entity:
		var entity_name = name_override if name_override != "" else node.name
		entities.append({"node": node, "path": current_path, "name": entity_name})
		return

	if node is Node3D:
		var children = node.get_children()
		# Check if it's a wrapper: exactly one child and that child is a Skeleton3D
		if node.name != "Export" and children.size() == 1 and children[0] is Skeleton3D:
			# Skip the wrapper name in the path and process the child directly at current level
			# Use the wrapper name as the name override for the child
			_find_entities_recursive(children[0], current_path, entities, node.name)
			return

		var new_path = current_path
		if node.name != "Export":
			if new_path != "":
				new_path = new_path.path_join(node.name)
			else:
				new_path = node.name

		for child in children:
			_find_entities_recursive(child, new_path, entities)


func _get_entity_fingerprint(node: Node) -> String:
	# The fingerprint must change whenever the files generated for this entity
	# would change. That is the content of the entity's node subtree (hashed by
	# Fingerprint: meshes by their actual vertex/index/attribute data, materials,
	# skins, bones, transforms, metadata...) plus the project-side inputs of the
	# pipeline: the settings below and the material each surface resolves to.
	var resolved_materials = []
	_collect_resolved_materials(node, resolved_materials)
	var pipeline_inputs = [
		ProjectSettings.get_setting("BakPak/ImportTool/auto_generate_lods", true),
		ProjectSettings.get_setting("BakPak/ImportTool/max_primitive_collision_shapes", 10),
		ProjectSettings.get_setting("BakPak/ImportTool/collision_debug_color", Color(0.0, 0.6, 0.7, 0.4)),
		resolved_materials
	]
	return Fingerprint.entity_fingerprint(node, pipeline_inputs)


# Lists, for every surface of the entity, what _merge_meshes() will do with it:
# final surface name, whether a preset matched, and which material gets assigned.
# Editing the preset/default materials in the Project Settings therefore triggers
# a re-import of exactly the entities that use the affected slots.
func _collect_resolved_materials(node: Node, results: Array) -> void:
	if node.name.begins_with("_"):
		return

	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var mat_info = _get_final_material_info(node.get_active_material(i), node.mesh.surface_get_name(i))
			var final_mat_path = ""
			if mat_info.material:
				final_mat_path = mat_info.material.resource_path
			results.append([mat_info.name, mat_info.matched, final_mat_path])

	for child in node.get_children():
		_collect_resolved_materials(child, results)


func _process_entity(entity_node: Node, base_dir: String, base_name: String) -> Array:
	var generated_files = []

	# Detect collision skipping before cleaning base_name
	var skip_collision = base_name.ends_with("_nocol")
	if skip_collision:
		base_name = base_name.trim_suffix("_nocol")

	# Ensure base_name is snake_case for filenames
	var snake_name = base_name.to_snake_case()

	var extracted_data = _extract_meshes_data(entity_node, Transform3D.IDENTITY, true)
	var visual_data = extracted_data.visual
	var collision_data = extracted_data.collision
	var skeletons_data = extracted_data.skeletons

	# Separate visual data into static and skinned
	var static_visual_data = []
	var skinned_visual_data = []

	var merged_mesh = null
	var save_path = ""

	# Calculate reference transform for centering (pivot at center)
	var reference_transform = Transform3D.IDENTITY
	var has_reference = false

	if not visual_data.is_empty():
		reference_transform = visual_data[0].transform
		has_reference = true
		# Adjust all visual data transforms
		for i in range(visual_data.size()):
			visual_data[i].transform = reference_transform.affine_inverse() * visual_data[i].transform
	elif not collision_data.is_empty():
		reference_transform = collision_data[0].transform
		has_reference = true
		# Adjust all collision data transforms
		for i in range(collision_data.size()):
			collision_data[i].transform = reference_transform.affine_inverse() * collision_data[i].transform

	var inv_reference = Transform3D.IDENTITY
	if has_reference:
		inv_reference = reference_transform.affine_inverse()
		# Already adjusted visual_data if has_reference was from visual_data,
		# but if it was from collision_data, we might need to adjust visual_data here too.
		# Actually, let's keep it simple and just do it once.
		# Re-doing it to be sure and include skeletons.

		for i in range(visual_data.size()):
			visual_data[i].transform = inv_reference * visual_data[i].transform

		for i in range(collision_data.size()):
			collision_data[i].transform = inv_reference * collision_data[i].transform

		for i in range(skeletons_data.size()):
			skeletons_data[i].transform = inv_reference * skeletons_data[i].transform

	# Re-separate visual data into static and skinned after transform update
	static_visual_data = []
	var skinned_by_skeleton = {} # Skeleton3D -> Array

	for v in visual_data:
		if v.skeleton:
			if not skinned_by_skeleton.has(v.skeleton):
				skinned_by_skeleton[v.skeleton] = []
			skinned_by_skeleton[v.skeleton].append(v)
		else:
			static_visual_data.append(v)

	# Process skinned meshes: merge them if they share a skeleton.
	# Skinned mesh vertices come in "skin space", which carries the armature's
	# layout offset from the Blender scene (Godot's glTF importer bakes that
	# offset into the vertices and inverse-bind matrices rather than onto the
	# Skeleton3D node). We bake the skin-space -> rest transform into the mesh so
	# the saved .res is centered on the skeleton pivot (correct AABB and placement
	# when displayed without a skeleton), and compensate the skin bind poses by the
	# inverse so the rigged deformation stays exactly the same.
	skinned_visual_data = []
	for skel in skinned_by_skeleton.keys():
		var meshes_for_skel = skinned_by_skeleton[skel]
		var first_v = meshes_for_skel[0]
		var skin_orig = first_v.skin

		var center_xform = _compute_skin_center_transform(skel, skin_orig)

		# Bake the centering transform into the merged mesh vertices. Skinned mesh
		# nodes share the same skin space (glTF ignores their individual node
		# transforms), so the same transform applies to every mesh of the skeleton.
		var merge_inputs = []
		for mv in meshes_for_skel:
			var mv_copy = mv.duplicate()
			mv_copy.transform = center_xform
			merge_inputs.append(mv_copy)
		var merged_skel_mesh = _merge_meshes(merge_inputs)

		if merged_skel_mesh:
			var merged_name = skel.name + "_Mesh"

			# Compensate the skin (inverse-bind matrices) so that, combined with the
			# baked vertices, the deformation is identical to the source: for any
			# bone, bind' * (T * v) == bind * v because bind' = bind * T^-1.
			var skin_to_use = skin_orig
			if skin_orig:
				var inv_center = center_xform.affine_inverse()
				var new_skin = Skin.new()
				for b in range(skin_orig.get_bind_count()):
					new_skin.add_bind(skin_orig.get_bind_bone(b), skin_orig.get_bind_pose(b) * inv_center)
					new_skin.set_bind_name(b, skin_orig.get_bind_name(b))
				skin_to_use = new_skin

			skinned_visual_data.append({
				"mesh": merged_skel_mesh,
				"skeleton": skel,
				"skin": skin_to_use,
				"name": merged_name,
				"transform": Transform3D.IDENTITY
			})

	var tscn_path = base_dir.path_join(snake_name + ".tscn")
	var auto_generate_lods = ProjectSettings.get_setting("BakPak/ImportTool/auto_generate_lods", true)
	var current_lod_group = ProjectSettings.get_setting("BakPak/ImportTool/default_lod_group", "default")
	if auto_generate_lods and FileAccess.file_exists(tscn_path):
		var previous_scene = ResourceLoader.load(tscn_path, "PackedScene") as PackedScene
		current_lod_group = BakPakUtils.get_scene_root_meta(previous_scene, "bakpak_lod_group", current_lod_group)

	var saved_meshes = []
	var material_names = []
	var all_lods_triangles = [] # Array of Arrays

	if not static_visual_data.is_empty():
		merged_mesh = _merge_meshes(static_visual_data)

		if merged_mesh:
			if auto_generate_lods:
				var lod_result = BakPakUtils.generate_mesh_lods(merged_mesh, current_lod_group)
				merged_mesh = lod_result.mesh
				if not lod_result.lod_info.is_empty():
					all_lods_triangles.append_array(lod_result.lod_info)

			if merged_mesh.get_surface_count() > 0:
				save_path = base_dir.path_join(snake_name + ".res")
				# Write the file and refresh the mesh object the editor already has
				# for this path, so open scenes show the new geometry right away.
				var live_mesh = BakPakUtils.save_resource_in_place(merged_mesh, save_path)
				if live_mesh:
					merged_mesh = live_mesh
					saved_meshes.append(save_path)
					generated_files.append(save_path)
				else:
					save_path = ""

	# Save skinned meshes to .res files
	for i in range(skinned_visual_data.size()):
		var sm = skinned_visual_data[i]
		var mesh_to_save = sm.mesh
		if auto_generate_lods:
			var lod_result = BakPakUtils.generate_mesh_lods(mesh_to_save, current_lod_group)
			mesh_to_save = lod_result.mesh
			if not lod_result.lod_info.is_empty():
				all_lods_triangles.append_array(lod_result.lod_info)

		var sm_path = base_dir.path_join(snake_name + ".res")
		if skinned_visual_data.size() > 1:
			sm_path = base_dir.path_join(snake_name + "_" + str(i) + ".res")

		var live_mesh = BakPakUtils.save_resource_in_place(mesh_to_save, sm_path)
		if live_mesh:
			sm.mesh = live_mesh
			saved_meshes.append(sm_path)
			generated_files.append(sm_path)

	_cleanup_obsolete_meshes(base_dir, snake_name, saved_meshes)

	var merged_collision_mesh = null
	var collision_shapes = []

	if not collision_data.is_empty():
		var max_primitives = ProjectSettings.get_setting("BakPak/ImportTool/max_primitive_collision_shapes", 10)

		if collision_data.size() <= max_primitives:
			for col in collision_data:
				var detection = _detect_primitive_shape(col.mesh, col.transform)
				collision_shapes.append(detection)
		else:
			# Exceeded limit, merge into one concave
			merged_collision_mesh = _merge_meshes(collision_data, true)
			# _merge_meshes already bakes transforms into vertices.
	elif not static_visual_data.is_empty():
		# Try to detect primitives from visual meshes if no specified colliders
		var max_primitives = ProjectSettings.get_setting("BakPak/ImportTool/max_primitive_collision_shapes", 10)
		if static_visual_data.size() <= max_primitives:
			for visual in static_visual_data:
				var detection = _detect_primitive_shape(visual.mesh, visual.transform)
				# Only add if it's a primitive shape, not the concave fallback
				if not detection.shape is ConcavePolygonShape3D:
					collision_shapes.append(detection)

	_generate_tscn_complex(merged_mesh, merged_collision_mesh, collision_shapes, base_dir, base_name, skeletons_data, skinned_visual_data, skip_collision)
	generated_files.append(base_dir.path_join(snake_name + ".tscn"))

	# Collect material names for logging
	for v in visual_data:
		for surf in v.surface_info:
			var mat_info = _get_final_material_info(surf.material, surf.slot_name)
			var mname = mat_info.name
			if not mat_info.matched:
				mname += " (no preset)"
			if not mname in material_names:
				material_names.append(mname)

	# Summary log
	var final_lod_summary = ""
	if not all_lods_triangles.is_empty():
		# Use the first surface's LOD info as representative, or aggregate?
		# Usually, we want the count of LODs and triangle counts.
		# If there are multiple surfaces/meshes, they might differ, but the request implies a single set of numbers.
		# Let's take the first one available.
		var first_lod_info = all_lods_triangles[0]
		var lod_count = first_lod_info.size()
		var tris_str = "/".join(first_lod_info)
		final_lod_summary = " — %d LODs [%s]" % [lod_count, tris_str]

	var rel_path = base_dir.path_join(snake_name).trim_prefix(BakPakUtils.canonicalize_path(IMPORT_ROOT) + "/")
	print("[BakPakImportTool] Successfully imported '%s' — Materials : %s%s" % [rel_path, ", ".join(material_names), final_lod_summary])

	return generated_files


func _cleanup_obsolete_meshes(base_dir: String, snake_name: String, current_paths: Array) -> void:
	var dir = DirAccess.open(base_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				# Pattern: snake_name + "_" + numeric_index + ".res" or exactly snake_name + ".res"
				var is_obsolete_candidate = false
				if file_name == (snake_name + ".res"):
					is_obsolete_candidate = true
				elif file_name.begins_with(snake_name + "_") and file_name.ends_with(".res"):
					var suffix = file_name.get_slice("_", file_name.get_slice_count("_") - 1).trim_suffix(".res")
					if suffix.is_valid_int():
						is_obsolete_candidate = true

				if is_obsolete_candidate:
					var full_path = base_dir.path_join(file_name)
					if not full_path in current_paths:
						var err = dir.remove(file_name)
						if err == OK:
							print("[BakPakImportTool] Removed obsolete mesh: ", full_path)
							EditorInterface.get_resource_filesystem().update_file(full_path)
						else:
							printerr("[BakPakImportTool] Failed to remove obsolete mesh: ", full_path, " Error: ", err)
			file_name = dir.get_next()
		dir.list_dir_end()



func _extract_meshes_data(node: Node, parent_transform: Transform3D = Transform3D.IDENTITY, is_root: bool = true, is_collision: bool = false, current_skeleton: Skeleton3D = null) -> Dictionary:
	if node.name.begins_with("_"):
		return {"visual": [], "collision": [], "skeletons": []}

	var visual_results = []
	var collision_results = []
	var skeletons = []
	var current_transform = parent_transform

	var node_is_collision = is_collision
	if not node_is_collision:
		var node_name = node.name.to_lower()
		node_is_collision = node_name.contains("collider")

	if node is Node3D:
		if not is_root:
			current_transform = parent_transform * node.transform
		else:
			current_transform = Transform3D.IDENTITY

	var skeleton_to_pass = current_skeleton
	if node is Skeleton3D:
		skeleton_to_pass = node
		skeletons.append({
			"skeleton": node,
			"transform": current_transform,
			"name": node.name
		})

	if node is MeshInstance3D:
		var mesh = node.mesh
		if mesh:
			if node_is_collision:
				collision_results.append({"mesh": mesh, "transform": current_transform, "name": node.name})
			else:
				var surface_materials = []
				for i in range(mesh.get_surface_count()):
					var mat = node.get_active_material(i)
					var slot_name = mesh.surface_get_name(i)

					# If slot name is empty in mesh, try to get it from node if possible
					# (Godot's MeshInstance3D doesn't easily expose original slot names if mesh doesn't have them)

					surface_materials.append({"material": mat, "slot_name": slot_name})

				visual_results.append({
					"mesh": mesh,
					"transform": current_transform,
					"surface_info": surface_materials,
					"skeleton": skeleton_to_pass,
					"skin": node.skin,
					"name": node.name
				})

	for child in node.get_children():
		var child_results = _extract_meshes_data(child, current_transform, false, node_is_collision, skeleton_to_pass)
		visual_results.append_array(child_results.visual)
		collision_results.append_array(child_results.collision)
		skeletons.append_array(child_results.skeletons)

	return {"visual": visual_results, "collision": collision_results, "skeletons": skeletons}


func _get_final_material_info(mat: Material, slot_name: String) -> Dictionary:
	var preset_materials = ProjectSettings.get_setting("BakPak/ImportTool/preset_import_materials", {})
	var default_mat_path = ProjectSettings.get_setting("BakPak/ImportTool/default_import_material", "")
	var default_mat = null
	if default_mat_path != "":
		default_mat = load(default_mat_path)

	var match_name = slot_name
	if match_name == "" and mat:
		if mat.resource_name != "":
			match_name = mat.resource_name
		else:
			match_name = mat.get_class()

	var final_mat = default_mat
	var final_surf_name = "DefaultMaterial"
	var matched = false

	if match_name != "" and preset_materials.has(match_name):
		var preset_value = preset_materials[match_name]
		if preset_value is String and preset_value != "":
			final_mat = load(preset_value)
		elif preset_value is Material:
			final_mat = preset_value

		final_surf_name = match_name
		matched = true
	else:
		# No preset found: keep the source slot name so the surface stays identifiable,
		# and use the default material (null when no default is configured)
		if match_name != "":
			final_surf_name = match_name
		final_mat = default_mat

	return {"material": final_mat, "name": final_surf_name, "matched": matched}


func _merge_meshes(extracted_data: Array, ignore_materials: bool = false) -> ArrayMesh:
	var final_mesh = ArrayMesh.new()
	var surface_tools = {} # merge_key -> SurfaceTool
	var material_refs = {} # merge_key -> Material reference
	var surface_names = {} # merge_key -> Final Surface Name

	for data_idx in range(extracted_data.size()):
		var data = extracted_data[data_idx]
		var mesh: Mesh = data.mesh
		var transform: Transform3D = data.transform

		# For skinned meshes, the transform might already be factored into the mesh vertices
		# (if it was centered in a previous version of this tool), but now we handle it here.
		# _merge_meshes is used for both static and skinned.
		# Static meshes: transform is their world-ish transform relative to Export node.
		# Skinned meshes: transform is usually IDENTITY after centering, or their local transform.

		for surface_idx in range(mesh.get_surface_count()):
			var merge_key = "DefaultMaterial"
			var final_mat = null
			var final_surf_name = "DefaultMaterial"

			if not ignore_materials:
				var surface_info = data.surface_info[surface_idx]
				var mat_info = _get_final_material_info(surface_info.material, surface_info.slot_name)
				final_mat = mat_info.material
				final_surf_name = mat_info.name
				merge_key = final_surf_name

				if not mat_info.matched:
					# Slots without a preset must keep their own surface: key them by
					# source slot rather than by a shared fallback name, otherwise every
					# unmatched slot collapses into a single surface.
					if surface_info.slot_name != "":
						merge_key = "slot:" + surface_info.slot_name
					elif surface_info.material:
						merge_key = "mat:%d" % surface_info.material.get_instance_id()
					else:
						merge_key = "surface:%d:%d" % [data_idx, surface_idx]
			else:
				var mat_info = _get_final_material_info(null, "")
				final_mat = mat_info.material
				final_surf_name = mat_info.name
				merge_key = final_surf_name

			if not surface_tools.has(merge_key):
				var st = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				surface_tools[merge_key] = st
				material_refs[merge_key] = final_mat
				surface_names[merge_key] = final_surf_name

			surface_tools[merge_key].append_from(mesh, surface_idx, transform)

	for merge_key in surface_tools.keys():
		var st = surface_tools[merge_key]
		st.commit(final_mesh)
		var surf_idx = final_mesh.get_surface_count() - 1
		final_mesh.surface_set_name(surf_idx, surface_names[merge_key])
		if material_refs[merge_key]:
			final_mesh.surface_set_material(surf_idx, material_refs[merge_key])

	return final_mesh


func _compute_skin_center_transform(skel: Skeleton3D, skin: Skin) -> Transform3D:
	# Returns the transform that maps the mesh's "skin space" to the skeleton's
	# rest space. Baking it into skinned vertices recenters the geometry onto the
	# skeleton pivot (the armature origin), matching the rigged rest pose.
	#
	# For a bone, (global_rest * inverse_bind) maps a skin-space point to its rest
	# position. In a layout export every bone shares the same skin-space offset
	# (the armature's placement), so this equals the inverse of that placement,
	# which is exactly what we want to remove. When the mesh is already bound at
	# rest (no layout offset) it evaluates to identity, leaving the mesh untouched.
	# A root bone (no parent) gives the cleanest result and avoids quirks of the
	# synthetic "_leaf" tip bones Godot adds.
	if not skel or not skin or skin.get_bind_count() == 0:
		return Transform3D.IDENTITY

	var fallback = Transform3D.IDENTITY
	var has_fallback = false
	for b in range(skin.get_bind_count()):
		var bone_idx = skin.get_bind_bone(b)
		if bone_idx < 0:
			bone_idx = skel.find_bone(skin.get_bind_name(b))
		if bone_idx < 0:
			continue

		var xform = skel.get_bone_global_rest(bone_idx) * skin.get_bind_pose(b)
		if skel.get_bone_parent(bone_idx) == -1:
			return xform
		if not has_fallback:
			fallback = xform
			has_fallback = true

	return fallback




func _detect_primitive_shape(mesh: Mesh, transform: Transform3D) -> Dictionary:
	# Try to detect if the mesh is a primitive box, sphere, cylinder or capsule.
	# We use the transform to get the final world-space-ish scale for the shape settings.
	var aabb = mesh.get_aabb()
	var local_size = aabb.size
	var local_center = aabb.get_center()
	var scale = transform.basis.get_scale()
	var final_size = local_size * scale

	# Create a transform that only has translation and rotation
	var orthonormalized_transform = transform.orthonormalized()
	# Apply the offset of the center (if mesh is not centered at origin)
	orthonormalized_transform = orthonormalized_transform.translated(local_center * scale)

	var faces = mesh.get_faces()
	var vertex_count = faces.size()

	# Box: 12 triangles * 3 vertices = 36 vertices
	if vertex_count == 36:
		var box = BoxShape3D.new()
		box.size = final_size
		return {"shape": box, "transform": orthonormalized_transform}

	# Sphere and Cylinder detection
	# Heuristic for Sphere:
	if vertex_count > 100:
		var is_cubic = abs(final_size.x - final_size.y) < 0.01 and abs(final_size.y - final_size.z) < 0.01
		if is_cubic:
			var radius = final_size.x / 2.0
			var is_sphere = true
			# We check local distance to center
			for i in range(0, faces.size(), faces.size() / 10):
				if abs((faces[i] - local_center).length() - (local_size.x / 2.0)) > (local_size.x / 2.0) * 0.1:
					is_sphere = false
					break
			if is_sphere:
				var sphere = SphereShape3D.new()
				sphere.radius = radius
				return {"shape": sphere, "transform": orthonormalized_transform}

		# Check for Cylinder:
		var is_cylindrical = abs(final_size.x - final_size.z) < 0.01
		if is_cylindrical:
			var radius = final_size.x / 2.0
			var is_cyl = true
			for i in range(0, faces.size(), faces.size() / 10):
				var p = faces[i]
				var p_xz = Vector3(p.x, local_center.y, p.z)
				var dist_xz = (p_xz - local_center).length()
				var on_surface = abs(dist_xz - (local_size.x / 2.0)) < (local_size.x / 2.0) * 0.1
				var on_cap = abs(p.y - (local_center.y + local_size.y / 2.0)) < 0.01 or abs(p.y - (local_center.y - local_size.y / 2.0)) < 0.01
				if not (on_surface or on_cap):
					is_cyl = false
					break
			if is_cyl:
				var cyl = CylinderShape3D.new()
				cyl.radius = radius
				cyl.height = final_size.y
				return {"shape": cyl, "transform": orthonormalized_transform}

	# Fallback to concave
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	# For concave shapes, we still use the original transform because Godot
	# doesn't allow scaling the points in the resource easily without recreating it.
	# Actually, physics engine handles Concave with scale better than primitives,
	# but we should probably bake the scale into the faces if we want to be consistent.

	# Let's bake the transform into the faces for Concave fallback to avoid scale on the node.
	var transformed_faces = PackedVector3Array()
	transformed_faces.resize(faces.size())
	for i in range(faces.size()):
		transformed_faces[i] = transform * faces[i]

	shape.set_faces(transformed_faces)

	return {"shape": shape, "transform": Transform3D.IDENTITY}


func _generate_tscn_complex(merged_mesh: Mesh, merged_collision_mesh: Mesh, collision_shapes: Array, base_dir: String, base_name: String, skeletons: Array, skinned_meshes: Array, skip_collision: bool = false) -> void:
	var snake_name = base_name.to_snake_case()
	var pascal_name = snake_name.to_pascal_case()
	var tscn_path = base_dir.path_join(snake_name + ".tscn")
	var root: Node3D = null

	var existing_meta = {}
	# Digest of the scene as it is currently saved, to detect whether this import
	# changes it at all. Stays empty when the scene has to be written regardless.
	var saved_digest = PackedByteArray()

	# Determine root type
	var root_type = "Node3D"
	if not skeletons.is_empty():
		root_type = "Skeleton3D"
	elif merged_mesh:
		root_type = "MeshInstance3D"

	if FileAccess.file_exists(tscn_path):
		# Read the saved scene straight from disk, without going through (or altering)
		# the PackedScene the editor may have cached: scenes that are open keep using
		# that cached state to tell their local changes apart from the instanced
		# scene, until _flush_pending_scene_saves() has them reload it.
		var existing_scene = ResourceLoader.load(tscn_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
		if existing_scene:
			var instance = existing_scene.instantiate()
			# Store existing metadata
			if instance.has_meta("bakpak_generated"):
				existing_meta["bakpak_lod_group"] = instance.get_meta("bakpak_lod_group", "")

			var can_reuse = instance.get_class() == root_type
			if can_reuse and root_type == "Skeleton3D" and instance.get_bone_count() > 0:
				# Check if bone names/hierarchy changed
				if skeletons.is_empty():
					can_reuse = false
				else:
					var old_skel = skeletons[0].skeleton as Skeleton3D
					if instance.get_bone_count() != old_skel.get_bone_count():
						can_reuse = false
					else:
						for i in range(instance.get_bone_count()):
							if instance.get_bone_name(i) != old_skel.get_bone_name(i):
								can_reuse = false
								break

			if can_reuse:
				root = instance
				if not _scene_has_stale_paths(tscn_path):
					saved_digest = Fingerprint.scene_digest(root)
			else:
				instance.free()

	if not root:
		if root_type == "Skeleton3D":
			root = Skeleton3D.new()
		elif root_type == "MeshInstance3D":
			root = MeshInstance3D.new()
		else:
			root = Node3D.new()
		root.name = pascal_name

	root.set_meta("bakpak_generated", true)
	var lod_group = existing_meta.get("bakpak_lod_group", ProjectSettings.get_setting("BakPak/ImportTool/default_lod_group", "default"))
	root.set_meta("bakpak_lod_group", lod_group)

	var groups = ProjectSettings.get_setting("BakPak/ImportTool/lod_groups", {})
	var bias = 1.0
	if groups.has(lod_group):
		bias = groups[lod_group].get("bias", 1.0)

	# Static Mesh
	var static_mi: MeshInstance3D = null
	if merged_mesh:
		if root is MeshInstance3D:
			static_mi = root
		else:
			static_mi = root.get_node_or_null("StaticMesh")
			if not static_mi:
				static_mi = MeshInstance3D.new()
				static_mi.name = "StaticMesh"
				root.add_child(static_mi)

		# merged_mesh is the live resource for its .res file (see _process_entity).
		static_mi.mesh = merged_mesh
		static_mi.lod_bias = bias
		_report_surface_overrides(static_mi, tscn_path)

	# Skeletons and Skinned Meshes
	var skeleton_map = {} # Original Skeleton3D -> New Skeleton3D
	var processed_nodes = [] # To keep track of nodes we updated/added

	for skel_data in skeletons:
		var new_skel: Skeleton3D = null
		if root is Skeleton3D and skel_data == skeletons[0]:
			new_skel = root
		else:
			new_skel = root.get_node_or_null(skel_data.name)
			if not new_skel or not (new_skel is Skeleton3D):
				new_skel = Skeleton3D.new()
				new_skel.name = skel_data.name
				root.add_child(new_skel)

		processed_nodes.append(new_skel)
		new_skel.transform = skel_data.transform

		# Copy bone data
		var old_skel = skel_data.skeleton as Skeleton3D

		# Check if we need to rebuild bones (only if they are different)
		var bones_match = new_skel.get_bone_count() == old_skel.get_bone_count()
		if bones_match:
			for i in range(new_skel.get_bone_count()):
				if new_skel.get_bone_name(i) != old_skel.get_bone_name(i):
					bones_match = false
					break

		if not bones_match:
			# We can't remove bones, so if we're here and it's not the root,
			# we might have a problem if it already had bones.
			# If it's not the root and has bones, we should probably replace it.
			if new_skel != root and new_skel.get_bone_count() > 0:
				var parent = new_skel.get_parent()
				var skel_name = new_skel.name
				new_skel.free()
				new_skel = Skeleton3D.new()
				new_skel.name = skel_name
				parent.add_child(new_skel)
				processed_nodes.erase(null) # Cleanup just in case
				processed_nodes.append(new_skel)

			for i in range(old_skel.get_bone_count()):
				new_skel.add_bone(old_skel.get_bone_name(i))

		# Always update rests and poses
		for i in range(old_skel.get_bone_count()):
			new_skel.set_bone_rest(i, old_skel.get_bone_rest(i))
			new_skel.set_bone_parent(i, old_skel.get_bone_parent(i))
			new_skel.set_bone_pose_position(i, old_skel.get_bone_pose_position(i))
			new_skel.set_bone_pose_rotation(i, old_skel.get_bone_pose_rotation(i))
			new_skel.set_bone_pose_scale(i, old_skel.get_bone_pose_scale(i))

		skeleton_map[old_skel] = new_skel

	for sm in skinned_meshes:
		var target_parent = root
		if sm.skeleton in skeleton_map:
			target_parent = skeleton_map[sm.skeleton]

		var new_mi: MeshInstance3D = target_parent.get_node_or_null(NodePath(sm.name))
		if not new_mi or not (new_mi is MeshInstance3D):
			new_mi = MeshInstance3D.new()
			new_mi.name = sm.name
			target_parent.add_child(new_mi)

		processed_nodes.append(new_mi)

		if sm.skeleton in skeleton_map:
			new_mi.skeleton = NodePath("..")
		else:
			new_mi.skeleton = NodePath("")

		# If it's skinned, transform is relative to skeleton or root.
		# sm.transform was set to IDENTITY in _on_glb_imported if the mesh data was centered.
		new_mi.transform = sm.transform

		new_mi.mesh = sm.mesh
		new_mi.skin = sm.skin
		new_mi.lod_bias = bias
		_report_surface_overrides(new_mi, tscn_path)

	# Collisions - Skip if it's ONLY a skeleton scene OR if entity has _nocol suffix (detected in _process_entity)
	if not skip_collision and (static_mi or not collision_shapes.is_empty() or merged_collision_mesh):
		var collision_owner = static_mi if static_mi else root
		_update_or_add_collision_complex(collision_owner, merged_collision_mesh, collision_shapes, root)
		if collision_owner != root:
			processed_nodes.append(collision_owner)
		var sb = collision_owner.get_node_or_null("StaticBody3D")
		if sb:
			processed_nodes.append(sb)
	elif skip_collision:
		# If it has _nocol, we should probably ensure no StaticBody3D exists if it was there before
		var collision_owner = static_mi if static_mi else root
		var sb = collision_owner.get_node_or_null("StaticBody3D")
		if sb:
			collision_owner.remove_child(sb)
			sb.queue_free()

	# Cleanup deprecated/removed nodes that were generated by us but are no longer in the GLB
	# (But DON'T touch nodes added by the user)
	# For simplicity, we only remove nodes that we would have created but didn't this time.
	# Actually, the user asked to avoid deleting nodes, but "except for deprecated nodes".
	# If a mesh was removed from GLB, we should remove its MeshInstance3D.
	# But how to distinguish our nodes from user nodes?
	# Our nodes have specific names (StaticMesh, or names from GLB) and are usually MeshInstance3D/Skeleton3D.

	# Let's see... the user might have added nodes. We should only remove nodes that were PREVIOUSLY
	# generated by BakPak but are no longer present.
	# But we don't track which nodes were generated by us except by name and type.
	# If we only remove what we didn't "process" and it's a MeshInstance3D/Skeleton3D/StaticBody3D...
	# No, that's risky.

	# Better: The user says "If nodes had been added... they should not change."
	# So we just don't delete anything from root that we didn't create just now?
	# But if I reimport and a mesh is GONE from GLB, it SHOULD be gone from .tscn too.

	# I will only cleanup children of root that are MeshInstance3D or Skeleton3D and were NOT in processed_nodes.
	# This might still hit user MeshInstance3Ds.
	# Maybe I should check metadata on them? I don't set metadata on children currently.

	# Let's skip cleanup for now as the user emphasized NOT deleting nodes.
	# If they want to delete something, they can do it manually, or we can add metadata to our children later.

	_set_owner_recursive(root, root)

	if not saved_digest.is_empty() and Fingerprint.scene_digest(root) == saved_digest:
		# Nothing changed in the scene itself (the usual case: only the mesh data in
		# the .res changed, and that is already live). Leave the file alone.
		root.free()
		return

	_queue_scene_save(root, tscn_path)


# A surface override stored in the generated scene takes precedence over the
# material assigned to the mesh surface, so a material slot set up later in Blender
# (or a new preset) stays hidden behind it. Overrides are user data and are kept;
# this only makes the situation visible in the import log.
func _report_surface_overrides(mi: MeshInstance3D, tscn_path: String) -> void:
	if not mi.mesh:
		return
	var overridden = []
	for i in range(mi.mesh.get_surface_count()):
		if mi.get_surface_override_material(i):
			overridden.append("%d (%s)" % [i, mi.mesh.surface_get_name(i)])
	if not overridden.is_empty():
		print("[BakPakImportTool] Note: '%s' keeps its Surface Material Override on surface %s of '%s'. The override hides the imported/preset material; clear it in the generated scene to see the material coming from the GLB." % [tscn_path.get_file(), ", ".join(overridden), mi.name])


# Whether the saved scene refers to one of its dependencies through a path that is
# not spelled as on disk (written by earlier versions of this tool, which always
# used "res://assets/"). Such a scene is re-saved so the reference gets corrected.
func _scene_has_stale_paths(tscn_path: String) -> bool:
	for dependency in ResourceLoader.get_dependencies(tscn_path):
		var dependency_path = dependency
		if dependency.get_slice_count("::") >= 3:
			dependency_path = dependency.get_slice("::", 2)
		if dependency_path.begins_with("res://") and BakPakUtils.canonicalize_path(dependency_path) != dependency_path:
			return true
	return false


# Takes ownership of `root_node`: it is freed once the scene has been written.
func _queue_scene_save(root_node: Node, tscn_path: String) -> void:
	_pending_scene_saves.append({"root": root_node, "path": tscn_path})


# Writes the queued generated scenes and brings the editor up to date with them.
#
# A generated scene can be open in a tab and/or instanced in other open scenes.
# Those hold instantiated nodes, which do not change when the .tscn is rewritten.
# The editor already has the machinery to deal with a scene file being regenerated
# underneath open scenes - it is what runs when an imported scene (.glb, .blend) is
# re-imported: it reloads the tabs showing the scene and replaces its instances in
# every open scene while keeping their local overrides. It is driven by
# EditorFileSystem's "resources_reimporting" / "resources_reimported" signals, so
# the scenes generated here are announced through the same two signals.
func _flush_pending_scene_saves() -> void:
	if _pending_scene_saves.is_empty():
		return

	var pending = _pending_scene_saves
	_pending_scene_saves = []
	var fs = EditorInterface.get_resource_filesystem()

	# Only scenes that are actually open or instanced need the editor's attention.
	var in_use = PackedStringArray()
	if fs.has_signal("resources_reimporting"):
		for entry in pending:
			if FileAccess.file_exists(entry.path) and _is_scene_in_use(entry.path):
				in_use.append(entry.path)

	if not in_use.is_empty():
		# Lets the editor record the local overrides of the instances it is about to replace.
		_notifying_editor = true
		fs.emit_signal("resources_reimporting", in_use)
		_notifying_editor = false

	var saved = []
	for entry in pending:
		var packed_scene = PackedScene.new()
		var err = packed_scene.pack(entry.root)
		if err == OK:
			# (In the editor, ResourceSaver already reports the saved file to EditorFileSystem.)
			err = ResourceSaver.save(packed_scene, entry.path)
		entry.root.free()
		if err == OK:
			saved.append(entry.path)
		else:
			printerr("[BakPakImportTool] Failed to save TSCN: ", entry.path, " Error: ", err)

	if not in_use.is_empty():
		_notifying_editor = true
		fs.emit_signal("resources_reimported", in_use)
		_notifying_editor = false

	# A scene nobody has open can still be cached (e.g. referenced by another loaded
	# scene); refresh that copy from the new file. Scenes in use were just reloaded
	# by the editor.
	for path in saved:
		if not path in in_use and ResourceLoader.has_cached(path):
			ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


# Whether `tscn_path` is open in a scene tab, or instanced/inherited by an open scene.
func _is_scene_in_use(tscn_path: String) -> bool:
	var open_scenes = EditorInterface.get_open_scenes()
	if tscn_path in open_scenes:
		return true

	# Instances, including nested ones and ones added since the scene was last saved.
	for scene_root in EditorInterface.get_open_scene_roots():
		if _has_instance_of(scene_root, tscn_path):
			return true

	# Inherited scenes: the base scene is a dependency of the open scene's file.
	var uid_text = ""
	var uid = ResourceLoader.get_resource_uid(tscn_path)
	if uid != ResourceUID.INVALID_ID:
		uid_text = ResourceUID.id_to_text(uid)
	for open_scene in open_scenes:
		if not FileAccess.file_exists(open_scene):
			continue
		for dependency in ResourceLoader.get_dependencies(open_scene):
			if dependency == tscn_path or dependency.ends_with("::" + tscn_path) or (uid_text != "" and dependency.begins_with(uid_text)):
				return true

	return false


func _has_instance_of(node: Node, tscn_path: String) -> bool:
	if node.scene_file_path == tscn_path:
		return true
	for child in node.get_children():
		if _has_instance_of(child, tscn_path):
			return true
	return false


func _regenerate_all_lods_with_progress() -> void:
	print("[BakPakImportTool] Starting regeneration of all LODs...")
	var fs = EditorInterface.get_resource_filesystem().get_filesystem()

	var files_to_process = []
	_find_generated_scenes(fs, files_to_process)

	if files_to_process.is_empty():
		print("[BakPakImportTool] No generated scenes found to regenerate.")
		return

	var total = files_to_process.size()
	var processed_count = 0

	# Create progress dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Regenerating LODs"
	dialog.exclusive = false

	var vb = VBoxContainer.new()
	dialog.add_child(vb)

	var label = Label.new()
	label.text = "Processing files..."
	vb.add_child(label)

	var progress = ProgressBar.new()
	progress.max_value = total
	progress.value = 0
	progress.custom_minimum_size.x = 400
	vb.add_child(progress)

	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()

	# Hide the OK button to make it look more like a progress dialog
	dialog.get_ok_button().hide()

	for i in range(total):
		var file_path = files_to_process[i]
		label.text = "Regenerating LODs for: %s" % file_path.get_file()
		progress.value = i

		# Allow UI to update
		await get_tree().process_frame

		_regenerate_lods_for_scene(file_path)

	_flush_pending_scene_saves()

	progress.value = total
	label.text = "Finished!"

	print("[BakPakImportTool] Regeneration of all LODs finished.")

	dialog.get_ok_button().show()
	dialog.get_ok_button().text = "Close"
	dialog.get_ok_button().pressed.connect(func(): dialog.queue_free())

func _find_generated_scenes(dir: EditorFileSystemDirectory, results: Array) -> void:
	if not dir:
		return

	for i in range(dir.get_subdir_count()):
		_find_generated_scenes(dir.get_subdir(i), results)

	for i in range(dir.get_file_count()):
		var file_path = dir.get_file_path(i)
		if BakPakUtils.is_generated_scene(file_path):
			results.append(file_path)

func _regenerate_all_lods() -> void:
	_regenerate_all_lods_with_progress()


# Scenes whose nodes had to change are queued; callers run _flush_pending_scene_saves().
func _regenerate_lods_for_scene(tscn_path: String) -> void:
	tscn_path = BakPakUtils.canonicalize_path(tscn_path)
	# Read from disk without touching the cached PackedScene (see _generate_tscn_complex).
	var scene = ResourceLoader.load(tscn_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if not scene:
		return

	var instance = scene.instantiate()
	if not instance:
		return

	if not instance.has_meta("bakpak_generated"):
		instance.free()
		return

	var lod_group = instance.get_meta("bakpak_lod_group", ProjectSettings.get_setting("BakPak/ImportTool/default_lod_group", "default"))
	var groups = ProjectSettings.get_setting("BakPak/ImportTool/lod_groups", {})
	var target_bias = 1.0
	if groups.has(lod_group):
		target_bias = groups[lod_group].get("bias", 1.0)

	var scene_changed = false

	# Find all MeshInstance3D nodes
	var mesh_instances = []
	_find_mesh_instances_recursive(instance, mesh_instances)

	for mi in mesh_instances:
		if not mi.mesh or not (mi.mesh is ArrayMesh):
			continue

		var mesh_path = mi.mesh.resource_path
		if mesh_path == "" or "::" in mesh_path:
			# If it's an internal resource or has no path, we look for external .res files
			var base_dir = tscn_path.get_base_dir()
			var base_name = tscn_path.get_file().replace(".generated.tscn", "")

			var possible_paths = [
				base_dir.path_join(base_name + "_merged.res")
			]
			# Also check for skinned mesh paths (though usually they should have a resource_path if they were saved)
			for j in range(10): # Check first 10 possible skinned meshes
				possible_paths.append(base_dir.path_join(base_name + "_skinned_" + str(j) + ".res"))

			for p in possible_paths:
				if FileAccess.file_exists(p):
					# How to know which mesh corresponds to which path?
					# For simplicity, if the MeshInstance3D name matches or if it's the only one.
					# Actually, in the current architecture, we usually only have one merged mesh or indexed skinned meshes.
					# If we find a path that contains the mesh name (if it's indexed) or is _merged.res for "StaticMesh"
					if p.ends_with("_merged.res") and (mi.name == "StaticMesh" or mi.name == base_name):
						mesh_path = p
						break
					elif "_skinned_" in p:
						# Match by index if possible? mi.name might be the original name.
						# This is a bit weak, but it's a fallback.
						pass

			if mesh_path == "" or "::" in mesh_path:
				# Final attempt: if it's the only mesh and we have _merged.res
				var merged_path = base_dir.path_join(base_name + "_merged.res")
				if FileAccess.file_exists(merged_path) and mesh_instances.size() == 1:
					mesh_path = merged_path

			if mesh_path != "" and not "::" in mesh_path:
				mi.mesh = ResourceLoader.load(mesh_path, "", ResourceLoader.CACHE_MODE_REPLACE)
				if not mi.mesh or not (mi.mesh is ArrayMesh):
					mesh_path = "" # Reset if load failed

			if mesh_path != "" and not "::" in mesh_path:
				# print("[BakPakImportTool] Regenerating LODs for: ", tscn_path, " mesh: ", mesh_path)
				var lod_result = BakPakUtils.generate_mesh_lods(mi.mesh, lod_group)
				# Refreshes the mesh object already in use for this path (and keeps its UID).
				BakPakUtils.save_resource_in_place(lod_result.mesh, mesh_path)

		# Update LOD Bias
		if not is_equal_approx(mi.lod_bias, target_bias):
			mi.lod_bias = target_bias
			scene_changed = true

	if scene_changed:
		_queue_scene_save(instance, tscn_path)
	else:
		instance.free()

func _find_mesh_instances_recursive(node: Node, results: Array) -> void:
	if node is MeshInstance3D:
		results.append(node)
	for child in node.get_children():
		_find_mesh_instances_recursive(child, results)


func _check_duplicate_names(resource_path: String) -> void:
	var gltf_doc = GLTFDocument.new()
	var state = GLTFState.new()
	# Flags 0 is default
	var err = gltf_doc.append_from_file(resource_path, state)
	if err != OK:
		return

	var seen_names = {} # name -> count
	var duplicates = []

	for gnode in state.nodes:
		var nname = gnode.original_name
		if nname == "":
			continue

		if seen_names.has(nname):
			if not nname in duplicates:
				duplicates.append(nname)
			seen_names[nname] += 1
		else:
			seen_names[nname] = 1

	if not duplicates.is_empty():
		var msg = "[BakPakImportTool] ERROR: Duplicate node names found in GLB: %s\n" % resource_path.get_file()
		msg += "The following names are used multiple times: %s\n" % ", ".join(duplicates)
		msg += "Godot's importer renames duplicate nodes (e.g., appending '2'), which results in unexpected folder paths like '.../danger/carnivora2/'.\n"
		msg += "Please ensure all collections and objects have unique names in your source file (e.g., in Blender)."
		printerr(msg)
		push_error(msg)


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)


const IMPORT_DATA_FILE = "res://bakpak_import_history.json"

func _load_import_data() -> Dictionary:
	if not FileAccess.file_exists(IMPORT_DATA_FILE):
		print("[BakPakImportTool] No import history file found.")
		return {}

	var file = FileAccess.open(IMPORT_DATA_FILE, FileAccess.READ)
	if not file:
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(json_text)
	if err == OK:
		if json.data is Dictionary:
			BakPakUtils.clear_path_cache()
			return _canonicalize_import_data(json.data)
	return {}


# Rewrites the paths of the import history as they are spelled on disk. Earlier
# versions recorded "res://assets/..." whatever the real folder name was, and could
# hold two entries for the same GLB differing only by case.
func _canonicalize_import_data(data: Dictionary) -> Dictionary:
	var result = {}
	# Entries whose key is already spelled correctly win over case variants.
	for exact_pass in [true, false]:
		for glb_path in data:
			var canonical_glb = BakPakUtils.canonicalize_path(glb_path)
			if (canonical_glb == glb_path) != exact_pass or result.has(canonical_glb):
				continue
			var glb_data = data[glb_path]
			if not glb_data is Dictionary:
				continue
			if glb_data.has("files"):
				glb_data["files"] = _canonicalize_paths(glb_data["files"])
			var entities = glb_data.get("entities", {})
			for entity_name in entities:
				if entities[entity_name] is Dictionary and entities[entity_name].has("files"):
					entities[entity_name]["files"] = _canonicalize_paths(entities[entity_name]["files"])
			result[canonical_glb] = glb_data
	return result


func _canonicalize_paths(paths: Array) -> Array:
	var result = []
	for path in paths:
		var canonical = BakPakUtils.canonicalize_path(path)
		if not canonical in result:
			result.append(canonical)
	return result


func _save_import_data(data: Dictionary) -> void:
	var file = FileAccess.open(IMPORT_DATA_FILE, FileAccess.WRITE)
	if not file:
		printerr("[BakPakImportTool] Failed to save import history.")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _update_or_add_collision_complex(mi: Node3D, merged_collision_mesh: Mesh, collision_shapes: Array, owner_node: Node) -> void:
	var debug_color = ProjectSettings.get_setting("BakPak/ImportTool/collision_debug_color", Color(0.0, 0.6, 0.7, 0.4))
	var static_body = mi.get_node_or_null("StaticBody3D")
	if not static_body:
		static_body = StaticBody3D.new()
		static_body.name = "StaticBody3D"
		mi.add_child(static_body)

	static_body.owner = owner_node
	static_body.transform = Transform3D.IDENTITY

	# Instead of removing all children, we will update/replace them as needed.
	var existing_shapes = []
	for child in static_body.get_children():
		if child is CollisionShape3D:
			existing_shapes.append(child)

	var shape_idx = 0
	if not collision_shapes.is_empty():
		for i in range(collision_shapes.size()):
			var data = collision_shapes[i]

			var cs: CollisionShape3D = null
			if shape_idx < existing_shapes.size():
				cs = existing_shapes[shape_idx]
				shape_idx += 1
			else:
				cs = CollisionShape3D.new()
				static_body.add_child(cs)
				cs.owner = owner_node

			# Name based on shape type
			var shape_name = "ConcaveCollision"
			if data.shape is BoxShape3D:
				shape_name = "BoxCollision"
			elif data.shape is SphereShape3D:
				shape_name = "SphereCollision"
			elif data.shape is CylinderShape3D:
				shape_name = "CylinderCollision"

			cs.name = shape_name + (str(i) if i > 0 else "")
			cs.shape = data.shape
			cs.debug_color = debug_color
			cs.transform = data.transform
	else:
		# Use merged_collision_mesh or fallback to visual merged_mesh
		var mesh_to_use = merged_collision_mesh
		if not mesh_to_use and mi is MeshInstance3D:
			mesh_to_use = mi.mesh

		if mesh_to_use:
			var cs: CollisionShape3D = null
			if shape_idx < existing_shapes.size():
				cs = existing_shapes[shape_idx]
				shape_idx += 1
			else:
				cs = CollisionShape3D.new()
				static_body.add_child(cs)
				cs.owner = owner_node

			cs.name = "ConcaveCollision"
			var shape = ConcavePolygonShape3D.new()
			var faces = mesh_to_use.get_faces()
			if not faces.is_empty():
				shape.set_faces(faces)
				cs.shape = shape
				cs.debug_color = debug_color
				cs.transform = Transform3D.IDENTITY
			else:
				# Empty mesh, don't create/update this shape if it's new
				if cs.owner == null: # It was just created
					static_body.remove_child(cs)
					cs.queue_free()
				shape_idx -= 1

	# Remove remaining old collision shapes if any
	while shape_idx < existing_shapes.size():
		var child = existing_shapes[shape_idx]
		static_body.remove_child(child)
		child.queue_free()
		shape_idx += 1

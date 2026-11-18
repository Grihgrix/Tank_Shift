@tool
extends EditorContextMenuPlugin

var plugin: EditorPlugin

func _popup_menu(paths: PackedStringArray):
	var has_bakpak_tscn = false
	var has_glb = false
	for path in paths:
		if path.ends_with(".tscn"):
			# Optimization: don't load everything if it doesn't even have "bakpak" in meta or similar?
			# Actually, we have to check metadata.
			var scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
			if scene:
				var state = scene.get_state()
				# Checking metadata without instantiating if possible?
				# PackedScene doesn't expose metadata easily without instantiating.
				var inst = scene.instantiate()
				if inst and inst.has_meta("bakpak_generated"):
					has_bakpak_tscn = true
					inst.free()
					break
				if inst:
					inst.free()
		elif path.ends_with(".glb") or path.ends_with(".gltf"):
			has_glb = true

	if has_bakpak_tscn:
		add_context_menu_item("BakPak: Regenerate LODs", _on_regenerate_lods)
		add_context_menu_item("BakPak: Re-import from Source GLB", _on_reimport_from_glb)

	if has_glb:
		add_context_menu_item("BakPak: Force Re-import All", _on_force_reimport_glb)

func _on_regenerate_lods(paths: PackedStringArray):
	if plugin and plugin.has_method("_on_context_regenerate_lods"):
		plugin.call("_on_context_regenerate_lods", paths)

func _on_reimport_from_glb(paths: PackedStringArray):
	if plugin and plugin.has_method("_on_context_reimport_from_glb"):
		plugin.call("_on_context_reimport_from_glb", paths)

func _on_force_reimport_glb(paths: PackedStringArray):
	if plugin and plugin.has_method("_on_context_force_reimport_glb"):
		plugin.call("_on_context_force_reimport_glb", paths)

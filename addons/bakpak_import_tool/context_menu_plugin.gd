@tool
extends EditorContextMenuPlugin

var plugin: EditorPlugin

func _popup_menu(paths: PackedStringArray):
	var has_bakpak_tscn = false
	var has_glb = false
	for path in paths:
		if path.ends_with(".tscn"):
			# Read-only check. It must not reload the scene into the cache
			# (CACHE_MODE_REPLACE): that overwrites, on every right-click, the scene
			# state open scenes use to track their instances of it.
			if BakPakUtils.is_generated_scene(path):
				has_bakpak_tscn = true
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

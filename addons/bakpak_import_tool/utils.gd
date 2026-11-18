@tool
class_name BakPakUtils
extends Object

static func generate_mesh_lods(mesh: ArrayMesh, lod_group_name: String = "") -> Dictionary:
	if lod_group_name == "":
		lod_group_name = ProjectSettings.get_setting("BakPak/ImportTool/default_lod_group", "default")

	var groups = ProjectSettings.get_setting("BakPak/ImportTool/lod_groups", {})
	var default_name = ProjectSettings.get_setting("BakPak/ImportTool/default_lod_group", "default")
	var group_params = groups.get(lod_group_name, groups.get(default_name, {
		"normal_merge_angle": 25.0,
		"normal_split_angle": 60.0,
		"bias": 1.0
	}))

	var merge_angle = group_params.get("normal_merge_angle", 25.0)
	var split_angle = group_params.get("normal_split_angle", 60.0)

	var importer = ImporterMesh.new()
	for i in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(i)
		var name = mesh.surface_get_name(i)
		var mat = mesh.surface_get_material(i)
		var format = mesh.surface_get_format(i)

		var empty_blend_shapes: Array[Array] = []
		importer.add_surface(mesh.surface_get_primitive_type(i), arrays, empty_blend_shapes, {}, mat, name, format)

	var all_bone_transforms: Array[Transform3D] = []
	var global_max_bone_idx = -1
	for i in range(mesh.get_surface_count()):
		var format = mesh.surface_get_format(i)
		if format & Mesh.ARRAY_FORMAT_BONES:
			var arrays = mesh.surface_get_arrays(i)
			var bones = arrays[Mesh.ARRAY_BONES]
			if bones:
				for b in bones:
					if b > global_max_bone_idx:
						global_max_bone_idx = b

	if global_max_bone_idx >= 0:
		for b in range(global_max_bone_idx + 1):
			all_bone_transforms.append(Transform3D.IDENTITY)

	importer.generate_lods(merge_angle, split_angle, all_bone_transforms)

	# Collect LOD info
	var surfaces_lod_info = []
	var surface_count = importer.get_surface_count()
	for i in range(surface_count):
		var lod_count = importer.get_surface_lod_count(i)
		var base_indices = importer.get_surface_arrays(i)[Mesh.ARRAY_INDEX]
		var base_triangles = 0
		if base_indices:
			base_triangles = base_indices.size() / 3
		else:
			var verts = importer.get_surface_arrays(i)[Mesh.ARRAY_VERTEX]
			base_triangles = verts.size() / 3

		var lod_triangles_list = [base_triangles]

		for lod_idx in range(lod_count):
			var lod_indices = importer.get_surface_lod_indices(i, lod_idx)
			var lod_triangles = lod_indices.size() / 3
			lod_triangles_list.append(lod_triangles)

		surfaces_lod_info.append(lod_triangles_list)

	var new_mesh = importer.get_mesh()
	return {
		"mesh": new_mesh,
		"lod_info": surfaces_lod_info
	}

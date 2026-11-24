@tool
extends RefCounted
## Content hashing for the BakPak import pipeline.
##
## Two digests are built from the same walker:
## - entity_fingerprint(): decides whether an entity of a re-imported GLB has to be
##   processed again. It covers everything the pipeline can read from the entity's
##   node subtree, by content.
## - scene_digest(): tells whether a generated scene tree differs from the one that
##   is already saved, so unchanged .tscn files are not rewritten.
##
## Nodes and resources are hashed generically, through every property flagged for
## storage (transforms, metadata such as glTF "extras", skins, skeleton bones,
## material parameters, blend shape values...). That is the same set of properties
## Godot serializes, so data added by future importer versions is picked up without
## having to be listed here. Meshes are hashed from their actual surface arrays.

## Bump when the hashed data or the import pipeline's output changes, so that every
## entity is processed once more with the new code.
const VERSION := 2


## Fingerprint of an entity of an imported GLB scene.
## `pipeline_inputs` is extra plain data that also influences the generated files
## (project settings, resolved preset materials).
static func entity_fingerprint(root: Node, pipeline_inputs: Variant = null) -> String:
	# Nodes whose name starts with "_" are ignored by the pipeline, so they are
	# ignored here as well. Meshes, skins and materials are always hashed by
	# content, even if the importer was configured to save them to their own files.
	var state := {"memo": {}, "content_types": true, "skip_underscore": true}
	var data := [VERSION, pipeline_inputs, _node_data(root, state)]
	return "v%d:%s" % [VERSION, Marshalls.raw_to_base64(_digest(var_to_bytes(data)))]


## Digest of a scene tree as it would be saved: built-in resources by content,
## resources that live in their own file by path.
static func scene_digest(root: Node) -> PackedByteArray:
	var state := {"memo": {}, "content_types": false, "skip_underscore": false}
	return _digest(var_to_bytes(_node_data(root, state)))


static func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		ctx.update(bytes)
	return ctx.finish()


static func _node_data(node: Node, state: Dictionary) -> Array:
	var children := []
	for child in node.get_children():
		if state.skip_underscore and String(child.name).begins_with("_"):
			continue
		children.append(_node_data(child, state))
	# "name" and "scene_file_path" are not storage properties but are part of what
	# gets saved (and of what the pipeline reads), so they are added explicitly.
	return [node.get_class(), String(node.name), node.scene_file_path, _stored_properties(node, state), children]


static func _stored_properties(object: Object, state: Dictionary) -> Array:
	var data := []
	for property in object.get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		data.append(property.name)
		data.append(_value_data(object.get(property.name), state))
	return data


## Converts a value into plain data that var_to_bytes() encodes deterministically:
## objects are replaced by a digest of their content (or by their path).
static func _value_data(value: Variant, state: Dictionary) -> Variant:
	match typeof(value):
		TYPE_OBJECT:
			if not is_instance_valid(value):
				return null
			if value is Resource:
				return _resource_data(value, state)
			return ["object", value.get_class()]
		TYPE_ARRAY:
			var items := []
			for item in value:
				items.append(_value_data(item, state))
			return items
		TYPE_DICTIONARY:
			var items := []
			for key in value:
				items.append(_value_data(key, state))
				items.append(_value_data(value[key], state))
			return ["dictionary", items]
		TYPE_RID, TYPE_CALLABLE, TYPE_SIGNAL:
			# Runtime handles: different on every run, never part of the content.
			return ["handle", typeof(value)]
	return value


static func _resource_data(resource: Resource, state: Dictionary) -> Variant:
	var memo: Dictionary = state.memo
	var id := resource.get_instance_id()
	if memo.has(id):
		return memo[id]

	if not resource.is_built_in():
		var by_content: bool = state.content_types and (resource is Mesh or resource is Skin or resource is Material)
		if not by_content:
			memo[id] = ["external", resource.resource_path]
			return memo[id]

	# Guards against reference cycles; replaced by the real digest below. A mesh
	# shared by many nodes is hashed once thanks to the memo.
	memo[id] = ["cycle", resource.get_class()]
	var data: Array = _mesh_data(resource, state) if resource is Mesh else [resource.get_class(), _stored_properties(resource, state)]
	memo[id] = _digest(var_to_bytes(data))
	return memo[id]


## Meshes are hashed from the surface arrays (vertices, normals, tangents, colors,
## UVs, custom channels, bones, weights, indices), blend shapes, surface names,
## formats, primitive types and materials.
static func _mesh_data(mesh: Mesh, state: Dictionary) -> Array:
	var data := [mesh.get_class(), mesh.resource_name, mesh.lightmap_size_hint]

	for meta_name in mesh.get_meta_list():
		data.append(["meta", String(meta_name), _value_data(mesh.get_meta(meta_name), state)])

	var array_mesh := mesh as ArrayMesh
	var has_blend_shapes := false
	if array_mesh:
		var blend_shape_names := []
		for i in array_mesh.get_blend_shape_count():
			blend_shape_names.append(String(array_mesh.get_blend_shape_name(i)))
		has_blend_shapes = not blend_shape_names.is_empty()
		data.append([blend_shape_names, array_mesh.blend_shape_mode, array_mesh.custom_aabb])
	else:
		# Procedural meshes are defined by their parameters.
		data.append(_stored_properties(mesh, state))

	for i in mesh.get_surface_count():
		var surface := [_digest(var_to_bytes(mesh.surface_get_arrays(i)))]
		if array_mesh:
			surface.append(array_mesh.surface_get_name(i))
			surface.append(array_mesh.surface_get_primitive_type(i))
			surface.append(array_mesh.surface_get_format(i))
		if has_blend_shapes:
			surface.append(_digest(var_to_bytes(mesh.surface_get_blend_shape_arrays(i))))
		surface.append(_value_data(mesh.surface_get_material(i), state))
		data.append(surface)

	return data

class_name GrassSpawner
extends CollisionShape3D

@export var grass_scene:PackedScene
@export var grass_count:int = 10
@export var grass_scale_range:Vector2 = Vector2(0.5, 1.5)
@export var grass_material:ShaderMaterial

@onready var multi_mesh: MultiMeshInstance3D = $MultiMeshInstance3D

func _ready() -> void:
	if grass_material.get_shader_parameter("rand_seed") == 0:
		grass_material.set_shader_parameter("rand_seed", randf_range(-1000.0, 1000.0))

	multi_mesh.multimesh = multi_mesh.multimesh.duplicate()
	multi_mesh.multimesh.instance_count = grass_count
	for i in range(grass_count):
		var random_position = Vector3(
			randf_range(-1.0, 1.0),
			0.0,
			randf_range(-1.0, 1.0)
		)
		random_position *= (shape as BoxShape3D).size / 2
		var random_scale = Vector3.ONE * randf_range(grass_scale_range.x, grass_scale_range.y)
		var _basis = Basis().scaled(random_scale)
		multi_mesh.multimesh.set_instance_transform(i, Transform3D(_basis, random_position))

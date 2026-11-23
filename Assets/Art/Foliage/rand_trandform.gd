extends Node3D

@export var rand_scale_range: Vector2 = Vector2(0.8, 1.2)

func _ready() -> void:
	rotate_y(rad_to_deg(randf_range(0, 360)))
	scale *= randf_range(rand_scale_range.x, rand_scale_range.y)
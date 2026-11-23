extends Node3D

func _ready() -> void:
	rotate_y(rad_to_deg(randf_range(0, 360)))
	scale *= randf_range(0.8, 1.2)
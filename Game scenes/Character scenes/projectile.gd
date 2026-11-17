extends RigidBody3D

@onready var collision_shape_3d = $CollisionShape3D


# Called when the node enters the scene tree for the first time.
func _ready():
	# Disable the collistion upon spawn (so it does not collide with its own character)
	collision_shape_3d.disabled = true
	
	# Wait a short while for the projectile to be away from the shooter
	await get_tree().create_timer(0.3).timeout
	# re-establish collision
	collision_shape_3d.disabled = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

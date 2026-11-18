extends RigidBody3D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Disable the collistion with characters upon spawn (so it does not collide with its own character)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(2, true)
	set_collision_mask_value(2, true)
	# Layers and mask 2 remain active so it can collide with obstacles
	
	# Wait a short while for the projectile to be away from the shooter
	await get_tree().create_timer(0.05).timeout
	# re-establish collision with characters
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

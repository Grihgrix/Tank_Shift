extends RayCast3D

# Tuto followed for this : https://www.youtube.com/watch?v=vGpFwaLUG4U

#@export var speed:int = Global.projectile_speed


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _physics_process(delta):
	# Move the projectile forward at set speed
	position += global_basis * Vector3.FORWARD * Global.projectile_speed * delta
	# Update check where the projectile is going next
	target_position = Vector3.FORWARD * Global.projectile_speed * delta
	# Ensure raycast is fully updating
	force_raycast_update()
	# Find the object with which we would collide if any
	var collider = get_collider()
	
	if is_colliding():
		# Keep the pojectile on the object colliding
		global_position = get_collision_point()
		# Stop the projectile from moving
		set_physics_process(false)
		
		# Detecti if we hit a character
		collider = get_collider()
		if collider is CharacterBody3D:
			# Implement character death
			collider.is_alive = false
	
		# Depsawn projectile if we had a collision
		despawn_projectile()


func despawn_projectile():
	queue_free()


func _on_timer_timeout():
	# At the end of the time, despawn the projectile, thus limiting the range
	despawn_projectile()

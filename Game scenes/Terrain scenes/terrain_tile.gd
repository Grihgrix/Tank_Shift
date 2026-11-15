extends Node3D

@export var tile_id:int
@export var tile_shift_requested:bool = false

var rotation_z_target:float
var tile_shift_triggered:bool = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if tile_shift_requested:
		tile_shift_target()
	
	if Global.shift_requested_on_mouse and tile_shift_triggered:
		Global.shift_requested_on_mouse = false
	elif Global.shift_requested_on_mouse and Global.current_tile_pointed_is_valid and Global.current_tile_pointed_id == tile_id:
		print("Character requested shift of tile : " + str(tile_id))
		# Calculate the rotation target for the tile we point at and enable trgger
		tile_shift_target()
	
	if tile_shift_triggered:
		# Operate tile shift
		tile_shift(delta)

func _on_area_3d_mouse_entered():
	# Identify what tile the player is pointing at so it can be shifted when requested
	Global.current_tile_pointed_id = tile_id
	Global.current_tile_pointed_is_valid = true

func _on_area_3d_mouse_exited():
	# Identify when the player is not pointing at the current tile anymore (and in case he is now on the tank, prevent from triggering the previous tile shift)
	Global.current_tile_pointed_is_valid = false


# tile_shift_target amd tile_shift had to be separated so the shift can complete withouyt the next one being triggered before
func tile_shift_target():
	# Stops any attempts at relaunching the shift
	tile_shift_requested = false
	Global.shift_requested_on_mouse = false
	# Set the next rotation (after shift end)
	rotation_z_target = rotation.z + PI
	#print("rotation_z_target = " + str(rotation_z_target))
	# Enable launch of the shift
	tile_shift_triggered = true
	
	 # Immobilize the character currently on the tile
	for child in get_children():
		if child is CharacterBody3D:
			child.not_in_shift = 0 # This disables movement forward and backward


func tile_shift(delta):
	# Operate rile shift
	if abs(rotation.z - rotation_z_target) > 0.3 and tile_shift_triggered:
		# Make the shift happen at the set speed
		position.y = 0 # ensures we remain on the tile side we are supposed to be on
		rotation.z = move_toward(rotation.z, rotation_z_target, Global.SHIFT_SPEED * delta)
	elif abs(rotation.z - rotation_z_target) <= 0.3 and tile_shift_triggered:
		# When close enough from target stop the rotation movement and give the final angle
		tile_shift_triggered = false
		rotation.z = rotation_z_target
		position.y = 0 # ensures we remain on the tile side we are supposed to be on
		# Reenable character to move
		for child in get_children():
			if child is CharacterBody3D:
				child.not_in_shift = 1 # This enables movement forward and backward

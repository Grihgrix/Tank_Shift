extends Node3D

@onready var group_tourelle = $"."
@onready var tourelle = $Head
@onready var character = $"../.."
@onready var shooter = $Head/Shooter



# Variable for mouse angle measurements and calculations
@onready var current_tourelle_viewport_position:Vector2 = get_viewport().get_camera_3d().unproject_position(tourelle.global_position)
@onready var current_mouse_postion:Vector2
@onready var tourelle_mouse_positon:Vector2
@onready var mouse_viewport_angular_position:float
@onready var cosinus_cam:String = "+"
@onready var sinus_cam:String = "-"
@onready var mouse_viewport_angular_position_Ref_tour:float

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Tourelle aiming at player if live NPC can see the player
	if not character.is_player and character.is_alive and character.aim_enemy_available:
		# Only NPCs when playert is at range
		# Find the target vector from the NPC to the player
		var target_vector = character.global_position - character.detected_enemy_character.global_position
		# Use the vector to calculate the angle needed for the tourelle
		var target_rotation = - atan2(target_vector.z, target_vector.x)  + PI / 2
		# Slowly turn the tourelle towards target
		global_rotation.y = lerp_angle(global_rotation.y, target_rotation, delta * 2)



# Only triggers when the mouse is clicked are moves
func _input(event):
	# find the mouse in the world referential and use its postion to turn the tourelle (using raycast)
	if character.is_player and character.is_alive and character.not_in_shift == 1 and event is InputEventMouseMotion:
		# Get the camera related objects
		var mouse_position_viewport = get_viewport().get_mouse_position()
		var camera = get_viewport().get_camera_3d()
		
		# Raycast origin and direction :
		var raycast_origin = camera.project_ray_origin(mouse_position_viewport)
		var raycast_direction = camera.project_ray_normal(mouse_position_viewport)
		
		# Define intersection with plan where Y = shooter Y
		var raycast_distance = -(raycast_origin.y - shooter.global_position.y) / raycast_direction.y
		
		var mouse_position_on_lvl = raycast_origin + raycast_direction * raycast_distance
		#print(str(mouse_position_on_lvl) + " - " + str(character.global_position))
		
		# Calculate the mouse position relative ot hte player position
		var mouse_position_rel_player = mouse_position_on_lvl - character.global_position
		
		
		# Assign new angle to the tourelle
		group_tourelle.global_rotation.y = atan2(mouse_position_rel_player.x, mouse_position_rel_player.z) + PI
		group_tourelle.global_rotation.x = character.global_rotation.x
		group_tourelle.global_rotation.z = character.global_rotation.z
		

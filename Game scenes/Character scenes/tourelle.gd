extends Node3D

@onready var group_tourelle = $"."
@onready var tourelle = $Head
@onready var character = $"../.."


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
	# Mouse in viewport coordinates.
	if character.is_player and character.is_alive and event is InputEventMouseMotion and 1 == 0:
		# Find mouse position
		current_mouse_postion = event.position
		# Find tourelle position
		current_tourelle_viewport_position = get_viewport().get_camera_3d().unproject_position(tourelle.global_position)
		# Calculate mouse postion relative to tourele in the viewport
		tourelle_mouse_positon = current_mouse_postion - current_tourelle_viewport_position

		# Calculate angular position of the mouse with the tourelle being (0,0)
		mouse_viewport_angular_position = atan2(-tourelle_mouse_positon.y, tourelle_mouse_positon.x)

		if cos(mouse_viewport_angular_position) >=0:
			cosinus_cam = "+"
		else:
			cosinus_cam = "-"
		if sin(mouse_viewport_angular_position) >=0:
			sinus_cam = "+"
		else:
			sinus_cam = "-"

		# Convert viewport angle to tourelle angle
		if  cosinus_cam == "-" and sinus_cam == "-":
			mouse_viewport_angular_position_Ref_tour = (1.5 * PI) + mouse_viewport_angular_position
		elif cosinus_cam == "+"  and sinus_cam == "-":
			mouse_viewport_angular_position_Ref_tour = -0.5 * PI + mouse_viewport_angular_position
		elif cosinus_cam == "+"  and sinus_cam == "+":
			mouse_viewport_angular_position_Ref_tour = (- 0.5 * PI) + mouse_viewport_angular_position
		elif cosinus_cam == "-"  and sinus_cam == "+":
			mouse_viewport_angular_position_Ref_tour = (1.5 * PI) + mouse_viewport_angular_position

		# Assign new angle to the tourelle
		group_tourelle.rotation.y = mouse_viewport_angular_position_Ref_tour
	
	# V2 using raycast ?
	if character.is_player and character.is_alive and character.not_in_shift == 1 and event is InputEventMouseMotion:
		# Get the camera related objects
		var mouse_position_viewport = get_viewport().get_mouse_position()
		var camera = get_viewport().get_camera_3d()
		
		# Raycast origin and direction :
		var raycast_origin = camera.project_ray_origin(mouse_position_viewport)
		var raycast_direction = camera.project_ray_normal(mouse_position_viewport)
		
		# Define intersection with plan where Y = 0
		var raycast_distance = -(raycast_origin.y - 0.0) / raycast_direction.y
		
		var mouse_position_on_lvl = raycast_origin + raycast_direction * raycast_distance
		#print(str(mouse_position_on_lvl) + " - " + str(character.global_position))
		
		# Calculate the mouse position relative ot hte player position
		var mouse_position_rel_player = mouse_position_on_lvl - character.global_position
		
		
		# Assign new angle to the tourelle
		group_tourelle.global_rotation.y = atan2(mouse_position_rel_player.x, mouse_position_rel_player.z) + PI
		group_tourelle.global_rotation.x = character.global_rotation.x
		group_tourelle.global_rotation.z = character.global_rotation.z
		

class_name Character
extends CharacterBody3D


# UI variables
@export var hp:int = 3
signal on_hp_changed(new_hp:int)

# Variables to help the basic controls to work in both up and down side
@onready var is_up_or_down:int # to be used as a marker of whethere we are upside or downside (value down : -1 or up: 1)
@onready var tile_rotation_modifier:int
@onready var self_shift_triggered:bool = false
@onready var rotation_z_target:float
# Character movements
var steer_direction:int
var move_direction:int

# Shift related variables
@export var current_tile_id:int # to be used to assing tile as temp parent of the character
@export var not_in_shift:int = 1
@onready var shift_timer:Timer = $Shift_Timer

@onready var shoot_timer:Timer = $Proto_tank/Tourelle/Head/Shooter/Shooter_Timer

# characters deifferentiation variables
@export var is_player:bool
@export var character_id:int

# Visuals
@export_category("Visuals")
@export var team_a_mat : Material
@export var team_b_mat : Material
@export var dead_mat : Material
@export var colored_meshes: Array[MeshInstance3D]
@export var dead_meshs_position: Dictionary[MeshInstance3D, Node3D]
@export var particle_trails: Array[GPUParticles3D]
@onready var explosion_fx: Node = $FxExplosionBig

@onready var is_alive:bool = true

# NPC behaviour
@onready var state_machine_player:StateMachinePlayer = $StateMachinePlayer
@onready var current_state = state_machine_player.get_current()
@onready var enemy_detection:Area3D = $Enemy_Detection
@onready var enemies_detected:int = 0
@onready var enemies_shift_req_detected:int = 0
@onready var allies_detected:int = 0

@onready var aim_enemy_available:bool = false
@onready var npc_is_shooting:bool = false
var detected_enemy_character:CharacterBody3D
var npc_dodge_rand_array:Array = [-1, 1]

@onready var npc_dodge_direction_modifier = 1 # picked between 1 and -1 when npc_dodge_direction_timer stops
@onready var npc_dodge_angular_direction_modifier = 1 # picked between 1 and -1 when npc_dodge_direction_timer stops

@onready var npc_dodge_direction_timer:Timer = $NPC_dodge_direction_Timer
@onready var npc_dodge_angular_direction_timer:Timer = $NPC_dodge_angular_direction_Timer

@onready var npc_shift_timer:Timer = $NPC_shift_Timer
@onready var npc_shift_decision:bool = false


# Signal to detect if ennemy just shifted
signal on_shift(shifter_id:int, shifter_is_up_or_down:int)

@onready var label_3d:Label3D = $Label3D

# Navigation NPC
@onready var navigation_agent_3d:NavigationAgent3D = $NavigationAgent3D
@onready var npc_navigation_timer:Timer = $NPC_navigation_Timer

# Rotation watchdog
@onready var character_orientation_check_timer:Timer = $Character_orientation_check_Timer




func _ready():
	if is_player:
		Global.player_character = self

	# Ensires no immediate shift happens at game start
	npc_shift_timer.start(randf_range(4,10))
	# Intialize character spawn position
	position.x = Global.characters_spawn_locations[character_id]["x"]
	position.y = Global.characters_spawn_locations[character_id]["y"]
	position.z = Global.characters_spawn_locations[character_id]["z"]

	rotation.z = Global.characters_spawn_locations[character_id]["Rz"]
	rotation.y = Global.characters_spawn_locations[character_id]["Ry"]

	label_3d.text = str(hp)

	# Visuals
	for mesh in colored_meshes:
		if is_player:
			mesh.set_surface_override_material(0, team_a_mat)
		else:
			mesh.set_surface_override_material(0, team_b_mat)


func _physics_process(delta):
	# Get the current state of the state machine for this character
	current_state = state_machine_player.get_current()
	#label_3d.text = str(character_id) + " state = " + current_state
	label_3d.text = str(hp)

	#if character_id == 2:
		#print("Character : " + str(character_id) + " Current State :  " + str(current_state))
		#print("enemies_detected = " + str(enemies_detected) + " shift_req_detected = " + str(enemies_shift_req_detected))

	########################################
	# Find the tile id the character is on #
	########################################
	var Current_Tile_X:int = round(global_position.x / (Global.terrain_tile_size + Global.space_between_tiles))
	var Current_Tile_Y:int = -(round(global_position.z / (Global.terrain_tile_size + Global.space_between_tiles)))
	current_tile_id = (Current_Tile_X * 10000) + Current_Tile_Y
	#print(current_tile_id)

	##############
	# Self-shift #
	##############

	# Upside-down shift command capture
	if is_player and is_alive and Input.is_action_just_pressed("ui_accept") and shift_timer.is_stopped():
		# Start the cooldown
		shift_timer.start(Global.shift_cooldown)
		Global.on_shift_cooldown_started.emit()
		# Trigger reparenting (in the main script)
		Global.self_shift_requested = true
		# Trigger shift of current parent
		var current_tile:Node = get_parent()
		current_tile.self_shift_requested = true

	# Self shift NPC decision
	if not is_player and is_alive and npc_shift_timer.is_stopped():
		# Ensures NPC do not get stuck in a shift loop
		npc_shift_timer.start(randf_range(4,10))

		# Proba threshold will give a certain chance for a shift to be triggered at the end of each npc shift timer
		var shift_proba_threshold:float = 0.1
		# Define the shift probability depending on the current state of the NPC
		if current_state == "Exploration":
			shift_proba_threshold = 0.2
		elif current_state == "Attaque":
			shift_proba_threshold = 0.1
		elif current_state == "Ennemy below":
			shift_proba_threshold = 0.3


		# check if we trigger the shift
		if randf() <= shift_proba_threshold:
			# Start the cooldown
			shift_timer.start(Global.shift_cooldown)
			# Trigger reparenting (in the main script)
			Global.self_shift_requested = true
			# Trigger shift of current parent
			var current_tile:Node = get_parent()
			current_tile.self_shift_requested = true

	###############################################
	# Check if character is not flat on the floor #
	###############################################

	if is_alive and not_in_shift and character_orientation_check_timer.is_stopped():
		#print("character : " + str(character_id) + " current rotation : " + str(global_rotation))
		if round(global_rotation.x * 10) != 0 :
			# If x rotation is no longer close to 0 we put it back to 0
			global_rotation.x = 0
			global_position.y = 0 # Ensure we remain above ground
			print("rotation x corrected for character " + str(character_id))
		if round(global_rotation.z * 10) != 0 and  abs(round(global_rotation.z * 100)/100) != 3.14:
			if abs(global_rotation.z) <= 1:
				global_rotation.z = 0
			else:
				global_rotation.z = PI
			global_position.y = 0 # Ensure we remain above ground
			print("rotation z corrected for character " + str(character_id))
		character_orientation_check_timer.start(1)


	###########################
	# Command a distant Shift #
	###########################
	# Distant shift is cut
	#if is_player and is_alive and Input.is_action_just_released("Distant_Shift") and shift_timer.is_stopped():
	#	# Start the cooldown
	#	shift_timer.start(Global.shift_cooldown)
	#	# Trigger reparenting (in the main script) and shift (in the tile script)
	#	Global.shift_requested_on_mouse = true
	#	# Actual shift is happening in the tiles code

	#######################################
	# NPC behaviours related timer checks #
	#######################################

	# MPC dodge direction picker
	if npc_dodge_angular_direction_timer.is_stopped():
		# Choose new direction
		npc_dodge_angular_direction_modifier = [-1,1].pick_random()
		# Relaunch the timer at a new random time
		npc_dodge_angular_direction_timer.start(round(randf_range(1,30))) # anything between 1 secong and 30 sec

	# NPC doge forward or backward
	if npc_dodge_direction_timer.is_stopped():
		# Choose new direction
		npc_dodge_direction_modifier = [-1,1].pick_random()
		# Relaunch the timer at a new random time
		npc_dodge_direction_timer.start(round(randf_range(1,3))) # anything between 1 secong and 10 sec

	######################################
	# Check if we are upside down or not #
	######################################
	# Tank modifier
	var prev_is_up_or_down = is_up_or_down
	if abs(round(global_rotation.z * 100)/100) == 3.14 and abs(round(global_rotation.x * 100)/100) == 3.14:
		# If both X and Z axis are at 180 deg, we are upside
		is_up_or_down = 1
	elif round(global_rotation.z) == 0 and round(global_rotation.x) == 0:
		# If both X and Z axis are at 0 deg, we are upside
		is_up_or_down = 1
	else:
		# Otherwise either X or Z or at 180 while the other is at 0, we are downside
		is_up_or_down = -1


	# When shift just happened, emit the signal
	if prev_is_up_or_down !=is_up_or_down:
		on_shift.emit(character_id, is_up_or_down)

	# Tile rotation modifier
	var tile_rotation = (round((round(get_parent().rotation.z * 100)/(3.14 * 2)) / 10)) / 10
	if tile_rotation == round(tile_rotation):
		tile_rotation_modifier = 1
	else:
		tile_rotation_modifier = -1

	##############################################
	# Affect NPC nav agent to its current region #
	##############################################
	if is_up_or_down == 1:
		navigation_agent_3d.navigation_layers = 1
	elif is_up_or_down == -1:
		navigation_agent_3d.navigation_layers = 2

	#####################################################
	# Define NPC movement using pre-defined Destination #
	#####################################################

	if not is_player and is_alive and (current_state == "Exploration" or current_state == "Ennemy below"):
		# Trigger the new destination assignment (for now when pressing CTRL, but to be replaced by timer controlled or when path finished)
		#if Input.is_action_just_released("Debug Path"):
		#	#_debug_npc_path_assignment()
		#	pass

		# Add here a timer mechanism that will change destination to a new random location
		if npc_navigation_timer.is_stopped() or navigation_agent_3d.is_navigation_finished():
			npc_navigation_timer.stop()
			npc_navigation_timer.start(round(randf_range(3,15)))

			if randf() >= 0.1:
				# NPC decides of a new random destination
				_calculate_new_NPC_destination()
				# In 90% of cases choose a new destination

		# Stop the NPC if he arrived at destination
		if navigation_agent_3d.is_navigation_finished():
			velocity.x = 0
			velocity.z = 0
		# Otherwise move towards destination
		else:
			#var nav_destination = navigation_agent_3d.get_next_path_position()
			var nav_next_destination = navigation_agent_3d.get_next_path_position() - global_position
			nav_next_destination.y = 0 # ensure we won't try to move up or down

			#Check if we are still away from destination
			if nav_next_destination.length() > 0.1:
				# Calculate if there is need for steer
				var nav_npc_steer_angle = atan2(nav_next_destination.x, nav_next_destination.z) + PI

				if abs(round((global_rotation.y - nav_npc_steer_angle) * 10 / PI))  != 0 and abs(round((global_rotation.y - nav_npc_steer_angle) * 10 / PI)) != 20:
					# NPC Steers
					global_rotation.y = rotate_toward(global_rotation.y, nav_npc_steer_angle, delta)

					# Check if the turn is more than 90 degrees, if so stop during turn
					if abs(global_rotation.y - nav_npc_steer_angle) >=  2 * PI / 3 and abs(global_rotation.y - nav_npc_steer_angle) <= 4 * PI / 3:
						# if angle is too tight, stop moving and just turn
						velocity.x = 0
						velocity.z = 0
					else:
						velocity.x = Global.SPEED * cos(rotation.y + tile_rotation_modifier * PI/2) * not_in_shift
						velocity.z = Global.SPEED * sin(rotation.y -  PI/2) * not_in_shift
				else:
					# if next location is straght ahead
					global_rotation.y = nav_npc_steer_angle
					velocity.x = Global.SPEED * cos(rotation.y + tile_rotation_modifier * PI/2) * not_in_shift
					velocity.z = Global.SPEED * sin(rotation.y -  PI/2) * not_in_shift
			else:
				# Stop when very close to objectif
				velocity.x = 0
				velocity.z = 0
	elif not is_player and is_alive and current_state == "Attaque":
		# Same target vector as used in tourelle for NPC aiming
		var target_vector = global_position - detected_enemy_character.global_position
		# Use the vector to calculate the orthogonal direction for the NPC to turn towards
		var dodge_rotation = (npc_dodge_angular_direction_modifier * PI) - atan2(target_vector.z, target_vector.x) # this will make give a direction either right or left at 90 degrees from the direction of the player (so we can turn around the player)
		# Trigger turn
		global_rotation.y = rotate_toward(global_rotation.y, dodge_rotation, delta)

		# Doge translation
		if npc_is_shooting:
			# NPC stops to shoot
			velocity.x = 0
			velocity.z = 0
		else:
			# If noty shooting NPC turns around target
			velocity.x = Global.SPEED * cos(rotation.y + tile_rotation_modifier * PI/2) * not_in_shift * npc_dodge_direction_modifier
			velocity.z = Global.SPEED * sin(rotation.y -  PI/2) * not_in_shift * npc_dodge_direction_modifier
	else:
		# if current state is not exploration
		velocity.x = 0
		velocity.z = 0


	#########################################
	# Controlled player movements movements #
	#########################################

	if is_player and is_alive:
		# Capture rotation controls
		steer_direction = Input.get_axis("ui_right", "ui_left") # Left = 1 # Right = -1
		# Capture translation controls
		move_direction = Input.get_axis("ui_up", "ui_down") # Up = -1 # Down = 1
		# Character moving forward or backward
		velocity.z = move_direction * Global.SPEED * cos(rotation.y) * not_in_shift
		velocity.x = move_direction * Global.SPEED * sin(rotation.y) * not_in_shift * tile_rotation_modifier

		# Character rotating right or left
		global_rotation.y += (steer_direction * is_up_or_down *  delta)

	###################
	# Particle Trails #
	###################

	for trail in particle_trails:
		if velocity.length() > 0.1:
			trail.emitting = true
		else:
			trail.emitting = false

	##################
	# Apply movement #
	##################
	move_and_slide()




func _debug_npc_path_assignment():
	print("Debug Path")
	# This is when prtessing CTRL
	_calculate_new_NPC_destination()

func _calculate_new_NPC_destination():
	var random_position:Vector3 = Vector3.ZERO
	random_position.x = randf_range(1.0, Global.board_total_length.x - 1.0)
	random_position.z = randf_range(1.0, - (Global.board_total_length.y - 1.0))
	random_position.y = 0
	#print(str(character_id) + str(random_position))
	navigation_agent_3d.set_target_position(random_position)


func _on_state_machine_player_transited(from, to):
	pass # Replace with function body.


func _on_enemy_detection_body_entered(body):
	if not is_player and is_alive and body is CharacterBody3D:
		if body.character_id == 1:
			# Assign the player node to the  ennemy character body variable
			detected_enemy_character = body
			# Trigger the marker showing that the ennemy can be seen
			if is_up_or_down == body.is_up_or_down:
				# only aim if the ennemy is visible (on the same side as you)
				aim_enemy_available = true

			# Trigger the change of state
			enemies_detected +=1
			state_machine_player.set_param("Ennemies Detected", enemies_detected)

			# Check if the enemy is on the other side
			if body.is_up_or_down != is_up_or_down:
				enemies_shift_req_detected += 1
			state_machine_player.set_param("Ennemies Shift Required", enemies_shift_req_detected)

			# Start checking the on shift signal for this character
			body.on_shift.connect(_nearby_ennemy_shifted)
		else:
			allies_detected +=1
			state_machine_player.set_param("Allies Detected", enemies_detected)


func _on_enemy_detection_body_exited(body):
	if not is_player and body is CharacterBody3D:
		if body.character_id == 1:
			# Trigger the marker showing that the ennemy can no longer be seen
			aim_enemy_available = false

			# Trigger the state change
			enemies_detected -=1
			state_machine_player.set_param("Ennemies Detected", enemies_detected)
			# Check if the enemy is on the other side
			if body.is_up_or_down != is_up_or_down:
				enemies_shift_req_detected -= 1
				state_machine_player.set_param("Ennemies Shift Required", enemies_shift_req_detected)

			# Start checking the on shift signal for this character
			body.on_shift.disconnect(_nearby_ennemy_shifted)
		else:
			allies_detected -=1
			state_machine_player.set_param("Allies Detected", enemies_detected)

# Runs when on_shift signal is emitted
func _nearby_ennemy_shifted(shifter_id, shifter_is_up_or_down):
	print("Shifter detected : " + str(shifter_id))
	if shifter_id == 1:
		#print("Ennemy shifter nearby : " + str(shifter_id) + " " + str(shifter_is_up_or_down))

		if shifter_is_up_or_down == is_up_or_down:
			# If we are on the same side now :
			# Trigger the marker showing that the ennemy can be seen
			aim_enemy_available = true

			# Trigger the change of state
			enemies_shift_req_detected -= 1
		else :
			# If we are now shifted away
			# Trigger the marker showing that the ennemy can no longer be seen
			aim_enemy_available = false

			# Trigger the change of state
			enemies_shift_req_detected += 1
		state_machine_player.set_param("Ennemies Shift Required", enemies_shift_req_detected)

func death():
	is_alive = false
	hp = 0
	for mesh in colored_meshes:
		mesh.set_surface_override_material(0, dead_mat)
	explosion_fx.burst()
	for mesh in dead_meshs_position.keys():
		mesh.position = dead_meshs_position[mesh].position
		mesh.rotation = dead_meshs_position[mesh].rotation

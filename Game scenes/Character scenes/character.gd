extends CharacterBody3D

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

# characters deifferentiation variables
@export var is_player:bool
@export var character_id:int

@onready var is_alive:bool = true

# NPC behaviour
@onready var state_machine_player:StateMachinePlayer = $StateMachinePlayer
@onready var enemy_detection:Area3D = $Enemy_Detection
@onready var enemies_detected:int = 0
@onready var enemies_shift_req_detected:int = 0
@onready var allies_detected:int = 0

# Signal to detect if ennemy just shifted
signal on_shift(shifter_id:int, shifter_is_up_or_down:int)

@onready var label_3d:Label3D = $Label3D

# Navigation NPC
@onready var navigation_agent_3d:NavigationAgent3D = $NavigationAgent3D
@onready var up_navigation_region_3d = $"../Up_NavigationRegion3D"
@onready var npc_activities_timer = $NPC_Activities_Timer # Will be used to change destination, or move between shots, or delay shifts




func _ready():
	
	# Intialize character spawn position
	position.x = Global.characters_spawn_locations[character_id]["x"]
	position.y = Global.characters_spawn_locations[character_id]["y"]
	position.z = Global.characters_spawn_locations[character_id]["z"]
	
	rotation.z = Global.characters_spawn_locations[character_id]["Rz"]
	rotation.y = Global.characters_spawn_locations[character_id]["Ry"]
	
	label_3d.text = str(character_id)
	

func _physics_process(delta):
	# Get the current state of the state machine for this character
	var current_state = state_machine_player.get_current()
	label_3d.text = str(character_id) + " state = " + current_state
	
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
		# Trigger reparenting (in the main script)
		Global.self_shift_requested = true
		# Trigger shift of current parent
		var current_tile:Node = get_parent()
		current_tile.self_shift_requested = true
		
	
	
	###########################
	# Command a distant Shift #
	###########################
	if is_player and is_alive and Input.is_action_just_released("Distant_Shift") and shift_timer.is_stopped():
		# Start the cooldown
		shift_timer.start(Global.shift_cooldown)
		# Trigger reparenting (in the main script) and shift (in the tile script)
		Global.shift_requested_on_mouse = true
		# Actual shift is happening in the tiles code
	
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
	##########################
	# Capture controls input #
	##########################
	
	if is_player and is_alive:
		# Capture rotation controls
		steer_direction = Input.get_axis("ui_right", "ui_left") # Left = 1 # Right = -1
		# Capture translation controls
		move_direction = Input.get_axis("ui_up", "ui_down") # Up = -1 # Down = 1 
	
	###########################
	# Capture NPC Destination #
	###########################
	
	#if navigation_agent_3d.is_navigation_finished():
	#	#print("PATH FINISHED")
	#	pass
	
	if not is_player and current_state == "Exploration":
		
		if Input.is_action_just_released("Debug Path"):
			_debug_npc_path_assignment()
		
		if navigation_agent_3d.is_navigation_finished():
			velocity.x = 0
			velocity.z = 0
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
					velocity.x = 0
					velocity.z = 0
				else:
					global_rotation.y = nav_npc_steer_angle
					velocity.x = Global.SPEED * cos(rotation.y + tile_rotation_modifier * PI/2) * not_in_shift
					velocity.z = Global.SPEED * sin(rotation.y -  PI/2) * not_in_shift
			else:
				velocity.x = 0
				velocity.z = 0
			
			#var nav_direction = nav_next_destination.normalized()
		
			#velocity = nav_direction * Global.SPEED
	
	
	###################
	# Apply movements #
	###################
	
	if is_player:
		# Character moving forward or backward
		velocity.z = move_direction * Global.SPEED * cos(rotation.y) * not_in_shift
		velocity.x = move_direction * Global.SPEED * sin(rotation.y) * not_in_shift * tile_rotation_modifier
		
		# Character rotating right or left
		global_rotation.y += (steer_direction * is_up_or_down *  delta)
	
	move_and_slide()

func _debug_npc_path_assignment():
	#up_navigation_region_3d.bake_navigation_mesh()
	#await up_navigation_region_3d.bake_finished
	#await get_tree().create_timer(1).timeout
	print("Debug Path")
	# This is when prtessing CTRL
	var random_position:Vector3 = Vector3.ZERO
	random_position.x = randf_range(1.0, Global.board_total_length.x - 1.0)
	random_position.z = randf_range(1.0, - (Global.board_total_length.y - 1.0))
	#random_position.x = 1
	random_position.y = 1
	#random_position.z = -20
	print(str(character_id) + str(random_position))
	navigation_agent_3d.set_target_position(random_position)


func _on_state_machine_player_transited(from, to):
	pass # Replace with function body.


func _on_enemy_detection_body_entered(body):
	if not is_player and body is CharacterBody3D:
		if body.character_id == 1:
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
			enemies_shift_req_detected -= 1
		else :
			# If we are now shifted away
			enemies_shift_req_detected += 1
		state_machine_player.set_param("Ennemies Shift Required", enemies_shift_req_detected)

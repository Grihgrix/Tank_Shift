extends CharacterBody3D

@onready var is_up_or_down:int # to be used as a marker of whethere we are upside or downside (value down : -1 or up: 1)
@onready var tile_rotation_modifier:int
@onready var self_shift_triggered:bool = false
@onready var rotation_z_target:float

@export var current_tile_id:int # to be used to assing tile as temp parent of the character
@export var not_in_shift:int = 1

@export var canon_ammo_count:int = Global.start_canon_ammo_count
@export var shift_ammo_count:int = Global.start_shift_ammo_count


func _ready():
	position.y = 0 # ensures we are on the tile level
	

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		#velocity += get_gravity() * delta
		pass
		# Gravity is not to be used in this project
		# Needs to be replaced by thecharacter sticking to the tile surface
	
	########################################
	# Find the tile id the character is on #
	########################################
	var Current_Tile_X:int = round(global_position.x / (Global.terrain_tile_size + Global.space_between_tiles))
	var Current_Tile_Y:int = -(round(global_position.z / (Global.terrain_tile_size + Global.space_between_tiles)))
	current_tile_id = (Current_Tile_X * 10000) + Current_Tile_Y
	#print(current_tile_id)
	
	#######################################################
	# Reparent the character to the current tile it is on #
	#######################################################
	#reparent()
	
	
	##############
	# Self-shift #
	##############
	
	# Upside-down shift command capture
	if Input.is_action_just_pressed("ui_accept") and self_shift_triggered == false:
		# Define the rotation post self shift
		rotation_z_target = rotation.z + PI
		self_shift_triggered = true
		#rotation.z = rotation_z_target
		#self_shift_triggered = false
	
	# Operate self-shift
	if abs(rotation.z - rotation_z_target) > 0.3 and self_shift_triggered:
		position.y = 0 # ensures we remain on the tile side we are supposed to be on
		rotation.z = move_toward(rotation.z, rotation_z_target, Global.SHIFT_SPEED * delta)
	elif abs(rotation.z - rotation_z_target) <= 0.3 and self_shift_triggered:
		self_shift_triggered = false
		rotation.z = rotation_z_target
		position.y = 0 # ensures we remain on the tile side we are supposed to be on
	
	###########################
	# Command a distant Shift #
	###########################
	if Input.is_action_just_released("Distant_Shift") and shift_ammo_count > 0:
		Global.shift_requested_on_mouse = true
		# Actual shift is happening in the tiles code
		# consume a shift ammo
		shift_ammo_count -= 1
	
	######################################
	# Check if we are upside down or not #
	######################################
	# Tank modifier
	if abs(round(rotation.z * 100)/100) == 3.14 and abs(round(rotation.x * 100)/100) == 3.14:
		# If both X and Z axis are at 180 deg, we are upside
		is_up_or_down = 1
	elif round(rotation.z) == 0 and round(rotation.x) == 0:
		# If both X and Z axis are at 0 deg, we are upside
		is_up_or_down = 1
	else:
		# Otherwise either X or Z or at 180 while the other is at 0, we are downside
		is_up_or_down = -1
	
	# Tile rotation modifier
	var tile_rotation = (round((round(get_parent().rotation.z * 100)/(3.14 * 2)) / 10)) / 10
	if tile_rotation == round(tile_rotation):
		tile_rotation_modifier = 1
	else:
		tile_rotation_modifier = -1
	##########################
	# Capture controls input #
	##########################
	
	# Capture rotation controls
	var steer_direction = Input.get_axis("ui_right", "ui_left") # Left = 1 # Right = -1
	# Capture translation controls
	var move_direction = Input.get_axis("ui_up", "ui_down") # Up = -1 # Down = 1 
	
	###################
	# Apply movements #
	###################
	
	# Character moving forward or backward
	velocity.z = move_direction * Global.SPEED * cos(rotation.y) * not_in_shift
	velocity.x = move_direction * Global.SPEED * sin(rotation.y) * not_in_shift * tile_rotation_modifier
	
	
	# Character rotating right or left
	rotate_y(steer_direction * is_up_or_down * delta)

	move_and_slide()

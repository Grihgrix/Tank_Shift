extends CharacterBody3D


const SPEED = 5.0
@onready var is_up_or_down:int # to be used as a marker of whethere we are upside or downside (value down : -1 or up: 1)

func _ready():
	pass

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		#velocity += get_gravity() * delta
		pass
		# Gravity is not to be used in this project
		# Needs to be replaced by thecharacter sticking to the tile surface

	# Upside-down shift
	if Input.is_action_just_pressed("ui_accept"):
		print(rotation.z)
		rotation.z += PI
		print(rotation.z)
		# This could be reused to provoke the rotation of the currently occupied tile
	
	######################################
	# Check if we are upside down or not #
	######################################
	if abs(round(rotation.z * 100)/100) == 3.14 and abs(round(rotation.x * 100)/100) == 3.14:
		# If both X and Z axis are at 180 deg, we are upside
		is_up_or_down = 1
	elif round(rotation.z) == 0 and round(rotation.x) == 0:
		# If both X and Z axis are at 0 deg, we are upside
		is_up_or_down = 1
	else:
		# Otherwise either X or Z or at 180 while the other is at 0, we are downside
		is_up_or_down = -1
	
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
	velocity.z = move_direction * SPEED * cos(rotation.y)
	velocity.x = move_direction * SPEED * sin(rotation.y)
	
	# Character rotating right or left
	rotate_y(steer_direction * is_up_or_down * delta)

	move_and_slide()

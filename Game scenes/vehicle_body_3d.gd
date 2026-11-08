extends VehicleBody3D

@onready var ground_node_3d:Node = $"../Ground_Node3D"

# Group all left wheels
@onready var wheel_l_1:Node = $Wheel_L1
@onready var wheel_l_2:Node = $Wheel_L2
@onready var left_wheels:Array = [wheel_l_1, wheel_l_2]

# Group all right wheels
@onready var wheel_r_1:Node = $Wheel_R1
@onready var wheel_r_2:Node = $Wheel_R2
@onready var right_wheels:Array = [wheel_r_1, wheel_r_2]



# Vehicle speed
@onready var max_speed:int = 1000
@onready var current_speed:int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var steer = Input.get_axis("ui_right", "ui_left") # Left = -1 # Right = 1
	#print(steer)
	var move_dir = Input.get_axis("ui_up", "ui_down") # Up = 1 # Down = -1
	#print(move_dir) 
	
	# Need to change that into wheel power, and need to get it as a fraction of available power  (so you don't turn faster than go straight)
	for wheel in right_wheels:
		wheel.engine_force =  max_speed * (move_dir + steer) # for right
	for wheel in left_wheels:
		wheel.engine_force = max_speed * (move_dir - steer) # for left

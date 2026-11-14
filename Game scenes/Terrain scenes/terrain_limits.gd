extends Node3D

@onready var board_limit_1 = $Board_Limit_1
@onready var board_limit_2 = $Board_Limit_2
@onready var board_limit_3 = $Board_Limit_3
@onready var board_limit_4 = $Board_Limit_4


@onready var board_total_length:Vector2 = Vector2(0,0)

@onready var board_limit_thickness:float = 0.2

# Called when the node enters the scene tree for the first time.
func _ready():
	print(Global.terrain_tile_size)
	print(Global.terrain_dimension)
	
	# Calculate length of the board
	board_total_length.x = (Global.terrain_dimension.x + (2 * Global.space_between_tiles)) * Global.terrain_tile_size
	board_total_length.y = (Global.terrain_dimension.y + (2 * Global.space_between_tiles)) * Global.terrain_tile_size
	print(board_total_length)
	
	
	# Apply to limit 1
	# Resize
	board_limit_1.scale.x = board_total_length.x + board_limit_thickness
	board_limit_1.scale.y = 1
	board_limit_1.scale.z =  board_limit_thickness
	# Reposition
	board_limit_1.global_position.x = (board_limit_1.scale.x / 2) - Global.terrain_tile_size / 2
	board_limit_1.global_position.y = 0
	board_limit_1.global_position.z = 0 + Global.terrain_tile_size / 2
	
	# Apply to limit 2 (it is the one opposite 1 so same orientation)
	# Resize 
	board_limit_2.scale.x = board_limit_1.scale.x
	board_limit_2.scale.y = board_limit_1.scale.y
	board_limit_2.scale.z = board_limit_1.scale.z
	# Reposition
	board_limit_2.global_position.x = board_limit_1.global_position.x
	board_limit_2.global_position.y = 0
	board_limit_2.global_position.z = - (board_total_length.y - Global.terrain_tile_size / 2)
	
	# Apply to limit 3
	# Resize
	board_limit_3.scale.x =  board_limit_thickness
	board_limit_3.scale.y = 1
	board_limit_3.scale.z = board_total_length.y + board_limit_thickness
	# Reposition
	board_limit_3.global_position.x = 0 - Global.terrain_tile_size / 2
	board_limit_3.global_position.y = 0
	board_limit_3.global_position.z = - ((board_limit_3.scale.z / 2) - (board_limit_thickness + Global.terrain_tile_size) / 2)
	
	# Apply to limit 4
	# Resize
	board_limit_4.scale.x = board_limit_3.scale.x
	board_limit_4.scale.y = board_limit_3.scale.y
	board_limit_4.scale.z = board_limit_3.scale.z
	# Reposition
	board_limit_4.global_position.x = (board_total_length.x - Global.terrain_tile_size / 2) + board_limit_thickness / 2
	board_limit_4.global_position.y = 0
	board_limit_4.global_position.z = board_limit_3.global_position.z

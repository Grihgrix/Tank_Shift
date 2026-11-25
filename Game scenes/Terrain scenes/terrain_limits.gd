extends Node3D

@onready var board_limit_1 = $Board_Limit_1
@onready var board_limit_2 = $Board_Limit_2
@onready var board_limit_3 = $Board_Limit_3
@onready var board_limit_4 = $Board_Limit_4

@onready var collision_shape_board_limit_1:CollisionShape3D = $Board_Limit_1/StaticBody3D/CollisionShape3D
@onready var collision_shape_board_limit_2:CollisionShape3D = $Board_Limit_2/StaticBody3D/CollisionShape3D
@onready var collision_shape_board_limit_3:CollisionShape3D = $Board_Limit_3/StaticBody3D/CollisionShape3D
@onready var collision_shape_board_limit_4:CollisionShape3D = $Board_Limit_4/StaticBody3D/CollisionShape3D



@onready var board_limit_thickness:float = 0.2

# Navigation box resizing
@onready var nav_csg_box_3d = $"../Nav_CSGBox3D"


# Called when the node enters the scene tree for the first time.
func _ready():	
	
	# Apply to limit 1
	# Resize
	board_limit_1.mesh.size.x = Global.board_total_length.x + board_limit_thickness
	board_limit_1.mesh.size.y = 1
	board_limit_1.mesh.size.z =  board_limit_thickness
	# Resize collision shape
	collision_shape_board_limit_1.shape.size.x = board_limit_1.mesh.size.x
	collision_shape_board_limit_1.shape.size.y = board_limit_1.mesh.size.y
	collision_shape_board_limit_1.shape.size.z = board_limit_1.mesh.size.z
	# Reposition
	board_limit_1.global_position.x = (board_limit_1.mesh.size.x / 2) - Global.terrain_tile_size / 2
	board_limit_1.global_position.y = 0
	board_limit_1.global_position.z = 0 + Global.terrain_tile_size / 2
	
	# Apply to limit 2 (it is the one opposite 1 so same orientation)
	# Resize 
	board_limit_2.mesh.size.x = board_limit_1.mesh.size.x
	board_limit_2.mesh.size.y = board_limit_1.mesh.size.y
	board_limit_2.mesh.size.z = board_limit_1.mesh.size.z
	# Resize collision shape
	collision_shape_board_limit_2.shape.size.x = board_limit_2.mesh.size.x
	collision_shape_board_limit_2.shape.size.y = board_limit_2.mesh.size.y
	collision_shape_board_limit_2.shape.size.z = board_limit_2.mesh.size.z
	# Reposition
	board_limit_2.global_position.x = board_limit_1.global_position.x
	board_limit_2.global_position.y = 0
	board_limit_2.global_position.z = - (Global.board_total_length.y - Global.terrain_tile_size / 2)
	
	# Apply to limit 3
	# Resize
	board_limit_3.mesh.size.x =  board_limit_thickness
	board_limit_3.mesh.size.y = 1
	board_limit_3.mesh.size.z = Global.board_total_length.y + board_limit_thickness
	# Resize collision shape
	collision_shape_board_limit_3.shape.size.x = board_limit_3.mesh.size.x
	collision_shape_board_limit_3.shape.size.y = board_limit_3.mesh.size.y
	collision_shape_board_limit_3.shape.size.z = board_limit_3.mesh.size.z
	# Reposition
	board_limit_3.global_position.x = 0 - Global.terrain_tile_size / 2
	board_limit_3.global_position.y = 0
	board_limit_3.global_position.z = - ((board_limit_3.mesh.size.z / 2) - (board_limit_thickness + Global.terrain_tile_size) / 2)
	
	# Apply to limit 4
	# Resize
	board_limit_4.mesh.size.x = board_limit_3.mesh.size.x
	board_limit_4.mesh.size.y = board_limit_3.mesh.size.y
	board_limit_4.mesh.size.z = board_limit_3.mesh.size.z
	# Resize collision shape
	collision_shape_board_limit_4.shape.size.x = board_limit_4.mesh.size.x
	collision_shape_board_limit_4.shape.size.y = board_limit_4.mesh.size.y
	collision_shape_board_limit_4.shape.size.z = board_limit_4.mesh.size.z
	# Reposition
	board_limit_4.global_position.x = (Global.board_total_length.x - Global.terrain_tile_size / 2) + board_limit_thickness / 2
	board_limit_4.global_position.y = 0
	board_limit_4.global_position.z = board_limit_3.global_position.z
	
	

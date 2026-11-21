extends Node3D


# Define in variable the scene we will instantiate (the projectile scene)
const TILE = preload("res://Game scenes/Terrain scenes/terrain_tile.tscn")

@export var Tiles_parent_group:String = "tile_parent"
var tiles_node:Node

@onready var nav_csg_box_3d = $"../Up_NavigationRegion3D/Nav_CSGBox3D"


# Called when the node enters the scene tree for the first time.
func _ready():
	
	tiles_node = get_tree().get_first_node_in_group(Tiles_parent_group)
	
	#########################################
	# Instantiat the terrain for this level #
	#########################################
	
	var Current_X:int = 0
	var Current_Y:int = 0
	
	while Current_X < Global.terrain_dimension.x:
		# Reintialize Current_Y
		Current_Y = 0
		while Current_Y < Global.terrain_dimension.y:
			# Spawn current tile
			spawn_tile(Current_X,Current_Y)
			# Increment Y
			Current_Y += 1
		# Increment X
		Current_X += 1
	
	# Resize the navigation_box
	nav_csg_box_3d.size.x = Global.board_total_length.x
	#nav_csg_box_3d.size.y = 1
	nav_csg_box_3d.size.z = Global.board_total_length.y
	# Reposition the nav box
	nav_csg_box_3d.position.x = (nav_csg_box_3d.size.x - Global.terrain_tile_size) / 2
	#nav_csg_box_3d.position.y = nav_csg_box_3d.size.y / 2
	nav_csg_box_3d.position.z = - (nav_csg_box_3d.size.z - Global.terrain_tile_size) / 2



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func spawn_tile(X:int,Y:int):
	
	var terrain_tile = TILE.instantiate()
	tiles_node.add_child(terrain_tile)
	
	terrain_tile.position.x = X * (Global.terrain_tile_size + Global.space_between_tiles)
	terrain_tile.position.y = 0
	terrain_tile.position.z = -Y * (Global.terrain_tile_size + Global.space_between_tiles)
	
	# Create a tile id
	
	terrain_tile.tile_id = (X * 10000) + Y
	#print(terrain_tile.tile_id)
	



	
	
	

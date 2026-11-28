extends Control

@onready var map_size
@onready var map_type


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_launch_button_pressed():
	get_tree().change_scene_to_file("res://Game scenes/Main_game_scene.tscn")


func _on_easy_button_pressed():
	Global.npc_starting_hp = 1
	Global.player_starting_hp = 3
	Global.terrain_dim_additionned = 40
	var map_shape_factor = randi_range(2,5)
	_set_terrain_dimensions(map_shape_factor)


func _on_medium_button_pressed():
	Global.npc_starting_hp = 3
	Global.player_starting_hp = 3
	Global.terrain_dim_additionned = 30
	var map_shape_factor = randi_range(2,4)
	_set_terrain_dimensions(map_shape_factor)
	


func _on_hard_button_pressed():
	Global.npc_starting_hp = 3
	Global.player_starting_hp = 1
	Global.terrain_dim_additionned = 20
	var map_shape_factor = randi_range(2,3)
	_set_terrain_dimensions(map_shape_factor)


func _set_terrain_dimensions(map_shape_factor:int):
	# Update terrain dimensions
	var map_x = round(Global.terrain_dim_additionned / map_shape_factor)
	var map_y = Global.terrain_dim_additionned - map_x
	print(str(map_shape_factor) + " - X = " + str(map_x) + " - Y = " + str(map_y))
	Global.terrain_dimension = Vector2i(map_x, map_y)
	
	# Terrain limits resize :
	Global.board_total_length = Vector2(
		(Global.terrain_dimension.x + (2 * Global.space_between_tiles)) * Global.terrain_tile_size
		, (Global.terrain_dimension.y + (2 * Global.space_between_tiles)) * Global.terrain_tile_size
		)
	
	
	# Update character spawn locations :
	Global.characters_spawn_locations[2]["x"] = (Global.terrain_dimension.x - 1) * (Global.terrain_tile_size + Global.space_between_tiles)
	Global.characters_spawn_locations[3]["x"] = (Global.terrain_dimension.x - 1) * (Global.terrain_tile_size + Global.space_between_tiles)
	Global.characters_spawn_locations[3]["z"] = - (Global.terrain_dimension.y - 1) * (Global.terrain_tile_size + Global.space_between_tiles)
	Global.characters_spawn_locations[4]["z"] = - (Global.terrain_dimension.y - 1) * (Global.terrain_tile_size + Global.space_between_tiles)
	Global.characters_spawn_locations[6]["x"] = (Global.terrain_dimension.x - 1) * (Global.terrain_tile_size + Global.space_between_tiles)
	Global.characters_spawn_locations[7]["x"] = (Global.terrain_dimension.x - 1) * (Global.terrain_tile_size + Global.space_between_tiles)
	Global.characters_spawn_locations[7]["z"] = - (Global.terrain_dimension.y - 1) * (Global.terrain_tile_size + Global.space_between_tiles)
	Global.characters_spawn_locations[8]["z"] = - (Global.terrain_dimension.y - 1) * (Global.terrain_tile_size + Global.space_between_tiles)

extends Control

@onready var difficulty_selected:String
@onready var end_game_message_label = $End_Game_Message_Label
@onready var mode_selected_label = $VBoxContainer/Mode_selected_Label
@onready var medium_button = $VBoxContainer/Difficulty_Container/Medium_Button




# Called when the node enters the scene tree for the first time.
func _ready():
	# Displays the end game message if populated
	end_game_message_label.text = "[center]"+ Global.End_Game_Message + "[/center]"
	
	# Aggro focus on button
	medium_button.grab_focus()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	mode_selected_label.text = "[center] Current difficulty selected: " + difficulty_selected + "[/center]"


func _on_launch_button_pressed():
	get_tree().change_scene_to_file("res://Game scenes/Main_game_scene.tscn")


func _on_easy_button_pressed():
	difficulty_selected = "Easy"
	Global.npc_starting_hp = 1
	Global.player_starting_hp = 3
	Global.terrain_dim_additionned = 40
	var map_shape_factor = randi_range(2,5)
	_set_terrain_dimensions(map_shape_factor)


func _on_medium_button_pressed():
	difficulty_selected = "Medium"
	Global.npc_starting_hp = 3
	Global.player_starting_hp = 3
	Global.terrain_dim_additionned = 30
	var map_shape_factor = randi_range(2,4)
	_set_terrain_dimensions(map_shape_factor)
	


func _on_hard_button_pressed():
	difficulty_selected = "Hard"
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
		Global.terrain_dimension.x * (Global.terrain_tile_size + Global.space_between_tiles)
		, Global.terrain_dimension.y * (Global.terrain_tile_size + Global.space_between_tiles)
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
	
	# Update corner tiles ID
	Global.corner_tile_id_1 = (0 * 10000) + 0
	Global.corner_tile_id_2 = (0 * 10000) + Global.terrain_dimension.y - 1
	Global.corner_tile_id_3 = ((Global.terrain_dimension.x - 1) * 10000) + 0
	Global.corner_tile_id_4 = ((Global.terrain_dimension.x - 1) * 10000) + Global.terrain_dimension.y - 1

extends Node




# Gameplay
var projectile_speed:int = 20
const SPEED:float = 10.0
const SHIFT_SPEED:float = PI / 0.5
var living_npc_count:int = 7 # to be used for UI
var player_character:Character
var npc_starting_hp:int = 3
var player_starting_hp:int = 3
#var projectile_damage:int = (100 / 3) + 1 # 34

# Cooldown
var shoot_cooldown:float = 0.5
var shift_cooldown:float = 1
signal on_shift_cooldown_started()

# Detect tile on which the mouse is
var current_tile_pointed_id:int # Used to detect which tile to distant shift (which tile has the mouse on it)
var current_tile_pointed_is_valid:bool = false # If the mouse is on a character the pointer if may no longer be correct
var shift_requested_on_mouse:bool = false
var self_shift_requested:bool = false

# Level instanciation
var terrain_dim_additionned:int = 20
var terrain_dimension:Vector2i = Vector2i(10, 10)
var terrain_tile_size:float = 2 * 3 #(2 * scale of tile)
var space_between_tiles:float = 0.2 # if we want to make the tiles visible or if we want to keep a small space to see the other side
var corner_tile_id_1 = (0 * 10000) + 0
var corner_tile_id_2 = (0 * 10000) + terrain_dimension.y - 1
var corner_tile_id_3 = ((terrain_dimension.x - 1) * 10000) + 0
var corner_tile_id_4 = ((terrain_dimension.x - 1) * 10000) + terrain_dimension.y - 1
var plain_proba:float = 2.0 / 3.0
var board_total_length:Vector2 = Vector2(
	terrain_dimension.x * (terrain_tile_size + space_between_tiles)
	, terrain_dimension.y * (terrain_tile_size + space_between_tiles)
	)


# NPC navigation
var navigation_mesh_bake_requested:bool = false

# Spawn locations and conditions for each character (upt to 8)
# location X,Y,Z, Rotation Z
var characters_spawn_locations:Dictionary = {
	1:{
		"x": 0   # Loc X
		, "y": 0 # Loc Y
		, "z": 0 # Loc Z
		, "Ry": - PI/4 # Rot Y
		, "Rz": 0 # Rot Z
		}
	, 2:{
		"x": (terrain_dimension.x - 1) * (terrain_tile_size + space_between_tiles)
		, "y": 0 
		, "z": 0 
		, "Ry": PI/4
		, "Rz": 0
		}
	, 3:{
		"x": (terrain_dimension.x - 1) * (terrain_tile_size + space_between_tiles)
		, "y": 0 
		, "z": - (terrain_dimension.y - 1) * (terrain_tile_size + space_between_tiles)
		, "Ry": 3 * PI / 4
		, "Rz": 0
		}
	, 4:{
		"x": 0
		, "y": 0 
		, "z": - (terrain_dimension.y - 1) * (terrain_tile_size + space_between_tiles)
		, "Ry": - 3 * PI / 4
		, "Rz": 0
		}
	, 5:{
		"x": 0
		, "y": 0 
		, "z": 0
		, "Ry": - PI / 4
		, "Rz": PI
		}
	, 6:{
		"x": (terrain_dimension.x - 1) * (terrain_tile_size + space_between_tiles)
		, "y": 0 
		, "z": 0 
		, "Ry": PI/4
		, "Rz": PI
		}
	, 7:{
		"x": (terrain_dimension.x - 1) * (terrain_tile_size + space_between_tiles)
		, "y": 0 
		, "z": - (terrain_dimension.y - 1) * (terrain_tile_size + space_between_tiles)
		, "Ry": 3 * PI / 4
		, "Rz": PI
		}
	, 8:{
		"x": 0
		, "y": 0 
		, "z": - (terrain_dimension.y - 1) * (terrain_tile_size + space_between_tiles)
		, "Ry": - 3 * PI / 4
		, "Rz": PI
		}
	}


# Game over 
var End_Game_Message:String
var game_is_over:bool = false
var player_won:bool

func End_of_game(player_won:bool):
	if player_won:
		End_Game_Message = "You won !"
	else:
		End_Game_Message = "Game over. " + str(living_npc_count) + " ennemies remaining"
	
	# Wait a short while so player can see the game over message
	await get_tree().create_timer(3).timeout
	
	# Go back to main menu so player can launch a new game
	get_tree().change_scene_to_file("res://Menu scenes/main_menu.tscn")
	
	# Need to reinitialize global variables : 
	living_npc_count = 7
	game_is_over = false

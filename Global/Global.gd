extends Node




# Gameplay
var projectile_speed:int = 20
const SPEED:float = 10.0
const SHIFT_SPEED:float = PI / 0.5
var living_npc_count:int = 7 # to be used for UI
var player_character: Character
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
var terrain_dimension:Vector2i = Vector2i(10, 10)
var terrain_tile_size:float = 2 * 3 #(2 * scale of tile)
var space_between_tiles:float = 0.2 # if we want to make the tiles visible or if we want to keep a small space to see the other side
var corner_tile_id_1 = (0 * 10000) + 0
var corner_tile_id_2 = (0 * 10000) + terrain_dimension.y - 1
var corner_tile_id_3 = ((terrain_dimension.x - 1) * 10000) + 0
var corner_tile_id_4 = ((terrain_dimension.x - 1) * 10000) + terrain_dimension.y - 1
var plain_proba:float = 2.0 / 3.0
var board_total_length:Vector2 = Vector2(
	(terrain_dimension.x + (2 * space_between_tiles)) * terrain_tile_size, (terrain_dimension.y + (2 * space_between_tiles)) * terrain_tile_size
	)

# NPC navigation
var navigation_mesh_bale_requested:bool = false

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

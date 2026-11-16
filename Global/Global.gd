extends Node




# Gameplay
var character_count:int = 2
var projectile_speed:int = 50
const SPEED:float = 20.0
const SHIFT_SPEED:float = PI / 0.5

# Detect tile on which the mouse is
var current_tile_pointed_id:int # Used to detect which tile to distant shift (which tile has the mouse on it)
var current_tile_pointed_is_valid:bool = false # If the mouse is on a character the pointer if may no longer be correct
var shift_requested_on_mouse:bool = false

# Level instanciation
var terrain_dimension:Vector2i = Vector2i(10, 10)
var terrain_tile_size:float = 2 * 3 #(2 * scale of tile)
var space_between_tiles:float = 0.1 # if we want to make the tiles visible or if we want to keep a small space to see the other side

# Bonuses
var cannon_bonus_amount = 5
var shift_bonus_amount = 1

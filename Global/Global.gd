extends Node

# Gameplay
var character_count:int = 2
var projectile_speed:int = 50

# Level instanciation
var terrain_dimension:Vector2i = Vector2i(20, 20)
var terrain_tile_size:float = 2 * 2 #(2 * scale of tile)
var space_between_tiles:float = 0.1 # if we want to make the tiles visible or if we want to keep a small space to see the other side

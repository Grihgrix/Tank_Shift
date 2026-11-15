extends Node

@onready var character = $Character
@onready var level = $Level
@onready var Tiles_parent_group = level.get_node("Tiles_parent_group")

# Called when the node enters the scene tree for the first time.
func _ready():
	assign_character_to_tile(character)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	#assign_character_to_tile(character)
	if Global.shift_requested_on_mouse:
		assign_character_to_tile(character)


func assign_character_to_tile(current_character):
	for tile in Tiles_parent_group.get_children():
		if tile.tile_id == current_character.current_tile_id:
			current_character.reparent(tile, true)
			#print(current_character.get_parent())

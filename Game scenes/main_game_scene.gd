extends Node

@onready var player = $Player
@onready var npc_2 = $NPC_2
@onready var character_list:Array = [player, npc_2]

@onready var level = $Level
@onready var Tiles_parent_group = level.get_node("Tiles_parent_group")

# Called when the node enters the scene tree for the first time.
func _ready():
	for character in character_list:
		assign_character_to_tile(character)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	for character in character_list:
		assign_character_to_tile(character)
	#if Global.shift_requested_on_mouse or Global.self_shift_requested:
	#	assign_character_to_tile(character)


func assign_character_to_tile(current_character):
	for tile in Tiles_parent_group.get_children():
		if tile.tile_id == current_character.current_tile_id:
			current_character.reparent(tile, true)

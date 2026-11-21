extends Node

@onready var player = $Up_NavigationRegion3D/Player
@onready var npc_2 = $Up_NavigationRegion3D/NPC_2
@onready var npc_3 = $Up_NavigationRegion3D/NPC_3
@onready var npc_4 = $Up_NavigationRegion3D/NPC_4
@onready var npc_5 = $Up_NavigationRegion3D/NPC_5
@onready var npc_6 = $Up_NavigationRegion3D/NPC_6
@onready var npc_7 = $Up_NavigationRegion3D/NPC_7
@onready var npc_8 = $Up_NavigationRegion3D/NPC_8

@onready var character_list:Array = [player, npc_2, npc_3, npc_4, npc_5, npc_6, npc_7, npc_8]

@onready var level = $Level
@onready var Tiles_parent_group = level.get_node("Tiles_parent_group")

@onready var up_navigation_region_3d = $Up_NavigationRegion3D


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

func _refresh_navigation_region():
	await get_tree().create_timer(0.1).timeout
	up_navigation_region_3d.bake_navigation_mesh()

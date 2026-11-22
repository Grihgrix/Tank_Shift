extends Node

@onready var player = $Player
@onready var npc_2 = $NPC_2
@onready var npc_3 = $NPC_3
@onready var npc_4 = $NPC_4
@onready var npc_5 = $NPC_5
@onready var npc_6 = $NPC_6
@onready var npc_7 = $NPC_7
@onready var npc_8 = $NPC_8

@onready var character_list:Array = [player, npc_2, npc_3, npc_4, npc_5, npc_6, npc_7, npc_8]

@onready var level = $Level
@onready var Tiles_parent_group = level.get_node("Tiles_parent_group")

@onready var up_navigation_region_3d = $Up_NavigationRegion3D


# Called when the node enters the scene tree for the first time.
func _ready():
	for character in character_list:
		assign_character_to_tile(character)
	
	_refresh_navigation_region()
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	for character in character_list:
		assign_character_to_tile(character)
	#if Global.shift_requested_on_mouse or Global.self_shift_requested:
	#	assign_character_to_tile(character)
	
	if Global.navigation_mesh_bale_requested:
		_refresh_navigation_region()


func assign_character_to_tile(current_character):
	for tile in Tiles_parent_group.get_children():
		if tile.tile_id == current_character.current_tile_id:
			current_character.reparent(tile, true)

func _refresh_navigation_region():
	Global.navigation_mesh_bale_requested = false
	await get_tree().create_timer(1).timeout
	
	print("obstacles in UP source group: ", get_tree().get_nodes_in_group("UP_navigation_mesh_source_group"))
	print("obstacles in DOWN source group: ", get_tree().get_nodes_in_group("DOWN_navigation_mesh_source_group"))
	print("region group name: '", up_navigation_region_3d.navigation_mesh.geometry_source_group_name, "'")
	print("source mode: ", up_navigation_region_3d.navigation_mesh.geometry_source_geometry_mode)
	
	up_navigation_region_3d.bake_navigation_mesh(false)
	print("Nav mesh rebaked")

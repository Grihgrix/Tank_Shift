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
@onready var down_navigation_region_3d = $Down_NavigationRegion3D

@export var day_environment: Environment
@export var night_environment: Environment
@onready var day_light = $Day_Light
@onready var night_light = $Night_Light
@onready var world_environment = $WorldEnvironment


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

	_update_lighting()


func assign_character_to_tile(current_character):
	for tile in Tiles_parent_group.get_children():
		if tile.tile_id == current_character.current_tile_id:
			current_character.reparent(tile, true)

func _refresh_navigation_region():
	Global.navigation_mesh_bale_requested = false
	await get_tree().create_timer(1).timeout
	up_navigation_region_3d.bake_navigation_mesh(false)
	down_navigation_region_3d.bake_navigation_mesh(false)

var day_amount = 1.0 # 1.0 = day, -1.0 = night
func _update_lighting():
	var new_day_amount = player.global_basis.y.dot(Vector3.UP)
	print("new_day_amount: ", new_day_amount)

	if new_day_amount != day_amount:
		day_amount = new_day_amount
		if day_amount > 0:
			world_environment.environment = day_environment
			day_light.visible = true
			night_light.visible = false
		else:
			world_environment.environment = night_environment
			day_light.visible = false
			night_light.visible = true

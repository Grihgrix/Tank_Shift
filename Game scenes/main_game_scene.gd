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

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() and event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		snapshot(get_tree().current_scene)

func snapshot(root: Node) -> void:
	root.scene_file_path = ""
	_claim(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed: %s" % err)
		return
	var path := "res://snapshots/snap_%d.tscn" % Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute("res://snapshots")
	ResourceSaver.save(packed, path)
	print("Saved ", path)

func _claim(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.scene_file_path = ""   # stop it being saved as an instance reference
		child.owner = root           # make it part of the saved scene
		_claim(child, root)

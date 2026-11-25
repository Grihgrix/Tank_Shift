extends Node3D

# Define in variable the scene we will instantiate (the projectile scene)
const PROJECTILE_RC = preload("uid://suu8idgxtenm")



# Variables necessary to properly spawn the projectile
@export var projectiles_parent_group:String = "projectile_parent"
var projectiles_node:Node


# Variables needed for orientation
@onready var character = $"../../../.."
@onready var tourelle = $"../../Tourelle"
@onready var shooter_timer = $Shooter_Timer
@onready var npc_is_shooting_timer = $"../../../../NPC_is_Shooting_Timer"



# Called when the node enters the scene tree for the first time.
func _ready():
	# Ensures the projectile node is part of a group separate from the character, so it is no longer affected by the character movements after being spawned
	projectiles_node = get_tree().get_first_node_in_group(projectiles_parent_group)


func _physics_process(delta):
	
	if npc_is_shooting_timer.is_stopped():
		npc_is_shooting_timer.start(round(randf_range(1,3)))
		if character.npc_is_shooting:
			character.npc_is_shooting = false
		else:
			character.npc_is_shooting = true
	
	
	if character.is_player and character.is_alive and Input.is_action_just_released("Shoot") and shooter_timer.is_stopped():
		shooter_timer.start(Global.shoot_cooldown)
		shoot_rc()
	# Test to ensure that NPC and player death works
	elif not character.is_player and character.is_alive and shooter_timer.is_stopped() and character.npc_is_shooting and character.current_state == "Attaque":
		shooter_timer.start(Global.shoot_cooldown)
		shoot_rc()

func shoot_rc():
	var projectile_rc:Node = PROJECTILE_RC.instantiate() # Intantiate new projectile
	projectiles_node.add_child(projectile_rc)
	projectile_rc.global_transform = global_transform

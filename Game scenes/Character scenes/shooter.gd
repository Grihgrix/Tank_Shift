extends Node3D

# Define in variable the scene we will instantiate (the projectile scene)
const PROJECTILE = preload("res://Game scenes/Character scenes/projectile.tscn")
const PROJECTILE_RC = preload("uid://suu8idgxtenm")



# Variables necessary to properly spawn the projectile
@export var projectiles_parent_group:String = "projectile_parent"
var projectiles_node:Node


# Variables needed for orientation
@onready var character = $"../../../.."
@onready var tourelle = $"../../Tourelle"
@onready var timer = $Timer


# Called when the node enters the scene tree for the first time.
func _ready():
	# Ensures the projectile node is part of a group separate from the character, so it is no longer affected by the character movements after being spawned
	projectiles_node = get_tree().get_first_node_in_group(projectiles_parent_group)


func _physics_process(delta):
	if Input.is_action_just_released("Shoot") and timer.is_stopped():
		timer.start(1)
		print("Shoot")
		shoot_rc()

func shoot_rc():
	print("Function starts")
	var projectile_rc:Node = PROJECTILE_RC.instantiate() # Intantiate new projectile
	projectiles_node.add_child(projectile_rc)
	projectile_rc.global_transform = global_transform
	print("Function stops")

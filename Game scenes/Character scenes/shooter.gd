extends Node3D

# Define in variable the scene we will instantiate (the projectile scene)
const PROJECTILE = preload("res://Game scenes/Character scenes/projectile.tscn")

# Variables necessary to properly spawn the projectile
@export var projectiles_parent_group:String = "projectile_parent"
var projectiles_node:Node

# Variables needed for orientation
@onready var tourelle = $"../.."
@onready var character = $"../../../.."


# Called when the node enters the scene tree for the first time.
func _ready():
	# Ensures the projectile node is part of a group separate from the character, so it is no longer affected by the character movements after being spawned
	projectiles_node = get_tree().get_first_node_in_group(projectiles_parent_group)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_released("Shoot"):
		_shoot()


func _shoot():
	
	# Spawn the projectile
	var projectile:Node = PROJECTILE.instantiate() # Intantiate new projectile
	projectiles_node.add_child(projectile)
	
	# Define initial position
	projectile.global_position = global_position # Necessary if in a different node
	
	# Give the projectile an initial speed
	projectile.linear_velocity.x = - Global.projectile_speed * sin(tourelle.rotation.y + character.rotation.y)
	projectile.linear_velocity.y = 0
	projectile.linear_velocity.z = - Global.projectile_speed * cos(tourelle.rotation.y + character.rotation.y)

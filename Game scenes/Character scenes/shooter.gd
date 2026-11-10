extends Node3D

# Define in variable the scene we will instantiate (the projectile scene)
const PROJECTILE = preload("res://Game scenes/Character scenes/projectile.tscn")

# Variables necessary to properly spawn the projectile
@export var projectiles_parent_group:String = "projectile_parent"
var projectiles_node:Node


# Variables needed for orientation
@onready var character = $"../../../.."
@onready var tourelle = $"../../Tourelle"

@onready var position_delta_x:float = tourelle.global_position.x - global_position.x
@onready var position_delta_z:float = tourelle.global_position.z - global_position.z
@onready var position_delta_xz:float


# Called when the node enters the scene tree for the first time.
func _ready():
	# Ensures the projectile node is part of a group separate from the character, so it is no longer affected by the character movements after being spawned
	projectiles_node = get_tree().get_first_node_in_group(projectiles_parent_group)
	
	# Find the length between the 2 points we are comparing for linear velocity
	position_delta_x = tourelle.global_position.x - global_position.x
	position_delta_z = tourelle.global_position.z - global_position.z
	
	position_delta_xz = sqrt(position_delta_x * position_delta_x) + (position_delta_z * position_delta_z)
	#print(position_delta_xz)


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
	
	position_delta_x = tourelle.global_position.x - global_position.x
	position_delta_z = tourelle.global_position.z - global_position.z
	#print("position_delta_x = " + str(position_delta_x) + " position_delta_z = " + str(position_delta_z))
	projectile.linear_velocity.x = -Global.projectile_speed * position_delta_x / position_delta_xz
	projectile.linear_velocity.z = -Global.projectile_speed * position_delta_z / position_delta_xz

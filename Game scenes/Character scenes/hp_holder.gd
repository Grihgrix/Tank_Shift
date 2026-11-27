@tool
extends Node3D
var character : Character

var max_hp : int
var relative_position : Vector3

@export var radius : float
@export var base_angle : float
@export var angle_offset_between_bullets : float
@export var bullet_scene : PackedScene
@export var bullet_full_material : Material
@export var bullet_empty_material : Material

@export_tool_button("Setup", "Callable") var setup_callback : Callable = _setup
@export_tool_button("Clear", "Callable") var clear_callback : Callable = _clear

func _ready() -> void:
	character = get_parent()
	character.on_hp_changed.connect(_hp_changed)
	relative_position = global_position - character.global_position

	if not Engine.is_editor_hint():
		call_deferred("_setup")
		visible = false

func _setup():
	reparent(get_tree().current_scene)
	rotation = Vector3.ZERO
	max_hp = character.hp

	for hp in range(max_hp):
		var bullet = bullet_scene.instantiate()
		self.add_child(bullet)
		# Position is based on the angle of the bullet in relation to the base angle and the offset between bullets
		var angle = deg_to_rad( base_angle) + (deg_to_rad(angle_offset_between_bullets) * hp) - (max_hp * deg_to_rad(angle_offset_between_bullets) / 2.)
		bullet.position = Vector3(radius * cos(angle), 0, radius * sin(angle))


func _clear():
	for bullet in get_children():
		if bullet is Node3D:
			bullet.queue_free()

func _hp_changed(new_hp:int) -> void:
	visible = new_hp < max_hp and new_hp > 0
	for i in range(max_hp):
		var bullet = get_child(i)
		if bullet is Node3D:
			if i < new_hp:
				bullet.material_override = bullet_full_material
			else:
				bullet.material_override = bullet_empty_material

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return

	global_position = character.global_position + relative_position
	global_rotation.x = character.global_rotation.x
	global_rotation.z = character.global_rotation.z
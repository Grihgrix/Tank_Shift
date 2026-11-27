extends CanvasLayer

@export var enemy_alive_icon: Texture2D
@export var enemy_dead_icon: Texture2D
@export var enemy_icon_scene: PackedScene

@onready var cooldown_shoot: ColorRect = $VBoxContainer/Cooldown_Shoot
@onready var cooldown_shift: ColorRect = $Cooldown_Shift_Control/Cooldown_Shift
@onready var space_input: TextureRect = $Cooldown_Shift_Control/Space_Input
@onready var cooldown_shift_control: Control = $Cooldown_Shift_Control
@onready var enemy_icons_container: HBoxContainer = $PanelContainer/MarginContainer_Horizontal/HBoxContainer_EnemiesIcons

var initial_living_npc_count:int

func _ready() -> void:
	Global.on_shift_cooldown_started.connect(_on_shift_cooldown_started)

	initial_living_npc_count = Global.living_npc_count
	for i in range(Global.living_npc_count):
		var enemy_icon = enemy_icon_scene.instantiate()
		enemy_icons_container.add_child(enemy_icon)

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
#	_set_cooldown_progress(Global.player_character.shoot_timer.time_left / Global.shoot_cooldown, cooldown_shoot)
	_set_cooldown_progress(Global.player_character.shift_timer.time_left / Global.shift_cooldown, cooldown_shift)

	if Global.living_npc_count < initial_living_npc_count:
		for i in range(initial_living_npc_count):
			var enemy_icon = enemy_icons_container.get_child(i)
			if i < Global.living_npc_count:
				enemy_icon.texture = enemy_alive_icon
			else:
				enemy_icon.texture = enemy_dead_icon

func _set_cooldown_progress(cooldown: float, rect: ColorRect) -> void:
	rect.material.set_shader_parameter("progress", 1. - cooldown)
	space_input.self_modulate = Color.WHITE if cooldown <= 0.01 else Color(1, 1, 1, 0.5)

func _on_shift_cooldown_started() -> void:
	# Tween quick animation of the cooldown bar for a "press" effect, size decreases directly then increases back to normal size
	var tween = get_tree().create_tween()
	cooldown_shift_control.scale = Vector2(0.75, 0.75)
	tween.tween_property(cooldown_shift_control, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_SINE)

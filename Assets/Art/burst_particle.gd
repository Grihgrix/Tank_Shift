@tool
extends Node3D
class_name BurstParticle

@export_tool_button("Burst", "Callable") var burst_callback : Callable = burst
@export var burst_on_ready : bool = true

func _ready() -> void:
	if not Engine.is_editor_hint():
		if burst_on_ready:
			burst()

var amount_started : int = 0

func burst() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true
			amount_started += 1
			child.finished.connect(_on_particle_finished)

func _on_particle_finished() -> void:
	amount_started -= 1
	if amount_started <= 0:
		if not Engine.is_editor_hint():
			queue_free()
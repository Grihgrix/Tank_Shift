extends Control

@onready var map_size
@onready var map_type


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_launch_button_pressed():
	get_tree().change_scene_to_file("res://Game scenes/Main_game_scene.tscn")

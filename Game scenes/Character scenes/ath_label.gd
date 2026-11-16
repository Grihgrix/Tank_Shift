extends RichTextLabel

@onready var character = $"../.."

var line_1:String
var line_2:String

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	line_1 =  "[b][color=orange]Ammo: " + str(character.canon_ammo_count) + "[/color]\n"
	line_2 = "[color=light_blue]Shift: " + str(character.shift_ammo_count)
	text = line_1 + line_2

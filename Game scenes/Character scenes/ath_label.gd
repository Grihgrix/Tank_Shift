extends RichTextLabel

@onready var character = $"../.."

@onready var shooter_timer = $"../../Proto_tank/Tourelle/Head/Shooter/Shooter_Timer"
@onready var shift_timer = $"../../Shift_Timer"


var line_1:String
var line_2:String

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	line_1 =  "[b][color=orange]Ammo cooldown : " + str(round(shooter_timer.time_left * 10) / 10) + "[/color]\n"
	line_2 = "[color=light_blue]Shift cooldown : " + str(round(shift_timer.time_left * 10) / 10)
	text = line_1 + line_2
	#text = ""

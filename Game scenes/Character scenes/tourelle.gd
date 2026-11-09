extends Node3D

@onready var group_tourelle = $"."
@onready var tourelle = $Tourelle


# Variable for mouse angle measurements and calculations
@onready var current_tourelle_viewport_position:Vector2 = get_viewport().get_camera_3d().unproject_position(tourelle.global_position)
@onready var current_mouse_postion:Vector2
@onready var tourelle_mouse_positon:Vector2
@onready var mouse_viewport_angular_position:float
@onready var cosinus_cam:String = "+"
@onready var sinus_cam:String = "-"
@onready var mouse_viewport_angular_position_Ref_tour:float

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass



# Only triggers when the mouse is clicked are moves
func _input(event):
	# Mouse in viewport coordinates.
	#if event is InputEventMouseButton:
	#	pass
	if event is InputEventMouseMotion:
		# Find mouse position
		current_mouse_postion = event.position
		# Find tourelle position
		current_tourelle_viewport_position = get_viewport().get_camera_3d().unproject_position(tourelle.global_position)
		# Calculate mouse postion relative to tourele in the viewport
		tourelle_mouse_positon = current_mouse_postion - current_tourelle_viewport_position
		
		# Calculate angular position of the mouse with the tourelle being (0,0)
		mouse_viewport_angular_position = atan2(-tourelle_mouse_positon.y, tourelle_mouse_positon.x)
		
		if cos(mouse_viewport_angular_position) >=0:
			cosinus_cam = "+"
		else:
			cosinus_cam = "-"
		if sin(mouse_viewport_angular_position) >=0:
			sinus_cam = "+"
		else:
			sinus_cam = "-"
		
		# Convert viewport angle to tourelle angle
		if  cosinus_cam == "-" and sinus_cam == "-":
			mouse_viewport_angular_position_Ref_tour = (1.5 * PI) + mouse_viewport_angular_position
		elif cosinus_cam == "+"  and sinus_cam == "-":
			mouse_viewport_angular_position_Ref_tour = -0.5 * PI + mouse_viewport_angular_position
		elif cosinus_cam == "+"  and sinus_cam == "+":
			mouse_viewport_angular_position_Ref_tour = (- 0.5 * PI) + mouse_viewport_angular_position
		elif cosinus_cam == "-"  and sinus_cam == "+":
			mouse_viewport_angular_position_Ref_tour = (1.5 * PI) + mouse_viewport_angular_position
		
		# Assign new angle to the tourelle
		group_tourelle.rotation.y = mouse_viewport_angular_position_Ref_tour

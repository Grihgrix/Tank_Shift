extends Area3D

@onready var shift_mesh = $Shift_Mesh
@onready var ammo_mesh = $Ammo_Mesh


@onready var mesh_choices:Array = [0,1,2] # 0 = no mesh active, 1 = shift active, 2 = ammo active
@onready var active_mesh:int = 0
@onready var shift_bonus:int = 0
@onready var ammo_bonus:int = 0

@onready var board_side_choices:Array = [-1,1] # 1 = Upside, -1 = downside
@onready var is_upside_or_down_side:int = board_side_choices.pick_random()


# Called when the node enters the scene tree for the first time.
func _ready():
	# At the begining the collectibles are not active
	shift_mesh.visible = false
	ammo_mesh.visible = false
	
	# set position to be above or below the board
	global_position.y = 1 * is_upside_or_down_side


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	# Switch randomly the bonus to the other side of the board
	if randi_range(-2000, 2000) == 0:
		is_upside_or_down_side = - is_upside_or_down_side
		global_position.y = 1 * is_upside_or_down_side
	
	# Check if we should change the active bonus
	if randi_range(-2000, 2000) == 0:
		active_mesh = mesh_choices.pick_random()
	
	# Determine if one of the bonus shoulb be pickable and visible
	if active_mesh == 0:
		shift_mesh.visible = false
		ammo_mesh.visible = false
		shift_bonus = 0
		ammo_bonus = 0
	elif active_mesh == 1:
		shift_mesh.visible = true
		ammo_mesh.visible = false
		shift_bonus = 1
		ammo_bonus = 0
	elif active_mesh == 2:
		shift_mesh.visible = false
		ammo_mesh.visible = true
		shift_bonus = 0
		ammo_bonus = 1
	else:
		shift_mesh.visible = false
		ammo_mesh.visible = false
		shift_bonus = 0
		ammo_bonus = 0
	
#character.canon_ammo_count
#character.shift_ammo_count


func _on_body_entered(body):
	# Needs to be the same collision mask 
	if body is CharacterBody3D:
		# assign the bonus to the character's wallet
		body.shift_ammo_count += shift_bonus * Global.shift_bonus_amount
		body.canon_ammo_count += ammo_bonus * Global.cannon_bonus_amount
		# Deactivate the collectible
		active_mesh = 0

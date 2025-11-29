extends Node2D
class_name InputHandler

signal jump_pressed
signal light_pressed
signal heavy_pressed
signal pause_pressed

var move_dir: float = 0.0
var aim_vector: Vector2 = Vector2.ZERO
var drop_pressed: bool = false

var jump_buffer_time := 0.15
var jump_buffer := false
var jump_timer := 0.0

var using_controller := false


func _ready():
	Input.set_use_accumulated_input(false)


func _process(delta):
	_read_movement()
	_read_jump(delta)
	_read_attacks()
	_read_pause()
	_read_aim()


# ---------------------------------------------------------
# MOVIMENTO
# ---------------------------------------------------------
func _read_movement():
	move_dir = Input.get_axis("left_movement", "right_movement")
	drop_pressed = Input.is_action_pressed("down_movement")


# ---------------------------------------------------------
# PULO (buffer + sinal)
# ---------------------------------------------------------
func _read_jump(delta):
	if Input.is_action_just_pressed("jump"):
		jump_pressed.emit()
		jump_buffer = true
		jump_timer = jump_buffer_time

	if jump_buffer:
		jump_timer -= delta
		if jump_timer <= 0:
			jump_buffer = false


# ---------------------------------------------------------
# ATAQUES (sinais)
# ---------------------------------------------------------
func _read_attacks():
	if Input.is_action_just_pressed("shoot_light"):
		light_pressed.emit()

	if Input.is_action_just_pressed("shoot_heavy"):
		heavy_pressed.emit()


# ---------------------------------------------------------
# PAUSE
# ---------------------------------------------------------
func _read_pause():
	if Input.is_action_just_pressed("pause"):
		pause_pressed.emit()


# ---------------------------------------------------------
# AIM — Mouse OU Controle
# ---------------------------------------------------------
func _read_aim():
	var controller_vec := Vector2(
		Input.get_action_strength("aim_right") - Input.get_action_strength("aim_left"),
		Input.get_action_strength("aim_down") - Input.get_action_strength("aim_up")
	)

	if controller_vec.length() > 0.3:
		using_controller = true
		aim_vector = controller_vec.normalized()
	else:
		using_controller = false
		var parent := get_parent()
		if parent:
			aim_vector = (get_global_mouse_position() - parent.global_position).normalized()

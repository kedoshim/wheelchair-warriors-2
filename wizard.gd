extends CharacterBody2D

class_name Wizard

# --- CONSTANTES ---
const SPEED := 130
const JUMP_VELOCITY := -320
const WALL_JUMP_FORCE := Vector2(250, -320)
const COYOTE_TIME := 0.15
const JUMP_BUFFER_TIME := 0.15
const MAX_FALL_SPEED := 900

# --- NODES ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var wall_left: RayCast2D = $wall_check_left
@onready var wall_right: RayCast2D = $wall_check_right
@onready var jump_buffer: Timer = $jump_buffer

# --- POWERS ---
# nó Inventory dentro do Player (ajuste o caminho se for diferente)
@onready var inventory: Inventory = $InventoryComponent

# exports visíveis no Inspector do Player — cada um delega para set/get
@export_category("Powers")
@export var light_attack: ElementalPower
@export var heavy_attack: ElementalPower
@export var passive: ElementalPower


# --- VARIÁVEIS ---
var coyote_counter := 0.0
var can_wall_jump := false
var input_buffered := false
var facing := 1 # 1 = direita, -1 = esquerda (default: direita)

func _ready():
	jump_buffer.wait_time = JUMP_BUFFER_TIME
	
	if inventory:
		if light_attack:
			inventory.light_attack_power = light_attack
		if heavy_attack:
			inventory.heavy_attack_power = heavy_attack
		if passive:
			inventory.passive_power = passive

func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	handle_input()
	handle_movement(delta)
	handle_animations()
	move_and_slide()

func handle_gravity(delta):
	if not is_on_floor():
		coyote_counter -= delta
		velocity += get_gravity() * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)
	else:
		coyote_counter = COYOTE_TIME
		can_wall_jump = false
		

func handle_input():
	# BUFFERING DE PULO
	if Input.is_action_just_pressed("jump"):
		input_buffered = true
		jump_buffer.start()

	# se o timer acabar, limpar buffer
	if not jump_buffer.is_stopped() and jump_buffer.time_left <= 0:
		input_buffered = false

	# atravessar plataforma ao apertar para baixo
	if Input.is_action_pressed("down_movement"):
		set_collision_mask_value(1, false) # desativa colisão com plataformas
	else:
		set_collision_mask_value(1, true)
		

func handle_movement(delta):
	var direction := Input.get_axis("left_movement", "right_movement")

	# FLIP
	if direction != 0:
		facing = sign(direction)
		anim.flip_h = facing == -1

	# ACELERAÇÃO
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 2)

	# CHECAR WALL SLIDE
	var on_wall := (wall_left.is_colliding() or wall_right.is_colliding()) and not is_on_floor()

	if on_wall:
		velocity.y = min(velocity.y, 80)
		can_wall_jump = true

	# ✨ PULO NORMAL OU BUFFERADO / COYOTE / WALL JUMP
	if input_buffered:
		try_jump()

func jump():
	velocity.y = JUMP_VELOCITY
	$JumpSound.play()
	
func try_jump():
	if coyote_counter > 0:
		jump()
	elif can_wall_jump:
		wall_jump()
	input_buffered = false
	jump_buffer.stop()


func wall_jump():
	if wall_left.is_colliding():
		velocity = WALL_JUMP_FORCE
		$JumpSound.play()
	else:
		velocity = Vector2(-WALL_JUMP_FORCE.x, WALL_JUMP_FORCE.y)
		$JumpSound.play()
	can_wall_jump = false

func handle_animations():
	if anim.animation == "hit" or anim.animation == "death":
		return

	if not is_on_floor():
		anim.play("roll") # usar roll como animação aérea
	elif abs(velocity.x) > 10:
		anim.play("run")
	else:
		anim.play("idle")

extends CharacterBody2D
class_name Wizard

# ---------------------------------------------------------
# CONSTANTES
# ---------------------------------------------------------
const SPEED := 130
const JUMP_VELOCITY := -320
const WALL_JUMP_FORCE := Vector2(250, -320)
const COYOTE_TIME := 0.15
const JUMP_BUFFER_TIME := 0.15
const MAX_FALL_SPEED := 900

# ---------------------------------------------------------
# NODES
# ---------------------------------------------------------
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var wall_left: RayCast2D = $wall_check_left
@onready var wall_right: RayCast2D = $wall_check_right
@onready var jump_buffer: Timer = $jump_buffer
@onready var input: InputHandler = $InputHandler
@onready var shooting: ShootingManagerComponent = $ShootingManager
@onready var inventory: Inventory = $Inventory
@onready var health: HealthComponent = $Health



# ---------------------------------------------------------
# POWERS
# ---------------------------------------------------------
@export_category("Powers")
@export var light_attack: ElementalPower
@export var heavy_attack: ElementalPower
@export var passive: ElementalPower


@export var camera: Camera2D


# ---------------------------------------------------------
# Configs
# ---------------------------------------------------------
@export var spawn_invulnerability_time := 2.0 # seconds

var is_invulnerable := false
@onready var invul_timer: Timer = $InvulnerabilityTimer

# ---------------------------------------------------------
# VARIÁVEIS
# ---------------------------------------------------------
var coyote_counter := 0.0
var can_wall_jump := false
var input_buffered := false
var facing := 1

# multiplayer sync
var syncPos: Vector2
var syncRot := 0.0


# =========================================================
# READY
# =========================================================
func _ready():
	$MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())
	
	# Start invulnerability
	become_invulnerable(spawn_invulnerability_time)

	jump_buffer.wait_time = JUMP_BUFFER_TIME

	# carregar poderes
	if inventory:
		if light_attack: inventory.light_attack_power = light_attack
		if heavy_attack: inventory.heavy_attack_power = heavy_attack
		if passive:      inventory.passive_power = passive

	# conectar eventos de input
	input.jump_pressed.connect(_on_jump_pressed)
	input.light_pressed.connect(_on_light_pressed)
	input.heavy_pressed.connect(_on_heavy_pressed)
	input.pause_pressed.connect(_on_pause)


# ---------------------------------------------------------
# EVENTOS DE INPUT
# ---------------------------------------------------------
func _on_jump_pressed():
	input_buffered = true
	jump_buffer.start()

func _on_light_pressed():
	shooting.shoot_light()

func _on_heavy_pressed():
	shooting.shoot_heavy()

func _on_pause():
	get_tree().paused = !get_tree().paused


# =========================================================
# PHYSICS
# =========================================================
func _physics_process(delta: float) -> void:

	if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():

		handle_aim()
		handle_gravity(delta)
		handle_platform_drop()
		handle_movement(delta)
		handle_jump_buffer_logic()
		handle_animations()

		move_and_slide()

		# sync send
		syncPos = global_position
		syncRot = shooting.rotation_degrees

	else:
		# sync receive (smooth)
		global_position = global_position.lerp(syncPos, 0.5)
		shooting.rotation_degrees = lerpf(shooting.rotation_degrees, syncRot, 0.5)


# =========================================================
# GRAVIDADE / PULO
# =========================================================
func handle_gravity(delta):
	if not is_on_floor():
		coyote_counter -= delta
		velocity += get_gravity() * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)
	else:
		coyote_counter = COYOTE_TIME
		can_wall_jump = false


func handle_jump_buffer_logic():
	if input_buffered:
		try_jump()

	# limpar buffer quando timer expira
	if not jump_buffer.is_stopped() and jump_buffer.time_left <= 0.0:
		input_buffered = false


func try_jump():
	if coyote_counter > 0:
		jump()
	elif can_wall_jump:
		wall_jump()

	input_buffered = false
	jump_buffer.stop()


func jump():
	velocity.y = JUMP_VELOCITY
	$JumpSound.play()


func wall_jump():
	if wall_left.is_colliding():
		velocity = WALL_JUMP_FORCE
	else:
		velocity = Vector2(-WALL_JUMP_FORCE.x, WALL_JUMP_FORCE.y)

	$JumpSound.play()
	can_wall_jump = false


# =========================================================
# MOVIMENTO
# =========================================================
func handle_movement(delta):
	var direction := input.move_dir

	# FLIP
	if direction != 0:
		facing = sign(direction)
		anim.flip_h = facing == -1

	# ACELERAÇÃO
	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 2)

	# WALL SLIDE
	var on_wall := (wall_left.is_colliding() or wall_right.is_colliding()) and not is_on_floor()

	if on_wall:
		velocity.y = min(velocity.y, 80)
		can_wall_jump = true
		
func handle_aim():
	var shooting_manager = $ShootingManager
	var target = input.aim_vector
	if shooting_manager:
		shooting_manager.update_aim(target)


func become_invulnerable(duration: float):
	var hurtbox_component: HurtboxComponent = $Hurtbox
	if hurtbox_component:
		hurtbox_component.is_invulnerable = true
	invul_timer.start(duration)
	flicker_effect(true)
	
func _on_invulnerability_timer_timeout():
	input.active = true
	var hurtbox_component: HurtboxComponent = $Hurtbox
	if hurtbox_component:
		hurtbox_component.is_invulnerable = false
	flicker_effect(false)
	modulate = Color(1, 1, 1, 1) # restore normal appearance

var flicker_tween: Tween

func flicker_effect(active: bool):
	if active:
		if flicker_tween and flicker_tween.is_running():
			flicker_tween.kill()
			
		flicker_tween = create_tween()
		flicker_tween.set_loops() # infinite until stopped
		
		flicker_tween.tween_property(self, "modulate:a", 0.3, 0.1)
		flicker_tween.tween_property(self, "modulate:a", 1.0, 0.1)
	else:	
		if flicker_tween:
			flicker_tween.kill()
	modulate = Color(1, 1, 1, 1)


# =========================================================
# DROP THROUGH PLATFORMS
# =========================================================
func handle_platform_drop():
	if input.drop_pressed:
		set_collision_mask_value(1, false)
	else:
		set_collision_mask_value(1, true)


# =========================================================
# ANIMAÇÕES
# =========================================================
func handle_animations():
	if anim.animation in ["hit", "death"]:
		return

	if not is_on_floor():
		anim.play("roll")
	elif abs(velocity.x) > 10:
		anim.play("run")
	else:
		anim.play("idle")

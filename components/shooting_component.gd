extends Node2D
class_name ShootingComponent

@export var inventory: Inventory

var target: Vector2
var origin: Vector2
var user: Node2D

# Tracks internal cooldown state (per attack type)
var light_cooldown: bool = false
var heavy_cooldown: bool = false


# -------------------------------------------------------
#   INITIALIZATION
# -------------------------------------------------------

func _ready():
	user = get_parent()


func _process(_delta: float) -> void:
	target = get_global_mouse_position()
	origin = $Marker2D.global_position
	look_at(target)
	handle_shooting()


# -------------------------------------------------------
#   INPUT HANDLING
# -------------------------------------------------------

func handle_shooting():
	if Input.is_action_just_pressed("shoot_light") and not light_cooldown:
		use_power("light")

	if Input.is_action_just_pressed("shoot_heavy") and not heavy_cooldown:
		use_power("heavy")


# -------------------------------------------------------
#   USE POWER ENTRY POINT
# -------------------------------------------------------

func use_power(attack_type: String):
	var power: ElementalPower = null

	match attack_type:
		"light":
			power = inventory.light_attack_power
		"heavy":
			power = inventory.heavy_attack_power

	if not power:
		return

	var actions = (
		power.get_light_attack(user, origin, target)
		if attack_type == "light"
		else power.get_heavy_attack(user, origin, target)
	)

	_execute_actions(actions, attack_type)


# -------------------------------------------------------
#   EXECUTION OF ABILITY ACTIONS
# -------------------------------------------------------

func _execute_actions(actions, attack_type: String):
	if actions == null:
		return

	# Single action
	if actions is AbilityAction:
		actions.execute(self)

	# Multiple actions
	elif actions is Array:
		for action in actions:
			if action is AbilityAction:
				action.execute(self)


# -------------------------------------------------------
#   WORLD HELPERS (used by SpawnNodesAction)
# -------------------------------------------------------

func add_to_world(node: Node):
	get_tree().current_scene.add_child(node)


func add_timer(duration: float, callback: Callable) -> Timer:
	var t := Timer.new()
	t.wait_time = duration
	t.one_shot = true
	add_child(t)
	t.timeout.connect(callback)
	t.start()
	return t


# -------------------------------------------------------
#   COOLDOWN SYSTEM (used by CooldownAction)
# -------------------------------------------------------

func start_power_cooldown(duration: float, attack_type: String = "light"):
	if attack_type == "light":
		light_cooldown = true
		add_timer(duration, func(): light_cooldown = false)
	else:
		heavy_cooldown = true
		add_timer(duration, func(): heavy_cooldown = false)


# -------------------------------------------------------
#   CAST TIME (used by CastTimeAction)
# -------------------------------------------------------

func perform_after_delay(delay: float, callback: Callable):
	add_timer(delay, callback)

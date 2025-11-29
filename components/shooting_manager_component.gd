extends Node2D
class_name ShootingManagerComponent

@export var inventory: Inventory

var target: Vector2
var origin: Vector2
var user: Node2D

var light_cooldown: bool = false
var heavy_cooldown: bool = false

@export var max_aim_distance := 300.0

func _ready():
	user = get_parent()


func update_aim(aim_vector: Vector2):
	# origem do disparo
	origin = $Marker2D.global_position

	# destino baseado no vetor de mira externo
	target = origin + (aim_vector.normalized() * max_aim_distance)

	# gira o jogador para mirar corretamente
	look_at(target)


func shoot_light():
	if not light_cooldown:
		use_power("light")


func shoot_heavy():
	if not heavy_cooldown:
		use_power("heavy")


func use_power(attack_type: String):
	#print_debug("using power ", attack_type)

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

	_execute_actions.rpc(actions, attack_type)


@rpc("any_peer", "call_local")
func _execute_actions(actions, attack_type: String):
	print_debug("executing action for player ", multiplayer.get_unique_id())
	if actions == null:
		return

	if actions is AbilityAction:
		actions.execute(self)
	elif actions is Array:
		for action in actions:
			if action is AbilityAction:
				action.execute(self)


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


func start_power_cooldown(duration: float, attack_type: String = "light"):
	if attack_type == "light":
		light_cooldown = true
		add_timer(duration, func(): light_cooldown = false)
	else:
		heavy_cooldown = true
		add_timer(duration, func(): heavy_cooldown = false)


func perform_after_delay(delay: float, callback: Callable):
	add_timer(delay, callback)

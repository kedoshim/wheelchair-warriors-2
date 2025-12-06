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
	origin = $Marker2D.global_position
	target = origin + (aim_vector.normalized() * max_aim_distance)
	look_at(target)


# ============================================================
# PUBLIC SHOOT REQUESTS (CLIENT SIDE)
# ============================================================

func shoot_light():
	if not light_cooldown:
		request_use_power("light")


func shoot_heavy():
	if not heavy_cooldown:
		request_use_power("heavy")


func request_use_power(attack_type: String):
	# Se servidor → executa direto
	if multiplayer.is_server():
		_server_use_power(attack_type, origin, target)
	else:
		# Cliente → envia RPC para o servidor
		rpc_id(1, "server_use_power", attack_type, origin, target)
	

# ============================================================
# RPC: SERVER RECEBE O PEDIDO DE TIRO
# ============================================================

@rpc("any_peer")
func server_use_power(attack_type: String, origin_pos: Vector2, target_pos: Vector2):
	if not multiplayer.is_server():
		return

	_server_use_power(attack_type, origin_pos, target_pos)


func _server_use_power(attack_type, origin_pos, target_pos):
	if target_pos == Vector2(0,0) and origin_pos == Vector2(0,0):
		return
		
	var power: ElementalPower = null

	match attack_type:
		"light":
			if light_cooldown: return
			power = inventory.light_attack_power

		"heavy":
			if heavy_cooldown: return
			power = inventory.heavy_attack_power

	if not power:
		return

	# Gera a lista de ações no servidor
	var actions = (
		power.get_light_attack(user, origin_pos, target_pos)
		if attack_type == "light"
		else power.get_heavy_attack(user, origin_pos, target_pos)
	)

	_execute_actions(actions, attack_type)

	# Replica visualmente/funcionalmente para todos os clientes
	rpc("client_replicate_action", attack_type, origin_pos, target_pos)


# ============================================================
# CLIENT EXECUTES VISUAL COPY OF THE SERVER ACTION
# ============================================================

@rpc("call_remote")
func client_replicate_action(attack_type: String, origin_pos: Vector2, target_pos: Vector2):
	if multiplayer.is_server():
		return  # servidor já executou a ação real

	# Criar versão visual local
	var power: ElementalPower = null

	match attack_type:
		"light":
			power = inventory.light_attack_power
		"heavy":
			power = inventory.heavy_attack_power

	if not power:
		return

	var actions = (
		power.get_light_attack(user, origin_pos, target_pos)
		if attack_type == "light"
		else power.get_heavy_attack(user, origin_pos, target_pos)
	)

	_execute_actions(actions, attack_type)


# ============================================================
# ACTION EXECUTION
# ============================================================

func _execute_actions(actions, attack_type: String):
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


# ============================================================
# TIMERS / COOLDOWNS
# ============================================================

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

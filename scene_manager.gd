extends Node2D

@export var PlayerScene: PackedScene
@export var default_camera: Camera2D
@export var respawn_ui: RespawnUI

@export var light_attack: ElementalPower
@export var heavy_attack: ElementalPower

var spawn_points = []
var players := {}        # [player_id] = Player instance (sempre existe enquanto a partida roda)
var dead_players := {}   # [player_id] = true quando está morto (mas node continua na cena)

func _ready() -> void:
	print("[WORLD] _ready called")

	default_camera.enabled = false
	spawn_points = get_tree().get_nodes_in_group("PlayerSpawnPoint")

	var camera = Camera2D.new()
	camera.name = "GameplayCamera"
	camera.zoom = Vector2(2.71, 2.71)

	var index := 0

	for i in GameManager.players:
		var player_id = GameManager.players[i].id
		var player_name = GameManager.players[i].name
		var currentPlayer: Wizard = PlayerScene.instantiate()
		
		currentPlayer.player_name = player_name
		currentPlayer.player_id = player_id
		
		save_original_collision_state(currentPlayer)

		print("[WORLD] Spawning player ", player_id)

		players[player_id] = currentPlayer
		currentPlayer.name = str(player_id)

		# posição de spawn
		for spawn in spawn_points:
			if spawn.name == str(index):
				currentPlayer.global_position = spawn.global_position

		# ataques
		currentPlayer.light_attack = light_attack
		currentPlayer.heavy_attack = heavy_attack

		add_child(currentPlayer)

		# este é o jogador local?
		if player_id == multiplayer.get_unique_id():
			print("[WORLD] Found local player ", player_id)
			# adiciona a câmera local
			var local_cam = camera.duplicate() # duplique pra evitar reparent problems
			local_cam.name = "GameplayCamera"
			currentPlayer.add_child(local_cam)
			currentPlayer.camera = local_cam
			local_cam.enabled = true

		# conectar sinais de morte para TODOS players (o signal sempre será emitido no server)
		var health_component: HealthComponent = currentPlayer.health
		health_component.killed.connect(
			func(_body):
				# o objeto que emitiu sinal pode ser o player do server; chamamos o handler com player_id
				handle_player_death(player_id)
		)

		index += 1

	# conectar botão de respawn (UI global)
	respawn_ui.respawn_pressed.connect(on_respawn_button_pressed)


# =================================================================
#  PLAYER DEATH (servidor autoritativo chama isso quando detecta morte)
#  -> este handler agora DESATIVA o jogador (mantendo-o na cena)
# =================================================================
func handle_player_death(player_id: int):
	print("[WORLD] handle_player_death CALLED for ", player_id)

	if not players.has(player_id):
		print("[WORLD ERROR] Player not found in dictionary for death:", player_id)
		return

	# servidor decide como processar morte autoritativamente
	# marque como morto
	dead_players[player_id] = true

	# desativa o player (mas não queue_free)
	_set_dead_state(players[player_id])

	# Notifica todos os clients para reproduzirem efeitos de morte / UI
	# Chamar RPC para notificar (o client vai executar client_handle_player_death)
	rpc("client_notify_death", player_id)

	# Se este player for local (rodando aqui), mostre a UI localmente
	if player_id == multiplayer.get_unique_id():
		print("[WORLD] LOCAL PLAYER DIED (show UI)")
		default_camera.enabled = true
		respawn_ui.visible = true
	else:
		print("[WORLD] Remote player ", player_id, " died (server side)")


# desativa node de jogador de forma segura (mantém na cena)
func _set_dead_state(player):

	# impedir que o jogador se mexa
	player.input.movement_enabled = false 
	player.input.shooting_enabled = false 

	# desativar hurtbox
	var hurtbox = player.get_node("Hurtbox")
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)

	# impedir que este player empurre os outros
	player.set_collision_layer_value(1, false)  # layer de players
	player.set_collision_mask_value(1, false)

	# esconder visual
	player.visible = false



func _disable_collision_recursive(node):
	if node is CollisionShape2D:
		node.set_deferred("disabled", true)

	if node is CollisionObject2D:
		node.set_deferred("collision_layer", 0)
		node.set_deferred("collision_mask", 0)
		node.set_deferred("monitoring", false)
		node.set_deferred("monitorable", false)

	if node.has_method("set_physics_process"):
		node.call_deferred("set_physics_process", false)

	for child in node.get_children():
		_disable_collision_recursive(child)



# =================================================================
#  CLIENT: recebe notificação de morte (executa efeitos visuais)
# =================================================================
@rpc("any_peer")
func client_notify_death(player_id: int) -> void:
	print("[CLIENT ", multiplayer.get_unique_id(), "] client_notify_death for ", player_id)

	# Se o node não existe localmente (e você quer criar efeito), ignore
	if not players.has(player_id):
		print("[CLIENT ", multiplayer.get_unique_id(), "] client_notify_death: player not found (id=", player_id, ")")
		return

	# No cliente apenas reproduza efeitos e UI local (não recalcule lógica)
	var player = players[player_id]
	# marque como morto localmente também
	dead_players[player_id] = true

	# aplica efeitos visuais locais
	_set_dead_state(player)

	# Se este client é o dono do player, mostra respawn UI localmente
	if player_id == multiplayer.get_unique_id():
		print("[CLIENT] Showing respawn UI for local player")
		default_camera.enabled = true
		respawn_ui.visible = true


# =================================================================
#  CLIENT → SERVER: respawn request (quando jogador clicar)
# =================================================================
func on_respawn_button_pressed():
	print("[WORLD] Respawn button pressed by local player (peer=", multiplayer.get_unique_id(), ")")
	respawn_ui.visible = false

	var local_id = multiplayer.get_unique_id()
	print("[WORLD] Requesting server_respawn for id ", local_id)

	if multiplayer.is_server():
		# Se somos o host, chamamos diretamente (sem rpc)
		print("[WORLD] We are server; calling server_respawn() directly")
		server_respawn(local_id)
	else:
		# Cliente remoto pede pro servidor
		rpc_id(1, "server_respawn", local_id)



# =================================================================
#  SERVER autoritativo: respawn (REUSANDO o node do player)
# =================================================================
@rpc("any_peer")
func server_respawn(player_id: int) -> void:
	print("[SERVER] server_respawn CALLED for ", player_id)

	if not multiplayer.is_server():
		print("[SERVER] Rejecting respawn, not server")
		return

	# verifique se o player existe (aqui assumimos que nodes não foram freeados)
	if not players.has(player_id):
		# fallback: se realmente não existe, instantiate one
		print("[SERVER] player node missing at respawn, instantiating new node for id ", player_id)
		var fallback = PlayerScene.instantiate()
		fallback.name = str(player_id)
		fallback.light_attack = light_attack
		fallback.heavy_attack = heavy_attack
		add_child(fallback)
		players[player_id] = fallback

	var player = players[player_id]

	# reposicionar no spawn escolhido (autoritativo)
	var sp = spawn_points.pick_random()
	player.global_position = sp.global_position

	# resetar estado de vida (autoritativo)
	if player.has_node("Health"):
		player.health.current_health = player.health.max_health
		player.health.health_changed.emit(player.health.current_health)
	else:
		print("[SERVER] Warning: player has no Health node")

	# reativar colisões/processamento/visual
	_set_alive_state(player)

	# remover flag de dead
	dead_players.erase(player_id)

	# notificar o dono somente (opcional) para efeitos locais imediatos
	print("[SERVER] Respawn ready. Sending client_on_respawn to ", player_id)
	
		# Notifica o dono do player (UI e camera)
	rpc_id(player_id, "client_on_respawn", sp.global_position)

		# Notifica todos os outros clientes para recriar o player visualmente
	rpc("client_notify_respawn", player_id, sp.global_position)



# reativar node do jogador
func _set_alive_state(player: Node) -> void:
	print_debug("[WORLD] _set_alive_state for ", player.name)
	
	restore_original_collision_state(player)

	player.set_physics_process(true)
	player.set_process(true)
	
	player.input.movement_enabled = true 

	# reativa colisões: percorre filhos e habilita CollisionShape2D
	for c in player.get_children():
		_enable_collision_recursive(c)

	# REATIVAR VISUAL DE TODOS OS FILHOS
	for child in player.get_children():
		if child is CanvasItem:
			child.visible = true

	if player is CanvasItem:
		player.visible = true
				
	apply_respawn_invincibility(player)

	# re-ligar câmera local se for o dono (server não sabe disso, client fará localmente)
	# mover para a posição que o servidor já definiu (garantido)
	# (o client que for dono receberá client_on_respawn para ligar a câmera local)


# ===== _enable_collision_recursive (corrigida) =====
func _enable_collision_recursive(node):
	if node is CollisionShape2D:
		node.set_deferred("disabled", false)

	if node is CollisionObject2D:
		node.set_deferred("collision_layer", node.collision_layer)
		node.set_deferred("collision_mask", node.collision_mask)
		node.set_deferred("monitoring", true)
		node.set_deferred("monitorable", true)

	if node.has_method("set_physics_process"):
		node.call_deferred("set_physics_process", true)

	for child in node.get_children():
		_enable_collision_recursive(child)


func save_original_collision_state(player):
	var original := {}
	original.layers = player.collision_layer
	original.masks = player.collision_mask
	original.monitoring = player.monitoring if player is Area2D else null
	original.monitorable = player.monitorable if player is Area2D else null
	player.set_meta("original_collision", original)

func restore_original_collision_state(player):
	var saved = player.get_meta("original_collision")

	if saved:
		player.set_deferred("collision_layer", saved.layers)
		player.set_deferred("collision_mask", saved.masks)

	if saved.monitoring != null:
		player.set_deferred("monitoring", saved.monitoring)
		player.set_deferred("monitorable", saved.monitorable)


# =================================================================
#  CLIENT: aplica efeitos visuais do respawn (recebe do server)
# =================================================================
@rpc("any_peer","call_local")
func client_on_respawn(spawn_pos: Vector2):
	var my_id = multiplayer.get_unique_id()
	print("[CLIENT ", my_id, "] client_on_respawn called")

	if not players.has(my_id):
		print("[CLIENT] Warning: local player node missing on respawn, creating new one")
		var new_player = PlayerScene.instantiate()
		new_player.name = str(my_id)
		new_player.light_attack = light_attack
		new_player.heavy_attack = heavy_attack
		add_child(new_player)
		players[my_id] = new_player

	var player = players[my_id]
	player.global_position = spawn_pos

	# reativar camera local
	var cam = player.get_node_or_null("GameplayCamera")
	if cam:
		cam.enabled = true
	else:
		print("[CLIENT ", my_id, "] Camera not found, creating one")
		var camera = Camera2D.new()
		camera.name = "GameplayCamera"
		camera.zoom = Vector2(2.71, 2.71)
		player.add_child(camera)
		player.camera = camera
		camera.enabled = true

	default_camera.enabled = false

	# reativar estado local
	_set_alive_state(player)

	# remover flag dead localmente também
	dead_players.erase(my_id)

	print("[CLIENT ", my_id, "] Respawn complete")
	
@rpc("any_peer")
func client_notify_respawn(player_id: int, spawn_pos: Vector2):
	print("[CLIENT ", multiplayer.get_unique_id(), "] client_notify_respawn for ", player_id)

	if not players.has(player_id):
		print("[CLIENT] player not found, cannot respawn")
		return

	var player = players[player_id]

	# limpar flag morto
	dead_players.erase(player_id)

	# reposicionar
	player.global_position = spawn_pos

	# reativar visual, colisão, processamento
	_set_alive_state(player)

	print("[CLIENT ", multiplayer.get_unique_id(), "] remote respawn complete for ", player_id)



func apply_respawn_invincibility(player: Node, duration := 1.5):
	print_debug("[WORLD] apply_respawn_invincibility for ", player.name)

	# desativar colisão do HURTBOX APENAS
	var hurtbox = player.get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)

	# efeito visual opcional
	player.modulate = Color(1, 1, 1, 0.5)

	# timer para voltar ao normal
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)

	timer.timeout.connect(func():
		if hurtbox:
			hurtbox.set_deferred("monitoring", true)
			hurtbox.set_deferred("monitorable", true)

		player.modulate = Color(1, 1, 1, 1)
		print_debug("[WORLD] invincibility ended for ", player.name)
		
		player.input.shooting_enabled = true 

		)
	timer.start()

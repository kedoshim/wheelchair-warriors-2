extends Node2D

@export var PlayerScene: PackedScene
@export var default_camera: Camera2D
@export var respawn_ui: RespawnUI

@export var light_attack: ElementalPower
@export var heavy_attack: ElementalPower

var spawn_points = []
var players := {}        # [player_id] = Player instance vivo
var dead_players := {}   # [player_id] = true só para controle

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
		var currentPlayer: Wizard = PlayerScene.instantiate()

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

			currentPlayer.add_child(camera)
			currentPlayer.camera = camera
			camera.enabled = true

		# conectar sinais de morte para TODOS players
		var health_component: HealthComponent = currentPlayer.health
		health_component.killed.connect(
			func(_body):
				handle_player_death(player_id)
		)

		index += 1


# =================================================================
#  PLAYER DEATH
# =================================================================
func handle_player_death(player_id: int):
	print("[WORLD] handle_player_death CALLED for ", player_id)

	if not players.has(player_id):
		print("[WORLD ERROR] Player not found in dictionary")
		return

	var player : Wizard = players[player_id]
	dead_players[player_id] = true

	# REMOVENDO PLAYER DA CENA
	print_debug("[", multiplayer.get_unique_id(),"] freeing ", player_id)
	player.queue_free()
	players.erase(player_id)
	
	# avisar TODOS os clientes que esse player morreu
	rpc("client_notify_death", player_id)

	# SE FOR O CLIENTE LOCAL:
	if player_id == multiplayer.get_unique_id():

		print("[HOST] LOCAL PLAYER DIED")

		# desliga câmera de jogo
		default_camera.enabled = true

		# mostra respawn UI
		respawn_ui.visible = true
		respawn_ui.respawn_pressed.connect(on_respawn_button_pressed)

	else:
		print("[WORLD] Remote player ", player_id, " died")
		
		
func client_handle_player_death(player_id: int):
	print("[CLIENT ", multiplayer.get_unique_id(),"] client_handle_player_death CALLED for ", player_id)

	if (not players.has(player_id)) or players[player_id]==null:
		print("[CLIENT ERROR] Player not found in dictionary")
		return

	var player : Wizard = players[player_id]
	dead_players[player_id] = true

	# REMOVENDO PLAYER DA CENA
	print_debug("[", multiplayer.get_unique_id(),"] freeing ", player_id)
	player.queue_free()
	players.erase(player_id)

	# SE FOR O CLIENTE LOCAL:
	if player_id == multiplayer.get_unique_id():

		print("[CLIENT ", multiplayer.get_unique_id(),"] LOCAL PLAYER DIED")

		# desliga câmera de jogo
		default_camera.enabled = true

		# mostra respawn UI
		respawn_ui.visible = true
		respawn_ui.respawn_pressed.connect(on_respawn_button_pressed)

	else:
		print("[CLIENT] Remote player ", player_id, " died")

@rpc("any_peer")
func client_notify_death(player_id):
	print("[CLIENT ", multiplayer.get_unique_id(),"] Received death event for ", player_id)

	client_handle_player_death(player_id)



# =================================================================
#  CLIENT → SERVER: respawn request
# =================================================================
func on_respawn_button_pressed():
	print("[WORLD] Respawn button pressed by local player")

	respawn_ui.visible = false

	var local_id = multiplayer.get_unique_id()
	print("[WORLD] Requesting server_respawn for id ", local_id)
	rpc_id(1, "server_respawn", local_id)


# =================================================================
#  SERVER autoritativo: cria novo player
# =================================================================
@rpc("any_peer", "call_local")
func server_respawn(player_id: int):
	print("[SERVER] server_respawn CALLED for ", player_id)

	if not multiplayer.is_server():
		print("[SERVER] Rejecting respawn, not server")
		return

	# criar novo player
	var new_player: Wizard = PlayerScene.instantiate()
	new_player.name = str(player_id)
	print("[SERVER] Instantiating new player node")

	players[player_id] = new_player

	# spawn aleatório
	var sp = spawn_points.pick_random()
	new_player.global_position = sp.global_position

	# resetar propriedade dos ataques
	new_player.light_attack = light_attack
	new_player.heavy_attack = heavy_attack
	
	if multiplayer.get_unique_id() == player_id:
		# ligar câmera
		var cam = new_player.get_node_or_null("GameplayCamera")
		if cam:
			cam.enabled = true
		else:
			print("[CLIENT ", multiplayer.get_unique_id(),"] Camera not found")
			var camera = Camera2D.new()
			camera.name = "GameplayCamera"
			camera.zoom = Vector2(2.71, 2.71)
			new_player.add_child(camera)
			new_player.camera = camera

		default_camera.enabled = false

	add_child(new_player)

	# reconectar sinal de morte
	new_player.health.killed.connect(
		func(_body): handle_player_death(player_id)
	)

	dead_players.erase(player_id)
	

	print("[SERVER] Respawn ready. Sending client_on_respawn to ", player_id)

	# avisar o cliente
	rpc("client_on_respawn", sp.global_position, player_id)


# =================================================================
#  CLIENT: aplica efeitos visuais do respawn
# =================================================================
@rpc("any_peer")
func client_on_respawn(spawn_pos: Vector2, player_id: int):
	print("[CLIENT ", multiplayer.get_unique_id(),"] client_on_respawn CALLED for ", player_id)
		
	# criar novo player
	var new_player: Wizard = PlayerScene.instantiate()
	new_player.name = str(player_id)
	print("[CLIENT ", multiplayer.get_unique_id(),"] Instantiating new player node on ", spawn_pos)

	players[player_id] = new_player
	
	# resetar propriedade dos ataques
	new_player.light_attack = light_attack
	new_player.heavy_attack = heavy_attack

	# mover visualmente o player
	new_player.global_position = spawn_pos
	
	if multiplayer.get_unique_id() == player_id:
		# ligar câmera
		var cam = new_player.get_node_or_null("GameplayCamera")
		if cam:
			cam.enabled = true
		else:
			print("[CLIENT ", multiplayer.get_unique_id(),"] Camera not found")
			var camera = Camera2D.new()
			camera.name = "GameplayCamera"
			camera.zoom = Vector2(2.71, 2.71)
			new_player.add_child(camera)
			new_player.camera = camera

		default_camera.enabled = false
		
	add_child(new_player)

	print("[CLIENT ", multiplayer.get_unique_id(),"] Respawn complete")

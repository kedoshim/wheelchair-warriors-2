extends Control

@export var _address = "127.0.0.1"
@export var _port = 8910

var address
var port
var peer

var compression_method = ENetConnection.COMPRESS_RANGE_CODER

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	
	if "--server" in OS.get_cmdline_args():
		host_game()
		
	port = _port
	address = _address

func host_game():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 4)
	if error != OK:
		print("cannot host: ", error)
		return
	peer.get_host().compress(compression_method)
	
	multiplayer.set_multiplayer_peer(peer)
	print("Waiting For Players!")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# this gets called on the server AND clients
func peer_connected(id):
	print("Player Connected ", id)
	
# this gets called on the server AND clients
func peer_disconnected(id):
	print("Player Disconnected ", id)
	
# this gets called ONLY from clients
func connected_to_server():
	print("Connected to server")
	send_player_information.rpc_id(1, $LineEdit.text, multiplayer.get_unique_id())
	
# this gets called ONLY from clients
func connection_failed():
	print("Connection Failed")
	
@rpc("any_peer")
func send_player_information(name,id):
	if !GameManager.players.has(id):
		GameManager.players[id] = {
			"name": name,
			"id": id,
			"score" : 0
		}
	
	if multiplayer.is_server():
		for i in GameManager.players:
			send_player_information.rpc(GameManager.players[i].name, i)
	
@rpc("any_peer","call_local")
func start_game():
	var scene = load("res://main.tscn").instantiate()
	get_tree().root.add_child(scene)
	self.hide()

func _on_host_button_down() -> void:
	host_game()
	send_player_information($LineEdit.text, multiplayer.get_unique_id())


func _on_join_button_down() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(address,port)
	peer.get_host().compress(compression_method)
	multiplayer.set_multiplayer_peer(peer)
	


func _on_start_game_button_down() -> void:
	start_game.rpc()

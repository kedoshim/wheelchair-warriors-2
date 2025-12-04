extends Node2D

@export var PlayerScene : PackedScene

@export var light_attack: ElementalPower
@export var heavy_attack: ElementalPower

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	var camera = Camera2D.new()
	camera.position = Vector2(0,0)
	camera.zoom.x = 2.71
	camera.zoom.y = 2.71
	
	var index = 0
	for i in GameManager.players:
		var currentPlayer: Wizard = PlayerScene.instantiate()
		var player_id = GameManager.players[i].id
		
		currentPlayer.name = str(player_id)
		
		if player_id == multiplayer.get_unique_id():
			currentPlayer.add_child(camera)
		
		currentPlayer.light_attack = light_attack
		currentPlayer.heavy_attack = heavy_attack
		for spawn in get_tree().get_nodes_in_group("PlayerSpawnPoint"):
			if spawn.name == str(index):
				currentPlayer.global_position = spawn.global_position
				add_child(currentPlayer)
		index += 1


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

extends CanvasLayer
class_name RespawnUI

@onready var respawn_button = $RespawnButton

signal respawn_pressed

func _ready():
	visible = false
	respawn_button.pressed.connect(func():
		respawn_pressed.emit()
	)

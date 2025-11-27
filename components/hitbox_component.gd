extends Area2D
class_name HitboxComponent

@export var damage: int = 1
@export var perfuration: int = 1
@export var deletable: bool = false

var perfuration_left

signal was_deleted

func _ready() -> void:
	perfuration_left = perfuration

func hit():
	perfuration_left -= 1
	if deletable and perfuration_left<=0:
		was_deleted.emit(self)
		get_parent().queue_free()

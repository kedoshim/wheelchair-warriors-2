extends AbilityAction
class_name AttachToPlayerAction

var node: Node

func _init(n: Node):
	node = n

func execute(shooting_component):
	var player = shooting_component.user
	player.add_child(node)

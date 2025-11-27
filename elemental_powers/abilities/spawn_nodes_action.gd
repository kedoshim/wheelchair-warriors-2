extends AbilityAction
class_name SpawnNodesAction

var immediate_nodes: Array = []
var delayed_nodes: Array = []   # array of dictionaries: {node, delay}

func _init(nodes := []):
	immediate_nodes = nodes

func add_delayed_spawn(node: Node, delay: float):
	delayed_nodes.append({"node": node, "delay": delay})

func execute(shooting_component):
	# Spawn immediate nodes
	for n in immediate_nodes:
		var root : Window = shooting_component.get_tree().root
		root.get_child(2).add_child(n)

	# Spawn delayed nodes
	for d in delayed_nodes:
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = d.delay
		shooting_component.add_child(timer)

		timer.timeout.connect(func():
			shooting_component.get_tree().current_scene.add_child(d.node)
		)

		timer.start()

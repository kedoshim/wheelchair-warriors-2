extends AbilityAction
class_name BeamAction

var beam_scene: PackedScene
var origin: Vector2
var target: Vector2
var duration: float

func _init(beam_scene: PackedScene, origin: Vector2, target: Vector2, duration := 0.3):
	self.beam_scene = beam_scene
	self.origin = origin
	self.target = target
	self.duration = duration

func execute(shooting_component):
	var beam := beam_scene.instantiate()

	beam.global_position = origin
	if beam.has_method("setup"):
		beam.setup(origin, target, duration)

	shooting_component.get_tree().current_scene.add_child(beam)

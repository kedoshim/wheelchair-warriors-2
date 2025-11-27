extends AbilityAction
class_name CastTimeAction

var time: float
var callback: Callable

func _init(t: float, cb: Callable):
	time = t
	callback = cb

func execute(shooting_component):
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = time
	shooting_component.add_child(timer)

	timer.timeout.connect(callback)
	timer.start()

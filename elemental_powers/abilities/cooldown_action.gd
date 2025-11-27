extends AbilityAction
class_name CooldownAction

var duration: float

func _init(time: float):
	duration = time

func execute(shooting_component):
	shooting_component.start_power_cooldown(duration)

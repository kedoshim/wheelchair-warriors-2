extends ElementalPower
class_name FireElement

@export var fireball_scene: PackedScene = preload("res://elemental_powers/projectille_scenes/fireball.tscn")

# --------------------------------------------
# LIGHT ATTACK → Single Fireball
# --------------------------------------------
func get_light_attack(user: Wizard, origin: Vector2, target: Vector2):
	var bullet := _create_basic_projectille(user, origin, target, fireball_scene)
	return [
		SpawnNodesAction.new([bullet]),
		CooldownAction.new(0.15)  # small cooldown
	]


# --------------------------------------------
# HEAVY ATTACK → Cone Burst (5 fireballs)
# --------------------------------------------
func get_heavy_attack(user: Wizard, origin: Vector2, target: Vector2):
	return [
		create_cast_time_action(0.25, func(): pass), # small cast
		create_cone_action(
			user,
			origin,
			target,
			fireball_scene,
			45.0,   # cone angle
			5,      # fireballs
			1200.0
		),
		CooldownAction.new(1.2)  # big cooldown
	]


# --------------------------------------------
# PASSIVE → Fire-based attacks ignite enemies
# --------------------------------------------
func get_passive(_user):
	# You can add a passive effect object later
	return []

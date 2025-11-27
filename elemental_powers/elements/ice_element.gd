extends ElementalPower
class_name IceElement

@export var shard_scene: PackedScene = preload("res://elemental_powers/projectille_scenes/ice_shard.tscn")
@export var nova_scene: PackedScene = preload("res://elemental_powers/projectille_scenes/ice_shard.tscn")


# --------------------------------------------
# LIGHT ATTACK → Slow Shard
# --------------------------------------------
func get_light_attack(user: Wizard, origin: Vector2, target: Vector2):
	var shard := _create_basic_projectille(user, origin, target, shard_scene)

	# Ice shards slow enemies on hit (inside the projectile script)
	return [
		SpawnNodesAction.new([shard]),
		CooldownAction.new(0.1)
	]


# --------------------------------------------
# HEAVY ATTACK → Frost Nova
# --------------------------------------------
func get_heavy_attack(user: Wizard, origin: Vector2, target: Vector2):
	var nova := nova_scene.instantiate()
	nova.global_position = user.global_position

	return [
		CastTimeAction.new(0.35, func(): pass),
		SpawnNodesAction.new([nova]),
		CooldownAction.new(2.0)
	]


# --------------------------------------------
# PASSIVE → Ice reduces cooldown slightly
# --------------------------------------------
func get_passive(user):
	return []  # add slow resist, freeze bonus, etc.

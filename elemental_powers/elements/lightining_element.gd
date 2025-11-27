extends ElementalPower
class_name LightningElement

@export var spark_scene: PackedScene = preload("res://spark.tscn")
@export var strike_scene: PackedScene = preload("res://lightning_strike.tscn")


# --------------------------------------------
# LIGHT ATTACK → Quick Spark (high speed)
# --------------------------------------------
func get_light_attack(user: Wizard, origin: Vector2, target: Vector2):
	var spark := _create_basic_projectille(user, origin, target, spark_scene)
	spark.speed = 900  # optional tweak if your projectile supports it

	return [
		SpawnNodesAction.new([spark]),
		CooldownAction.new(0.1)
	]


# --------------------------------------------
# HEAVY ATTACK → Lightning Strike (AoE on target)
# --------------------------------------------
func get_heavy_attack(user: Wizard, origin: Vector2, target: Vector2):
	var strike := strike_scene.instantiate()
	strike.global_position = target

	return [
		CastTimeAction.new(0.20, func(): pass),
		SpawnNodesAction.new([strike]),
		CooldownAction.new(1.0)
	]


# --------------------------------------------
# PASSIVE → Critical shock chance
# --------------------------------------------
func get_passive(user):
	return []

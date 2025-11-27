extends Resource
class_name ElementalPower

@export var name: String
@export var icon: Texture2D

# -------------------------------------------------------
#   OVERRIDABLE INTERFACE
# -------------------------------------------------------

func get_light_attack(user: Wizard, origin: Vector2, target: Vector2) -> Array:
	return []   # Override in subclasses

func get_heavy_attack(user: Wizard, origin: Vector2, target: Vector2) -> Array:
	return []   # Override in subclasses

func get_passive(user):
	return []   # Optional return of AbilityActions


# -------------------------------------------------------
#   PROJECTILE HELPERS
# -------------------------------------------------------

func _create_basic_projectille(
	user: Wizard,
	origin: Vector2,
	target: Vector2,
	projectile_scene: PackedScene
) -> Node2D:
	var bullet := projectile_scene.instantiate()

	var direction := (target - origin).normalized()
	bullet.global_position = origin + direction * 20

	bullet.direction = direction
	bullet.shooter = user.name

	var hitbox = bullet.get_node("HitboxComponent")
	if hitbox:
		hitbox.collision_layer = 8

	return bullet


# -------------------------------------------------------
#   CONE ATTACK
# -------------------------------------------------------

func create_cone_action(
	user: Wizard,
	origin: Vector2,
	target: Vector2,
	projectile_scene: PackedScene,
	cone_angle_degrees := 45.0,
	count := 5,
	range := 1000.0
):
	var projectiles: Array = []

	if count <= 0:
		return SpawnNodesAction.new([])

	var base := (target - origin).normalized()
	var total_angle := deg_to_rad(cone_angle_degrees)
	var step :=  total_angle / (count - 1) if count > 1 else 0.0
	var start := -total_angle / 2.0

	for i in range(count):
		var offset := start + step * i
		var dir := base.rotated(offset)
		var proj_target := origin + dir * range

		projectiles.append(
			_create_basic_projectille(user, origin, proj_target, projectile_scene)
		)

	return SpawnNodesAction.new(projectiles)


# -------------------------------------------------------
#   RAPID FIRE
# -------------------------------------------------------

func create_rapid_fire_action(
	user: Wizard,
	origin: Vector2,
	target: Vector2,
	projectile_scene: PackedScene,
	shots := 5,
	interval := 0.1
):
	var action := SpawnNodesAction.new([])

	for i in range(shots):
		var bullet := _create_basic_projectille(user, origin, target, projectile_scene)
		action.add_delayed_spawn(bullet, i * interval)

	return action


# -------------------------------------------------------
#   COOLDOWN WRAPPER
# -------------------------------------------------------

func create_cooldown_action(time: float):
	return CooldownAction.new(time)


# -------------------------------------------------------
#   CAST TIME
# -------------------------------------------------------

func create_cast_time_action(time: float, callback: Callable):
	return CastTimeAction.new(time, callback)

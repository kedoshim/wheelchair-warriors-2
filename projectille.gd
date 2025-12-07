class_name Projectile
extends Area2D

# --- CONFIGURAÇÕES DO PROJETIL ---
@export var speed: float = 200.0
@export var damage: int = 1
@export var perfuration: int = 1
@export var lifetime: float = 3.0
@export var shooter: String

# --- EFEITOS OPCIONAIS ---
@export var ricochet_enabled := false
@export var max_ricochets := 3

@export var homing_enabled := false
@export var homing_strength := 4.0
@export var homing_range := 300.0

@export var explosion_enabled := false
@export var explosion_radius := 60.0
@export var explosion_damage := 1

@export var trail_enabled := false
@export var trail_scene: PackedScene

# --- VARIÁVEIS INTERNAS ---
var direction: Vector2 = Vector2.RIGHT
var remaining_hits: int
var ricochets_left: int

# store previous position so we can raycast between frames
var _prev_position: Vector2

@onready var hitboxComponent = $HitboxComponent


func _ready():
	remaining_hits = perfuration
	ricochets_left = max_ricochets

	hitboxComponent.damage = damage
	hitboxComponent.perfuration = perfuration

	# orient the sprite/area
	look_at(global_position + direction)

	# trail
	if trail_enabled and trail_scene:
		var trail = trail_scene.instantiate()
		add_child(trail)

	# auto-destroy
	var t := Timer.new()
	t.wait_time = lifetime
	t.one_shot = true
	add_child(t)
	t.start()
	t.timeout.connect(queue_free)

	# initialize previous position
	_prev_position = global_position


func _physics_process(delta):
	# homing
	if homing_enabled:
		_apply_homing(delta)

	# compute next position
	var next_pos :Vector2 = global_position + direction.normalized() * speed * delta

	# Acquire space state
	var space_state = get_world_2d().direct_space_state

	# Build a typed ray query (PhysicsRayQueryParameters2D)
	var params := PhysicsRayQueryParameters2D.new()
	params.from = global_position
	params.to = next_pos
	params.exclude = [self]
	# Optionally control what is hit:
	# params.collision_mask = 0xFFFFFFFF
	# params.collide_with_areas = true
	# params.collide_with_bodies = true

	var result: Dictionary = space_state.intersect_ray(params)

	if result.size() > 0:
		# result keys: "position", "normal", "collider", "rid", "shape"
		var collision_point: Vector2 = result.get("position")
		var collision_normal: Vector2 = result.get("normal")
		var _collider = result.get("collider")

		if collision_normal and collision_point:
			# ricochet logic (same as before)
			if ricochet_enabled and ricochets_left > 0:
				ricochets_left -= 1
				direction = direction.normalized().bounce(collision_normal).normalized()
				global_position = collision_point + collision_normal * 0.1
				# apply damage or remaining_hits logic here...
				_prev_position = global_position
				return
			else:
				# impact (no ricochet)
				global_position = collision_point + collision_normal * 0.1
				# apply damage and explosion
				_prev_position = global_position
				return
	else:
		# no collision: move normally
		global_position = next_pos
		_prev_position = global_position


func _apply_homing(delta):
	var nearest = null
	var nearest_dist := homing_range

	for body in get_tree().get_nodes_in_group("enemies"):
		if not (body and body.has_method("global_position")):
			continue
		var d = global_position.distance_to(body.global_position)
		if d < nearest_dist:
			nearest = body
			nearest_dist = d

	if nearest:
		var desired = (nearest.global_position - global_position).normalized()
		# lerp direction smoothly towards desired
		direction = direction.lerp(desired, homing_strength * delta).normalized()


# NOTE: _handle_ricochet kept for compatibility, but now we prefer the raycast version above.
# You can remove this if you don't call it from anywhere else.
func _handle_ricochet(body: Node2D) -> void:
	# fallback: approximate normal pointing from collider center to this projectile
	var approx_normal := (global_position - body.global_position).normalized()
	direction = direction.bounce(approx_normal).normalized()


func _do_explosion():
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()

	circle.radius = explosion_radius
	shape.shape = circle
	area.add_child(shape)
	area.global_position = global_position
	area.set_collision_layer_value(5, true) # explosion layer
	get_tree().current_scene.add_child(area)

	for b in area.get_overlapping_bodies(): 
		if b.is_in_group("enemies"): 
			if b.has_method("take_damage"): 
				b.take_damage(explosion_damage) 
	area.queue_free()


# Keep old hitbox entry handler in case your HitboxComponent still emits signals.
# It will still apply damage as before but won't be used for normals.
func _on_hitbox_component_body_entered(body: Node2D) -> void:
	if body.name == shooter:
		return

	remaining_hits -= 1

	# If ricochet is allowed, we don't rely on Area signal normals — the raycast handles normals.
	# But if you want to attempt ricochet here (approximate), you could call _handle_ricochet(body).
	# For consistency we just handle death/explosion:
	if remaining_hits <= 0:
		if explosion_enabled:
			_do_explosion()
		queue_free()

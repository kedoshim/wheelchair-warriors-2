extends Node
class_name HealthComponent

signal health_changed(new_value)
signal killed(body)

@export_range(1, 100) var max_health: int = 4
@export var marker: Marker2D
@export var visible: bool = true
@export var death_animation: AnimatedSprite2D

var current_health: int
var original_health: int

func _ready() -> void:
	current_health = max_health
	original_health = max_health
	health_changed.emit(current_health)

# ============================================================
# ===== DAMAGE ENTRY POINT (SERVIDOR AUTORITATIVO) ==========
# ============================================================

func take_damage(damage: int):
	# cliente → pede dano ao servidor
	if not multiplayer.is_server():
		rpc_id(1, "server_apply_damage", damage)
	else:
		# servidor → aplica diretamente
		_server_apply_damage(damage)


@rpc("any_peer")
func server_apply_damage(damage: int):
	if not multiplayer.is_server():
		return
	_server_apply_damage(damage)


func _server_apply_damage(damage: int):
	if current_health <= 0:
		return

	current_health -= damage

	# servidor atualiza vida em todos os clientes
	rpc("client_sync_health", current_health, damage)

	health_changed.emit(current_health)

	if current_health <= 0:
		# servidor decide a morte
		rpc("client_play_death")
		killed.emit(get_parent())


# ============================================================
# ======== CLIENTS SYNC HEALTH (VISUAL ONLY) ================
# ============================================================

@rpc("call_remote")
func client_sync_health(new_health: int, damage: int):
	# atualiza localmente
	current_health = new_health
	health_changed.emit(current_health)

	display_number(damage)

	# câmera treme só se este player for o dono
	var camera = get_parent().get_node_or_null("Camera2D")
	if camera and is_local_player():
		apply_camera_shake(camera)


func is_local_player() -> bool:
	var parent = get_parent()
	return parent.get_multiplayer_authority() == multiplayer.get_unique_id()


# ============================================================
# ================ DEATH HANDLING ============================
# ============================================================

@rpc("call_remote")
func client_play_death():
	play_death_animation()


func play_death_animation() -> void:
	if death_animation and death_animation.sprite_frames and death_animation.sprite_frames.has_animation("death"):

		if not death_animation.is_connected("animation_finished", _on_death_animation_finished):
			death_animation.connect("animation_finished", _on_death_animation_finished)

		death_animation.modulate = Color(1,1,1)
		death_animation.play("death")
		disable_interactions()
	else:
		get_parent().queue_free()


func disable_interactions() -> void:
	var parent = get_parent()
	if parent:
		if parent.has_method("set_physics_process"):
			parent.set_physics_process(false)

		if parent.has_method("set_collision_layer"):
			parent.collision_layer = 0

		for child in parent.get_children():
			if child.has_method("set_physics_process"):
				child.set_physics_process(false)
			if child is CollisionShape2D:
				child.disabled = true


# ============================================================
# UI DAMAGE FLOATING NUMBERS
# ============================================================

func display_number(value: int):
	var number = Label.new()
	number.global_position = get_parent().global_position
	number.text = str(value)
	number.z_index = 10
	number.label_settings = LabelSettings.new()
	number.modulate = Color(1,1,1)
	var color = "#FF0"

	number.label_settings.font_color = color
	number.label_settings.font_size = 36
	number.label_settings.outline_color = "#000"
	number.label_settings.outline_size = 1
	call_deferred("add_child", number)

	await number.resized

	number.pivot_offset = Vector2(number.size / 2)

	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		number, "position:y", number.position.y - 25, 0.25
	).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		number, "position:y", number.position.y, 0.5
	).set_ease(Tween.EASE_IN).set_delay(0.5)

	tween.tween_property(
		number, "scale", Vector2.ZERO, 0.25
	).set_ease(Tween.EASE_IN).set_delay(0.5)

	await tween.finished
	number.queue_free()


func _on_death_animation_finished():
	pass


func apply_camera_shake(camera: Camera2D) -> void:
	# Create a Tween to animate the camera shake
	var tween = get_tree().create_tween()
	var shake_strength = 12.0  # Adjust the strength of the shake as needed
	
	tween.tween_property(
		camera, "offset", Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength)), 0.1
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	tween.tween_property(
		camera, "offset", Vector2.ZERO, 0.1
	).set_delay(0.4)
	

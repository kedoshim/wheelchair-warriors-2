extends Node
class_name HealthComponent

signal health_changed
signal killed(body)

@export_range(1, 100) var max_health: int = 4
@export var marker: Marker2D
@export var visible: bool = true
@export var death_animation: AnimatedSprite2D

var current_health: int
var original_health: int

# Chamado quando o nó entra na cena
func _ready() -> void:
	current_health = max_health
	original_health = max_health
	health_changed.emit(current_health)
	
	#print_debug(current_health)
# Função chamada quando algo entra na área de dano

# Função chamada quando a saúde chega a zero
func _process(_delta: float) -> void:
	if current_health <= 0:
		play_death_animation()

# Função que toca a animação de morte, se houver
func play_death_animation() -> void:
	# Se uma animação de morte existir e o sprite tiver a animação 'death'
	if death_animation and death_animation.sprite_frames and death_animation.sprite_frames.has_animation("death"):
		# Conecta o sinal para saber quando a animação de morte termina
		if(not death_animation.is_connected("animation_finished",_on_death_animation_finished)):
			death_animation.connect("animation_finished",_on_death_animation_finished)
		death_animation.modulate = Color(1,1,1)
		death_animation.play("death")  # Toca a animação de morte
		disable_interactions()  # Desativa todas as interações do objeto com o mundo
	else:
		# Se não houver animação de morte, apenas libera o nó
		get_parent().queue_free()

# Desativa as interações com o mundo (colisões, física, etc.)
func disable_interactions() -> void:
	var parent = get_parent()
	if parent:
		# Desativa colisões, física ou outros componentes que possam interagir
		if(parent.has_method("set_physics_process")):
			parent.set_physics_process(false)
		if(parent.has_method("set_collision_layer")):
			parent.collision_layer = 8
			#parent.mask_layer = 0
		for child in parent.get_children():
			if child.has_method("set_physics_process"):
				child.set_physics_process(false)  # Desativa a física
			if child.has_method("set_collision_layer"):
				child.collision_layer = 8
				child.queue_free()
				#child.mask_layer = 0
			if(child.has_method("set_mask_layer")):
				child.mask_layer = 8

# Função chamada quando a saúde é reduzida
func take_damage(damage: int):
	if current_health > 0:
		current_health -= damage
		health_changed.emit(current_health)
		display_number(damage)
		
		# Apply camera shake if there is a Camera2D child node
		var camera = get_parent().get_node_or_null("Camera2D")
		if camera:
			apply_camera_shake(camera)
		
	if current_health <= 0:
		killed.emit(get_parent())

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
	call_deferred("add_child",number)
	#get_parent().add_child(number)
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
	
# Chamado quando a animação de morte termina
func _on_death_animation_finished() -> void:
	
	#if get_parent() is Player:
		#get_node("/root/ScenesComposer/HUD").game_over.visible = true
	# Libera o nó após a animação de morte terminar
	#get_parent().queue_free()
	pass

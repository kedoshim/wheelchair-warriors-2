extends Area2D
class_name HurtboxComponent

@export var healthComponent: HealthComponent

# Variável para controlar a duração do efeito de "blink"
@export var blink_duration: float = 0.1  # Duração do blink em segundos

# Variável para referenciar o sprite
@export var sprite : AnimatedSprite2D  # Ajuste o caminho conforme necessário

@export var is_invulnerable : bool

var old_modulate_value

var is_being_captured: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if is_invulnerable:
		return
	if body.is_in_group('Bullet') and HealthComponent:
		print("entrou")
		
		healthComponent.take_damage(body.damage)
		
		get_parent().queue_free()


func _on_area_entered(hitbox: Area2D) -> void:
	if is_invulnerable:
		return
		
	if hitbox.is_in_group('Bullet') and HealthComponent:
		
		var hitbox_component: HitboxComponent = hitbox.get_node("HitboxComponent")

		if hitbox_component:
			healthComponent.take_damage(hitbox_component.damage)
		
	if hitbox is HitboxComponent:
		var _hitbox_owner = hitbox.get_parent()
			
		if healthComponent:
			healthComponent.take_damage(hitbox.damage)
			_blink_once()  # Chama a função de blink
			$HurtSound.play()
		

# Função que aplica o efeito de blink
func _blink_once() -> void:
	if not sprite:
		return
	# Muda a cor para branco para o efeito de blink
	old_modulate_value = sprite.self_modulate
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate:v", 1, 0.13).from(10)
	

	# Cria um Timer para restaurar a cor original
	var blink_timer = Timer.new()
	blink_timer.wait_time = blink_duration
	blink_timer.one_shot = true
	blink_timer.connect("timeout",_restore_original_color)
	add_child(blink_timer)
	blink_timer.start()

# Função para restaurar a cor original após o blink
func _restore_original_color() -> void:
	sprite.self_modulate = old_modulate_value

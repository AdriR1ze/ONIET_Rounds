class_name TrainingTarget
extends Area2D

# Blanco de práctica del tutorial. Es un Area2D en la capa de hurtbox (4), la
# misma que las balas del proyecto escanean (bullet.gd: query_area.collision_mask = 4).
# Las balas le pegan llamando take_hit() sobre este Area2D (bullet.gd:583).

signal destroyed

@onready var _health: HealthComponent = $HealthComponent
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	_health.died.connect(_on_died)


# API que consume bullet.gd al impactar un Area2D con take_hit().
func take_hit(amount: int, source: Node = null) -> void:
	if not _health.is_alive():
		return
	_health.apply_damage(amount, source)


# Deja el blanco listo para reintentar el paso de disparo.
func revive() -> void:
	_health.reset()
	_visual.visible = true
	_shape.set_deferred("disabled", false)


# Oculta y deshabilita la colisión del blanco hasta su momento.
func desactivar() -> void:
	if _visual != null:
		_visual.visible = false
	if _shape != null:
		_shape.set_deferred("disabled", true)


func _on_died() -> void:
	_shape.set_deferred("disabled", true)
	_visual.visible = false
	destroyed.emit()

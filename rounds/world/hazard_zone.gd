class_name HazardZone
extends Area2D

@export var damage: int = 999

var _pulse_timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Jugadores
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_pulse_timer += delta * 6.0
	var alpha: float = 0.8 + 0.2 * sin(_pulse_timer)
	modulate.a = alpha


func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body):
		return
	if body.has_method("hurt"):
		body.hurt(damage, self)
	elif body.has_method("_on_died"):
		body._on_died()

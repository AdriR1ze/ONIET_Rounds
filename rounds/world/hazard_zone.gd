class_name HazardZone
extends Area2D

@export var damage: int = 999


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Jugadores
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if is_instance_valid(body) and body is Node2D:
			if body.has_method("is_alive") and not body.is_alive():
				continue
			if body.has_method("hurt"):
				body.hurt(damage, self)
			elif body.has_method("_on_died"):
				body._on_died()


func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body):
		return
	if body.has_method("is_alive") and not body.is_alive():
		return
	if body.has_method("hurt"):
		body.hurt(damage, self)
	elif body.has_method("_on_died"):
		body._on_died()

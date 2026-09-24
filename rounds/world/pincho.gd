extends Area2D

## Pincho: hace daño al jugador que lo toca. Se puede pintar desde el TileSet.

@export var damage: int = 1


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not is_instance_valid(body):
		return
	if body.has_method("is_alive") and not body.is_alive():
		return
	if body.has_method("hurt"):
		body.hurt(damage, self)

extends Area2D

## Cuerda para trepar: mientras el jugador la toca, sube/baja con arriba/abajo.
## Se puede pintar desde el TileSet (apilá varias para hacer una cuerda vertical).

func _ready() -> void:
	add_to_group("cuerda_trepar")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.has_method("enter_climb_rope"):
		body.enter_climb_rope(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("exit_climb_rope"):
		body.exit_climb_rope(self)

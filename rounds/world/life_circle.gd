extends Area2D

## Objeto de vida (placeholder: un círculo). Es un Area2D: se puede atravesar.
## Si un jugador queda parado encima/apoyado en él durante TIEMPO_VIDA segundos,
## gana una vida y el objeto desaparece. Pintable desde el TileSet.

const TIEMPO_VIDA := 1.5

var _tiempos: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_tiempos[body] = 0.0


func _on_body_exited(body: Node) -> void:
	_tiempos.erase(body)


func _physics_process(delta: float) -> void:
	for p in _tiempos.keys():
		if not is_instance_valid(p):
			_tiempos.erase(p)
			continue
		if p.is_on_floor() and p.has_method("is_alive") and p.is_alive():
			var t: float = _tiempos[p] + delta
			if t >= TIEMPO_VIDA:
				_otorgar(p.player_number)
				return
			_tiempos[p] = t
		else:
			_tiempos[p] = 0.0


func _otorgar(player_number: int) -> void:
	set_physics_process(false)
	monitoring = false
	RunManager.ganar_vida(player_number)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)

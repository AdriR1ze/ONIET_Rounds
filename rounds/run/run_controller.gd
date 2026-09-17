extends Node

@export var pantalla_mejoras: CanvasLayer

var _muertos: Array = []
var _procesando: bool = false


func _ready() -> void:
	if pantalla_mejoras == null and get_parent() != null:
		pantalla_mejoras = get_parent().get_node_or_null("UpgradeScreen")
	await get_tree().process_frame
	for jugador in RunManager.jugadores():
		var salud: Node = jugador.get_node_or_null("HealthComponent")
		if salud != null and not salud.died.is_connected(_on_jugador_muerto):
			salud.died.connect(_on_jugador_muerto.bind(jugador))


func _on_jugador_muerto(jugador: Node) -> void:
	if not _muertos.has(jugador):
		_muertos.append(jugador)
	if _procesando:
		return
	_procesando = true
	if pantalla_mejoras != null and pantalla_mejoras.has_method("abrir"):
		await pantalla_mejoras.abrir()
	for caido in _muertos:
		if is_instance_valid(caido) and caido.has_method("respawn"):
			caido.respawn()
	_muertos.clear()
	_procesando = false

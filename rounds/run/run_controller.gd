extends Node

@export var pantalla_mejoras: CanvasLayer
@export var pantalla_fin: CanvasLayer

var _procesando: bool = false
var _ronda_activa: bool = false


func _ready() -> void:
	if pantalla_mejoras == null and get_parent() != null:
		pantalla_mejoras = get_parent().get_node_or_null("UpgradeScreen")
	if pantalla_fin == null and get_parent() != null:
		pantalla_fin = get_parent().get_node_or_null("MatchEnd")
	await get_tree().process_frame
	for jugador in RunManager.jugadores():
		var salud: Node = jugador.get_node_or_null("HealthComponent")
		if salud != null and not salud.died.is_connected(_on_jugador_muerto):
			salud.died.connect(_on_jugador_muerto.bind(jugador))
	RunManager.iniciar_partida()
	RunManager.iniciar_ronda(1)
	_ronda_activa = true


func _on_jugador_muerto(jugador: Node) -> void:
	if not _ronda_activa or _procesando:
		return
	var numero: int = jugador.player_number
	var le_quedan: bool = RunManager.registrar_muerte(numero)
	if le_quedan:
		await get_tree().create_timer(0.6).timeout
		if _ronda_activa and is_instance_valid(jugador):
			jugador.respawn()
		return

	_procesando = true
	_ronda_activa = false
	var ganador: int = RunManager.ganador_de_ronda(numero)
	RunManager.terminar_ronda(ganador)

	if RunManager.partida_ganada():
		if pantalla_fin != null and pantalla_fin.has_method("mostrar"):
			pantalla_fin.mostrar(ganador)
		_procesando = false
		return

	if pantalla_mejoras != null and pantalla_mejoras.has_method("abrir"):
		await pantalla_mejoras.abrir()
	for jug in RunManager.jugadores():
		if is_instance_valid(jug) and jug.has_method("respawn"):
			jug.respawn()
	RunManager.iniciar_ronda(RunManager.ronda + 1)
	_ronda_activa = true
	_procesando = false

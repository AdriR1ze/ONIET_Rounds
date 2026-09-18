extends Node

@export var pantalla_mejoras: CanvasLayer
@export var pantalla_fin: CanvasLayer
@export var banner_ganador: CanvasLayer

var _procesando: bool = false
var _ronda_activa: bool = false
var _mapa_actual: Node2D = null


func _ready() -> void:
	if pantalla_mejoras == null and get_parent() != null:
		pantalla_mejoras = get_parent().get_node_or_null("UpgradeScreen")
	if pantalla_fin == null and get_parent() != null:
		pantalla_fin = get_parent().get_node_or_null("MatchEnd")
	if banner_ganador == null and get_parent() != null:
		banner_ganador = get_parent().get_node_or_null("RoundWinnerBanner")
	await get_tree().process_frame
	for jugador in RunManager.jugadores():
		var salud: Node = jugador.get_node_or_null("HealthComponent")
		if salud != null and not salud.died.is_connected(_on_jugador_muerto):
			salud.died.connect(_on_jugador_muerto.bind(jugador))
	RunManager.iniciar_partida()
	cargar_nuevo_mapa()
	RunManager.iniciar_ronda(1)
	_ronda_activa = true


func _on_jugador_muerto(jugador: Node) -> void:
	if not _ronda_activa or _procesando:
		return
	_procesando = true
	_ronda_activa = false
	_limpiar_proyectiles()

	var numero: int = jugador.player_number
	RunManager.perder_vida(numero)
	var ganador: int = RunManager.ganador_de_ronda(numero)
	RunManager.terminar_ronda(ganador)

	if banner_ganador != null and banner_ganador.has_method("mostrar_ganador"):
		await banner_ganador.mostrar_ganador(ganador)

	if RunManager.partida_ganada():
		if pantalla_fin != null and pantalla_fin.has_method("mostrar"):
			pantalla_fin.mostrar(ganador)
		_procesando = false
		return

	if pantalla_mejoras != null and pantalla_mejoras.has_method("abrir"):
		await pantalla_mejoras.abrir()
	_limpiar_proyectiles()

	if MapManager.total_activos() > 1:
		cargar_nuevo_mapa()

	for jug in RunManager.jugadores():
		if is_instance_valid(jug) and jug.has_method("respawn"):
			jug.respawn()
	RunManager.iniciar_ronda(RunManager.ronda + 1)
	_ronda_activa = true
	_procesando = false


func cargar_nuevo_mapa() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var map_container := parent_node.get_node_or_null("MapContainer")
	if map_container == null:
		return

	if _mapa_actual != null and is_instance_valid(_mapa_actual):
		_mapa_actual.queue_free()
		_mapa_actual = null

	var info := MapManager.obtener_mapa_aleatorio()
	var escena_path: String = info.get("escena", "")
	if escena_path.is_empty():
		return

	var escena_mapa: PackedScene = load(escena_path)
	if escena_mapa == null:
		return

	_mapa_actual = escena_mapa.instantiate() as Node2D
	map_container.add_child(_mapa_actual)

	var sp1 := _mapa_actual.get_node_or_null("SpawnP1") as Marker2D
	var sp2 := _mapa_actual.get_node_or_null("SpawnP2") as Marker2D

	for jug in RunManager.jugadores():
		if not is_instance_valid(jug):
			continue
		var spawn_pos := Vector2(480, 600)
		if jug.player_number == 1 and sp1 != null:
			spawn_pos = sp1.global_position
		elif jug.player_number == 2 and sp2 != null:
			spawn_pos = sp2.global_position

		jug.set("_spawn_position", spawn_pos)
		jug.global_position = spawn_pos
		jug.velocity = Vector2.ZERO


func _limpiar_proyectiles() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for entidad in tree.get_nodes_in_group("bullet"):
		if is_instance_valid(entidad):
			entidad.queue_free()

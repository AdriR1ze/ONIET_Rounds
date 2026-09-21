extends Node

@export var pantalla_mejoras: CanvasLayer
@export var pantalla_fin: CanvasLayer
@export var banner_ganador: CanvasLayer
@export var banner_intro: CanvasLayer

var _procesando: bool = false
var _ronda_activa: bool = false
var _mapa_actual: Node2D = null
var _mapa_info_actual: Dictionary = {}

const SPAWNS_FALLBACK := {
	1: Vector2(480, 600),
	2: Vector2(800, 600),
	3: Vector2(320, 600),
	4: Vector2(960, 600),
}


func _ready() -> void:
	if pantalla_mejoras == null and get_parent() != null:
		pantalla_mejoras = get_parent().get_node_or_null("UpgradeScreen")
	if pantalla_fin == null and get_parent() != null:
		pantalla_fin = get_parent().get_node_or_null("MatchEnd")
	if banner_ganador == null and get_parent() != null:
		banner_ganador = get_parent().get_node_or_null("RoundWinnerBanner")
	if banner_intro == null and get_parent() != null:
		banner_intro = get_parent().get_node_or_null("MapIntroBanner")
	await get_tree().process_frame
	for jugador in RunManager.jugadores():
		var salud: Node = jugador.get_node_or_null("HealthComponent")
		if salud != null and not salud.died.is_connected(_on_jugador_muerto):
			salud.died.connect(_on_jugador_muerto.bind(jugador))
	RunManager.iniciar_partida()
	cargar_nuevo_mapa()
	RunManager.iniciar_ronda(1)
	if banner_intro != null and banner_intro.has_method("mostrar_intro"):
		await banner_intro.mostrar_intro(1, _mapa_info_actual)
	_ronda_activa = true


func _on_jugador_muerto(jugador: Node) -> void:
	if not _ronda_activa or _procesando:
		return
	var numero: int = jugador.player_number
	RunManager.perder_vida(numero)

	# Free-for-all: la ronda sigue mientras haya más de un jugador vivo.
	var vivos := _jugadores_vivos()
	if vivos.size() > 1:
		return

	_procesando = true
	_ronda_activa = false
	_limpiar_proyectiles()

	var ganador: int = vivos[0].player_number if vivos.size() == 1 else 0
	RunManager.terminar_ronda(ganador)

	if banner_ganador != null and ganador > 0 and banner_ganador.has_method("mostrar_ganador"):
		await banner_ganador.mostrar_ganador(ganador)

	if RunManager.partida_ganada():
		if pantalla_fin != null and pantalla_fin.has_method("mostrar"):
			pantalla_fin.mostrar(RunManager.ganador_partida())
		_procesando = false
		return

	if pantalla_mejoras != null and pantalla_mejoras.has_method("abrir"):
		await pantalla_mejoras.abrir()
	_limpiar_proyectiles()

	if MapManager.total_activos() > 1:
		cargar_nuevo_mapa()

	for jug in RunManager.jugadores():
		if not is_instance_valid(jug):
			continue
		if RunManager.vidas_de(jug.player_number) > 0 and jug.has_method("respawn"):
			jug.respawn()
	var proxima_ronda: int = RunManager.ronda + 1
	RunManager.iniciar_ronda(proxima_ronda)
	if banner_intro != null and banner_intro.has_method("mostrar_intro"):
		await banner_intro.mostrar_intro(proxima_ronda, _mapa_info_actual)
	_ronda_activa = true
	_procesando = false


func _jugadores_vivos() -> Array:
	var lista: Array = []
	for jug in RunManager.jugadores():
		if is_instance_valid(jug) and RunManager.vidas_de(jug.player_number) > 0 and jug.is_alive():
			lista.append(jug)
	return lista


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
	_mapa_info_actual = info
	var escena_path: String = info.get("escena", "")
	if escena_path.is_empty():
		return

	var escena_mapa: PackedScene = load(escena_path)
	if escena_mapa == null:
		return

	_mapa_actual = escena_mapa.instantiate() as Node2D
	map_container.add_child(_mapa_actual)

	for jug in RunManager.jugadores():
		if not is_instance_valid(jug):
			continue
		var numero: int = jug.player_number
		if RunManager.vidas_de(numero) <= 0:
			continue
		var marker := _mapa_actual.get_node_or_null("SpawnP%d" % numero) as Marker2D
		var spawn_pos: Vector2 = marker.global_position if marker != null else SPAWNS_FALLBACK.get(numero, Vector2(640, 600))

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

extends Node

@export var pantalla_mejoras: CanvasLayer
@export var pantalla_fin: CanvasLayer
@export var banner_ganador: CanvasLayer
@export var banner_intro: CanvasLayer
@export var banner_baja: CanvasLayer

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
	if banner_baja == null and get_parent() != null:
		banner_baja = get_parent().get_node_or_null("KillBanner")

	for jugador in RunManager.jugadores():
		var salud: Node = jugador.get_node_or_null("HealthComponent")
		if salud != null and not salud.died.is_connected(_on_jugador_muerto.bind(jugador)):
			salud.died.connect(_on_jugador_muerto.bind(jugador))

	RunManager.iniciar_partida()
	cargar_nuevo_mapa()
	_revivir_caidos()
	_congelar_jugadores(true)
	RunManager.iniciar_ronda(1)

	if banner_intro != null and banner_intro.has_method("mostrar_intro"):
		await banner_intro.mostrar_intro(1, _mapa_info_actual)

	_congelar_jugadores(false)
	_ronda_activa = true


func _process(_delta: float) -> void:
	if not _ronda_activa or _procesando:
		return
	# Verificación de seguridad: si algún jugador con vidas murió y el evento no se procesó, procesarlo
	for jug in RunManager.jugadores():
		if not is_instance_valid(jug):
			continue
		if not jug.is_alive() and RunManager.vidas_de(jug.player_number) > 0:
			_on_jugador_muerto(jug)
			break


func _on_jugador_muerto(jugador: Node) -> void:
	if not is_instance_valid(jugador) or _procesando:
		return
	var numero: int = jugador.player_number
	RunManager.perder_vida(numero)

	if RunManager.vidas_de(numero) > 0:
		# Sigue en la ronda: animación de baja y reposicionamiento de ambos jugadores a spawns distribuidos
		_procesar_baja_intermedia(jugador)
		return

	# Se quedó sin vidas en esta ronda.
	var con_vidas := RunManager.jugadores_con_vidas()
	if con_vidas.size() == 1 and not con_vidas[0].is_alive():
		RunManager.perder_vida(con_vidas[0].player_number)
		con_vidas = RunManager.jugadores_con_vidas()

	if con_vidas.size() > 1:
		_procesar_baja_intermedia(jugador)
		return

	_procesando = true
	_ronda_activa = false
	_limpiar_proyectiles()
	_congelar_jugadores(true)

	var ganador: int = con_vidas[0].player_number if con_vidas.size() == 1 else 0
	RunManager.terminar_ronda(ganador)

	if RunManager.partida_ganada():
		if pantalla_fin != null and pantalla_fin.has_method("mostrar"):
			pantalla_fin.mostrar(RunManager.ganador_partida())
		_procesando = false
		return

	if banner_ganador != null and ganador > 0 and banner_ganador.has_method("mostrar_ganador"):
		await banner_ganador.mostrar_ganador(ganador)

	if pantalla_mejoras != null and pantalla_mejoras.has_method("abrir"):
		await pantalla_mejoras.abrir()
	_limpiar_proyectiles()

	if MapManager.total_activos() > 1:
		cargar_nuevo_mapa()
	else:
		_asignar_spawns_distribuidos()

	_revivir_caidos()
	_congelar_jugadores(true)
	RunManager.iniciar_ronda(RunManager.ronda + 1)

	if banner_intro != null and banner_intro.has_method("mostrar_intro"):
		await banner_intro.mostrar_intro(RunManager.ronda, _mapa_info_actual)

	_congelar_jugadores(false)
	_ronda_activa = true
	_procesando = false


func _procesar_baja_intermedia(jugador_muerto: Node) -> void:
	_ronda_activa = false
	_procesando = true

	# Congelar movimiento y controles de todos los jugadores de inmediato
	_congelar_jugadores(true)

	# Esperar a que concluya la secuencia de hitstop/cámara lenta de muerte
	await get_tree().create_timer(0.55, true, false, true).timeout
	Engine.time_scale = 1.0

	_limpiar_proyectiles()

	# Asignar los nuevos spawns y recolocar/revivir a los duelistas MIENTRAS el banner se muestra
	_asignar_spawns_distribuidos()
	_revivir_caidos()
	_congelar_jugadores(true)

	# Mostrar la mini animación de baja
	var num_muerto: int = jugador_muerto.player_number
	if banner_baja != null and banner_baja.has_method("mostrar_baja"):
		await banner_baja.mostrar_baja(num_muerto, RunManager.vidas_de(num_muerto))
	else:
		await get_tree().create_timer(0.5).timeout

	_limpiar_proyectiles()

	# Descongelar a los jugadores en su posición final sin teletransporte extra
	_congelar_jugadores(false)
	_ronda_activa = true
	_procesando = false


func _congelar_jugadores(congelar: bool) -> void:
	for jug in RunManager.jugadores():
		if not is_instance_valid(jug):
			continue
		jug.can_control = not congelar
		jug.velocity = Vector2.ZERO
		jug.set_physics_process(not congelar)


func _revivir_caidos() -> void:
	for jug in RunManager.jugadores():
		if not is_instance_valid(jug):
			continue
		if RunManager.vidas_de(jug.player_number) > 0:
			if jug.has_method("respawn"):
				jug.respawn()
		else:
			jug.visible = false
			jug.can_control = false


func _obtener_spawns_mapa() -> Array[Vector2]:
	var lista: Array[Vector2] = []
	if _mapa_actual == null or not is_instance_valid(_mapa_actual):
		return lista
	for hijo in _mapa_actual.get_children():
		if hijo is Marker2D and hijo.name.begins_with("Spawn"):
			lista.append(hijo.global_position)
	return lista


func _asignar_spawns_distribuidos() -> void:
	var spawns := _obtener_spawns_mapa()
	var jugadores := RunManager.jugadores()
	if spawns.is_empty():
		for jug in jugadores:
			if is_instance_valid(jug):
				var num: int = jug.player_number
				var fb: Vector2 = SPAWNS_FALLBACK.get(num, Vector2(640, 600))
				jug.set("_spawn_position", fb)
				jug.global_position = fb
				jug.velocity = Vector2.ZERO
		return

	spawns.shuffle()

	var seleccionados: Array[Vector2] = []
	const DIST_MIN := 240.0

	for jug in jugadores:
		if not is_instance_valid(jug):
			continue
		var mejor_spawn: Vector2 = spawns[0]
		var encontrado := false
		for sp in spawns:
			if seleccionados.has(sp):
				continue
			var muy_cerca := false
			for ya in seleccionados:
				if sp.distance_to(ya) < DIST_MIN:
					muy_cerca = true
					break
			if not muy_cerca:
				mejor_spawn = sp
				encontrado = true
				break

		if not encontrado:
			for sp in spawns:
				if not seleccionados.has(sp):
					mejor_spawn = sp
					break

		seleccionados.append(mejor_spawn)
		jug.set("_spawn_position", mejor_spawn)
		jug.global_position = mejor_spawn
		jug.velocity = Vector2.ZERO


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
	MapManager.aplicar_estilo_mapa(_mapa_actual, _mapa_info_actual)
	map_container.add_child(_mapa_actual)

	_asignar_spawns_distribuidos()


func _limpiar_proyectiles() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for entidad in tree.get_nodes_in_group("bullet"):
		if is_instance_valid(entidad):
			entidad.queue_free()

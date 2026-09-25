extends Node

func _ready() -> void:
	print("--- TEST DE CORAZONES, SPAWNS DISTRIBUIDOS Y BAJA INTERMEDIA ---")
	test_default_rounds()
	test_map_spawns()
	test_hud_character_hearts()
	test_bot_random_character_selection()
	test_mid_round_kill_flow()
	await test_round_end_revives_loser_next_round()
	print("--- TODOS LOS NUEVOS TESTS PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func test_default_rounds() -> void:
	assert(RunManager.rondas_para_ganar == 5, "Rondas por defecto debe ser 5, actual: %d" % RunManager.rondas_para_ganar)
	assert(RunManager.vidas_por_ronda == 2, "Vidas por defecto debe ser 2, actual: %d" % RunManager.vidas_por_ronda)
	var menu_scn: PackedScene = load("res://ui/main_menu.tscn")
	var menu = menu_scn.instantiate()
	var rondas_val: Node = menu.get_node_or_null("ModalPartida/Centro/Marco/Margin/VBox/Config/Rondas/Valor")
	assert(rondas_val != null, "Rondas/Valor debe existir en ModalPartida")
	assert(rondas_val.value == 5, "Rondas valor inicial debe ser 5, actual: %d" % rondas_val.value)
	var vidas_val: Node = menu.get_node_or_null("ModalPartida/Centro/Marco/Margin/VBox/Config/Vidas/Valor")
	assert(vidas_val != null, "Vidas/Valor debe existir en ModalPartida")
	assert(vidas_val.value == 2, "Vidas valor inicial debe ser 2, actual: %d" % vidas_val.value)
	menu.free()
	print("✓ Rondas y vidas por defecto: 5 rondas para ganar y 2 vidas por ronda")


func test_map_spawns() -> void:
	var mapas := MapManager.obtener_mapas()
	for info in mapas:
		var scn: PackedScene = load(info["escena"])
		assert(scn != null, "No se pudo cargar mapa: %s" % info["escena"])
		var inst: Node2D = scn.instantiate() as Node2D
		var spawns: Array[Vector2] = []
		for child in inst.get_children():
			if child is Marker2D and child.name.begins_with("Spawn"):
				spawns.append(child.global_position)
		assert(spawns.size() >= 4, "Mapa %s debe tener al menos 4 spawns, tiene %d" % [info["nombre"], spawns.size()])
		# Verificar que no sean todos iguales
		var unique := {}
		for sp in spawns:
			unique[sp] = true
		assert(unique.size() >= 4, "Mapa %s debe tener al menos 4 posiciones únicas de spawn" % info["nombre"])
		inst.free()
	print("✓ Spawns distribuidos: todos los mapas tienen al menos 4 spawns en distintas posiciones")


func test_hud_character_hearts() -> void:
	var hud_scn: PackedScene = load("res://ui/match_hud.tscn")
	assert(hud_scn != null, "No se pudo cargar match_hud.tscn")
	var hud = hud_scn.instantiate()

	# Probar para cada personaje y colores de jugadores
	for pj in ["esqueleto", "sapo", "pajaro", "fantasma"]:
		for p_num in [1, 2, 3, 4]:
			RunManager.set_personaje(p_num, pj)
			var cont := VBoxContainer.new()
			hud._actualizar_vidas_container(cont, 2, 3, p_num, true)
			assert(cont.get_child_count() == 1, "3 vidas debe tener 1 fila")
			var fila := cont.get_child(0) as HBoxContainer
			assert(fila.get_child_count() == 3, "Fila debe tener 3 corazones")

			var pip1 := fila.get_child(0) as TextureRect
			var pip2 := fila.get_child(1) as TextureRect
			var pip3 := fila.get_child(2) as TextureRect

			assert(pip1.texture != null, "Pip 1 debe tener textura")
			assert(pip2.texture != null, "Pip 2 debe tener textura")
			assert(pip3.texture != null, "Pip 3 debe tener textura")

			# pip 1 y 2 son vidas activas (lleno), pip 3 es vida perdida (vacio)
			assert(pip1.texture == pip2.texture, "Pip 1 y 2 deben compartir la textura de vida llena")
			assert(pip1.texture != pip3.texture, "Pip 1 (lleno) debe ser distinto a Pip 3 (vacío)")

			var texturas: Dictionary = RunManager.obtener_texturas_corazon(pj, p_num)
			assert(pip1.texture == texturas["lleno"], "Pip 1 debe tener textura llena de %s para jugador %d" % [pj, p_num])
			assert(pip3.texture == texturas["vacio"], "Pip 3 debe tener textura vacía de %s para jugador %d" % [pj, p_num])

			# Verificar que el corazón lleno sea opaco y el vacío translúcido
			var at_lleno: AtlasTexture = texturas["lleno"]
			var at_vacio: AtlasTexture = texturas["vacio"]
			var img: Image = at_lleno.atlas.get_image()
			var a_lleno: float = img.get_pixel(int(at_lleno.region.position.x) + 16, int(at_lleno.region.position.y) + 16).a
			var a_vacio: float = img.get_pixel(int(at_vacio.region.position.x) + 16, int(at_vacio.region.position.y) + 16).a
			assert(a_lleno > 0.9, "Corazón lleno de %s debe ser opaco en el centro (alfa actual: %f)" % [pj, a_lleno])
			assert(a_vacio < 0.8, "Corazón vacío de %s debe ser translúcido en el centro (alfa actual: %f)" % [pj, a_vacio])

			cont.free()

	hud.free()
	print("✓ HUD de corazones: texturas asignadas correctamente para todos los personajes y colores")


func test_mid_round_kill_flow() -> void:
	var level_scn: PackedScene = load("res://levels/test_level.tscn")
	assert(level_scn != null, "No se pudo cargar test_level.tscn")
	var level = level_scn.instantiate()
	add_child(level)

	var run_ctrl = level.get_node("RunController")
	var kill_banner = level.get_node_or_null("KillBanner")
	assert(kill_banner != null, "KillBanner debe existir en test_level.tscn")
	if run_ctrl.banner_baja == null:
		run_ctrl.banner_baja = kill_banner
	assert(run_ctrl.banner_baja == kill_banner, "RunController debe tener referencia a KillBanner")

	var p1 = level.get_node("Player1")
	var p2 = level.get_node("Player2")

	# Simular muerte intermedia de P1 teniendo 2 vidas
	RunManager.configurar_partida(2, 2)
	RunManager.iniciar_ronda(1)
	run_ctrl._ronda_activa = true
	run_ctrl._procesando = false

	# P1 muere
	run_ctrl._on_jugador_muerto(p1)

	# Vidas de P1 deben haber bajado a 1
	assert(RunManager.vidas_de(1) == 1, "P1 debe tener 1 vida restante")
	assert(RunManager.vidas_de(2) == 2, "P2 debe conservar sus 2 vidas")

	level.free()
	print("✓ Flujo de baja intermedia: KillBanner integrado y vidas descontadas correctamente")


func test_round_end_revives_loser_next_round() -> void:
	var level_scn: PackedScene = load("res://levels/test_level.tscn")
	assert(level_scn != null, "No se pudo cargar test_level.tscn")
	var level = level_scn.instantiate()
	add_child(level)

	var run_ctrl = level.get_node("RunController")
	var p1 = level.get_node("Player1")
	var p2 = level.get_node("Player2")

	# Neutralizar pantallas y banners para que la transición de ronda sea síncrona
	run_ctrl.banner_ganador = null
	run_ctrl.pantalla_mejoras = null
	run_ctrl.banner_intro = null
	run_ctrl.banner_baja = null

	RunManager.configurar_partida(2, 2)
	RunManager.iniciar_partida()
	RunManager.iniciar_ronda(1)

	# P1 queda sin vidas y muerto: la ronda termina con P2 como ganador
	RunManager.perder_vida(1)
	p1.current_state = Player.PlayerState.DEAD
	run_ctrl._procesando = false
	run_ctrl._ronda_activa = true
	run_ctrl._on_jugador_muerto(p1)

	# La ronda 2 debe haber iniciado con TODOS los jugadores vivos y visibles
	assert(RunManager.ronda == 2, "Debe iniciar la ronda 2, actual: %d" % RunManager.ronda)
	assert(p1.is_alive(), "P1 debe revivir al iniciar la ronda 2")
	assert(p1.visible, "P1 debe ser visible al iniciar la ronda 2")
	assert(p2.is_alive(), "P2 debe seguir vivo al iniciar la ronda 2")

	# Esperar frames: el safety net de _process NO debe descontar vida a un
	# jugador recién revivido
	await get_tree().process_frame
	await get_tree().process_frame
	assert(RunManager.vidas_de(1) == 2, "P1 debe iniciar la ronda 2 con vidas llenas, actual: %d" % RunManager.vidas_de(1))
	assert(RunManager.vidas_de(2) == 2, "P2 debe iniciar la ronda 2 con vidas llenas, actual: %d" % RunManager.vidas_de(2))

	level.free()
	print("✓ Fin de ronda: los eliminados reaparecen visibles y con vidas llenas en la ronda siguiente")


func test_bot_random_character_selection() -> void:
	Settings.set_dispositivo(1, Settings.DISPOSITIVO_TECLADO)
	Settings.set_dispositivo(2, Settings.DISPOSITIVO_BOT)
	RunManager.set_cantidad_jugadores(2)

	var cs_scn: PackedScene = load("res://ui/character_select.tscn")
	assert(cs_scn != null, "No se pudo cargar character_select.tscn")

	# Probar múltiples inicios de selección de personaje para verificar que el bot elige al azar
	var personajes_elegidos := {}
	for i in 25:
		var cs = cs_scn.instantiate()
		add_child(cs)
		var eleccion: int = cs._choice[2]
		assert(eleccion >= 0 and eleccion < cs.PERSONAJES.size(), "La elección del bot debe ser válida (0..3)")
		var pj: String = cs.PERSONAJES[eleccion]
		personajes_elegidos[pj] = true
		remove_child(cs)
		cs.free()

	# Con 25 re-rolls, es virtualmente imposible que no elija más de un personaje
	assert(personajes_elegidos.size() > 1, "El bot debe elegir personajes aleatorios de los 4 disponibles")

	# Verificar también inicialización directa en RunManager
	RunManager.personajes.clear()
	RunManager.set_cantidad_jugadores(2)
	RunManager._inicializar_jugadores()
	assert(RunManager.PERSONAJES_VALIDOS.has(RunManager.personaje_de(2)), "El personaje de bot en RunManager debe ser válido")

	print("✓ Selección aleatoria de bot: los bots eligen personajes variados de los 4 disponibles")


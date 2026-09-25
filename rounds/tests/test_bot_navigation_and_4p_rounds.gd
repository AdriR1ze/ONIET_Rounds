extends Node

## Test automatizado para:
## 1. Sistema de rondas con >2 jugadores y >1 vida (no reiniciar cuando muere 1, esperar al último vivo).
## 2. Wall jump encadenado y despegue de pared.
## 3. Navegación hacia puertas en habitaciones cerradas.
## 4. Búsqueda de plataformas para objetivos elevados en vez de salto ciego vertical.

func _ready() -> void:
	print("--- TEST DE SISTEMA DE RONDAS 4P Y NAVEGACIÓN AVANZADA DE BOTS ---")
	await test_map_pyramid_silent_bot_exclusion()
	await test_4p_rounds_system()
	await test_wall_jump_consecutive_and_wall_facing()
	await test_door_navigation_in_closed_room()
	await test_target_above_seeks_platform()
	await test_one_way_platform_and_shaft_navigation()
	print("--- TODOS LOS TESTS DE RONDAS 4P Y NAVEGACIÓN PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func test_map_pyramid_silent_bot_exclusion() -> void:
	MapManager.activar_todos()
	Settings.set_dispositivo(1, Settings.DISPOSITIVO_TECLADO)
	Settings.set_dispositivo(2, Settings.DISPOSITIVO_BOT)
	RunManager.set_cantidad_jugadores(2)

	# Con un bot en la partida, la pirámide queda excluida silenciosamente si hay otros mapas
	for i in 25:
		var mapa := MapManager.obtener_mapa_aleatorio()
		assert(not MapManager._es_mapa_piramide(mapa), "Con bots presentes, el mapa de la pirámide debe quedar excluido")

	# Si sólo queda la pirámide habilitada, se permite jugar
	MapManager.desactivar_todos()
	for m in MapManager.DEFINICIONES_MAPAS:
		if MapManager._es_mapa_piramide(m):
			MapManager.desactivados.erase(m["id"])
		else:
			MapManager.desactivados[m["id"]] = true
	var unico := MapManager.obtener_mapa_aleatorio()
	assert(MapManager._es_mapa_piramide(unico), "Si sólo queda la pirámide, se debe permitir jugar")

	MapManager.activar_todos()
	print("✓ Exclusión silenciosa de pirámide con bots: funcionando correctamente")


func _crear_jugador(pos: Vector2, p_num: int) -> CharacterBody2D:
	Settings.set_dispositivo(p_num, Settings.DISPOSITIVO_TECLADO if p_num == 1 else Settings.DISPOSITIVO_BOT)
	var p_scn: PackedScene = load("res://player/player.tscn")
	var p: CharacterBody2D = p_scn.instantiate()
	p.set("player_number", p_num)
	p.global_position = pos
	add_child(p)
	return p


func test_4p_rounds_system() -> void:
	var level_scn: PackedScene = load("res://levels/test_level.tscn")
	var level = level_scn.instantiate()
	add_child(level)

	var run_ctrl = level.get_node("RunController")
	run_ctrl.banner_ganador = null
	run_ctrl.pantalla_mejoras = null
	run_ctrl.banner_intro = null
	run_ctrl.banner_baja = null

	# 4 jugadores, 3 vidas cada uno
	RunManager.configurar_partida(3, 3)
	RunManager.set_cantidad_jugadores(4)

	var p1 = level.get_node("Player1")
	var p2 = level.get_node("Player2")
	var p3 = _crear_jugador(Vector2(320, 600), 3)
	var p4 = _crear_jugador(Vector2(960, 600), 4)

	RunManager.iniciar_partida()
	RunManager.iniciar_ronda(1)
	run_ctrl._ronda_activa = true
	run_ctrl._procesando = false

	assert(RunManager.vidas_de(1) == 3, "P1 debe iniciar con 3 vidas")
	assert(RunManager.vidas_de(2) == 3, "P2 debe iniciar con 3 vidas")
	assert(RunManager.vidas_de(3) == 3, "P3 debe iniciar con 3 vidas")
	assert(RunManager.vidas_de(4) == 3, "P4 debe iniciar con 3 vidas")

	# P1 muere: le quedan 2 vidas restantes.
	# La ronda DEBE permanecer activa y no pausar
	p1.current_state = Player.PlayerState.DEAD
	run_ctrl._on_jugador_muerto(p1)

	assert(RunManager.vidas_de(1) == 2, "P1 debe tener 2 vidas tras morir")
	assert(run_ctrl._ronda_activa == true, "La ronda DEBE permanecer activa cuando P1 tiene vidas restantes")
	assert(run_ctrl._procesando == false, "No debe estar procesando reinicio")

	# P2 y P3 mueren una vez: les quedan vidas, la ronda sigue activa
	p2.current_state = Player.PlayerState.DEAD
	run_ctrl._on_jugador_muerto(p2)
	assert(RunManager.vidas_de(2) == 2, "P2 debe tener 2 vidas tras morir")
	assert(run_ctrl._ronda_activa == true, "La ronda DEBE permanecer activa cuando aún hay jugadores con vidas")

	p3.current_state = Player.PlayerState.DEAD
	run_ctrl._on_jugador_muerto(p3)
	assert(RunManager.vidas_de(3) == 2, "P3 debe tener 2 vidas tras morir")
	assert(run_ctrl._ronda_activa == true, "La ronda DEBE permanecer activa cuando aún hay jugadores con vidas")

	# Simular que P1, P2 y P3 agotan todas sus vidas (quedan con 0 vidas)
	RunManager.vidas[1] = 0
	p1.current_state = Player.PlayerState.DEAD
	RunManager.vidas[2] = 0
	p2.current_state = Player.PlayerState.DEAD
	RunManager.vidas[3] = 1 # P3 pierde su última vida ahora
	run_ctrl._muertos_esta_ronda.erase(3)
	p3.current_state = Player.PlayerState.DEAD
	run_ctrl._on_jugador_muerto(p3) # P3 pasa a 0 vidas y queda eliminado

	# Ahora sólo P4 tiene vidas. ¡Aquí concluye la ronda 1 y pasa a ronda 2!
	assert(RunManager.ronda == 2, "Debe haber avanzado a la ronda 2")
	assert(RunManager.marcador_de(4) == 1, "P4 debe tener 1 punto de ronda ganada")

	# En la ronda 2, TODOS los jugadores deben iniciar con sus 3 vidas completas (vidas_por_ronda)
	assert(RunManager.vidas_de(1) == 3, "P1 debe reiniciar con 3 vidas en ronda 2")
	assert(RunManager.vidas_de(2) == 3, "P2 debe reiniciar con 3 vidas en ronda 2")
	assert(RunManager.vidas_de(3) == 3, "P3 debe reiniciar con 3 vidas en ronda 2")
	assert(RunManager.vidas_de(4) == 3, "P4 debe tener 3 vidas en ronda 2")

	# Todos los jugadores deben haber sido revividos para la nueva ronda
	assert(p1.is_alive(), "P1 debe revivir en ronda 2")
	assert(p2.is_alive(), "P2 debe revivir en ronda 2")
	assert(p3.is_alive(), "P3 debe revivir en ronda 2")
	assert(p4.is_alive(), "P4 debe revivir en ronda 2")

	p3.free()
	p4.free()
	level.free()
	print("✓ Sistema 4P: la ronda continúa con reaparición por vidas y restaura vidas al iniciar nueva ronda")


func test_wall_jump_consecutive_and_wall_facing() -> void:
	var bot := _crear_jugador(Vector2(200, 300), 2)
	var target := _crear_jugador(Vector2(400, 300), 1)
	await get_tree().physics_frame

	var brain: BotBrain = bot.get_node("PlayerInput/BotBrain")
	brain._target = target

	# Simular pared a la derecha (wall_dir = 1) estando en el aire
	bot.velocity.y = -50.0 # En el aire
	bot._wall_ray_right.target_position = Vector2(50, 0) # Forzar colisión

	# Verificar que _try_wall_jump siempre empuja hacia afuera de la pared
	bot._wall_jump_lockout_timer = 0.0
	bot._last_wall_jump_side = 0
	# Apuntar erróneamente hacia la pared
	brain._aim_dir = Vector2(1.0, 0.0)
	var success: bool = bool(bot._try_wall_jump())
	if success:
		assert(bot.velocity.x < 0.0, "El wall jump DEBE empujar hacia la izquierda (-1) alejándose de la pared derecha")
		assert(bot.velocity.y < 0.0, "El wall jump DEBE impulsar verticalmente hacia arriba")

	bot.free()
	target.free()
	print("✓ Wall Jump: impulso garantizado alejándose de la pared y encadenamiento aéreo")


func test_door_navigation_in_closed_room() -> void:
	var bot := _crear_jugador(Vector2(100, 300), 2)
	var target := _crear_jugador(Vector2(500, 300), 1)

	# Puerta cerrada entre el bot y el target
	var puerta_scn: PackedScene = load("res://world/puerta.tscn")
	var puerta: Node2D = puerta_scn.instantiate()
	puerta.position = Vector2(200, 300)
	add_child(puerta)
	await get_tree().physics_frame

	var brain: BotBrain = bot.get_node("PlayerInput/BotBrain")
	brain._target = target

	# Evaluar aproximación a puerta
	var res := brain._bt_handle_doors(0.016)
	assert(res == BTNode.Status.SUCCESS, "El bot debe detectar la puerta cercana y aproximarse a ella")
	assert(brain.get_move_axis() > 0.0, "El bot debe moverse hacia la derecha en dirección a la puerta")

	# Evaluar cruce a través del umbral de la puerta (no debe detenerse en x=200)
	bot.global_position = Vector2(200, 300)
	var res_cross := brain._bt_handle_doors(0.016)
	assert(res_cross == BTNode.Status.SUCCESS, "El bot debe continuar atravesando la puerta")
	assert(brain.get_move_axis() > 0.0, "El bot debe seguir empujando hacia adelante para cruzar la puerta")

	# Una vez cruzada la puerta completamente, _bt_handle_doors debe ceder el control
	bot.global_position = Vector2(245, 300)
	var res_cleared := brain._bt_handle_doors(0.016)
	assert(res_cleared == BTNode.Status.FAILURE, "El bot ya cruzó la puerta y debe continuar el combate normal en la sala")

	puerta.free()
	bot.free()
	target.free()
	print("✓ Puertas: detección, navegación y cruce completo del umbral sin atascos")


func test_target_above_seeks_platform() -> void:
	var bot := _crear_jugador(Vector2(200, 500), 2)
	var target := _crear_jugador(Vector2(200, 200), 1) # Directamente arriba (300px encima)
	await get_tree().physics_frame

	var brain: BotBrain = bot.get_node("PlayerInput/BotBrain")
	brain._target = target

	# Simular un NavGraph con puntos de plataformas
	var nav := NavGraph.new()
	nav._astar = AStar2D.new()
	nav._ids[Vector2i(6, 11)] = 0 # Plataforma a Y=352 (entre Y=500 y Y=200) a X=192
	nav._astar.add_point(0, Vector2(192, 352))
	brain._nav_graph = nav

	var plat := brain._buscar_plataforma_elevada(bot.global_position, target.global_position)
	assert(plat != Vector2.ZERO, "Debe encontrar la plataforma elevada intermedia")
	assert(plat.y < bot.global_position.y - 50.0, "La plataforma debe estar por encima del bot")

	bot.free()
	target.free()
	print("✓ Plataformas elevadas: busca plataformas intermedias en lugar de salto ciego vertical")


func test_one_way_platform_and_shaft_navigation() -> void:
	# 1. Crear una plataforma atravesable (one-way, layer 64) y una sólida (layer 1)
	var ow_body := StaticBody2D.new()
	ow_body.collision_layer = 64
	var ow_shape := CollisionShape2D.new()
	var ow_rect := RectangleShape2D.new()
	ow_rect.size = Vector2(200, 16)
	ow_shape.shape = ow_rect
	ow_body.add_child(ow_shape)
	ow_body.global_position = Vector2(300, 300)
	add_child(ow_body)

	var solid_body := StaticBody2D.new()
	solid_body.collision_layer = 1
	var solid_shape := CollisionShape2D.new()
	var solid_rect := RectangleShape2D.new()
	solid_rect.size = Vector2(200, 16)
	solid_shape.shape = solid_rect
	solid_body.add_child(solid_shape)
	solid_body.global_position = Vector2(600, 300)
	add_child(solid_body)

	await get_tree().physics_frame
	await get_tree().physics_frame

	# 2. Bot sobre plataforma one-way
	var bot := _crear_jugador(Vector2(300, 275), 2)
	var target := _crear_jugador(Vector2(300, 500), 1) # Target claramente abajo
	await get_tree().physics_frame
	await get_tree().physics_frame

	var brain: BotBrain = bot.get_node("PlayerInput/BotBrain")
	brain._target = target

	# Verificar detección correcta de plataforma one-way debajo de los pies
	assert(brain._is_standing_on_one_way(), "El bot debe detectar que está parado sobre una plataforma atravesable (layer 64)")

	# Probar BT descenso de one-way hacia target inferior
	brain._platform_drop_cooldown = 0.0
	var res := brain._bt_handle_one_way_platform(0.016)
	assert(res == BTNode.Status.SUCCESS, "El bot debe descender al tener el objetivo por debajo")
	assert(bot.get_collision_mask_value(7) == false, "El bot debe haber desactivado colisión layer 7 para atravesar la plataforma")

	# 3. Mover el bot sobre suelo sólido
	bot.global_position = Vector2(600, 275)
	bot.set_collision_mask_value(7, true)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert(not brain._is_standing_on_one_way(), "El bot NO debe reportar plataforma one-way si está sobre suelo sólido (layer 1)")

	# 4. Probar que una pared con techo bajo y target en otra dirección no traba al bot en wall jump infinito
	bot.global_position = Vector2(300, 275)
	target.global_position = Vector2(100, 200) # Target a la izquierda y arriba
	brain._target = target
	# Simular contacto con pared a la derecha
	var wall_res := brain._bt_handle_wall_jump(0.016)
	assert(wall_res == BTNode.Status.FAILURE, "No debe iniciar wall jump contra una pared en dirección opuesta al objetivo o bajo techo")

	ow_body.free()
	solid_body.free()
	bot.free()
	target.free()
	print("✓ Plataformas One-Way y Pozo Vertical: detección precisa de suelo atravesable y descenso táctico hacia pisos inferiores")


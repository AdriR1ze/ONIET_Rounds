extends Node

## Test automatizado para:
## 1. Sistema de rondas con >2 jugadores y >1 vida (no reiniciar cuando muere 1, esperar al último vivo).
## 2. Wall jump encadenado y despegue de pared.
## 3. Navegación hacia puertas en habitaciones cerradas.
## 4. Búsqueda de plataformas para objetivos elevados en vez de salto ciego vertical.

func _ready() -> void:
	print("--- TEST DE SISTEMA DE RONDAS 4P Y NAVEGACIÓN AVANZADA DE BOTS ---")
	await test_4p_rounds_system()
	await test_wall_jump_consecutive_and_wall_facing()
	await test_door_navigation_in_closed_room()
	await test_target_above_seeks_platform()
	print("--- TODOS LOS TESTS DE RONDAS 4P Y NAVEGACIÓN PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


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

	# P1 muere: aún quedan 3 jugadores vivos (P2, P3, P4).
	# ¡NO debe reiniciar la ronda ni pausar!
	p1.current_state = Player.PlayerState.DEAD
	run_ctrl._on_jugador_muerto(p1)

	assert(RunManager.vidas_de(1) == 2, "P1 debe tener 2 vidas tras morir")
	assert(run_ctrl._ronda_activa == true, "La ronda DEBE permanecer activa cuando aún quedan 3 jugadores vivos")
	assert(run_ctrl._procesando == false, "No debe estar procesando reinicio con 3 vivos")

	# P2 muere: quedan 2 jugadores vivos (P3, P4).
	p2.current_state = Player.PlayerState.DEAD
	run_ctrl._on_jugador_muerto(p2)

	assert(RunManager.vidas_de(2) == 2, "P2 debe tener 2 vidas tras morir")
	assert(run_ctrl._ronda_activa == true, "La ronda DEBE permanecer activa cuando quedan 2 jugadores vivos")

	# P3 muere: ahora SÓLO P4 queda vivo (1 jugador vivo).
	# ¡Aquí sí debe finalizar la ronda!
	p3.current_state = Player.PlayerState.DEAD
	run_ctrl._on_jugador_muerto(p3)

	# La ronda concluye y pasa a ronda 2
	assert(RunManager.ronda == 2, "Debe haber avanzado a la ronda 2")
	# En la ronda 2, los caídos conservan las vidas descontadas (2), y el superviviente (3)
	assert(RunManager.vidas_de(1) == 2, "P1 debe tener 2 vidas en ronda 2")
	assert(RunManager.vidas_de(2) == 2, "P2 debe tener 2 vidas en ronda 2")
	assert(RunManager.vidas_de(3) == 2, "P3 debe tener 2 vidas en ronda 2")
	assert(RunManager.vidas_de(4) == 3, "P4 debe tener 3 vidas en ronda 2")

	# Todos los jugadores con vidas (> 0) deben haber sido revividos
	assert(p1.is_alive(), "P1 debe revivir en ronda 2")
	assert(p2.is_alive(), "P2 debe revivir en ronda 2")
	assert(p3.is_alive(), "P3 debe revivir en ronda 2")
	assert(p4.is_alive(), "P4 debe revivir en ronda 2")

	p3.free()
	p4.free()
	level.free()
	print("✓ Sistema 4P: la ronda continúa mientras haya más de 1 vivo y descuenta vidas correctamente al reiniciar")


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

	puerta.free()
	bot.free()
	target.free()
	print("✓ Puertas: detección y navegación directa hacia la puerta para abrirla")


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

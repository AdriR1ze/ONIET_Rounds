extends Node

func _ready() -> void:
	print("--- TEST DE BAJADA DE ONE-WAY, ESPACIADO DE BOTS Y SALTO ENTRE PLATAFORMAS ---")
	await _test_one_way_drop()
	await _test_bot_spacing_no_glue()
	await _test_chained_platform_navigation()
	await _test_clean_navigation_no_random_jumps_or_wall_bounces()
	print("--- TODOS LOS TESTS PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func _crear_bot(pos: Vector2, p_num: int = 2) -> CharacterBody2D:
	Settings.set_dispositivo(p_num, Settings.DISPOSITIVO_BOT)
	var p_scn: PackedScene = load("res://player/player.tscn")
	var bot: CharacterBody2D = p_scn.instantiate()
	bot.set("player_number", p_num)
	bot.global_position = pos
	add_child(bot)
	return bot


func _test_one_way_drop() -> void:
	var bot := _crear_bot(Vector2(200, 200), 2)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Probar drop_through_platform
	bot.drop_through_platform()
	assert(bot.get_collision_mask_value(7) == false, "drop_through_platform debe desactivar capa 7")
	assert(bot.velocity.y >= 120.0, "drop_through_platform debe aplicar velocidad hacia abajo")

	# Probar reactivación tras timer
	bot._physics_process(0.25)
	assert(bot.get_collision_mask_value(7) == true, "La capa 7 debe reactivarse tras el timer")
	print("✓ Plataformas One-Way: descenso fluido y reactivación correcta")
	bot.queue_free()
	await get_tree().physics_frame


func _test_bot_spacing_no_glue() -> void:
	var bot1 := _crear_bot(Vector2(300, 400), 1)
	var bot2 := _crear_bot(Vector2(340, 400), 2) # Muy cerca (40 px de distancia)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var brain1: BotBrain = bot1.get_node("PlayerInput/BotBrain")
	var brain2: BotBrain = bot2.get_node("PlayerInput/BotBrain")
	brain1._target = bot2
	brain2._target = bot1

	# Simular actualización de BT para ambos
	brain1._tree.tick(0.016)
	brain2._tree.tick(0.016)

	# Bot 1 debe alejarse hacia la izquierda (move_axis < 0)
	# Bot 2 debe alejarse hacia la derecha (move_axis > 0)
	# ¡NO deben correr hacia el centro a pegarse!
	assert(brain1.get_move_axis() < 0.0, "Bot 1 debe retroceder alejándose de Bot 2, actual: %f" % brain1.get_move_axis())
	assert(brain2.get_move_axis() > 0.0, "Bot 2 debe retroceder alejándose de Bot 1, actual: %f" % brain2.get_move_axis())
	print("✓ Espaciado táctico humano: los bots no se pegan cuerpo a cuerpo, retroceden para mantener distancia de tiro")

	bot1.queue_free()
	bot2.queue_free()
	await get_tree().physics_frame


func _test_chained_platform_navigation() -> void:
	# Cargar un mapa con plataformas separadas (map_02_tres_pisos o map_04_repisas_orbes)
	var map_scn: PackedScene = load("res://levels/maps/map_02_tres_pisos.tscn")
	var map = map_scn.instantiate()
	add_child(map)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var tilemap: TileMapLayer = map.get_node("NeonTileMap")
	assert(tilemap != null, "NeonTileMap debe existir")

	var nav := NavGraph.get_or_build(tilemap, "test_chained_nav")

	# Buscar camino entre extremos de repisas separadas
	var start_pos := Vector2(200, 450)
	var end_pos := Vector2(800, 240)
	var path := nav.find_path(start_pos, end_pos)

	assert(not path.is_empty(), "NavGraph debe encontrar camino conectando plataformas separadas")
	print("✓ Navegación entre plataformas: NavGraph conecta plataformas consecutivas con saltos (puntos: %d)" % path.size())

	map.queue_free()
	await get_tree().physics_frame


func _test_clean_navigation_no_random_jumps_or_wall_bounces() -> void:
	var bot := _crear_bot(Vector2(200, 300), 2)
	var target := _crear_bot(Vector2(200, 600), 1) # Target claramente abajo en un pozo/tubo
	await get_tree().physics_frame
	await get_tree().physics_frame

	var brain: BotBrain = bot.get_node("PlayerInput/BotBrain")
	brain._target = target

	# 1. Simular descenso aéreo en un pozo tocando la pared lateral
	bot.velocity = Vector2(0.0, 150.0) # Cayendo en el aire
	bot._wall_ray_right.target_position = Vector2(40.0, 0.0) # Tocando pared a la derecha
	brain._current_path = PackedVector2Array([Vector2(200, 300), Vector2(200, 600)])
	brain._path_index = 1

	var wall_res := brain._bt_handle_wall_jump(0.016)
	# Al descender hacia un objetivo inferior, NO debe wall-jumpear hacia arriba
	assert(wall_res == BTNode.Status.FAILURE, "Al descender por un tubo, no debe hacer wall-jump hacia arriba")
	assert(not brain.is_jump_just_pressed(), "No debe presionar salto al caer por un tubo")

	# 2. Navegación en línea recta: no debe realizar saltos aleatorios ni girar 180°
	bot.velocity = Vector2(100.0, 0.0)
	brain._current_path = PackedVector2Array([Vector2(200, 300), Vector2(500, 300)])
	brain._path_index = 1
	target.global_position = Vector2(500, 300)

	for i in range(10):
		brain._bt_handle_navigation_and_spacing(0.016)
		assert(brain.get_move_axis() > 0.0, "El bot debe avanzar directamente hacia el waypoint sin revertir dirección")
		assert(not brain.is_jump_just_pressed(), "El bot no debe saltar aleatoriamente mientras camina en línea recta")
		assert(brain._edge_turnaround_timer == 0.0, "No debe activar giros en U sin precipicio")

	bot.queue_free()
	target.queue_free()
	await get_tree().physics_frame
	print("✓ Navegación limpia y directa: sin saltos aleatorios, sin rebotes de pared al descender tubos y sin giros erráticos")


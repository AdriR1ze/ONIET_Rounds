extends Node

func _ready() -> void:
	print("--- TEST DE PREVENCIÓN DE BUCLE DE MUERTE Y EVASIÓN DE ABISMO DEL BOT ---")
	test_freeze_during_intro()
	await test_bot_abyss_prevention()
	print("--- TODOS LOS TESTS DE ESTABILIDAD PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func test_freeze_during_intro() -> void:
	var level_scn: PackedScene = load("res://levels/test_level.tscn")
	assert(level_scn != null, "No se pudo cargar test_level.tscn")
	var level = level_scn.instantiate()
	add_child(level)

	var run_ctrl = level.get_node("RunController")
	var p1 = level.get_node("Player1")
	var p2 = level.get_node("Player2")

	# Congelar a los jugadores debe poner can_control = false y velocity = ZERO
	run_ctrl._congelar_jugadores(true)
	assert(not p1.can_control, "P1 debe tener can_control = false al estar congelado")
	assert(not p2.can_control, "P2 debe tener can_control = false al estar congelado")
	assert(p1.velocity == Vector2.ZERO, "P1 velocity debe ser ZERO")
	assert(p2.velocity == Vector2.ZERO, "P2 velocity debe ser ZERO")

	# Descongelar
	run_ctrl._congelar_jugadores(false)
	assert(p1.can_control, "P1 debe poder controlarse tras descongelar")
	assert(p2.can_control, "P2 debe poder controlarse tras descongelar")

	level.queue_free()
	print("✓ Congelamiento durante intros: jugadores inmovilizados sin riesgo de caer mientras se muestra el banner")


func test_bot_abyss_prevention() -> void:
	# Cargar un mapa con abismo (El Abismo)
	var scn: PackedScene = load("res://levels/maps/map_05_el_abismo.tscn")
	assert(scn != null, "No se pudo cargar map_05_el_abismo.tscn")
	var map = scn.instantiate() as Node2D
	add_child(map)

	Settings.set_dispositivo(2, Settings.DISPOSITIVO_BOT)
	var p_scn: PackedScene = load("res://player/player_2.tscn")
	var bot = p_scn.instantiate() as CharacterBody2D
	# Ubicar al bot cerca del borde derecho del bastión izquierdo (X=330, Y=340)
	bot.global_position = Vector2(325, 328)
	map.add_child(bot)

	var brain = bot.get_node("PlayerInput/BotBrain") as BotBrain
	assert(brain != null, "BotBrain debe existir")

	# Esperar frame de física para sincronizar colisiones en el servidor de física
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Simular aterrizaje en el suelo
	bot.velocity = Vector2(0, 100)
	bot.move_and_slide()

	# Simular que quiere correr hacia la derecha hacia el vacío
	brain._move_axis = 1.0
	brain._evitar_abismo(0.016)

	# El bot DEBE haber frenado o invertido su eje de movimiento ante el vacío
	assert(brain._move_axis <= 0.0, "El bot debe frenar o retroceder ante el abismo, actual: %f" % brain._move_axis)

	map.queue_free()
	print("✓ IA del Bot: frena inmediatamente ante el borde de un abismo y no salta al vacío")

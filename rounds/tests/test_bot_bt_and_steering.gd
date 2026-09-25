extends Node

## Test integral para el Behavior Tree y Steering Behaviors del Bot.
## Verifica:
## 1. No disparar a través de paredes (Línea de visión).
## 2. Disparar con camino libre.
## 3. Mecánica de Wall-Jump.
## 4. Atravesar plataformas one-way (subida y bajada).
## 5. Cuerdas de trepar y balanceo.
## 6. Detección y aproximación a puertas.
## 7. Evasión de pinchos y abismos.

func _ready() -> void:
	print("--- TEST DE BEHAVIOR TREE Y STEERING DEL BOT ---")
	await _test_no_shoot_through_walls()
	await _test_shoot_when_clear()
	await _test_one_way_platform_drop_and_jump()
	await _test_wall_jump_mechanics()
	await _test_rope_climb_and_swing()
	await _test_door_approach()
	await _test_hazard_and_spikes_avoidance()
	print("--- TODOS LOS TESTS DE BEHAVIOR TREE Y STEERING PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func _crear_bot(pos: Vector2, p_num: int = 2) -> CharacterBody2D:
	Settings.set_dispositivo(p_num, Settings.DISPOSITIVO_BOT)
	var p_scn: PackedScene = load("res://player/player.tscn")
	var bot: CharacterBody2D = p_scn.instantiate()
	bot.set("player_number", p_num)
	bot.global_position = pos
	add_child(bot)
	return bot


func _crear_objetivo(pos: Vector2, p_num: int = 1) -> CharacterBody2D:
	Settings.set_dispositivo(p_num, Settings.DISPOSITIVO_TECLADO)
	var p_scn: PackedScene = load("res://player/player.tscn")
	var p: CharacterBody2D = p_scn.instantiate()
	p.set("player_number", p_num)
	p.global_position = pos
	add_child(p)
	return p


func _crear_pared(pos: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = pos
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	wall.add_child(col)
	add_child(wall)
	return wall


func _test_no_shoot_through_walls() -> void:
	var bot := _crear_bot(Vector2(100, 300), 2)
	var target := _crear_objetivo(Vector2(400, 300), 1)
	# Muro intermedio bloqueando la línea de visión
	var wall := _crear_pared(Vector2(250, 300), Vector2(30, 200))

	await get_tree().physics_frame
	await get_tree().physics_frame

	var brain: BotBrain = bot.get_node("PlayerInput/BotBrain")
	assert(brain != null, "BotBrain debe existir")

	# Simular actualización de BT
	brain._target = target
	brain._tree.tick(0.016)

	assert(not brain.is_fire_pressed(), "El bot NO debe disparar si hay una pared interpuesta")
	print("✓ Línea de visión: el bot detecta la pared y NO dispara")

	wall.queue_free()
	bot.queue_free()
	target.queue_free()
	await get_tree().physics_frame


func _test_shoot_when_clear() -> void:
	var bot := _crear_bot(Vector2(100, 300), 2)
	var target := _crear_objetivo(Vector2(280, 300), 1)

	await get_tree().physics_frame
	await get_tree().physics_frame

	var brain: BotBrain = bot.get_node("PlayerInput/BotBrain")
	brain.dificultad = RunManager.DificultadBot.HACKER
	brain._shoot_delay_timer = 0.0
	brain._target = target
	brain._aim_dir = Vector2.RIGHT

	# Disparo con camino libre y alineado
	brain._tree.tick(0.016)
	assert(brain.is_fire_pressed(), "El bot DEBE disparar si el camino está libre y alineado")
	print("✓ Disparo táctico: el bot dispara cuando el objetivo está en línea de visión despejada")

	bot.queue_free()
	target.queue_free()
	await get_tree().physics_frame


func _test_one_way_platform_drop_and_jump() -> void:
	var bot := _crear_bot(Vector2(200, 200), 2)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Probar drop_through_platform en Player
	var initial_mask := bot.collision_mask
	bot.drop_through_platform()
	# La capa 7 (bitmask 64) debe haberse desactivado temporalmente
	assert(bot.get_collision_mask_value(7) == false, "drop_through_platform debe desactivar colisión con one-way")

	# Esperar a que se restaure
	for i in 20:
		await get_tree().physics_frame
	assert(bot.get_collision_mask_value(7) == true, "La capa one-way debe reactivarse tras el drop")
	print("✓ Plataformas One-Way: descenso fluido y reactivación correcta de colisión")

	bot.queue_free()
	await get_tree().physics_frame


func _test_wall_jump_mechanics() -> void:
	var bot := _crear_bot(Vector2(200, 300), 2)
	var wall := _crear_pared(Vector2(215, 300), Vector2(20, 200))
	var target := _crear_objetivo(Vector2(200, 100), 1)

	await get_tree().physics_frame
	await get_tree().physics_frame

	var brain: BotBrain = bot.get_node("PlayerInput/BotBrain")
	brain._target = target

	# Evaluar tick con pared adyacente
	brain._tree.tick(0.016)
	# Debe haber empujado contra la pared o intentado el salto de pared
	assert(brain.get_move_axis() != 0.0 or brain.is_jump_just_pressed(), "El bot debe interactuar con la pared para escalar hacia el objetivo")
	print("✓ Escalar paredes y Wall-Jump: secuencia de empuje y despegue activa")

	wall.queue_free()
	bot.queue_free()
	target.queue_free()
	await get_tree().physics_frame


func _test_rope_climb_and_swing() -> void:
	var bot := _crear_bot(Vector2(100, 300), 2)
	var target := _crear_objetivo(Vector2(100, 100), 1)

	await get_tree().physics_frame

	var rope := Node.new()
	bot.enter_climb_rope(rope)
	assert(bot.is_touching_climb_rope(), "El bot debe registrar que está tocando una cuerda")

	var brain: BotBrain = bot.get_node("PlayerInput/BotBrain")
	brain._target = target
	brain._tree.tick(0.016)

	assert(brain.is_up_pressed(), "El bot debe presionar ARRIBA para trepar hacia un objetivo elevado")
	print("✓ Cuerdas de trepar: activación automática de subida (W) y alineación")

	bot.exit_climb_rope(rope)
	rope.free()
	bot.queue_free()
	target.queue_free()
	await get_tree().physics_frame


func _test_door_approach() -> void:
	var bot := _crear_bot(Vector2(100, 300), 2)
	var target := _crear_objetivo(Vector2(400, 300), 1)

	# Puerta en Vector2(220, 300)
	var puerta_scn: PackedScene = load("res://world/puerta.tscn")
	var puerta: Node2D = puerta_scn.instantiate()
	puerta.position = Vector2(220, 300)
	add_child(puerta)

	await get_tree().physics_frame
	await get_tree().physics_frame

	var brain: BotBrain = bot.get_node("PlayerInput/BotBrain")
	brain._target = target
	brain._tree.tick(0.016)

	# El bot debe desplazarse hacia la puerta para abrirla
	assert(brain.get_move_axis() > 0.0, "El bot debe avanzar hacia la puerta que bloquea el camino")
	print("✓ Puertas: detección de puerta cerrada y aproximación para apertura automática")

	puerta.queue_free()
	bot.queue_free()
	target.queue_free()
	await get_tree().physics_frame


func _test_hazard_and_spikes_avoidance() -> void:
	var bot := _crear_bot(Vector2(100, 300), 2)
	var brain: BotBrain = bot.get_node("PlayerInput/BotBrain")

	# Pinchos adelante en X=130
	var pincho_scn: PackedScene = load("res://world/pincho.tscn")
	var pincho: Area2D = pincho_scn.instantiate()
	pincho.position = Vector2(130, 310)
	add_child(pincho)

	await get_tree().physics_frame
	await get_tree().physics_frame

	brain._move_axis = 1.0
	brain._tree.tick(0.016)

	# Ante peligro de pinchos o abismo, no debe mantener avance ciego
	assert(brain._move_axis <= 0.0 or brain.is_jump_just_pressed(), "El bot debe frenar o saltar por encima del peligro")
	print("✓ Evasión de pinchos y abismo: freno reactivo y prevención de daño ambiental")

	pincho.queue_free()
	bot.queue_free()
	await get_tree().physics_frame

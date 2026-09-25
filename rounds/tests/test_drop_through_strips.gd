extends Node

## Strips (plataformas de una sola cara): se baja manteniendo abajo.
## Sin apretar abajo el jugador se queda arriba; sobre suelo firme no cae.

const STRIP_LAYER := 7
const STRIP_Y := 400.0

var _player: Player = null
var _strip: StaticBody2D = null
var _ground: StaticBody2D = null


func _ready() -> void:
	print("--- TEST DE BAJAR POR LOS STRIPS (MANTENIENDO ABAJO) ---")
	await _levantar_jugador()
	await _test_mantener_abajo_atraviesa()
	await _test_sin_abajo_no_atraviesa()
	await _test_capa_se_restaura()
	await _test_suelo_firme_no_pierde_colision()
	print("--- TODOS LOS TESTS DE STRIPS PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func _levantar_jugador() -> void:
	var player_scn: PackedScene = load("res://player/player_1.tscn")
	_player = player_scn.instantiate() as Player
	add_child(_player)
	_strip = _crear_suelo(true, 64)
	_ground = _crear_suelo(false, 1)
	_ground.position = Vector2(0.0, 600.0)
	_player.global_position = Vector2(0.0, 300.0)
	for i in 30:
		await get_tree().physics_frame
	assert(_player.is_on_floor(), "El jugador debe quedar apoyado en el strip")
	assert(_player.get_collision_mask_value(STRIP_LAYER), "El jugador debe colisionar con la capa del strip")


func _crear_suelo(one_way: bool, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.one_way_collision = one_way
	var rect := RectangleShape2D.new()
	rect.size = Vector2(600.0, 16.0)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(0.0, STRIP_Y)
	add_child(body)
	return body


func _abajo(presionado: bool) -> void:
	if presionado:
		Input.action_press("p1_down")
	else:
		Input.action_release("p1_down")


func _frames(cantidad: int) -> void:
	for i in cantidad:
		await get_tree().physics_frame


func _test_mantener_abajo_atraviesa() -> void:
	_abajo(true)
	await _frames(25)
	_abajo(false)
	assert(_player.global_position.y > STRIP_Y + 8.0, "Mantener abajo debe atravesar el strip, y=%f" % _player.global_position.y)
	print("OK: mantener abajo atraviesa el strip")


func _test_sin_abajo_no_atraviesa() -> void:
	await _reposicionar()
	await _frames(25)
	assert(_player.global_position.y < STRIP_Y, "Sin apretar abajo el jugador no debe caer, y=%f" % _player.global_position.y)
	assert(_player.is_on_floor(), "El jugador debe seguir apoyado en el strip")
	print("OK: sin apretar abajo no se cae del strip")


func _test_capa_se_restaura() -> void:
	await _reposicionar()
	_abajo(true)
	await _frames(2)
	assert(not _player.get_collision_mask_value(STRIP_LAYER), "Durante el descenso la capa del strip debe estar apagada")
	# Se suelta abajo: manteniendo abajo sobre el suelo de abajo el combo se
	# re-dispara cada 0.22s (sin efecto, el suelo firme está en otra capa).
	_abajo(false)
	await _frames(30)
	assert(_player.get_collision_mask_value(STRIP_LAYER), "Terminado el descenso la capa del strip debe volver")
	print("OK: la capa de una sola cara se restaura al terminar de bajar")


func _test_suelo_firme_no_pierde_colision() -> void:
	_strip.queue_free()
	_player.global_position = Vector2(0.0, 520.0)
	await _frames(30)
	assert(_player.is_on_floor(), "El jugador debe caer al suelo firme")
	_abajo(true)
	await _frames(40)
	_abajo(false)
	assert(_player.get_collision_mask_value(1), "Bajar no debe apagar la capa World del suelo firme")
	assert(_player.is_on_floor(), "Sobre suelo firme no debe perder el suelo")
	print("OK: sobre suelo firme mantiene la colisión y no se cae")


func _reposicionar() -> void:
	_player.velocity = Vector2.ZERO
	_player.global_position = Vector2(0.0, 300.0)
	await _frames(30)
	assert(_player.is_on_floor(), "El jugador debe volver a apoyarse en el strip")
	_player.velocity = Vector2.ZERO

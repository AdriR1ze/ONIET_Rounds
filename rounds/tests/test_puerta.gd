extends Node

## Puerta: tiene que leerse como una puerta, no como una mini puerta. Una sola
## celda pintada ya da un vano de 1x4 tiles; el jugador (24x41) entra cómodo y
## al acercarse la puerta se abre y lo deja pasar.

const TILE := 32.0
## Medidas del jugador parado, para comparar contra la puerta.
const JUGADOR := Vector2(24.0, 41.0)
## Lo que tiene que medir el vano como mínimo para leerse como puerta.
const VANIO_MIN := Vector2(TILE, 128.0)
## Como hornea el TileSet una celda de escena: atlas (0,0) y el scene tile id
## en alternative_tile (asi esta en los mapas: source=7, atlas=(0,0), alt=1).
const SCENE_ID := 1
const ATLAS := Vector2i(0, 0)

var _tm: TileMapLayer
var _id_puerta := -1
var _escena: PackedScene
var _puestas: Array = []


func _ready() -> void:
	print("--- TEST DE PUERTA: PROPORCIONES Y APERTURA ---")
	var ts: TileSet = load("res://effects/neon_tileset.tres")
	_id_puerta = _buscar_puerta(ts)
	_escena = _cargar_puerta(ts)
	assert(_id_puerta > 0, "El TileSet tiene que exponer la puerta como escena")
	assert(_escena != null, "No se pudo cargar la escena de la puerta")

	_tm = TileMapLayer.new()
	_tm.tile_set = ts
	add_child(_tm)
	await get_tree().physics_frame

	await _test_una_celda_es_una_puerta()
	await _test_la_puerta_abre_al_acercarse()
	await _test_celdas_apiladas_la_hacen_mas_alta()
	await _test_puertas_de_distinto_alto_no_se_pisan()
	print("--- TODOS LOS TESTS DE PUERTA PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func _buscar_puerta(ts: TileSet) -> int:
	for i in range(1, ts.get_source_count() + 1):
		var s := ts.get_source(i)
		if s is TileSetScenesCollectionSource:
			for j in range(s.get_scene_tiles_count()):
				var esc: PackedScene = s.get_scene_tile_scene(s.get_scene_tile_id(j))
				if esc != null and esc.resource_path.ends_with("puerta.tscn"):
					return i
	return -1


func _cargar_puerta(ts: TileSet) -> PackedScene:
	return load("res://world/puerta.tscn") as PackedScene


## Registra las celdas y pone una instancia de puerta en cada una, que es lo que
## hace el TileSet sobre un mapa horneado. Primero todas las celdas y despues
## las instancias: la puerta cuenta celdas contiguas para saber su alto, asi que
## si nace antes que sus vecinas creeria estar sola.
func _pintar(celdas: Array) -> Array:
	for c in celdas:
		_tm.set_cell(c, _id_puerta, ATLAS, SCENE_ID)
	var creadas := []
	for c in celdas:
		var puerta: Node2D = _escena.instantiate()
		puerta.position = _tm.map_to_local(c)
		_tm.add_child(puerta)
		_puestas.append(puerta)
		creadas.append(puerta)
	await get_tree().physics_frame
	return creadas


## La puerta que manda es la de la celda de abajo: la unica visible.
func _ancla(celdas: Array) -> Node2D:
	var visibles := celdas.filter(func(p: Node2D) -> bool: return p.visible)
	assert(visibles.size() == 1, "Deberia haber una sola puerta ancla, hay %d" % visibles.size())
	return visibles[0]


func _caja_de(puerta: Node2D) -> RectangleShape2D:
	var forma: CollisionShape2D = puerta.get_node("Cuerpo/CollisionShape2D")
	return forma.shape as RectangleShape2D


func _forma_de(puerta: Node2D) -> CollisionShape2D:
	return puerta.get_node("Cuerpo/CollisionShape2D")


func _sprite_de(puerta: Node2D) -> Sprite2D:
	return puerta.get_node("Sprite")


func _test_una_celda_es_una_puerta() -> void:
	var celdas := await _pintar([Vector2i(0, 0)])
	var puerta: Node2D = celdas[0]
	assert(puerta.visible, "La celda de abajo es la ancla: la puerta tiene que verse")

	var caja := _caja_de(puerta).size
	assert(caja.x >= VANIO_MIN.x, "El vano debe medir al menos %f de ancho, mide %f" % [VANIO_MIN.x, caja.x])
	assert(caja.y >= VANIO_MIN.y, "El vano debe medir al menos %f de alto, mide %f" % [VANIO_MIN.y, caja.y])
	# Que no sea una mini puerta: holgura real alrededor del jugador.
	assert(caja.x > JUGADOR.x, "El vano (%f) tiene que ser mas ancho que el jugador (%f)" % [caja.x, JUGADOR.x])
	assert(caja.y > JUGADOR.y, "El vano (%f) tiene que ser mas alto que el jugador (%f)" % [caja.y, JUGADOR.y])
	# El sprite tiene que llenar la misma caja que la colision y apoyar su borde
	# de abajo en el piso. El arte trae relleno transparente abajo, asi que sin
	# recortarlo el dibujo flotaba un tile por encima de la celda pintada.
	var sprite := _sprite_de(puerta)
	var tam_sprite := sprite.get_rect().size * sprite.scale
	assert(is_equal_approx(tam_sprite.x, caja.x), "El sprite (%f) tiene que llenar el ancho de la colision (%f)" % [tam_sprite.x, caja.x])
	assert(is_equal_approx(tam_sprite.y, caja.y), "El sprite (%f) tiene que llenar el alto de la colision (%f)" % [tam_sprite.y, caja.y])
	var fondo_sprite := sprite.position.y + tam_sprite.y * 0.5
	var fondo_caja := _forma_de(puerta).position.y + caja.y * 0.5
	assert(is_equal_approx(fondo_sprite, fondo_caja), "El dibujo (fondo %f) tiene que apoyar en el fondo de la caja (%f), no flotar" % [fondo_sprite, fondo_caja])
	assert(is_equal_approx(fondo_caja, TILE * 0.5), "La base de la puerta debe apoyar en el piso de la celda, quedo en %f" % fondo_caja)

	# Las celdas de arriba no se muestran: solo manda la ancla.
	var arriba: Array = await _pintar([Vector2i(0, -1)])
	assert(not (arriba[0] as Node2D).visible, "La celda de arriba no es ancla: no debe verse")
	print("OK: una celda sola ya es un vano de %f x %f" % [caja.x, caja.y])


func _test_la_puerta_abre_al_acercarse() -> void:
	var puerta: Node2D = _puestas[0]
	var forma := _forma_de(puerta)
	var detector: Area2D = puerta.get_node("Detector")
	var sprite := _sprite_de(puerta)

	var jugador := CharacterBody2D.new()
	jugador.collision_layer = 2
	jugador.collision_mask = 0
	var jforma := CollisionShape2D.new()
	var jrect := RectangleShape2D.new()
	jrect.size = JUGADOR
	jforma.shape = jrect
	jugador.add_child(jforma)
	jugador.add_to_group("player")
	add_child(jugador)

	# Lejos de la puerta: cerrada.
	jugador.global_position = Vector2(900.0, 900.0)
	await _frames(4)
	assert(not forma.disabled, "Lejos de la puerta la colision tiene que estar activa")
	assert(sprite.frame == 0, "Lejos de la puerta el sprite tiene que estar cerrado (frame 0), va en %d" % sprite.frame)

	# Al lado del vano: abierta y sin colision.
	jugador.global_position = Vector2(0.0, -40.0)
	await _frames(6)
	assert(detector.get_overlapping_bodies().size() > 0, "El detector tiene que ver al jugador al lado del vano")
	assert(forma.disabled, "Con el jugador al lado la colision tiene que estar apagada")
	assert(sprite.frame == 3, "Con el jugador al lado el sprite tiene que estar abierto (frame 3), va en %d" % sprite.frame)

	# Se aleja: vuelve a cerrar.
	jugador.global_position = Vector2(900.0, 900.0)
	await _frames(6)
	assert(not forma.disabled, "Al alejarse la colision tiene que volver")
	assert(sprite.frame == 0, "Al alejarse el sprite tiene que volver a cerrado (frame 0), va en %d" % sprite.frame)
	print("OK: la puerta abre al acercarse, deja pasar y vuelve a cerrar")


func _test_celdas_apiladas_la_hacen_mas_alta() -> void:
	# Columna nueva de 6 celdas: 6 tiles de alto.
	var celdas := []
	for i in range(6):
		celdas.append(Vector2i(6, -5 + i))
	var puestas: Array = await _pintar(celdas)
	var alta := _ancla(puestas)
	var caja := _caja_de(alta).size
	assert(is_equal_approx(caja.y, 6.0 * TILE), "6 celdas apiladas deben dar un vano de %f de alto, dio %f" % [6.0 * TILE, caja.y])
	var piso := _forma_de(alta).position.y + caja.y * 0.5
	assert(is_equal_approx(piso, TILE * 0.5), "La puerta alta tambien tiene que apoyar en el piso, quedo en %f" % piso)
	print("OK: apilar celdas crece la puerta a %f de alto" % caja.y)


func _test_puertas_de_distinto_alto_no_se_pisan() -> void:
	# Las formas del .tscn las comparten todas las instancias: si el codigo no
	# crea una propia, la ultima puerta que se calcula pisa a las otras.
	var hay_baja := false
	var hay_alta := false
	for p in _puestas:
		var h := _caja_de(p).size.y
		if is_equal_approx(h, 4.0 * TILE):
			hay_baja = true
		elif is_equal_approx(h, 6.0 * TILE):
			hay_alta = true
	assert(hay_baja, "La puerta de una celda debe seguir midiendo %f" % (4.0 * TILE))
	assert(hay_alta, "La puerta de 6 celdas debe seguir midiendo %f" % (6.0 * TILE))
	print("OK: dos puertas de alto distinto no comparten la misma forma")


func _frames(cantidad: int) -> void:
	for i in cantidad:
		await get_tree().physics_frame

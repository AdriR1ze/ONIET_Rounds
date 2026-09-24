extends Node2D

## Colapso de El Péndulo: cada vez que vence el ColapsoTimer se derrumba una
## capa de bloques del borde, avanzando hacia el centro hasta que solo queda
## el núcleo (el "corazón" del mapa).

@export var radio_nucleo := 10.0   # radio (en celdas) que se conserva en el centro
@export var ancho_capa := 6.0      # grosor de cada capa que cae

@onready var _layer: TileMapLayer = $NeonTileMap
@onready var _timer: Timer = $ColapsoTimer

var _celdas: Array[Vector2i] = []
var _datos: Dictionary = {}
var _centro := Vector2.ZERO
var _radio_max := 0.0
var _radio := 0.0
var _tweens: Array[Tween] = []
var _caidas: Array[Sprite2D] = []


func _ready() -> void:
	_capturar()
	_timer.timeout.connect(_on_timer_timeout)
	RunManager.ronda_iniciada.connect(_on_ronda_iniciada)
	_on_ronda_iniciada(RunManager.ronda)


func _capturar() -> void:
	_celdas = _layer.get_used_cells()
	var suma := Vector2.ZERO
	for c in _celdas:
		_datos[c] = {
			"source": _layer.get_cell_source_id(c),
			"atlas": _layer.get_cell_atlas_coords(c),
			"alt": _layer.get_cell_alternative_tile(c),
		}
		suma += Vector2(c)
	_centro = suma / float(maxi(1, _celdas.size()))
	_radio_max = 0.0
	for c in _celdas:
		_radio_max = maxf(_radio_max, Vector2(c).distance_to(_centro))


func _on_ronda_iniciada(_numero: int) -> void:
	_limpiar_caidas()
	if not _datos.is_empty():
		_layer.clear()
		for c in _datos:
			var d: Dictionary = _datos[c]
			_layer.set_cell(c, d["source"], d["atlas"], d["alt"])
	_radio = _radio_max
	_timer.start()


func _on_timer_timeout() -> void:
	if _radio <= radio_nucleo:
		_timer.stop()
		return

	_radio = maxf(radio_nucleo, _radio - ancho_capa)
	for c in _celdas:
		if _layer.get_cell_source_id(c) == -1:
			continue
		if Vector2(c).distance_to(_centro) > _radio:
			_derribar(c)

	if _radio <= radio_nucleo:
		_timer.stop()


func _derribar(c: Vector2i) -> void:
	var d: Dictionary = _datos[c]
	var pos := _layer.to_global(_layer.map_to_local(c))
	_layer.erase_cell(c)
	# Nodos creados en runtime a propósito: son cientos de bloques cayendo, no
	# algo fijo de escena (ver skill de nodos-primero).
	_soltar(d["source"], d["atlas"], d["alt"], pos)


func _soltar(source: int, atlas: Vector2i, alt: int, pos: Vector2) -> void:
	var src := _layer.tile_set.get_source(source)
	if not (src is TileSetAtlasSource):
		return
	var atlas_src := src as TileSetAtlasSource
	var spr := Sprite2D.new()
	spr.texture = atlas_src.texture
	spr.region_enabled = true
	spr.region_rect = Rect2(Vector2(atlas) * Vector2(atlas_src.texture_region_size), Vector2(atlas_src.texture_region_size))
	spr.global_position = pos
	var td := atlas_src.get_tile_data(atlas, alt)
	if td != null and td.material != null:
		spr.material = td.material
	add_child(spr)
	_caidas.append(spr)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "global_position:y", pos.y + 520.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(spr, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(spr):
			_caidas.erase(spr)
			spr.queue_free()
	)
	_tweens.append(tw)


func _limpiar_caidas() -> void:
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	for spr in _caidas:
		if is_instance_valid(spr):
			spr.queue_free()
	_caidas.clear()

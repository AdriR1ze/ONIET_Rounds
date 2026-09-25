extends Node2D

## Colapso de El Péndulo / La Pirámide:
## Tras 20 segundos de gracia, se derrumban gradualmente las columnas de los bordes
## exteriores (de izquierda y derecha, de arriba a abajo) avanzando hacia el centro
## hasta que solo queda el núcleo / pirámide central.

const RETRASO_INICIAL := 20.0
const INTERVALO_COLAPSO := 2.5

@export var radio_nucleo: float = 12.0   # radio horizontal (en celdas) que se conserva en el centro
@export var ancho_capa: int = 1          # cantidad de columnas que caen por paso en cada lado

@onready var _layer: TileMapLayer = $NeonTileMap
@onready var _timer: Timer = $ColapsoTimer

var _celdas: Array[Vector2i] = []
var _datos: Dictionary = {}
var _min_x: int = 0
var _max_x: int = 0
var _centro_x: int = 0
var _colapso_izq: int = 0
var _colapso_der: int = 0
var _radio: float = 999.0
var _en_intervalo: bool = false
var _tweens: Array[Tween] = []
var _caidas: Array[Sprite2D] = []


func _ready() -> void:
	_capturar()
	_timer.timeout.connect(_on_timer_timeout)
	RunManager.ronda_iniciada.connect(_on_ronda_iniciada)
	_on_ronda_iniciada(RunManager.ronda)


func _capturar() -> void:
	_celdas = _layer.get_used_cells()
	if _celdas.is_empty():
		return
	_min_x = _celdas[0].x
	_max_x = _celdas[0].x
	for c in _celdas:
		_datos[c] = {
			"source": _layer.get_cell_source_id(c),
			"atlas": _layer.get_cell_atlas_coords(c),
			"alt": _layer.get_cell_alternative_tile(c),
		}
		_min_x = mini(_min_x, c.x)
		_max_x = maxi(_max_x, c.x)
	_centro_x = int(round(float(_min_x + _max_x) / 2.0))


func _on_ronda_iniciada(_numero: int) -> void:
	_limpiar_caidas()
	if not _datos.is_empty():
		_layer.clear()
		for c in _datos:
			var d: Dictionary = _datos[c]
			_layer.set_cell(c, d["source"], d["atlas"], d["alt"])
	_colapso_izq = _min_x - 1
	_colapso_der = _max_x + 1
	_radio = float(_max_x - _min_x) / 2.0
	_en_intervalo = false
	if is_inside_tree() and _timer != null:
		_timer.stop()
		_timer.wait_time = RETRASO_INICIAL
		_timer.start()


func _on_timer_timeout() -> void:
	# Si estábamos en el retraso inicial de 20s, cambiar al intervalo regular
	if not _en_intervalo:
		_en_intervalo = true
		_timer.stop()
		_timer.wait_time = INTERVALO_COLAPSO
		_timer.start()

	var limite_izq := _centro_x - int(radio_nucleo)
	var limite_der := _centro_x + int(radio_nucleo)

	if _colapso_izq >= limite_izq and _colapso_der <= limite_der:
		_radio = radio_nucleo
		_timer.stop()
		return

	if _colapso_izq < limite_izq:
		_colapso_izq = mini(_colapso_izq + ancho_capa, limite_izq)
	if _colapso_der > limite_der:
		_colapso_der = maxi(_colapso_der - ancho_capa, limite_der)

	_radio = maxf(radio_nucleo, float(_colapso_der - _colapso_izq) / 2.0)

	# Derribar todas las celdas en las columnas colapsadas de arriba a abajo
	for c in _celdas:
		if _layer.get_cell_source_id(c) == -1:
			continue
		if c.x <= _colapso_izq or c.x >= _colapso_der:
			_derribar(c)

	if _colapso_izq >= limite_izq and _colapso_der <= limite_der:
		_radio = radio_nucleo
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

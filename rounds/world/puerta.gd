extends Node2D

## Puerta: se pinta con celdas del TileSet en un TileMapLayer. UNA celda ya
## ocupa 2 tiles de alto (la celda de abajo ancla y crece hacia arriba); si
## apilás más celdas contiguas, la puerta crece a ese alto. Es sólida cerrada
## y se abre cuando un jugador se acerca.

const FRAME_CERRADA := 0
const FRAME_ABIERTA := 3
const TILE := 32.0
const MARGEN_DETECTOR := 18.0
const ALTO_MINIMO := 2

var _es_ancla := false
var _alto := 2.0
var _abierta := false

@onready var _cuerpo: StaticBody2D = $Cuerpo
@onready var _detector: Area2D = $Detector
@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("puerta")
	var tm := get_parent() as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	var sid := tm.get_cell_source_id(cell)
	# La celda de ABAJO ancla: la puerta crece hacia arriba.
	_es_ancla = tm.get_cell_source_id(cell + Vector2i(0, 1)) != sid
	if not _es_ancla:
		visible = false
		_cuerpo.set_deferred("collision_layer", 0)
		_detector.monitoring = false
		set_physics_process(false)
		return
	var n := 1
	while tm.get_cell_source_id(cell + Vector2i(0, -n)) == sid:
		n += 1
	_alto = float(maxi(n, ALTO_MINIMO))
	add_to_group("puerta")
	var desplazamiento := 16.0 * (1.0 - _alto)
	_sprite.position.y = desplazamiento
	_sprite.scale.y = _alto
	var cuerpo_shape := ($Cuerpo/CollisionShape2D.shape as RectangleShape2D)
	cuerpo_shape.size = Vector2(28.0, _alto * TILE)
	$Cuerpo/CollisionShape2D.position.y = desplazamiento
	var detector_shape := ($Detector/CollisionShape2D.shape as RectangleShape2D)
	detector_shape.size = Vector2(72.0, _alto * TILE + MARGEN_DETECTOR * 2.0)
	$Detector/CollisionShape2D.position.y = desplazamiento


func _physics_process(_delta: float) -> void:
	var hay_jugador := false
	for b in _detector.get_overlapping_bodies():
		if b.is_in_group("player"):
			hay_jugador = true
			break
	if hay_jugador == _abierta:
		return
	_abierta = hay_jugador
	_sprite.frame = FRAME_ABIERTA if _abierta else FRAME_CERRADA
	for c in _cuerpo.get_children():
		if c is CollisionShape2D:
			c.disabled = _abierta


func is_open() -> bool:
	return _abierta

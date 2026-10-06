extends Node2D

## Puerta: se pinta con celdas del TileSet en un TileMapLayer. UNA celda ya
## ocupa ANCHO de ancho y ALTO_MINIMO tiles de alto (la celda de abajo ancla y
## crece hacia arriba); si apilás más celdas contiguas, la puerta crece a ese
## alto. Es sólida cerrada y se abre cuando un jugador se acerca.
##
## El alto mínimo y el ancho salen del jugador: mide 24x41 parado, así que 4
## tiles (128) es el mínimo para que el vano se lea como vano y le pase por
## arriba con aire. Con 2 tiles de alto quedaba como una mini puerta. De ancho
## ocupa un tile, así que la puerta queda centrada en su celda.

const FRAME_CERRADA := 0
const FRAME_ABIERTA := 3
const TILE := 32.0
const MARGEN_DETECTOR := 18.0
const ALTO_MINIMO := 4
const ANCHO := TILE

var _es_ancla := false
var _alto := float(ALTO_MINIMO)
var _abierta := false

@onready var _cuerpo: StaticBody2D = $Cuerpo
@onready var _detector: Area2D = $Detector
@onready var _sprite: Sprite2D = $Sprite
@onready var _cuerpo_forma: CollisionShape2D = $Cuerpo/CollisionShape2D
@onready var _detector_forma: CollisionShape2D = $Detector/CollisionShape2D

## Recuadro del dibujo dentro de cada frame, por textura. Se calcula una vez.
static var _dibujos: Dictionary = {}


func _ready() -> void:
	add_to_group("puerta")
	var tm := get_parent() as TileMapLayer
	if tm != null:
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
	else:
		_alto = float(ALTO_MINIMO)


func _physics_process(_delta: float) -> void:
	var jugador: Node2D = null
	for b in _detector.get_overlapping_bodies():
		if b.is_in_group("player"):
			jugador = b
			break
	var hay_jugador := jugador != null
	if hay_jugador == _abierta:
		return
	_abierta = hay_jugador
	if _abierta:
		_sprite.flip_h = jugador.global_position.x > global_position.x
	_sprite.frame = FRAME_ABIERTA if _abierta else FRAME_CERRADA
	for c in _cuerpo.get_children():
		if c is CollisionShape2D:
			c.disabled = _abierta


func is_open() -> bool:
	return _abierta

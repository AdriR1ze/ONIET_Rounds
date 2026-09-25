extends Node2D

## Cuerda de balanceo: apilá varias celdas y forman UN solo péndulo (la celda de
## arriba ancla, el largo sale de cuántas pongas). Es un péndulo físico con
## amortiguación: si nadie la usa, se va quedando sin fuerza. El jugador la
## agarra al tocar la pesa y se columpia; salta para soltarse con la inercia.

const LARGO_TILE := 32.0
const GRAVEDAD := 1400.0        # px/s^2 para el péndulo
const AMORTIGUACION := 0.7      # 1/s; sólo cuando no hay jugador colgado
const ANGULO_INICIAL := deg_to_rad(70.0)
const MAX_ANGULO := deg_to_rad(90.0)   # límite de altura (no pasa de este ángulo)
const VELOCIDAD_MAX := 780.0           # límite de velocidad de la pesa (px/s)
const IMPULSO := 2.0                   # rad/s^2; mover izq/der empuja el columpio
const REAGARRE_ESPERA := 0.45          # s; no re-engancha al instante tras soltarse

var _es_ancla := false
var _largo := 120.0
var _theta := ANGULO_INICIAL
var _omega := 0.0
var _cooldown := 0.0
var _jugador: Node = null

@onready var _arm: Node2D = $Arm
@onready var _linea: Line2D = $Arm/Linea
@onready var _bob: Node2D = $Arm/Bob
@onready var _agarre: Area2D = $Arm/Agarre


func _ready() -> void:
	var tm := get_parent() as TileMapLayer
	if tm != null:
		var cell := tm.local_to_map(tm.to_local(global_position))
		var sid := tm.get_cell_source_id(cell)
		_es_ancla = tm.get_cell_source_id(cell + Vector2i(0, -1)) != sid
		if not _es_ancla:
			if _arm != null:
				_arm.visible = false
			if _agarre != null:
				_agarre.monitoring = false
			set_physics_process(false)
			return
		var n := 1
		while tm.get_cell_source_id(cell + Vector2i(0, n)) == sid:
			n += 1
		_largo = n * LARGO_TILE
	_setup_arm()


func _setup_arm() -> void:
	add_to_group("cuerda_balanceo")
	if _arm != null:
		_arm.visible = true
	if _linea != null:
		_linea.points = PackedVector2Array([Vector2.ZERO, Vector2(0.0, _largo)])
	if _bob != null:
		_bob.position = Vector2(0.0, _largo)
	if _agarre != null:
		_agarre.position = Vector2(0.0, _largo)


func _intentar_agarrar(body: Node) -> bool:
	if _jugador != null or _cooldown > 0.0 or not is_instance_valid(body):
		return false
	if not body.is_in_group("player") or not body.has_method("attach_swing"):
		return false
	# Sólo se agarra si el jugador aprieta arriba (W).
	if body.has_method("wants_grab_rope") and not body.wants_grab_rope():
		return false
	# Transferir el impulso del jugador al péndulo (si llega con velocidad).
	var tangente := Vector2(-cos(_theta), -sin(_theta))
	_omega += body.velocity.dot(tangente) / maxf(_largo, 1.0)
	_jugador = body
	body.attach_swing(self)
	return true


func release_player() -> void:
	if _jugador != null and is_instance_valid(_jugador) and _jugador.has_method("detach_swing"):
		_jugador.detach_swing()
	_jugador = null
	_cooldown = REAGARRE_ESPERA


func get_end_position() -> Vector2:
	if _arm != null:
		return _arm.to_global(Vector2(0.0, _largo))
	return global_position + Vector2(0.0, _largo)


func get_end_velocity() -> Vector2:
	return _omega * Vector2(-cos(_theta), -sin(_theta)) * _largo


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_omega += -(GRAVEDAD / _largo) * sin(_theta) * delta
	if _jugador == null:
		_omega *= exp(-AMORTIGUACION * delta)
	elif is_instance_valid(_jugador) and _jugador.has_method("swing_input"):
		# Moverte para un lado acelera el columpio hacia ese lado.
		_omega -= _jugador.swing_input() * IMPULSO * delta
	# Límite de velocidad y de altura.
	var max_omega := VELOCIDAD_MAX / maxf(_largo, 1.0)
	_omega = clampf(_omega, -max_omega, max_omega)
	_theta = clampf(_theta, -MAX_ANGULO, MAX_ANGULO)
	_theta += _omega * delta
	_theta = clampf(_theta, -MAX_ANGULO, MAX_ANGULO)
	if _arm != null:
		_arm.rotation = _theta
	if _jugador == null:
		# Agarra sólo si el jugador está encima y aprieta arriba.
		if _agarre != null:
			for body in _agarre.get_overlapping_bodies():
				if _intentar_agarrar(body):
					break
	if _jugador == null:
		return
	if not is_instance_valid(_jugador):
		_jugador = null
		return
	_jugador.global_position = get_end_position()
	_jugador.velocity = get_end_velocity()

class_name CombatCamera
extends Camera2D

## Cámara dinámica para party game: encuadra a todos los jugadores vivos,
## hace zoom out cuando se dispersan y zoom in cuando se acercan, con un
## look-ahead suave hacia el centro de acción. Conserva el screenshake como
## offset aditivo.

@export_group("Framing")
## Zoom mínimo (más alejado). Menor = ver todo lo disperso.
@export var min_zoom: float = 0.35
## Zoom máximo (más cerca). 1.0 = escala 1:1 del viewport base.
@export var max_zoom: float = 1.0
## Margen en píxeles alrededor de los jugadores al encuadrar.
@export var padding: float = 140.0
## Cuánto se adelanta el enfoque hacia el centro de acción (0..1).
@export var lookahead_factor: float = 0.25

@export_group("Suavizado")
## Velocidad de interpolación de la posición (más alto = más ágil).
@export var position_speed: float = 6.0
## Velocidad de interpolación del zoom (más alto = más ágil).
@export var zoom_speed: float = 4.0

@export_group("Viewport base")
## Si > 0, fuerza el tamaño base del world para el cálculo de zoom.
## Si 0, se usa el viewport real (recomendado con stretch=canvas_items).
@export var base_viewport: Vector2 = Vector2.ZERO

var _rng := RandomNumberGenerator.new()
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0

# Estado actual suavizado.
var _current_center: Vector2 = Vector2.ZERO
var _current_zoom: float = 1.0
var _initialized: bool = false


func _ready() -> void:
	_rng.randomize()
	_current_center = global_position
	_current_zoom = zoom.x
	_initialized = true


func _process(delta: float) -> void:
	_update_framing(delta)
	_update_shake(delta)


## Calcula el encuadre deseado y lo interpola suavemente.
func _update_framing(delta: float) -> void:
	var target_center: Vector2
	var target_zoom: float

	var players := _alive_players()
	if players.is_empty():
		# Sin jugadores vivos: mantener posición y zoom actuales.
		return

	var bounds := _players_bounds(players)
	target_center = bounds.get_center() + _lookahead(players, bounds)

	# Tamaño del mundo visible a zoom 1.0 (en píxeles de mundo).
	var world_view_size := get_viewport_rect().size
	if base_viewport.x > 0.0 and base_viewport.y > 0.0:
		world_view_size = base_viewport

	var needed_zoom := minf(
		world_view_size.x / maxf(bounds.size.x + padding * 2.0, 1.0),
		world_view_size.y / maxf(bounds.size.y + padding * 2.0, 1.0)
	)
	target_zoom = clampf(needed_zoom, min_zoom, max_zoom)

	# Suavizado.
	var k_pos := 1.0 - exp(-position_speed * delta)
	_current_center = _current_center.lerp(target_center, k_pos)

	var k_zoom := 1.0 - exp(-zoom_speed * delta)
	_current_zoom = lerpf(_current_zoom, target_zoom, k_zoom)

	global_position = _current_center
	zoom = Vector2(_current_zoom, _current_zoom)


## Devuelve los jugadores vivos del grupo "player".
func _alive_players() -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(node) and node.has_method("is_alive") and node.is_alive():
			result.append(node)
	return result


## Bounding box (Rect2) que contiene a todos los jugadores.
func _players_bounds(players: Array) -> Rect2:
	if players.is_empty():
		return Rect2(_current_center, Vector2.ZERO)
	var min_pos: Vector2 = players[0].global_position
	var max_pos: Vector2 = players[0].global_position
	for p in players:
		min_pos.x = minf(min_pos.x, p.global_position.x)
		min_pos.y = minf(min_pos.y, p.global_position.y)
		max_pos.x = maxf(max_pos.x, p.global_position.x)
		max_pos.y = maxf(max_pos.y, p.global_position.y)
	return Rect2(min_pos, max_pos - min_pos)


## Look-ahead: desplaza el enfoque un poco hacia la dirección de movimiento
## promedio de los jugadores, para anticipar la acción en vez de ir a remolque.
func _lookahead(players: Array, _bounds: Rect2) -> Vector2:
	if players.size() < 2:
		return Vector2.ZERO
	var velocities := Vector2.ZERO
	var count := 0
	for p in players:
		if p is CharacterBody2D:
			velocities += (p as CharacterBody2D).velocity
			count += 1
	if count == 0:
		return Vector2.ZERO
	velocities /= float(count)
	# Peso el look-ahead por la magnitud de la velocidad, con tope.
	var mag := velocities.length()
	if mag < 1.0:
		return Vector2.ZERO
	var max_look := 120.0
	var weighted := velocities.limit_length(max_look) * (mag / (mag + 400.0))
	return weighted * lookahead_factor


## Screenshake aditivo (offset temporal sobre la posición de encuadre).
func _update_shake(delta: float) -> void:
	if _shake_duration <= 0.0:
		return
	_shake_time += delta
	if _shake_time >= _shake_duration:
		_reset_shake()
		return
	var falloff := 1.0 - (_shake_time / _shake_duration)
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf() * _shake_intensity * falloff
	offset = Vector2.RIGHT.rotated(angle) * radius


func shake(intensidad: float, duracion: float = 0.25) -> void:
	# Solo se actualiza si la nueva sacudida es más fuerte que la actual.
	if intensidad < _shake_intensity and _shake_duration > 0.0:
		return
	_shake_intensity = intensidad
	_shake_duration = maxf(duracion, 0.0)
	_shake_time = 0.0


func _reset_shake() -> void:
	_shake_time = 0.0
	_shake_duration = 0.0
	_shake_intensity = 0.0
	offset = Vector2.ZERO


static func shake_viewport(from: Node, intensidad: float, duracion: float = 0.25) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	var camera := from.get_viewport().get_camera_2d()
	if camera is CombatCamera:
		camera.shake(intensidad, duracion)

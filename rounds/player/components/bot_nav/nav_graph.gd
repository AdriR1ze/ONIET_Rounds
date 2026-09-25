class_name NavGraph
extends RefCounted

## Grafo AStar2D de celdas transitables extraídas del TileMapLayer y cuerdas/puertas.
## Considera el tamaño físico real del jugador (22x38 px) para garantizar que los
## caminos generados tengan espacio suficiente y el bot nunca quede atascado en
## huecos estrechos o techos bajos.

const JUMP_UP_CELLS: int = 5
const JUMP_DOWN_CELLS: int = 8      # Salto/descenso a plataformas inferiores cruzando vacíos
const JUMP_REACH_CELLS: int = 10     # Hasta 320 px de alcance horizontal
const MAX_FALL_CELLS: int = 16        # Caída por pozos / huecos verticales
const CLEARANCE_SAMPLES: int = 6
const WORLD_MASK: int = 1 | 64        # Sólidos (1) + Plataformas One-Way (64)

# Dimensiones reales del cuerpo del jugador (StandShape es 24x41, usamos 20x36 con tolerancia)
const PLAYER_WIDTH: float = 20.0
const PLAYER_HEIGHT: float = 36.0

var tile_size: int = 32
var _astar: AStar2D
var _ids: Dictionary = {}             # Vector2i cell -> int id
var _is_rope_cell: Dictionary = {}    # Vector2i cell -> bool
var _probe_shape: RectangleShape2D

static var _cache: Dictionary = {}


static func get_or_build(tilemap: TileMapLayer, key: String) -> NavGraph:
	if _cache.has(key):
		return _cache[key]
	var graph := NavGraph.new()
	graph.build(tilemap)
	_cache[key] = graph
	return graph


func build(tilemap: TileMapLayer) -> void:
	tile_size = tilemap.tile_set.tile_size.x
	_astar = AStar2D.new()
	_ids.clear()
	_is_rope_cell.clear()
	_probe_shape = RectangleShape2D.new()
	_probe_shape.size = Vector2(PLAYER_WIDTH, PLAYER_HEIGHT)

	var space := tilemap.get_world_2d().direct_space_state
	var rect := tilemap.get_used_rect()

	# 1. Registrar celdas transitables (piso y cuerdas)
	for y in range(rect.position.y - 1, rect.end.y + 2):
		for x in range(rect.position.x - 1, rect.end.x + 2):
			var cell := Vector2i(x, y)
			var center := tilemap.to_global(tilemap.map_to_local(cell))

			# Comprobar si la celda es una cuerda de trepar (source_id 8)
			var sid := tilemap.get_cell_source_id(cell)
			if sid == 8:
				if _is_free(space, center):
					var id := _astar.get_point_count()
					_astar.add_point(id, center)
					_ids[cell] = id
					_is_rope_cell[cell] = true
				continue

			# Celda normal de suelo: debe tener espacio para el cuerpo y soporte debajo
			if _is_standable(space, center):
				var id := _astar.get_point_count()
				_astar.add_point(id, center)
				_ids[cell] = id
				_is_rope_cell[cell] = false

	# 2. Conectar aristas entre celdas
	_connect_edges(space, tilemap)


func _connect_edges(space: PhysicsDirectSpaceState2D, _tilemap: TileMapLayer) -> void:
	for key in _ids.keys():
		var cell: Vector2i = key
		var id: int = _ids[cell]
		var center: Vector2 = _astar.get_point_position(id)
		var is_rope: bool = _is_rope_cell.get(cell, false)

		if is_rope:
			# Conexión vertical de cuerda (subir y bajar)
			for dy in [-1, 1]:
				var rope_neighbor := cell + Vector2i(0, dy)
				if _ids.has(rope_neighbor):
					_astar.connect_points(id, _ids[rope_neighbor], true)

			# Conexión horizontal a plataformas adyacentes para desembarcar
			for dx in [-2, -1, 1, 2]:
				var plat_neighbor := cell + Vector2i(dx, 0)
				if _ids.has(plat_neighbor) and _clearance_ok(space, center, _astar.get_point_position(_ids[plat_neighbor])):
					_astar.connect_points(id, _ids[plat_neighbor], true)
			continue

		# Caminar horizontalmente: vecinos inmediatos
		for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
			var neighbor: Vector2i = cell + offset
			if _ids.has(neighbor):
				if _clearance_ok(space, center, _astar.get_point_position(_ids[neighbor])):
					_astar.connect_points(id, _ids[neighbor], true)

		# Caída: bajar a una celda inferior transitable (unidireccional)
		for dy in range(1, MAX_FALL_CELLS + 1):
			for dx in [-2, -1, 0, 1, 2]:
				var fall_target: Vector2i = cell + Vector2i(dx, dy)
				if _ids.has(fall_target):
					var target_pos := _astar.get_point_position(_ids[fall_target])
					if _clearance_ok(space, center, target_pos):
						_astar.connect_points(id, _ids[fall_target], false)

		# Salto: alcanzar repisas o plataformas a diferente altura y distancia (tanto arriba como abajo)
		for dy in range(-JUMP_UP_CELLS, JUMP_DOWN_CELLS + 1):
			for dx in range(-JUMP_REACH_CELLS, JUMP_REACH_CELLS + 1):
				if dx == 0 and dy == 0:
					continue
				var jump_target: Vector2i = cell + Vector2i(dx, dy)
				if _ids.has(jump_target):
					var target_pos := _astar.get_point_position(_ids[jump_target])
					if _clearance_ok(space, center, target_pos):
						var bidirectional := (dy <= 0) # Si sube saltando, también puede bajar
						_astar.connect_points(id, _ids[jump_target], bidirectional)


## Verifica si el espacio contiene altura y ancho libre para el cuerpo del jugador.
func _is_free(space: PhysicsDirectSpaceState2D, center: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _probe_shape
	query.transform = Transform2D(0.0, center - Vector2(0.0, 3.0))
	query.collision_mask = 1 # Solo paredes sólidas bloquean el cuerpo
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space.intersect_shape(query, 1).is_empty()


func _is_standable(space: PhysicsDirectSpaceState2D, center: Vector2) -> bool:
	return _is_free(space, center) and _has_ground_below(space, center)


func _has_ground_below(space: PhysicsDirectSpaceState2D, center: Vector2) -> bool:
	var from := center + Vector2(0.0, tile_size * 0.2)
	var to := center + Vector2(0.0, tile_size * 1.3)
	var query := PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not space.intersect_ray(query).is_empty()


## Verifica que el camino entre a y b tenga espacio físico para el cuerpo del jugador.
## Simula una parábola de salto para no chocar con las esquinas de los bordes.
func _clearance_ok(space: PhysicsDirectSpaceState2D, a: Vector2, b: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _probe_shape
	query.collision_mask = 1 # Las plataformas one-way se pueden atravesar
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var is_jumping := absf(a.x - b.x) > tile_size * 1.2 or b.y < a.y
	for i in range(1, CLEARANCE_SAMPLES + 1):
		var t := float(i) / float(CLEARANCE_SAMPLES + 1)
		var p := a.lerp(b, t)
		if is_jumping:
			var arc_height := sin(t * PI) * maxf(28.0, (a.y - b.y) + 20.0)
			p.y -= arc_height
		query.transform = Transform2D(0.0, p - Vector2(0.0, 3.0))
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true


func nearest_cell(world: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := INF
	for key in _ids.keys():
		var cell: Vector2i = key
		var center: Vector2 = _astar.get_point_position(_ids[cell])
		var dist := center.distance_squared_to(world)
		if dist < best_dist:
			best_dist = dist
			best = cell
	return best


func has_cell(cell: Vector2i) -> bool:
	return _ids.has(cell)


func point_count() -> int:
	return _astar.get_point_count() if _astar != null else 0


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _nearest_id(from)
	var b := _nearest_id(to)
	if a == -1 or b == -1:
		return PackedVector2Array()
	if a == b:
		return PackedVector2Array([_astar.get_point_position(a)])
	return _astar.get_point_path(a, b)


func _nearest_id(world: Vector2) -> int:
	var cell := nearest_cell(world)
	return _ids[cell] if _ids.has(cell) else -1

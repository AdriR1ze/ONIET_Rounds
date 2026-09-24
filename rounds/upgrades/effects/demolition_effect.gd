class_name DemolitionEffect
extends UpgradeEffect

## Golpes demoledores necesarios para romper un tile de borde: el tile usado
## más cercano a una zona segura (DeadZone) del mapa, en cualquier dirección
## (paredes, suelo y techo cuando la deadzone queda del lado correspondiente).
const SUELO_GOLPES := 2
const SUELO_GOLPES_META := &"demolition_suelo_golpes"


func on_body_hit(shot: Shot, body: Node, _player: Node) -> void:
	if body is TileMapLayer:
		_destroy_tiles(body as TileMapLayer, shot.hit_position, shot.direction)
	elif body.has_method("local_to_map") and body.has_method("erase_cell"):
		_destroy_tiles(body, shot.hit_position, shot.direction)


func _destroy_tiles(layer: Node, world_pos: Vector2, dir: Vector2) -> void:
	var local_pos: Vector2 = layer.to_local(world_pos)
	# Step slightly into the hit surface to ensure we map inside the correct tile
	var contact_pos := local_pos + dir.normalized() * 6.0
	var center_cell: Vector2i = layer.local_to_map(contact_pos)
	if layer is TileMapLayer and (layer as TileMapLayer).get_cell_source_id(center_cell) == -1:
		center_cell = layer.local_to_map(local_pos)

	# Demolish impact cell and one adjacent cell along the dominant impact axis (not diagonal leap)
	var forward_cell := center_cell
	if absf(dir.x) >= absf(dir.y):
		forward_cell += Vector2i(signi(dir.x), 0)
	else:
		forward_cell += Vector2i(0, signi(dir.y))

	_erase(layer, center_cell)
	_erase(layer, forward_cell)


func _erase(layer: Node, coords: Vector2i) -> void:
	# Borde = el tile usado más cercano a una zona segura (DeadZone) del mapa:
	# aguanta SUELO_GOLPES impactos y recién ahí se rompe. El resto de los
	# tiles (interiores y los que no miran a una deadzone, por ejemplo el
	# techo cuando no hay deadzone superior) se rompe de 1 golpe.
	if layer.has_meta("indestructible_coords"):
		var no_romper: Array = layer.get_meta("indestructible_coords")
		if coords in no_romper:
			return
	if layer is TileMapLayer:
		var tml := layer as TileMapLayer
		if _es_borde(tml, coords) and not _acumular_golpe(tml, coords):
			return
	else:
		# Fallback para capas genéricas sin TileMapLayer: borde = casco del
		# rect usado, conservando el comportamiento anterior.
		if coords in _borde_perimetral(layer, true) and not _acumular_golpe(layer, coords):
			return
	if layer is TileMapLayer:
		layer.set_cell(coords, -1)
	elif layer.has_method("erase_cell"):
		layer.erase_cell(coords)


## Devuelve las coordenadas del borde perimetral del tilemap: paredes
## (columnas x0 y x1), techo (fila superior) y, cuando incluir_suelo es
## true, la última capa del suelo (fila inferior). Usa el rect usado real
## para soportar mapas de cualquier tamaño.
func _borde_perimetral(layer: Node, incluir_suelo: bool = true) -> Array:
	var rect := _rect_usado(layer)
	if rect.size.x <= 0 or rect.size.y <= 0:
		# Fallback conservador si no hay rect disponible.
		return []
	var perimetro := []
	var x0: int = rect.position.x
	var y0: int = rect.position.y
	var x1: int = rect.position.x + rect.size.x - 1
	var y1: int = rect.position.y + rect.size.y - 1
	for x in range(x0, x1 + 1):
		perimetro.append(Vector2i(x, y0))
		if incluir_suelo:
			perimetro.append(Vector2i(x, y1))
	for y in range(y0, y1 + 1):
		perimetro.append(Vector2i(x0, y))
		perimetro.append(Vector2i(x1, y))
	return perimetro


func _rect_usado(layer: Node) -> Rect2i:
	if layer is TileMapLayer:
		return (layer as TileMapLayer).get_used_rect()
	if layer.has_method("get_used_rect"):
		return layer.get_used_rect()
	return Rect2i()


## Cache de las rectas (en espacio global) de las DeadZones del mapa que
## contiene cada capa, por instance_id de la capa.
var _deadzones_cache: Dictionary = {}


## Devuelve los rects globales de las zonas seguras (DeadZone) del mapa,
## subiendo por la jerarquía desde la capa hasta encontrar el Area2D.
func _deadzones(layer: TileMapLayer) -> Array:
	var key := layer.get_instance_id()
	if _deadzones_cache.has(key):
		return _deadzones_cache[key]
	var rects: Array = []
	var node: Node = layer
	while node != null:
		var dz := _find_deadzone(node)
		if dz != null:
			for child in dz.get_children():
				if child is CollisionShape2D and child.shape is RectangleShape2D:
					var col := child as CollisionShape2D
					var size := (col.shape as RectangleShape2D).size
					var center := col.global_position
					rects.append(Rect2(center - size * 0.5, size))
			break
		node = node.get_parent()
	_deadzones_cache[key] = rects
	return rects


func _find_deadzone(node: Node) -> Area2D:
	for child in node.get_children():
		if child is Area2D and (child.name == "DeadZone" or child is HazardZone):
			return child as Area2D
	return null


## Un tile es borde cuando es el tile usado MÁS CERCANO a una deadzone en
## alguna dirección: no hay ningún otro tile usado más allá (entre él y la
## deadzone) y la deadzone queda del lado correspondiente, alineada en el
## eje perpendicular.
func _es_borde(layer: TileMapLayer, coords: Vector2i) -> bool:
	var deadzones: Array = _deadzones(layer)
	if deadzones.is_empty():
		return false
	var rect := layer.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return false
	var tile_size: Vector2 = layer.tile_set.tile_size
	var tile_center := layer.to_global(layer.map_to_local(coords))
	var half := tile_size * 0.5
	for dz in deadzones:
		var d: Rect2 = dz
		# Deadzone a la izquierda, alineada en Y.
		if d.end.x <= tile_center.x and not _hay_tile_hasta(layer, coords, Vector2i.LEFT, rect) \
				and d.end.y > tile_center.y - half.y and d.position.y < tile_center.y + half.y:
			return true
		# Deadzone a la derecha, alineada en Y.
		if d.position.x >= tile_center.x and not _hay_tile_hasta(layer, coords, Vector2i.RIGHT, rect) \
				and d.end.y > tile_center.y - half.y and d.position.y < tile_center.y + half.y:
			return true
		# Deadzone abajo, alineada en X.
		if d.position.y >= tile_center.y and not _hay_tile_hasta(layer, coords, Vector2i.DOWN, rect) \
				and d.end.x > tile_center.x - half.x and d.position.x < tile_center.x + half.x:
			return true
		# Deadzone arriba, alineada en X (para mapas futuros con deadzone superior).
		if d.end.y <= tile_center.y and not _hay_tile_hasta(layer, coords, Vector2i.UP, rect) \
				and d.end.x > tile_center.x - half.x and d.position.x < tile_center.x + half.x:
			return true
	return false


## Devuelve true si existe algún tile usado entre coords (excluido) y el
## borde del rect usado, hacia la dirección dada. Si los hay, coords no es
## el tile más cercano a la deadzone en esa dirección.
func _hay_tile_hasta(layer: TileMapLayer, coords: Vector2i, dir: Vector2i, rect: Rect2i) -> bool:
	var cursor := coords + dir
	while rect.has_point(cursor):
		if layer.get_cell_source_id(cursor) != -1:
			return true
		cursor += dir
	return false


## Registra un golpe demoledor sobre el borde perimetral. Devuelve true solo
## cuando se acumularon los SUELO_GOLPES necesarios y el tile se rompe.
func _acumular_golpe(layer: Node, coords: Vector2i) -> bool:
	var golpes: Dictionary = layer.get_meta(SUELO_GOLPES_META, {})
	var total: int = int(golpes.get(coords, 0)) + 1
	if total < SUELO_GOLPES:
		golpes[coords] = total
		layer.set_meta(SUELO_GOLPES_META, golpes)
		return false
	golpes.erase(coords)
	layer.set_meta(SUELO_GOLPES_META, golpes)
	return true

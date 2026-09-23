class_name DemolitionEffect
extends UpgradeEffect


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
	# Los bordes perimetrales del mapa (paredes, suelo y techo) son irrompibles.
	# Se calculan dinámicamente desde el rect usado del tilemap, para soportar
	# mapas de cualquier tamaño (los antiguos 40x22 y los nuevos más grandes).
	if coords in _borde_perimetral(layer):
		return
	if layer.has_meta("indestructible_coords"):
		var no_romper: Array = layer.get_meta("indestructible_coords")
		if coords in no_romper:
			return
	if layer is TileMapLayer:
		layer.set_cell(coords, -1)
	elif layer.has_method("erase_cell"):
		layer.erase_cell(coords)


## Devuelve las coordenadas del borde perimetral del tilemap (paredes, techo y
## suelo), que deben ser irrompibles. Usa el rect usado real para soportar
## mapas de cualquier tamaño.
func _borde_perimetral(layer: Node) -> Array:
	var rect := Rect2i()
	if layer is TileMapLayer:
		rect = (layer as TileMapLayer).get_used_rect()
	elif layer.has_method("get_used_rect"):
		rect = layer.get_used_rect()
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
		perimetro.append(Vector2i(x, y1))
	for y in range(y0, y1 + 1):
		perimetro.append(Vector2i(x0, y))
		perimetro.append(Vector2i(x1, y))
	return perimetro

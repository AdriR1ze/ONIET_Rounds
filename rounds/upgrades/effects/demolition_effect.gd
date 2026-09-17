class_name DemolitionEffect
extends UpgradeEffect


func on_body_hit(bullet: Node, body: Node, _player: Node) -> void:
	if body is TileMapLayer:
		_destroy_tiles(body as TileMapLayer, bullet.global_position, bullet.direction)
	elif body.has_method("local_to_map") and body.has_method("erase_cell"):
		_destroy_tiles(body, bullet.global_position, bullet.direction)


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
	if layer is TileMapLayer:
		layer.set_cell(coords, -1)
	elif layer.has_method("erase_cell"):
		layer.erase_cell(coords)

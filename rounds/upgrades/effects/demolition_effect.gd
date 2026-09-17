class_name DemolitionEffect
extends UpgradeEffect


func on_body_hit(bullet: Node, body: Node, _player: Node) -> void:
	if body is TileMapLayer:
		_destroy_tiles(body as TileMapLayer, bullet.global_position, bullet.direction)
	elif body.has_method("local_to_map") and body.has_method("erase_cell"):
		_destroy_tiles(body, bullet.global_position, bullet.direction)


func _destroy_tiles(layer: Node, world_pos: Vector2, dir: Vector2) -> void:
	var local_pos: Vector2 = layer.to_local(world_pos)
	var center_cell: Vector2i = layer.local_to_map(local_pos)

	# Destroy impact cell and forward cell
	var forward_cell := center_cell + Vector2i(int(round(dir.x)), int(round(dir.y)))
	_erase(layer, center_cell)
	_erase(layer, forward_cell)


func _erase(layer: Node, coords: Vector2i) -> void:
	if layer is TileMapLayer:
		layer.set_cell(coords, -1)
	elif layer.has_method("erase_cell"):
		layer.erase_cell(coords)

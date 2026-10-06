extends SceneTree

func _init() -> void:
	var ps: PackedScene = load("res://levels/maps/map_02_tres_pisos.tscn")
	var root: Node = ps.instantiate()
	var layer: TileMapLayer = root.get_node("NeonTileMap")
	var ts: TileSet = layer.tile_set
	var tile_size := Vector2.ZERO
	if ts != null:
		tile_size = Vector2(ts.tile_size)
	print("TILE_SIZE=", tile_size)
	var cells := layer.get_used_cells()
	print("USED_CELLS=", cells.size())
	for c in cells:
		var sd: int = layer.get_cell_source_id(c)
		var ac: Vector2i = layer.get_cell_atlas_coords(c)
		print("CELL ", c.x, ",", c.y, " src=", sd, " atlas=", ac.x, ",", ac.y, " world=", Vector2(c) * tile_size)
	quit()

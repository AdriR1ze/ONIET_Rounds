extends SceneTree
var _player
var _st := 0
func _initialize() -> void:
	var ts: TileSet = load("res://effects/neon_tileset.tres")
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	for y in range(3, 7):
		layer.set_cell(Vector2i(5, y), 8, Vector2i(0, 0), 1)
	root.add_child(layer)
	_player = load("res://player/player_1.tscn").instantiate()
	_player.position = Vector2(176, 5 * 32)
	root.add_child(_player)
func _process(_d):
	var pf := Engine.get_physics_frames()
	if pf == 1 and _st == 0:
		_st = 1
		Input.action_press("p1_up"); Input.action_press("p1_jump")   # W
	if pf == 120 and _st == 1:
		_st = 2
		print("TREPAR con W: y=", "%.0f" % _player.position.y, " (arrancó 160, debe subir) climbing=", _player._is_climbing())
		Input.action_release("p1_up"); Input.action_release("p1_jump")
		print("RESULT: done")
		return true
	return false

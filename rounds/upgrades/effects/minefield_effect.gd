class_name MinefieldEffect
extends UpgradeEffect

const MINE_SCENE := preload("res://weapons/proximity_mine.tscn")


func on_body_hit(shot: Shot, _body: Node, player: Node) -> void:
	if shot.bounces > 0:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var mine: Node = MINE_SCENE.instantiate()
	mine.set("global_position", shot.hit_position)
	mine.set("source_player", player)
	tree.current_scene.add_child(mine)

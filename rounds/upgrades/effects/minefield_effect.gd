class_name MinefieldEffect
extends UpgradeEffect

const MINE_SCENE := preload("res://weapons/proximity_mine.tscn")


func on_body_hit(bullet: Node, _body: Node, player: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var mine: Node = MINE_SCENE.instantiate()
	mine.set("global_position", bullet.global_position)
	mine.set("source_player", player)
	tree.current_scene.add_child(mine)

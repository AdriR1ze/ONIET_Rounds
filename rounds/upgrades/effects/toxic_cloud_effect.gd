class_name ToxicCloudEffect
extends UpgradeEffect

const CLOUD_SCENE := preload("res://effects/toxic_cloud.tscn")


func on_hit(shot: Shot, _target: Node, player: Node) -> void:
	_spawn_cloud(shot.hit_position, player)


func on_body_hit(shot: Shot, _body: Node, player: Node) -> void:
	_spawn_cloud(shot.hit_position, player)


func _spawn_cloud(pos: Vector2, player: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var cloud: Node = CLOUD_SCENE.instantiate()
	cloud.set("global_position", pos)
	cloud.set("source_player", player)
	tree.current_scene.add_child(cloud)

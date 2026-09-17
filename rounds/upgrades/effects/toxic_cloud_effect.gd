class_name ToxicCloudEffect
extends UpgradeEffect

const CLOUD_SCENE := preload("res://effects/toxic_cloud.tscn")


func on_hit(bullet: Node, _target: Node, player: Node) -> void:
	var pos: Vector2 = bullet.global_position if bullet != null else (_target.global_position if _target is Node2D else Vector2.ZERO)
	_spawn_cloud(pos, player)


func on_body_hit(bullet: Node, _body: Node, player: Node) -> void:
	var pos: Vector2 = bullet.global_position if bullet != null else (_body.global_position if _body is Node2D else Vector2.ZERO)
	_spawn_cloud(pos, player)


func _spawn_cloud(pos: Vector2, player: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var cloud: Node = CLOUD_SCENE.instantiate()
	cloud.set("global_position", pos)
	cloud.set("source_player", player)
	tree.current_scene.add_child(cloud)

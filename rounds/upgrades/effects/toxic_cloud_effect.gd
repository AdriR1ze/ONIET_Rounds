class_name ToxicCloudEffect
extends UpgradeEffect

const CLOUD_SCENE := preload("res://effects/toxic_cloud.tscn")


func on_hit(shot: Shot, _target: Node, player: Node) -> void:
	_spawn_cloud(shot.hit_position, player, shot.damage if shot != null else 25)


func on_body_hit(shot: Shot, _body: Node, player: Node) -> void:
	if shot.bounces > 0:
		return
	_spawn_cloud(shot.hit_position, player, shot.damage if shot != null else 25)


func _spawn_cloud(pos: Vector2, player: Node, shot_damage: int = 25) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var cloud: Node = CLOUD_SCENE.instantiate()
	cloud.set("global_position", pos)
	cloud.set("source_player", player)
	cloud.set("tick_damage", maxf(float(shot_damage) * 0.20, 1.0))
	tree.current_scene.add_child.call_deferred(cloud)

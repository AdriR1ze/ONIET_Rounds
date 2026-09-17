class_name SplitterEffect
extends UpgradeEffect


func on_fire(bullet: Node, _player: Node) -> void:
	if "can_split" in bullet:
		bullet.can_split = true

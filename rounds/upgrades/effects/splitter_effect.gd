class_name SplitterEffect
extends UpgradeEffect


func on_fire(shot: Shot, _player: Node) -> void:
	shot.can_split = true

class_name PhantomRoundsEffect
extends UpgradeEffect


func on_fire(shot: Shot, _player: Node) -> void:
	shot.phantom = true

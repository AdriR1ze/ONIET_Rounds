class_name PhantomRoundsEffect
extends UpgradeEffect

@export var extra_wall_pierce: int = 1


func on_fire(bullet: Node, _player: Node) -> void:
	if "wall_pierce" in bullet:
		bullet.wall_pierce += extra_wall_pierce

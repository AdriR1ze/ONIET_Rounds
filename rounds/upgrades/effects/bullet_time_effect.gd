class_name BulletTimeEffect
extends UpgradeEffect

@export var speed_mult: float = 0.3


func on_fire(shot: Shot, _player: Node) -> void:
	shot.speed *= speed_mult
	shot.gravity *= speed_mult * speed_mult
	shot.lifetime = INF

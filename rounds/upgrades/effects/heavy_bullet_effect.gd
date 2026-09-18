class_name HeavyBulletEffect
extends UpgradeEffect

@export var stun_duration: float = 0.35


func on_fire(shot: Shot, _player: Node) -> void:
	shot.stun_duration = maxf(shot.stun_duration, stun_duration)

class_name HeavyBulletEffect
extends UpgradeEffect

@export var stun_duration: float = 0.35


func on_fire(bullet: Node, _player: Node) -> void:
	if "stun_duration" in bullet:
		bullet.stun_duration = maxf(bullet.stun_duration, stun_duration)

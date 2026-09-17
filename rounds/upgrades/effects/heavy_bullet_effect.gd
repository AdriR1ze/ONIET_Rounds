class_name HeavyBulletEffect
extends UpgradeEffect

@export var scale_multiplier: float = 1.6
@export var stun_duration: float = 0.35


func on_fire(bullet: Node, _player: Node) -> void:
	if "scale" in bullet:
		bullet.scale *= scale_multiplier
	if "stun_duration" in bullet:
		bullet.stun_duration = maxf(bullet.stun_duration, stun_duration)

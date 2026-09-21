class_name ImpactoSismicoEffect
extends UpgradeEffect

@export var knockback_bonus: float = 550.0
@export var stun_duration: float = 0.35


func on_fire(shot: Shot, _player: Node) -> void:
	if shot == null:
		return
	shot.knockback += knockback_bonus
	shot.stun_duration = maxf(shot.stun_duration, stun_duration)

class_name GlitchEffect
extends UpgradeEffect

@export var is_glitch: bool = true
@export var glitch_chance: float = 0.65


func on_fire(shot: Shot, _player: Node) -> void:
	if shot != null and randf() < glitch_chance:
		shot.is_glitch = true

class_name GlitchEffect
extends UpgradeEffect

@export var is_glitch: bool = true
@export var glitch_chance: float = 0.50


func on_fire(bullet: Node, _player: Node) -> void:
	if bullet != null and randf() < glitch_chance:
		bullet.set("is_glitch", true)

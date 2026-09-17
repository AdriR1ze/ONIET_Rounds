class_name LifestealEffect
extends UpgradeEffect

@export var amount: int = 1


func on_hit(_bullet: Node, _target: Node, player: Node) -> void:
	if player != null and player.has_method("heal"):
		player.heal(amount)

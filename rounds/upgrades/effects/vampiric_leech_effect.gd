class_name VampiricLeechEffect
extends UpgradeEffect

@export var leech_ratio: float = 0.30


func on_hit(shot: Shot, _target: Node, player: Node) -> void:
	if player != null and player.has_method("heal"):
		var dmg: int = 25
		if shot != null:
			dmg = shot.damage

		var heal_amount := maxi(int(round(dmg * leech_ratio)), 4)
		player.heal(heal_amount)

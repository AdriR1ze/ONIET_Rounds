class_name VampiricLeechEffect
extends UpgradeEffect

@export var leech_ratio: float = 0.30


func on_hit(bullet: Node, _target: Node, player: Node) -> void:
	if player != null and player.has_method("heal"):
		var dmg: int = 25
		if bullet != null and "damage" in bullet:
			dmg = bullet.damage
		elif player.has_meta("last_laser_damage"):
			dmg = player.get_meta("last_laser_damage")
		elif "_stats" in player and player._stats != null:
			dmg = player._stats.get_entero(&"damage")

		var heal_amount := maxi(int(round(dmg * leech_ratio)), 4)
		player.heal(heal_amount)

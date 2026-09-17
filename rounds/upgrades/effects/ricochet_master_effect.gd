class_name RicochetMasterEffect
extends UpgradeEffect

@export var bonus_per_bounce: float = 0.45


func on_fire(bullet: Node, _player: Node) -> void:
	if "ricochet_bonus" in bullet:
		bullet.ricochet_bonus += bonus_per_bounce


func on_bounce(bullet: Node, bounce_count: int, _player: Node) -> void:
	var visual := bullet.get_node_or_null("Visual") as CanvasItem
	if visual != null:
		# Gradually shifts from yellow to blazing red/orange with each bounce
		var r: float = 1.0 + float(bounce_count) * 0.4
		var g: float = maxf(0.9 - float(bounce_count) * 0.25, 0.1)
		var b: float = maxf(0.35 - float(bounce_count) * 0.15, 0.05)
		visual.modulate = Color(r, g, b, 1.0)

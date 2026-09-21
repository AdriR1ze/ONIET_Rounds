class_name PerforadoraVitalEffect
extends UpgradeEffect

@export var max_health_pct_per_tick: float = 0.04
@export var ticks: int = 3


func on_hit(_shot: Shot, target: Node, player: Node) -> void:
	if target == null:
		return
	var victim: Node = target.get_parent() if target is Area2D else target
	if victim != null and is_instance_valid(victim) and victim != player:
		if victim.has_method("apply_dot"):
			var target_max_hp: float = 100.0
			var hcomp = victim.get_node_or_null("HealthComponent")
			if hcomp != null and "max_health" in hcomp:
				target_max_hp = float(hcomp.max_health)
			var dmg_per_tick: float = maxf(target_max_hp * max_health_pct_per_tick, 4.0)
			victim.apply_dot(dmg_per_tick, ticks, player)

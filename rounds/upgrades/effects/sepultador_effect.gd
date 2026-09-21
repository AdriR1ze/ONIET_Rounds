class_name SepultadorEffect
extends UpgradeEffect


func on_hit(shot: Shot, target: Node, player: Node) -> void:
	if shot == null or target == null:
		return
	var victim: Node = target.get_parent() if target is Area2D else target
	if victim != null and is_instance_valid(victim) and victim != player:
		if victim.has_method("mark_sepultador"):
			victim.mark_sepultador(player, shot.damage, 0.6)

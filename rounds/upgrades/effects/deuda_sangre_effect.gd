class_name DeudaSangreEffect
extends UpgradeEffect


func on_apply(player: Node, _stacks: int) -> void:
	if player != null and "has_blood_debt" in player:
		player.has_blood_debt = true

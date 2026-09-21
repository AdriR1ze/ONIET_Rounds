class_name CorazonTitanioEffect
extends UpgradeEffect


func on_apply(player: Node, _stacks: int) -> void:
	if player != null and "has_titanium_heart" in player:
		player.has_titanium_heart = true

class_name CosechaBalasEffect
extends UpgradeEffect

@export var heal_amount: int = 5
@export var max_stacks: int = 3


func on_parry(_bullet: Node, player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("heal"):
		player.heal(heal_amount)
	if "_harvest_armor_stacks" in player:
		player._harvest_armor_stacks = mini(player._harvest_armor_stacks + 1, max_stacks)
		player._harvest_armor_timer = 5.0

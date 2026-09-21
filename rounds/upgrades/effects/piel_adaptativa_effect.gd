class_name PielAdaptativaEffect
extends UpgradeEffect

@export var max_stacks: int = 3
@export var duration: float = 4.0


func on_damaged(_amount: int, _source: Node, player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	if "_adaptive_armor_stacks" in player:
		player._adaptive_armor_stacks = mini(player._adaptive_armor_stacks + 1, max_stacks)
		player._adaptive_armor_timer = duration

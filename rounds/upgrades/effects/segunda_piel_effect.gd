class_name SegundaPielEffect
extends UpgradeEffect

@export var duration: float = 3.0


func on_damaged(_amount: int, _source: Node, player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	if "_second_skin_timer" in player:
		player._second_skin_timer = duration
		player._second_skin_tick_timer = 0.5

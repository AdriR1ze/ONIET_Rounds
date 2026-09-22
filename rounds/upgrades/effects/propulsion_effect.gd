class_name PropulsionEffect
extends UpgradeEffect

@export var recoil_force: float = 950.0


func on_fire(shot: Shot, player: Node) -> void:
	if shot == null or player == null or not is_instance_valid(player):
		return
	if player.has_method("apply_recoil"):
		var impulse := -shot.direction * recoil_force
		player.apply_recoil(impulse)

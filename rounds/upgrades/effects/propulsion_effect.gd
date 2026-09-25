class_name PropulsionEffect
extends UpgradeEffect

@export var recoil_force: float = 220.0
@export var air_recoil_force: float = 640.0


func on_fire(shot: Shot, player: Node) -> void:
	if shot == null or player == null or not is_instance_valid(player):
		return
	if player.has_method("apply_recoil"):
		var in_air := false
		if player.has_method("is_on_floor"):
			in_air = not player.is_on_floor()
		var force := air_recoil_force if in_air else recoil_force
		var impulse := -shot.direction * force
		if in_air and impulse.y < -50.0 and "velocity" in player:
			if player.velocity.y > 0.0:
				player.velocity.y = 0.0
		player.apply_recoil(impulse)

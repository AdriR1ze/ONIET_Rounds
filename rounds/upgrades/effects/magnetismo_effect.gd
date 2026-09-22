class_name MagnetismoEffect
extends UpgradeEffect

@export var radius: float = 240.0
@export var pull_force: float = 2600.0


func on_process(delta: float, player: Node) -> void:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return
	var p2d := player as Node2D
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	var pos := p2d.global_position
	for bullet in tree.get_nodes_in_group("bullet"):
		if not is_instance_valid(bullet) or not (bullet is Node2D):
			continue
		var b2d := bullet as Node2D
		# Ignore bullets fired by the player themselves
		if "shooter" in bullet and bullet.shooter == player:
			continue
		var diff := pos - b2d.global_position
		var dist := diff.length()
		if dist <= radius and dist > 8.0:
			if "velocity" in bullet:
				var current_speed: float = bullet.velocity.length()
				var pull := diff.normalized() * (pull_force * delta)
				bullet.velocity += pull
				if current_speed > 10.0:
					bullet.velocity = bullet.velocity.normalized() * current_speed
				bullet.direction = bullet.velocity.normalized()
				bullet.rotation = bullet.velocity.angle()

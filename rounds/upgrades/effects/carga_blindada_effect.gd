class_name CargaBlindadaEffect
extends UpgradeEffect

@export var damage: int = 20
@export var knockback: float = 450.0


func on_process(delta: float, player: Node) -> void:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return
	var p2d := player as Node2D

	var is_running: bool = false
	if "current_state" in player and "is_on_floor" in player:
		is_running = player.is_on_floor() and absf(player.velocity.x) > 100.0

	if is_running:
		player._running_time += delta
		if player._running_time >= 0.4:
			player._charge_armor = 0.25
			# Partícula/estela de embestida
			_check_enemy_ram(p2d, player)
	else:
		player._running_time = maxf(player._running_time - delta * 2.0, 0.0)
		player._charge_armor = 0.0


func _check_enemy_ram(p2d: Node2D, player: Node) -> void:
	if player._charge_hit_cooldown > 0.0:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	for p in tree.get_nodes_in_group("player"):
		if p != null and is_instance_valid(p) and p != player and p is Node2D:
			var target_p2d := p as Node2D
			if target_p2d.global_position.distance_to(p2d.global_position) < 32.0:
				player._charge_hit_cooldown = 1.2
				if p.has_method("hurt"):
					p.hurt(damage, player)
				if p.has_method("apply_knockback"):
					var dir := Vector2(signf(player.velocity.x), -0.3).normalized()
					p.apply_knockback(dir, knockback)
				CombatCamera.shake_viewport(player, 4.0, 0.15)
				var audio := tree.root.get_node_or_null("AudioManager")
				if audio != null and audio.has_method("reproducir"):
					audio.reproducir("golpe", 0.15)
				break

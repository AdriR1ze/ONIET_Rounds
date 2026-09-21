class_name MuroVivoEffect
extends UpgradeEffect

const BARRIER_MAX_HITS := 2


class Barrier extends Node2D:
	var hits_remaining: int = BARRIER_MAX_HITS
	var owner_player: Node = null
	var _shield_visual: Polygon2D = null

	func _ready() -> void:
		_shield_visual = Polygon2D.new()
		_shield_visual.color = Color(0.25, 0.75, 1.0, 0.65)
		_shield_visual.polygon = PackedVector2Array([
			Vector2(14, -26), Vector2(22, -14), Vector2(22, 14), Vector2(14, 26),
			Vector2(18, 14), Vector2(18, -14)
		])
		add_child(_shield_visual)

	func absorb_hit() -> bool:
		if hits_remaining <= 0:
			return false
		hits_remaining -= 1
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root.has_node("AudioManager"):
			tree.root.get_node("AudioManager").call("reproducir", "golpe", 0.12)
		if is_instance_valid(owner_player):
			CombatCamera.shake_viewport(owner_player, 3.0, 0.15)

		# Flash del escudo
		if _shield_visual != null:
			var tw := _shield_visual.create_tween()
			_shield_visual.modulate = Color(2.0, 2.0, 2.0, 1.0)
			tw.tween_property(_shield_visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

		if hits_remaining <= 0:
			# Romper escudo
			if is_instance_valid(owner_player) and "active_barrier" in owner_player:
				owner_player.active_barrier = null
			queue_free()
		return true


func on_process(delta: float, player: Node) -> void:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return
	var p2d := player as Node2D

	var is_still: bool = false
	if "is_on_floor" in player and "velocity" in player:
		is_still = player.is_on_floor() and absf(player.velocity.x) < 8.0 and absf(player.velocity.y) < 8.0

	if is_still:
		player._still_timer += delta
		if player._still_timer >= 0.75 and not is_instance_valid(player.active_barrier):
			_deploy_barrier(p2d, player)
	else:
		player._still_timer = 0.0
		if is_instance_valid(player.active_barrier):
			player.active_barrier.queue_free()
			player.active_barrier = null


func _deploy_barrier(p2d: Node2D, player: Node) -> void:
	var b := Barrier.new()
	b.owner_player = player
	b.scale.x = float(player.facing) if "facing" in player else 1.0
	p2d.add_child(b)
	player.active_barrier = b
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.has_node("AudioManager"):
		tree.root.get_node("AudioManager").call("reproducir", "mejora", 0.06)

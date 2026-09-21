class_name ZonaGravedadEffect
extends UpgradeEffect

@export var radius: float = 130.0


func on_process(_delta: float, player: Node) -> void:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return
	var p2d := player as Node2D
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	var pos := p2d.global_position
	for p in tree.get_nodes_in_group("player"):
		if p != null and is_instance_valid(p) and p != player and p is Node2D:
			var target_p2d := p as Node2D
			if target_p2d.global_position.distance_to(pos) <= radius:
				if "gravity_scale" in p:
					p.gravity_scale = 1.85
				if "jump_force_multiplier" in p:
					p.jump_force_multiplier = 0.45

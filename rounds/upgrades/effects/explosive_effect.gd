class_name ExplosiveEffect
extends UpgradeEffect

@export var radius: float = 70.0
@export var damage: int = 15


func on_hit(bullet: Node, _target: Node, player: Node) -> void:
	if player == null or bullet == null:
		return
	var origen: Vector2 = bullet.global_position
	var targets: Array = player.get_tree().get_nodes_in_group("player")
	for enemigo in player.get_tree().get_nodes_in_group("enemy"):
		targets.append(enemigo)
	for objetivo in targets:
		if not is_instance_valid(objetivo) or objetivo == player:
			continue
		if objetivo.global_position.distance_to(origen) <= radius and objetivo.has_method("hurt"):
			objetivo.hurt(damage, player)

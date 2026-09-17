class_name ExplosiveEffect
extends UpgradeEffect

@export var radius: float = 70.0
@export var damage: int = 1


func on_hit(bullet: Node, _target: Node, player: Node) -> void:
	if player == null or bullet == null:
		return
	var origen: Vector2 = bullet.global_position
	for enemigo in player.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemigo):
			continue
		if enemigo.global_position.distance_to(origen) <= radius and enemigo.has_method("hurt"):
			enemigo.hurt(damage, player)

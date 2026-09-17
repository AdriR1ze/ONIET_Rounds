class_name HurtboxComponent
extends Area2D

signal hurt(amount: int, source: Node)
signal parried(bullet: Node)


func take_hit(amount: int, source: Node = null) -> void:
	hurt.emit(amount, source)


func try_parry(bullet: Node) -> bool:
	var parent: Node = get_parent()
	if parent != null and parent.has_method("can_parry") and parent.can_parry():
		if bullet.has_method("parry"):
			bullet.parry(parent)
		parried.emit(bullet)
		if parent.has_method("on_parry"):
			parent.on_parry(bullet)
		return true
	return false

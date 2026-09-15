class_name HurtboxComponent
extends Area2D

signal hurt(amount: int, source: Node)


func take_hit(amount: int, source: Node = null) -> void:
	hurt.emit(amount, source)

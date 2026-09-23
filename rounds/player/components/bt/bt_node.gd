class_name BTNode
extends RefCounted

enum Status { SUCCESS, FAILURE, RUNNING }

func tick(_delta: float) -> int:
	return Status.SUCCESS

func reset() -> void:
	pass

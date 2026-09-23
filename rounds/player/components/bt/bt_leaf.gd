class_name BTLeaf
extends BTNode

var _fn: Callable

func _init(fn: Callable) -> void:
	_fn = fn

func tick(delta: float) -> int:
	var r: Variant = _fn.call(delta)
	if r is int:
		return r
	if r is bool:
		return BTNode.Status.SUCCESS if r else BTNode.Status.FAILURE
	return BTNode.Status.SUCCESS

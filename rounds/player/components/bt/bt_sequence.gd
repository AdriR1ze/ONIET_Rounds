class_name BTSequence
extends BTNode

var children: Array = []

func _init(kids: Array = []) -> void:
	children = kids

func tick(delta: float) -> int:
	for c in children:
		var r: int = c.tick(delta)
		if r != BTNode.Status.SUCCESS:
			return r
	return BTNode.Status.SUCCESS

func reset() -> void:
	for c in children:
		c.reset()

class_name BTSelector
extends BTNode

var children: Array = []

func _init(kids: Array = []) -> void:
	children = kids

func tick(delta: float) -> int:
	for c in children:
		var r: int = c.tick(delta)
		if r != BTNode.Status.FAILURE:
			return r
	return BTNode.Status.FAILURE

func reset() -> void:
	for c in children:
		c.reset()

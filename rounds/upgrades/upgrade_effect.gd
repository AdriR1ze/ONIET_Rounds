class_name UpgradeEffect
extends Resource


func on_apply(_player: Node, _stacks: int) -> void:
	pass


func on_fire(_bullet: Node, _player: Node) -> void:
	pass


func on_hit(_bullet: Node, _target: Node, _player: Node) -> void:
	pass


func on_body_hit(_bullet: Node, _body: Node, _player: Node) -> void:
	pass


func on_bounce(_bullet: Node, _bounce_count: int, _player: Node) -> void:
	pass


func on_kill(_target: Node, _player: Node) -> void:
	pass


func on_crit(_bullet: Node, _player: Node) -> void:
	pass


func on_shoot(_bullet: Node, _player: Node) -> void:
	pass

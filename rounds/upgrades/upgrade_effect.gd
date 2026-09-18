class_name UpgradeEffect
extends Resource


func on_apply(_player: Node, _stacks: int) -> void:
	pass


func on_fire(_shot: Shot, _player: Node) -> void:
	pass


func on_hit(_shot: Shot, _target: Node, _player: Node) -> void:
	pass


func on_body_hit(_shot: Shot, _body: Node, _player: Node) -> void:
	pass


func on_bounce(_shot: Shot, _bounce_count: int, _player: Node) -> void:
	pass


func on_kill(_target: Node, _player: Node) -> void:
	pass


func on_crit(_bullet: Node, _player: Node) -> void:
	pass


func on_shoot(_bullet: Node, _player: Node) -> void:
	pass

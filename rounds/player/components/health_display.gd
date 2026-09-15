extends Label

var _player_number: int = 1


func _ready() -> void:
	var value: Variant = get_parent().get("player_number")
	if value != null:
		_player_number = int(value)
	var health: Node = get_parent().get_node_or_null("HealthComponent")
	if health != null:
		_on_health_changed(health.health, health.max_health)


func _on_health_changed(current: int, _maximum: int) -> void:
	text = "P%d  HP %d" % [_player_number, current]

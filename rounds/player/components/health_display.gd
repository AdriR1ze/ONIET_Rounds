extends ProgressBar


func _ready() -> void:
	var health: Node = get_parent().get_node_or_null("HealthComponent")
	if health != null:
		_on_health_changed(health.health, health.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	max_value = maxi(maximum, 1)
	value = current

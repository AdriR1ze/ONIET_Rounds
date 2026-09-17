extends Label

var _player_number: int = 1
var _current_hp: int = 100
var _max_hp: int = 100
var _ammo: int = 3
var _max_ammo: int = 3
var _reloading: bool = false


func _ready() -> void:
	var value: Variant = get_parent().get("player_number")
	if value != null:
		_player_number = int(value)
	var health: Node = get_parent().get_node_or_null("HealthComponent")
	if health != null:
		_current_hp = health.health
		_max_hp = health.max_health
	var weapon: Node = get_parent().get_node_or_null("WeaponComponent")
	if weapon != null:
		_ammo = weapon.current_ammo
		_max_ammo = weapon.max_ammo
		weapon.ammo_changed.connect(_on_ammo_changed)
		weapon.reload_started.connect(_on_reload_started)
		weapon.reload_completed.connect(_on_reload_completed)
	_update_text()


func _on_health_changed(current: int, maximum: int) -> void:
	_current_hp = current
	_max_hp = maximum
	_update_text()


func _on_ammo_changed(current: int, maximum: int) -> void:
	_ammo = current
	_max_ammo = maximum
	_update_text()


func _on_reload_started() -> void:
	_reloading = true
	_update_text()


func _on_reload_completed() -> void:
	_reloading = false
	_update_text()


func _update_text() -> void:
	var ammo_str := ""
	if _reloading:
		ammo_str = "[Recargando...]"
	else:
		var pips := ""
		for i in _max_ammo:
			pips += "●" if i < _ammo else "○"
		ammo_str = "%s (%d/%d)" % [pips, _ammo, _max_ammo]

	var vidas_count: int = 5
	if RunManager != null and RunManager.has_method("vidas_de"):
		vidas_count = RunManager.vidas_de(_player_number)

	var hearts := ""
	for i in 5:
		hearts += "♥" if i < vidas_count else "♡"

	text = "P%d: %d/%d HP\n%s\n%s" % [_player_number, _current_hp, _max_hp, ammo_str, hearts]

class_name ToxicCloud
extends Area2D

@export var radius: float = 52.0
@export var duration: float = 3.5
@export var tick_damage: float = 5.0
@export var cloud_tick_interval: float = 0.50
@export var lingering_hits: int = 3

var source_player: Node = null
var _time_alive: float = 0.0
var _anim_time: float = 0.0
var _overlapping_players: Dictionary = {}  # Player -> float (timer hasta siguiente tick)


func _ready() -> void:
	add_to_group("bullet")
	collision_layer = 0
	collision_mask = 4  # Hurtbox layer
	var shape := CircleShape2D.new()
	shape.radius = radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	_time_alive += delta
	_anim_time += delta * 3.0
	queue_redraw()

	# Detectar áreas solapadas si el jugador ya estaba al crearse la nube
	for area in get_overlapping_areas():
		var p: Node = area.get_parent()
		if p != null and p != source_player and p.has_method("apply_dot"):
			if not _overlapping_players.has(p):
				_register_player_inside(p)

	# Procesar daño por permanencia dentro de la nube tóxica
	var to_remove: Array = []
	for p in _overlapping_players:
		if not is_instance_valid(p) or (p.has_method("is_alive") and not p.is_alive()):
			to_remove.append(p)
			continue
		_overlapping_players[p] -= delta
		if _overlapping_players[p] <= 0.0:
			_overlapping_players[p] = cloud_tick_interval
			_damage_player_inside(p)

	for p in to_remove:
		_overlapping_players.erase(p)

	# Al terminar la duración de la nube, aplicar los 3 hits de veneno residual a quienes sigan dentro
	if _time_alive >= duration:
		_on_cloud_expired()
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var target_player: Node = area.get_parent()
	if target_player == null or target_player == source_player:
		return
	if target_player.has_method("apply_dot") and not _overlapping_players.has(target_player):
		_register_player_inside(target_player)


func _on_area_exited(area: Area2D) -> void:
	var target_player: Node = area.get_parent()
	if target_player != null and _overlapping_players.has(target_player):
		_overlapping_players.erase(target_player)
		if target_player.has_method("set_in_toxic_cloud"):
			target_player.set_in_toxic_cloud(false)
		# Al salir de la nube: 3 hits más de veneno
		_apply_lingering_poison(target_player)


func _register_player_inside(player: Node) -> void:
	_overlapping_players[player] = cloud_tick_interval
	if player.has_method("set_in_toxic_cloud"):
		player.set_in_toxic_cloud(true)
	# Primer impacto de veneno inmediato al entrar en la nube
	_damage_player_inside(player)


func _damage_player_inside(player: Node) -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("apply_poison_tick"):
		player.apply_poison_tick(tick_damage, source_player)
	elif player.has_method("apply_dot"):
		player.apply_dot(tick_damage, 1, source_player)


func _apply_lingering_poison(player: Node) -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("apply_dot"):
		# Exactamente 3 hits más tras salir o terminarse la nube
		player.apply_dot(tick_damage, lingering_hits, source_player)


func _on_cloud_expired() -> void:
	for p in _overlapping_players.keys():
		if is_instance_valid(p):
			if p.has_method("set_in_toxic_cloud"):
				p.set_in_toxic_cloud(false)
			_apply_lingering_poison(p)
	_overlapping_players.clear()


func _exit_tree() -> void:
	# Asegurar que ningún jugador quede con tinte de nube si la escena o nodo se destruye
	for p in _overlapping_players.keys():
		if is_instance_valid(p) and p.has_method("set_in_toxic_cloud"):
			p.set_in_toxic_cloud(false)


func _draw() -> void:
	var alpha := 1.0 - (_time_alive / duration)
	var pulse := 1.0 + 0.08 * sin(_anim_time)
	var r := radius * pulse

	# Outer smoke ring
	draw_circle(Vector2.ZERO, r, Color(0.2, 0.85, 0.25, 0.22 * alpha))
	# Mid ring
	draw_circle(Vector2.ZERO, r * 0.7, Color(0.15, 0.95, 0.35, 0.28 * alpha))
	# Inner cloud
	draw_circle(Vector2.ZERO, r * 0.4, Color(0.3, 1.0, 0.2, 0.35 * alpha))

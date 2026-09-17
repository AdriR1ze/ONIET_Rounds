class_name ProximityMine
extends Area2D

@export var damage: int = 35
@export var explosion_radius: float = 65.0
@export var detection_radius: float = 40.0
@export var arming_delay: float = 0.3
@export var fuse_time: float = 0.2
@export var lifetime: float = 6.0
@export var knockback: float = 350.0

var source_player: Node = null

var _time_alive: float = 0.0
var _armed: bool = false
var _triggered: bool = false
var _fuse_timer: float = 0.0
var _blink_time: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4  # Hurtbox layer
	var shape := CircleShape2D.new()
	shape.radius = detection_radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_time_alive += delta
	_blink_time += delta

	if not _armed:
		if _time_alive >= arming_delay:
			_armed = true
			_check_existing_overlaps()

	if _triggered:
		_fuse_timer -= delta
		if _fuse_timer <= 0.0:
			_detonate()
			return

	if _time_alive >= lifetime:
		_detonate()
		return

	queue_redraw()


func _check_existing_overlaps() -> void:
	for area in get_overlapping_areas():
		_check_target(area)


func _on_area_entered(area: Area2D) -> void:
	if not _armed or _triggered:
		return
	_check_target(area)


func _check_target(area: Area2D) -> void:
	var target := area.get_parent()
	if target == null or target == source_player:
		return
	_triggered = true
	_fuse_timer = fuse_time


func _detonate() -> void:
	# Query in explosion radius
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 4  # Hurtbox

	var hits := space.intersect_shape(query, 16)
	var damaged_players: Array = []
	for hit in hits:
		var area: Area2D = hit.get("collider")
		if area == null:
			continue
		var target := area.get_parent()
		if target != null and not damaged_players.has(target):
			damaged_players.append(target)
			if area.has_method("take_hit"):
				area.take_hit(damage, source_player)
			if target.has_method("apply_knockback"):
				var target_pos: Vector2 = target.global_position
				var dir: Vector2 = (target_pos - global_position).normalized()
				if dir.is_zero_approx():
					dir = Vector2.UP
				target.apply_knockback(dir, knockback)

	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("reproducir"):
		audio.reproducir("golpe", 0.05)
	queue_free()


func _draw() -> void:
	# Metal base
	draw_rect(Rect2(-8, -4, 16, 6), Color(0.2, 0.22, 0.25), true)
	draw_rect(Rect2(-6, -6, 12, 3), Color(0.3, 0.33, 0.38), true)

	# Blinking LED
	var blink_speed := 16.0 if _triggered else (6.0 if _armed else 2.0)
	var led_on := fmod(_blink_time * blink_speed, 2.0) < 1.0
	var led_color := Color(1.0, 0.15, 0.15) if led_on else Color(0.3, 0.05, 0.05)
	draw_circle(Vector2(0, -6), 2.5, led_color)

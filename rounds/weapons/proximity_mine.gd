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
	add_to_group("bullet")
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
	var target: Node = area.get_parent()
	if target == null or target == source_player:
		return
	_triggered = true
	_fuse_timer = fuse_time


func _detonate() -> void:
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 4  # Hurtbox
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hits := space.intersect_shape(query, 16)
	var damaged_players: Array = []
	for hit in hits:
		var area: Area2D = hit.get("collider") as Area2D
		if area == null:
			continue
		var target: Node = area.get_parent()
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

	# Direct fallback check for all players in group within radius
	var tree := get_tree()
	if tree != null:
		for p in tree.get_nodes_in_group("player"):
			if p != null and p is Node2D and not damaged_players.has(p):
				if (p as Node2D).global_position.distance_to(global_position) <= explosion_radius:
					damaged_players.append(p)
					if p.has_method("hurt"):
						p.hurt(damage, source_player)
					if p.has_method("apply_knockback"):
						var dir := ((p as Node2D).global_position - global_position).normalized()
						if dir.is_zero_approx():
							dir = Vector2.UP
						p.apply_knockback(dir, knockback)

	# Visual explosion flash
	if tree != null and tree.current_scene != null:
		var boom := Polygon2D.new()
		var pts: PackedVector2Array = []
		for a in 16:
			var ang := float(a) / 16.0 * TAU
			pts.append(Vector2(cos(ang), sin(ang)) * explosion_radius)
		boom.polygon = pts
		boom.color = Color(1.0, 0.45, 0.1, 0.65)
		boom.global_position = global_position
		tree.current_scene.add_child(boom)
		var tween := boom.create_tween()
		tween.tween_property(boom, "modulate:a", 0.0, 0.22)
		tween.tween_callback(boom.queue_free)

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

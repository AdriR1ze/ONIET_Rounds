class_name ToxicCloud
extends Area2D

@export var radius: float = 52.0
@export var duration: float = 3.5
@export var tick_damage: float = 5.0
@export var dot_duration: float = 3.0

var source_player: Node = null
var _time_alive: float = 0.0
var _tick_interval: float = 0.8
var _tick_timer: float = 0.0
var _anim_time: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4  # Hurtbox layer
	var shape := CircleShape2D.new()
	shape.radius = radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_time_alive += delta
	_anim_time += delta * 3.0
	_tick_timer -= delta
	queue_redraw()

	if _tick_timer <= 0.0:
		_tick_timer = _tick_interval
		_reapply_to_overlapping()

	if _time_alive >= duration:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	_apply_poison_to_area(area)


func _reapply_to_overlapping() -> void:
	for area in get_overlapping_areas():
		_apply_poison_to_area(area)


func _apply_poison_to_area(area: Area2D) -> void:
	var target_player := area.get_parent()
	if target_player == null or target_player == source_player:
		return
	if target_player.has_method("apply_dot"):
		# 3 ticks of damage over dot_duration
		target_player.apply_dot(tick_damage, dot_duration, source_player)


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

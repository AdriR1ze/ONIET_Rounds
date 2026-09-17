extends Area2D

@export var speed: float = 780.0
@export var lifetime: float = 2.5
@export var damage: int = 25
@export var pierce: int = 0
@export var knockback: float = 0.0
@export var bullet_gravity: float = 720.0
@export var drag: float = 0.2
@export var max_fall_speed: float = 1200.0
@export var bounces: int = 0
@export var splits: int = 0

var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var shooter: Node = null
var _time_alive: float = 0.0
var player: Node = null
var effects: Array = []
var _hit_targets: Array = []
var _trail_points: Array[Vector2] = []

const MAX_TRAIL_POINTS := 8


func _ready() -> void:
	if velocity == Vector2.ZERO:
		velocity = direction * speed
	rotation = velocity.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	var count := _trail_points.size()
	if count < 2:
		return
	var base_color := Color(1.0, 0.88, 0.35)
	for i in range(count - 1):
		var p1 := to_local(_trail_points[i])
		var p2 := to_local(_trail_points[i + 1])
		var t := float(i + 1) / float(count)
		var col := Color(base_color.r, base_color.g, base_color.b, t * 0.65)
		var width := lerpf(1.0, 3.5, t)
		draw_line(p1, p2, col, width)


func _physics_process(delta: float) -> void:
	# Resistencia del aire / drag aerodinámico
	if drag > 0.0:
		velocity -= velocity * (drag * delta)

	# Aceleración por gravedad
	velocity.y += bullet_gravity * delta
	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed

	position += velocity * delta

	if not velocity.is_zero_approx():
		direction = velocity.normalized()
		rotation = velocity.angle()

	_trail_points.append(global_position)
	if _trail_points.size() > MAX_TRAIL_POINTS:
		_trail_points.pop_front()
	queue_redraw()

	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


func parry(new_shooter: Node) -> void:
	shooter = new_shooter
	player = new_shooter
	velocity = -velocity
	direction = velocity.normalized()
	rotation = velocity.angle()
	position += direction * 8.0
	_time_alive = 0.0
	_hit_targets.clear()
	_trail_points.clear()
	var visual := get_node_or_null("Visual") as CanvasItem
	if visual != null:
		visual.modulate = Color(1.5, 1.5, 1.5, 1.0)


func _on_area_entered(area: Area2D) -> void:
	if area in _hit_targets:
		return
	if shooter != null and (area == shooter or shooter.is_ancestor_of(area)):
		return

	if area.has_method("try_parry") and area.try_parry(self):
		return
	var parent := area.get_parent()
	if parent != null and parent.has_method("can_parry") and parent.can_parry():
		parry(parent)
		if parent.has_method("on_parry"):
			parent.on_parry(self)
		return

	if not area.has_method("take_hit"):
		return

	var dueno := area.get_parent()
	_hit_targets.append(area)
	for efecto in effects:
		efecto.on_hit(self, area, player)
	area.take_hit(damage, player)
	if knockback > 0.0 and dueno != null and dueno.has_method("apply_knockback"):
		dueno.apply_knockback(direction, knockback)

	if pierce > 0:
		pierce -= 1
	else:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if shooter != null and (body == shooter or shooter.is_ancestor_of(body)):
		return
	if bounces > 0:
		bounces -= 1
		var space_state := get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(global_position - direction * 16.0, global_position + direction * 16.0)
		query.exclude = [self]
		var result := space_state.intersect_ray(query)
		if result.has("normal"):
			velocity = velocity.bounce(result["normal"]) * 0.75
		else:
			velocity.y = -velocity.y * 0.75
		direction = velocity.normalized()
		rotation = velocity.angle()
		position += direction * 6.0
		_trail_points.clear()
		return
	queue_free()

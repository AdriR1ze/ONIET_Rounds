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
@export var wall_pierce: int = 0
@export var can_split: bool = false
@export var ricochet_bonus: float = 0.0
@export var stun_duration: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var shooter: Node = null
var _time_alive: float = 0.0
var player: Node = null
var effects: Array = []
var _hit_targets: Array = []
var _trail_points: Array[Vector2] = []
var bounce_count: int = 0
var has_split: bool = false
var _initial_dir: Vector2 = Vector2.ZERO
var _distance_traveled: float = 0.0
var _split_distance: float = 0.0

const MAX_TRAIL_POINTS := 8


func _ready() -> void:
	if velocity == Vector2.ZERO:
		velocity = direction * speed
	_initial_dir = direction
	rotation = velocity.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	if can_split and not has_split:
		call_deferred("_setup_split_distance")


func _setup_split_distance() -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + direction * 1400.0)
	query.collision_mask = 5
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if shooter != null:
		query.exclude = [shooter, self]
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		var total_dist: float = global_position.distance_to(hit["position"])
		_split_distance = maxf(total_dist * 0.5, 45.0)
	else:
		_split_distance = speed * 0.45


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

	# Aceleración por gravedad: menor al disparar horizontalmente, completa al tirar en parábola
	var vert_ratio := clampf(absf(_initial_dir.y) / 0.55, 0.0, 1.0)
	var gravity_factor := lerpf(0.20, 1.0, vert_ratio)
	velocity.y += (bullet_gravity * gravity_factor) * delta
	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed

	var step := velocity * delta
	position += step
	_distance_traveled += step.length()

	if not velocity.is_zero_approx():
		direction = velocity.normalized()
		rotation = velocity.angle()

	_trail_points.append(global_position)
	if _trail_points.size() > MAX_TRAIL_POINTS:
		_trail_points.pop_front()
	queue_redraw()

	if can_split and not has_split and _split_distance > 0.0 and _distance_traveled >= _split_distance:
		_do_split()

	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


func _do_split() -> void:
	if has_split:
		return
	has_split = true
	can_split = false

	var bullet_scene: PackedScene = load("res://weapons/bullet.tscn")
	var current_spd := velocity.length()
	var child_dmg := maxi(int(round(damage * 0.40)), 1)

	scale *= 0.75
	damage = child_dmg

	var angles := [deg_to_rad(-20.0), deg_to_rad(20.0)]
	for ang in angles:
		var child_b: Node = bullet_scene.instantiate()
		child_b.global_position = global_position
		child_b.direction = direction.rotated(ang)
		child_b.speed = current_spd
		child_b.velocity = child_b.direction * current_spd
		child_b.damage = child_dmg
		child_b.lifetime = maxf(lifetime - _time_alive, 0.6)
		child_b.bullet_gravity = bullet_gravity
		child_b.drag = drag
		child_b.shooter = shooter
		child_b.player = player
		child_b.can_split = false
		child_b.has_split = true
		child_b.bounces = bounces
		child_b.wall_pierce = wall_pierce
		child_b.scale = scale
		get_parent().add_child(child_b)


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
	var parent: Node = area.get_parent()
	if parent != null and parent.has_method("can_parry") and parent.can_parry():
		parry(parent)
		if parent.has_method("on_parry"):
			parent.on_parry(self)
		return

	if not area.has_method("take_hit"):
		return

	var dueno: Node = area.get_parent()
	_hit_targets.append(area)
	for efecto in effects:
		efecto.on_hit(self, area, player)

	var hit_damage := damage
	if ricochet_bonus > 0.0 and bounce_count > 0:
		hit_damage = int(round(damage * (1.0 + ricochet_bonus * bounce_count)))

	area.take_hit(hit_damage, player)
	if knockback > 0.0 and dueno != null and dueno.has_method("apply_knockback"):
		dueno.apply_knockback(direction, knockback)
	if stun_duration > 0.0 and dueno != null and dueno.has_method("stun"):
		dueno.stun(stun_duration)

	if pierce > 0:
		pierce -= 1
	else:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if shooter != null and (body == shooter or shooter.is_ancestor_of(body)):
		return

	for efecto in effects:
		if efecto.has_method("on_body_hit"):
			efecto.on_body_hit(self, body, player)

	if wall_pierce > 0:
		wall_pierce -= 1
		var visual := get_node_or_null("Visual") as CanvasItem
		if visual != null:
			visual.modulate = Color(0.75, 0.4, 1.0, 0.7)
		position += direction * 24.0
		return

	if bounces > 0:
		bounces -= 1
		bounce_count += 1
		for efecto in effects:
			if efecto.has_method("on_bounce"):
				efecto.on_bounce(self, bounce_count, player)

		if can_split and not has_split:
			_do_split()

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

extends Area2D

static var _bullet_scene_res: PackedScene = null
const MAX_TRAIL_POINTS := 8
const BORDER_PROBE := 96.0

@export var speed: float = 1050.0
@export var lifetime: float = 1.5
@export var damage: int = 25
@export var pierce: int = 0
@export var knockback: float = 0.0
@export var bullet_gravity: float = 1200.0
@export var drag: float = 0.0
@export var max_fall_speed: float = 2000.0
@export var bounces: int = 0
@export var splits: int = 0
@export var wall_pierce: int = 0
@export var can_split: bool = false
@export var ricochet_bonus: float = 0.0
@export var stun_duration: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var shooter: Node = null
var player: Node = null
var effects: Array = []
var shot: Shot = null

var _time_alive: float = 0.0
var _hit_targets: Array = []
# Fuego amigo: la bala solo es inmune al dueño mientras siga dentro de su hurtbox.
var _shooter_immune: bool = true
var _trail_points: Array[Vector2] = []
var bounce_count: int = 0
var has_split: bool = false
var _initial_dir: Vector2 = Vector2.ZERO
var _distance_traveled: float = 0.0
var _split_distance: float = 0.0

# Mecánica de Glitch
var is_glitch: bool = false
var has_glitched: bool = false
var _glitch_timer: float = 0.0

# Mecánica de Balas Fantasma / Phasing
var _is_phasing_wall: bool = false
var _phasing_bodies: Array[Node] = []


func _ready() -> void:
	add_to_group("bullet")
	if velocity == Vector2.ZERO:
		velocity = direction * speed
	_initial_dir = direction
	rotation = velocity.angle()

	if shot == null:
		shot = Shot.new()
		shot.direction = direction
		shot.damage = damage
		shot.speed = speed
		shot.lifetime = lifetime
		shot.knockback = knockback
		shot.pierce = pierce
		shot.wall_pierce = wall_pierce
		shot.bounces = bounces
		shot.gravity = bullet_gravity
		shot.drag = drag
		shot.stun_duration = stun_duration
		shot.ricochet_bonus = ricochet_bonus
		shot.can_split = can_split
		shot.is_glitch = is_glitch
	if shot != null:
		shot.visual = get_node_or_null("Visual") as CanvasItem
		if shot.phantom and shot.visual != null:
			shot.visual.modulate = Color(0.85, 0.5, 1.0, 0.85)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if is_glitch and not has_glitched:
		_glitch_timer = randf_range(0.12, 0.18)

	if can_split and not has_split and _split_distance <= 0.0:
		_split_distance = 360.0


func _draw() -> void:
	var count := _trail_points.size()
	if count < 2:
		return
	var base_color := Color(1.0, 0.88, 0.35)
	if is_glitch:
		base_color = Color(0.2, 0.95, 1.0)
	elif wall_pierce > 0 or _is_phasing_wall:
		base_color = Color(0.85, 0.45, 1.0)

	for i in range(count - 1):
		var p1 := to_local(_trail_points[i])
		var p2 := to_local(_trail_points[i + 1])
		var t := float(i + 1) / float(count)
		var col := Color(base_color.r, base_color.g, base_color.b, t * 0.65)
		var width := lerpf(1.0, 3.5, t)
		draw_line(p1, p2, col, width)


func _physics_process(delta: float) -> void:
	# 0. Protección de spawn: en cuanto la bala sale del hurtbox del dueño, deja de
	# ser inmune y puede dañarlo (fuego amigo). No se vuelve a armar si reingresa.
	if _shooter_immune:
		_shooter_immune = _is_inside_shooter_hurtbox()

	# 1. Resistencia del aire / drag aerodinámico
	if drag > 0.0:
		velocity -= velocity * (drag * delta)

	# 2. Gravedad según ángulo de disparo: tiro frontal más plano, arriba/abajo caída rápida
	var grav_scale := lerpf(0.30, 1.0, absf(_initial_dir.y))
	velocity.y += (bullet_gravity * grav_scale) * delta
	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed

	var step := velocity * delta
	var next_pos := global_position + step

	# 3. CCD (Continuous Collision Detection) para evitar traspasos del suelo/muros sin mejoras
	var space_state := get_world_2d().direct_space_state

	# Comprobar si salimos del muro durante phasing
	if _is_phasing_wall and not _phasing_bodies.is_empty():
		var point_query := PhysicsPointQueryParameters2D.new()
		point_query.position = next_pos
		point_query.collision_mask = 1 | 16
		point_query.collide_with_bodies = true
		point_query.collide_with_areas = false
		var overlaps := space_state.intersect_point(point_query, 4)
		if overlaps.is_empty():
			_phasing_bodies.clear()
			_is_phasing_wall = false

	# Raycast continuo contra el mundo (Capa 1: mundo/suelo, Capa 16: obstáculos)
	var shape_rad: float = 4.0 * maxf(scale.x, 1.0)
	var ray_end := next_pos + direction * shape_rad
	var query_body := PhysicsRayQueryParameters2D.create(global_position, ray_end)
	query_body.collision_mask = 1 | 16
	query_body.collide_with_bodies = true
	query_body.collide_with_areas = false
	var excludes: Array[RID] = [get_rid()]
	if shooter != null and shooter is CollisionObject2D:
		excludes.append((shooter as CollisionObject2D).get_rid())
	for pb in _phasing_bodies:
		if is_instance_valid(pb) and pb is CollisionObject2D:
			excludes.append((pb as CollisionObject2D).get_rid())
	query_body.exclude = excludes

	var hit_world := space_state.intersect_ray(query_body)
	if not hit_world.is_empty():
		var hit_collider: Node = hit_world.get("collider", null)
		var hit_pos: Vector2 = hit_world.get("position", next_pos)
		var hit_norm: Vector2 = hit_world.get("normal", Vector2.UP)
		if hit_norm.is_zero_approx():
			hit_norm = _get_contact_info(hit_collider).get("normal", -direction)
		_handle_body_collision(hit_collider, hit_pos, hit_norm)
		if not is_instance_valid(self) or is_queued_for_deletion():
			return
		step = velocity * delta
		next_pos = global_position + step

	# Raycast continuo contra hurtboxes (Capa 4: hurtbox)
	var query_area := PhysicsRayQueryParameters2D.create(global_position, next_pos)
	query_area.collision_mask = 4
	query_area.collide_with_areas = true
	query_area.collide_with_bodies = false
	query_area.exclude = excludes
	var hit_area := space_state.intersect_ray(query_area)
	if not hit_area.is_empty():
		var area_collider = hit_area.get("collider", null)
		if area_collider is Area2D and not (area_collider in _hit_targets):
			_on_area_entered(area_collider)
			if not is_instance_valid(self) or is_queued_for_deletion():
				return

	# Aplicar movimiento
	global_position += step
	_distance_traveled += step.length()

	if not velocity.is_zero_approx():
		direction = velocity.normalized()
		rotation = velocity.angle()

	_trail_points.append(global_position)
	if _trail_points.size() > MAX_TRAIL_POINTS:
		_trail_points.pop_front()
	queue_redraw()

	# 4. Timer de Glitch
	if is_glitch and not has_glitched:
		_glitch_timer -= delta
		if randf() < 0.35:
			modulate = Color(0.2, 1.8, 1.8, 1.0) if randf() < 0.5 else Color(1.8, 0.2, 1.6, 1.0)
		if _glitch_timer <= 0.0:
			_do_glitch()

	# 5. División en vuelo al alcanzar la distancia
	if can_split and not has_split and _split_distance > 0.0 and _distance_traveled >= _split_distance:
		_do_split()

	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


## Crea una bala hija que hereda todas las propiedades, escala, rebotes y copia profunda de efectos.
func spawn_child_bullet(
	new_dir: Vector2,
	speed_mult: float = 1.0,
	damage_mult: float = 1.0,
	allow_split: bool = false,
	allow_glitch: bool = false
) -> Node:
	if _bullet_scene_res == null:
		_bullet_scene_res = load("res://weapons/bullet.tscn")
	var child := _bullet_scene_res.instantiate()
	child.global_position = global_position
	# 1. Escala proporcional idéntica (mantiene Balas Grandes)
	child.scale = scale
	# 2. Velocidad y dirección
	var cur_speed := velocity.length() * speed_mult
	child.direction = new_dir.normalized()
	child.speed = cur_speed
	child.velocity = child.direction * cur_speed
	# 3. Daño proporcional
	child.damage = maxi(int(round(damage * damage_mult)), 1)
	# 4. Herencia de físicas y rebotes restantes (mantiene Rebote con Split)
	child.bounces = bounces
	child.bounce_count = bounce_count
	child.ricochet_bonus = ricochet_bonus
	child.wall_pierce = wall_pierce
	child.pierce = pierce
	child.bullet_gravity = bullet_gravity
	child.drag = drag
	child.max_fall_speed = max_fall_speed
	child.knockback = knockback
	child.stun_duration = stun_duration
	child.lifetime = maxf(lifetime - _time_alive, 0.8)
	# 5. Autor y efectos (copia profunda para contadores independientes)
	child.shooter = shooter
	child.player = player
	child.effects = effects.duplicate(true)
	# 6. Visual
	child.modulate = modulate
	# 7. Control granular de recursión
	child.can_split = allow_split
	child.has_split = not allow_split
	child._split_distance = _split_distance
	child.is_glitch = allow_glitch
	child.has_glitched = not allow_glitch
	# 8. Datos del disparo (el resto de campos los hereda del padre)
	child.shot = shot.copy()
	child.shot.can_split = allow_split
	child.shot.is_glitch = allow_glitch

	var target_parent := get_parent()
	if target_parent == null and is_inside_tree():
		target_parent = get_tree().current_scene
	if target_parent != null:
		target_parent.add_child(child)
	return child


func _do_split() -> void:
	if has_split or not can_split:
		return
	has_split = true

	# Reducir proporcionalmente daño y escala en padre e hijos
	scale *= 0.82
	damage = maxi(int(round(damage * 0.30)), 1)

	var angles := [deg_to_rad(-18.0), deg_to_rad(18.0)]
	for ang in angles:
		var child_dir := direction.rotated(ang)
		spawn_child_bullet(child_dir, 1.0, 1.0, false, false)

	_reproducir_sfx("disparo", 0.25)


func _do_glitch() -> void:
	if has_glitched or not is_glitch:
		return
	has_glitched = true
	is_glitch = false

	# Micro salto cuántico cibernético hacia adelante
	global_position += direction * 8.0

	var tween := create_tween()
	if tween:
		modulate = Color(0.3, 1.9, 1.8, 1.0)
		tween.tween_property(self, "modulate", Color.WHITE, 0.15)

	# Clon secundario enfocado hacia adelante (-10° a +10°)
	var clone_angle := deg_to_rad(randf_range(-10.0, 10.0))
	if absf(clone_angle) < deg_to_rad(3.0):
		clone_angle = deg_to_rad(7.0 if randf() < 0.5 else -7.0)
	var clone_dir := direction.rotated(clone_angle)

	# El clon hereda can_split para que Glitch + Split funcionen juntos!
	var clone := spawn_child_bullet(clone_dir, randf_range(0.96, 1.04), 0.70, can_split, false)
	if clone != null:
		clone.modulate = Color(1.8, 0.2, 1.5, 1.0)
		var cl_tween := clone.create_tween()
		if cl_tween:
			cl_tween.tween_property(clone, "modulate", Color.WHITE, 0.2)

	_reproducir_sfx("disparo", 0.3)


func _reproducir_sfx(nombre: String, volumen: float = 0.25) -> void:
	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_tree().root.get_node("AudioManager").call("reproducir", nombre, volumen)


func _sync_shot(pos: Vector2, normal: Vector2) -> void:
	shot.direction = direction
	shot.damage = damage
	shot.bounces = bounces
	shot.hit_position = pos
	shot.hit_normal = normal
	shot.visual = get_node_or_null("Visual") as CanvasItem


## Indica si el impacto cae en el borde de la arena: mira si el punto de golpe
## está a menos de BORDER_PROBE del perímetro del rect visible de la cámara activa.
func _is_border_hit(hit_pos: Vector2) -> bool:
	var camera := get_viewport().get_camera_2d()
	var visible_rect := get_viewport().get_visible_rect()
	if camera != null:
		var visible_size := get_viewport().get_visible_rect().size / camera.zoom
		visible_rect = Rect2(camera.get_screen_center_position() - visible_size * 0.5, visible_size)
	if not visible_rect.has_point(hit_pos):
		return true
	return (
		hit_pos.x - visible_rect.position.x < BORDER_PROBE
		or visible_rect.end.x - hit_pos.x < BORDER_PROBE
		or hit_pos.y - visible_rect.position.y < BORDER_PROBE
		or visible_rect.end.y - hit_pos.y < BORDER_PROBE
	)


## Rebote reutilizable: consume un rebote, refleja la velocidad y reposiciona.
func _bounce_off(hit_pos: Vector2, hit_norm: Vector2) -> void:
	bounces -= 1
	bounce_count += 1
	for efecto in effects:
		if efecto.has_method("on_bounce"):
			_sync_shot(hit_pos, hit_norm)
			efecto.on_bounce(shot, bounce_count, player)

	velocity = velocity.bounce(hit_norm) * 0.75
	direction = velocity.normalized()
	rotation = velocity.angle()
	var effective_radius: float = 4.0 * maxf(scale.x, 1.0)
	global_position = hit_pos + hit_norm * (effective_radius + 0.5)
	_trail_points.clear()

	if can_split and not has_split:
		_do_split.call_deferred()


func _handle_body_collision(body: Node, hit_pos: Vector2, hit_norm: Vector2) -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	# El cuerpo del dueño no está en la máscara de la bala (21 = Mundo|Hurtbox jugador|Hurtbox enemigo),
	# así que este guard no bloquea el fuego amigo; solo evita autoimpactos sobre cuerpos del shooter.
	if shooter != null and (body == shooter or shooter.is_ancestor_of(body)):
		return
	if body != null and (body in _phasing_bodies):
		return

	for efecto in effects:
		if efecto.has_method("on_body_hit"):
			_sync_shot(hit_pos, hit_norm)
			efecto.on_body_hit(shot, body, player)

	# Borde de la arena: nunca gasta Balas Fantasma; rebota o se destruye.
	if _is_border_hit(hit_pos):
		if bounces > 0:
			_bounce_off(hit_pos, hit_norm)
		else:
			global_position = hit_pos
			queue_free()
		return

	# Balas Fantasma: atravesar paredes fluidamente sin teletransportes bruscos
	if wall_pierce > 0:
		wall_pierce -= 1
		_is_phasing_wall = true
		if body != null and not (body in _phasing_bodies):
			_phasing_bodies.append(body)
		var visual := get_node_or_null("Visual") as CanvasItem
		if visual != null:
			visual.modulate = Color(0.75, 0.45, 1.0, 0.75)
		return

	# Rebote en superficies sólidas
	if bounces > 0:
		_bounce_off(hit_pos, hit_norm)
		return

	global_position = hit_pos
	queue_free()


func _get_contact_info(hit_body: Node) -> Dictionary:
	var space_state := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs != null:
		params.shape = cs.shape
		params.transform = global_transform
	params.motion = direction * 4.0
	params.collision_mask = 1 | 16
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var excludes: Array[RID] = [get_rid()]
	if shooter != null and shooter is CollisionObject2D:
		excludes.append((shooter as CollisionObject2D).get_rid())
	params.exclude = excludes

	var rest := space_state.get_rest_info(params)
	if not rest.is_empty():
		var n: Vector2 = rest.get("normal", Vector2.ZERO)
		if not n.is_zero_approx():
			return {"normal": n, "point": rest.get("point", global_position)}

	return {"normal": -direction, "point": global_position}


func _on_body_entered(body: Node) -> void:
	if not _is_phasing_wall and not (body in _phasing_bodies):
		var info := _get_contact_info(body)
		_handle_body_collision(body, info.get("point", global_position), info.get("normal", -direction))


func _on_body_exited(body: Node) -> void:
	if body in _phasing_bodies:
		_phasing_bodies.erase(body)
	if _phasing_bodies.is_empty():
		_is_phasing_wall = false


func parry(new_shooter: Node) -> void:
	shooter = new_shooter
	player = new_shooter
	velocity = -velocity
	direction = velocity.normalized()
	rotation = velocity.angle()
	global_position += direction * 8.0
	_time_alive = 0.0
	_hit_targets.clear()
	_trail_points.clear()
	_phasing_bodies.clear()
	_is_phasing_wall = false
	# El nuevo dueño también queda protegido hasta que la bala salga de su hurtbox.
	_shooter_immune = true
	var visual := get_node_or_null("Visual") as CanvasItem
	if visual != null:
		visual.modulate = Color(1.5, 1.5, 1.5, 1.0)


## Indica si la bala sigue solapando el hurtbox del dueño actual.
func _is_inside_shooter_hurtbox() -> bool:
	if shooter == null or not is_instance_valid(shooter):
		return false
	for area in get_overlapping_areas():
		if area == shooter or shooter.is_ancestor_of(area):
			return true
	return false


func _on_area_entered(area: Area2D) -> void:
	if area in _hit_targets:
		return
	if _shooter_immune and shooter != null and (area == shooter or shooter.is_ancestor_of(area)):
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

	var hit_damage := damage
	if ricochet_bonus > 0.0 and bounce_count > 0:
		hit_damage = int(round(damage * (1.0 + ricochet_bonus * bounce_count)))
	damage = hit_damage

	for efecto in effects:
		_sync_shot(global_position, -direction)
		efecto.on_hit(shot, area, player)

	area.take_hit(hit_damage, player)
	if knockback > 0.0 and dueno != null and dueno.has_method("apply_knockback"):
		dueno.apply_knockback(direction, knockback)
	if stun_duration > 0.0 and dueno != null and dueno.has_method("stun"):
		dueno.stun(stun_duration)

	if pierce > 0:
		pierce -= 1
	else:
		queue_free()

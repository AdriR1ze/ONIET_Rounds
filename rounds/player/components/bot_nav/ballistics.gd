class_name Ballistics
extends RefCounted

## Pure static projectile math in Godot's y-down coordinates.
## Gravity is positive downward: accel = (0, +gravity).
## No nodes, no state; callers pass the physics space they want to trace against.

const STEP: float = 1.0 / 120.0


## Returns the launch angle (radians) that makes the projectile pass through
## `to` when fired from `from` at `speed` under `gravity`, or NAN if unreachable.
## `high_arc = true` selects the lofted solution.
static func solve_launch_angle(from: Vector2, to: Vector2, speed: float, gravity: float, high_arc: bool = false) -> float:
	if speed <= 0.0 or gravity <= 0.0:
		return NAN
	var d := to - from
	var dx := absf(d.x)
	var dy := d.y  # dy > 0 => target below, dy < 0 => target above
	if dx < 1.0:
		if dy < 0.0:
			if absf(dy) > speed * speed / (2.0 * gravity):
				return NAN
			return -PI / 2.0
		return PI / 2.0
	# Solve A*u^2 + dx*u + (A - dy) = 0, where A = g*dx^2/(2*v^2) and u = tan(theta).
	# The root closer to 0 is the flat arc; the other is the lofted one.
	var a := gravity * dx * dx / (2.0 * speed * speed)
	var disc := dx * dx - 4.0 * a * (a - dy)
	if disc < 0.0:
		return NAN
	var r := sqrt(disc)
	var u := (-dx - r) / (2.0 * a) if high_arc else (-dx + r) / (2.0 * a)
	var theta := atan(u)
	return theta if d.x >= 0.0 else PI - theta


## Steps the projectile from `from` with velocity dir.normalized()*speed under
## gravity and raycasts each step against `mask`. Returns
## {"hit": bool, "position": Vector2, "collider": Object|null}.
static func trace_arc(space: PhysicsDirectSpaceState2D, from: Vector2, dir: Vector2, speed: float, gravity: float, duration: float, mask: int, exclude: Array) -> Dictionary:
	var steps := ceili(duration / STEP)
	var pos := from
	var vel := dir.normalized() * speed
	for i in steps:
		vel.y += gravity * STEP
		var new_pos := pos + vel * STEP
		var query := PhysicsRayQueryParameters2D.create(pos, new_pos, mask, exclude)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return {"hit": true, "position": hit.position, "collider": hit.collider}
		pos = new_pos
	return {"hit": false, "position": pos, "collider": null}


## Decides whether a shot from `from` to `to` is feasible: solvable angle, within
## `lifetime`, and with a clear arc. Returns
## {"feasible": bool, "reason": String, "angle": float}.
static func can_hit(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, speed: float, gravity: float, lifetime: float, mask: int, exclude: Array, target_radius: float = 12.0) -> Dictionary:
	if speed <= 0.0 or gravity <= 0.0:
		return {"feasible": false, "reason": "invalid", "angle": NAN}
	var angle := solve_launch_angle(from, to, speed, gravity)
	if is_nan(angle):
		return {"feasible": false, "reason": "out_of_range", "angle": angle}
	var dir := Vector2(cos(angle), sin(angle))
	var d := to - from
	var t := absf(d.x) / (speed * maxf(absf(dir.x), 0.0001)) if absf(dir.x) > 0.01 else absf(d.y) / maxf(speed, 0.0001)
	if t > lifetime:
		return {"feasible": false, "reason": "out_of_range", "angle": angle}
	var res := trace_arc(space, from, dir, speed, gravity, t, mask, exclude)
	if res.hit:
		return {"feasible": false, "reason": "blocked", "angle": angle}
	return {"feasible": true, "reason": "ok", "angle": angle}

extends Node

## Tests for Ballistics: angle solver and arc feasibility against a live physics world.

func _ready() -> void:
	print("--- TEST DE BALÍSTICA DEL BOT ---")
	_test_solve_level()
	_test_solve_out_of_range()
	_test_solve_below_and_above()
	_test_arc_consistency()
	await _test_can_hit_open_path()
	await _test_can_hit_blocked()
	for child in get_children():
		child.free()
	print("--- TODOS LOS TESTS DE BALÍSTICA PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func _test_solve_level() -> void:
	var angle := Ballistics.solve_launch_angle(Vector2.ZERO, Vector2(300, 0), 1050.0, 1000.0)
	assert(not is_nan(angle), "El objetivo a la misma altura debe tener solución")
	assert(angle < 0.0 and angle > -0.4, "El ángulo debe ser negativo y chico (apunta apenas arriba), actual: %f" % angle)
	print("✓ Ángulo para objetivo a 300 px: %f rad" % angle)


func _test_solve_out_of_range() -> void:
	var angle := Ballistics.solve_launch_angle(Vector2.ZERO, Vector2(5000, 0), 100.0, 1000.0)
	assert(is_nan(angle), "Un objetivo a 5000 px con velocidad 100 no debe tener solución")
	print("✓ Objetivo fuera de rango: sin solución (NAN)")


func _test_solve_below_and_above() -> void:
	var below := Ballistics.solve_launch_angle(Vector2.ZERO, Vector2(300, 120), 1050.0, 1000.0)
	assert(not is_nan(below) and below > 0.0, "Objetivo debajo debe dar ángulo positivo (hacia abajo), actual: %f" % below)
	var above := Ballistics.solve_launch_angle(Vector2.ZERO, Vector2(300, -120), 1050.0, 1000.0)
	assert(not is_nan(above) and above < 0.0, "Objetivo arriba debe dar ángulo negativo (hacia arriba), actual: %f" % above)
	assert(absf(above) > absf(below), "El ángulo hacia arriba debe ser más pronunciado que hacia abajo, arriba: %f / abajo: %f" % [above, below])
	print("✓ Debajo: %f rad (positivo) / Arriba: %f rad (negativo, más pronunciado)" % [below, above])


func _test_arc_consistency() -> void:
	# Integra la trayectoria con el MISMO modelo que trace_arc (dt=1/120, vel.y += g*dt)
	# y verifica que el ángulo resuelto pasa por el objetivo a dx=300.
	var speed := 1050.0
	var gravity := 1000.0
	var target_x := 300.0
	var angle := Ballistics.solve_launch_angle(Vector2.ZERO, Vector2(target_x, 0), speed, gravity)
	assert(not is_nan(angle), "El arco de consistencia necesita una solución válida")

	var dt := 1.0 / 120.0
	var pos := Vector2.ZERO
	var vel := Vector2(cos(angle), sin(angle)) * speed
	var y_at_target := 0.0
	var found := false
	for i in 1000:
		vel.y += gravity * dt
		var new_pos := pos + vel * dt
		if not found and new_pos.x >= target_x:
			var span := new_pos.x - pos.x
			var t := 0.0 if span == 0.0 else (target_x - pos.x) / span
			y_at_target = lerpf(pos.y, new_pos.y, t)
			found = true
			break
		pos = new_pos
	assert(found, "La trayectoria debe alcanzar x=300")
	assert(absf(y_at_target) <= 8.0, "El arco debe caer dentro de ±8 px de y=0, actual: %.2f" % y_at_target)
	print("✓ Coherencia solver/tracer: y a dx=300 = %.3f px (objetivo 0 ± 8)" % y_at_target)


func _test_can_hit_open_path() -> void:
	_add_floor()
	await get_tree().physics_frame
	await get_tree().physics_frame

	var space := get_viewport().world_2d.direct_space_state
	var res := Ballistics.can_hit(space, Vector2(0, 0), Vector2(300, 0), 1050.0, 1000.0, 1.5, 1, [])
	assert(res["feasible"] == true, "Con camino libre el disparo debe ser factible, motivo: %s" % res["reason"])
	print("✓ Camino libre: factible (reason=%s)" % res["reason"])


func _test_can_hit_blocked() -> void:
	_add_wall()
	await get_tree().physics_frame
	await get_tree().physics_frame

	var space := get_viewport().world_2d.direct_space_state
	var res := Ballistics.can_hit(space, Vector2(0, 0), Vector2(300, 0), 1050.0, 1000.0, 1.5, 1, [])
	assert(res["feasible"] == false, "Una pared en el medio debe bloquear el disparo")
	assert(res["reason"] == "blocked", "El motivo debe ser 'blocked', actual: %s" % res["reason"])
	print("✓ Pared en el medio: bloqueado (reason=%s)" % res["reason"])


func _add_floor() -> void:
	var body := StaticBody2D.new()
	body.name = "TestFloor"
	body.collision_layer = 1
	body.position = Vector2(500, 200)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4000, 40)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _add_wall() -> void:
	var body := StaticBody2D.new()
	body.name = "TestWall"
	body.collision_layer = 1
	body.position = Vector2(150, 0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 800)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

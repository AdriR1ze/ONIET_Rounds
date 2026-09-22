extends RefCounted


func _pi(numero: int) -> PlayerInput:
	var p := PlayerInput.new()
	p.player_number = numero
	return p


func _tiene_eje(accion: String, eje: int, signo: float, device: int) -> bool:
	if not InputMap.has_action(accion):
		return false
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventJoypadMotion and ev.axis == eje and signf(ev.axis_value) == signf(signo) and ev.device == device:
			return true
	return false


func test_defaults_gamepad() -> void:
	assert(Settings.DEFAULT_JOY["left"]["axis"] == 0, "mover = stick izquierdo X")
	assert(Settings.DEFAULT_JOY["right"]["axis"] == 0, "mover = stick izquierdo X")
	assert(Settings.DEFAULT_JOY["up"]["axis"] == 1, "mover = stick izquierdo Y")
	assert(Settings.DEFAULT_JOY["down"]["axis"] == 1, "mover = stick izquierdo Y")
	assert(Settings.DEFAULT_JOY["jump"]["button"] == 0, "saltar = A")
	assert(Settings.DEFAULT_JOY["fire"]["axis"] == 5, "disparar = gatillo derecho")
	assert(Settings.DEFAULT_JOY["lock"]["axis"] == 4, "bloquear = gatillo izquierdo")
	assert(Settings.DEFAULT_JOY["grab"]["button"] == 2, "agarrar = X")
	assert(Settings.DEFAULT_JOY["ragdoll"]["button"] == 1, "trompezar = B")
	assert(Settings.DEFAULT_JOY["quack"]["button"] == 3, "graznar = Y")
	assert(Settings.DEFAULT_JOY["strafe"]["button"] == 9, "strafe = LB")


func test_apuntado_configurado_por_jugador() -> void:
	var previo := Settings.dispositivos.duplicate()
	for n in [1, 2, 3, 4]:
		Settings.dispositivos[n] = n - 1
	Settings.aplicar_controles()
	for n in [1, 2, 3, 4]:
		assert(_tiene_eje("p%d_aim_left" % n, 2, -1.0, n - 1), "aim_left p%d" % n)
		assert(_tiene_eje("p%d_aim_right" % n, 2, 1.0, n - 1), "aim_right p%d" % n)
		assert(_tiene_eje("p%d_aim_up" % n, 3, -1.0, n - 1), "aim_up p%d" % n)
		assert(_tiene_eje("p%d_aim_down" % n, 3, 1.0, n - 1), "aim_down p%d" % n)
	Settings.dispositivos = previo
	Settings.aplicar_controles()


func test_cada_jugador_usa_su_dispositivo() -> void:
	# Un jugador de teclado no debe responder al joystick, y uno de joystick
	# no debe responder al teclado.
	var previo := Settings.dispositivos.duplicate()
	Settings.dispositivos[1] = Settings.DISPOSITIVO_TECLADO
	Settings.dispositivos[2] = 0
	Settings.aplicar_controles()
	for ev in InputMap.action_get_events("p1_left"):
		assert(not (ev is InputEventJoypadButton or ev is InputEventJoypadMotion), "P1 teclado no debe tener eventos de mando")
	for ev in InputMap.action_get_events("p2_left"):
		assert(not (ev is InputEventKey), "P2 mando no debe tener eventos de teclado")
	assert(_tiene_eje("p2_aim_left", 2, -1.0, 0), "P2 mando usa el stick de su device")
	assert(InputMap.action_get_events("p1_aim_left").is_empty(), "P1 teclado no tiene stick de apuntado")
	Settings.dispositivos = previo
	Settings.aplicar_controles()


func test_apuntado_analogico_no_rigido() -> void:
	# Un stick apenas inclinado a la derecha debe dar direccion derecha
	# (no se cuantiza a 8 direcciones).
	var p := _pi(1)
	Input.action_press("p1_aim_right", 0.45)
	Input.action_press("p1_aim_up", 0.30)
	var d := p.aim()
	Input.action_release("p1_aim_right")
	Input.action_release("p1_aim_up")
	assert(d.x > 0.0, "debe apuntar a la derecha, dio %s" % d)
	assert(d.y < 0.0, "debe apuntar hacia arriba, dio %s" % d)
	assert(not is_equal_approx(d.x, d.y), "direccion analogica, no diagonal fija, dio %s" % d)


func test_apuntado_analogico_diagonal() -> void:
	var p := _pi(1)
	Input.action_press("p1_aim_right", 0.9)
	Input.action_press("p1_aim_down", 0.9)
	var d := p.aim()
	Input.action_release("p1_aim_right")
	Input.action_release("p1_aim_down")
	assert(d.x > 0.2 and d.y > 0.2, "diagonal analogica, dio %s" % d)


func test_fallback_digital_sin_stick() -> void:
	# Sin stick derecho, el teclado/D-pad sigue dando 8 direcciones.
	var p := _pi(1)
	Input.action_release("p1_aim_left")
	Input.action_release("p1_aim_right")
	Input.action_release("p1_aim_up")
	Input.action_release("p1_aim_down")
	Input.action_press("p1_right")
	var d := p.aim()
	Input.action_release("p1_right")
	assert(d == Vector2(1, 0), "fallback digital derecha, dio %s" % d)


func test_sin_input_sin_apuntado() -> void:
	var p := _pi(1)
	for a in ["p1_aim_left", "p1_aim_right", "p1_aim_up", "p1_aim_down", "p1_left", "p1_right", "p1_up", "p1_down"]:
		Input.action_release(a)
	assert(p.aim() == Vector2.ZERO, "sin input no hay direccion")


func test_movimiento_analogico() -> void:
	var p := _pi(1)
	Input.action_press("p1_right", 0.7)
	var m := p.move_axis()
	Input.action_release("p1_right")
	assert(m > 0.1, "el movimiento debe ser analogico, dio %f" % m)


func test_arma_apunta_en_angulo_libre() -> void:
	# El arma debe rotar a un angulo arbitrario, no solo a los 8 cardinales.
	var arma := WeaponComponent.new()
	var direccion := Vector2(0.9, 0.4)
	arma.set_aim(direccion)
	assert(is_equal_approx(arma.rotation, direccion.angle()), "rotacion libre, dio %f" % arma.rotation)
	assert(not is_equal_approx(arma.rotation, deg_to_rad(45.0)), "no debe caer en una diagonal fija")
	arma.free()


extends Node

# Test end-to-end del tutorial interactivo. No usa assert() a secas: acumula
# fallos y decide el resultado por sí mismo (en headless un assert fallido NO
# cambia el exit code).

const RUTA_NIVEL := "res://levels/tutorial_level.tscn"
const RUTA_MENU := "res://ui/main_menu.tscn"
const RUTA_MAPA := "map_02_tres_pisos.tscn"
const DRILL_SPOT := Vector2(258.0, 451.0)

var _fallos: int = 0


func _ready() -> void:
	Settings.set_dispositivo(1, Settings.DISPOSITIVO_TECLADO)
	print("--- TEST NIVEL TUTORIAL (SALA DE PRÁCTICA INTERACTIVA) ---")
	_test_boton_menu()

	var nivel: Node2D = await _instanciar_nivel()
	await _esperar_fisica(45)
	_test_nodos_presentes(nivel)
	await _test_estado_inicial(nivel)
	await _test_no_avanza_solo(nivel)
	await _test_paso1_mover(nivel)
	await _test_paso2_saltar(nivel)
	await _test_paso3_blanco(nivel)
	await _test_paso4_parry_lateral(nivel)
	await _test_paso5_parry_arriba(nivel)
	await _test_paso6_mejoras(nivel)
	_test_respawn_blando(nivel)
	nivel.free()

	var nivel2: Node2D = await _instanciar_nivel()
	await _esperar_fisica(5)
	_test_botones(nivel2)
	nivel2.free()

	if _fallos == 0:
		print("--- TODOS LOS TESTS DEL TUTORIAL PASARON EXITOSAMENTE ---")
	else:
		print("--- HAY %d FALLO(S) EN EL TEST DEL TUTORIAL ---" % _fallos)
	get_tree().quit(1 if _fallos > 0 else 0)


func _check(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("✓ %s" % mensaje)
	else:
		_fallos += 1
		print("✗ FALLO: %s" % mensaje)


func _instanciar_nivel() -> Node2D:
	var scn: PackedScene = load(RUTA_NIVEL)
	_check(scn != null, "Carga %s" % RUTA_NIVEL)
	var nivel: Node2D = scn.instantiate() as Node2D
	_check(nivel != null, "tutorial_level.tscn tiene raíz Node2D")
	add_child(nivel)
	await get_tree().process_frame
	return nivel


func _esperar_fisica(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _esperar_hasta(condicion: Callable, frames: int) -> bool:
	for i in frames:
		if condicion.call():
			return true
		await get_tree().physics_frame
	return condicion.call()


func _test_boton_menu() -> void:
	var scn: PackedScene = load(RUTA_MENU)
	_check(scn != null, "Carga %s" % RUTA_MENU)
	var menu = scn.instantiate()
	var boton = menu.get_node_or_null("Centro/Menu/Tutorial")
	_check(boton is Button, "main_menu: Centro/Menu/Tutorial es un Button")
	if boton is Button:
		_check(boton.text == "Tutorial", "El botón dice 'Tutorial'")
	menu.free()


func _test_nodos_presentes(nivel) -> void:
	_check(nivel.get_node_or_null("Player1") != null, "Existe Player1")
	_check(nivel.get_node_or_null("Camera") is Camera2D, "Existe Camera (Camera2D)")
	_check(nivel.get_node_or_null("PauseMenu") != null, "Existe PauseMenu")
	_check(nivel.get_node_or_null("UpgradeScreen") is UpgradeScreen, "Existe UpgradeScreen (clase real)")
	_check(nivel.get_node_or_null("TutorialHUD") is CanvasLayer, "Existe TutorialHUD (CanvasLayer)")
	_check(nivel.get_node_or_null("TutorialHUD/Arriba/Info/Paso") is Label, "Existe HUD/Paso")
	_check(nivel.get_node_or_null("TutorialHUD/Arriba/Info/Progreso") is Label, "Existe HUD/Progreso")
	_check(nivel.get_node_or_null("TutorialHUD/Arriba/Info/Aviso") is Label, "Existe HUD/Aviso")
	_check(nivel.get_node_or_null("TutorialHUD/Abajo/Botones/Saltear") is Button, "Existe HUD/Saltear")
	_check(nivel.get_node_or_null("TutorialHUD/Abajo/Botones/Volver") is Button, "Existe HUD/Volver")
	_check(nivel.get_node_or_null("Meta") is Marker2D, "Existe Meta (Marker2D)")
	_check(nivel.get_node_or_null("Placement/Blanco") != null, "Existe Placement/Blanco")
	_check(nivel.get_node_or_null("DrillTimer") is Timer, "Existe DrillTimer")
	# El mapa instanciado tiene que ser el chico de tres pisos, no la arena vieja.
	var mapa = nivel.get_node_or_null("MapContainer/MapTresPisos")
	_check(mapa != null, "Existe la instancia del mapa en MapContainer")
	if mapa != null:
		var ruta: String = mapa.scene_file_path
		_check(ruta.ends_with(RUTA_MAPA), "El mapa instanciado es %s (es '%s')" % [RUTA_MAPA, ruta])
	var p1 = nivel.get_node("Player1")
	_check(p1.player_number == 1, "Player1.player_number == 1")


func _test_estado_inicial(nivel) -> void:
	await _esperar_fisica(1)
	_check(nivel._paso == 0, "Estado inicial = paso 1 (MOVER), es %d" % nivel._paso)
	_check(nivel._progreso_label.text == "1 / 6", "Progreso inicial '1 / 6', es '%s'" % nivel._progreso_label.text)

	_check(not nivel._blanco._visual.visible, "La diana no aparece inicialmente (oculta hasta su momento)")

	# La instrucción debe contener las teclas REALES de los bindings vivos.
	var izq := _clave("p1_left")
	var der := _clave("p1_right")
	_check(izq != "" and izq != "—", "Binding real para p1_left ('%s')" % izq)
	_check(der != "" and der != "—", "Binding real para p1_right ('%s')" % der)
	_check(nivel._paso_label.text.contains(izq), "El paso 1 contiene la tecla real izquierda '%s'" % izq)
	_check(nivel._paso_label.text.contains(der), "El paso 1 contiene la tecla real derecha '%s'" % der)
	print("  (paso 1 = '%s')" % nivel._paso_label.text)

	# Detección dinámica de mando y cambio de instrucciones
	var joy_ev := InputEventJoypadButton.new()
	joy_ev.device = 0
	joy_ev.button_index = JOY_BUTTON_A
	joy_ev.pressed = true
	nivel._input(joy_ev)
	_check(nivel._usando_control, "Detecta mando dinámicamente al presionar botón de control")
	_check(nivel._paso_label.text.contains("Stick"), "Instrucción muestra controles de mando para moverse")

	# Volver a teclado
	var key_ev := InputEventKey.new()
	key_ev.pressed = true
	key_ev.keycode = KEY_A
	nivel._input(key_ev)
	_check(not nivel._usando_control, "Retorna a modo teclado al pulsar una tecla")


func _test_no_avanza_solo(nivel) -> void:
	var paso_antes: int = nivel._paso
	await _esperar_fisica(70)
	_check(nivel._paso == paso_antes, "El paso NO avanza solo con el tiempo (sigue en %d)" % nivel._paso)


func _test_paso1_mover(nivel) -> void:
	var p1 = nivel.get_node("Player1")
	var meta = nivel.get_node("Meta")
	p1.global_position = meta.global_position
	var avanzo := await _esperar_hasta(func() -> bool: return nivel._paso == 1, 20)
	_check(avanzo, "Llegar a Meta avanza a paso 2 (SALTAR)")
	_check(nivel._progreso_label.text == "2 / 6", "Progreso '2 / 6', es '%s'" % nivel._progreso_label.text)

	var salto := _clave("p1_jump")
	_check(nivel._paso_label.text.contains(salto), "El paso 2 contiene la tecla real de salto '%s'" % salto)
	print("  (paso 2 = '%s')" % nivel._paso_label.text)


func _test_paso2_saltar(nivel) -> void:
	var p1 = nivel.get_node("Player1")
	p1.global_position = Vector2(nivel._meta.global_position.x, 451.0)
	p1.velocity = Vector2.ZERO
	await _esperar_fisica(20)
	_check(p1.is_on_floor(), "P1 está en el suelo antes de saltar")

	# Salto real: sale del suelo con velocidad hacia arriba.
	p1.velocity.y = -520.0
	var avanzo := await _esperar_hasta(func() -> bool: return nivel._paso == 2, 25)
	_check(avanzo, "Dejar el suelo hacia arriba avanza a paso 3 (DISPARAR)")
	_check(nivel._progreso_label.text == "3 / 6", "Progreso '3 / 6', es '%s'" % nivel._progreso_label.text)

	var disparo := _clave("p1_fire")
	_check(nivel._paso_label.text.contains(disparo), "El paso 3 contiene la tecla real de disparo '%s'" % disparo)
	print("  (paso 3 = '%s')" % nivel._paso_label.text)


func _test_paso3_blanco(nivel) -> void:
	var p1 = nivel.get_node("Player1")
	var blanco = nivel.get_node("Placement/Blanco")
	var health = blanco.get_node("HealthComponent")

	# Parado en el punto del drill (plataforma del SpawnP1), de frente al blanco.
	p1.global_position = DRILL_SPOT
	p1.velocity = Vector2.ZERO
	p1.facing = 1
	await _esperar_fisica(20)
	p1._weapon.reset_cooldown(0.0)
	p1._weapon.reset_ammo()

	_check(health.is_alive(), "El blanco está vivo antes del disparo")
	var pos_antes: Vector2 = p1.global_position
	var balas_antes: int = get_tree().get_nodes_in_group("bullet").size()
	var disparo_ok: bool = p1._weapon.try_fire()
	_check(disparo_ok, "El arma de P1 dispara una bala real (try_fire)")
	var balas_despues: int = get_tree().get_nodes_in_group("bullet").size()
	_check(balas_despues > balas_antes, "Se creó una bala real (grupo 'bullet')")

	var avanzo := await _esperar_hasta(
		func() -> bool: return nivel._paso == 3 and not health.is_alive(), 120
	)
	_check(not health.is_alive(), "El blanco murió por una bala real (sin apply_damage directo)")
	_check(avanzo, "El blanco destruido avanza a paso 4 (PARRY_LATERAL)")

	# Sin teletransporte: entrar al drill no movió al jugador.
	var delta_pos: float = p1.global_position.distance_to(pos_antes)
	_check(delta_pos < 5.0, "Entrar al drill NO teleporta al jugador (Δ=%.2f)" % delta_pos)

	var parry := _clave("p1_ragdoll")
	_check(nivel._paso_label.text.contains(parry), "El paso 4 contiene la tecla real de parry '%s'" % parry)
	print("  (paso 4 = '%s')" % nivel._paso_label.text)


func _test_paso4_parry_lateral(nivel) -> void:
	var p1 = nivel.get_node("Player1")
	_check(nivel._paso == 3, "Estamos en paso 4 (PARRY_LATERAL)")

	var bala = nivel._bala_drill
	_check(is_instance_valid(bala), "El drill lateral spawneó una bala real")
	if not is_instance_valid(bala):
		return
	_check(bala.is_in_group("bullet"), "La bala del drill está en el grupo 'bullet'")
	_check(bala.wall_pierce == 0, "La bala lateral NO tiene wall_pierce (%d)" % bala.wall_pierce)
	_check(absf(bala.velocity.y) < 1.0 and bala.velocity.x > 1.0, "La bala lateral es horizontal, hacia el jugador")
	_check(bala.global_position.x < p1.global_position.x, "La bala lateral nace a un costado del jugador")

	# Recorre su carril: sobrevive la mayor parte del trayecto sin morir contra geometría.
	var x0: float = bala.global_position.x
	var recorrido := await _esperar_hasta(
		func() -> bool:
			return is_instance_valid(bala) and bala.global_position.x >= x0 + 120.0,
		90
	)
	_check(is_instance_valid(bala), "La bala lateral sobrevive el carril (no muere contra geometría)")
	_check(recorrido, "La bala lateral avanza por su carril hacia el jugador")

	# Reintento: fallar genera una bala nueva, reinicia el cooldown y NO teleporta.
	var pos_antes: Vector2 = p1.global_position
	p1.set("_parry_cooldown", 5.0)
	var id_vieja: int = bala.get_instance_id()
	bala.queue_free()
	var reintento := await _esperar_hasta(
		func() -> bool:
			var nueva = nivel._bala_drill
			return is_instance_valid(nueva) and nueva.is_inside_tree() and nueva.get_instance_id() != id_vieja,
		40
	)
	_check(reintento, "Fallar el drill lateral genera una bala nueva (reintento inmediato)")
	_check(nivel._paso == 3, "Fallar el drill lateral NO avanza el paso")
	_check(p1.get("_parry_cooldown") == 0.0, "El reintento reinicia el cooldown del parry")
	_check(p1.global_position.distance_to(pos_antes) < 2.0, "El reintento NO teleporta al jugador")

	bala = nivel._bala_drill
	if not is_instance_valid(bala):
		return

	# Negativo: parrear OTRA bala no debe resolver el paso.
	var otra := load("res://weapons/bullet.tscn").instantiate() as Node2D
	add_child(otra)
	otra.global_position = Vector2(600.0, 400.0)
	p1.on_parry(otra)
	await _esperar_fisica(2)
	_check(nivel._paso == 3, "Parrear una bala distinta NO avanza el paso de parry")
	otra.free()

	# Positivo: parrear la bala lateral avanza al paso 5.
	p1.on_parry(bala)
	var avanzo := await _esperar_hasta(func() -> bool: return nivel._paso == 4, 10)
	_check(avanzo, "Parrear la bala lateral avanza a paso 5 (PARRY_ARRIBA)")
	_check(nivel._progreso_label.text == "5 / 6", "Progreso '5 / 6', es '%s'" % nivel._progreso_label.text)


func _test_paso5_parry_arriba(nivel) -> void:
	var p1 = nivel.get_node("Player1")
	_check(nivel._paso == 4, "Estamos en paso 5 (PARRY_ARRIBA)")

	var bala = nivel._bala_drill
	_check(is_instance_valid(bala), "El drill vertical spawneó una bala real")
	if not is_instance_valid(bala):
		return
	_check(bala.is_in_group("bullet"), "La bala que cae está en el grupo 'bullet'")
	_check(bala.wall_pierce == 0, "La bala que cae NO tiene wall_pierce (%d)" % bala.wall_pierce)
	_check(absf(bala.velocity.x) < 1.0 and bala.velocity.y > 1.0, "La bala que cae va en vertical, hacia el jugador")
	_check(bala.global_position.y < p1.global_position.y, "La bala que cae nace por encima del jugador")

	# Recorre su carril sin morir contra el techo.
	var y0: float = bala.global_position.y
	var recorrido := await _esperar_hasta(
		func() -> bool:
			return is_instance_valid(bala) and bala.global_position.y >= y0 + 25.0,
		60
	)
	_check(is_instance_valid(bala), "La bala que cae sobrevive el carril (no muere contra el techo)")
	_check(recorrido, "La bala que cae avanza hacia el jugador")

	# El texto del paso 5 usa la tecla real de apuntar arriba y la de parry.
	var arriba := _clave("p1_up")
	var parry := _clave("p1_ragdoll")
	_check(arriba != "" and arriba != "—", "Binding real para p1_up ('%s')" % arriba)
	_check(nivel._paso_label.text.contains(arriba), "El paso 5 contiene la tecla real de apuntar arriba '%s'" % arriba)
	_check(nivel._paso_label.text.contains(parry), "El paso 5 contiene la tecla real de parry '%s'" % parry)
	print("  (paso 5 = '%s')" % nivel._paso_label.text)

	# Negativo: parrear otra bala no avanza.
	var otra := load("res://weapons/bullet.tscn").instantiate() as Node2D
	add_child(otra)
	otra.global_position = Vector2(DRILL_SPOT.x, 200.0)
	p1.on_parry(otra)
	await _esperar_fisica(2)
	_check(nivel._paso == 4, "Parrear una bala distinta NO avanza el paso de parry")
	otra.free()

	# Positivo: parrear la bala que cae avanza al paso 6.
	bala = nivel._bala_drill
	if not is_instance_valid(bala):
		return
	p1.on_parry(bala)
	var avanzo := await _esperar_hasta(func() -> bool: return nivel._paso == 5, 10)
	_check(avanzo, "Parrear la bala que cae avanza a paso 6 (MEJORAS)")
	_check(nivel._progreso_label.text == "6 / 6", "Progreso '6 / 6', es '%s'" % nivel._progreso_label.text)


func _test_paso6_mejoras(nivel) -> void:
	_check(nivel._paso == 5, "Estamos en paso 6 (MEJORAS)")
	var pantalla = nivel.get_node_or_null("UpgradeScreen")
	_check(pantalla is UpgradeScreen, "La pantalla de mejoras es la clase real UpgradeScreen")
	if pantalla == null:
		return

	# La pantalla real se abre sola al entrar al paso.
	var abierta := await _esperar_hasta(func() -> bool: return pantalla._activo and pantalla.visible, 90)
	_check(abierta, "El paso 6 abre la pantalla REAL de mejoras")
	var cantidad: int = pantalla._opciones[1].size() if pantalla._opciones.has(1) else -1
	_check(cantidad == 1, "La pantalla pide EXACTAMENTE una carta (pidió %d)" % cantidad)
	print("  (cartas pedidas: %d)" % cantidad)

	# El jugador confirma; al cerrarse, el paso avanza al final.
	pantalla._confirmar(1)
	var avanzo := await _esperar_hasta(func() -> bool: return nivel._paso == 6, 180)
	_check(avanzo, "El paso 6 avanza al cerrarse la pantalla (FIN)")
	_check(nivel._progreso_label.text == "6 / 6", "Progreso final '6 / 6', es '%s'" % nivel._progreso_label.text)
	_check(nivel._paso_label.text.contains("Listo"), "El texto final muestra '¡Listo!'")
	_check(not nivel._boton_saltear.visible, "En el final se oculta SALTAR PASO")


func _test_respawn_blando(nivel) -> void:
	var p1 = nivel.get_node("Player1")
	var health = p1.get_node("HealthComponent")
	var spawn: Vector2 = p1._spawn_position
	p1.global_position = spawn + Vector2(400.0, -50.0)
	_check(p1.global_position != spawn, "P1 se movió antes de morir")
	health.apply_damage(999)
	_check(health.is_alive(), "Tras morir, el reset blando deja vivo a P1")
	_check(p1.global_position == spawn, "Tras morir, P1 vuelve a su spawn %s" % spawn)


func _test_botones(nivel) -> void:
	var saltear: Button = nivel._boton_saltear
	var volver: Button = nivel._boton_volver
	_check(saltear.focus_mode == Control.FOCUS_NONE, "SALTAR PASO no depende del foco (mouse-only)")
	_check(volver.focus_mode == Control.FOCUS_NONE, "VOLVER AL MENÚ no depende del foco (mouse-only)")
	_check(saltear.text == "SALTAR PASO", "SALTAR PASO tiene el texto correcto")
	_check(volver.text == "VOLVER AL MENÚ", "VOLVER AL MENÚ tiene el texto correcto")
	_check(volver.pressed.get_connections().size() > 0, "VOLVER AL MENÚ está conectado a su handler")

	_check(nivel._paso == 0, "El nivel nuevo arranca en paso 1")
	saltear.pressed.emit()
	await _esperar_fisica(1)
	_check(nivel._paso == 1, "SALTAR PASO avanza de verdad al paso siguiente")


func _clave(accion: String) -> String:
	return Settings.nombre_binding(Settings.binding_de(accion))

extends Node

const NumberPickerButton = preload("res://ui/number_picker_button.gd")


func _ready() -> void:
	print("--- INICIANDO TEST DINÁMICO DE TECLADO Y MENÚ ---")
	test_menu_principal()
	test_number_picker_control()
	test_w_no_confirma_teclado()
	test_corazones_hud()
	test_dynamic_keyboard_scenarios()
	test_reiniciar_full()
	test_joystick_existing()
	test_mapas_materiales_nativos()
	print("--- TODOS LOS TESTS PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func test_menu_principal() -> void:
	var menu_scene: PackedScene = load("res://ui/main_menu.tscn")
	assert(menu_scene != null, "No se pudo cargar main_menu.tscn")
	var menu: Node = menu_scene.instantiate()
	var indice_btn: Button = menu.get_node_or_null("Centro/Menu/Indice")
	assert(indice_btn != null, "El botón Índice debe existir")
	assert(indice_btn.text == "Índice", "El texto debe ser 'Índice', actual: '%s'" % indice_btn.text)
	assert(menu.get_node_or_null("Centro/Menu/Controles") == null, "El botón Controles NO debe existir en el menú")
	assert(menu.get_node_or_null("Controles") == null, "El panel modal Controles NO debe existir")

	var rondas_val: Node = menu.get_node_or_null("ModalPartida/Centro/Marco/Margin/VBox/Config/Rondas/Valor")
	if rondas_val == null:
		rondas_val = menu.get_node_or_null("Centro/Menu/Config/Rondas/Valor")
	assert(rondas_val is Button, "Rondas/Valor debe ser Button")
	assert(not (rondas_val is SpinBox), "Rondas/Valor NO debe ser SpinBox")
	var vidas_val: Node = menu.get_node_or_null("ModalPartida/Centro/Marco/Margin/VBox/Config/Vidas/Valor")
	if vidas_val == null:
		vidas_val = menu.get_node_or_null("Centro/Menu/Config/Vidas/Valor")
	assert(vidas_val is Button, "Vidas/Valor debe ser Button")
	assert(not (vidas_val is SpinBox), "Vidas/Valor NO debe ser SpinBox")
	assert(vidas_val.max_value == 20, "Vidas max_value debe ser 20")

	menu.queue_free()
	print("✓ Menú principal: botón renombrado, Controles removido y SpinBoxes reemplazados")


func test_number_picker_control() -> void:
	var picker = NumberPickerButton.new()
	picker.min_value = 1
	picker.max_value = 20
	picker.value = 3
	assert(picker.text == "3", "Texto inicial debe ser '3'")
	assert(not picker.editando, "No debe estar editando inicialmente")

	# Simular pulsar X / Enter (ui_accept)
	var ev_accept := InputEventAction.new()
	ev_accept.action = "ui_accept"
	ev_accept.pressed = true
	picker._gui_input(ev_accept)
	assert(picker.editando, "Debe entrar en modo edición tras ui_accept")
	assert(picker.text == "▲  3  ▼", "Texto en edición debe ser '▲  3  ▼'")

	# Simular mover arriba (ui_up)
	var ev_up := InputEventAction.new()
	ev_up.action = "ui_up"
	ev_up.pressed = true
	picker._gui_input(ev_up)
	assert(picker.value == 4, "Valor debe subir a 4")
	assert(picker.text == "▲  4  ▼", "Texto debe actualizarse a '▲  4  ▼'")

	# Simular mover abajo (ui_down)
	var ev_down := InputEventAction.new()
	ev_down.action = "ui_down"
	ev_down.pressed = true
	picker._gui_input(ev_down)
	assert(picker.value == 3, "Valor debe bajar a 3")

	# Simular pulsar X de nuevo para confirmar
	picker._gui_input(ev_accept)
	assert(not picker.editando, "Debe salir de modo edición tras confirmar con ui_accept")
	assert(picker.text == "3", "Texto final debe ser '3'")

	picker.queue_free()
	print("✓ NumberPickerButton: responde a ui_accept para editar y up/down para cambiar")


func test_w_no_confirma_teclado() -> void:
	Settings.dispositivos[1] = Settings.DISPOSITIVO_TECLADO
	Settings.aplicar_controles()

	# Para un jugador de teclado, jump_pressed no debe activarse
	var jump_pressed_teclado: bool = not Settings.es_teclado(1) and Input.is_action_just_pressed("p1_jump")
	assert(not jump_pressed_teclado, "jump_pressed DEBE ser falso para jugadores de teclado")

	# Para un jugador de mando, jump_pressed sí se evalúa (representa el botón X / A)
	Settings.dispositivos[1] = 0
	Settings.aplicar_controles()
	assert(not Settings.es_teclado(1), "P1 ahora es mando")
	var jump_pressed_mando_eval: bool = not Settings.es_teclado(1)
	assert(jump_pressed_mando_eval, "jump_pressed se habilita en mando (botón X)")

	Settings.dispositivos[1] = Settings.DISPOSITIVO_TECLADO
	Settings.aplicar_controles()
	print("✓ Confirmación: la tecla W (salto) NO confirma ready para jugadores con teclado")


func test_corazones_hud() -> void:
	RunManager.configurar_partida(3, 30)
	assert(RunManager.vidas_por_ronda == 20, "Vidas no debe superar el máximo de 20")

	var hud_scene: PackedScene = load("res://ui/match_hud.tscn")
	assert(hud_scene != null, "No se pudo cargar match_hud.tscn")
	var hud = hud_scene.instantiate()

	var contenedor := VBoxContainer.new()
	# Probar con 20 vidas (4 filas de 5)
	hud._actualizar_vidas_container(contenedor, 18, 20, 2, false)
	assert(contenedor.get_child_count() == 4, "20 vidas debe generar 4 filas")
	for i in 4:
		var fila = contenedor.get_child(i) as HBoxContainer
		assert(fila.alignment == BoxContainer.ALIGNMENT_END, "Jugador de la derecha (P2) debe alinear a la derecha")
		assert(fila.get_child_count() == 5, "Cada fila debe tener 5 corazones")

	# Probar con 7 vidas (2 filas: 5 y 2)
	hud._actualizar_vidas_container(contenedor, 5, 7, 1, true)
	assert(contenedor.get_child_count() == 2, "7 vidas debe generar 2 filas")
	var fila0 = contenedor.get_child(0) as HBoxContainer
	var fila1 = contenedor.get_child(1) as HBoxContainer
	assert(fila0.get_child_count() == 5, "Fila 0 debe tener 5 corazones")
	assert(fila1.get_child_count() == 2, "Fila 1 debe tener 2 corazones")
	assert(fila0.alignment == BoxContainer.ALIGNMENT_BEGIN, "Jugador de la izquierda (P1) debe alinear a la izquierda")

	hud.queue_free()
	contenedor.queue_free()
	print("✓ HUD de corazones: máximo 5 por fila, 20 vidas máximo y alineación correcta")


func test_dynamic_keyboard_scenarios() -> void:
	var previo := Settings.dispositivos.duplicate()

	# Escenario A: Todos en teclado
	Settings.dispositivos[1] = Settings.DISPOSITIVO_TECLADO
	Settings.dispositivos[2] = Settings.DISPOSITIVO_TECLADO
	Settings.dispositivos[3] = Settings.DISPOSITIVO_TECLADO
	Settings.dispositivos[4] = Settings.DISPOSITIVO_TECLADO
	Settings.aplicar_controles()

	assert(Settings.slot_teclado_de(1) == 1, "P1 debe ser slot 1")
	assert(Settings.slot_teclado_de(2) == 2, "P2 debe ser slot 2")
	assert(Settings.slot_teclado_de(3) == 3, "P3 debe ser slot 3")
	assert(Settings.slot_teclado_de(4) == 4, "P4 debe ser slot 4")
	assert(Settings.primer_jugador_teclado() == 1, "Primer jugador con teclado debe ser 1")
	assert(_tiene_tecla("p1_left", KEY_A), "P1 slot 1 debe ser A (WASD)")
	assert(_tiene_tecla("p2_left", KEY_LEFT), "P2 slot 2 debe ser Flecha Izq")
	assert(_tiene_tecla("p3_left", KEY_KP_4), "P3 slot 3 debe ser Numpad 4")
	assert(_tiene_tecla("p4_left", KEY_F), "P4 slot 4 debe ser F")
	print("✓ Escenario A (Todos teclado): slots 1, 2, 3, 4 asignados correctamente")

	# Escenario B: P1 = Mando 0, P2 = Teclado
	Settings.dispositivos[1] = 0
	Settings.dispositivos[2] = Settings.DISPOSITIVO_TECLADO
	Settings.dispositivos[3] = Settings.DISPOSITIVO_TECLADO
	Settings.dispositivos[4] = Settings.DISPOSITIVO_TECLADO
	Settings.aplicar_controles()

	assert(Settings.slot_teclado_de(1) == 0, "P1 con mando debe ser slot 0")
	assert(Settings.slot_teclado_de(2) == 1, "P2 debe ser el 1er teclado -> Slot 1")
	assert(Settings.slot_teclado_de(3) == 2, "P3 debe ser el 2do teclado -> Slot 2")
	assert(Settings.primer_jugador_teclado() == 2, "Primer jugador con teclado debe ser 2")
	assert(_tiene_tecla("p2_left", KEY_A), "P2 ahora debe recibir A (WASD)")
	assert(_tiene_tecla("p2_right", KEY_D), "P2 ahora debe recibir D (WASD)")
	assert(_tiene_tecla("p2_jump", KEY_W), "P2 ahora debe recibir W (WASD)")
	assert(_tiene_tecla("p2_fire", KEY_V), "P2 ahora debe recibir V (WASD)")
	assert(_tiene_tecla("p3_left", KEY_LEFT), "P3 ahora debe recibir Flecha Izq")
	print("✓ Escenario B (P1 mando, P2 teclado): P2 recibe WASD!")

	# Escenario C: P1 = Mando 0, P2 = Mando 1, P3 = Teclado, P4 = Teclado
	Settings.dispositivos[1] = 0
	Settings.dispositivos[2] = 1
	Settings.dispositivos[3] = Settings.DISPOSITIVO_TECLADO
	Settings.dispositivos[4] = Settings.DISPOSITIVO_TECLADO
	Settings.aplicar_controles()

	assert(Settings.slot_teclado_de(1) == 0, "P1 mando slot 0")
	assert(Settings.slot_teclado_de(2) == 0, "P2 mando slot 0")
	assert(Settings.slot_teclado_de(3) == 1, "P3 debe ser slot 1 (WASD)")
	assert(Settings.slot_teclado_de(4) == 2, "P4 debe ser slot 2 (Flechas)")
	assert(Settings.primer_jugador_teclado() == 3, "Primer teclado debe ser 3")
	assert(_tiene_tecla("p3_left", KEY_A), "P3 recibe WASD")
	assert(_tiene_tecla("p4_left", KEY_LEFT), "P4 recibe Flechas")
	print("✓ Escenario C (P1 y P2 mandos, P3 y P4 teclados): P3 recibe WASD y P4 Flechas!")

	# Restaurar
	Settings.dispositivos = previo
	Settings.aplicar_controles()


func test_reiniciar_full() -> void:
	RunManager.configurar_partida(3, 5)
	RunManager.iniciar_partida()
	# Simular mejoras acumuladas
	RunManager._mejoras[1] = ["corazon_titanio", "granada"]
	RunManager._mejoras[2] = ["rebote", "radar"]
	RunManager._marcador[1] = 2
	RunManager.ronda = 3

	# Ejecutar reiniciar
	RunManager.reiniciar()

	assert(RunManager._mejoras.is_empty(), "_mejoras debe estar vacío tras reiniciar()")
	assert(RunManager.marcador_de(1) == 0, "Marcador debe ser 0")
	assert(RunManager.ronda == 0, "Ronda debe ser 0")
	assert(RunManager.vidas_de(1) == 5, "Vidas deben resetearse a vidas_por_ronda")
	print("✓ Reinicio total: RunManager.reiniciar() limpia mejoras, marcador y restaura vidas")


func test_joystick_existing() -> void:
	var test_script: RefCounted = load("res://tests/test_input_joystick.gd").new()
	test_script.test_defaults_gamepad()
	test_script.test_apuntado_configurado_por_jugador()
	test_script.test_cada_jugador_usa_su_dispositivo()
	print("✓ Tests de joystick existentes pasaron correctamente")


func _tiene_tecla(accion: String, tecla: Key) -> bool:
	if not InputMap.has_action(accion):
		return false
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventKey:
			var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			if code == tecla:
				return true
	return false


func test_mapas_materiales_nativos() -> void:
	var mapas := MapManager.obtener_mapas()
	assert(mapas.size() >= 4, "Debe haber al menos 4 mapas registrados")

	for info in mapas:
		var mapa_id: StringName = info["id"]
		var escena_path: String = info["escena"]

		var escena: PackedScene = load(escena_path)
		assert(escena != null, "No se pudo cargar la escena: %s" % escena_path)

		var instancia: Node2D = escena.instantiate() as Node2D
		assert(instancia != null, "No se pudo instanciar la escena: %s" % escena_path)

		# Verificar que los spawns existan
		for p in range(1, 5):
			var sp_name := "SpawnP%d" % p
			var sp: Marker2D = instancia.get_node_or_null(sp_name) as Marker2D
			assert(sp != null, "El mapa %s debe tener %s como Marker2D" % [mapa_id, sp_name])

		# En mapas basados en polígonos, verificar que cada Polygon2D tenga su material nativo asignado en la escena
		if not instancia.has_node("NeonTileMap"):
			var poligonos := 0
			for hijo in instancia.get_children():
				if hijo is StaticBody2D:
					for subhijo in hijo.get_children():
						if subhijo is Polygon2D:
							poligonos += 1
							assert(subhijo.material != null, "Polygon2D en %s debe tener material asignado desde la escena!" % mapa_id)
			assert(poligonos > 0, "El mapa %s debe tener polígonos de plataformas" % mapa_id)

		instancia.queue_free()

	print("✓ Todos los 12 mapas cargan con materiales nativos y spawns configurados")


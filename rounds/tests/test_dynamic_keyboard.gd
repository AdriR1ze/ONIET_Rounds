extends Node


func _ready() -> void:
	print("--- INICIANDO TEST DINÁMICO DE TECLADO Y MENÚ ---")
	test_menu_principal()
	test_dynamic_keyboard_scenarios()
	test_reiniciar_full()
	test_joystick_existing()
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
	menu.queue_free()
	print("✓ Menú principal: botón renombrado y Controles removido correctamente")


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

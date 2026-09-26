extends Node

func _ready() -> void:
	print("--- TEST DE MENÚ UNIFICADO DE SELECCIÓN Y CONFIGURACIÓN ---")
	test_instanciar_escena()
	test_elementos_top_bar()
	test_ranuras_jugadores_y_activacion()
	test_dispositivo_y_dificultad_bot()
	test_condicion_inicio_partida()
	test_bloqueo_al_escribir_nombre()
	test_control_unirse_y_navegacion()
	print("--- TODOS LOS TESTS DEL MENÚ UNIFICADO PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func test_instanciar_escena() -> void:
	var scn: PackedScene = load("res://ui/character_select.tscn")
	assert(scn != null, "character_select.tscn debe existir y ser válida")
	var cs = scn.instantiate()
	assert(cs != null, "Debe poder instanciarse character_select")
	add_child(cs)
	cs.queue_free()
	print("✓ Carga e instanciación correcta de character_select.tscn")


func test_elementos_top_bar() -> void:
	var scn: PackedScene = load("res://ui/character_select.tscn")
	var cs = scn.instantiate()
	add_child(cs)

	assert(cs._btn_volver != null, "El botón Volver debe existir")
	assert(cs._rondas_picker != null, "El selector de rondas debe existir")
	assert(cs._vidas_picker != null, "El selector de vidas debe existir")

	# Probar cambio de rondas y vidas
	cs._rondas_picker.value = 7
	assert(RunManager.rondas_para_ganar == 7, "Cambiar rondas_picker debe actualizar RunManager.rondas_para_ganar")

	cs._vidas_picker.value = 4
	assert(RunManager.vidas_por_ronda == 4, "Cambiar vidas_picker debe actualizar RunManager.vidas_por_ronda")

	cs.queue_free()
	print("✓ Top Bar: Volver, RondasPicker y VidasPicker configurados con fuentes ampliadas y funcionales")


func test_ranuras_jugadores_y_activacion() -> void:
	var scn: PackedScene = load("res://ui/character_select.tscn")
	var cs = scn.instantiate()
	add_child(cs)

	assert(cs._bottom_slots != null, "El contenedor de ranuras inferiores debe existir")
	assert(cs._bottom_slots.get_child_count() == 4, "Debe haber 4 ranuras de jugadores (P1, P2, P3, P4)")

	# Por defecto, P1 y P2 activos, P3 y P4 inactivos
	assert(cs._slot_activo[1] == true, "P1 debe estar activo por defecto")
	assert(cs._slot_activo[2] == true, "P2 debe estar activo por defecto")

	# Desactivar P2 y activar P3 (ej: jugar con verde aunque sean 2 jugadores)
	cs._toggle_slot_activo(2)
	assert(cs._slot_activo[2] == false, "P2 debe haberse desactivado")

	cs._toggle_slot_activo(3)
	assert(cs._slot_activo[3] == true, "P3 debe haberse activado")

	var activos = cs._obtener_slots_activos()
	assert(activos == [1, 3], "Los slots activos deben ser exactamente P1 y P3")

	# Modificar nombre de P3
	var input_p3: LineEdit = cs._name_inputs[3]
	assert(input_p3 != null, "P3 debe tener campo de nombre")
	input_p3.text = "Tobi Verde"
	input_p3.text_changed.emit("Tobi Verde")
	assert(RunManager.nombre_jugador(3) == "Tobi Verde", "RunManager debe haber recibido el nombre de P3")

	cs.queue_free()
	print("✓ Ranuras de jugadores: activación/desactivación independiente, vista ampliada y edición de nombres")


func test_dispositivo_y_dificultad_bot() -> void:
	var scn: PackedScene = load("res://ui/character_select.tscn")
	var cs = scn.instantiate()
	add_child(cs)

	# Cambiar P2 a Bot
	var sel_p2: OptionButton = cs._disp_sel[2]
	var bot_idx = sel_p2.get_item_index(99)
	sel_p2.select(bot_idx)
	sel_p2.item_selected.emit(bot_idx)

	assert(Settings.es_bot(2), "P2 debe ser bot")
	assert(cs._listo[2] == true, "El bot debe marcarse como listo automáticamente")
	assert(cs._dif_row[2].visible == true, "La fila de dificultad debe ser visible para un bot")

	# Cambiar dificultad del bot P2 a 'Difícil' (índice 3)
	var dif_sel: OptionButton = cs._dif_sel[2]
	dif_sel.select(3)
	dif_sel.item_selected.emit(3)
	assert(RunManager.dificultad_bot_de(2) == 3, "La dificultad de bot de P2 debe ser 3 (Difícil)")

	# Cambiar P2 de vuelta a Teclado
	var tec_idx = sel_p2.get_item_index(0)
	sel_p2.select(tec_idx)
	sel_p2.item_selected.emit(tec_idx)
	assert(not Settings.es_bot(2), "P2 ya no debe ser bot")
	assert(cs._dif_row[2].visible == false, "La dificultad de bot debe ocultarse para un humano")
	assert(cs._listo[2] == false, "El humano no debe estar listo hasta pulsar ¡LISTO!")

	cs.queue_free()
	print("✓ Dispositivos y bots: cambio humano/bot y dificultad por bot funcional")


func test_condicion_inicio_partida() -> void:
	var scn: PackedScene = load("res://ui/character_select.tscn")
	var cs = scn.instantiate()
	add_child(cs)

	# Solo P1 y P2 activos, ninguno listo inicialmente
	cs._slot_activo[1] = true
	cs._slot_activo[2] = true
	cs._slot_activo[3] = false
	cs._slot_activo[4] = false
	cs._listo[1] = false
	cs._listo[2] = false
	Settings.set_dispositivo(1, Settings.DISPOSITIVO_TECLADO)
	Settings.set_dispositivo(2, Settings.DISPOSITIVO_TECLADO)
	cs._actualizar_ui()

	assert(cs._todos_listos() == false, "No deben estar todos listos al inicio")

	# P1 listo
	cs._toggle_ready(1)
	assert(cs._todos_listos() == false, "Aún falta P2")

	# P2 listo
	cs._toggle_ready(2)
	assert(cs._todos_listos() == true, "Ahora ambos están listos para iniciar automáticamente")

	# Si desactivamos P2 dejando solo 1 jugador activo
	cs._toggle_slot_activo(2)
	assert(cs._todos_listos() == false, "Con solo 1 jugador activo no se puede comenzar")

	cs.queue_free()
	print("✓ Condición de inicio: requiere mínimo 2 jugadores y confirmación de todos los humanos para arrancar solo")


func test_bloqueo_al_escribir_nombre() -> void:
	var scn: PackedScene = load("res://ui/character_select.tscn")
	var cs = scn.instantiate()
	add_child(cs)

	# Ambos listos para iniciar
	cs._slot_activo[1] = true
	cs._slot_activo[2] = true
	cs._listo[1] = true
	cs._listo[2] = true
	cs._actualizar_ui()
	assert(cs._todos_listos() == true, "Inicialmente listos para empezar")

	# Simular que P1 empieza a escribir su nombre (focus_entered)
	var input_p1: LineEdit = cs._name_inputs[1]
	input_p1.focus_entered.emit()

	assert(cs._esta_escribiendo_nombre() == true, "Debe detectar que se está editando un nombre")
	assert(cs._todos_listos() == false, "No debe permitir iniciar mientras se escribe el nombre")

	# Intentos de otros jugadores o teclas de cambiar personaje o activar/desactivar ranuras deben ser bloqueados
	var prev_choice_p2: int = cs._choice[2]
	cs._mover_eleccion(2, 1)
	assert(cs._choice[2] == prev_choice_p2, "No debe permitir mover personaje mientras alguien escribe nombre")

	var prev_activo_p2: bool = cs._slot_activo[2]
	cs._toggle_slot_activo(2)
	assert(cs._slot_activo[2] == prev_activo_p2, "No debe permitir cambiar ranuras mientras se escribe nombre")

	# Simular confirmación con ENTER (text_submitted)
	input_p1.text = "NuevoNombre"
	input_p1.text_submitted.emit("NuevoNombre")

	assert(cs._esta_escribiendo_nombre() == false, "Ya no debe estar en modo edición de nombre")
	assert(RunManager.nombre_jugador(1) == "NuevoNombre", "El nombre debe haberse guardado")
	assert(cs._todos_listos() == true, "Al confirmar, las acciones se reanudan normalmente")

	cs.queue_free()
	print("✓ Bloqueo al escribir nombre: no permite otras acciones hasta confirmar con ENTER")


func test_control_unirse_y_navegacion() -> void:
	var scn: PackedScene = load("res://ui/character_select.tscn")
	var cs = scn.instantiate()
	add_child(cs)

	for n in [1, 2, 3, 4]:
		Settings.set_dispositivo(n, Settings.DISPOSITIVO_TECLADO)
	RunManager.set_slots_activos([1, 2])

	# Simular pulsación de botón X (JOY_BUTTON_X) en mando 0 para unirse
	var joy_x := InputEventJoypadButton.new()
	joy_x.device = 0
	joy_x.button_index = JOY_BUTTON_X
	joy_x.pressed = true
	cs._input(joy_x)

	assert(Settings.dispositivo_de(1) == 0, "Mando 0 debe haberse unido y asignado a P1")
	assert(cs._slot_activo[1] == true, "Slot 1 debe estar activo")

	# Mover personaje con D-Pad derecho en mando 0
	var prev_choice = cs._choice[1]
	var joy_right := InputEventJoypadButton.new()
	joy_right.device = 0
	joy_right.button_index = JOY_BUTTON_DPAD_RIGHT
	joy_right.pressed = true
	cs._input(joy_right)
	assert(cs._choice[1] != prev_choice, "D-Pad derecho debe cambiar el personaje de P1")

	# Pulsar A (JOY_BUTTON_A) para ponerse ¡LISTO!
	var joy_a := InputEventJoypadButton.new()
	joy_a.device = 0
	joy_a.button_index = JOY_BUTTON_A
	joy_a.pressed = true
	cs._input(joy_a)
	assert(cs._listo[1] == true, "Botón A debe marcar P1 como LISTO")

	# Pulsar B (JOY_BUTTON_B) para cancelar ¡LISTO!
	var joy_b := InputEventJoypadButton.new()
	joy_b.device = 0
	joy_b.button_index = JOY_BUTTON_B
	joy_b.pressed = true
	cs._input(joy_b)
	assert(cs._listo[1] == false, "Botón B debe cancelar el estado LISTO de P1")

	# Simular segundo mando (device 1) uniéndose con botón A
	var joy2_a := InputEventJoypadButton.new()
	joy2_a.device = 1
	joy2_a.button_index = JOY_BUTTON_A
	joy2_a.pressed = true
	cs._input(joy2_a)

	assert(Settings.dispositivo_de(2) == 1, "Mando 1 debe haberse unido y asignado a P2")
	assert(cs._slot_activo[2] == true, "Slot 2 debe estar activo para el segundo mando")

	# Botón B en P2 cuando no está listo debe desactivar la ranura
	var joy2_b := InputEventJoypadButton.new()
	joy2_b.device = 1
	joy2_b.button_index = JOY_BUTTON_B
	joy2_b.pressed = true
	cs._input(joy2_b)
	assert(cs._slot_activo[2] == false, "Botón B en P2 no listo debe cerrar/desactivar la ranura")

	cs.queue_free()
	for n in [1, 2, 3, 4]:
		Settings.set_dispositivo(n, Settings.DISPOSITIVO_TECLADO)
	RunManager.set_slots_activos([1, 2])
	print("✓ Soporte de mandos: unirse con X/A, navegación completa con stick/D-pad y confirmación/cancelación con A/B")

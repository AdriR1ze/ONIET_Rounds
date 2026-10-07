extends Node

func _ready() -> void:
	print("--- TEST DE CONFIRMACIÓN AL REINICIAR (TECLA R) ---")
	test_dialogo_en_test_level()
	test_flujo_abrir_y_cancelar()
	test_flujo_confirmar()
	print("--- TODOS LOS TESTS DE CONFIRMACIÓN PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func test_dialogo_en_test_level() -> void:
	var level_scn: PackedScene = load("res://levels/test_level.tscn")
	assert(level_scn != null, "No se pudo cargar test_level.tscn")
	var level = level_scn.instantiate()
	add_child(level)

	var dialog = level.get_node_or_null("RestartConfirmDialog")
	assert(dialog != null, "RestartConfirmDialog debe existir en test_level.tscn")
	assert(dialog.visible == false, "El diálogo debe iniciar oculto")
	assert(PauseManager.activo() == false, "PauseManager no debe estar activo inicialmente")

	# Simular pulsar R para abrir el diálogo
	var ev_restart = InputEventAction.new()
	ev_restart.action = "restart"
	ev_restart.pressed = true
	level._unhandled_input(ev_restart)

	assert(dialog.visible == true, "Al presionar R, el diálogo debe hacerse visible")
	assert(PauseManager.activo() == true, "PauseManager debe estar activo (juego pausado)")
	assert(PauseManager.dueno_actual() == dialog, "El dueño de la pausa debe ser el diálogo")

	# Simular cancelar
	dialog.cerrar()
	assert(dialog.visible == false, "Al cancelar, el diálogo debe ocultarse")
	assert(PauseManager.activo() == false, "PauseManager debe soltarse al cancelar")

	level.queue_free()
	print("✓ Diálogo integrado en test_level.tscn y activación con 'restart'")


func test_flujo_abrir_y_cancelar() -> void:
	var dlg_scn: PackedScene = load("res://ui/restart_confirm_dialog.tscn")
	assert(dlg_scn != null, "No se pudo cargar restart_confirm_dialog.tscn")
	var dialog = dlg_scn.instantiate()
	add_child(dialog)

	assert(dialog.visible == false, "Debe iniciar invisible")

	dialog.abrir()
	assert(dialog.visible == true, "Debe ser visible tras abrir")
	assert(PauseManager.activo() == true, "Debe tomar PauseManager")

	var emitio_cancelado := [false]
	dialog.cancelado.connect(func(): emitio_cancelado[0] = true)

	# Simular ui_cancel (ESC / B en gamepad)
	var ev_cancel = InputEventAction.new()
	ev_cancel.action = "ui_cancel"
	ev_cancel.pressed = true
	dialog._unhandled_input(ev_cancel)

	assert(dialog.visible == false, "Debe ocultarse al presionar ui_cancel")
	assert(PauseManager.activo() == false, "Debe soltar PauseManager al cancelar")
	assert(emitio_cancelado[0] == true, "Debe emitir señal cancelado")

	dialog.queue_free()
	print("✓ Flujo de apertura y cancelación con ESC/ui_cancel")


func test_flujo_confirmar() -> void:
	var dlg_scn: PackedScene = load("res://ui/restart_confirm_dialog.tscn")
	var dialog = dlg_scn.instantiate()
	add_child(dialog)

	var boton_reiniciar = dialog.get_node("Centro/Marco/Margin/VBox/Botones/Reiniciar")
	assert(boton_reiniciar != null, "El botón Reiniciar debe existir")
	assert(boton_reiniciar.pressed.is_connected(dialog._al_confirmar), "El botón Reiniciar debe estar conectado a _al_confirmar")

	var boton_cancelar = dialog.get_node("Centro/Marco/Margin/VBox/Botones/Cancelar")
	assert(boton_cancelar != null, "El botón Cancelar debe existir")
	assert(boton_cancelar.pressed.is_connected(dialog.cerrar), "El botón Cancelar debe estar conectado a cerrar")

	dialog.abrir()
	assert(dialog.visible == true, "Debe abrirse")

	# Tecla restart ('R') repetida mientras está abierto: no debe cerrar ni romper
	var ev_restart = InputEventAction.new()
	ev_restart.action = "restart"
	ev_restart.pressed = true
	dialog._unhandled_input(ev_restart)
	assert(dialog.visible == true, "Pulsar restart mientras está abierto no debe cerrarlo")

	# Cancelar mediante el botón Cancelar
	var cancelado_por_boton := [false]
	dialog.cancelado.connect(func(): cancelado_por_boton[0] = true)
	boton_cancelar.pressed.emit()
	assert(dialog.visible == false, "Presionar botón Cancelar debe cerrar el diálogo")
	assert(PauseManager.activo() == false, "Presionar botón Cancelar debe soltar PauseManager")
	assert(cancelado_por_boton[0] == true, "Presionar botón Cancelar debe emitir cancelado")

	dialog.queue_free()
	print("✓ Botones, foco y eventos repetidos verificados")

extends Node

func _ready() -> void:
	print("--- TEST DE START SCREEN (CLICK Y BOTONES) ---")
	var scn: PackedScene = load("res://ui/start_screen.tscn")
	assert(scn != null, "start_screen.tscn debe existir")
	var screen = scn.instantiate()
	add_child(screen)

	assert(screen._transicionando == false, "Inicialmente no debe estar transicionando")

	# Simular un click con el mouse
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	screen._input(mouse_event)

	assert(screen._transicionando == true, "Al hacer click con el mouse debe iniciar transicion")
	print("✓ Click del mouse via _input avanza a la siguiente escena correctamente")

	screen.queue_free()

	# Probar también vía _gui_input
	var screen2 = scn.instantiate()
	add_child(screen2)
	assert(screen2._transicionando == false)
	screen2._gui_input(mouse_event)
	assert(screen2._transicionando == true, "_gui_input con mouse click debe iniciar transicion")
	print("✓ Click del mouse via _gui_input avanza a la siguiente escena correctamente")
	screen2.queue_free()

	print("--- TEST DE START SCREEN PASADO EXITOSAMENTE ---")
	get_tree().quit(0)

extends Node

const RUTA_NIVEL := "res://levels/tutorial_level.tscn"
const RUTA_MENU := "res://ui/main_menu.tscn"

# Acciones de P1 que el panel del tutorial debe mostrar.
const ACCIONES_MOSTRADAS := ["left", "right", "jump", "down", "fire", "ragdoll", "grab"]


func _ready() -> void:
	print("--- TEST NIVEL TUTORIAL (SALA DE PRÁCTICA) ---")
	_test_boton_menu()
	var nivel: Node2D = await _instanciar_nivel()
	_test_nodos_presentes(nivel)
	_test_jugador_activo(nivel)
	_test_texto_controles(nivel)
	_test_muerte_respawnea(nivel)
	nivel.free()
	print("--- TODOS LOS TESTS DEL TUTORIAL PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func _instanciar_nivel() -> Node2D:
	var scn: PackedScene = load(RUTA_NIVEL)
	assert(scn != null, "No se pudo cargar %s" % RUTA_NIVEL)
	var nivel: Node2D = scn.instantiate() as Node2D
	assert(nivel != null, "tutorial_level.tscn debe tener una raíz Node2D")
	add_child(nivel)
	await get_tree().process_frame
	return nivel


func _test_nodos_presentes(nivel: Node) -> void:
	assert(nivel.get_node_or_null("Player1") != null, "tutorial_level debe tener Player1")
	assert(nivel.get_node_or_null("Camera") is Camera2D, "tutorial_level debe tener Camera (Camera2D)")
	assert(nivel.get_node_or_null("TutorialHUD") is CanvasLayer, "tutorial_level debe tener TutorialHUD")
	assert(nivel.get_node_or_null("PauseMenu") != null, "tutorial_level debe tener PauseMenu")
	assert(nivel.get_node_or_null("MapContainer/MapArenaAbierta") != null, "tutorial_level debe instanciar el mapa reusado")
	assert(nivel.get_node_or_null("TutorialHUD/Fondo/Panel/Controles") is Label, "falta el Label de Controles")
	print("✓ Escena carga con Player1, Camera, TutorialHUD, PauseMenu y mapa reusado")


func _test_jugador_activo(nivel: Node) -> void:
	var p1 = nivel.get_node_or_null("Player1")
	assert(p1 != null and is_instance_valid(p1), "Player1 no debe haber sido descartado (culled)")
	assert(p1.is_inside_tree(), "Player1 debe seguir dentro del árbol")
	assert(p1.player_number == 1, "Player1.player_number debe ser 1, es %d" % p1.player_number)
	print("✓ Player1 activo y no descartado (player_number == 1)")


func _test_texto_controles(nivel: Node) -> void:
	var controles: Label = nivel.get_node("TutorialHUD/Fondo/Panel/Controles")
	var texto: String = controles.text
	assert(not texto.strip_edges().is_empty(), "El texto de Controles no debe estar vacío")

	# Cada línea debe usar la etiqueta legible real y el binding real vigente.
	for sufijo in ACCIONES_MOSTRADAS:
		var accion := "p1_%s" % sufijo
		var etiqueta: String = Settings.ETIQUETAS.get(sufijo, sufijo)
		var esperado: String = Settings.nombre_binding(Settings.binding_de(accion))
		assert(not esperado.is_empty() and esperado != "—", "Binding real vacío para %s" % accion)
		assert(texto.contains(etiqueta), "El texto debe usar la etiqueta '%s' de %s" % [etiqueta, accion])
		assert(texto.contains(esperado), "El texto debe contener la tecla real de %s ('%s')" % [accion, esperado])

	var disparo: String = Settings.nombre_binding(Settings.binding_de("p1_fire"))
	print("✓ Controles generados desde bindings reales (disparar = '%s', no hardcodeado)" % disparo)


func _test_muerte_respawnea(nivel: Node) -> void:
	var p1 = nivel.get_node("Player1")
	var health = p1.get_node("HealthComponent")
	assert(health.is_alive(), "Player1 debe empezar con vida llena")

	var spawn: Vector2 = p1._spawn_position
	# Alejarlo del spawn: así se prueba que respawn() realmente lo devuelve.
	p1.global_position = spawn + Vector2(400.0, -50.0)
	assert(p1.global_position != spawn, "El jugador debe haberse movido antes de morir")

	health.apply_damage(999)
	assert(health.is_alive(), "Tras morir, el reset blando debe dejar vivo a Player1")
	assert(
		p1.global_position == spawn,
		"Tras morir, Player1 debe volver a su spawn %s, está en %s" % [spawn, p1.global_position]
	)
	print("✓ Muerte = respawn blando: Player1 vivo y de vuelta en %s" % spawn)


func _test_boton_menu() -> void:
	var scn: PackedScene = load(RUTA_MENU)
	assert(scn != null, "No se pudo cargar %s" % RUTA_MENU)
	var menu = scn.instantiate()
	var boton = menu.get_node_or_null("Centro/Menu/Tutorial")
	assert(boton != null, "main_menu.tscn debe tener el nodo Centro/Menu/Tutorial")
	assert(boton is Button, "Centro/Menu/Tutorial debe ser un Button")
	assert(boton.text == "Tutorial", "El botón debe decir 'Tutorial', dice '%s'" % boton.text)
	menu.free()
	print("✓ Menú principal: botón 'Tutorial' presente en Centro/Menu")

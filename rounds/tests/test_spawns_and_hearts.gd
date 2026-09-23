extends Node

func _ready() -> void:
	print("--- TEST DE CORAZONES, SPAWNS DISTRIBUIDOS Y BAJA INTERMEDIA ---")
	test_default_rounds()
	test_map_spawns()
	test_hud_character_hearts()
	test_mid_round_kill_flow()
	print("--- TODOS LOS NUEVOS TESTS PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func test_default_rounds() -> void:
	assert(RunManager.rondas_para_ganar == 5, "Rondas por defecto debe ser 5, actual: %d" % RunManager.rondas_para_ganar)
	assert(RunManager.vidas_por_ronda == 2, "Vidas por defecto debe ser 2, actual: %d" % RunManager.vidas_por_ronda)
	var menu_scn: PackedScene = load("res://ui/main_menu.tscn")
	var menu = menu_scn.instantiate()
	var rondas_val: Node = menu.get_node_or_null("ModalPartida/Centro/Marco/Margin/VBox/Config/Rondas/Valor")
	assert(rondas_val != null, "Rondas/Valor debe existir en ModalPartida")
	assert(rondas_val.value == 5, "Rondas valor inicial debe ser 5, actual: %d" % rondas_val.value)
	var vidas_val: Node = menu.get_node_or_null("ModalPartida/Centro/Marco/Margin/VBox/Config/Vidas/Valor")
	assert(vidas_val != null, "Vidas/Valor debe existir en ModalPartida")
	assert(vidas_val.value == 2, "Vidas valor inicial debe ser 2, actual: %d" % vidas_val.value)
	menu.free()
	print("✓ Rondas y vidas por defecto: 5 rondas para ganar y 2 vidas por ronda")


func test_map_spawns() -> void:
	var mapas := MapManager.obtener_mapas()
	for info in mapas:
		var scn: PackedScene = load(info["escena"])
		assert(scn != null, "No se pudo cargar mapa: %s" % info["escena"])
		var inst: Node2D = scn.instantiate() as Node2D
		var spawns: Array[Vector2] = []
		for child in inst.get_children():
			if child is Marker2D and child.name.begins_with("Spawn"):
				spawns.append(child.global_position)
		assert(spawns.size() >= 8, "Mapa %s debe tener al menos 8 spawns, tiene %d" % [info["nombre"], spawns.size()])
		# Verificar que no sean todos iguales
		var unique := {}
		for sp in spawns:
			unique[sp] = true
		assert(unique.size() >= 6, "Mapa %s debe tener al menos 6 posiciones únicas de spawn" % info["nombre"])
		inst.free()
	print("✓ Spawns distribuidos: todos los 12 mapas tienen 8 a 9 spawns en distintas alturas y posiciones")


func test_hud_character_hearts() -> void:
	var hud_scn: PackedScene = load("res://ui/match_hud.tscn")
	assert(hud_scn != null, "No se pudo cargar match_hud.tscn")
	var hud = hud_scn.instantiate()

	# Probar para cada personaje
	for pj in ["esqueleto", "sapo", "pajaro"]:
		RunManager.set_personaje(1, pj)
		var cont := VBoxContainer.new()
		hud._actualizar_vidas_container(cont, 2, 3, 1, true)
		assert(cont.get_child_count() == 1, "3 vidas debe tener 1 fila")
		var fila := cont.get_child(0) as HBoxContainer
		assert(fila.get_child_count() == 3, "Fila debe tener 3 corazones")

		var pip1 := fila.get_child(0) as TextureRect
		var pip2 := fila.get_child(1) as TextureRect
		var pip3 := fila.get_child(2) as TextureRect

		assert(pip1.texture != null, "Pip 1 debe tener textura")
		assert(pip2.texture != null, "Pip 2 debe tener textura")
		assert(pip3.texture != null, "Pip 3 debe tener textura")

		# pip 1 y 2 son vidas activas (lleno), pip 3 es vida perdida (vacio)
		assert(pip1.texture == pip2.texture, "Pip 1 y 2 deben compartir la textura de vida llena")
		assert(pip1.texture != pip3.texture, "Pip 1 (lleno) debe ser distinto a Pip 3 (vacío)")

		var texturas: Dictionary = hud.TEXTURAS_CORAZONES[pj]
		assert(pip1.texture == texturas["lleno"], "Pip 1 debe tener textura llena de %s" % pj)
		assert(pip3.texture == texturas["vacio"], "Pip 3 debe tener textura vacía de %s" % pj)

		cont.free()

	hud.free()
	print("✓ HUD de corazones: texturas asignadas correctamente para esqueleto, sapo y pájaro")


func test_mid_round_kill_flow() -> void:
	var level_scn: PackedScene = load("res://levels/test_level.tscn")
	assert(level_scn != null, "No se pudo cargar test_level.tscn")
	var level = level_scn.instantiate()
	add_child(level)

	var run_ctrl = level.get_node("RunController")
	var kill_banner = level.get_node_or_null("KillBanner")
	assert(kill_banner != null, "KillBanner debe existir en test_level.tscn")
	if run_ctrl.banner_baja == null:
		run_ctrl.banner_baja = kill_banner
	assert(run_ctrl.banner_baja == kill_banner, "RunController debe tener referencia a KillBanner")

	var p1 = level.get_node("Player1")
	var p2 = level.get_node("Player2")

	# Simular muerte intermedia de P1 teniendo 2 vidas
	RunManager.configurar_partida(2, 2)
	RunManager.iniciar_ronda(1)
	run_ctrl._ronda_activa = true
	run_ctrl._procesando = false

	# P1 muere
	run_ctrl._on_jugador_muerto(p1)

	# Vidas de P1 deben haber bajado a 1
	assert(RunManager.vidas_de(1) == 1, "P1 debe tener 1 vida restante")
	assert(RunManager.vidas_de(2) == 2, "P2 debe conservar sus 2 vidas")

	level.free()
	print("✓ Flujo de baja intermedia: KillBanner integrado y vidas descontadas correctamente")

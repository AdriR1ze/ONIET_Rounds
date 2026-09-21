extends Node

func _ready() -> void:
	print("--- INICIANDO TEST DE PROPULSIÓN Y GOLPE TITÁNICO ---")
	UpgradeDatabase.cargar()

	var def_propulsion: UpgradeDefinition = null
	var def_melee: UpgradeDefinition = null
	for def in UpgradeDatabase.definiciones:
		if def.id == &"propulsion":
			def_propulsion = def
		elif def.id == &"golpe_titanico":
			def_melee = def

	assert(def_propulsion != null, "No se encontró propulsión")
	assert(def_melee != null, "No se encontró golpe_titanico")

	var player_scene: PackedScene = load("res://player/player.tscn")
	var p1: Player = player_scene.instantiate()
	p1.player_number = 1
	add_child(p1)

	var p2: Player = player_scene.instantiate()
	p2.player_number = 2
	p2.position = Vector2(40, 0)
	add_child(p2)

	# 1. Probar Propulsión
	p1.aplicar_mejoras([def_propulsion])
	assert(p1.has_propulsion == true, "has_propulsion debe ser true")
	assert(p1._weapon._has_infinite_ammo() == true, "debe tener infinite_ammo")

	p1._weapon.reset_cooldown(0.0)
	var initial_ammo := p1._weapon.current_ammo
	p1._weapon.aim_direction = Vector2.DOWN
	var fired_ok := p1._weapon.try_fire()
	assert(fired_ok == true, "try_fire debió disparar")
	assert(p1._weapon.current_ammo == initial_ammo, "La munición no debió disminuir (cargador infinito)")
	print("Retroceso vertical tras disparar hacia abajo: ", p1.velocity.y)
	assert(p1.velocity.y <= -800.0, "El impulso vertical debe ser superior a 800")

	# 2. Probar Golpe Titánico
	p1.aplicar_mejoras([def_melee])
	p1._weapon.reset_cooldown(0.0)
	assert(p1._weapon._has_melee_strike() == true, "debe tener melee strike activo")
	var p2_hp_before := p2._health.health
	p1._weapon.aim_direction = Vector2.RIGHT
	p1._weapon.try_fire()
	print("Vida del rival antes: %d, después del golpe melee: %d" % [p2_hp_before, p2._health.health])
	assert(p2._health.health < p2_hp_before, "El golpe melee debe dañar al rival")

	print("--- TODOS LOS TESTS DE PROPULSIÓN Y GOLPE TITÁNICO PASARON ---")
	get_tree().quit(0)

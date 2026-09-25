extends Node

func _ready() -> void:
	print("--- TEST DE PROPULSIÓN EN EL AIRE, COLAPSO Y SEGURIDAD AL INICIAR RONDA ---")
	test_propulsion_ground_vs_air()
	test_player_invulnerability_while_frozen()
	test_pyramid_collapse_timing_and_bounds()
	print("--- TODOS LOS TESTS DE PROPULSIÓN Y SEGURIDAD PASARON EXITOSAMENTE ---")
	get_tree().quit(0)


func test_propulsion_ground_vs_air() -> void:
	var effect := PropulsionEffect.new()
	assert(effect.recoil_force == 220.0, "Fuerza en tierra debe ser 220")
	assert(effect.air_recoil_force == 640.0, "Fuerza en aire debe ser 640")

	var player_scn: PackedScene = load("res://player/player_1.tscn")
	var p: CharacterBody2D = player_scn.instantiate()
	add_child(p)
	p.position = Vector2(500, 300)

	# Simular disparo en el suelo hacia la derecha (Vector2.RIGHT)
	var shot_ground := Shot.new()
	shot_ground.direction = Vector2.RIGHT
	p.velocity = Vector2.ZERO
	effect.on_fire(shot_ground, p)
	# In air (is_on_floor is false without collision): recoil should be air_recoil_force = 640
	assert(p.velocity.x == -640.0, "En el aire debe aplicar fuerza de 640 hacia la izquierda, actual: %f" % p.velocity.x)

	# Simular disparo hacia abajo en el aire mientras cae (velocity.y = 300)
	p.velocity = Vector2(0, 300)
	var shot_down := Shot.new()
	shot_down.direction = Vector2.DOWN
	effect.on_fire(shot_down, p)
	assert(p.velocity.y == -640.0, "Disparo hacia abajo en el aire debe cancelar caída y elevar a -640, actual: %f" % p.velocity.y)

	p.queue_free()
	print("✓ Propulsión en el aire: eleva al jugador con 640 de impulso y cancela la caída previa")


func test_player_invulnerability_while_frozen() -> void:
	var player_scn: PackedScene = load("res://player/player_1.tscn")
	var p: CharacterBody2D = player_scn.instantiate()
	add_child(p)
	p.position = Vector2(500, 300)

	var initial_hp: int = p.get_node("HealthComponent").health
	# Mientras invulnerable == true, hurt() no debe hacer daño ni de muerte (999)
	p.invulnerable = true
	p.hurt(999, null)
	assert(p.get_node("HealthComponent").health == initial_hp, "Jugador congelado/invulnerable no debe recibir daño")
	assert(p.is_alive() == true, "Jugador invulnerable debe seguir con vida")

	# Quitar invulnerable pero con spawn protection activo
	p.invulnerable = false
	p.set("_spawn_protection_timer", 0.5)
	p.hurt(999, null)
	assert(p.get_node("HealthComponent").health == initial_hp, "Jugador con protección de spawn no debe morir")

	# Agotar spawn protection -> ahora sí puede recibir daño
	p.set("_spawn_protection_timer", 0.0)
	p.hurt(20, null)
	assert(p.get_node("HealthComponent").health < initial_hp, "Jugador sin invulnerabilidad debe recibir daño normalmente")

	p.queue_free()
	print("✓ Seguridad al iniciar ronda: invulnerabilidad mientras está congelado y protección en spawn")


func test_pyramid_collapse_timing_and_bounds() -> void:
	var mapa_scn: PackedScene = load("res://levels/maps/map_03_el_pendulo.tscn")
	var mapa: Node2D = mapa_scn.instantiate()
	add_child(mapa)

	var timer: Timer = mapa.get_node("ColapsoTimer")
	# Al iniciar ronda (o al perder una vida) debe arrancar la gracia corta
	mapa._on_ronda_iniciada(1)
	assert(timer.wait_time == mapa.RETRASO_INICIAL, "El retraso inicial debe ser RETRASO_INICIAL, actual: %f" % timer.wait_time)
	assert(mapa.ancho_capa >= 2, "Deben caer varias columnas por paso para que el colapso sea rápido")

	# Al dispararse el primer timeout (termina la gracia), cambia al intervalo regular
	mapa._on_timer_timeout()
	assert(timer.wait_time == mapa.INTERVALO_COLAPSO, "Intervalo de colapso debe ser INTERVALO_COLAPSO tras el inicio")

	# Al perder una vida a mitad del colapso, todo se rehace desde la gracia
	mapa._on_timer_timeout()
	mapa._on_vida_perdida(1, 1)
	assert(mapa._fase == mapa.Fase.GRACIA, "Perder una vida debe reiniciar el colapso")
	assert(timer.wait_time == mapa.RETRASO_INICIAL, "Perder una vida debe reiniciar el retraso inicial")

	print("✓ Tiempos de colapso de la pirámide: gracia de %ds, %ds por capa y reinicio total al perder una vida"
		% [int(mapa.RETRASO_INICIAL), int(mapa.INTERVALO_COLAPSO)])
	mapa.queue_free()
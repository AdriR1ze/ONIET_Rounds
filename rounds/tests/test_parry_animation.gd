extends Node

## Test for parry animation, directional aiming, movement preservation, and bullet bounce

func _ready() -> void:
	print("--- INICIANDO TEST DE PARRY Y REBOTE DE BALAS ---")
	var player_scene: PackedScene = load("res://player/player.tscn")
	assert(player_scene != null, "player.tscn debe cargar correctamente")

	var player: Player = player_scene.instantiate() as Player
	assert(player != null, "Player debe instanciarse")
	add_child(player)

	var parry_effect: AnimatedSprite2D = player.get_node_or_null("ParryEffect") as AnimatedSprite2D
	assert(parry_effect != null, "ParryEffect node debe existir en Player")
	assert(parry_effect.sprite_frames != null, "ParryEffect debe tener SpriteFrames")
	assert(parry_effect.sprite_frames.has_animation(&"parry"), "Debe existir la animación 'parry'")
	assert(parry_effect.sprite_frames.get_frame_count(&"parry") == 6, "La animación 'parry' debe tener 6 frames")
	assert(not parry_effect.visible, "ParryEffect debe iniciar invisible")
	print("✓ Configuración de nodo y SpriteFrames correcta (6 frames)")

	# 1. Test aiming in multiple directions
	var directions: Array[Vector2] = [
		Vector2.RIGHT,
		Vector2.UP,
		Vector2.LEFT,
		Vector2.DOWN,
		Vector2(1, -1).normalized(),
		Vector2(-1, -1).normalized()
	]

	for dir in directions:
		player.get_node("WeaponComponent").set_aim(dir)
		player._play_parry_animation()
		assert(parry_effect.visible, "ParryEffect debe ser visible al activar parry")
		assert(parry_effect.is_playing(), "ParryEffect debe estar reproduciéndose")
		
		var expected_rot: float = dir.angle() + deg_to_rad(45.0)
		var diff: float = absf(wrapf(parry_effect.rotation - expected_rot, -PI, PI))
		assert(diff < 0.001, "La rotación de ParryEffect debe apuntar a la dirección deseada (dir: %s, rot: %f, esp: %f)" % [dir, parry_effect.rotation, expected_rot])
		print("✓ Parry apuntando a %s: rotación %.2f rad correcta" % [dir, parry_effect.rotation])

	# 2. Test que NO gire el personaje ni se congele en el aire
	player.velocity = Vector2(350.0, -200.0)
	player._start_ragdoll()
	assert(player.get_node("Visual").rotation == 0.0, "El personaje no debe girar al hacer parry")
	assert(player.velocity.x == 350.0, "El personaje no debe perder velocidad horizontal en el aire al parrear")
	assert(player.velocity.y == -200.0, "El personaje no debe perder velocidad vertical en el aire al parrear")
	assert(player.can_control, "El personaje debe conservar el control durante el parry")
	print("✓ Sin giro visual y sin congelamiento en el aire al parrear")

	# 3. Test de rebote de bala con velocidad real
	var bullet_scene: PackedScene = load("res://weapons/bullet.tscn")
	assert(bullet_scene != null, "bullet.tscn debe cargar")
	var bullet = bullet_scene.instantiate()
	add_child(bullet)
	bullet.velocity = Vector2(-1050.0, 0.0)
	bullet.global_position = player.global_position + Vector2(50.0, 0.0)
	player.get_node("WeaponComponent").set_aim(Vector2.RIGHT)
	bullet.parry(player)
	assert(bullet.velocity.length() > 500.0, "La bala parreada debe rebotar a gran velocidad, actual: %f" % bullet.velocity.length())
	assert(bullet.velocity.x > 0.0, "La bala debe viajar hacia donde apunta el parry (derecha)")
	print("✓ Rebote de bala funcional con velocidad: %.1f px/s" % bullet.velocity.length())
	bullet.queue_free()

	# 4. Test de efecto visual de recarga de parry
	var initial_children := player.get_child_count()
	player._on_parry_recharged()
	assert(player.get_child_count() > initial_children, "Debe instanciarse el efecto visual (Line2D) de recarga")
	print("✓ Efecto visual de recarga instanciado correctamente")

	# 5. Test death and respawn resets
	player._on_died()
	assert(not parry_effect.visible, "ParryEffect debe ocultarse al morir")
	player.respawn()
	assert(not parry_effect.visible, "ParryEffect debe mantenerse oculto al reaparecer")
	print("✓ Reset en muerte y respawn correcto")

	player.queue_free()
	print("--- TODOS LOS TESTS DE PARRY PASARON EXITOSAMENTE ---")
	get_tree().quit(0)

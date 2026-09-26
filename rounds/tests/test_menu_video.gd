extends Node

func _ready() -> void:
	print("--- TEST DE VIDEO DE FONDO EN MENÚ PRINCIPAL ---")
	var scn: PackedScene = load("res://ui/main_menu.tscn")
	assert(scn != null, "main_menu.tscn debe existir y ser válida")
	var menu = scn.instantiate()
	add_child(menu)

	var video = menu.get_node_or_null("VideoFondo") as VideoStreamPlayer
	assert(video != null, "VideoFondo debe existir en MainMenu")
	assert(video.stream != null, "VideoFondo debe tener stream asignado")
	assert(video.autoplay == true, "VideoFondo debe tener autoplay = true")
	assert(video.loop == true, "VideoFondo debe tener loop = true")
	assert(video.expand == true, "VideoFondo debe tener expand = true")
	assert(video.mouse_filter == Control.MOUSE_FILTER_IGNORE, "VideoFondo no debe bloquear clics (MOUSE_FILTER_IGNORE)")
	print("✓ VideoFondo configurado correctamente con stream, loop y autoplay")

	var oscurecedor = menu.get_node_or_null("Oscurecedor") as ColorRect
	assert(oscurecedor != null, "Oscurecedor debe existir para atenuar el video")
	assert(oscurecedor.color.a >= 0.5, "Oscurecedor debe tener opacidad adecuada para contraste oscuro")
	assert(oscurecedor.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Oscurecedor no debe bloquear clics")
	print("✓ Oscurecedor configurado correctamente para dar contraste oscuro y cinematográfico")

	menu.queue_free()
	print("--- TEST DE VIDEO DE FONDO PASADO EXITOSAMENTE ---")
	get_tree().quit(0)

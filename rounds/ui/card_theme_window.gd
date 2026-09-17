extends Control

@export var tema: StringName = &"default"
@export var border_color: Color = Color(0.25, 0.8, 1.0, 0.8)

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func set_tema(nuevo_tema: StringName, color_rareza: Color = Color(0.25, 0.8, 1.0, 0.8)) -> void:
	tema = nuevo_tema
	border_color = color_rareza
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var c := size / 2.0

	# Fondo oscuro de la ventana
	draw_rect(rect, Color(0.03, 0.04, 0.07, 0.96))
	# Borde sutil
	draw_rect(rect, Color(border_color.r, border_color.g, border_color.b, 0.35), false, 1.0)

	# Corchetes en las esquinas de la ventana (estilo ROUNDS)
	var arm := 12.0
	var thick := 2.0
	var bracket_col := border_color
	# Superior Izquierda
	draw_line(Vector2(4, 4), Vector2(4 + arm, 4), bracket_col, thick)
	draw_line(Vector2(4, 4), Vector2(4, 4 + arm), bracket_col, thick)
	# Superior Derecha
	draw_line(Vector2(size.x - 4, 4), Vector2(size.x - 4 - arm, 4), bracket_col, thick)
	draw_line(Vector2(size.x - 4, 4), Vector2(size.x - 4, 4 + arm), bracket_col, thick)
	# Inferior Izquierda
	draw_line(Vector2(4, size.y - 4), Vector2(4 + arm, size.y - 4), bracket_col, thick)
	draw_line(Vector2(4, size.y - 4), Vector2(4, size.y - 4 - arm), bracket_col, thick)
	# Inferior Derecha
	draw_line(Vector2(size.x - 4, size.y - 4), Vector2(size.x - 4 - arm, size.y - 4), bracket_col, thick)
	draw_line(Vector2(size.x - 4, size.y - 4), Vector2(size.x - 4, size.y - 4 - arm), bracket_col, thick)

	# Dibujo temático
	match tema:
		&"toxico":
			_draw_toxico(c)
		&"vampirico":
			_draw_vampirico(c)
		&"explosivo":
			_draw_explosivo(c)
		&"laser":
			_draw_laser(c)
		&"glitch":
			_draw_glitch(c)
		&"rebote":
			_draw_rebote(c)
		&"pesado":
			_draw_pesado(c)
		&"rapido":
			_draw_rapido(c)
		&"cristal":
			_draw_cristal(c)
		&"roulette":
			_draw_roulette(c)
		&"fantasma":
			_draw_fantasma(c)
		&"demolicion":
			_draw_demolicion(c)
		_:
			_draw_default(c)


func _draw_toxico(c: Vector2) -> void:
	# Resplandor central verde
	var pulse: float = 0.85 + 0.15 * sin(_time * 3.0)
	draw_circle(c, 26.0 * pulse, Color(0.2, 0.85, 0.3, 0.25))
	draw_circle(c, 18.0 * pulse, Color(0.3, 0.95, 0.4, 0.45))
	# Burbujas ascendentes
	var bubble_offsets: Array[Vector2] = [
		Vector2(-24, 18), Vector2(-10, 10), Vector2(8, 14),
		Vector2(-16, -10), Vector2(16, -8), Vector2(0, -22)
	]
	var radii: Array[float] = [4.5, 6.0, 5.0, 7.0, 5.5, 4.0]
	for i in bubble_offsets.size():
		var dy: float = fmod(_time * 24.0 * (1.0 + float(i) * 0.2), 48.0)
		var b_pos: Vector2 = c + bubble_offsets[i] - Vector2(0.0, dy)
		if b_pos.y > 6.0 and b_pos.y < size.y - 6.0:
			var rad: float = radii[i]
			draw_circle(b_pos, rad, Color(0.35, 1.0, 0.45, 0.75))
			draw_circle(b_pos + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.35, Color(0.9, 1.0, 0.9, 0.9))


func _draw_vampirico(c: Vector2) -> void:
	# Anillos de pulso de sangre
	var pulse := fmod(_time * 1.5, 1.0)
	draw_circle(c, 14.0 + pulse * 28.0, Color(0.9, 0.1, 0.2, (1.0 - pulse) * 0.4))
	# Gota de sangre estilizada
	var drop_pts := PackedVector2Array([
		c + Vector2(0, -22),
		c + Vector2(16, 6),
		c + Vector2(12, 18),
		c + Vector2(0, 24),
		c + Vector2(-12, 18),
		c + Vector2(-16, 6)
	])
	draw_colored_polygon(drop_pts, Color(0.88, 0.08, 0.16, 0.92))
	# Brillo interior
	draw_circle(c + Vector2(-4, 6), 5.0, Color(1.0, 0.4, 0.5, 0.8))


func _draw_explosivo(c: Vector2) -> void:
	var pulse := 0.9 + 0.1 * sin(_time * 8.0)
	draw_circle(c, 24.0 * pulse, Color(1.0, 0.4, 0.05, 0.3))
	draw_circle(c, 14.0 * pulse, Color(1.0, 0.8, 0.15, 0.6))
	# Puntas de explosión estelar
	var points := 10
	var star_pts := PackedVector2Array()
	for i in range(points * 2):
		var ang := float(i) * PI / float(points) + _time * 0.8
		var r := 28.0 if (i % 2 == 0) else 12.0
		star_pts.append(c + Vector2(cos(ang), sin(ang)) * r * pulse)
	draw_colored_polygon(star_pts, Color(1.0, 0.55, 0.1, 0.85))


func _draw_laser(c: Vector2) -> void:
	# Línea láser continua roja/cyan brillante
	var y_beam := c.y
	draw_line(Vector2(6, y_beam), Vector2(size.x - 6, y_beam), Color(1.0, 0.2, 0.2, 0.3), 8.0)
	draw_line(Vector2(6, y_beam), Vector2(size.x - 6, y_beam), Color(1.0, 0.4, 0.4, 0.9), 3.0)
	draw_line(Vector2(6, y_beam), Vector2(size.x - 6, y_beam), Color(1.0, 1.0, 1.0, 1.0), 1.0)
	# Retícula de puntería
	var reticle_col := Color(0.2, 0.9, 1.0, 0.85)
	draw_arc(c, 22.0, 0, TAU, 32, reticle_col, 1.5)
	draw_line(c + Vector2(0, -28), c + Vector2(0, -12), reticle_col, 1.5)
	draw_line(c + Vector2(0, 12), c + Vector2(0, 28), reticle_col, 1.5)
	draw_line(c + Vector2(-28, 0), c + Vector2(-12, 0), reticle_col, 1.5)
	draw_line(c + Vector2(12, 0), c + Vector2(28, 0), reticle_col, 1.5)
	draw_circle(c, 3.0, Color.WHITE)


func _draw_glitch(c: Vector2) -> void:
	var glitch_shift := sin(_time * 12.0) * 6.0
	# Bloque cian
	draw_rect(Rect2(c + Vector2(-28 + glitch_shift, -14), Vector2(50, 24)), Color(0.1, 0.9, 1.0, 0.5))
	# Bloque magenta
	draw_rect(Rect2(c + Vector2(-22 - glitch_shift, -8), Vector2(50, 24)), Color(1.0, 0.15, 0.8, 0.5))
	# Scanlines
	for i in 6:
		var y_scan := c.y - 20 + i * 8.0
		draw_line(Vector2(8, y_scan), Vector2(size.x - 8, y_scan), Color(0.9, 1.0, 1.0, 0.25), 1.0)
	# Texto de error pixelado
	draw_rect(Rect2(c + Vector2(-14, -6), Vector2(28, 12)), Color.WHITE)


func _draw_rebote(c: Vector2) -> void:
	# Paredes reflectoras en los bordes
	var wall_col := Color(0.4, 0.7, 1.0, 0.6)
	draw_line(Vector2(20, 12), Vector2(20, size.y - 12), wall_col, 4.0)
	draw_line(Vector2(size.x - 20, 12), Vector2(size.x - 20, size.y - 12), wall_col, 4.0)
	# Trayectoria zig zag
	var p1 := Vector2(22, size.y - 24)
	var p2 := Vector2(size.x - 22, c.y - 6)
	var p3 := Vector2(c.x + 10, 16)
	draw_line(p1, p2, Color(0.2, 0.95, 1.0, 0.9), 2.5)
	draw_line(p2, p3, Color(0.2, 0.95, 1.0, 0.9), 2.5)
	# Chispas de rebote
	draw_circle(p1, 5.0, Color(1.0, 1.0, 0.4, 0.9))
	draw_circle(p2, 6.0, Color(1.0, 1.0, 0.4, 1.0))
	draw_circle(p3, 4.0, Color(0.2, 0.95, 1.0, 1.0))


func _draw_pesado(c: Vector2) -> void:
	# Bala maciza de plomo
	var bullet_col := Color(0.75, 0.78, 0.85, 0.95)
	var b_pts := PackedVector2Array([
		c + Vector2(0, -22),
		c + Vector2(16, -6),
		c + Vector2(16, 18),
		c + Vector2(-16, 18),
		c + Vector2(-16, -6)
	])
	draw_colored_polygon(b_pts, bullet_col)
	draw_polyline(b_pts, Color(0.2, 0.25, 0.35, 1.0), 2.0)
	# Chevrons de peso hacia abajo
	var chev_col := Color(1.0, 0.4, 0.2, 0.8)
	for i in 2:
		var y_ch := c.y + 2 + i * 8.0
		draw_line(c + Vector2(-10, y_ch), c + Vector2(0, y_ch + 6), chev_col, 2.0)
		draw_line(c + Vector2(0, y_ch + 6), c + Vector2(10, y_ch), chev_col, 2.0)


func _draw_rapido(c: Vector2) -> void:
	# Líneas de estela doradas
	var gold := Color(1.0, 0.88, 0.25, 0.9)
	for i in 3:
		var y_l := c.y - 12 + i * 12.0
		var x_len := 30.0 + i * 10.0
		var off := fmod(_time * 60.0 + i * 14.0, 30.0)
		draw_line(Vector2(c.x - 36 + off, y_l), Vector2(c.x - 36 + off + x_len, y_l), Color(1.0, 0.85, 0.2, 0.4), 2.0)
	# Punta aerodinámica
	var tip_pts := PackedVector2Array([
		c + Vector2(28, 0),
		c + Vector2(-6, -14),
		c + Vector2(2, 0),
		c + Vector2(-6, 14)
	])
	draw_colored_polygon(tip_pts, gold)


func _draw_cristal(c: Vector2) -> void:
	# Fragmentos de cristal fracturado gélido
	var col_ice := Color(0.65, 0.92, 1.0, 0.85)
	var col_glow := Color(0.9, 0.98, 1.0, 1.0)
	var shard1 := PackedVector2Array([c + Vector2(0, -24), c + Vector2(14, -6), c + Vector2(-4, 4)])
	var shard2 := PackedVector2Array([c + Vector2(-20, -10), c + Vector2(-4, 6), c + Vector2(-16, 20)])
	var shard3 := PackedVector2Array([c + Vector2(6, 6), c + Vector2(22, 14), c + Vector2(0, 24)])
	draw_colored_polygon(shard1, col_ice)
	draw_polyline(shard1, col_glow, 1.5)
	draw_colored_polygon(shard2, col_ice * 0.85)
	draw_polyline(shard2, col_glow, 1.5)
	draw_colored_polygon(shard3, col_ice * 0.95)
	draw_polyline(shard3, col_glow, 1.5)


func _draw_roulette(c: Vector2) -> void:
	# Tambor de revólver
	draw_arc(c, 25.0, 0, TAU, 32, Color(0.7, 0.75, 0.82, 0.85), 2.0)
	draw_circle(c, 5.0, Color(0.5, 0.55, 0.65, 1.0))
	# 6 recámaras
	for i in 6:
		var ang := float(i) * TAU / 6.0
		var pos := c + Vector2(cos(ang), sin(ang)) * 16.0
		if i == 0:
			# Bala letal cargada al rojo vivo
			draw_circle(pos, 5.0, Color(1.0, 0.2, 0.2, 0.95))
			draw_circle(pos, 2.0, Color(1.0, 0.9, 0.9, 1.0))
		else:
			draw_circle(pos, 4.0, Color(0.1, 0.12, 0.18, 0.9))
			draw_arc(pos, 4.0, 0, TAU, 16, Color(0.4, 0.45, 0.55, 0.7), 1.0)


func _draw_fantasma(c: Vector2) -> void:
	# Muro intermedio segmentado
	for i in 4:
		var y_w: float = 14.0 + float(i) * 14.0
		draw_line(Vector2(c.x, y_w), Vector2(c.x, y_w + 8.0), Color(0.6, 0.6, 0.7, 0.5), 5.0)
	# Bala espectral que atraviesa
	var ghost_col := Color(0.75, 0.5, 1.0, 0.75)
	draw_circle(c + Vector2(8, 0), 12.0, ghost_col)
	draw_circle(c + Vector2(8, 0), 6.0, Color(0.9, 0.8, 1.0, 0.9))
	# Ondas etéreas
	draw_arc(c + Vector2(-8, 0), 16.0, -PI/2, PI/2, 16, Color(0.7, 0.4, 1.0, 0.4), 2.0)


func _draw_demolicion(c: Vector2) -> void:
	# Bloque agrietándose
	var block_rect := Rect2(c - Vector2(24, 20), Vector2(48, 40))
	draw_rect(block_rect, Color(0.4, 0.35, 0.3, 0.9))
	draw_rect(block_rect, Color(0.8, 0.5, 0.2, 0.9), false, 2.0)
	# Grietas de impacto
	draw_line(c + Vector2(-16, -14), c + Vector2(4, -2), Color(1.0, 0.8, 0.3, 1.0), 2.0)
	draw_line(c + Vector2(4, -2), c + Vector2(18, 12), Color(1.0, 0.8, 0.3, 1.0), 2.0)
	draw_line(c + Vector2(4, -2), c + Vector2(-8, 14), Color(1.0, 0.8, 0.3, 1.0), 2.0)


func _draw_default(c: Vector2) -> void:
	draw_circle(c, 18.0, Color(border_color.r, border_color.g, border_color.b, 0.25))
	draw_arc(c, 22.0, 0, TAU, 32, border_color, 1.5)
	draw_circle(c, 4.0, border_color)

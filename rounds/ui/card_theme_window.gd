extends Control

@export var tema: StringName = &"default"
@export var border_color: Color = Color(0.25, 0.8, 1.0, 0.8)
@export var is_mini: bool = false

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
	var mini: bool = is_mini or size.x < 90.0

	# Fondo oscuro de la ventana
	draw_rect(rect, Color(0.03, 0.04, 0.07, 0.96))
	# Borde sutil
	draw_rect(rect, Color(border_color.r, border_color.g, border_color.b, 0.45 if mini else 0.35), false, 1.5 if mini else 1.0)

	# Corchetes en las esquinas de la ventana
	var arm := 6.0 if mini else 12.0
	var thick := 1.5 if mini else 2.0
	var bracket_col := border_color
	# Superior Izquierda
	draw_line(Vector2(3, 3), Vector2(3 + arm, 3), bracket_col, thick)
	draw_line(Vector2(3, 3), Vector2(3, 3 + arm), bracket_col, thick)
	# Superior Derecha
	draw_line(Vector2(size.x - 3, 3), Vector2(size.x - 3 - arm, 3), bracket_col, thick)
	draw_line(Vector2(size.x - 3, 3), Vector2(size.x - 3, 3 + arm), bracket_col, thick)
	# Inferior Izquierda
	draw_line(Vector2(3, size.y - 3), Vector2(3 + arm, size.y - 3), bracket_col, thick)
	draw_line(Vector2(3, size.y - 3), Vector2(3, size.y - 3 - arm), bracket_col, thick)
	# Inferior Derecha
	draw_line(Vector2(size.x - 3, size.y - 3), Vector2(size.x - 3 - arm, size.y - 3), bracket_col, thick)
	draw_line(Vector2(size.x - 3, size.y - 3), Vector2(size.x - 3, size.y - 3 - arm), bracket_col, thick)

	if mini:
		var sf := minf(size.x / 80.0, size.y / 80.0)
		draw_set_transform(c, 0.0, Vector2(sf, sf))
		c = Vector2.ZERO

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
		&"sismico":
			_draw_sismico(c)
		&"armadura":
			_draw_armadura(c)
		&"gravedad":
			_draw_gravedad(c)
		&"totem":
			_draw_totem(c)
		&"barrera":
			_draw_barrera(c)
		&"iman":
			_draw_iman(c)
		&"sangre":
			_draw_sangre(c)
		&"division":
			_draw_division(c)
		&"ricochet":
			_draw_ricochet(c)
		&"bala_grande":
			_draw_bala_grande(c)
		&"minas":
			_draw_minas(c)
		&"regeneracion":
			_draw_regeneracion(c)
		&"desenfunde":
			_draw_desenfunde(c)
		&"electrico":
			_draw_electrico(c)
		&"contragolpe":
			_draw_contragolpe(c)
		&"onda":
			_draw_onda(c)
		&"titanico":
			_draw_titanico(c)
		&"sangrado":
			_draw_sangrado(c)
		&"deuda":
			_draw_deuda(c)
		&"anclaje":
			_draw_anclaje(c)
		&"tiempo":
			_draw_tiempo(c)
		&"piel":
			_draw_piel(c)
		&"vitalidad":
			_draw_vitalidad(c)
		&"corazon":
			_draw_corazon(c)
		_:
			_draw_default(c)

	if mini:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
		if absf(b_pos.y - c.y) < 28.0:
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
	var x1 := -44.0 if c == Vector2.ZERO else 6.0
	var x2 := 44.0 if c == Vector2.ZERO else size.x - 6.0
	draw_line(Vector2(x1, y_beam), Vector2(x2, y_beam), Color(1.0, 0.2, 0.2, 0.3), 8.0)
	draw_line(Vector2(x1, y_beam), Vector2(x2, y_beam), Color(1.0, 0.4, 0.4, 0.9), 3.0)
	draw_line(Vector2(x1, y_beam), Vector2(x2, y_beam), Color(1.0, 1.0, 1.0, 1.0), 1.0)
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
	var x1 := -36.0 if c == Vector2.ZERO else 8.0
	var x2 := 36.0 if c == Vector2.ZERO else size.x - 8.0
	for i in 6:
		var y_scan := c.y - 20 + i * 8.0
		draw_line(Vector2(x1, y_scan), Vector2(x2, y_scan), Color(0.9, 1.0, 1.0, 0.25), 1.0)
	# Texto de error pixelado
	draw_rect(Rect2(c + Vector2(-14, -6), Vector2(28, 12)), Color.WHITE)


func _draw_rebote(c: Vector2) -> void:
	# Paredes reflectoras en los bordes
	var wall_col := Color(0.4, 0.7, 1.0, 0.6)
	var x1 := -34.0 if c == Vector2.ZERO else 20.0
	var x2 := 34.0 if c == Vector2.ZERO else size.x - 20.0
	var y1 := -28.0 if c == Vector2.ZERO else 12.0
	var y2 := 28.0 if c == Vector2.ZERO else size.y - 12.0
	draw_line(Vector2(x1, y1), Vector2(x1, y2), wall_col, 4.0)
	draw_line(Vector2(x2, y1), Vector2(x2, y2), wall_col, 4.0)
	# Trayectoria zig zag
	var p1 := Vector2(x1 + 2.0, y2 - 8.0)
	var p2 := Vector2(x2 - 2.0, c.y - 4.0)
	var p3 := Vector2(c.x + 8.0, y1 + 4.0)
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
		var y_w: float = c.y - 21.0 + float(i) * 14.0
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


func _draw_sismico(c: Vector2) -> void:
	var pulse := 0.85 + 0.15 * sin(_time * 6.0)
	var col := Color(1.0, 0.6, 0.2, 0.85)
	for i in 3:
		var r := (10.0 + float(i) * 10.0) * pulse
		draw_arc(c, r, 0, TAU, 24, Color(col.r, col.g, col.b, 0.7 - float(i) * 0.2), 2.0)
	draw_circle(c, 5.0, Color(1.0, 0.8, 0.3, 1.0))


func _draw_armadura(c: Vector2) -> void:
	var shield_pts := PackedVector2Array([
		c + Vector2(0, -22), c + Vector2(18, -14), c + Vector2(16, 6),
		c + Vector2(0, 24), c + Vector2(-16, 6), c + Vector2(-18, -14)
	])
	draw_colored_polygon(shield_pts, Color(0.2, 0.3, 0.45, 0.85))
	draw_polyline(shield_pts, Color(0.4, 0.8, 1.0, 0.95), 2.0)
	draw_line(c + Vector2(0, -18), c + Vector2(0, 18), Color(0.6, 0.9, 1.0, 0.6), 1.5)


func _draw_gravedad(c: Vector2) -> void:
	var pulse := fmod(_time * 1.8, 1.0)
	var col_void := Color(0.55, 0.2, 0.9, 0.8)
	draw_circle(c, 10.0, Color(0.05, 0.02, 0.1, 0.95))
	draw_circle(c, 4.0, Color(0.7, 0.4, 1.0, 0.9))
	for i in 3:
		var r := 12.0 + fmod(pulse + float(i) * 0.33, 1.0) * 22.0
		var alpha := 1.0 - (r / 34.0)
		draw_arc(c, r, 0, TAU, 24, Color(col_void.r, col_void.g, col_void.b, alpha * 0.7), 1.5)


func _draw_totem(c: Vector2) -> void:
	var totem_col := Color(0.2, 0.85, 0.4, 0.9)
	var post_pts := PackedVector2Array([
		c + Vector2(-6, 20), c + Vector2(6, 20), c + Vector2(4, -8), c + Vector2(-4, -8)
	])
	draw_colored_polygon(post_pts, Color(0.3, 0.4, 0.35, 0.9))
	# Cristal flotante
	var y_off := sin(_time * 3.0) * 3.0
	var crys_pts := PackedVector2Array([
		c + Vector2(0, -22 + y_off), c + Vector2(7, -14 + y_off),
		c + Vector2(0, -6 + y_off), c + Vector2(-7, -14 + y_off)
	])
	draw_colored_polygon(crys_pts, totem_col)
	draw_polyline(crys_pts, Color.WHITE, 1.5)


func _draw_barrera(c: Vector2) -> void:
	var col := Color(0.2, 0.75, 1.0, 0.85)
	# Hexágono de barrera
	var hex := PackedVector2Array()
	for a in 6:
		var ang := float(a) * TAU / 6.0 + PI / 6.0
		hex.append(c + Vector2(cos(ang), sin(ang)) * 22.0)
	hex.append(hex[0])
	draw_polyline(hex, col, 2.0)
	draw_circle(c, 6.0, Color(col.r, col.g, col.b, 0.5))


func _draw_iman(c: Vector2) -> void:
	# Herradura magnética
	var p_left := c + Vector2(-16, -14)
	var p_right := c + Vector2(16, -14)
	var col_u := Color(0.85, 0.2, 0.25, 0.9)
	var col_s := Color(0.2, 0.45, 0.95, 0.9)
	draw_arc(c + Vector2(0, 4), 16.0, 0, PI, 16, Color(0.6, 0.65, 0.7, 0.9), 5.0)
	draw_line(p_left + Vector2(0, 6), p_left + Vector2(0, 18), col_u, 5.0)
	draw_line(p_right + Vector2(0, 6), p_right + Vector2(0, 18), col_s, 5.0)
	# Líneas de campo
	var pulse := fmod(_time * 2.0, 1.0)
	draw_arc(c + Vector2(0, -10), 10.0 + pulse * 14.0, PI * 0.2, PI * 0.8, 12, Color(1.0, 1.0, 0.4, (1.0 - pulse) * 0.7), 1.5)


func _draw_sangre(c: Vector2) -> void:
	var pulse := 0.85 + 0.15 * sin(_time * 4.0)
	var col := Color(0.85, 0.08, 0.15, 0.9)
	draw_circle(c, 18.0 * pulse, Color(col.r, col.g, col.b, 0.25))
	var drop_pts := PackedVector2Array([
		c + Vector2(0, -18), c + Vector2(14, 4), c + Vector2(0, 18), c + Vector2(-14, 4)
	])
	draw_colored_polygon(drop_pts, col)
	draw_circle(c + Vector2(-3, 2), 4.0, Color(1.0, 0.4, 0.4, 0.8))


func _draw_division(c: Vector2) -> void:
	var f_col := Color(0.2, 0.95, 1.0, 0.9)
	# Bala original a la izquierda
	draw_circle(c + Vector2(-20, 0), 6.0, Color(1.0, 1.0, 1.0, 0.9))
	# Tres fragmentos saliendo en abanico
	var dirs: Array[Vector2] = [Vector2(1, -0.7), Vector2(1, 0), Vector2(1, 0.7)]
	for d in dirs:
		var end: Vector2 = c + d.normalized() * 26.0
		draw_line(c + Vector2(-10, 0), end, Color(f_col.r, f_col.g, f_col.b, 0.55), 2.0)
		draw_circle(end, 5.0, f_col)


func _draw_ricochet(c: Vector2) -> void:
	# Trayectoria de rebotes que se potencia
	var pts := PackedVector2Array([
		c + Vector2(-28, 16), c + Vector2(-13, -6), c + Vector2(2, 10),
		c + Vector2(14, -12), c + Vector2(24, 2)
	])
	draw_polyline(pts, Color(0.2, 0.95, 1.0, 0.85), 2.5)
	for p in pts:
		draw_circle(p, 3.0, Color(1.0, 1.0, 0.4, 0.9))
	# Proyectil final potenciado
	draw_circle(c + Vector2(24, 2), 7.0, Color(1.0, 0.85, 0.3, 0.95))
	# Chevrones de potencia
	var chev := Color(1.0, 0.6, 0.1, 0.9)
	draw_line(c + Vector2(4, -22), c + Vector2(14, -22), chev, 2.0)
	draw_line(c + Vector2(9, -17), c + Vector2(19, -17), chev, 2.0)


func _draw_bala_grande(c: Vector2) -> void:
	var body := Color(0.8, 0.83, 0.9, 0.98)
	var big := PackedVector2Array([
		c + Vector2(-22, -20), c + Vector2(12, -20), c + Vector2(26, 0),
		c + Vector2(12, 20), c + Vector2(-22, 20)
	])
	draw_colored_polygon(big, body)
	draw_polyline(big, Color(0.3, 0.35, 0.45, 1.0), 2.0)
	# Bandas de contundencia
	draw_line(c + Vector2(-22, -7), c + Vector2(8, -7), Color(0.6, 0.65, 0.75, 0.8), 1.5)
	draw_line(c + Vector2(-22, 7), c + Vector2(8, 7), Color(0.6, 0.65, 0.75, 0.8), 1.5)
	# Líneas de impacto detrás
	draw_line(c + Vector2(-30, -12), c + Vector2(-24, -12), Color(1.0, 0.6, 0.2, 0.7), 2.0)
	draw_line(c + Vector2(-30, 12), c + Vector2(-24, 12), Color(1.0, 0.6, 0.2, 0.7), 2.0)


func _draw_minas(c: Vector2) -> void:
	# Cuerpo de la mina de proximidad
	draw_circle(c, 13.0, Color(0.25, 0.3, 0.35, 0.95))
	draw_arc(c, 13.0, 0, TAU, 24, Color(0.5, 0.55, 0.62, 0.9), 2.0)
	# Sensores / púas
	for i in 8:
		var ang := float(i) * TAU / 8.0
		var a := c + Vector2(cos(ang), sin(ang)) * 13.0
		var b := c + Vector2(cos(ang), sin(ang)) * 21.0
		draw_line(a, b, Color(0.4, 0.45, 0.5, 0.9), 2.0)
	# LED parpadeante
	var blink := 0.5 + 0.5 * sin(_time * 8.0)
	draw_circle(c, 4.5, Color(1.0, 0.15, 0.15, blink))
	draw_circle(c, 2.0, Color(1.0, 0.8, 0.8, 0.9))


func _draw_regeneracion(c: Vector2) -> void:
	var col := Color(0.3, 0.95, 0.45, 0.95)
	# Corazón
	var heart := PackedVector2Array([
		c + Vector2(0, 16), c + Vector2(-16, -2), c + Vector2(-16, -12),
		c + Vector2(-8, -18), c + Vector2(0, -10),
		c + Vector2(8, -18), c + Vector2(16, -12), c + Vector2(16, -2)
	])
	draw_colored_polygon(heart, col)
	# Cruz de regeneración
	draw_line(c + Vector2(0, -6), c + Vector2(0, 8), Color.WHITE, 3.0)
	draw_line(c + Vector2(-7, 1), c + Vector2(7, 1), Color.WHITE, 3.0)
	# Anillo de pulso
	var pulse := fmod(_time * 1.5, 1.0)
	draw_arc(c, 14.0 + pulse * 14.0, 0, TAU, 24, Color(0.4, 1.0, 0.5, (1.0 - pulse) * 0.5), 2.0)


func _draw_desenfunde(c: Vector2) -> void:
	var steel := Color(0.7, 0.75, 0.82, 0.95)
	# Cañón
	draw_rect(Rect2(c + Vector2(-18, -6), Vector2(34, 10)), steel)
	# Empuñadura
	draw_rect(Rect2(c + Vector2(-16, 4), Vector2(12, 18)), Color(0.4, 0.35, 0.3, 0.95))
	# Fogonazo del primer tiro
	var flash := PackedVector2Array([
		c + Vector2(18, -1), c + Vector2(30, -9), c + Vector2(34, -1), c + Vector2(30, 7)
	])
	draw_colored_polygon(flash, Color(1.0, 0.9, 0.3, 0.95))
	# Estela de velocidad
	draw_line(c + Vector2(-32, -1), c + Vector2(-20, -1), Color(1.0, 0.85, 0.2, 0.7), 2.0)


func _draw_electrico(c: Vector2) -> void:
	var bolt := PackedVector2Array([
		c + Vector2(5, -24), c + Vector2(-12, 2), c + Vector2(0, 2),
		c + Vector2(-6, 24), c + Vector2(14, -4), c + Vector2(2, -4)
	])
	# Resplandor
	draw_colored_polygon(bolt, Color(0.5, 0.9, 1.0, 0.35))
	# Rayo
	draw_colored_polygon(bolt, Color(1.0, 0.95, 0.3, 0.95))
	draw_polyline(bolt, Color(1.0, 1.0, 0.9, 1.0), 1.5)
	# Chispas
	var spark := 0.5 + 0.5 * sin(_time * 10.0)
	draw_circle(c + Vector2(-18, -14), 3.0, Color(0.6, 0.95, 1.0, spark))
	draw_circle(c + Vector2(18, 14), 3.0, Color(0.6, 0.95, 1.0, spark))


func _draw_contragolpe(c: Vector2) -> void:
	# Escudo enfrentando la embestida
	var shield := PackedVector2Array([
		c + Vector2(6, -22), c + Vector2(22, -10), c + Vector2(22, 10), c + Vector2(6, 22)
	])
	draw_colored_polygon(shield, Color(0.2, 0.45, 0.6, 0.85))
	draw_polyline(shield, Color(0.4, 0.85, 1.0, 0.95), 2.0)
	# Explosión radial del parry hacia atrás
	var pulse := 0.85 + 0.15 * sin(_time * 7.0)
	for i in 3:
		draw_arc(c + Vector2(2, 0), (10.0 + i * 8.0) * pulse, PI * 0.6, PI * 1.4, 16, Color(1.0, 0.6, 0.2, 0.7 - i * 0.2), 2.0)
	draw_circle(c + Vector2(-20, 0), 5.0, Color(1.0, 0.8, 0.3, 1.0))


func _draw_onda(c: Vector2) -> void:
	var col := Color(0.4, 0.8, 1.0, 0.85)
	var pulse := fmod(_time * 1.6, 1.0)
	# Anillos segmentados que se expanden
	for i in 3:
		var r := 10.0 + float(i) * 8.0
		var alpha := 0.8 - float(i) * 0.2
		for k in 4:
			var a0 := float(k) * TAU / 4.0 + pulse * TAU / 4.0
			draw_arc(c, r, a0, a0 + TAU / 8.0, 8, Color(col.r, col.g, col.b, alpha), 2.5)
	draw_circle(c, 4.0, Color.WHITE)


func _draw_titanico(c: Vector2) -> void:
	var skin := Color(0.85, 0.65, 0.45, 0.95)
	# Puño
	draw_rect(Rect2(c + Vector2(-16, -12), Vector2(28, 24)), skin)
	draw_circle(c + Vector2(-14, 0), 12.0, skin)
	# Nudillos
	for i in 3:
		draw_circle(c + Vector2(6, -8 + i * 8), 4.0, Color(0.72, 0.52, 0.36, 1.0))
	# Líneas de impacto
	var imp := Color(1.0, 0.7, 0.2, 0.9)
	draw_line(c + Vector2(18, -14), c + Vector2(26, -20), imp, 2.0)
	draw_line(c + Vector2(20, 0), c + Vector2(30, 0), imp, 2.0)
	draw_line(c + Vector2(18, 14), c + Vector2(26, 20), imp, 2.0)


func _draw_sangrado(c: Vector2) -> void:
	var col := Color(0.85, 0.1, 0.15, 0.95)
	# Gota principal
	var drop := PackedVector2Array([
		c + Vector2(0, -20), c + Vector2(12, 0), c + Vector2(0, 16), c + Vector2(-12, 0)
	])
	draw_colored_polygon(drop, col)
	# Goteo continuo bajo el centro
	for i in 3:
		var dy := fmod(_time * 26.0 + i * 12.0, 30.0)
		draw_circle(c + Vector2(0, 16 + dy), 3.5 - i * 0.6, Color(col.r, col.g, col.b, 0.8 - i * 0.2))


func _draw_deuda(c: Vector2) -> void:
	var frame := Color(0.6, 0.62, 0.7, 0.9)
	var blood := Color(0.85, 0.1, 0.15, 0.95)
	# Marco del reloj de arena
	draw_line(c + Vector2(-14, -20), c + Vector2(14, -20), frame, 3.0)
	draw_line(c + Vector2(-14, 20), c + Vector2(14, 20), frame, 3.0)
	# Arena (sangre) arriba y abajo
	draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -17), c + Vector2(11, -17), c + Vector2(0, -2)]), blood)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 2), c + Vector2(11, 17), c + Vector2(-11, 17)]), blood)
	# Vidrio
	draw_line(c + Vector2(-14, -20), c + Vector2(0, 0), frame, 1.5)
	draw_line(c + Vector2(14, -20), c + Vector2(0, 0), frame, 1.5)
	draw_line(c + Vector2(0, 0), c + Vector2(-14, 20), frame, 1.5)
	draw_line(c + Vector2(0, 0), c + Vector2(14, 20), frame, 1.5)


func _draw_anclaje(c: Vector2) -> void:
	var col := Color(0.5, 0.55, 0.65, 0.95)
	# Anilla superior
	draw_arc(c + Vector2(0, -18), 5.0, 0, TAU, 16, col, 2.5)
	# Eje
	draw_line(c + Vector2(0, -13), c + Vector2(0, 16), col, 3.0)
	# Travesaño
	draw_line(c + Vector2(-11, -8), c + Vector2(11, -8), col, 3.0)
	# Arcos inferiores
	draw_arc(c + Vector2(0, 6), 12.0, PI * 0.15, PI * 0.85, 16, col, 3.0)
	# Puntas
	draw_line(c + Vector2(-11, 10), c + Vector2(-8, 16), col, 2.5)
	draw_line(c + Vector2(11, 10), c + Vector2(8, 16), col, 2.5)
	# Campo de anclaje
	var pulse := fmod(_time * 1.5, 1.0)
	draw_arc(c, 18.0 + pulse * 8.0, 0, TAU, 24, Color(0.4, 0.8, 1.0, (1.0 - pulse) * 0.5), 1.5)


func _draw_tiempo(c: Vector2) -> void:
	var face := Color(0.85, 0.9, 1.0, 0.95)
	draw_circle(c, 21.0, Color(0.08, 0.12, 0.22, 0.92))
	draw_arc(c, 21.0, 0, TAU, 32, face, 2.0)
	# Marcas
	for i in 12:
		var ang := float(i) * TAU / 12.0
		var a := c + Vector2(cos(ang), sin(ang)) * 16.0
		var b := c + Vector2(cos(ang), sin(ang)) * 19.0
		draw_line(a, b, Color(face.r, face.g, face.b, 0.7), 1.5)
	# Agujas
	var t := _time * 1.2
	draw_line(c, c + Vector2(cos(-PI / 2 + t), sin(-PI / 2 + t)) * 12.0, Color(1.0, 0.4, 0.4, 1.0), 2.0)
	draw_line(c, c + Vector2(cos(-PI / 2 + t * 3.0), sin(-PI / 2 + t * 3.0)) * 9.0, Color.WHITE, 2.0)


func _draw_piel(c: Vector2) -> void:
	# Capas de piel endurecida
	for i in 3:
		var w := 40.0 - i * 8.0
		var y := -14.0 + i * 12.0
		var r := Rect2(c + Vector2(-w * 0.5, y), Vector2(w, 10))
		draw_rect(r, Color(0.55 - i * 0.08, 0.38, 0.28, 0.95))
		draw_rect(r, Color(0.8, 0.6, 0.4, 0.6), false, 1.5)
	# Sello de resistencia
	draw_circle(c + Vector2(0, -21), 4.0, Color(0.3, 1.0, 0.45, 0.9))


func _draw_vitalidad(c: Vector2) -> void:
	# Cruz médica sólida (vida plana)
	var col := Color(0.95, 0.3, 0.35, 0.95)
	draw_rect(Rect2(c + Vector2(-7, -20), Vector2(14, 40)), col)
	draw_rect(Rect2(c + Vector2(-20, -7), Vector2(40, 14)), col)
	draw_rect(Rect2(c + Vector2(-7, -20), Vector2(14, 40)), Color.WHITE, false, 1.5)
	draw_rect(Rect2(c + Vector2(-20, -7), Vector2(40, 14)), Color.WHITE, false, 1.5)


func _draw_corazon(c: Vector2) -> void:
	var col := Color(0.9, 0.15, 0.3, 0.95)
	var heart := PackedVector2Array([
		c + Vector2(0, 18), c + Vector2(-18, -2), c + Vector2(-18, -12),
		c + Vector2(-9, -19), c + Vector2(0, -11),
		c + Vector2(9, -19), c + Vector2(18, -12), c + Vector2(18, -2)
	])
	draw_colored_polygon(heart, col)
	draw_polyline(heart, Color(1.0, 0.6, 0.65, 0.8), 1.5)
	# Signo +
	draw_line(c + Vector2(0, -7), c + Vector2(0, 9), Color.WHITE, 3.0)
	draw_line(c + Vector2(-8, 1), c + Vector2(8, 1), Color.WHITE, 3.0)
	# Destello de "extra"
	draw_circle(c + Vector2(20, -16), 3.0, Color(1.0, 0.9, 0.4, 0.9))


func _draw_default(c: Vector2) -> void:
	pass

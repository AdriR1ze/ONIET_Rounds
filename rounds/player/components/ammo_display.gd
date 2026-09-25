class_name AmmoDisplay
extends Node2D

const COLOR_AMMO := Color(1.0, 0.55, 0.12, 1.0) # Naranja calido de bala
const COLOR_AMMO_GLOW := Color(1.0, 0.78, 0.25, 0.45)
const COLOR_RELOAD_GRAY := Color(0.72, 0.75, 0.82, 1.0) # Gris de recarga
const COLOR_EMPTY_OUTLINE := Color(0.35, 0.38, 0.46, 0.45)

@export var dot_radius: float = 2.2
@export var dot_spacing: float = 6.0

var max_ammo: int = 3
var current_ammo: int = 3
var is_reloading: bool = false
var reload_progress: float = 0.0

var _weapon: WeaponComponent = null
var _flash_timer: float = 0.0


func _ready() -> void:
	_weapon = get_parent() as WeaponComponent
	if _weapon != null:
		_weapon.ammo_changed.connect(_on_ammo_changed)
		_weapon.reload_started.connect(_on_reload_started)
		_weapon.reload_completed.connect(_on_reload_completed)
		_weapon.fired.connect(queue_redraw)
		max_ammo = _weapon.max_ammo
		current_ammo = _weapon.current_ammo


func _process(delta: float) -> void:
	if _weapon != null and _weapon._player != null:
		var p = _weapon._player
		if p.get("current_state") == 4: # PlayerState.DEAD
			visible = false
			return
		else:
			visible = true

	if _weapon != null and _weapon.is_reloading:
		is_reloading = true
		if _weapon.has_method("get_reload_progress"):
			reload_progress = _weapon.get_reload_progress()
		elif _weapon.reload_time > 0.0:
			reload_progress = clampf(1.0 - (_weapon._reload_timer / _weapon.reload_time), 0.0, 1.0)
		queue_redraw()
	elif is_reloading and (_weapon == null or not _weapon.is_reloading):
		is_reloading = false
		queue_redraw()

	if _flash_timer > 0.0:
		_flash_timer -= delta
		queue_redraw()


func _on_ammo_changed(cur: int, maximum: int) -> void:
	current_ammo = cur
	max_ammo = maximum
	queue_redraw()


func _on_reload_started() -> void:
	is_reloading = true
	reload_progress = 0.0
	queue_redraw()


func _on_reload_completed() -> void:
	is_reloading = false
	current_ammo = max_ammo
	_flash_timer = 0.25
	queue_redraw()


func _draw() -> void:
	if max_ammo <= 0:
		return

	var spacing := dot_spacing
	if max_ammo > 4:
		spacing = minf(dot_spacing, 24.0 / float(max_ammo - 1))

	var total_w := float(max_ammo - 1) * spacing
	var start_x := -total_w * 0.5

	# Cuántos puntitos grises (balas ya recargadas) mostramos por encima de las actuales
	var refilled := 0
	if is_reloading:
		refilled = int(floor(reload_progress * float(maxi(max_ammo - current_ammo, 0))))

	for i in range(max_ammo):
		var center := Vector2(start_x + float(i) * spacing, 0.0)

		# Sombra exterior para contraste con el escenario
		draw_circle(center, dot_radius + 0.9, Color(0.06, 0.07, 0.1, 0.85))

		if is_reloading:
			if i < current_ammo:
				# Bala que ya tenés: sigue activa en naranja durante la recarga
				draw_circle(center, dot_radius, COLOR_AMMO)
			elif i < current_ammo + refilled:
				# Bala ya recargada en gris
				draw_circle(center, dot_radius, COLOR_RELOAD_GRAY)
			else:
				# Bala que todavía no se recargó
				draw_arc(center, dot_radius - 0.2, 0.0, TAU, 16, COLOR_EMPTY_OUTLINE, 1.0)
		else:
			if i < current_ammo:
				# Bala lista en naranja
				var col := COLOR_AMMO
				if _flash_timer > 0.0:
					col = Color(1.0, 0.88, 0.45, 1.0) # Destello al completar recarga
					draw_circle(center, dot_radius + 2.0, COLOR_AMMO_GLOW)
				draw_circle(center, dot_radius, col)
			else:
				# Bala gastada
				draw_arc(center, dot_radius - 0.2, 0.0, TAU, 16, COLOR_EMPTY_OUTLINE, 1.0)

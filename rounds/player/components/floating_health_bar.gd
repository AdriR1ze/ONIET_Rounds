class_name FloatingHealthBar
extends Node2D

@export var bar_width: float = 34.0
@export var bar_height: float = 4.0

var max_hp: float = 100.0
var current_hp: float = 100.0
var display_hp: float = 100.0
var lag_hp: float = 100.0

var fill_color: Color = Color(1.0, 0.85, 0.2, 1.0)
var lag_color: Color = Color(1.0, 1.0, 1.0, 0.85)
var bg_color: Color = Color(0.06, 0.07, 0.1, 0.88)
var border_color: Color = Color(0.18, 0.2, 0.26, 0.95)

var _fade_tween: Tween = null
var _lag_delay: float = 0.0


func _ready() -> void:
	modulate.a = 0.0
	visible = false


func setup(player_number: int, current: int, maximum: int) -> void:
	fill_color = RunManager.color_jugador(player_number)
	max_hp = float(maximum)
	current_hp = float(current)
	display_hp = current_hp
	lag_hp = current_hp
	_update_visibility(false)
	queue_redraw()


func update_health(new_health: int, maximum: int) -> void:
	max_hp = float(maximum)
	var prev_hp := current_hp
	current_hp = clampf(float(new_health), 0.0, max_hp)

	if current_hp < prev_hp:
		_lag_delay = 0.22
	else:
		lag_hp = current_hp

	_update_visibility(true)


func _update_visibility(animate: bool) -> void:
	var should_show := (current_hp < max_hp and current_hp > 0.0)

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	if should_show:
		visible = true
		if animate:
			_fade_tween = create_tween()
			_fade_tween.tween_property(self, "modulate:a", 1.0, 0.15)
		else:
			modulate.a = 1.0
	else:
		if animate:
			_fade_tween = create_tween()
			_fade_tween.tween_property(self, "modulate:a", 0.0, 0.35)
			_fade_tween.tween_callback(func(): visible = false)
		else:
			modulate.a = 0.0
			visible = false


func _process(delta: float) -> void:
	if not visible and modulate.a <= 0.0:
		return

	# Suave interpolacion hacia la vida actual
	display_hp = move_toward(display_hp, current_hp, delta * maxf(max_hp * 3.5, 220.0))

	# Barra de rezago de dano
	if _lag_delay > 0.0:
		_lag_delay -= delta
	else:
		lag_hp = move_toward(lag_hp, display_hp, delta * maxf(max_hp * 2.0, 110.0))

	queue_redraw()


func _draw() -> void:
	if max_hp <= 0.0:
		return

	var half_w := bar_width * 0.5
	var half_h := bar_height * 0.5

	# Marco exterior y fondo oscuro
	draw_rect(Rect2(-half_w - 1.0, -half_h - 1.0, bar_width + 2.0, bar_height + 2.0), border_color, false, 1.0)
	draw_rect(Rect2(-half_w, -half_h, bar_width, bar_height), bg_color, true)

	# Barra de rezago blanca
	var lag_ratio := clampf(lag_hp / max_hp, 0.0, 1.0)
	if lag_ratio > 0.0:
		draw_rect(Rect2(-half_w, -half_h, bar_width * lag_ratio, bar_height), lag_color, true)

	# Barra de vida actual con color del equipo
	var hp_ratio := clampf(display_hp / max_hp, 0.0, 1.0)
	if hp_ratio > 0.0:
		draw_rect(Rect2(-half_w, -half_h, bar_width * hp_ratio, bar_height), fill_color, true)

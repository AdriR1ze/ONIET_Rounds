extends CanvasLayer

signal terminado

@onready var _centro: CenterContainer = $Centro
@onready var _numero: Label = $Centro/Numero

const COLORES := {
	3: Color(1.0, 0.35, 0.3, 1.0),
	2: Color(1.0, 0.8, 0.25, 1.0),
	1: Color(0.4, 1.0, 0.45, 1.0),
}


func _ready() -> void:
	visible = false


func mostrar_countdown(segundos: int = 3) -> void:
	visible = true
	_numero.pivot_offset = _numero.custom_minimum_size / 2.0

	for i in range(segundos, 0, -1):
		_numero.text = str(i)
		_numero.modulate = COLORES.get(i, Color.WHITE)
		_centro.modulate.a = 1.0
		_numero.scale = Vector2(1.5, 1.5)

		var tween_entrada := create_tween()
		tween_entrada.tween_property(_numero, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tween_entrada.finished

		await get_tree().create_timer(0.72).timeout

		var tween_salida := create_tween()
		tween_salida.tween_property(_centro, "modulate:a", 0.0, 0.12)
		await tween_salida.finished

	visible = false
	terminado.emit()

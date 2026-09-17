extends Control

const NIVEL := "res://levels/test_level.tscn"

@onready var _menu: VBoxContainer = $Centro/Menu
@onready var _controles: ColorRect = $Controles
@onready var _boton_jugar: Button = $Centro/Menu/Jugar
@onready var _boton_controles: Button = $Centro/Menu/Controles
@onready var _boton_salir: Button = $Centro/Menu/Salir
@onready var _boton_volver: Button = $Controles/Centro/Marco/Margin/VBox/Volver


func _ready() -> void:
	get_tree().paused = false
	_controles.visible = false
	_boton_jugar.pressed.connect(_jugar)
	_boton_controles.pressed.connect(_mostrar_controles)
	_boton_salir.pressed.connect(_salir)
	_boton_volver.pressed.connect(_ocultar_controles)
	_menu.visible = true
	_boton_jugar.grab_focus()


func _jugar() -> void:
	RunManager.reiniciar()
	get_tree().change_scene_to_file(NIVEL)


func _mostrar_controles() -> void:
	_menu.visible = false
	_controles.visible = true
	_boton_volver.grab_focus()


func _ocultar_controles() -> void:
	_controles.visible = false
	_menu.visible = true
	_boton_controles.grab_focus()


func _salir() -> void:
	get_tree().quit()

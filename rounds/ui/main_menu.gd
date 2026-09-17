extends Control

const NIVEL := "res://levels/test_level.tscn"
const OPCIONES_RONDAS := [1, 2, 3, 5, 7]
const OPCIONES_VIDAS := [1, 2, 3, 4, 5]

@onready var _menu: VBoxContainer = $Centro/Menu
@onready var _controles: ColorRect = $Controles
@onready var _opciones: CanvasLayer = $OptionsScreen
@onready var _rondas: OptionButton = $Centro/Menu/Config/Rondas/Valor
@onready var _vidas: OptionButton = $Centro/Menu/Config/Vidas/Valor
@onready var _boton_jugar: Button = $Centro/Menu/Jugar
@onready var _boton_controles: Button = $Centro/Menu/Controles
@onready var _boton_opciones: Button = $Centro/Menu/Opciones
@onready var _boton_salir: Button = $Centro/Menu/Salir
@onready var _boton_volver: Button = $Controles/Centro/Marco/Margin/VBox/Volver


func _ready() -> void:
	get_tree().paused = false
	_controles.visible = false
	_poblar(_rondas, OPCIONES_RONDAS, RunManager.rondas_para_ganar)
	_poblar(_vidas, OPCIONES_VIDAS, RunManager.vidas_por_ronda)
	_boton_jugar.pressed.connect(_jugar)
	_boton_controles.pressed.connect(_mostrar_controles)
	_boton_opciones.pressed.connect(_mostrar_opciones)
	_boton_salir.pressed.connect(_salir)
	_boton_volver.pressed.connect(_ocultar_controles)
	_opciones.cerrado.connect(_ocultar_opciones)
	_menu.visible = true
	_boton_jugar.grab_focus()


func _jugar() -> void:
	RunManager.configurar_partida(_valor(_rondas, OPCIONES_RONDAS), _valor(_vidas, OPCIONES_VIDAS))
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


func _mostrar_opciones() -> void:
	_menu.visible = false
	_opciones.abrir()


func _ocultar_opciones() -> void:
	_menu.visible = true
	_boton_opciones.grab_focus()


func _salir() -> void:
	get_tree().quit()


func _poblar(boton: OptionButton, valores: Array, actual: int) -> void:
	boton.clear()
	for valor in valores:
		boton.add_item(str(valor))
	var indice: int = valores.find(actual)
	boton.selected = indice if indice >= 0 else 0


func _valor(boton: OptionButton, valores: Array) -> int:
	return int(valores[boton.selected])

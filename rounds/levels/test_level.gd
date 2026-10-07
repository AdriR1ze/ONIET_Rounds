extends Node2D

@onready var _restart_dialog: CanvasLayer = get_node_or_null("RestartConfirmDialog")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		if PauseManager.bloqueado():
			return
		if _restart_dialog != null:
			_restart_dialog.abrir()
		else:
			# RunManager es autoload: sin reiniciar() las mejoras sobreviven al
			# reload de escena y se reaplican al respawnear los jugadores.
			RunManager.reiniciar()
			Transition.recargar()

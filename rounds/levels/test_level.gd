extends Node2D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		# RunManager es autoload: sin reiniciar() las mejoras sobreviven al
		# reload de escena y se reaplican al respawnear los jugadores.
		RunManager.reiniciar()
		Transition.recargar()

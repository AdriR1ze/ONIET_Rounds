extends Node2D


func _ready() -> void:
	AudioManager.reproducir_musica("nivel")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()

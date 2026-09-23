class_name PlayerInput
extends Node

@export var player_number: int = 1

var _bot_brain: Node = null


func _ready() -> void:
	var value: Variant = get_parent().get("player_number")
	if value != null:
		player_number = int(value)
	if Settings.es_bot(player_number):
		var brain_script: Script = load("res://player/components/bot_brain.gd")
		if brain_script != null:
			_bot_brain = brain_script.new()
			_bot_brain.name = "BotBrain"
			add_child(_bot_brain)


func move_axis() -> float:
	if _bot_brain != null:
		return _bot_brain.get_move_axis()
	if _usa_raw_keyboard():
		return KeyboardSetup.raw_move_axis(_slot_teclado())
	return Input.get_axis(_action("left"), _action("right"))


func aim() -> Vector2:
	if _bot_brain != null:
		return _bot_brain.get_aim()
	if _usa_raw_keyboard():
		return KeyboardSetup.raw_aim(_slot_teclado())

	# Stick derecho: apuntado analogico libre (si el dispositivo lo tiene).
	if InputMap.has_action(_action("aim_left")):
		var stick := Input.get_vector(
			_action("aim_left"), _action("aim_right"),
			_action("aim_up"), _action("aim_down")
		)
		if stick.length_squared() > 0.0:
			return stick

	# Fallback digital (teclado / D-pad): 8 direcciones.
	var left := Input.is_action_pressed(_action("left"))
	var right := Input.is_action_pressed(_action("right"))
	var up := Input.is_action_pressed(_action("up"))
	var down := Input.is_action_pressed(_action("down"))

	var direction := Vector2.ZERO
	if left and not right:
		direction.x = -1.0
	elif right and not left:
		direction.x = 1.0
	if up and not down:
		direction.y = -1.0
	elif down and not up:
		direction.y = 1.0
	return direction


func is_jump_just_pressed() -> bool:
	if _bot_brain != null:
		return _bot_brain.is_jump_just_pressed()
	if _usa_raw_keyboard():
		return KeyboardSetup.raw_action_just_pressed(_slot_teclado(), "jump")
	return Input.is_action_just_pressed(_action("jump"))


func is_jump_just_released() -> bool:
	if _bot_brain != null:
		return _bot_brain.is_jump_just_released()
	if _usa_raw_keyboard():
		return KeyboardSetup.raw_action_just_released(_slot_teclado(), "jump")
	return Input.is_action_just_released(_action("jump"))


func is_crouch_pressed() -> bool:
	if _bot_brain != null:
		return false
	if _usa_raw_keyboard():
		return KeyboardSetup.raw_action_pressed(_slot_teclado(), "down")
	return Input.is_action_pressed(_action("down"))


func is_strafe_pressed() -> bool:
	if _bot_brain != null:
		return false
	if _usa_raw_keyboard():
		return KeyboardSetup.raw_action_pressed(_slot_teclado(), "strafe")
	return Input.is_action_pressed(_action("strafe"))


func is_fire_pressed() -> bool:
	if _bot_brain != null:
		return _bot_brain.is_fire_pressed()
	if _usa_raw_keyboard():
		return KeyboardSetup.raw_action_pressed(_slot_teclado(), "fire")
	return Input.is_action_pressed(_action("fire"))


func is_grab_just_pressed() -> bool:
	if _bot_brain != null:
		return false
	if _usa_raw_keyboard():
		return KeyboardSetup.raw_action_just_pressed(_slot_teclado(), "grab")
	return Input.is_action_just_pressed(_action("grab"))


func is_ragdoll_just_pressed() -> bool:
	if _bot_brain != null:
		return _bot_brain.is_ragdoll_just_pressed()
	if _usa_raw_keyboard():
		return KeyboardSetup.raw_action_just_pressed(_slot_teclado(), "ragdoll")
	return Input.is_action_just_pressed(_action("ragdoll"))


func is_quack_just_pressed() -> bool:
	if _bot_brain != null:
		return false
	if _usa_raw_keyboard():
		return KeyboardSetup.raw_action_just_pressed(_slot_teclado(), "quack")
	var act := _action("quack")
	return InputMap.has_action(act) and Input.is_action_just_pressed(act)


func is_lock_pressed() -> bool:
	if _bot_brain != null:
		return false
	if _usa_raw_keyboard():
		return KeyboardSetup.raw_action_pressed(_slot_teclado(), "lock")
	return Input.is_action_pressed(_action("lock"))


func _action(name: String) -> String:
	return "p%d_%s" % [player_number, name]


func _slot_teclado() -> int:
	return Settings.slot_teclado_de(player_number)


func _usa_raw_keyboard() -> bool:
	var slot := _slot_teclado()
	return slot >= 1 and slot <= 2 and KeyboardSetup.raw_input_activo()

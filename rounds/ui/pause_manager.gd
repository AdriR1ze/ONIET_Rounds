extends Node

signal pausa_cambiada(pausada: bool)

var _dueno: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func tomar(dueno: Node) -> bool:
	if _dueno != null and not is_instance_valid(_dueno):
		_dueno = null
	if _dueno != null and _dueno != dueno:
		return false
	_dueno = dueno
	_aplicar()
	return true


func soltar(dueno: Node) -> void:
	if _dueno != dueno:
		return
	_dueno = null
	_aplicar()


func activo() -> bool:
	return is_instance_valid(_dueno)


func bloqueado(dueno: Node = null) -> bool:
	return is_instance_valid(_dueno) and _dueno != dueno


func dueno_actual() -> Node:
	return _dueno if is_instance_valid(_dueno) else null


func _aplicar() -> void:
	var pausado := activo()
	get_tree().paused = pausado
	pausa_cambiada.emit(pausado)

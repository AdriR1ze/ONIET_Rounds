extends Node

## Carga todos los scripts .gd del proyecto y reporta los que fallan al
## compilar. Se corre como escena para que los autoloads estén registrados:
##   godot --headless --path rounds res://tools/validate_all.tscn
## Sale con código 1 si algún script no compila.

func _ready() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	files.sort()

	var checked := 0
	var failed: Array[String] = []
	for path in files:
		if not path.ends_with(".gd"):
			continue
		if path == "res://tools/validate_all.gd":
			continue
		checked += 1
		var res: Resource = ResourceLoader.load(path)
		var script := res as GDScript
		if script == null or not script.can_instantiate():
			failed.append(path)

	print("VALIDATE: checked %d scripts, %d failed" % [checked, failed.size()])
	for path in failed:
		print("VALIDATE FAIL: ", path)
	get_tree().quit(1 if failed.size() > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_collect(full, out)
		else:
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()

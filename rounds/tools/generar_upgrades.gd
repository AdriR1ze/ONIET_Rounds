extends SceneTree

const RUTA := "res://upgrades/definitions/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(RUTA)
	_generar()
	print("Mejoras generadas en ", RUTA)
	quit()


func _crear(id: StringName, titulo: String, descripcion: String, rareza: UpgradeDefinition.Rareza, peso: float, max_stacks: int, efectos: Array) -> void:
	var def := UpgradeDefinition.new()
	def.id = id
	def.titulo = titulo
	def.descripcion = descripcion
	def.rareza = rareza
	def.peso = peso
	def.max_stacks = max_stacks

	var lista_efectos: Array[UpgradeEffect] = []
	for efecto in efectos:
		lista_efectos.append(efecto)
	def.efectos = lista_efectos

	var error := ResourceSaver.save(def, RUTA + String(id) + ".tres")
	if error != OK:
		push_error("No se pudo guardar %s (%d)" % [id, error])


func _generar() -> void:
	var explosivo := ExplosiveEffect.new()
	explosivo.radius = 80.0
	explosivo.damage = 1
	_crear(&"explosivo", "Explosivo", "Las balas explotan al impactar (daño en área).",
		UpgradeDefinition.Rareza.LEGENDARIA, 1.0, 1, [explosivo])

	var vampirico := LifestealEffect.new()
	vampirico.amount = 1
	_crear(&"vampirico", "Vampírico", "Recuperas 1 de vida al golpear a un enemigo o jugador.",
		UpgradeDefinition.Rareza.EPICA, 1.0, 2, [vampirico])

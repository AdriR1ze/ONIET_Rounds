extends SceneTree

const RUTA := "res://upgrades/definitions/"

const ToxicCloudEffect = preload("res://upgrades/effects/toxic_cloud_effect.gd")
const DemolitionEffect = preload("res://upgrades/effects/demolition_effect.gd")
const SplitterEffect = preload("res://upgrades/effects/splitter_effect.gd")
const LaserSightEffect = preload("res://upgrades/effects/laser_sight_effect.gd")
const PhantomRoundsEffect = preload("res://upgrades/effects/phantom_rounds_effect.gd")
const HeavyBulletEffect = preload("res://upgrades/effects/heavy_bullet_effect.gd")
const RicochetMasterEffect = preload("res://upgrades/effects/ricochet_master_effect.gd")
const MinefieldEffect = preload("res://upgrades/effects/minefield_effect.gd")
const ExplosiveEffect = preload("res://upgrades/effects/explosive_effect.gd")
const LifestealEffect = preload("res://upgrades/effects/lifesteal_effect.gd")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(RUTA)
	_generar()
	print("Mejoras generadas en ", RUTA)
	quit()


func _mod(stat: StringName, op: StatModifier.Op, value: float) -> StatModifier:
	var m := StatModifier.new()
	m.stat = stat
	m.op = op
	m.value = value
	return m


func _crear(id: StringName, titulo: String, nivel: int, descripcion: String, rareza: UpgradeDefinition.Rareza, peso: float, max_stacks: int, stats: Array, efectos: Array) -> void:
	var def := UpgradeDefinition.new()
	def.id = id
	def.titulo = titulo
	def.nivel = nivel
	def.descripcion = descripcion
	def.rareza = rareza
	def.peso = peso
	def.max_stacks = max_stacks

	var lista_stats: Array[StatModifier] = []
	for st in stats:
		lista_stats.append(st)
	def.stats = lista_stats

	var lista_efectos: Array[UpgradeEffect] = []
	for efecto in efectos:
		lista_efectos.append(efecto)
	def.efectos = lista_efectos

	var error := ResourceSaver.save(def, RUTA + String(id) + ".tres")
	if error != OK:
		push_error("No se pudo guardar %s (%d)" % [id, error])


func _generar() -> void:
	# 1. Bouncy: Nivel 1 (Común)
	_crear(&"bouncy", "Bouncy", 1,
		"Tus balas rebotan en las superficies en vez de destruirse al impacto (+1 rebote, daño ligeramente reducido).",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[_mod(&"bounces", StatModifier.Op.ADD, 1.0), _mod(&"damage", StatModifier.Op.MULT, 0.85)],
		[])

	# 2. Toxic Cloud: Nivel 1 (Común)
	_crear(&"toxic_cloud", "Toxic Cloud", 1,
		"Genera una nube tóxica al impactar superficies o rivales (3 ticks de veneno con reinicio por permanencia).",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[_mod(&"fire_rate", StatModifier.Op.MULT, 0.85)],
		[ToxicCloudEffect.new()])

	# 3. Demolition Shot: Nivel 2 (Rara)
	_crear(&"demolition_shot", "Demolition Shot", 2,
		"Las balas perforan y destruyen fragmentos de plataformas o estructuras del escenario directamente al impactar.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"reload_time", StatModifier.Op.MULT, 1.35), _mod(&"pierce", StatModifier.Op.ADD, 1.0)],
		[DemolitionEffect.new()])

	# 4. Splitter: Nivel 1 (Común)
	_crear(&"splitter", "Splitter", 1,
		"La bala se divide en 3 fragmentos más chicos tras recorrer media distancia o tras el primer rebote.",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[_mod(&"damage", StatModifier.Op.MULT, 0.40)],
		[SplitterEffect.new()])

	# 5. Lead Slug: Nivel 2 (Rara)
	_crear(&"lead_slug", "Lead Slug", 2,
		"Balas pesadas con caída pronunciada, daño mejorado (+35%) y empuje cinético masivo (velocidad muy reducida).",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[
			_mod(&"damage", StatModifier.Op.MULT, 1.35),
			_mod(&"knockback", StatModifier.Op.ADD, 450.0),
			_mod(&"bullet_speed", StatModifier.Op.MULT, 0.65),
			_mod(&"bullet_gravity", StatModifier.Op.MULT, 1.60)
		],
		[])

	# 6. Laser Sight: Nivel 2 (Rara)
	_crear(&"laser_sight", "Laser Sight", 2,
		"Tus balas ya no tienen tiempo de viaje; impactan de forma instantánea en línea recta (hitscan, -1 bala en cargador).",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"max_ammo", StatModifier.Op.ADD, -1.0)],
		[LaserSightEffect.new()])

	# 7. Phantom Rounds: Nivel 2 (Rara)
	_crear(&"phantom_rounds", "Phantom Rounds", 2,
		"Las balas atraviesan la primera pared o estructura sólida del escenario sin destruirse (-15% de daño).",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"damage", StatModifier.Op.MULT, 0.85), _mod(&"wall_pierce", StatModifier.Op.ADD, 1.0)],
		[PhantomRoundsEffect.new()])

	# 8. Heavy Bullet: Nivel 1 (Común)
	_crear(&"heavy_bullet", "Heavy Bullet", 1,
		"Proyectiles más grandes (+60%) y contundentes (+30% daño) que aturden una fracción de segundo al rival.",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[
			_mod(&"damage", StatModifier.Op.MULT, 1.30),
			_mod(&"fire_rate", StatModifier.Op.MULT, 0.65),
			_mod(&"bullet_scale", StatModifier.Op.MULT, 1.60)
		],
		[HeavyBulletEffect.new()])

	# 9. Ricochet Master: Nivel 3 (Rara)
	_crear(&"ricochet_master", "Ricochet Master", 3,
		"+2 rebotes. Cada rebote que realiza la bala antes de tocar al rival incrementa notablemente (+45%) el daño final.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"bounces", StatModifier.Op.ADD, 2.0), _mod(&"damage", StatModifier.Op.MULT, 0.80)],
		[RicochetMasterEffect.new()])

	# 10. Minefield: Nivel 4 (Épica)
	_crear(&"minefield", "Minefield", 4,
		"Las balas que tocan el suelo y no impactan a un rival se plantan como minas de proximidad activas durante 6 segundos.",
		UpgradeDefinition.Rareza.EPICA, 1.0, 1,
		[_mod(&"reload_time", StatModifier.Op.MULT, 1.60)],
		[MinefieldEffect.new()])

	# Anteriores preservadas con sus niveles
	var explosivo := ExplosiveEffect.new()
	explosivo.radius = 80.0
	_crear(&"explosivo", "Explosivo", 2,
		"Las balas explotan al impactar (15 de daño en área).",
		UpgradeDefinition.Rareza.LEGENDARIA, 1.0, 1, [], [explosivo])

	var vampirico := LifestealEffect.new()
	vampirico.amount = 1
	_crear(&"vampirico", "Vampírico", 3,
		"Recuperas 1 de vida al golpear a un enemigo o jugador.",
		UpgradeDefinition.Rareza.EPICA, 1.0, 2, [], [vampirico])

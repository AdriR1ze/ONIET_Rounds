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
const VampiricLeechEffect = preload("res://upgrades/effects/vampiric_leech_effect.gd")
const QuickdrawEffect = preload("res://upgrades/effects/quickdraw_effect.gd")
const RussianRouletteEffect = preload("res://upgrades/effects/russian_roulette_effect.gd")
const GlitchEffect = preload("res://upgrades/effects/glitch_effect.gd")


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


func _crear(
	id: StringName,
	titulo: String,
	subtitulo: String,
	nivel: int,
	descripcion: String,
	rareza: UpgradeDefinition.Rareza,
	peso: float,
	max_stacks: int,
	stats: Array,
	efectos: Array,
	ventajas: Array,
	desventajas: Array,
	mecanicas: Array,
	tema: StringName = &"default"
) -> void:
	var def := UpgradeDefinition.new()
	def.id = id
	def.titulo = titulo
	def.subtitulo = subtitulo
	def.nivel = nivel
	def.descripcion = descripcion
	def.rareza = rareza
	def.peso = peso
	def.max_stacks = max_stacks
	def.tema = tema

	var lista_stats: Array[StatModifier] = []
	for st in stats:
		lista_stats.append(st)
	def.stats = lista_stats

	var lista_efectos: Array[UpgradeEffect] = []
	for efecto in efectos:
		lista_efectos.append(efecto)
	def.efectos = lista_efectos

	var lista_ventajas: Array[String] = []
	for v in ventajas:
		lista_ventajas.append(v)
	def.ventajas = lista_ventajas

	var lista_desventajas: Array[String] = []
	for d in desventajas:
		lista_desventajas.append(d)
	def.desventajas = lista_desventajas

	var lista_mecanicas: Array[String] = []
	for m in mecanicas:
		lista_mecanicas.append(m)
	def.mecanicas = lista_mecanicas

	var error := ResourceSaver.save(def, RUTA + String(id) + ".tres")
	if error != OK:
		push_error("No se pudo guardar %s (%d)" % [id, error])


func _generar() -> void:
	# 1. Rebote (Bouncy): Nivel 1 (Común)
	_crear(&"bouncy", "Rebote", "Tus balas rebotan en las paredes", 1,
		"Tus balas rebotan en las superficies en vez de destruirse al impacto (+1 rebote, daño ligeramente reducido).",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[_mod(&"bounces", StatModifier.Op.ADD, 1.0), _mod(&"damage", StatModifier.Op.MULT, 0.90)],
		[],
		["+1 Rebote de bala"],
		["-10% Daño de impacto"],
		["Balas rebotan en superficies"],
		&"rebote")

	# 2. Nube Tóxica (Toxic Cloud): Nivel 1 (Común)
	_crear(&"toxic_cloud", "Nube Tóxica", "Siembra un gas venenoso al impactar", 1,
		"Genera una nube tóxica al impactar superficies o rivales (3 ticks de veneno con reinicio por permanencia).",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[_mod(&"damage", StatModifier.Op.MULT, 0.90), _mod(&"fire_rate", StatModifier.Op.MULT, 0.90)],
		[ToxicCloudEffect.new()],
		["Área persistente por permanencia"],
		["-10% Daño de bala", "-10% Cadencia de tiro"],
		["Nube de veneno acumulativo continuo"],
		&"toxico")

	# 3. Disparo Demoledor (Demolition Shot): Nivel 2 (Rara)
	_crear(&"demolition_shot", "Disparo Demoledor", "Destruye coberturas y estructuras", 2,
		"Las balas perforan y destruyen fragmentos de plataformas o estructuras del escenario directamente al impactar.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"reload_time", StatModifier.Op.MULT, 1.35), _mod(&"pierce", StatModifier.Op.ADD, 1.0)],
		[DemolitionEffect.new()],
		["+1 Perforación de objetivos"],
		["+35% Tiempo de recarga"],
		["Destrucción de cobertura del mapa"],
		&"demolicion")

	# 4. Bala Divisora (Splitter): Nivel 1 (Común)
	_crear(&"splitter", "Bala Divisora", "Tu proyectil se divide en 3 fragmentos", 1,
		"La bala se divide en 3 fragmentos tras recorrer la mitad del camino o rebotar (+1 rebote).",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[_mod(&"damage", StatModifier.Op.MULT, 0.90), _mod(&"bounces", StatModifier.Op.ADD, 1.0)],
		[SplitterEffect.new()],
		["+1 Rebote base"],
		["-10% Daño de bala inicial"],
		["División en 3 proyectiles"],
		&"rebote")

	# 5. Bala de Plomo (Lead Slug): Nivel 2 (Rara)
	_crear(&"lead_slug", "Bala de Plomo", "Balas pesadas con empuje demoledor", 2,
		"Balas pesadas con caída pronunciada, daño mejorado (+35%) y empuje cinético masivo (velocidad muy reducida).",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[
			_mod(&"damage", StatModifier.Op.MULT, 1.35),
			_mod(&"knockback", StatModifier.Op.ADD, 450.0),
			_mod(&"bullet_speed", StatModifier.Op.MULT, 0.65),
			_mod(&"bullet_gravity", StatModifier.Op.MULT, 1.60)
		],
		[],
		["+35% Daño de impacto", "+450 Fuerza de empuje"],
		["-35% Velocidad de bala", "+60% Caída por gravedad"],
		["Empuje cinético masivo"],
		&"pesado")

	# 6. Mira Láser (Laser Sight): Nivel 2 (Rara)
	_crear(&"laser_sight", "Mira Láser", "Disparo instantáneo con haz continuo", 2,
		"Tus balas ya no tienen tiempo de viaje; impactan de forma instantánea en línea recta (hitscan, -1 bala en cargador).",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"max_ammo", StatModifier.Op.ADD, -1.0)],
		[LaserSightEffect.new()],
		["Impacto instantáneo a cualquier distancia"],
		["-1 Bala en el cargador"],
		["Disparo en rayo láser (Hitscan)"],
		&"laser")

	# 7. Balas Fantasma (Phantom Rounds): Nivel 2 (Rara)
	_crear(&"phantom_rounds", "Balas Fantasma", "Atraviesan la primera pared", 2,
		"Las balas atraviesan la primera pared o estructura sólida del escenario sin destruirse (-10% de daño).",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"damage", StatModifier.Op.MULT, 0.90), _mod(&"wall_pierce", StatModifier.Op.ADD, 1.0)],
		[PhantomRoundsEffect.new()],
		["Atraviesa coberturas enemigas"],
		["-10% Daño de impacto"],
		["Perfora la primera pared sólida"],
		&"fantasma")

	# 8. Bala Pesada (Heavy Bullet): Nivel 1 (Común)
	_crear(&"heavy_bullet", "Bala Pesada", "Balas más grandes y fuertes", 1,
		"Proyectiles más grandes (+60%) y contundentes (+30% daño) que aturden una fracción de segundo al rival.",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[
			_mod(&"damage", StatModifier.Op.MULT, 1.30),
			_mod(&"fire_rate", StatModifier.Op.MULT, 0.65),
			_mod(&"bullet_scale", StatModifier.Op.MULT, 1.60)
		],
		[HeavyBulletEffect.new()],
		["Gran aumento en tamaño de bala (+60%)", "+30% Daño de impacto"],
		["-35% Cadencia de tiro"],
		["Aturde brevemente al oponente"],
		&"pesado")

	# 9. Maestro del Rebote (Ricochet Master): Nivel 3 (Rara)
	_crear(&"ricochet_master", "Maestro del Rebote", "Cada rebote potencia el proyectil", 3,
		"+2 rebotes. Cada rebote que realiza la bala antes de tocar al rival incrementa notablemente (+45%) el daño final.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"bounces", StatModifier.Op.ADD, 2.0), _mod(&"damage", StatModifier.Op.MULT, 0.85)],
		[RicochetMasterEffect.new()],
		["+2 Rebotes adicionales"],
		["-15% Daño base sin rebotar"],
		["+45% Daño por cada rebote previo al hit"],
		&"rebote")

	# 10. Campo Minado (Minefield): Nivel 4 (Épica)
	_crear(&"minefield", "Campo Minado", "Planta minas de proximidad en el suelo", 4,
		"Las balas que tocan el suelo y no impactan a un rival se plantan como minas de proximidad activas durante 6 segundos.",
		UpgradeDefinition.Rareza.EPICA, 1.0, 1,
		[_mod(&"reload_time", StatModifier.Op.MULT, 1.60)],
		[MinefieldEffect.new()],
		["Control de zona y trampa de proximidad"],
		["+60% Tiempo de recarga"],
		["Balas al suelo se vuelven minas (6s)"],
		&"explosivo")

	# 11. Disparo Explosivo (Explosivo): Nivel 2 (Legendaria)
	var explosivo := ExplosiveEffect.new()
	explosivo.radius = 80.0
	_crear(&"explosivo", "Disparo Explosivo", "Detonaciones de área devastadoras", 2,
		"Las balas explotan al impactar (15 de daño en área).",
		UpgradeDefinition.Rareza.LEGENDARIA, 1.0, 1, [], [explosivo],
		["15 de daño explosivo en área"],
		[],
		["Explosión en área al impactar"],
		&"explosivo")

	# 12. Sanguijuela Vampírica (Vampiric Leech): Nivel 3 (Rara)
	_crear(&"vampiric_leech", "Sanguijuela Vampírica", "Robas vida a tu enemigo", 3,
		"Una porción del daño que le causás al rival se convierte inmediatamente en salud para vos. Salud máxima ligeramente reducida.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"max_health", StatModifier.Op.MULT, 0.85)],
		[VampiricLeechEffect.new()],
		["Regeneración inmediata en combate"],
		["-15% Salud máxima"],
		["Robo de vida (recuperas 30% del daño)"],
		&"vampirico")

	# 13. Cañón de Cristal (Glass Cannon): Nivel 4 (Épica)
	_crear(&"glass_cannon", "Cañón de Cristal", "Poder destructivo colosal a cambio de tu vida", 4,
		"Incrementa de forma masiva el daño infligido (+150%) pero reduce casi por completo tu salud máxima (-80%).",
		UpgradeDefinition.Rareza.EPICA, 1.0, 1,
		[_mod(&"damage", StatModifier.Op.MULT, 2.50), _mod(&"max_health", StatModifier.Op.MULT, 0.20)],
		[],
		["Extremo aumento en daño (+150%)"],
		["Salud máxima reducida en un 80% (20 HP)"],
		["Mortal a un golpe, daño desmesurado"],
		&"cristal")

	# 14. Desenfundado Rápido (Quickdraw): Nivel 1 (Común)
	_crear(&"quickdraw", "Desenfundado Rápido", "El primer tiro tras recargar es letal", 1,
		"El primer tiro disparado inmediatamente después de recargar sale sin dispersión y con velocidad extrema (+70% vel. bala, -1 cargador).",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[_mod(&"max_ammo", StatModifier.Op.ADD, -1.0)],
		[QuickdrawEffect.new()],
		["+70% Velocidad de bala en primer tiro", "Precisión perfecta (0 dispersión)"],
		["-1 Capacidad del cargador"],
		["Disparo inicial post-recarga instantáneo"],
		&"rapido")

	# 15. Ruleta Rusa (Russian Roulette): Nivel 4 (Épica)
	_crear(&"russian_roulette", "Ruleta Rusa", "Una bala secreta inflige daño colosal", 4,
		"Al recargar, hay 50% de probabilidad de que una bala aleatoria del cargador inflija daño crítico devastador (+300%). Daño base ligeramente reducido.",
		UpgradeDefinition.Rareza.EPICA, 1.0, 1,
		[_mod(&"damage", StatModifier.Op.MULT, 0.88)],
		[RussianRouletteEffect.new()],
		["+300% Daño crítico devastador (x4 daño)"],
		["-12% Daño en balas normales"],
		["50% chance por recarga de bala letal"],
		&"roulette")

	# 16. Glitch: Nivel 4 (Épica)
	_crear(&"glitch", "Glitch", "Salto de fase y clonación en vuelo", 4,
		"Las balas tienen probabilidad de desfasarse en el aire, realizando un micro-salto cibernético y duplicándose hacia adelante.",
		UpgradeDefinition.Rareza.EPICA, 1.0, 1,
		[_mod(&"spread", StatModifier.Op.ADD, 8.0)],
		[GlitchEffect.new()],
		["Genera un clon cibernético secundario"],
		["Ligera dispersión (+8°)"],
		["Fase cibernética y clonación en vuelo"],
		&"glitch")

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
const BulletTimeEffect = preload("res://upgrades/effects/bullet_time_effect.gd")

const ContragolpeSismicoEffect = preload("res://upgrades/effects/contragolpe_sismico_effect.gd")
const PielAdaptativaEffect = preload("res://upgrades/effects/piel_adaptativa_effect.gd")
const SegundaPielEffect = preload("res://upgrades/effects/segunda_piel_effect.gd")
const ImpactoSismicoEffect = preload("res://upgrades/effects/impacto_sismico_effect.gd")
const OndaChoqueEffect = preload("res://upgrades/effects/onda_choque_effect.gd")
const BalaAnclanteEffect = preload("res://upgrades/effects/bala_anclante_effect.gd")
const PropulsionEffect = preload("res://upgrades/effects/propulsion_effect.gd")
const PerforadoraVitalEffect = preload("res://upgrades/effects/perforadora_vital_effect.gd")
const MagnetismoEffect = preload("res://upgrades/effects/magnetismo_effect.gd")
const DeudaSangreEffect = preload("res://upgrades/effects/deuda_sangre_effect.gd")
const SacrificioCompartidoEffect = preload("res://upgrades/effects/sacrificio_compartido_effect.gd")
const ZonaGravedadEffect = preload("res://upgrades/effects/zona_gravedad_effect.gd")
const NexoVidaEffect = preload("res://upgrades/effects/nexo_vida_effect.gd")
const GolpeTitanicoEffect = preload("res://upgrades/effects/golpe_titanico_effect.gd")


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
	tema: StringName = &"default",
	categoria: UpgradeDefinition.Categoria = UpgradeDefinition.Categoria.ATAQUE
) -> void:
	var def := UpgradeDefinition.new()
	def.id = id
	def.titulo = titulo
	def.subtitulo = subtitulo
	def.nivel = nivel
	def.descripcion = descripcion
	def.rareza = rareza
	def.categoria = categoria
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
		&"division")

	# 5. Bala de Plomo (Lead Slug): Nivel 2 (Rara)
	_crear(&"lead_slug", "Bala de Plomo", "Balas pesadas con empuje demoledor", 2,
		"Balas pesadas con caída pronunciada, daño mejorado (+35%) y empuje cinético masivo (velocidad muy reducida).",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[
			_mod(&"damage", StatModifier.Op.MULT, 1.35),
			_mod(&"knockback", StatModifier.Op.ADD, 450.0),
			_mod(&"bullet_speed", StatModifier.Op.MULT, 0.65),
			_mod(&"bullet_gravity", StatModifier.Op.MULT, 1.50)
		],
		[],
		["+35% Daño de impacto", "+450 Fuerza de empuje"],
		["-35% Velocidad de bala", "+50% Caída por gravedad"],
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
		"Las balas atraviesan la primera pared o estructura sólida del escenario sin destruirse (-15% de daño).",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"damage", StatModifier.Op.MULT, 0.85), _mod(&"wall_pierce", StatModifier.Op.ADD, 1.0)],
		[PhantomRoundsEffect.new()],
		["Atraviesa coberturas enemigas"],
		["-15% Daño de impacto"],
		["Perfora la primera pared sólida"],
		&"fantasma")

	# 8. Bala Pesada (Heavy Bullet): Nivel 1 (Común)
	_crear(&"heavy_bullet", "Bala Pesada", "Balas más grandes y fuertes", 1,
		"Proyectiles más grandes (+60%) y contundentes (+30% daño) que aturden una fracción de segundo al rival.",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[
			_mod(&"damage", StatModifier.Op.MULT, 1.30),
			_mod(&"fire_rate", StatModifier.Op.MULT, 0.80),
			_mod(&"bullet_scale", StatModifier.Op.MULT, 1.60)
		],
		[HeavyBulletEffect.new()],
		["Gran aumento en tamaño de bala (+60%)", "+30% Daño de impacto"],
		["-20% Cadencia de tiro"],
		["Aturde brevemente al oponente"],
		&"bala_grande")

	# 9. Maestro del Rebote (Ricochet Master): Nivel 3 (Rara)
	_crear(&"ricochet_master", "Maestro del Rebote", "Cada rebote potencia el proyectil", 3,
		"+2 rebotes. Cada rebote que realiza la bala antes de tocar al rival incrementa notablemente (+45%) el daño final.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"bounces", StatModifier.Op.ADD, 2.0), _mod(&"damage", StatModifier.Op.MULT, 0.80)],
		[RicochetMasterEffect.new()],
		["+2 Rebotes adicionales"],
		["-20% Daño base sin rebotar"],
		["+45% Daño por cada rebote previo al hit"],
		&"ricochet")

	# 10. Campo Minado (Minefield): Nivel 4 (Épica)
	_crear(&"minefield", "Campo Minado", "Planta minas de proximidad en el suelo", 4,
		"Las balas que tocan el suelo y no impactan a un rival se plantan como minas de proximidad activas durante 6 segundos.",
		UpgradeDefinition.Rareza.EPICA, 1.0, 1,
		[_mod(&"reload_time", StatModifier.Op.MULT, 1.60)],
		[MinefieldEffect.new()],
		["Control de zona y trampa de proximidad"],
		["+60% Tiempo de recarga"],
		["Balas al suelo se vuelven minas (6s)"],
		&"minas")

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
		"Una porción del daño que le causás al rival se convierte inmediatamente en salud para vos.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[],
		[VampiricLeechEffect.new()],
		["Regeneración inmediata en combate"],
		[],
		["Robo de vida (recuperas 30% del daño)"],
		&"vampirico",
		UpgradeDefinition.Categoria.DEFENSA)

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
		&"desenfunde")

	# 15. Ruleta Rusa (Russian Roulette): Nivel 4 (Épica)
	_crear(&"russian_roulette", "Ruleta Rusa", "Una bala secreta inflige daño colosal", 4,
		"Al recargar, hay 50% de probabilidad de que una bala aleatoria del cargador inflija daño crítico devastador (+200%). Daño base ligeramente reducido.",
		UpgradeDefinition.Rareza.EPICA, 1.0, 1,
		[_mod(&"damage", StatModifier.Op.MULT, 0.85)],
		[RussianRouletteEffect.new()],
		["+200% Daño crítico devastador (x3 daño)"],
		["-15% Daño en balas normales"],
		["50% chance por recarga de bala letal"],
		&"roulette")

	# 16. Glitch: Nivel 4 (Épica)
	_crear(&"glitch", "Glitch", "Salto de fase y clonación en vuelo", 4,
		"Las balas tienen probabilidad de desfasarse en el aire, realizando un micro-salto cibernético y duplicándose hacia adelante.",
		UpgradeDefinition.Rareza.EPICA, 1.0, 1,
		[_mod(&"spread", StatModifier.Op.ADD, 20.0)],
		[GlitchEffect.new()],
		["Genera un clon cibernético secundario"],
		["Dispersión (+20°)"],
		["Fase cibernética y clonación en vuelo"],
		&"glitch")

	# 17. Bullet Time: Nivel 1 (Común)
	_crear(&"bullet_time", "Bullet Time", "Tus balas se mueven a cámara lenta", 1,
		"Tus proyectiles vuelan un 90% más lentos y no expiran por tiempo, quedando suspendidos en el aire hasta impactar.",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[],
		[BulletTimeEffect.new()],
		["Balas un 90% más lentas (control total)", "Tus balas no expiran por tiempo", "+1% Daño por segundo en el aire"],
		["Los proyectiles tardan en llegar al rival"],
		["Cámara lenta de proyectiles (bullet time)", "Escala daño mientras más tiempo vuela la bala"],
		&"tiempo",
		UpgradeDefinition.Categoria.CONTROL)

	# 18. Gatillo Eléctrico: Nivel 1 (Común)
	_crear(&"gatillo_electrico", "Gatillo Eléctrico", "Cadencia de fuego desmedida", 1,
		"Disparás mucho más rápido (+100% cadencia) y recargás más rápido (-30% tiempo de recarga) pero cada impacto hace menos daño (-25%).",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[
			_mod(&"fire_rate", StatModifier.Op.MULT, 2.0),
			_mod(&"reload_time", StatModifier.Op.MULT, 0.70),
			_mod(&"damage", StatModifier.Op.MULT, 0.75)
		],
		[],
		["+100% Cadencia de tiro", "-30% Tiempo de recarga"],
		["-25% Daño de impacto"],
		["Cadencia de fuego desmedida"],
		&"electrico")

	# 19. Piel Gruesa: Nivel 1 (Común)
	_crear(&"piel_gruesa", "Piel Gruesa", "Más aguante, menos agresividad", 1,
		"Ganás vida máxima (+30%) pero atacás un poco más débil y más lento (-10% daño y cadencia).",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[
			_mod(&"max_health", StatModifier.Op.MULT, 1.30),
			_mod(&"damage", StatModifier.Op.MULT, 0.90),
			_mod(&"fire_rate", StatModifier.Op.MULT, 0.90)
		],
		[],
		["+30% Salud máxima"],
		["-10% Daño de impacto", "-10% Cadencia de tiro"],
		["Más resistencia a cambio de ofensiva"],
		&"piel",
		UpgradeDefinition.Categoria.DEFENSA)

	# 20. Contragolpe Sísmico: Nivel 3 (Rara)
	_crear(&"contragolpe_sismico", "Contragolpe Sísmico", "Explosión masiva al parrear", 3,
		"Al parrear una bala, detonas una explosión radial alrededor de tu personaje que inflige 15% de tu vida máxima y empuja.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"damage", StatModifier.Op.MULT, 0.90)],
		[ContragolpeSismicoEffect.new()],
		["Explosión de 15% vida máx al parrear"],
		["-10% Daño de disparo"],
		["Contragolpe explosivo en área al hacer parry"],
		&"contragolpe",
		UpgradeDefinition.Categoria.DEFENSA)

	# 22. Piel Adaptativa: Nivel 3 (Rara)
	_crear(&"piel_adaptativa", "Piel Adaptativa", "Te endureces con cada impacto recibido", 3,
		"Cada golpe recibido te otorga +8% de armadura durante 4 segundos (acumula hasta 3 veces).",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[],
		[PielAdaptativaEffect.new()],
		["+8% Armadura por 4s al recibir golpe (stack 3)"],
		[],
		["Armadura reactiva acumulativa"],
		&"armadura",
		UpgradeDefinition.Categoria.DEFENSA)

	# 25. Segunda Piel: Nivel 4 (Épica)
	_crear(&"segunda_piel", "Segunda Piel", "Regeneración reactiva al sufrir daño", 4,
		"Al recibir un golpe de daño, tu cuerpo regenera inmediatamente +4 vida por segundo durante 3 segundos.",
		UpgradeDefinition.Rareza.EPICA, 1.0, 1,
		[],
		[SegundaPielEffect.new()],
		["Al recibir daño: +4 vida/s durante 3s (12 HP)"],
		[],
		["Regeneración reactiva en combate"],
		&"regeneracion",
		UpgradeDefinition.Categoria.DEFENSA)

	# 26. Impacto Sísmico: Nivel 3 (Rara)
	_crear(&"impacto_sismico", "Impacto Sísmico", "Empuje demoledor y aturdimiento contundente", 3,
		"Tus proyectiles empujan fuertemente (+550 fuerza) y aturden 0.35 s al objetivo impactado.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"damage", StatModifier.Op.MULT, 0.90)],
		[ImpactoSismicoEffect.new()],
		["Empuje masivo (+550) y aturde 0.35s"],
		["-10% Daño de bala"],
		["Empuje masivo y aturdimiento contundente"],
		&"sismico",
		UpgradeDefinition.Categoria.CONTROL)

	# 27. Onda de Choque: Nivel 3 (Rara)
	_crear(&"onda_choque", "Onda de Choque", "Expansión física radial en cada impacto", 3,
		"Al impactar a un rival o una superficie sólida, libera una onda expansiva de 90px que empuja a todos los rivales.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"damage", StatModifier.Op.MULT, 0.85)],
		[OndaChoqueEffect.new()],
		["Onda expansiva de empuje en área (radio 90px)"],
		["-15% Daño de bala"],
		["Onda de choque al impactar"],
		&"onda",
		UpgradeDefinition.Categoria.CONTROL)

	# 28. Bala Anclante: Nivel 3 (Rara)
	_crear(&"bala_anclante", "Bala Anclante", "Campo de anclaje que ralentiza en área", 3,
		"Al impactar, genera un campo de anclaje de 85px que reduce la velocidad de movimiento de los rivales un 50% por 1.5 s.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[],
		[BalaAnclanteEffect.new()],
		["Ralentiza al 50% en área durante 1.5s"],
		[],
		["Zona de anclaje y ralentización"],
		&"anclaje",
		UpgradeDefinition.Categoria.CONTROL)

	# 29. Propulsión: Nivel 2 (Rara)
	_crear(&"propulsion", "Propulsión", "Ligero impulso hacia atrás y +2 balas en el cargador", 2,
		"Cada disparo genera un ligero retroceso hacia atrás y amplía tu cargador en 2 balas.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"max_ammo", StatModifier.Op.ADD, 2.0)],
		[PropulsionEffect.new()],
		["Retroceso al disparar", "+2 Balas en el cargador"],
		[],
		["Impulso hacia atrás y cargador ampliado"],
		&"rapido",
		UpgradeDefinition.Categoria.CONTROL)


	# 31. Perforadora Vital: Nivel 3 (Rara)
	_crear(&"perforadora_vital", "Perforadora Vital", "Sangrado letal basado en salud máxima", 3,
		"Las balas aplican sangrado porcentual: 3 ticks que drenan un 4% de la salud máxima del rival cada uno (12% daño total).",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[],
		[PerforadoraVitalEffect.new()],
		["Sangrado porcentual: 4% vida máx por tick (3 ticks)"],
		[],
		["Sangrado (DOT) basado en vida máxima rival"],
		&"sangrado")

	# 32. Magnetismo: Nivel 3 (Rara)
	_crear(&"magnetismo", "Magnetismo", "Tus balas proyectan un aura magnética que atrae rivales", 3,
		"Tus balas generan un aura magnética visible en vuelo que succiona a los rivales hacia ellas y desvía proyectiles enemigos.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[],
		[MagnetismoEffect.new()],
		["Aura magnética en balas (radio 120px)", "Succiona rivales hacia la bala", "Desvía proyectiles enemigos hacia vos"],
		[],
		["Aura de succión magnética en proyectiles"],
		&"iman",
		UpgradeDefinition.Categoria.CONTROL)

	# 33. Deuda de Sangre: Nivel 4 (Épica)
	_crear(&"deuda_sangre", "Deuda de Sangre", "5 segundos de gracia para evitar la muerte", 4,
		"Al sufrir daño letal, no mueres de inmediato: entras en Deuda de Sangre por 5 segundos a 1 HP. Si logras curarte sobrevives; si no, mueres (10s de cooldown).",
		UpgradeDefinition.Rareza.EPICA, 1.0, 1,
		[],
		[DeudaSangreEffect.new()],
		["5s de gracia al recibir daño letal para curarte"],
		["Mueres si no te curas en 5s (10s cooldown)"],
		["Estado de deuda de sangre y supervivencia"],
		&"deuda",
		UpgradeDefinition.Categoria.DEFENSA)

	# 34. Sacrificio Compartido: Nivel 3 (Rara)
	_crear(&"sacrificio_compartido", "Sacrificio Compartido", "Tu sanación hiere a los rivales cercanos", 3,
		"Cada vez que recuperas vida, los rivales a menos de 140px sufren daño igual a la mitad de la cantidad curada.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[_mod(&"max_health", StatModifier.Op.MULT, 0.90)],
		[SacrificioCompartidoEffect.new()],
		["Al curarte, rivales cercanos reciben 50% de lo curado"],
		["-10% Salud máxima"],
		["Daño reactivo por curación en área"],
		&"sangre",
		UpgradeDefinition.Categoria.DEFENSA)

	# 35. Zona de Gravedad: Nivel 4 (Épica)
	_crear(&"zona_gravedad", "Zona de Gravedad", "Aura de gravedad: rivales caen rápido, se mueven lento y saltan menos", 4,
		"Los rivales cercanos (<140px) sufren gravedad extrema (+90%), se mueven un 35% más lento y pierden más de la mitad de su fuerza de salto.",
		UpgradeDefinition.Rareza.EPICA, 1.0, 1,
		[_mod(&"move_speed", StatModifier.Op.MULT, 0.90)],
		[ZonaGravedadEffect.new()],
		["Rivales cerca sufren +90% gravedad", "Rivales cerca se mueven 35% más lento", "Rivales cerca saltan un 55% menos"],
		["-10% Velocidad propia"],
		["Aura de gravedad aumentada, lentitud y reducción de salto"],
		&"gravedad",
		UpgradeDefinition.Categoria.CONTROL)

	# 36. Nexo de Vida: Nivel 4 (Épica)
	_crear(&"nexo_vida", "Nexo de Vida", "Tótem sanador al iniciar recarga", 4,
		"Al iniciar una recarga, plantas un tótem de vida a tus pies que cura en pulsos durante 3 segundos (+8 vida/s).",
		UpgradeDefinition.Rareza.EPICA, 1.0, 1,
		[],
		[NexoVidaEffect.new()],
		["Planta un tótem que cura en área durante 3s (+8 HP/s)"],
		[],
		["Invocación de tótem curativo al recargar"],
		&"totem",
		UpgradeDefinition.Categoria.DEFENSA)

	# 39. Vitalidad Sólida: Nivel 1 (Común)
	_crear(&"vitalidad_solida", "Vitalidad Sólida", "Salud base plana, no porcentual", 1,
		"Aumenta tu salud máxima base en +30 puntos directos (no porcentual). Ligeramente más lento al moverte.",
		UpgradeDefinition.Rareza.COMUN, 1.0, 1,
		[
			_mod(&"max_health", StatModifier.Op.ADD, 30.0),
			_mod(&"move_speed", StatModifier.Op.MULT, 0.92)
		],
		[],
		["+30 Salud base máxima (plana)"],
		["-8% Velocidad de movimiento"],
		["Incremento de salud base no porcentual"],
		&"vitalidad",
		UpgradeDefinition.Categoria.DEFENSA)

	# 40. Corazón Extra: Nivel 2 (Rara)
	_crear(&"corazon_extra", "Corazón Extra", "Tanque colosal a cambio de capacidad", 2,
		"Aumenta tu salud máxima base en +70 puntos directos. Reduce en 1 la capacidad de munición de tu cargador.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[
			_mod(&"max_health", StatModifier.Op.ADD, 70.0),
			_mod(&"max_ammo", StatModifier.Op.ADD, -1.0)
		],
		[],
		["+70 Salud base máxima (plana)"],
		["-1 Capacidad de cargador"],
		["Salud masiva a cambio de munición"],
		&"corazon")

	# 41. Golpe Titánico: Nivel 3 (Rara)
	_crear(&"golpe_titanico", "Golpe Titánico", "Tus disparos son reemplazados por un golpe masivo", 3,
		"Reemplaza tus proyectiles por un golpe cuerpo a cuerpo devastador cuyo daño equivale al 35% de tu vida máxima más empuje contundente.",
		UpgradeDefinition.Rareza.RARA, 1.0, 1,
		[],
		[GolpeTitanicoEffect.new()],
		["Reemplaza balas por golpe melee devastador", "Daño escala con tu salud máxima (35% max HP)"],
		["Rango limitado a cuerpo a cuerpo"],
		["Ataque cuerpo a cuerpo devastador"],
		&"titanico")

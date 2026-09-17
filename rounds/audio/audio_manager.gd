extends Node

const DIR_SFX := "res://audio/sfx/"
const DIR_MUSICA := "res://audio/music/"
const VOCES_SFX := 16
const BUSES := ["Music", "SFX"]

var _cache_sfx: Dictionary = {}
var _cache_musica: Dictionary = {}
var _voces: Array[AudioStreamPlayer] = []
var _musica: AudioStreamPlayer
var _musica_actual: String = ""
var _indice_voz: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_asegurar_buses()
	_musica = AudioStreamPlayer.new()
	_musica.name = "Musica"
	_musica.bus = "Music"
	_musica.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_musica)
	for i in VOCES_SFX:
		var voz := AudioStreamPlayer.new()
		voz.name = "SFX%d" % i
		voz.bus = "SFX"
		voz.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(voz)
		_voces.append(voz)
	get_tree().node_added.connect(_on_nodo_agregado)
	_conectar_botones(get_tree().root)
	_conectar_juego()


func reproducir(nombre: String, variacion_tono: float = 0.0) -> void:
	var stream := _cargar(DIR_SFX + nombre + ".wav", _cache_sfx)
	if stream == null:
		return
	var voz := _siguiente_voz()
	voz.stream = stream
	voz.pitch_scale = 1.0 if variacion_tono <= 0.0 else 1.0 + randf_range(-variacion_tono, variacion_tono)
	voz.play()


func reproducir_musica(nombre: String) -> void:
	if nombre == _musica_actual and _musica.playing:
		return
	var stream := _cargar(DIR_MUSICA + nombre + ".wav", _cache_musica)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_musica.stream = stream
	_musica.play()
	_musica_actual = nombre


func detener_musica() -> void:
	_musica.stop()
	_musica_actual = ""


func pausar_musica(pausar: bool) -> void:
	_musica.stream_paused = pausar


func _asegurar_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		var indice := AudioServer.bus_count
		AudioServer.add_bus(indice)
		AudioServer.set_bus_name(indice, bus)
		AudioServer.set_bus_send(indice, "Master")


func _cargar(ruta: String, cache: Dictionary) -> AudioStream:
	if cache.has(ruta):
		return cache[ruta]
	if not ResourceLoader.exists(ruta):
		return null
	var stream: AudioStream = load(ruta)
	cache[ruta] = stream
	return stream


func _siguiente_voz() -> AudioStreamPlayer:
	for i in _voces.size():
		var voz := _voces[(_indice_voz + i) % _voces.size()]
		if not voz.playing:
			_indice_voz = (_indice_voz + i + 1) % _voces.size()
			return voz
	var reemplazo := _voces[_indice_voz]
	_indice_voz = (_indice_voz + 1) % _voces.size()
	return reemplazo


func _conectar_juego() -> void:
	if RunManager == null:
		return
	RunManager.ronda_iniciada.connect(func(_ronda: int) -> void: reproducir("ronda_inicio"))
	RunManager.ronda_terminada.connect(func(_ronda: int, _ganador: int) -> void: reproducir("ronda_ganada"))
	RunManager.mejoras_cambiadas.connect(func(_numero: int) -> void: reproducir("mejora"))


func _conectar_botones(nodo: Node) -> void:
	if nodo is BaseButton and not nodo.pressed.is_connected(_reproducir_click):
		nodo.pressed.connect(_reproducir_click)
	for hijo in nodo.get_children():
		_conectar_botones(hijo)


func _on_nodo_agregado(nodo: Node) -> void:
	if nodo is BaseButton and not nodo.pressed.is_connected(_reproducir_click):
		nodo.pressed.connect(_reproducir_click)


func _reproducir_click() -> void:
	reproducir("ui_click", 0.03)

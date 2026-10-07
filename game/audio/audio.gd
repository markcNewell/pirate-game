extends Node
## Every sound in the game goes through here (the "Audio" autoload). Sounds are the synthesised
## WAVs in art/sounds (made by tools/make_sounds.py). Three buses under Master: Effects,
## Ambience and Music, so each can be turned up or down. A headless server or bot plays nothing.

const VOICES := 24
const UI_VOICES := 4
## Loops that run all the time on the Ambience bus; World sets how loud each is.
const AMBIENCE := ["sea", "wind", "rain", "bow_wash"]

var enabled := false
var _streams := {}
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0
var _ui: Array[AudioStreamPlayer] = []
var _next_ui := 0
var _loops := {}
var _loop_target := {}
var _music: AudioStreamPlayer
var _music_target := -80.0


func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		return
	for bus: String in ["Effects", "Ambience", "Music"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")
	apply_volumes()
	for i in VOICES:
		var v := AudioStreamPlayer3D.new()
		v.bus = "Effects"
		v.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		v.unit_size = 8.0
		v.max_distance = 400.0
		add_child(v)
		_voices.append(v)
	for i in UI_VOICES:
		var u := AudioStreamPlayer.new()
		u.bus = "Effects"
		add_child(u)
		_ui.append(u)
	for name: String in AMBIENCE:
		var p := AudioStreamPlayer.new()
		p.stream = stream(name, true)
		p.bus = "Ambience"
		p.volume_db = -80.0
		add_child(p)
		p.play()
		_loops[name] = p
		_loop_target[name] = -80.0
	_music = AudioStreamPlayer.new()
	_music.stream = stream("shanty", true)
	_music.bus = "Music"
	_music.volume_db = -80.0
	add_child(_music)


func _exit_tree() -> void:
	# Let go of every stream before the engine shuts down, so none is reported as leaked.
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()
			child.stream = null
	_streams.clear()


## Settings.volume and Settings.music (0-1) onto the Master and Music buses.
func apply_volumes() -> void:
	if not enabled:
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Settings.volume, 0.001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(Settings.music, 0.001)))


## The stream for `name`, loaded once; loops are set to repeat end to start.
func stream(name: String, loop := false) -> AudioStream:
	if not _streams.has(name):
		var s: AudioStreamWAV = load("res://art/sounds/%s.wav" % name)
		if loop:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() / 2
		_streams[name] = s
	return _streams[name]


## A one-shot sound in the world at `pos`, a little higher or lower each time.
func play_at(name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, jitter := 0.08) -> void:
	if not enabled:
		return
	var v := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	v.stream = stream(name)
	v.global_position = pos
	v.volume_db = volume_db
	v.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	v.play()


## A one-shot heard the same wherever you are (your own footsteps, the menu).
func play(name: String, volume_db := 0.0, pitch := 1.0, jitter := 0.06) -> void:
	if not enabled:
		return
	var u := _ui[_next_ui]
	_next_ui = (_next_ui + 1) % UI_VOICES
	u.stream = stream(name)
	u.volume_db = volume_db
	u.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	u.play()


## How loud one ambience loop should be (dB); it eases there.
func set_ambience(name: String, volume_db: float) -> void:
	_loop_target[name] = volume_db


## Fade the sea shanty in (title screen) or out.
func music(on: bool) -> void:
	if not enabled:
		return
	_music_target = -6.0 if on else -80.0
	if on and not _music.playing:
		_music.play()


func _process(delta: float) -> void:
	if not enabled:
		return
	for name: String in _loops:
		var p: AudioStreamPlayer = _loops[name]
		p.volume_db = move_toward(p.volume_db, _loop_target[name], delta * 30.0)
	_music.volume_db = move_toward(_music.volume_db, _music_target, delta * 25.0)
	if _music.playing and _music.volume_db <= -79.0 and _music_target <= -79.0:
		_music.stop()


## A 3D loop that belongs to something in the world (a camp fire, the tavern's music).
func loop_at(parent: Node3D, name: String, volume_db: float, reach: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	parent.add_child(p)
	if not enabled:
		return p
	p.stream = stream(name, true)
	p.bus = "Ambience" if name != "shanty" else "Music"
	p.volume_db = volume_db
	p.max_distance = reach
	p.unit_size = reach * 0.25
	# The owner may not be in the scene yet; start when it is.
	if p.is_inside_tree():
		p.play()
	else:
		p.autoplay = true
	return p

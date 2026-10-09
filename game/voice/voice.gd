class_name Voice
extends Node
## Proximity voice chat on one player's machine (docs/specs/2026-10-09-m25-voice.md). Sends:
## the mic (Mic) through push-to-talk or open mic (TalkGate), packed 60 ms at a time
## (VoicePacket). Hears: each speaker's packets wait in a queue (VoiceQueue) and play from a
## sound source on that pirate's head, fading out to nothing at FADE_TO metres.
## Without sound (a bot) it still sends and counts what it hears, for the smoke test.

## Full volume this close, fading to nothing at FADE_TO (the server sends to ServerSim.EARSHOT).
const FULL_TO := 5.0
const FADE_TO := 40.0
const MOUTH := Vector3(0, 1.6, 0)
## Someone counts as talking for this long after their last packet.
const TALKING_MS := 300
const TONE_ON := 2.0
const TONE_EVERY := 3.0

## Where packets go (Game.send_voice); a test can catch them instead.
var send := func(_packet: PackedByteArray) -> void: pass
var game: Game
var gate := TalkGate.new()
var mic: Mic
## Whether the mic is being sent this frame.
var sending := false
## Test hook (--voice-tone): speak a tone instead of the mic, TONE_ON seconds of every TONE_EVERY.
var tone := false
## A test bot always has voice on, whatever the machine's own settings say.
var for_bot := false
## Pirates muted this session: peer id -> true.
var muted := {}
## Packets heard from each speaker, and packets sent.
var heard := {}
var sent := 0

var _pending := PackedFloat32Array()
var _seq := 0
var _state := Adpcm.State.new()
var _speakers := {}  # peer id -> Speaker
var _last_heard := {}  # peer id -> Time.get_ticks_msec()
var _tone_time := 0.0
var _tone_phase := 0.0
var _tone_carry := 0.0


## One voice being played: its queue, its sound source and how much room the source has empty.
class Speaker:
	var queue := VoiceQueue.new()
	var player: AudioStreamPlayer3D
	var playback: AudioStreamGeneratorPlayback
	var room := 0


func _ready() -> void:
	mic = Mic.new()
	add_child(mic)
	apply_settings()


func _exit_tree() -> void:
	for id in _speakers:
		var s: Speaker = _speakers[id]
		s.player.stop()
		s.player.stream = null


## Settings.voice_on / open_mic / mic_level as they are now (after the Esc menu changes them).
func apply_settings() -> void:
	gate.open_mic = Settings.open_mic
	gate.level = Settings.mic_level
	if not is_on():
		sending = false
		_pending = PackedFloat32Array()
		for id in _speakers.keys():
			_drop(id)
	if mic == null:
		return
	if is_on() and not tone:
		mic.start()
	else:
		mic.stop()


func _process(delta: float) -> void:
	if tone:
		_tone_time += delta
		var on := fmod(_tone_time, TONE_EVERY) < TONE_ON
		# Show on the Esc menu's level bar as a mic would.
		mic.level = 0.3 if on else 0.0
		capture(_tone(delta), on, delta, mic.level)
	elif is_on():
		var samples := mic.read()
		capture(samples, Input.is_physical_key_pressed(KEY_V), delta, mic.level)
	_play()


## This frame's mic `samples` (16 kHz): sent while the gate is open, 60 ms to a packet. When it
## closes, what is left is padded out with silence and sent, so the last word gets through.
func capture(samples: PackedFloat32Array, held: bool, delta: float, loudness: float) -> void:
	var was := sending
	sending = gate.update(delta, held, loudness)
	if sending:
		_pending.append_array(samples)
		while _pending.size() >= VoicePacket.SAMPLES:
			_send(_pending.slice(0, VoicePacket.SAMPLES))
			_pending = _pending.slice(VoicePacket.SAMPLES)
		return
	if was and not _pending.is_empty():
		_pending.resize(VoicePacket.SAMPLES)
		_send(_pending)
	_pending = PackedFloat32Array()


func _send(samples: PackedFloat32Array) -> void:
	var packet := VoicePacket.pack(_seq, samples, _state)
	_seq = (_seq + 1) & 0xFFFF
	sent += 1
	send.call(packet)


## A packet of `speaker`'s voice, from the server.
func receive(speaker: int, packet: PackedByteArray) -> void:
	if muted.has(speaker) or not is_on():
		return
	var p := VoicePacket.unpack(packet)
	if p.is_empty():
		return
	heard[speaker] = int(heard.get(speaker, 0)) + 1
	if heard[speaker] == 1:
		print("[voice] hearing %s" % _name_of(speaker))
	_last_heard[speaker] = Time.get_ticks_msec()
	if Audio.enabled and is_inside_tree():
		_speaker(speaker).queue.push(p.seq, p.samples)


## Voice on: the Esc menu's switch (always, for a bot).
func is_on() -> bool:
	return Settings.voice_on or for_bot


func is_talking(id: int) -> bool:
	return _last_heard.has(id) and Time.get_ticks_msec() - int(_last_heard[id]) < TALKING_MS


func mute(id: int, on: bool) -> void:
	if on:
		muted[id] = true
		_drop(id)
	else:
		muted.erase(id)


func _name_of(id: int) -> String:
	return str(game.roster.get(id, id)) if game else str(id)


func _speaker(id: int) -> Speaker:
	if not _speakers.has(id):
		var s := Speaker.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = VoicePacket.RATE
		gen.buffer_length = 0.5
		s.player = AudioStreamPlayer3D.new()
		s.player.stream = gen
		s.player.bus = "Voice"
		# Our own fade (_place) rather than the engine's, so a voice dies away to nothing at
		# FADE_TO instead of stopping dead; the engine still pans it left and right.
		s.player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		s.player.max_distance = FADE_TO
		add_child(s.player)
		s.player.play()
		s.playback = s.player.get_stream_playback()
		s.room = s.playback.get_frames_available()
		_speakers[id] = s
	return _speakers[id]


func _drop(id: int) -> void:
	if _speakers.has(id):
		_speakers[id].player.queue_free()
		_speakers.erase(id)


## Each voice from its pirate's head, at the volume their distance gives, topped up from its queue.
func _play() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	for id: int in _speakers.keys():
		if game and not game.roster.has(id):
			_drop(id)
			continue
		var s: Speaker = _speakers[id]
		var avatar: Node3D = game.avatars.get(id) if game else null
		if avatar:
			s.player.global_position = avatar.global_position + MOUTH
		if cam:
			s.player.volume_db = linear_to_db(maxf(fade(cam.global_position.distance_to(s.player.global_position)), 0.0001))
		var buffered := s.room - s.playback.get_frames_available()
		var next := s.queue.pull(buffered)
		while not next.is_empty():
			var frames := PackedVector2Array()
			frames.resize(next.size())
			for i in next.size():
				frames[i] = Vector2(next[i], next[i])
			s.playback.push_buffer(frames)
			buffered += next.size()
			next = s.queue.pull(buffered)


## How loud a voice is (0-1) from `distance` metres away: full to FULL_TO, then easing down to
## nothing at FADE_TO.
static func fade(distance: float) -> float:
	var t := clampf((distance - FULL_TO) / (FADE_TO - FULL_TO), 0.0, 1.0)
	return (1.0 - t) * (1.0 - t)


## The test hook's voice: a low wobbling note, at 16 kHz, for `delta` seconds.
func _tone(delta: float) -> PackedFloat32Array:
	_tone_carry += delta * VoicePacket.RATE
	var n := int(_tone_carry)
	_tone_carry -= n
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		_tone_phase = fmod(_tone_phase + TAU * (200.0 + 30.0 * sin(_tone_time * 5.0)) / VoicePacket.RATE, TAU)
		out[i] = 0.3 * sin(_tone_phase)
	return out

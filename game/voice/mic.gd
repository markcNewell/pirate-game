class_name Mic
extends Node
## The microphone, read as 16 kHz mono. It plays into a muted bus ("Mic") with a capture effect
## on it: the game reads what arrives there, and nobody hears it, you least of all. Nothing
## happens without sound (a headless server or bot).

const BUS := "Mic"

## The loudest sample in the last read, 0-1 (for open mic and the Esc menu's level bar).
var level := 0.0
var running := false
var _player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _down: Downsampler


func start() -> void:
	if running or not Audio.enabled:
		return
	var bus := AudioServer.get_bus_index(BUS)
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, BUS)
		AudioServer.set_bus_mute(bus, true)
		var capture := AudioEffectCapture.new()
		# Room for half a second, so a slow frame (loading a model) loses nothing.
		capture.buffer_length = 0.5
		AudioServer.add_bus_effect(bus, capture)
	_capture = AudioServer.get_bus_effect(bus, 0)
	use_device(Settings.mic_device)
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = BUS
	add_child(_player)
	_player.play()
	_down = Downsampler.new(AudioServer.get_mix_rate())
	_capture.clear_buffer()
	running = true
	print("[voice] mic on (%s)" % AudioServer.input_device)


## Lets go of the mic (so the system stops showing it in use).
func stop() -> void:
	if not running:
		return
	_player.stop()
	_player.queue_free()
	_player = null
	running = false
	level = 0.0


## The microphones the system offers ("Default" first).
static func devices() -> PackedStringArray:
	return AudioServer.get_input_device_list() if Audio.enabled else PackedStringArray(["Default"])


func use_device(device: String) -> void:
	if Audio.enabled:
		AudioServer.input_device = device if device in AudioServer.get_input_device_list() else "Default"


## What the mic heard since the last call, at 16 kHz.
func read() -> PackedFloat32Array:
	if not running:
		return PackedFloat32Array()
	var n := _capture.get_frames_available()
	if n == 0:
		return PackedFloat32Array()
	var samples := _down.push(_capture.get_buffer(n))
	var peak := 0.0
	for v in samples:
		peak = maxf(peak, absf(v))
	level = minf(peak, 1.0)
	return samples

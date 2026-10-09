extends "res://tests/support/case.gd"
## Proximity voice chat (docs/specs/2026-10-09-m25-voice.md): packing, the mic's 16 kHz,
## push-to-talk and open mic, each speaker's queue, who hears whom and the server's cap.


## Something like a voice: a low note with overtones, rising and falling, and a little hiss.
func _voice_like(count: int, rate := 16000.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		var t := i / rate
		var swell := 0.5 + 0.5 * sin(TAU * 3.0 * t)
		var v := 0.35 * sin(TAU * 180.0 * t) + 0.15 * sin(TAU * 360.0 * t) + 0.07 * sin(TAU * 720.0 * t)
		out[i] = v * swell + rng.randf_range(-0.01, 0.01)
	return out


func _snr_db(clean: PackedFloat32Array, back: PackedFloat32Array) -> float:
	var signal_power := 0.0
	var noise_power := 0.0
	for i in clean.size():
		signal_power += clean[i] * clean[i]
		noise_power += (clean[i] - back[i]) * (clean[i] - back[i])
	return 10.0 * log(signal_power / maxf(noise_power, 1e-12)) / log(10.0)


func _crossings(samples: PackedFloat32Array) -> int:
	var n := 0
	for i in range(1, samples.size()):
		if (samples[i - 1] < 0.0) != (samples[i] < 0.0):
			n += 1
	return n


func _stereo_sine(freq: float, rate: float, count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(count)
	for i in count:
		var v := 0.5 * sin(TAU * freq * i / rate)
		out[i] = Vector2(v, v)
	return out


# --- packing ---

func test_the_codec_keeps_a_voice_clear() -> void:
	var clean := _voice_like(16000)
	var enc := Adpcm.State.new()
	var data := Adpcm.encode(clean, enc)
	check_eq(data.size(), 8000, "two samples a byte")
	var back := Adpcm.decode(data, Adpcm.State.new(), clean.size())
	check_eq(back.size(), clean.size(), "every sample back")
	var snr := _snr_db(clean, back)
	check(snr > 20.0, "signal to noise %.1f dB" % snr)


func test_the_codec_survives_full_scale() -> void:
	var loud := PackedFloat32Array()
	for i in 960:
		loud.append(1.0 if (i / 20) % 2 == 0 else -1.0)
	var back := Adpcm.decode(Adpcm.encode(loud, Adpcm.State.new()), Adpcm.State.new(), loud.size())
	for v in back:
		if v < -1.0 or v > 1.0:
			check(false, "a sample came back out of range: %s" % v)
			return


func test_a_packet_comes_back_whole() -> void:
	var clean := _voice_like(VoicePacket.SAMPLES * 2)
	var state := Adpcm.State.new()
	var first := VoicePacket.pack(65535, clean.slice(0, VoicePacket.SAMPLES), state)
	var second := VoicePacket.pack(0, clean.slice(VoicePacket.SAMPLES), state)
	check_eq(first.size(), VoicePacket.HEADER + VoicePacket.SAMPLES / 2, "485 bytes")
	var a := VoicePacket.unpack(first)
	var b := VoicePacket.unpack(second)
	check_eq(a.seq, 65535)
	check_eq(b.seq, 0)
	check_eq(b.samples.size(), VoicePacket.SAMPLES)
	# Each packet carries its own start, so the second decodes on its own (the first lost).
	var snr := _snr_db(clean.slice(VoicePacket.SAMPLES), b.samples)
	check(snr > 20.0, "the second packet alone: %.1f dB" % snr)


func test_a_broken_packet_is_refused() -> void:
	var good := VoicePacket.pack(3, _voice_like(VoicePacket.SAMPLES), Adpcm.State.new())
	check(not VoicePacket.unpack(good).is_empty(), "a good one is taken")
	check(VoicePacket.unpack(PackedByteArray([1, 2, 3])).is_empty(), "too short")
	var long := PackedByteArray()
	long.resize(VoicePacket.MAX_BYTES + 1)
	check(VoicePacket.unpack(long).is_empty(), "too long")
	var bad := good.duplicate()
	bad[4] = 200
	check(VoicePacket.unpack(bad).is_empty(), "a step index past the table")


func test_sequence_numbers_wrap() -> void:
	check(VoicePacket.newer(1, 0), "1 after 0")
	check(not VoicePacket.newer(0, 1), "0 not after 1")
	check(VoicePacket.newer(0, 65535), "0 after 65535")
	check(not VoicePacket.newer(5, 5), "not after itself")


# --- the mic's samples ---

func test_down_to_16k_from_48k_and_44k() -> void:
	for rate: float in [48000.0, 44100.0]:
		var down := Downsampler.new(rate)
		var frames := _stereo_sine(1000.0, rate, int(rate / 10.0))
		var out := down.push(frames)
		check_near(out.size(), 1600, 1, "%d Hz: a tenth of a second" % rate)
		# 1,000 Hz for a tenth of a second crosses zero 200 times.
		check_near(_crossings(out), 200, 2, "%d Hz: the pitch kept" % rate)


func test_down_in_pieces_matches_down_at_once() -> void:
	var frames := _stereo_sine(440.0, 44100.0, 4410)
	var whole := Downsampler.new(44100.0).push(frames)
	var bits := Downsampler.new(44100.0)
	var pieces := PackedFloat32Array()
	for start in range(0, frames.size(), 737):
		pieces.append_array(bits.push(frames.slice(start, start + 737)))
	check_eq(pieces.size(), whole.size(), "as many samples")
	check_eq(pieces, whole, "the same samples")


# --- push-to-talk and open mic ---

func test_push_to_talk_sends_only_while_held() -> void:
	var gate := TalkGate.new()
	check(gate.update(0.016, true, 0.0), "held, quiet")
	check(not gate.update(0.016, false, 0.9), "not held, loud")


func test_open_mic_hangs_on_after_a_word() -> void:
	var gate := TalkGate.new()
	gate.open_mic = true
	gate.level = 0.1
	check(not gate.update(0.016, false, 0.05), "quiet")
	check(gate.update(0.016, false, 0.3), "loud")
	check(gate.update(0.2, false, 0.0), "just after")
	check(gate.update(0.15, false, 0.0), "still within the hang")
	check(not gate.update(0.1, false, 0.0), "after 0.45 s quiet")
	check(gate.update(0.016, true, 0.0), "V still works in open mic")


# --- one speaker's queue ---

func _samples(seq: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(VoicePacket.SAMPLES)
	s.fill(seq / 1000.0)
	return s


func _seq_of(samples: PackedFloat32Array) -> int:
	return -1 if samples.is_empty() else roundi(samples[0] * 1000.0)


func test_the_queue_waits_for_two_then_plays_in_order() -> void:
	var q := VoiceQueue.new()
	q.push(10, _samples(10))
	check_eq(_seq_of(q.pull(0)), -1, "one is not enough")
	q.push(12, _samples(12))
	q.push(11, _samples(11))
	check_eq(_seq_of(q.pull(0)), 10)
	check_eq(_seq_of(q.pull(VoicePacket.SAMPLES)), 11, "room for another")
	check_eq(_seq_of(q.pull(VoicePacket.SAMPLES * 2)), -1, "two packets already playing")
	check_eq(_seq_of(q.pull(VoicePacket.SAMPLES)), 12)
	q.push(11, _samples(11))
	q.push(12, _samples(12))
	check_eq(q.size(), 0, "old and repeated packets dropped")


func test_the_queue_catches_up() -> void:
	var q := VoiceQueue.new()
	for seq in 10:
		q.push(seq, _samples(seq))
	check_eq(q.size(), VoiceQueue.MOST, "no more than six waiting")
	check_eq(_seq_of(q.pull(0)), 4, "the oldest went")


func test_after_a_gap_the_queue_waits_again() -> void:
	var q := VoiceQueue.new()
	q.push(1, _samples(1))
	q.push(2, _samples(2))
	q.pull(0)
	q.pull(0)
	check_eq(_seq_of(q.pull(0)), -1, "ran dry")
	q.push(3, _samples(3))
	check_eq(_seq_of(q.pull(0)), -1, "waits for two again")
	q.push(4, _samples(4))
	check_eq(_seq_of(q.pull(0)), 3)


# --- who hears whom ---

func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true})
	sim.add_player(1, "Anne", 1, "a")
	sim.add_player(2, "Ben", 1, "b")
	sim.add_player(3, "Cat", 2, "c")
	sim.add_player(4, "Dan", 1, "d")
	var at := {1: Vector3(0, 0, 0), 2: Vector3(20, 0, 0), 3: Vector3(0, 0, -40), 4: Vector3(60, 0, 0)}
	for id: int in at:
		sim.players[id].mode = LocalPlayer.Mode.WORLD
		sim.players[id].pos = at[id]
	return sim


func test_everyone_in_earshot_hears_and_nobody_else() -> void:
	var sim := _sim()
	var heard := sim.voice_listeners(1)
	heard.sort()
	check_eq(heard, [2, 3], "Ben (20 m) and Cat of another crew (40 m), not Dan (60 m) or Anne herself")
	check_eq(sim.voice_listeners(99), [], "nobody hears a stranger")


func test_the_server_caps_each_talker() -> void:
	var sim := _sim()
	var size := VoicePacket.HEADER + VoicePacket.SAMPLES / 2
	var taken := 0
	for i in 40:
		if sim.voice_ok(1, size):
			taken += 1
	check_eq(taken, ServerSim.VOICE_PER_SECOND, "a burst is cut at the cap")
	check(sim.voice_ok(2, size), "the cap is each player's own")
	sim.time += 1.0
	check(sim.voice_ok(1, size), "a second later there is room again")
	check(not sim.voice_ok(2, VoicePacket.MAX_BYTES + 1), "too big")
	check(not sim.voice_ok(2, VoicePacket.HEADER), "no samples")


# --- the voice on one machine, without sound (as on a bot) ---

func test_holding_v_sends_packets_and_letting_go_sends_the_rest() -> void:
	var voice := Voice.new()
	var sent: Array[PackedByteArray] = []
	voice.send = func(p: PackedByteArray) -> void: sent.append(p)
	var talk := _voice_like(VoicePacket.SAMPLES * 2 + 100)
	voice.capture(talk, true, 0.1, 0.5)
	check_eq(sent.size(), 2, "two whole packets")
	check(voice.sending, "sending while held")
	voice.capture(PackedFloat32Array(), false, 0.1, 0.0)
	check_eq(sent.size(), 3, "the last 100 samples padded and sent")
	check(not voice.sending, "stopped")
	voice.capture(talk, false, 0.1, 0.5)
	check_eq(sent.size(), 3, "nothing while not held")
	var seqs := sent.map(func(p: PackedByteArray) -> int: return VoicePacket.unpack(p).seq)
	check_eq(seqs, [0, 1, 2], "numbered in order")
	voice.free()


func test_voices_are_counted_and_muted() -> void:
	var voice := Voice.new()
	var p := VoicePacket.pack(0, _voice_like(VoicePacket.SAMPLES), Adpcm.State.new())
	voice.receive(7, p)
	check_eq(voice.heard.get(7, 0), 1, "heard Seven")
	check(voice.is_talking(7), "Seven is talking")
	check(not voice.is_talking(8), "Eight is not")
	voice.muted[7] = true
	voice.receive(7, VoicePacket.pack(1, _voice_like(VoicePacket.SAMPLES), Adpcm.State.new()))
	check_eq(voice.heard.get(7, 0), 1, "a muted pirate is not heard")
	voice.receive(8, PackedByteArray([1, 2, 3]))
	check_eq(voice.heard.get(8, 0), 0, "a broken packet is not heard")
	voice.free()


func test_turning_voice_off_stops_sending_and_hearing() -> void:
	var voice := Voice.new()
	var sent: Array[PackedByteArray] = []
	voice.send = func(p: PackedByteArray) -> void: sent.append(p)
	voice.capture(_voice_like(VoicePacket.SAMPLES + 10), true, 0.1, 0.5)
	check(voice.sending, "talking")
	Settings.voice_on = false
	voice.apply_settings()
	check(not voice.sending, "off at once (the mic mark goes)")
	voice.receive(5, VoicePacket.pack(0, _voice_like(VoicePacket.SAMPLES), Adpcm.State.new()))
	check_eq(voice.heard.get(5, 0), 0, "nobody heard while off")
	Settings.voice_on = true
	voice.free()

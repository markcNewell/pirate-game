class_name Downsampler
extends RefCounted
## The mic arrives at the sound card's rate (usually 48 or 44.1 kHz) in stereo; voice goes out
## at 16 kHz mono. Each output sample is the average of the input samples it covers, which is
## cheap and also stops hiss above 8 kHz folding down into the voice.

var _step := 3.0
var _sum := 0.0
var _count := 0
var _phase := 0.0


func _init(from_rate: float) -> void:
	_step = from_rate / VoicePacket.RATE


## The 16 kHz samples that `frames` make, carrying any part-made sample on to the next call.
func push(frames: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int((frames.size() + _phase) / _step) + 1)
	var n := 0
	for f in frames:
		_sum += (f.x + f.y) * 0.5
		_count += 1
		_phase += 1.0
		if _phase >= _step:
			out[n] = _sum / _count
			n += 1
			_sum = 0.0
			_count = 0
			_phase -= _step
	out.resize(n)
	return out

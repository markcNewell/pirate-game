class_name VoiceQueue
extends RefCounted
## One speaker's packets waiting to be played. The network delivers them a little unevenly, so
## play starts only once START are here; late, repeated or out-of-date packets are dropped; and
## if more than MOST pile up (360 ms behind) the oldest go, so a voice never drifts behind.

const START := 2
const MOST := 6
## Keep this much in the sound player itself, so it never runs dry between frames.
const AHEAD := VoicePacket.SAMPLES * 2

var _seqs: Array[int] = []
var _samples: Array[PackedFloat32Array] = []
var _last := -1
var _started := false


func size() -> int:
	return _seqs.size()


func push(seq: int, samples: PackedFloat32Array) -> void:
	if _last >= 0 and not VoicePacket.newer(seq, _last):
		return
	var at := _seqs.size()
	for i in _seqs.size():
		if _seqs[i] == seq:
			return
		if VoicePacket.newer(_seqs[i], seq):
			at = i
			break
	_seqs.insert(at, seq)
	_samples.insert(at, samples)
	while _seqs.size() > MOST:
		_last = _seqs.pop_front()
		_samples.pop_front()


## The next packet's samples, if it is time: the player holds `buffered` samples still to
## play. Empty if it already holds enough or nothing is ready.
func pull(buffered: int) -> PackedFloat32Array:
	if buffered >= AHEAD:
		return PackedFloat32Array()
	if _seqs.is_empty():
		if buffered == 0:
			_started = false
		return PackedFloat32Array()
	if not _started:
		if _seqs.size() < START:
			return PackedFloat32Array()
		_started = true
	_last = _seqs.pop_front()
	return _samples.pop_front()

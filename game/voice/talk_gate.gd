class_name TalkGate
extends RefCounted
## Whether the mic is being sent: while V is held, or (open mic) while it is louder than
## `level` and for HANG seconds after, so the quiet ends of words aren't cut off.

const HANG := 0.4

var open_mic := false
## Open mic's level, 0-1, against the mic's loudest sample in each frame.
var level := 0.1
var _hang := 0.0


func update(delta: float, held: bool, loudness: float) -> bool:
	if held:
		return true
	if not open_mic:
		return false
	if loudness >= level:
		_hang = HANG
		return true
	_hang -= delta
	return _hang > 0.0

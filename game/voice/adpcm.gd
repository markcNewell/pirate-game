class_name Adpcm
extends RefCounted
## IMA ADPCM: each 16-bit sample squeezed to 4 bits by sending only how far it moved from a
## running guess, in steps that grow and shrink with the sound. Old, simple and good enough
## for a voice (docs/specs/2026-10-09-m25-voice.md). Samples here are floats in -1..1.

const STEPS: Array[int] = [
	7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66,
	73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408,
	449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
	2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630,
	9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794,
	32767,
]
const INDEX_MOVES: Array[int] = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]
const LAST_INDEX := 88


## Where the guess is and how big a step is: carried from one sample to the next, and written
## at the start of each packet so the packet decodes on its own.
class State:
	var predictor := 0
	var index := 0


## Two samples a byte, the first in the low four bits. Moves `state` on, so the next call
## carries straight on from this one.
static func encode(samples: PackedFloat32Array, state: State) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize((samples.size() + 1) / 2)
	var predictor := state.predictor
	var index := state.index
	for i in samples.size():
		var target := clampi(roundi(samples[i] * 32767.0), -32768, 32767)
		var step: int = STEPS[index]
		var diff := target - predictor
		var code := 0
		if diff < 0:
			code = 8
			diff = -diff
		# Each bit of the code says whether the difference holds another step, half and quarter
		# step; the decoder rebuilds the same amount, so track that, not the true difference.
		var moved := step >> 3
		if diff >= step:
			code |= 4
			diff -= step
			moved += step
		if diff >= step >> 1:
			code |= 2
			diff -= step >> 1
			moved += step >> 1
		if diff >= step >> 2:
			code |= 1
			moved += step >> 2
		predictor = clampi(predictor - moved if code & 8 else predictor + moved, -32768, 32767)
		index = clampi(index + INDEX_MOVES[code], 0, LAST_INDEX)
		if i % 2 == 0:
			out[i / 2] = code
		else:
			out[i / 2] |= code << 4
	state.predictor = predictor
	state.index = index
	return out


## `count` samples from `data` (which holds two a byte), starting from `state`.
static func decode(data: PackedByteArray, state: State, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(mini(count, data.size() * 2))
	var predictor := state.predictor
	var index := state.index
	for i in out.size():
		var code := (data[i / 2] >> 4) & 15 if i % 2 else data[i / 2] & 15
		var step: int = STEPS[index]
		var moved := step >> 3
		if code & 4:
			moved += step
		if code & 2:
			moved += step >> 1
		if code & 1:
			moved += step >> 2
		predictor = clampi(predictor - moved if code & 8 else predictor + moved, -32768, 32767)
		index = clampi(index + INDEX_MOVES[code], 0, LAST_INDEX)
		out[i] = predictor / 32768.0
	state.predictor = predictor
	state.index = index
	return out

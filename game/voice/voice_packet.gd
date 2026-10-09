class_name VoicePacket
extends RefCounted
## One packet of voice: 60 ms at 16 kHz, packed with Adpcm. Five bytes of header, then the
## samples two to a byte:
##   0-1  sequence number (0-65535, then round again), low byte first
##   2-3  the codec's guess at the start (signed), low byte first
##   4    the codec's step index at the start (0-88)
## The codec's state rides along, so a packet decodes even if the one before it was lost.

const RATE := 16000
const SAMPLES := 960
const HEADER := 5
## Anything bigger is not ours (a full packet is 485 bytes).
const MAX_BYTES := 600


## Packs `samples` (one packet's worth) and moves the sender's codec `state` on.
static func pack(seq: int, samples: PackedFloat32Array, state: Adpcm.State) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(HEADER)
	out.encode_u16(0, seq & 0xFFFF)
	out.encode_s16(2, state.predictor)
	out.encode_u8(4, state.index)
	out.append_array(Adpcm.encode(samples, state))
	return out


## {seq, samples}, or {} if `data` is not a voice packet.
static func unpack(data: PackedByteArray) -> Dictionary:
	if data.size() <= HEADER or data.size() > MAX_BYTES:
		return {}
	var state := Adpcm.State.new()
	state.predictor = data.decode_s16(2)
	state.index = data.decode_u8(4)
	if state.index > Adpcm.LAST_INDEX:
		return {}
	var body := data.slice(HEADER)
	return {"seq": data.decode_u16(0), "samples": Adpcm.decode(body, state, body.size() * 2)}


## Whether sequence number `a` comes after `b`, allowing for the count going round.
static func newer(a: int, b: int) -> bool:
	var ahead := (a - b) & 0xFFFF
	return ahead != 0 and ahead < 0x8000

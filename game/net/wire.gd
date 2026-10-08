class_name Wire
extends RefCounted
## Snapshots packed small for the network (docs/specs/2026-10-08-m24-lean-snapshots.md). Godot's
## own encoding spends 8-12 bytes on every number; here a small whole number (0-127) is one
## byte, other numbers two to five, so a busy scene's snapshot fits a packet or two instead of
## six. The snapshot keeps its shape (ServerSim.snapshot): [time, ships, players, items, crews,
## skeletons, story objects], each section a list of flat entries; a section sent as null means
## "unchanged, keep the last one".

## A byte with the top bit set is a whole number 0-127 by itself; otherwise it says what follows.
enum Tag { I8 = 1, I16, I32, I64, F32, F64, STR, NIL, ZERO, MINUS_ONE, TRUE, FALSE }

## Floats this big keep double precision (the server's clock after hours of play).
const BIG := 16384.0


## A snapshot as bytes: the time, then each section (absent, or a count and its entries).
static func encode_snapshot(snap: Array) -> PackedByteArray:
	var out := StreamPeerBuffer.new()
	out.put_double(float(snap[0]))
	for section in range(1, 7):
		var entries: Variant = snap[section] if section < snap.size() else null
		if entries == null:
			out.put_u8(0)
			continue
		out.put_u8(1)
		out.put_u16((entries as Array).size())
		for entry: Array in entries:
			# A ship is [id, its state]; everything else is already flat.
			put_values(out, [entry[0]] + entry[1] if section == 1 else entry)
	return out.data_array


static func decode_snapshot(bytes: PackedByteArray) -> Array:
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	var snap: Array = [buf.get_double()]
	for section in range(1, 7):
		if buf.get_u8() == 0:
			snap.append(null)
			continue
		var entries := []
		for n in buf.get_u16():
			var values := get_values(buf)
			entries.append([values[0], values.slice(1)] if section == 1 else values)
		snap.append(entries)
	return snap


## A flat list of numbers, strings, booleans and nulls.
static func put_values(out: StreamPeerBuffer, values: Array) -> void:
	out.put_u16(values.size())
	for v: Variant in values:
		match typeof(v):
			TYPE_BOOL:
				out.put_u8(Tag.TRUE if v else Tag.FALSE)
			TYPE_INT:
				_put_int(out, v)
			TYPE_FLOAT:
				_put_float(out, v)
			TYPE_STRING, TYPE_STRING_NAME:
				var b := str(v).to_utf8_buffer()
				out.put_u8(Tag.STR)
				out.put_u16(b.size())
				out.put_data(b)
			TYPE_NIL:
				out.put_u8(Tag.NIL)
			_:
				push_error("Wire: can't send a %s" % type_string(typeof(v)))
				out.put_u8(Tag.NIL)


static func get_values(buf: StreamPeerBuffer) -> Array:
	var values := []
	for n in buf.get_u16():
		var b := buf.get_u8()
		if b & 0x80:
			values.append(b & 0x7F)
			continue
		match b:
			Tag.I8:
				values.append(buf.get_8())
			Tag.I16:
				values.append(buf.get_16())
			Tag.I32:
				values.append(buf.get_32())
			Tag.I64:
				values.append(buf.get_64())
			Tag.F32:
				values.append(buf.get_float())
			Tag.F64:
				values.append(buf.get_double())
			Tag.STR:
				values.append(buf.get_data(buf.get_u16())[1].get_string_from_utf8())
			Tag.ZERO:
				values.append(0.0)
			Tag.MINUS_ONE:
				values.append(-1)
			Tag.TRUE:
				values.append(true)
			Tag.FALSE:
				values.append(false)
			_:
				values.append(null)
	return values


static func _put_int(out: StreamPeerBuffer, v: int) -> void:
	if v >= 0 and v <= 127:
		out.put_u8(0x80 | v)
	elif v == -1:
		out.put_u8(Tag.MINUS_ONE)
	elif v >= -128 and v <= 127:
		out.put_u8(Tag.I8)
		out.put_8(v)
	elif v >= -32768 and v <= 32767:
		out.put_u8(Tag.I16)
		out.put_16(v)
	elif v >= -2147483648 and v <= 2147483647:
		out.put_u8(Tag.I32)
		out.put_32(v)
	else:
		out.put_u8(Tag.I64)
		out.put_64(v)


static func _put_float(out: StreamPeerBuffer, v: float) -> void:
	if v == 0.0:
		out.put_u8(Tag.ZERO)
	elif absf(v) >= BIG or is_nan(v) or is_inf(v):
		out.put_u8(Tag.F64)
		out.put_double(v)
	else:
		out.put_u8(Tag.F32)
		out.put_float(v)

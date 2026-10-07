class_name Waves
extends RefCounted
## The one sea formula. The server floats ships with it and the ocean shader draws it.
## The shader gets these exact numbers from shader_params(), so the two cannot drift apart.
##
## Height is a sum of sine waves: amplitude * sin(k * (dir . p) - omega * t + phase),
## with omega = sqrt(g * k) so long waves travel faster, as on a real deep sea.

const GRAVITY := 9.81
const COUNT := 4

## Wavelength (m), amplitude (m), heading the wave travels toward (degrees), phase (rad).
const SPEC := [
	[62.0, 0.45, 10.0, 0.0],
	[37.0, 0.30, 55.0, 1.7],
	[21.0, 0.15, -25.0, 4.1],
	[11.5, 0.07, 120.0, 2.6],
]

static var _a := PackedVector4Array()
static var _b := PackedVector4Array()


static func _build() -> void:
	if _a.size() == COUNT:
		return
	for spec in SPEC:
		var k: float = TAU / spec[0]
		var heading := deg_to_rad(spec[2])
		_a.append(Vector4(cos(heading), sin(heading), k, spec[1]))
		_b.append(Vector4(sqrt(GRAVITY * k), spec[3], 0.0, 0.0))


static func height(x: float, z: float, t: float) -> float:
	_build()
	var h := 0.0
	for i in COUNT:
		var a := _a[i]
		h += a.w * sin(a.z * (a.x * x + a.y * z) - _b[i].x * t + _b[i].y)
	return h


static func normal(x: float, z: float, t: float) -> Vector3:
	_build()
	var dx := 0.0
	var dz := 0.0
	for i in COUNT:
		var a := _a[i]
		var slope := a.w * a.z * cos(a.z * (a.x * x + a.y * z) - _b[i].x * t + _b[i].y)
		dx += slope * a.x
		dz += slope * a.y
	return Vector3(-dx, 1.0, -dz).normalized()


static func max_height() -> float:
	var total := 0.0
	for spec in SPEC:
		total += spec[1]
	return total


static func shader_params() -> Dictionary:
	_build()
	return {"wave_a": _a, "wave_b": _b}

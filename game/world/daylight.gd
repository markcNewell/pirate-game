class_name Daylight
extends RefCounted
## The time of day and everything it colours: where the sun or moon is, the sky, fog, ambient
## light, the sea's tint and the stars. A day lasts 24 minutes of the shared server clock, so
## everyone on a server sees the same sunset. The sun rises in the east (+x) and arcs through
## the south (+z); nights are short and blue rather than black.

const DAY_LENGTH := 1440.0
## Where in the day a fresh server starts: mid-morning.
const START := 0.32

## Key looks by the sun's height above the horizon (the y of its direction), blended between.
## night, twilight, sunset, golden hour, full day.
const KEYS: Array[Dictionary] = [
	{
		"at": -0.42, "top": Color("0d1736"), "horizon": Color("24386b"), "ambient": Color("5a72b8"),
		"ambient_energy": 0.42, "light": Color("a9bcff"), "energy": 0.32, "fog": Color("1e2f5c"),
		"sea": Color(0.32, 0.38, 0.58), "cloud": Color(0.3, 0.31, 0.38), "glow": 0.0, "stars": 1.0, "lamps": 1.0,
	},
	{
		"at": -0.14, "top": Color("2b3d82"), "horizon": Color("d27a8c"), "ambient": Color("8c7cb4"),
		"ambient_energy": 0.38, "light": Color("c9a0c8"), "energy": 0.04, "fog": Color("8a6890"),
		"sea": Color(0.55, 0.52, 0.72), "cloud": Color(0.8, 0.6, 0.72), "glow": 0.7, "stars": 0.35, "lamps": 1.0,
	},
	{
		"at": 0.08, "top": Color("4a7fd0"), "horizon": Color("ffae6a"), "ambient": Color("d8a890"),
		"ambient_energy": 0.38, "light": Color("ffae70"), "energy": 0.62, "fog": Color("f2b48a"),
		"sea": Color(0.95, 0.80, 0.76), "cloud": Color(1.0, 0.76, 0.6), "glow": 1.0, "stars": 0.0, "lamps": 0.6,
	},
	{
		"at": 0.26, "top": Color("3a8ae6"), "horizon": Color("ffd9a8"), "ambient": Color("b8c4e0"),
		"ambient_energy": 0.38, "light": Color("ffe2b8"), "energy": 0.86, "fog": Color("e6dcc8"),
		"sea": Color(1.0, 0.95, 0.9), "cloud": Color(1.0, 0.94, 0.86), "glow": 0.3, "stars": 0.0, "lamps": 0.0,
	},
	{
		"at": 0.46, "top": Color("2f8ff0"), "horizon": Color("c4e9ff"), "ambient": Color("9cc8f0"),
		"ambient_energy": 0.38, "light": Color("fff6e5"), "energy": 0.9, "fog": Color("c4e9ff"),
		"sea": Color(1.0, 1.0, 1.0), "cloud": Color(1.0, 1.0, 1.0), "glow": 0.0, "stars": 0.0, "lamps": 0.0,
	},
]

## For screenshots and the title screen: a fixed time of day, or below 0 to follow the clock.
static var override := -1.0


static func time_of_day(server_time: float) -> float:
	if override >= 0.0:
		return fposmod(override, 1.0)
	return fposmod(START + server_time / DAY_LENGTH, 1.0)


## Unit vector toward the sun. 0.25 is sunrise in the east, 0.5 noon, 0.75 sunset in the west.
## The arc is lifted so the sun spends more of the day up than down.
static func sun_direction(t: float) -> Vector3:
	var a := (t - 0.25) * TAU
	return Vector3(cos(a), 0.95 * sin(a) + 0.3, 0.45).normalized()


## The moon rides opposite the sun, also in the southern sky.
static func moon_direction(t: float) -> Vector3:
	var s := sun_direction(t)
	return Vector3(-s.x, -s.y, s.z).normalized()


## Everything the world needs to colour itself at time `t`. The light comes from the sun until
## it dips below the horizon, then from the moon; its energy is near zero at the swap.
static func look(t: float) -> Dictionary:
	var sun := sun_direction(t)
	var out := _blend(sun.y)
	out["sun"] = sun
	out["moon"] = moon_direction(t)
	out["light_dir"] = sun if sun.y > KEYS[1].at else out.moon
	return out


static func _blend(height: float) -> Dictionary:
	if height <= KEYS[0].at:
		return KEYS[0].duplicate()
	for i in range(1, KEYS.size()):
		var b: Dictionary = KEYS[i]
		if height <= b.at:
			var a: Dictionary = KEYS[i - 1]
			var w := smoothstep(a.at, b.at, height)
			var out := {}
			for key: String in a:
				out[key] = lerp(a[key], b[key], w)
			return out
	return KEYS[KEYS.size() - 1].duplicate()

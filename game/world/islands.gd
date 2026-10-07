class_name Islands
extends RefCounted
## Where the islands are. The server uses the waterline circles to stop ships running through
## them and to place treasure; clients build the models and the foam rings from the same list.

## x, z: centre. radius: waterline radius (m). seed: shapes palms and rocks. hill: extra mound.
## outpost: the trading post (pier, merchant, supplies) faces +x from the centre.
const LAYOUT: Array[Dictionary] = [
	{"name": "Cutlass Cay", "x": 40.0, "z": -460.0, "radius": 60.0, "seed": 11, "hill": true, "outpost": false},
	{"name": "Parrot Rock", "x": 360.0, "z": -150.0, "radius": 26.0, "seed": 23, "hill": false, "outpost": false},
	{"name": "Gull Isle", "x": -300.0, "z": 140.0, "radius": 22.0, "seed": 37, "hill": false, "outpost": false},
	{"name": "Port Merrow", "x": -380.0, "z": -300.0, "radius": 30.0, "seed": 41, "hill": false, "outpost": true},
]

## Ships stop this far outside the waterline (their draught reaches out under the beach).
const SHIP_CLEARANCE := 3.0
## Treasure is buried on dry ground at least this high (above the beach).
const DIG_GROUND := 1.4


## Circles for ShipPhysics.step: waterline radius plus clearance.
static func ship_blockers() -> Array:
	var out := []
	for island in LAYOUT:
		out.append({"x": island.x, "z": island.z, "radius": island.radius + SHIP_CLEARANCE})
	return out


static func outpost_index() -> int:
	for i in LAYOUT.size():
		if LAYOUT[i].outpost:
			return i
	return -1


## Index of the island whose land is under a world point, or -1.
static func island_at(x: float, z: float) -> int:
	for i in LAYOUT.size():
		var spec: Dictionary = LAYOUT[i]
		var dx: float = x - spec.x
		var dz: float = z - spec.z
		if dx * dx + dz * dz < (spec.radius + 2.0) ** 2:
			return i
	return -1


static func ground_at(index: int, x: float, z: float) -> float:
	var spec: Dictionary = LAYOUT[index]
	return IslandMesh.ground(spec, x - spec.x, z - spec.z)


## A random dry spot on an island (world x, z), for buried treasure.
static func dig_spot(index: int, rng: RandomNumberGenerator) -> Vector2:
	var spec: Dictionary = LAYOUT[index]
	for attempt in 200:
		var a := rng.randf() * TAU
		var r: float = rng.randf_range(0.15, 0.8) * spec.radius
		var x: float = spec.x + cos(a) * r
		var z: float = spec.z + sin(a) * r
		if ground_at(index, x, z) >= DIG_GROUND:
			return Vector2(x, z)
	return Vector2(spec.x, spec.z)

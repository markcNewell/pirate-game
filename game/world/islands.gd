class_name Islands
extends RefCounted
## Where the islands are. The server uses the waterline circles to stop ships running through
## them and to place treasure; clients build the models and the foam rings from the same list.

## x, z: centre. radius: waterline radius (m). seed: shapes palms and rocks. hill: extra mound.
## outpost: the trading post (pier, merchant, supplies) faces +x from the centre.
## landmark (optional): "arch" (a rock arch on the beach) or "stacks" (sea stacks off the shore).
## Act IV (docs/specs/2026-10-08-m11-the-drowned-fleet.md): skull (Isla Calavera's skull rock,
## Calavera), ash (grey sand and dead trees), stack (a small flat-topped rock on the Black Reef's
## rim). story_only: no board missions, camps or crabs there.
const LAYOUT: Array[Dictionary] = [
	{"name": "Cutlass Cay", "x": 40.0, "z": -460.0, "radius": 60.0, "seed": 11, "hill": true, "outpost": false},
	{"name": "Parrot Rock", "x": 360.0, "z": -150.0, "radius": 26.0, "seed": 23, "hill": false, "outpost": false, "landmark": "stacks"},
	{"name": "Gull Isle", "x": -300.0, "z": 140.0, "radius": 22.0, "seed": 37, "hill": false, "outpost": false, "landmark": "arch"},
	{"name": "Port Merrow", "x": -380.0, "z": -300.0, "radius": 30.0, "seed": 41, "hill": false, "outpost": true},
	# The Admiral's fort (story Act II): a flat-topped rock with Fuerte del Cuervo on it (Fort).
	{"name": "Fuerte del Cuervo", "x": 330.0, "z": 380.0, "radius": 34.0, "seed": 53, "hill": false, "outpost": false, "fort": true},
	{"name": "Isla Calavera", "x": -160.0, "z": 560.0, "radius": 32.0, "seed": 61, "hill": false, "outpost": false, "skull": true},
	{"name": "Isla Ceniza", "x": 420.0, "z": 800.0, "radius": 48.0, "seed": 67, "hill": true, "outpost": false, "ash": true, "story_only": true},
	{"name": "the West Stack", "x": 605.0, "z": 564.0, "radius": 10.0, "seed": 71, "hill": false, "outpost": false, "stack": true, "story_only": true},
	{"name": "the North Stack", "x": 816.0, "z": 465.0, "radius": 10.0, "seed": 73, "hill": false, "outpost": false, "stack": true, "story_only": true},
	{"name": "the South Stack", "x": 842.0, "z": 763.0, "radius": 10.0, "seed": 79, "hill": false, "outpost": false, "stack": true, "story_only": true},
	# Act V: the flat black rock beside the Maw where the Bone Colossus falls.
	{"name": "the Anvil", "x": 715.0, "z": 655.0, "radius": 13.0, "seed": 83, "hill": false, "outpost": false, "stack": true, "anvil": true, "story_only": true},
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
	out.append_array(Reef.blockers())
	return out


static func outpost_index() -> int:
	for i in LAYOUT.size():
		if LAYOUT[i].outpost:
			return i
	return -1


## Index of the island whose land is under a world point, or -1.
## The island whose waterline (plus `margin` metres) contains the point, or -1.
static func island_at(x: float, z: float, margin := 2.0) -> int:
	for i in LAYOUT.size():
		var spec: Dictionary = LAYOUT[i]
		var dx: float = x - spec.x
		var dz: float = z - spec.z
		if dx * dx + dz * dz < (spec.radius + margin) ** 2:
			return i
	return -1


static func ground_at(index: int, x: float, z: float) -> float:
	var spec: Dictionary = LAYOUT[index]
	return IslandMesh.ground(spec, x - spec.x, z - spec.z)


## Where the cargo trader waits on an island (world): up the beach, on its own side of the
## island (away from where its camp usually is).
static func trader_spot(index: int) -> Vector3:
	var spec: Dictionary = LAYOUT[index]
	var a := 0.8 + index * 2.3
	var r: float = spec.radius - 7.5
	var x: float = spec.x + cos(a) * r
	var z: float = spec.z + sin(a) * r
	return Vector3(x, ground_at(index, x, z), z)


## Islands missions can go to (every island but the outpost).
static func mission_islands() -> Array[int]:
	var out: Array[int] = []
	for i in LAYOUT.size():
		if not LAYOUT[i].outpost and not LAYOUT[i].get("fort", false) and not LAYOUT[i].get("story_only", false):
			out.append(i)
	return out


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

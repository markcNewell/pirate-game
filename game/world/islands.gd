class_name Islands
extends RefCounted
## Where the islands are. The server uses the waterline circles to stop ships running through
## them; clients build the models and the foam rings from the same list.

## x, z: centre. radius: waterline radius (m). seed: shapes palms and rocks. hill: extra mound.
const LAYOUT: Array[Dictionary] = [
	{"x": 40.0, "z": -460.0, "radius": 60.0, "seed": 11, "hill": true},
	{"x": 360.0, "z": -150.0, "radius": 26.0, "seed": 23, "hill": false},
	{"x": -300.0, "z": 140.0, "radius": 22.0, "seed": 37, "hill": false},
]

## Ships stop this far outside the waterline (their draught reaches out under the beach).
const SHIP_CLEARANCE := 3.0


## Circles for ShipPhysics.step: waterline radius plus clearance.
static func ship_blockers() -> Array:
	var out := []
	for island in LAYOUT:
		out.append({"x": island.x, "z": island.z, "radius": island.radius + SHIP_CLEARANCE})
	return out

class_name Reef
extends RefCounted
## The Black Reef (story Act IV, docs/specs/2026-10-08-m11-the-drowned-fleet.md): a ring of
## black rocks and old wreck masts far to the south-east, under a storm that never leaves. Its
## heart tears the hull of any ship whose crew doesn't know the channel (the pilot's chart).

const CENTRE := Vector2(760.0, 620.0)
## Its own storm, as wide as the roaming one (Storm.amount takes the stronger of the two).
const STORM_RADIUS := 150.0
## Within this of the centre the rocks tear a ship every TEAR_EVERY seconds, without the chart.
const HEART := 100.0
const TEAR_EVERY := 8.0
## Rocks breaking the surface round the heart: [angle, distance from the centre, size]. Ships
## steer round them like small islands.
const ROCKS := [
	[0.1, 112.0, 1.0], [0.55, 104.0, 1.4], [1.0, 116.0, 1.0], [1.7, 108.0, 1.4], [2.1, 118.0, 1.0],
	[2.9, 110.0, 1.4], [3.4, 102.0, 1.0], [4.0, 114.0, 1.4], [4.6, 106.0, 1.0], [5.3, 118.0, 1.4],
	[5.8, 100.0, 1.0], [1.3, 60.0, 1.0], [3.9, 70.0, 1.4], [5.1, 45.0, 1.0],
]
## Masts of the drowned fleet standing out of the sea: [angle, distance from the centre, yaw].
const MASTS := [[0.3, 80.0, 0.4], [1.5, 40.0, 2.1], [2.6, 90.0, 4.0], [3.6, 30.0, 1.0], [4.8, 85.0, 5.5], [5.6, 60.0, 3.0]]


static func rock_at(i: int) -> Vector2:
	var r: Array = ROCKS[i]
	return CENTRE + Vector2(cos(r[0]), sin(r[0])) * float(r[1])


static func mast_at(i: int) -> Vector2:
	var m: Array = MASTS[i]
	return CENTRE + Vector2(cos(m[0]), sin(m[0])) * float(m[1])


## Ship blockers for the rocks: like islands, waterline radius plus clearance.
static func blockers() -> Array:
	var out := []
	for i in ROCKS.size():
		var p := rock_at(i)
		out.append({"x": p.x, "z": p.y, "radius": 3.5 * float(ROCKS[i][2]) + Islands.SHIP_CLEARANCE})
	return out


## How deep in the Reef's storm a point is: 1 near the middle, 0 well outside.
static func amount(pos: Vector2) -> float:
	return 1.0 - smoothstep(0.7, Storm.EDGE, pos.distance_to(CENTRE) / STORM_RADIUS)


static func in_heart(pos: Vector2) -> bool:
	return pos.distance_to(CENTRE) < HEART

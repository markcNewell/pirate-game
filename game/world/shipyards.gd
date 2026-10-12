class_name Shipyards
extends RefCounted
## Where crews start, and where they buy a ship once theirs is sunk
## (docs/specs/2026-10-12-m26-shipyards.md). Port Merrow's yard is Old Hobb on his pier, and
## each crew's first ship is moored there; Cutlass Cay, Parrot Rock and Gull Isle each have a
## jetty with a shipwright at its landward end and a berth alongside. All in world space.

## How close to a shipwright you must stand to buy.
const REACH := 3.2
## A jetty runs out from this far inside the waterline to this far beyond it.
const JETTY_IN := 4.0
const JETTY_OUT := 20.0
const JETTY_HALF_WIDTH := 0.8
const JETTY_Y := 1.0
const MERROW := 0

## [island index, angle round the island from +x (radians), shipwright id, name]. The first is
## Merrow (Old Hobb, on the pier; its angle is the pier's).
const YARDS := [
	[3, 0.0, "hobb", "Old Hobb"],
	[0, 2.6, "peg", "Peg Oakum"],
	[1, 2.9, "tarr", "Bartholomew Tarr"],
	[2, -2.6, "nan", "Nan Caulker"],
]


static func count() -> int:
	return YARDS.size()


static func island(i: int) -> Dictionary:
	return Islands.LAYOUT[int(YARDS[i][0])]


static func wright_name(i: int) -> String:
	return YARDS[i][3]


static func _dir(i: int) -> Vector3:
	var a: float = YARDS[i][1]
	return Vector3(cos(a), 0.0, sin(a))


static func _centre(i: int) -> Vector3:
	var isl := island(i)
	return Vector3(isl.x, 0.0, isl.z)


## Where the shipwright stands.
static func wright_pos(i: int) -> Vector3:
	if i == MERROW:
		return Outpost.hobb_pos()
	var isl := island(i)
	var at := _centre(i) + _dir(i) * (float(isl.radius) - JETTY_IN + 1.0)
	at.y = IslandMesh.ground(isl, at.x - isl.x, at.z - isl.z)
	return at


## The jetty's landward and seaward ends, on its deck (not Merrow's, which is the pier).
static func jetty(i: int) -> Array[Vector3]:
	var r: float = island(i).radius
	var up := Vector3.UP * JETTY_Y
	return [_centre(i) + _dir(i) * (r - JETTY_IN) + up, _centre(i) + _dir(i) * (r + JETTY_OUT) + up]


static func on_jetty(i: int, x: float, z: float) -> bool:
	if i == MERROW:
		return Outpost.on_pier(x, z)
	var ends := jetty(i)
	var p := Vector2(x, z)
	var a := Vector2(ends[0].x, ends[0].z)
	var b := Vector2(ends[1].x, ends[1].z)
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return p.distance_to(a.lerp(b, t)) <= JETTY_HALF_WIDTH


## The yard whose shipwright is within reach of `pos`, or -1.
static func at(pos: Vector3) -> int:
	for i in count():
		if Vector2(pos.x, pos.z).distance_to(Vector2(wright_pos(i).x, wright_pos(i).z)) <= REACH:
			return i
	return -1


## Where a ship of `hull` is moored at yard `i`: {x, z, yaw}, her bow out to sea, alongside
## the jetty with a ladder by it. At Merrow each crew has its own berth by the pier, so the
## crews' ships never meet there.
static func berth(i: int, hull: Hull, crew := 1) -> Dictionary:
	if i == MERROW:
		return merrow_berth(crew, hull)
	var d := _dir(i)
	var side := Vector3(-d.z, 0.0, d.x)
	var r: float = island(i).radius
	# Stern just off the waterline; out from the jetty by its half width, her beam and a gap.
	var along := r + 3.0 + hull.half_length
	var out := JETTY_HALF_WIDTH + hull.half_width(0.0, hull.deck_y) + 0.8
	var p := _centre(i) + d * along + side * out
	return {"x": p.x, "z": p.z, "yaw": atan2(-d.x, -d.z)}


## A crew's berth at Merrow: crews 1 and 2 either side of the pier, 3 and 4 a swim beyond its end.
static func merrow_berth(crew: int, hull := Hull.galleon()) -> Dictionary:
	var c := Outpost.spec()
	var r: float = c.radius
	var beyond := 0.0 if crew <= 2 else 30.0
	var side := 1.0 if crew % 2 == 1 else -1.0
	var out := Outpost.PIER_HALF_WIDTH + hull.half_width(0.0, hull.deck_y) + 0.7
	return {"x": float(c.x) + r + 1.0 + hull.half_length + beyond, "z": float(c.z) + side * out, "yaw": -PI / 2.0}


## Where a pirate of `crew` starts (or wakes with no ship) on Merrow's pier, facing their
## berth; `n` spreads several of them along it.
static func pier_spawn(crew: int, n := 0) -> Dictionary:
	var c := Outpost.spec()
	var r: float = c.radius
	var x := float(c.x) + r + (15.0 if crew > 2 else 8.0) + 1.2 * (n % 4)
	var side := 1.0 if crew % 2 == 1 else -1.0
	return {"pos": Vector3(x, Outpost.PIER_Y, float(c.z) + side * 0.6), "yaw": PI if side > 0.0 else 0.0}

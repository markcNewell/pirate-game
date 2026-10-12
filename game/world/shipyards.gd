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
## High enough that a swimmer's head clears the planks: you swim under a jetty, between its piles
## (which are only for show), rather than bumping along it (playtest bots did).
const JETTY_Y := 1.3
## The landward end ramps up from the sand over this many metres.
const JETTY_RAMP := 3.0
## Jetty decks are on their own collision layer, which you walk on but swim under: a swimmer
## coming ashore beside a jetty would otherwise snag on its planks (playtest bots did).
const JETTY_LAYER := 4
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


## Where a pirate of `crew` starts (or wakes with no ship) on Merrow's pier, beside their
## berth and facing up the pier to the port (and Moll); `n` spreads several of them along it.
static func pier_spawn(crew: int, n := 0) -> Dictionary:
	var c := Outpost.spec()
	var r: float = c.radius
	# By the ship's ladder (crews 1 and 2), or at the pier's end for the swim out (3 and 4).
	var x := float(c.x) + r + (16.5 if crew > 2 else 12.5) + 1.2 * (n % 4)
	var side := 1.0 if crew % 2 == 1 else -1.0
	return {"pos": Vector3(x, Outpost.PIER_Y, float(c.z) + side * 0.6), "yaw": PI / 2.0}


## A yard's jetty, signboard and stack of timber, in island-local space (the island's centre at
## the origin): {"mesh" (solid), "deco" (the planks, piles and bollards, nothing to bump into),
## "faces" (the sign and timber), "jetty" (the deck to walk on, on JETTY_LAYER), "sign": [where
## its lettering goes, facing]}.
## Merrow's yard is Old Hobb's pier, built with the port.
static func build(i: int) -> Dictionary:
	var b := MeshBuilder.new()
	var c := _centre(i)
	var ends := jetty(i)
	var a := ends[0] - c
	var e := ends[1] - c
	var d := _dir(i)
	var side := Vector3(-d.z, 0.0, d.x)
	var basis := Basis.looking_at(d, Vector3.UP)
	var length := a.distance_to(e)
	var isl := island(i)
	var sand := IslandMesh.ground(isl, a.x, a.z)
	var height := func(along: float) -> float:
		# Up the ramp from the sand, then level out to sea.
		return lerpf(sand + 0.06, JETTY_Y, clampf(along / JETTY_RAMP, 0.0, 1.0))
	# The planks and piles are for show (deco). What you walk on is their top surface alone,
	# solid only from above, so a swimmer under the jetty never snags on it.
	var deco := MeshBuilder.new()
	var walk := MeshBuilder.new()
	var planks := int(length / 0.36)
	for k in planks:
		var along := (k + 0.5) / planks * length
		var at := a + d * along
		at.y = height.call(along)
		var tilt := Basis(side, atan2(JETTY_Y - sand, JETTY_RAMP)) if along < JETTY_RAMP else Basis.IDENTITY
		deco.box(at + Vector3(0, -0.06, 0), Vector3(JETTY_HALF_WIDTH, 0.06, 0.16), Color("b98a55").darkened(0.05 * (k % 3)), tilt * basis)
	var cuts: Array[float] = [0.0, JETTY_RAMP * 0.5, JETTY_RAMP, length]
	for k in cuts.size() - 1:
		var p0 := a + d * cuts[k]
		var p1 := a + d * cuts[k + 1]
		p0.y = height.call(cuts[k])
		p1.y = height.call(cuts[k + 1])
		var w := side * JETTY_HALF_WIDTH
		walk.quad(p0 - w, p0 + w, p1 + w, p1 - w, Color.BLACK, Vector3.UP)
	var t := JETTY_RAMP
	while t <= length:
		for s: float in [-1.0, 1.0]:
			var p := a + d * t + side * s * (JETTY_HALF_WIDTH - 0.1)
			deco.box(Vector3(p.x, JETTY_Y - 1.6, p.z), Vector3(0.11, 1.5, 0.11), Color("6a4a2e"), basis)
		t += 3.0
	# Bollards at the seaward end to make a ship fast to.
	for s: float in [-1.0, 1.0]:
		var bollard := Vector3(e.x, JETTY_Y, e.z) + side * s * 0.55
		deco.cylinder(bollard, bollard + Vector3(0, 0.45, 0), 0.13, 0.11, 8, Color("4a3424"))
	var w := wright_pos(i) - c
	var at_sign := w + side * 1.7
	b.box(at_sign + Vector3(0, 0.9, 0), Vector3(0.07, 1.0, 0.07), Color("6a4a2e"), basis)
	b.box(at_sign + Vector3(0, 1.8, 0), Vector3(0.95, 0.32, 0.05), Color("d8b07a"), basis)
	# Seasoned timber waiting for the next hull.
	for k in 4:
		var y := w.y + 0.12 + 0.24 * (k / 2)
		var off := -side * (2.2 + 0.3 * (k % 2))
		b.box(w + off + Vector3(0, y - w.y, 0), Vector3(0.12, 0.12, 1.6), Color("a0784a").darkened(0.06 * k), basis)
	return {"mesh": b.build(), "deco": deco.build(), "faces": b.faces(), "jetty": walk.faces(), "sign": [at_sign + Vector3(0, 1.8, 0) - d * 0.07, atan2(-d.x, -d.z) + PI]}


## Whether island-local (x, z) of `spec` is where a yard stands (no palms grow there).
static func clearing(spec: Dictionary, x: float, z: float) -> bool:
	for i in range(1, count()):
		if island(i) != spec:
			continue
		var w := wright_pos(i)
		if Vector2(x + float(spec.x), z + float(spec.z)).distance_to(Vector2(w.x, w.z)) < 7.0:
			return true
	return false


## Test hook (--wreck-at): a spot in the water a short swim from yard `i`, clear of its jetty
## and berth, from where a straight swim reaches the beach by the shipwright.
static func test_swim_spot(i: int) -> Vector3:
	var w := wright_pos(i)
	if i == MERROW:
		# South of the pier, so the way in crosses the beach rather than the pier's piles.
		var c := Outpost.spec()
		return Vector3(float(c.x) + float(c.radius) + 8.0, 0.0, float(c.z) + 24.0)
	var d := _dir(i)
	var side := Vector3(-d.z, 0.0, d.x)
	return Vector3(w.x, 0.0, w.z) + d * 18.0 - side * 9.0

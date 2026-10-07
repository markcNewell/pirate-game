class_name Outpost
extends RefCounted
## Port Merrow, the trading post: a pier running out to sea, a merchant's hut on the beach
## where chests are sold, supply barrels on the pier, a flag and some lamps. Positions are
## worked out from the island's layout entry, so the server and the model always agree.

const PIER_START := -6.0  # metres from the waterline radius (negative = inland)
const PIER_END := 18.0
const PIER_HALF_WIDTH := 1.6
const PIER_Y := 1.2
## The merchant's hut sits on the beach this far round from the pier (radians).
const HUT_ANGLE := 0.55
const HUT_RADIUS_IN := 5.0
const REACH := 3.2
## The lighthouse stands on the far side of the island from the pier.
const LIGHTHOUSE_ANGLE := -2.0
const LIGHTHOUSE_IN := 8.0
const LIGHTHOUSE_HEIGHT := 13.0


static func spec() -> Dictionary:
	return Islands.LAYOUT[Islands.outpost_index()]


static func _centre() -> Vector3:
	var s := spec()
	return Vector3(s.x, 0.0, s.z)


## Point at `r` from the island centre, `a` radians round from +x, `y` up (world).
static func _at(r: float, a: float, y: float) -> Vector3:
	return _centre() + Vector3(cos(a) * r, y, sin(a) * r)


static func merchant_pos() -> Vector3:
	var r: float = spec().radius - HUT_RADIUS_IN
	return _at(r - 0.9, HUT_ANGLE, PIER_Y)


## Where you stand to sell: in front of the counter, toward the sea.
static func sell_spot() -> Vector3:
	var r: float = spec().radius - HUT_RADIUS_IN
	return _at(r + 1.8, HUT_ANGLE, PIER_Y)


static func barrels() -> Array[Vector3]:
	var r: float = spec().radius + PIER_END - 3.0
	var out: Array[Vector3] = []
	for dz: float in [-0.9, 0.0, 0.9]:
		out.append(_centre() + Vector3(r, PIER_Y + 0.45, dz))
	return out


## A good anchorage off the merchant's beach (used by tests to start nearby).
## The lighthouse's foot, island-local.
static func _lighthouse_foot() -> Vector3:
	var s := spec()
	var r: float = s.radius - LIGHTHOUSE_IN
	var x := cos(LIGHTHOUSE_ANGLE) * r
	var z := sin(LIGHTHOUSE_ANGLE) * r
	return Vector3(x, IslandMesh.ground(s, x, z) - 0.3, z)


## The middle of the lighthouse's lamp room, in world space.
static func lighthouse_lamp() -> Vector3:
	return _centre() + _lighthouse_foot() + Vector3(0, LIGHTHOUSE_HEIGHT + 1.1, 0)


## Where the pier lamps and the hut's lantern hang, in world space.
static func lamps() -> Array[Vector3]:
	var r1: float = spec().radius + PIER_END
	var out: Array[Vector3] = []
	for side: float in [-1.0, 1.0]:
		out.append(_centre() + Vector3(r1 - 0.4, PIER_Y + 2.6, side * (PIER_HALF_WIDTH - 0.15)))
	out.append(merchant_pos() + Vector3(0, 2.4, 0))
	return out


static func anchorage() -> Vector3:
	return _at(spec().radius + 40.0, HUT_ANGLE, 0.0)


## The model and its collision, in island-local coordinates (the island's centre at the origin).
static func build() -> Dictionary:
	var s := spec()
	var b := MeshBuilder.new()
	var solid := MeshBuilder.new()
	var wood := Toon.color("deck")
	var dark := Toon.color("hull_dark")
	var r0: float = s.radius + PIER_START
	var r1: float = s.radius + PIER_END

	# Pier: planks across, posts down into the sea, a low rail along each side.
	var x := r0
	var plank := 0
	while x < r1:
		var c := wood if plank % 2 == 0 else wood.darkened(0.08)
		b.box(Vector3(x + 0.3, PIER_Y - 0.08, 0), Vector3(0.29, 0.08, PIER_HALF_WIDTH), c)
		x += 0.6
		plank += 1
	solid.box(Vector3((r0 + r1) * 0.5, PIER_Y - 0.1, 0), Vector3((r1 - r0) * 0.5, 0.1, PIER_HALF_WIDTH), Color.BLACK)
	var px := r0 + 2.0
	while px <= r1:
		for side: float in [-1.0, 1.0]:
			b.cylinder(Vector3(px, -4.0, side * (PIER_HALF_WIDTH - 0.15)), Vector3(px, PIER_Y + 0.9, side * (PIER_HALF_WIDTH - 0.15)), 0.16, 0.16, 7, dark)
			solid.box(Vector3(px, PIER_Y + 0.45, side * (PIER_HALF_WIDTH - 0.15)), Vector3(0.16, 0.45, 0.16), Color.BLACK)
		px += 3.0
	for side: float in [-1.0, 1.0]:
		b.box(Vector3((r0 + 2.0 + r1) * 0.5, PIER_Y + 0.85, side * (PIER_HALF_WIDTH - 0.15)), Vector3((r1 - r0 - 2.0) * 0.5, 0.05, 0.06), Toon.color("rope"))
	# Lamps at the end of the pier.
	for side: float in [-1.0, 1.0]:
		var foot := Vector3(r1 - 0.4, PIER_Y, side * (PIER_HALF_WIDTH - 0.15))
		b.cylinder(foot, foot + Vector3(0, 2.4, 0), 0.07, 0.07, 6, dark)
		b.box(foot + Vector3(0, 2.6, 0), Vector3(0.2, 0.22, 0.2), Toon.color("lantern"))

	# Supply barrels near the end of the pier.
	for p in barrels():
		var local := p - _centre()
		_barrel(b, Vector3(local.x, PIER_Y, local.z))
		solid.box(Vector3(local.x, PIER_Y + 0.45, local.z), Vector3(0.38, 0.45, 0.38), Color.BLACK)

	_hut(b, solid)
	_lighthouse(b, solid)
	# Flag pole by the root of the pier.
	var pole := Vector3(r0 - 1.0, IslandMesh.ground(s, r0 - 1.0, -3.0), -3.0)
	b.cylinder(pole, pole + Vector3(0, 9, 0), 0.12, 0.08, 7, dark)
	b.box(pole + Vector3(0.9, 8.3, 0), Vector3(0.85, 0.5, 0.03), Color("d63c3c"))
	b.box(pole + Vector3(0.9, 8.3, 0), Vector3(0.3, 0.18, 0.05), Toon.color("gold"))
	return {"mesh": b.build(), "merchant": Avatar.merchant_mesh(), "faces": solid.faces()}


static func _barrel(b: MeshBuilder, foot: Vector3) -> void:
	b.cylinder(foot, foot + Vector3(0, 0.9, 0), 0.34, 0.38, 10, Toon.color("trunk"))
	for h: float in [0.2, 0.65]:
		b.cylinder(foot + Vector3(0, h, 0), foot + Vector3(0, h + 0.08, 0), 0.39, 0.39, 10, Toon.color("trim"))
	b.cylinder(foot + Vector3(0, 0.9, 0), foot + Vector3(0, 0.95, 0), 0.3, 0.3, 10, Toon.color("deck"))


## A striped lighthouse: a tapering tower, a railed gallery, the lamp room and a red cap.
static func _lighthouse(b: MeshBuilder, solid: MeshBuilder) -> void:
	var foot := _lighthouse_foot()
	var white := Color("f4efe2")
	var red := Color("c8302a")
	var stripes := 5
	for i in stripes:
		var y0 := LIGHTHOUSE_HEIGHT * i / stripes
		var y1 := LIGHTHOUSE_HEIGHT * (i + 1) / stripes
		var r0 := lerpf(2.3, 1.5, float(i) / stripes)
		var r1 := lerpf(2.3, 1.5, float(i + 1) / stripes)
		b.cylinder(foot + Vector3(0, y0, 0), foot + Vector3(0, y1, 0), r0, r1, 14, white if i % 2 == 0 else red)
	var top := foot + Vector3(0, LIGHTHOUSE_HEIGHT, 0)
	b.cylinder(top, top + Vector3(0, 0.25, 0), 2.2, 2.2, 14, Color("3a3a42"))
	for k in 12:
		var a := TAU * k / 12.0
		b.box(top + Vector3(cos(a) * 2.05, 0.75, sin(a) * 2.05), Vector3(0.05, 0.5, 0.05), Color("3a3a42"))
	b.cylinder(top + Vector3(0, 1.2, 0), top + Vector3(0, 1.28, 0), 2.1, 2.1, 14, Color("3a3a42"))
	b.cylinder(top + Vector3(0, 0.25, 0), top + Vector3(0, 2.0, 0), 1.05, 1.05, 10, Color("fff3b0"))
	b.cylinder(top + Vector3(0, 2.0, 0), top + Vector3(0, 3.3, 0), 1.45, 0.0, 10, red)
	# A door at the foot, facing the middle of the island.
	var inward := -Vector3(foot.x, 0, foot.z).normalized()
	b.box(foot + inward * 2.2 + Vector3(0, 1.0, 0), Vector3(0.6, 1.0, 0.1), Color("4a2c1c"), Basis.looking_at(inward))
	solid.box(foot + Vector3(0, LIGHTHOUSE_HEIGHT * 0.5, 0), Vector3(1.9, LIGHTHOUSE_HEIGHT * 0.5, 1.9), Color.BLACK)


## The merchant's hut: plank walls on three sides, open toward the sea with a counter,
## a striped awning and a sign.
static func _hut(b: MeshBuilder, solid: MeshBuilder) -> void:
	var s := spec()
	var r: float = s.radius - HUT_RADIUS_IN
	var centre := Vector3(cos(HUT_ANGLE) * r, PIER_Y, sin(HUT_ANGLE) * r)
	# Local hut frame: +x points out to sea.
	var basis := Basis(Vector3.UP, -HUT_ANGLE)
	var at := func(v: Vector3) -> Vector3: return centre + basis * v
	var wall := Toon.color("hull")
	var floor_c := Toon.color("deck").darkened(0.2)
	b.box(at.call(Vector3(-0.5, -0.1, 0)), Vector3(2.6, 0.1, 2.4), floor_c, basis)
	solid.box(at.call(Vector3(-0.5, -0.1, 0)), Vector3(2.6, 0.1, 2.4), Color.BLACK, basis)
	for spec_wall in [
		[Vector3(-2.9, 1.4, 0), Vector3(0.12, 1.4, 2.4)],
		[Vector3(-0.5, 1.4, -2.3), Vector3(2.5, 1.4, 0.12)],
		[Vector3(-0.5, 1.4, 2.3), Vector3(2.5, 1.4, 0.12)],
	]:
		b.box(at.call(spec_wall[0]), spec_wall[1], wall, basis)
		solid.box(at.call(spec_wall[0]), spec_wall[1], Color.BLACK, basis)
	# Counter across the open front.
	b.box(at.call(Vector3(1.6, 0.55, 0)), Vector3(0.35, 0.55, 2.0), Toon.color("deck"), basis)
	b.box(at.call(Vector3(1.6, 1.13, 0)), Vector3(0.45, 0.05, 2.1), Toon.color("hull_dark"), basis)
	solid.box(at.call(Vector3(1.6, 0.55, 0)), Vector3(0.35, 0.55, 2.0), Color.BLACK, basis)
	# Roof and a red and cream striped awning over the counter.
	b.box(at.call(Vector3(-0.5, 2.9, 0)), Vector3(2.8, 0.12, 2.6), Toon.color("hull_dark"), basis)
	for i in 6:
		var c := Color("d63c3c") if i % 2 == 0 else Toon.color("sail")
		var z := -2.1 + i * 0.84
		b.box(at.call(Vector3(2.4, 2.55, z + 0.42)), Vector3(0.75, 0.05, 0.42), c, basis * Basis(Vector3.BACK, -0.35))
	# Sign board on the roof.
	b.box(at.call(Vector3(1.2, 3.45, 0)), Vector3(0.08, 0.4, 1.4), Toon.color("trunk"), basis)
	b.box(at.call(Vector3(1.27, 3.45, 0)), Vector3(0.02, 0.18, 0.9), Toon.color("gold"), basis)

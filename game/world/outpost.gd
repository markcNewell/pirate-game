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
## The Order of Souls' mystic stands on the beach the other side of the pier from the hut.
const MYSTIC_ANGLE := -0.62
## The Merchant Alliance's agent stands at the root of the pier, beside the cargo.
const AGENT_AT := Vector3(3.0, 0.0, -1.05)
## The tavern sits inland, round from the hut, its door facing the sea.
const TAVERN_ANGLE := 1.45
const TAVERN_IN := 13.0


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


## Where the Order of Souls' mystic stands (world), and where you stand to sell him a skull.
static func mystic_pos() -> Vector3:
	var r: float = spec().radius - HUT_RADIUS_IN - 2.0
	var x := cos(MYSTIC_ANGLE) * r
	var z := sin(MYSTIC_ANGLE) * r
	return _centre() + Vector3(x, IslandMesh.ground(spec(), x, z), z)


static func mystic_spot() -> Vector3:
	var r: float = spec().radius - HUT_RADIUS_IN + 0.2
	var x := cos(MYSTIC_ANGLE) * r
	var z := sin(MYSTIC_ANGLE) * r
	return _centre() + Vector3(x, IslandMesh.ground(spec(), x, z), z)


## The Merchant Alliance's agent, on the pier (world).
static func agent_pos() -> Vector3:
	var r0: float = spec().radius + PIER_START
	return _centre() + Vector3(r0 + AGENT_AT.x, PIER_Y, AGENT_AT.z)


## Where a cargo run's crates wait on the pier (world): along it, beside the agent.
static func cargo_spot(i: int) -> Vector3:
	var r0: float = spec().radius + PIER_START
	return _centre() + Vector3(r0 + 4.4 + 1.05 * i, PIER_Y, 0.75)


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


## The tavern's frame, island-local: +x out of its front door toward the sea.
static func _tavern_frame() -> Transform3D:
	var s := spec()
	var r: float = s.radius - TAVERN_IN
	var x := cos(TAVERN_ANGLE) * r
	var z := sin(TAVERN_ANGLE) * r
	return Transform3D(Basis(Vector3.UP, -TAVERN_ANGLE), Vector3(x, IslandMesh.ground(s, x, z) - 0.2, z))


## A point in the tavern's own frame (+x out of the front door), in world space.
static func tavern_point(local: Vector3) -> Vector3:
	return _centre() + _tavern_frame() * local


## Top of the tavern's chimney, in world space.
static func tavern_chimney() -> Vector3:
	return _centre() + _tavern_frame() * Vector3(-1.6, 9.1, 2.2)


## Where the pier lamps and the hut's lantern hang, in world space.
static func lamps() -> Array[Vector3]:
	var r1: float = spec().radius + PIER_END
	var out: Array[Vector3] = []
	for side: float in [-1.0, 1.0]:
		out.append(_centre() + Vector3(r1 - 0.4, PIER_Y + 2.6, side * (PIER_HALF_WIDTH - 0.15)))
	out.append(merchant_pos() + Vector3(0, 2.4, 0))
	out.append(_centre() + _tavern_frame() * Vector3(3.3, 2.6, 1.6))
	return out


static func anchorage() -> Vector3:
	return _at(spec().radius + 40.0, HUT_ANGLE, 0.0)


## The buildings (Blender models, art/blender/outpost.py) and their collision, in island-local
## coordinates (the island's centre at the origin). "props" lists [model, part, Transform3D].
static func build() -> Dictionary:
	var s := spec()
	var solid := MeshBuilder.new()
	var r0: float = s.radius + PIER_START
	var r1: float = s.radius + PIER_END
	var props: Array = []

	# Pier: walkable deck, posts you bump into.
	props.append(["pier", "pier", Transform3D(Basis.IDENTITY, Vector3(r0, PIER_Y, 0))])
	solid.box(Vector3((r0 + r1) * 0.5, PIER_Y - 0.1, 0), Vector3((r1 - r0) * 0.5, 0.1, PIER_HALF_WIDTH), Color.BLACK)
	var px := r0 + 2.0
	while px <= r1:
		for side: float in [-1.0, 1.0]:
			solid.box(Vector3(px, PIER_Y + 0.45, side * (PIER_HALF_WIDTH - 0.15)), Vector3(0.16, 0.45, 0.16), Color.BLACK)
		px += 3.0
	# Supply barrels near the end of the pier.
	for p in barrels():
		var local := p - _centre()
		props.append(["supply_barrel", "supply_barrel", Transform3D(Basis(Vector3.UP, local.z * 2.0), Vector3(local.x, PIER_Y, local.z))])
		solid.box(Vector3(local.x, PIER_Y + 0.45, local.z), Vector3(0.38, 0.45, 0.38), Color.BLACK)

	_hut(solid)
	props.append(["stall", "stall", _hut_frame()])
	_lighthouse(solid)
	var foot := _lighthouse_foot()
	var inward := -Vector3(foot.x, 0, foot.z).normalized()
	props.append(["lighthouse", "lighthouse", Transform3D(Basis.looking_at(inward), foot)])
	_tavern(solid)
	props.append(["tavern", "tavern", _tavern_frame()])
	# Flag pole by the root of the pier.
	var pole := Vector3(r0 - 1.0, IslandMesh.ground(s, r0 - 1.0, -3.0), -3.0)
	props.append(["pier", "flagpole", Transform3D(Basis.IDENTITY, pole)])
	return {"props": props, "faces": solid.faces()}


## The lighthouse's lamp-room glass, placed, for lighting at night (island-local).
static func lighthouse_glass() -> Transform3D:
	var foot := _lighthouse_foot()
	return Transform3D(Basis.looking_at(-Vector3(foot.x, 0, foot.z).normalized()), foot)


## The merchant's stall's frame, island-local: +x out over the counter to sea.
static func _hut_frame() -> Transform3D:
	var r: float = spec().radius - HUT_RADIUS_IN
	return Transform3D(Basis(Vector3.UP, -HUT_ANGLE), Vector3(cos(HUT_ANGLE) * r, PIER_Y, sin(HUT_ANGLE) * r))


## The Salty Dog tavern's collision.
static func _tavern(solid: MeshBuilder) -> void:
	var f := _tavern_frame()
	solid.box(f * Vector3(0, 2.8, 0), Vector3(3.0, 2.8, 3.6), Color.BLACK, f.basis)


## Where the tavern's window glass (a Blender part) goes, island-local: World lights it
## through Lantern.lit_panes so it glows from dusk to dawn.
static func tavern_windows() -> Transform3D:
	return _tavern_frame()


## The lighthouse's collision.
static func _lighthouse(solid: MeshBuilder) -> void:
	var foot := _lighthouse_foot()
	solid.box(foot + Vector3(0, LIGHTHOUSE_HEIGHT * 0.5, 0), Vector3(1.9, LIGHTHOUSE_HEIGHT * 0.5, 1.9), Color.BLACK)


## The merchant's stall's collision: its floor, three walls and the counter.
static func _hut(solid: MeshBuilder) -> void:
	var frame := _hut_frame()
	var basis := frame.basis
	solid.box(frame * Vector3(-0.5, -0.1, 0), Vector3(2.6, 0.1, 2.4), Color.BLACK, basis)
	for spec_wall in [
		[Vector3(-2.9, 1.4, 0), Vector3(0.12, 1.4, 2.4)],
		[Vector3(-0.5, 1.4, -2.3), Vector3(2.5, 1.4, 0.12)],
		[Vector3(-0.5, 1.4, 2.3), Vector3(2.5, 1.4, 0.12)],
	]:
		solid.box(frame * spec_wall[0], spec_wall[1], Color.BLACK, basis)
	solid.box(frame * Vector3(1.6, 0.55, 0), Vector3(0.35, 0.55, 2.0), Color.BLACK, basis)

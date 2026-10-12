class_name SloopHull
extends Hull
## The sloop, the tiny ship a shipwright gives away (docs/specs/2026-10-12-m26-shipyards.md):
## one open deck about 10 m long with one mast, a wheel at the stern, an anchor winch at the bow
## and a little map table. No guns and no hold. Her holes are in the planking under the deck
## and show by the rail, where you patch them; you bail from the deck. Quick and nimble, but
## water comes in fast and not much of it sinks her. art/blender/sloop.py builds her model from
## the same numbers.

const HALF_LENGTH := 5.6
const BEAM := 3.6
const KEEL_Y := -0.9
const DECK_Y := 1.2
const BOW_DECK_Z := -4.9
const STERN_Z := 5.1
const RAIL_HEIGHT := 0.7
const RAIL_BLOCK := 0.55
const MAST_Z := -1.3
const MAST_HEIGHT := 10.0
const MAST_RADIUS := 0.2
const LADDER_Z := 0.9
const LADDER_GAP := 0.6
const WHEEL := Vector3(0.0, DECK_Y, 3.8)
const CAPSTAN := Vector3(0.0, DECK_Y, -3.6)
const MAP_TABLE := Vector3(-0.85, DECK_Y, 2.1)
const BANANAS := Vector3(0.9, DECK_Y, 2.2)
const SAIL_POST := Vector3(0.7, DECK_Y, -0.5)
## Solid things on deck, as [centre, half size] (boxes for collision, footprints for walking).
const FITTINGS := [
	[Vector3(0.0, DECK_Y + 0.5, MAST_Z), Vector3(MAST_RADIUS, 0.5, MAST_RADIUS)],
	[WHEEL + Vector3(0, 0.55, 0), Vector3(0.25, 0.55, 0.2)],
	[CAPSTAN + Vector3(0, 0.4, 0), Vector3(0.4, 0.4, 0.4)],
	[MAP_TABLE + Vector3(0, 0.4, 0), Vector3(0.4, 0.4, 0.3)],
	[BANANAS + Vector3(0, 0.3, 0), Vector3(0.3, 0.3, 0.3)],
	[SAIL_POST + Vector3(0, 0.5, 0), Vector3(0.1, 0.5, 0.1)],
]


func _init() -> void:
	type = Type.SLOOP
	name = "sloop"
	price = 0
	half_length = HALF_LENGTH
	deck_y = DECK_Y
	keel_y = KEEL_Y
	mast_z = [MAST_Z]
	mast_height = [MAST_HEIGHT]
	spawns = [Vector3(-0.7, DECK_Y, 0.2), Vector3(0.7, DECK_Y, 0.4), Vector3(0.0, DECK_Y, -2.5)]
	has_hold = false
	guns = 0
	bananas_at = BANANAS
	cargo_spot = Vector3(-0.5, DECK_Y, -2.6)
	max_speed = ShipPhysics.MAX_SPEED * 1.15
	sail_push = 1.6
	turn_rate = ShipPhysics.TURN_RATE * 1.4
	turn_speed = 3.0
	leak_rate = 0.02
	sink_level = 0.9
	pose_half_length = 4.5
	pose_half_beam = 1.4
	bow_probe = 5.0
	bucket = 0.06
	bail_every = 1.5


func _make_stations() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{
			"id": 0, "kind": ShipShape.Kind.WHEEL, "mast": -1, "side": 0, "label": "take the wheel",
			"at": WHEEL + Vector3(0, 1.0, 0.2), "stand": WHEEL + Vector3(0, 0, 0.8),
		},
		{
			"id": 1, "kind": ShipShape.Kind.SAILS, "mast": 0, "side": 0, "label": "work the sail",
			"at": SAIL_POST + Vector3(0, 1.0, 0), "stand": SAIL_POST + Vector3(0, 0, 0.8),
		},
		{
			"id": 3, "kind": ShipShape.Kind.ANCHOR, "mast": -1, "side": 0, "label": "work the anchor",
			"at": CAPSTAN + Vector3(0, 0.7, 0), "stand": CAPSTAN + Vector3(0, 0, 1.0),
		},
	]
	return list


## Narrow and pointed at the bow, a small square transom, rounded toward the keel.
func half_width(z: float, y: float) -> float:
	var t := z / HALF_LENGTH
	var plan := 1.0 - 0.85 * pow(maxf(0.0, -t), 2.0) - 0.3 * pow(maxf(0.0, t), 4.0)
	var v := clampf((y - KEEL_Y) / (DECK_Y - KEEL_Y), 0.0, 1.0)
	return 0.5 * BEAM * plan * (0.35 + 0.65 * pow(v, 0.6))


func floor_y(_z: float, _x: float) -> float:
	return DECK_Y


func is_on_board(p: Vector3) -> bool:
	if p.z < BOW_DECK_Z - 0.5 or p.z > STERN_Z + 0.5 or p.y < DECK_Y - 1.0:
		return false
	return absf(p.x) <= half_width(p.z, minf(p.y, DECK_Y)) + 0.3


func is_below_deck(_p: Vector3) -> bool:
	return false


## Footprints of the fittings, for walking round them (bots) and for the server's check.
func solids() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for f: Array in FITTINGS:
		var c: Vector3 = f[0]
		var h: Vector3 = f[1]
		out.append(Rect2(c.x - h.x, c.z - h.z, h.x * 2.0, h.z * 2.0))
	return out


func plausible_position(p: Vector3) -> bool:
	if not is_on_board(p) or p.y < DECK_Y - 0.4 or p.y > DECK_Y + 3.0:
		return false
	for rect in solids():
		if rect.grow(-0.15).has_point(Vector2(p.x, p.z)):
			return false
	return true


func inside_hull(p: Vector3) -> bool:
	if absf(p.z) > HALF_LENGTH or p.y < KEEL_Y or p.y > DECK_Y + RAIL_HEIGHT:
		return false
	return absf(p.x) < half_width(p.z, p.y)


func makes_hole(hit: Vector3) -> bool:
	return hit.y < DECK_Y - 0.1


## A hole shows on deck by the rail on the side it was hit, where you can reach to patch it.
func hole_point(hit: Vector3) -> Vector3:
	var side := 1.0 if hit.x >= 0.0 else -1.0
	var z := clampf(hit.z, BOW_DECK_Z + 1.2, STERN_Z - 1.0)
	return Vector3(side * (half_width(z, DECK_Y) - 0.3), DECK_Y + 0.1, z)


func ladder_bottom(side: int) -> Vector3:
	return Vector3(side * (half_width(LADDER_Z, 0.0) + 0.3), 0.0, LADDER_Z)


func ladder_top(side: int) -> Vector3:
	return Vector3(side * (half_width(LADDER_Z, DECK_Y) - 0.6), DECK_Y, LADDER_Z)


func map_table_target() -> Vector3:
	return MAP_TABLE + Vector3(0, 0.8, 0)


## Bail from anywhere on her deck: the water is right there under the boards.
func can_scoop(p: Vector3, water: float) -> bool:
	return water >= 0.05 and is_on_board(p)


func can_throw(p: Vector3) -> bool:
	return is_on_board(p)


## Rail height on deck, with the gaps at the ladders.
func rail_top(z: float) -> float:
	if absf(z - LADDER_Z) < LADDER_GAP:
		return DECK_Y + 0.08
	return DECK_Y + RAIL_HEIGHT


func _make_faces() -> PackedVector3Array:
	var b := MeshBuilder.new()
	var ink := Color.BLACK
	var steps: Array[float] = []
	var z := BOW_DECK_Z
	while z < STERN_Z:
		steps.append(z)
		z += 0.5
	steps.append(STERN_Z)
	for cut: float in [LADDER_Z - LADDER_GAP, LADDER_Z + LADDER_GAP]:
		if not steps.has(cut):
			steps.append(cut)
	steps.sort()
	for i in steps.size() - 1:
		var z0: float = steps[i]
		var z1: float = steps[i + 1]
		if z1 - z0 < 0.05:
			continue
		var w0 := half_width(z0, DECK_Y)
		var w1 := half_width(z1, DECK_Y)
		b.quad(Vector3(-w0, DECK_Y, z0), Vector3(w0, DECK_Y, z0), Vector3(w1, DECK_Y, z1), Vector3(-w1, DECK_Y, z1), ink, Vector3.UP)
		if absf((z0 + z1) * 0.5 - LADDER_Z) < LADDER_GAP:
			continue
		for side: int in [-1, 1]:
			var a := Vector3(side * w0, DECK_Y, z0)
			var c := Vector3(side * w1, DECK_Y, z1)
			b.quad(a, c, c + Vector3.UP * RAIL_BLOCK, a + Vector3.UP * RAIL_BLOCK, ink, Vector3(-side, 0, 0))
	for end: float in [BOW_DECK_Z, STERN_Z]:
		var w := half_width(end, DECK_Y)
		var inward := Vector3.BACK if end < 0.0 else Vector3.FORWARD
		b.quad(Vector3(-w, DECK_Y, end), Vector3(w, DECK_Y, end), Vector3(w, DECK_Y + RAIL_BLOCK, end), Vector3(-w, DECK_Y + RAIL_BLOCK, end), ink, inward)
	for f: Array in FITTINGS:
		b.box(f[0], f[1], ink)
	# The mast above the fitting box, so you can't walk through it either.
	b.box(Vector3(0.0, DECK_Y + 2.5, MAST_Z), Vector3(MAST_RADIUS, 1.5, MAST_RADIUS), ink)
	return b.faces()

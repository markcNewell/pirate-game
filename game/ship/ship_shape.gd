class_name ShipShape
extends RefCounted
## The galleon's layout in ship coordinates: origin on the waterline at mid-ship, bow toward
## -Z, starboard toward +X, up +Y, metres. The model, the deck collision and the stations all
## read these numbers, so moving something here moves it everywhere.

const HALF_LENGTH := 13.0
const BEAM := 7.5
const KEEL_Y := -2.2
const DECK_Y := 3.0
## Where the walkable deck ends toward the bow and the stern.
const BOW_DECK_Z := -12.4
const STERN_Z := 12.6

## Visible bulwark height, and the lower height that actually blocks you, so you can hop over.
const RAIL_HEIGHT := 1.0
const RAIL_BLOCK := 0.75
const RAIL_THICKNESS := 0.18

const QUARTER_Z := 6.0
const QUARTER_Y := 5.2
const STAIR_BOTTOM_Z := 2.4
const STAIR_HALF_WIDTH := 1.1

## The lower deck: below the waterline, under the main deck from near the bow to the quarterdeck.
const LOWER_Y := -0.8
const LOWER_Z0 := -9.5
const LOWER_Z1 := 5.8
const WALL_INSET := 0.1

## The hatch down to the lower deck: an opening in the main deck with a raised rim (coaming)
## you cannot walk through; E climbs the ladder.
const HATCH_Z0 := -5.5
const HATCH_Z1 := -4.0
const HATCH_X := 0.55
const COAMING := 0.4

const MAST_Z: Array[float] = [-6.5, 0.8]
const MAST_HEIGHT: Array[float] = [18.0, 22.0]
const MAST_RADIUS := 0.35

## Ladders hang over both sides here, and the bulwark has a gap of +-LADDER_GAP around them.
const LADDER_Z := -2.5
const STERN_ROPE := 2
const LADDER_GAP := 0.75

const CAPSTAN := Vector3(0.0, DECK_Y, -3.2)
const WHEEL := Vector3(0.0, QUARTER_Y, 9.0)
## The map table on the quarterdeck, beside the wheel, where voyages are taken.
const MAP_TABLE := Vector3(-2.1, QUARTER_Y, 9.4)
## Things stowed on the main deck: [centre, half size, "barrel" | "crate" | "rope"].
const CLUTTER := [
	[Vector3(-2.35, DECK_Y + 0.45, -7.8), Vector3(0.38, 0.45, 0.38), "barrel"],
	[Vector3(-1.75, DECK_Y + 0.45, -8.55), Vector3(0.38, 0.45, 0.38), "barrel"],
	[Vector3(2.0, DECK_Y + 0.35, -8.2), Vector3(0.4, 0.35, 0.4), "crate"],
	[Vector3(2.05, DECK_Y + 0.95, -8.2), Vector3(0.3, 0.25, 0.3), "crate"],
	[Vector3(-2.7, DECK_Y + 0.1, 1.6), Vector3(0.45, 0.1, 0.45), "rope"],
	[Vector3(2.7, DECK_Y + 0.1, 0.6), Vector3(0.45, 0.1, 0.45), "rope"],
]

## The banana barrel on the lower deck, toward the stern.
const BANANA_BARREL := Vector3(1.0, LOWER_Y, 4.6)

## Four deck cannons, a pair at each of these lengths, one each side.
const CANNON_Z: Array[float] = [-1.2, 3.6]
const CANNON_PIVOT_INSET := 1.15
const CANNON_STAND_INSET := 2.25
const CANNON_HEIGHT := 1.2
const BARREL_LENGTH := 2.3
## How far a cannon swings from straight out, and its elevation limits (radians).
const CANNON_YAW_LIMIT := 0.7
const CANNON_PITCH_MIN := -0.17
const CANNON_PITCH_MAX := 0.55

enum Kind { WHEEL, SAILS, ANCHOR, CANNON }

## Spots on the main deck where players appear.
const SPAWNS: Array[Vector3] = [
	Vector3(-1.6, DECK_Y, 0.0),
	Vector3(1.9, DECK_Y, 0.2),
	Vector3(-2.0, DECK_Y, -4.0),
	Vector3(2.4, DECK_Y, -3.4),
]

## Where the hatch ladder puts you: at the bottom (facing aft) and back on deck beside the hatch.
const HATCH_BOTTOM := Vector3(0.0, LOWER_Y, -3.3)
const HATCH_TOP := Vector3(-1.3, DECK_Y, -4.75)


## Half the hull's width at length `z` and height `y`. Narrow and pointed at the bow, a
## square transom at the stern, rounded toward the keel, straight sides above the deck.
static func half_width(z: float, y: float) -> float:
	var t := z / HALF_LENGTH
	var plan := 1.0 - 0.92 * pow(maxf(0.0, -t), 2.0) - 0.25 * pow(maxf(0.0, t), 4.0)
	var v := clampf((y - KEEL_Y) / (DECK_Y - KEEL_Y), 0.0, 1.0)
	return 0.5 * BEAM * plan * (0.35 + 0.65 * pow(v, 0.6))


## Height of the bulwark top (visual), rising toward bow and stern like a real sheer line.
static func rail_top(z: float) -> float:
	if absf(z - LADDER_Z) < LADDER_GAP:
		return DECK_Y + 0.12
	if z > QUARTER_Z:
		return QUARTER_Y + RAIL_HEIGHT
	var t := z / HALF_LENGTH
	return DECK_Y + RAIL_HEIGHT + 0.45 * t * t


## Floor height under a point on the upper decks (main deck or quarterdeck; stairs are a ramp).
static func floor_y(z: float, x: float) -> float:
	if z >= QUARTER_Z:
		return QUARTER_Y
	if z > STAIR_BOTTOM_Z and absf(x) <= STAIR_HALF_WIDTH:
		return lerpf(DECK_Y, QUARTER_Y, (z - STAIR_BOTTOM_Z) / (QUARTER_Z - STAIR_BOTTOM_Z))
	return DECK_Y


## The inside face of the lower deck's walls: straight up and down, set in from the hull
## where it is narrowest (at the floor) so the walls never poke out through it.
static func lower_wall_x(z: float) -> float:
	return half_width(z, LOWER_Y) - WALL_INSET


## True when a ship-frame point is somewhere a crew member can be: on the upper decks or
## on the lower deck, inside the hull's sides.
static func is_on_board(p: Vector3) -> bool:
	if p.z < BOW_DECK_Z - 0.5 or p.z > STERN_Z + 0.5 or p.y < LOWER_Y - 1.0:
		return false
	# Up on deck allow a little slack at the rail; lower down the hull narrows.
	var margin := 0.3 if p.y >= DECK_Y - 0.5 else 0.15
	return absf(p.x) <= half_width(p.z, minf(p.y, DECK_Y)) + margin


static func is_below_deck(p: Vector3) -> bool:
	return p.y < DECK_Y - 0.6 and p.z > LOWER_Z0 - 0.5 and p.z < LOWER_Z1 + 0.5


## Could a player really be standing (or jumping) here, in the ship frame? Not inside a mast,
## cannon or wall, not sunk through a floor, not floating high above one. The hatch opening
## lets you drop to the lower deck.
static func plausible_position(p: Vector3) -> bool:
	if not is_on_board(p):
		return false
	var lower := p.y < DECK_Y - 1.0
	var flat := Vector2(p.x, p.z)
	if lower and absf(p.x) > lower_wall_x(p.z) + 0.1:
		return false
	for rect in BotNav.solids(lower):
		if rect.grow(-0.15).has_point(flat):
			return false
	var in_hatch := absf(p.x) < HATCH_X and p.z > HATCH_Z0 and p.z < HATCH_Z1
	var floor_here := LOWER_Y if lower else floor_y(p.z, p.x)
	if not in_hatch and p.y < floor_here - 0.4:
		return false
	return p.y < floor_here + 3.0


## True if a ship-frame point is inside the solid hull (for cannonball hits).
static func inside_hull(p: Vector3) -> bool:
	if absf(p.z) > HALF_LENGTH or p.y < KEEL_Y or p.y > rail_top(p.z):
		return false
	return absf(p.x) < half_width(p.z, p.y)


## A hit at or below the main deck holes the hull; higher hits only splinter the bulwark.
static func makes_hole(hit: Vector3) -> bool:
	return hit.y < DECK_Y - 0.15


## Where a hull hit shows up on the lower deck: on the inside wall, at a height a crew member
## can reach to patch it.
static func hole_point(hit: Vector3) -> Vector3:
	var side := 1.0 if hit.x >= 0.0 else -1.0
	var z := clampf(hit.z, LOWER_Z0 + 0.8, LOWER_Z1 - 0.8)
	var y := clampf(hit.y, LOWER_Y + 0.35, LOWER_Y + 1.5)
	return Vector3(side * (lower_wall_x(z) - 0.02), y, z)


static func stations() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{
			"id": 0, "kind": Kind.WHEEL, "mast": -1, "side": 0, "label": "take the wheel",
			"at": WHEEL + Vector3(0, 1.05, 0.25), "stand": WHEEL + Vector3(0, 0, 1.3),
		},
		{
			"id": 3, "kind": Kind.ANCHOR, "mast": -1, "side": 0, "label": "work the anchor",
			"at": CAPSTAN + Vector3(0, 0.8, 0), "stand": CAPSTAN + Vector3(0, 0, 1.4),
		},
	]
	for m in MAST_Z.size():
		var post := sail_post(m)
		list.append({
			"id": 1 + m, "kind": Kind.SAILS, "mast": m, "side": 0,
			"label": "work the %s sails" % ["fore", "main"][m],
			"at": post + Vector3(0, 1.0, 0), "stand": post + Vector3(0, 0, 1.0),
		})
	for i in CANNON_Z.size():
		for side: int in [-1, 1]:
			var pivot := cannon_pivot(i, side)
			list.append({
				"id": cannon_station(i, side), "kind": Kind.CANNON, "mast": -1, "side": side,
				"gun": cannon_index(i, side), "label": "man the cannon",
				"at": pivot - Vector3(side * 0.4, 0.2, 0), "stand": cannon_stand(i, side),
			})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return list


## Foot of the rope post beside each mast, on the starboard side.
static func sail_post(mast: int) -> Vector3:
	return Vector3(1.6, DECK_Y, MAST_Z[mast] + 0.9)


## Cannons are numbered 0-3: pair 0 port, pair 0 starboard, pair 1 port, pair 1 starboard.
static func cannon_index(pair: int, side: int) -> int:
	return pair * 2 + (1 if side > 0 else 0)


static func cannon_station(pair: int, side: int) -> int:
	return 4 + cannon_index(pair, side)


static func cannon_count() -> int:
	return CANNON_Z.size() * 2


static func cannon_side(gun: int) -> int:
	return 1 if gun % 2 == 1 else -1


static func cannon_pivot(pair: int, side: int) -> Vector3:
	var z: float = CANNON_Z[pair]
	return Vector3(side * (half_width(z, DECK_Y) - CANNON_PIVOT_INSET), DECK_Y + CANNON_HEIGHT, z)


static func cannon_pivot_of(gun: int) -> Vector3:
	return cannon_pivot(gun / 2, cannon_side(gun))


static func cannon_stand(pair: int, side: int) -> Vector3:
	var z: float = CANNON_Z[pair]
	return Vector3(side * (half_width(z, DECK_Y) - CANNON_STAND_INSET), DECK_Y, z)


## Barrel direction in the ship frame for a gun's aim. `yaw` swings toward the bow (positive)
## or the stern; `pitch` raises the muzzle.
static func barrel_direction(gun: int, yaw: float, pitch: float) -> Vector3:
	var side := cannon_side(gun)
	var y := clampf(yaw, -CANNON_YAW_LIMIT, CANNON_YAW_LIMIT)
	var p := clampf(pitch, CANNON_PITCH_MIN, CANNON_PITCH_MAX)
	var out := Vector3(side * cos(y), 0.0, -sin(y)).normalized()
	return (out * cos(p) + Vector3.UP * sin(p)).normalized()


static func muzzle(gun: int, yaw: float, pitch: float) -> Vector3:
	return cannon_pivot_of(gun) + barrel_direction(gun, yaw, pitch) * BARREL_LENGTH


## Bottom of a ladder at the waterline (where swimmers grab it) and its top on deck.
## Side -1 or +1: the ladders amidships. Side 2: the rope hanging from the prison hulk's stern
## (Act IV), up onto her quarterdeck behind her guards' rounds.
static func ladder_bottom(side: int) -> Vector3:
	if side == STERN_ROPE:
		return Vector3(0.0, 0.0, HALF_LENGTH + 0.8)
	return Vector3(side * (half_width(LADDER_Z, 0.0) + 0.35), 0.0, LADDER_Z)


static func ladder_top(side: int) -> Vector3:
	if side == STERN_ROPE:
		return Vector3(0.0, QUARTER_Y, HALF_LENGTH - 1.8)
	return Vector3(side * (half_width(LADDER_Z, DECK_Y) - 1.0), DECK_Y, LADDER_Z)


static func map_table_target() -> Vector3:
	return MAP_TABLE + Vector3(0, 0.95, 0)


## Points you look at to use the hatch ladder from above and from below.
static func hatch_top_target() -> Vector3:
	return Vector3(0.0, DECK_Y + 0.3, (HATCH_Z0 + HATCH_Z1) * 0.5)


static func hatch_bottom_target() -> Vector3:
	return Vector3(0.0, LOWER_Y + 1.4, HATCH_Z1 - 0.3)


## Collision triangles for the deck proxy: floors, stairs, rails, masts and fittings.
static func deck_faces() -> PackedVector3Array:
	var b := MeshBuilder.new()
	var ink := Color.BLACK
	var steps := _deck_z_steps()

	for i in steps.size() - 1:
		var z0: float = steps[i]
		var z1: float = steps[i + 1]
		var w0 := half_width(z0, DECK_Y)
		var w1 := half_width(z1, DECK_Y)
		var y := QUARTER_Y if z0 >= QUARTER_Z else DECK_Y
		if z0 >= HATCH_Z0 and z1 <= HATCH_Z1:
			# Floor either side of the hatch opening.
			for side: int in [-1, 1]:
				var inner := side * HATCH_X
				b.quad(Vector3(inner, y, z0), Vector3(side * w0, y, z0), Vector3(side * w1, y, z1), Vector3(inner, y, z1), ink, Vector3.UP)
		else:
			b.quad(Vector3(-w0, y, z0), Vector3(w0, y, z0), Vector3(w1, y, z1), Vector3(-w1, y, z1), ink, Vector3.UP)
		for side: int in [-1, 1]:
			if absf((z0 + z1) * 0.5 - LADDER_Z) < LADDER_GAP:
				continue
			var a := Vector3(side * w0, y, z0)
			var c := Vector3(side * w1, y, z1)
			b.quad(a, c, c + Vector3.UP * RAIL_BLOCK, a + Vector3.UP * RAIL_BLOCK, ink, Vector3(-side, 0, 0))

	var wq := half_width(QUARTER_Z, DECK_Y)
	var s := STAIR_HALF_WIDTH
	for side: int in [-1, 1]:
		# Wall under the quarterdeck edge beside the stairs, and the rail along its front.
		b.quad(
			Vector3(side * s, DECK_Y, QUARTER_Z), Vector3(side * wq, DECK_Y, QUARTER_Z),
			Vector3(side * wq, QUARTER_Y + RAIL_BLOCK, QUARTER_Z), Vector3(side * s, QUARTER_Y + RAIL_BLOCK, QUARTER_Z),
			ink, Vector3.FORWARD,
		)
	b.quad(
		Vector3(-s, DECK_Y, STAIR_BOTTOM_Z), Vector3(s, DECK_Y, STAIR_BOTTOM_Z),
		Vector3(s, QUARTER_Y, QUARTER_Z), Vector3(-s, QUARTER_Y, QUARTER_Z), ink, Vector3(0, 1, -0.6),
	)
	var ws := half_width(STERN_Z, DECK_Y)
	b.quad(
		Vector3(-ws, QUARTER_Y, STERN_Z), Vector3(ws, QUARTER_Y, STERN_Z),
		Vector3(ws, QUARTER_Y + RAIL_BLOCK, STERN_Z), Vector3(-ws, QUARTER_Y + RAIL_BLOCK, STERN_Z), ink, Vector3.FORWARD,
	)
	var wb := half_width(BOW_DECK_Z, DECK_Y)
	b.quad(
		Vector3(-wb, DECK_Y, BOW_DECK_Z), Vector3(wb, DECK_Y, BOW_DECK_Z),
		Vector3(wb, DECK_Y + RAIL_BLOCK, BOW_DECK_Z), Vector3(-wb, DECK_Y + RAIL_BLOCK, BOW_DECK_Z), ink, Vector3.BACK,
	)

	_hatch_faces(b)
	_lower_deck_faces(b)
	for m in MAST_Z.size():
		var top := DECK_Y + 4.0
		b.box(Vector3(0, (LOWER_Y + top) * 0.5, MAST_Z[m]), Vector3(MAST_RADIUS, (top - LOWER_Y) * 0.5, MAST_RADIUS), ink)
		b.box(sail_post(m) + Vector3(0, 0.6, 0), Vector3(0.15, 0.6, 0.15), ink)
	b.box(CAPSTAN + Vector3(0, 0.5, 0), Vector3(0.6, 0.5, 0.6), ink)
	b.box(WHEEL + Vector3(0, 0.6, 0), Vector3(0.3, 0.6, 0.25), ink)
	b.box(MAP_TABLE + Vector3(0, 0.45, 0), Vector3(0.6, 0.45, 0.4), ink)
	for c in CLUTTER:
		if c[2] != "rope":
			b.box(c[0], c[1], ink)
	for i in CANNON_Z.size():
		for side: int in [-1, 1]:
			var pivot := cannon_pivot(i, side)
			b.box(Vector3(pivot.x - side * 0.05, DECK_Y + 0.45, pivot.z), Vector3(0.6, 0.45, 0.45), ink)
	return b.faces()


## The rim around the hatch, high enough that you climb rather than fall.
static func _hatch_faces(b: MeshBuilder) -> void:
	var ink := Color.BLACK
	var top := DECK_Y + COAMING
	var x := HATCH_X
	var corners: Array[Vector3] = [
		Vector3(-x, DECK_Y, HATCH_Z0), Vector3(x, DECK_Y, HATCH_Z0),
		Vector3(x, DECK_Y, HATCH_Z1), Vector3(-x, DECK_Y, HATCH_Z1),
	]
	for i in 4:
		var a := corners[i]
		var c := corners[(i + 1) % 4]
		var mid := (a + c) * 0.5
		b.quad(a, c, c + Vector3.UP * COAMING, a + Vector3.UP * COAMING, ink, mid - Vector3(0, mid.y, (HATCH_Z0 + HATCH_Z1) * 0.5))
	b.quad(corners[0] + Vector3.UP * (top - DECK_Y), corners[1] + Vector3.UP * (top - DECK_Y),
		corners[2] + Vector3.UP * (top - DECK_Y), corners[3] + Vector3.UP * (top - DECK_Y), ink, Vector3.UP)


## Lower deck floor, its walls along the hull and its two end walls.
static func _lower_deck_faces(b: MeshBuilder) -> void:
	var ink := Color.BLACK
	var z := LOWER_Z0
	var step := 0.8
	while z < LOWER_Z1 - 1e-3:
		var z1 := minf(z + step, LOWER_Z1)
		var w0 := lower_wall_x(z)
		var w1 := lower_wall_x(z1)
		b.quad(Vector3(-w0, LOWER_Y, z), Vector3(w0, LOWER_Y, z), Vector3(w1, LOWER_Y, z1), Vector3(-w1, LOWER_Y, z1), ink, Vector3.UP)
		for side: int in [-1, 1]:
			var a := Vector3(side * w0, LOWER_Y, z)
			var c := Vector3(side * w1, LOWER_Y, z1)
			var h := DECK_Y - LOWER_Y
			b.quad(a, c, c + Vector3.UP * h, a + Vector3.UP * h, ink, Vector3(-side, 0, 0))
		z = z1
	for end: float in [LOWER_Z0, LOWER_Z1]:
		var w := lower_wall_x(end)
		var out := Vector3.BACK if end > 0.0 else Vector3.FORWARD
		b.quad(Vector3(-w, LOWER_Y, end), Vector3(w, LOWER_Y, end), Vector3(w, DECK_Y, end), Vector3(-w, DECK_Y, end), ink, -out)


## Lengthwise sample points for the deck, with extra cuts at the ladder gaps, the hatch and the quarterdeck.
static func _deck_z_steps() -> Array[float]:
	var steps: Array[float] = []
	var z := BOW_DECK_Z
	while z < STERN_Z:
		steps.append(z)
		z += 0.8
	steps.append(STERN_Z)
	for cut: float in [QUARTER_Z, LADDER_Z - LADDER_GAP, LADDER_Z + LADDER_GAP, HATCH_Z0, HATCH_Z1]:
		if not steps.has(cut):
			steps.append(cut)
	steps.sort()
	# Drop slivers left by the extra cuts.
	var clean: Array[float] = [steps[0]]
	for v in steps.slice(1):
		if v - clean.back() > 0.05:
			clean.append(v)
	return clean

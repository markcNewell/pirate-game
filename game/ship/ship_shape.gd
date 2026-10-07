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

const MAST_Z: Array[float] = [-6.5, 0.8]
const MAST_HEIGHT: Array[float] = [18.0, 22.0]
const MAST_RADIUS := 0.35

## Ladders hang over both sides here, and the bulwark has a gap of +-LADDER_GAP around them.
const LADDER_Z := -2.5
const LADDER_GAP := 0.75

const CAPSTAN := Vector3(0.0, DECK_Y, -3.2)
const WHEEL := Vector3(0.0, QUARTER_Y, 9.0)

enum Kind { WHEEL, SAILS, ANCHOR }

## Spots on the main deck where players appear.
const SPAWNS: Array[Vector3] = [
	Vector3(-1.8, DECK_Y, -4.6),
	Vector3(1.8, DECK_Y, -4.6),
	Vector3(-1.8, DECK_Y, -0.6),
	Vector3(2.0, DECK_Y, -1.0),
]


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


## Floor height under a point on board (main deck or quarterdeck; stairs are a ramp).
static func floor_y(z: float, x: float) -> float:
	if z >= QUARTER_Z:
		return QUARTER_Y
	if z > STAIR_BOTTOM_Z and absf(x) <= STAIR_HALF_WIDTH:
		return lerpf(DECK_Y, QUARTER_Y, (z - STAIR_BOTTOM_Z) / (QUARTER_Z - STAIR_BOTTOM_Z))
	return DECK_Y


## True when a ship-frame point is above the deck and inside the bulwarks.
static func is_on_board(p: Vector3) -> bool:
	if p.z < BOW_DECK_Z - 0.5 or p.z > STERN_Z + 0.5:
		return false
	if absf(p.x) > half_width(p.z, DECK_Y) + 0.3:
		return false
	return p.y > DECK_Y - 1.2


static func stations() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{
			"id": 0, "kind": Kind.WHEEL, "mast": -1, "label": "take the wheel",
			"at": WHEEL + Vector3(0, 1.05, 0.25), "stand": WHEEL + Vector3(0, 0, 1.3),
		},
		{
			"id": 3, "kind": Kind.ANCHOR, "mast": -1, "label": "work the anchor",
			"at": CAPSTAN + Vector3(0, 0.8, 0), "stand": CAPSTAN + Vector3(0, 0, 1.4),
		},
	]
	for m in MAST_Z.size():
		var post := sail_post(m)
		list.append({
			"id": 1 + m, "kind": Kind.SAILS, "mast": m,
			"label": "work the %s sails" % ["fore", "main"][m],
			"at": post + Vector3(0, 1.0, 0), "stand": post + Vector3(0, 0, 1.0),
		})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return list


## Foot of the rope post beside each mast, on the starboard side.
static func sail_post(mast: int) -> Vector3:
	return Vector3(1.6, DECK_Y, MAST_Z[mast] + 0.9)


## Bottom of a ladder at the waterline (where swimmers grab it) and its top on deck.
static func ladder_bottom(side: int) -> Vector3:
	return Vector3(side * (half_width(LADDER_Z, 0.0) + 0.35), 0.0, LADDER_Z)


static func ladder_top(side: int) -> Vector3:
	return Vector3(side * (half_width(LADDER_Z, DECK_Y) - 1.0), DECK_Y, LADDER_Z)


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
		b.quad(Vector3(-w0, y, z0), Vector3(w0, y, z0), Vector3(w1, y, z1), Vector3(-w1, y, z1), ink, Vector3.UP)
		var rail := RAIL_BLOCK
		for side: int in [-1, 1]:
			if absf((z0 + z1) * 0.5 - LADDER_Z) < LADDER_GAP:
				continue
			var a := Vector3(side * w0, y, z0)
			var c := Vector3(side * w1, y, z1)
			b.quad(a, c, c + Vector3.UP * rail, a + Vector3.UP * rail, ink, Vector3(-side, 0, 0))

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

	for m in MAST_Z.size():
		b.box(Vector3(0, DECK_Y + 2.0, MAST_Z[m]), Vector3(MAST_RADIUS, 2.0, MAST_RADIUS), ink)
		b.box(sail_post(m) + Vector3(0, 0.6, 0), Vector3(0.15, 0.6, 0.15), ink)
	b.box(CAPSTAN + Vector3(0, 0.5, 0), Vector3(0.6, 0.5, 0.6), ink)
	b.box(WHEEL + Vector3(0, 0.6, 0), Vector3(0.3, 0.6, 0.25), ink)
	return b.faces()


## Lengthwise sample points for the deck, with extra cuts at the ladder gaps and the quarterdeck.
static func _deck_z_steps() -> Array[float]:
	var steps: Array[float] = []
	var z := BOW_DECK_Z
	while z < STERN_Z:
		steps.append(z)
		z += 0.8
	steps.append(STERN_Z)
	for cut: float in [QUARTER_Z, LADDER_Z - LADDER_GAP, LADDER_Z + LADDER_GAP]:
		if not steps.has(cut):
			steps.append(cut)
	steps.sort()
	return steps

class_name Hull
extends RefCounted
## One kind of ship: her layout and how she handles (docs/specs/2026-10-12-m26-shipyards.md).
## Every ship carries a hull type; whatever deals with a ship asks Hull.of(ship) for its decks,
## stations, ladders and holes rather than reading one fixed layout. This base class is the
## galleon and reads ShipShape, so she is exactly as before; SloopHull is the tiny free ship.

enum Type { GALLEON, SLOOP }

static var _galleon: Hull
static var _sloop: Hull

var type := Type.GALLEON
var name := "galleon"
## Gold at a shipyard (the sloop is free).
var price := 500

## Layout (ship frame, as in ShipShape).
var half_length := ShipShape.HALF_LENGTH
var deck_y := ShipShape.DECK_Y
var keel_y := ShipShape.KEEL_Y
var mast_z: Array[float] = ShipShape.MAST_Z
var mast_height: Array[float] = ShipShape.MAST_HEIGHT
var spawns: Array[Vector3] = ShipShape.SPAWNS
## Has the lower deck, the hatch to it and the banana barrel down there.
var has_hold := true
var guns := ShipShape.cannon_count()
## Where you eat a banana (the barrel).
var bananas_at := ShipShape.BANANA_BARREL
## Where a story chest or a sold-off crate sits on deck.
var cargo_spot := Vector3(-1.2, ShipShape.DECK_Y, -2.2)

## Handling (ShipPhysics).
var max_speed := ShipPhysics.MAX_SPEED
var sail_push := ShipPhysics.SAIL_PUSH
var turn_rate := ShipPhysics.TURN_RATE
var turn_speed := ShipPhysics.TURN_SPEED
var leak_rate := ShipPhysics.LEAK_RATE
var sink_level := ShipPhysics.SINK_LEVEL
var pose_half_length := ShipPhysics.POSE_HALF_LENGTH
var pose_half_beam := ShipPhysics.POSE_HALF_BEAM
var bow_probe := ShipPhysics.BOW_PROBE
## Metres of water one bucket takes out, and the least time between two throws. A galleon's
## trip (scoop below, climb, throw) takes about BAIL_TRIP seconds, so one pirate bailing keeps
## ahead of two holes; playtest 12-10 found the old 0.06 couldn't keep up with even one.
const BAIL_TRIP := 8.0
var bucket := 0.2
var bail_every := 0.0

var _stations: Array[Dictionary] = []
var _faces := PackedVector3Array()


static func galleon() -> Hull:
	if _galleon == null:
		_galleon = Hull.new()
	return _galleon


static func sloop() -> Hull:
	if _sloop == null:
		_sloop = SloopHull.new()
	return _sloop


static func of_type(t: int) -> Hull:
	return sloop() if t == Type.SLOOP else galleon()


## The hull a ship is built on (a galleon when there is no ship).
static func of(s: ShipState) -> Hull:
	return of_type(s.hull) if s else galleon()


func masts() -> int:
	return mast_z.size()


## The stations, by id (wheel 0, sails 1-2, anchor 3, cannons 4-7; the sloop has 0, 1 and 3).
func stations() -> Array[Dictionary]:
	if _stations.is_empty():
		_stations = _make_stations()
	return _stations


## The station with this id, or {} if this hull has none.
func station(id: int) -> Dictionary:
	for st in stations():
		if st.id == id:
			return st
	return {}


func _make_stations() -> Array[Dictionary]:
	return ShipShape.stations()


func half_width(z: float, y: float) -> float:
	return ShipShape.half_width(z, y)


func floor_y(z: float, x: float) -> float:
	return ShipShape.floor_y(z, x)


func is_on_board(p: Vector3) -> bool:
	return ShipShape.is_on_board(p)


func is_below_deck(p: Vector3) -> bool:
	return ShipShape.is_below_deck(p)


func plausible_position(p: Vector3) -> bool:
	return ShipShape.plausible_position(p)


func inside_hull(p: Vector3) -> bool:
	return ShipShape.inside_hull(p)


func makes_hole(hit: Vector3) -> bool:
	return ShipShape.makes_hole(hit)


func hole_point(hit: Vector3) -> Vector3:
	return ShipShape.hole_point(hit)


func ladder_bottom(side: int) -> Vector3:
	return ShipShape.ladder_bottom(side)


func ladder_top(side: int) -> Vector3:
	return ShipShape.ladder_top(side)


func map_table_target() -> Vector3:
	return ShipShape.map_table_target()


## Whether a pirate at `p` (ship frame) can fill a bucket with `water` aboard.
func can_scoop(p: Vector3, water: float) -> bool:
	return water >= 0.1 and is_below_deck(p) and p.y < ShipShape.LOWER_Y + water + 0.3


## Whether a pirate at `p` holding a full bucket can throw it over the side.
func can_throw(p: Vector3) -> bool:
	return p.y >= deck_y - 0.5


## Collision triangles for the deck proxy (cached).
func deck_faces() -> PackedVector3Array:
	if _faces.is_empty():
		_faces = _make_faces()
	return _faces


func _make_faces() -> PackedVector3Array:
	return ShipShape.deck_faces()

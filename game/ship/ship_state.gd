class_name ShipState
extends RefCounted
## Everything the server knows about one ship. Sent in every snapshot, so keep it small.

const MASTS := 2
const GUNS := 4
const MAX_CANNONBALLS := 60
const MAX_PLANKS := 30
const MAX_BANANAS := 20

enum Kind { CREW, SKELETON }

var kind := Kind.CREW
## The crew sailing her (1-4), or 0 for a skeleton ship.
var crew := 0
var x := 0.0
var z := 0.0
## Heading in radians around +Y. 0 faces -Z; positive turns the bow to port (left).
var yaw := 0.0
## Metres per second along the heading.
var speed := 0.0
## Wheel position, -1 (hard to port) .. 1 (hard to starboard).
var rudder := 0.0
## Per mast: 0 furled .. 1 fully down.
var sail_height: Array[float] = [0.0, 0.0]
## Per mast: -1 .. 1, the yards swung to port .. starboard (up to 45 degrees).
var sail_angle: Array[float] = [0.0, 0.0]
var anchored := true
## Progress of winching the anchor up, 0..1. Only meaningful while anchored.
var anchor_progress := 0.0

## Depth of water on the lower deck (m).
var water := 0.0
## 0 afloat; above 0 the ship is going down, reaching 1 when it is gone.
var sink := 0.0
## Holes on the lower deck: [id, x, y, z, patch progress 0..1], in the ship frame.
var holes: Array = []
## Per gun: aim yaw and pitch (see ShipShape.barrel_direction), and seconds until reloaded.
var gun_yaw: Array[float] = [0.0, 0.0, 0.0, 0.0]
var gun_pitch: Array[float] = [0.0, 0.0, 0.0, 0.0]
var gun_reload: Array[float] = [0.0, 0.0, 0.0, 0.0]

## Supplies aboard. Skeleton ships never run out.
var cannonballs := 30
var planks := 15
var bananas := 10

## Server only (never sent): the next hole's id.
var next_hole_id := 1


func is_sinking() -> bool:
	return sink > 0.0


func leaks() -> int:
	return holes.size()


func to_array() -> Array:
	var a := [
		kind, crew, x, z, yaw, speed, rudder,
		sail_height[0], sail_height[1], sail_angle[0], sail_angle[1],
		1 if anchored else 0, anchor_progress, water, sink, cannonballs, planks, bananas,
	]
	for g in GUNS:
		a.append_array([gun_yaw[g], gun_pitch[g], gun_reload[g]])
	a.append(holes.size())
	for h in holes:
		a.append_array(h)
	return a


static func from_array(a: Array) -> ShipState:
	var s := ShipState.new()
	s.kind = a[0]
	s.crew = a[1]
	s.x = a[2]
	s.z = a[3]
	s.yaw = a[4]
	s.speed = a[5]
	s.rudder = a[6]
	s.sail_height = [a[7], a[8]]
	s.sail_angle = [a[9], a[10]]
	s.anchored = a[11] == 1
	s.anchor_progress = a[12]
	s.water = a[13]
	s.sink = a[14]
	s.cannonballs = a[15]
	s.planks = a[16]
	s.bananas = a[17]
	var i := 18
	for g in GUNS:
		s.gun_yaw[g] = a[i]
		s.gun_pitch[g] = a[i + 1]
		s.gun_reload[g] = a[i + 2]
		i += 3
	var count: int = a[i]
	i += 1
	for h in count:
		s.holes.append([int(a[i]), a[i + 1], a[i + 2], a[i + 3], a[i + 4]])
		i += 5
	return s


func copy() -> ShipState:
	var c := from_array(to_array())
	c.next_hole_id = next_hole_id
	return c


## Blend two snapshots for drawing. Discrete fields (anchor, holes) come from the newer one.
static func blend(a: ShipState, b: ShipState, w: float) -> ShipState:
	var s := b.copy()
	s.x = lerpf(a.x, b.x, w)
	s.z = lerpf(a.z, b.z, w)
	s.yaw = wrapf(lerp_angle(a.yaw, b.yaw, w), -PI, PI)
	s.speed = lerpf(a.speed, b.speed, w)
	s.rudder = lerpf(a.rudder, b.rudder, w)
	s.water = lerpf(a.water, b.water, w)
	s.sink = lerpf(a.sink, b.sink, w)
	for m in MASTS:
		s.sail_height[m] = lerpf(a.sail_height[m], b.sail_height[m], w)
		s.sail_angle[m] = lerpf(a.sail_angle[m], b.sail_angle[m], w)
	for g in GUNS:
		s.gun_yaw[g] = lerpf(a.gun_yaw[g], b.gun_yaw[g], w)
		s.gun_pitch[g] = lerpf(a.gun_pitch[g], b.gun_pitch[g], w)
	return s

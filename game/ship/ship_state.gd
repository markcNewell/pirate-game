class_name ShipState
extends RefCounted
## Everything the server knows about one ship. Sent in every snapshot, so keep it small.

const MASTS := 2

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


func to_array() -> Array:
	return [
		x, z, yaw, speed, rudder,
		sail_height[0], sail_height[1], sail_angle[0], sail_angle[1],
		1 if anchored else 0, anchor_progress,
	]


static func from_array(a: Array) -> ShipState:
	var s := ShipState.new()
	s.x = a[0]
	s.z = a[1]
	s.yaw = a[2]
	s.speed = a[3]
	s.rudder = a[4]
	s.sail_height = [a[5], a[6]]
	s.sail_angle = [a[7], a[8]]
	s.anchored = a[9] == 1
	s.anchor_progress = a[10]
	return s


func copy() -> ShipState:
	return from_array(to_array())


## Blend two snapshots for drawing. Discrete fields (anchor) come from the newer one.
static func blend(a: ShipState, b: ShipState, w: float) -> ShipState:
	var s := b.copy()
	s.x = lerpf(a.x, b.x, w)
	s.z = lerpf(a.z, b.z, w)
	s.yaw = wrapf(lerp_angle(a.yaw, b.yaw, w), -PI, PI)
	s.speed = lerpf(a.speed, b.speed, w)
	s.rudder = lerpf(a.rudder, b.rudder, w)
	for m in MASTS:
		s.sail_height[m] = lerpf(a.sail_height[m], b.sail_height[m], w)
		s.sail_angle[m] = lerpf(a.sail_angle[m], b.sail_angle[m], w)
	return s

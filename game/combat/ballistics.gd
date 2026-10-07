class_name Ballistics
extends RefCounted
## Cannonball flight: a straight launch and gravity, nothing else, so every machine draws
## the same arc from the same launch numbers.

const GRAVITY := 9.81
const MUZZLE_SPEED := 65.0
const LIFETIME := 14.0


static func position(p0: Vector3, v0: Vector3, dt: float) -> Vector3:
	return p0 + v0 * dt + Vector3(0.0, -0.5 * GRAVITY * dt * dt, 0.0)


static func velocity(v0: Vector3, dt: float) -> Vector3:
	return v0 + Vector3(0.0, -GRAVITY * dt, 0.0)


## Low-arc elevation (radians) to hit a point `d` metres away and `dy` metres higher,
## or NAN if it is out of reach.
static func elevation(d: float, dy: float, speed := MUZZLE_SPEED) -> float:
	var s2 := speed * speed
	var root := s2 * s2 - GRAVITY * (GRAVITY * d * d + 2.0 * dy * s2)
	if root < 0.0 or d < 1e-3:
		return NAN
	return atan((s2 - sqrt(root)) / (GRAVITY * d))


## Furthest a ball flies over flat water from the waterline.
static func max_range(speed := MUZZLE_SPEED) -> float:
	return speed * speed / GRAVITY

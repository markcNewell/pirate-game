class_name Gunnery
extends RefCounted
## Aiming: where to point a gun so its ball meets a moving target.


## Solve for a launch direction. The ball leaves at `speed` along the direction plus the
## shooter's own velocity, so we aim in the shooter's frame, where the target moves at the
## difference of the two velocities. Returns {ok, dir (world, unit), time (s)}.
static func solve(
	muzzle: Vector3, shooter_vel: Vector3, target: Vector3, target_vel: Vector3,
	speed := Ballistics.MUZZLE_SPEED
) -> Dictionary:
	var rel := target_vel - shooter_vel
	var t := muzzle.distance_to(target) / speed
	var dir := Vector3.ZERO
	for i in 6:
		var aim := target + rel * t
		var flat := Vector2(aim.x - muzzle.x, aim.z - muzzle.z)
		var d := flat.length()
		var theta := Ballistics.elevation(d, aim.y - muzzle.y, speed)
		if is_nan(theta):
			return {"ok": false}
		var h := flat / maxf(d, 1e-3)
		dir = Vector3(h.x * cos(theta), sin(theta), h.y * cos(theta))
		t = d / (speed * cos(theta))
	return {"ok": true, "dir": dir, "time": t}


## A world direction as a gun's yaw and pitch on a ship with the given pose.
## Returns {ok, yaw, pitch}; not ok if the direction points across the deck.
static func to_gun_angles(pose: Transform3D, gun: int, dir: Vector3) -> Dictionary:
	var local := (pose.basis.inverse() * dir).normalized()
	var side := ShipShape.cannon_side(gun)
	if local.x * side <= 0.05:
		return {"ok": false}
	var yaw := atan2(-local.z, local.x * side)
	var pitch := asin(clampf(local.y, -1.0, 1.0))
	var ok := absf(yaw) <= ShipShape.CANNON_YAW_LIMIT \
		and pitch >= ShipShape.CANNON_PITCH_MIN and pitch <= ShipShape.CANNON_PITCH_MAX
	return {"ok": ok, "yaw": yaw, "pitch": pitch}

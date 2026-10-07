class_name Weapons
extends RefCounted
## Hand weapons and what they hit. Pure geometry, so the server and tests agree exactly.
## Bodies are upright capsules standing on `feet` points, all in one frame (the world).

enum Kind { CUTLASS, PISTOL }

const CUTLASS_DAMAGE := 25
const CUTLASS_REACH := 2.4
## Half the swing's arc, in radians (70 degrees in all).
const CUTLASS_HALF_ARC := 0.61
const CUTLASS_COOLDOWN := 0.6

const PISTOL_DAMAGE := 40
const PISTOL_RANGE := 60.0
const PISTOL_RELOAD := 2.5

const BODY_RADIUS := 0.45
const BODY_HEIGHT := 1.8
const EYE_HEIGHT := 1.6


## Indices of the bodies a cutlass swing from `eye` along `look` catches.
static func cutlass_hits(eye: Vector3, look: Vector3, feet: Array) -> Array[int]:
	var hits: Array[int] = []
	var flat_look := Vector2(look.x, look.z).normalized()
	for i in feet.size():
		var f: Vector3 = feet[i]
		var centre := f + Vector3.UP * BODY_HEIGHT * 0.5
		var to := centre - eye
		if to.length() > CUTLASS_REACH + BODY_RADIUS:
			continue
		var flat := Vector2(to.x, to.z)
		if flat.length() < 0.2:
			hits.append(i)
			continue
		if absf(flat_look.angle_to(flat.normalized())) <= CUTLASS_HALF_ARC:
			hits.append(i)
	return hits


## Index of the first body a pistol ball along `look` from `eye` strikes, or -1.
static func pistol_hit(eye: Vector3, look: Vector3, feet: Array) -> int:
	var best := -1
	var best_t := PISTOL_RANGE
	var dir := look.normalized()
	for i in feet.size():
		var f: Vector3 = feet[i]
		# Closest approach of the shot to the capsule's spine.
		var a := f + Vector3.UP * BODY_RADIUS
		var b := f + Vector3.UP * (BODY_HEIGHT - BODY_RADIUS)
		var t := _ray_segment(eye, dir, a, b)
		if t.y <= BODY_RADIUS and t.x > 0.0 and t.x < best_t:
			best = i
			best_t = t.x
	return best


## Distance along the ray (x) and the gap between ray and segment there (y).
static func _ray_segment(o: Vector3, d: Vector3, a: Vector3, b: Vector3) -> Vector2:
	var best := Vector2(INF, INF)
	for k in 9:
		var p := a.lerp(b, k / 8.0)
		var t := maxf(0.0, (p - o).dot(d))
		var gap := (o + d * t).distance_to(p)
		if gap < best.y:
			best = Vector2(t, gap)
	return best


## Damage a cannonball does to someone this far from where it struck.
static func splash_damage(distance: float) -> int:
	if distance < 1.5:
		return 70
	if distance < 3.5:
		return 30
	return 0

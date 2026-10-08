class_name Weapons
extends RefCounted
## Hand weapons and what they hit. Pure geometry, so the server and tests agree exactly.
## Bodies are upright capsules standing on `feet` points, all in one frame (the world).

## The two hands (the weapon slot a player holds): the blade and the gun.
enum Kind { CUTLASS, PISTOL }

## What can go in each hand (docs/specs/2026-10-08-m14-the-armoury.md): fair choices, never
## upgrades. Blades all do about 42 damage a second; the guns trade range for punch.
const BLADES := [
	{"name": "Cutlass", "damage": 25, "reach": 2.4, "half_arc": 0.61, "every": 0.6, "mesh": "cutlass"},
	{"name": "Rapier", "damage": 15, "reach": 2.9, "half_arc": 0.3, "every": 0.36, "mesh": "rapier"},
	{"name": "Boarding axe", "damage": 45, "reach": 2.0, "half_arc": 0.87, "every": 1.05, "mesh": "boarding_axe"},
]
const GUNS := [
	{"name": "Flintlock pistol", "damage": 40, "range": 60.0, "every": 2.5, "pellets": 1, "spread": 0.0, "mesh": "flintlock"},
	{"name": "Blunderbuss", "damage": 12, "range": 18.0, "every": 3.0, "pellets": 6, "spread": 0.12, "mesh": "blunderbuss"},
	{"name": "Long musket", "damage": 75, "range": 110.0, "every": 4.5, "pellets": 1, "spread": 0.0, "mesh": "musket"},
]

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


static func blade(i: int) -> Dictionary:
	return BLADES[clampi(i, 0, BLADES.size() - 1)]


static func gun(i: int) -> Dictionary:
	return GUNS[clampi(i, 0, GUNS.size() - 1)]


## How long after an attack with hand `kind` (blade `blade_i` or gun `gun_i`) the next can come.
static func every(kind: int, blade_i: int, gun_i: int) -> float:
	return float(blade(blade_i).every) if kind == Kind.CUTLASS else float(gun(gun_i).every)


## The directions a gun's pellets fly along `look`: one straight, the rest in a ring `spread`
## (radians) round it. The same every time, so the server and tests agree.
static func pellet_dirs(look: Vector3, pellets: int, spread: float) -> Array[Vector3]:
	var dir := look.normalized()
	var out: Array[Vector3] = [dir]
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	for k in pellets - 1:
		var a := TAU * k / float(maxi(1, pellets - 1))
		out.append((dir + (side * cos(a) + up * sin(a)) * tan(spread)).normalized())
	return out


## Indices of the bodies a cutlass swing from `eye` along `look` catches (or another blade's,
## with its `reach` and `half_arc`).
static func cutlass_hits(eye: Vector3, look: Vector3, feet: Array, reach := CUTLASS_REACH, half_arc := CUTLASS_HALF_ARC) -> Array[int]:
	var hits: Array[int] = []
	var flat_look := Vector2(look.x, look.z).normalized()
	for i in feet.size():
		var f: Vector3 = feet[i]
		var centre := f + Vector3.UP * BODY_HEIGHT * 0.5
		var to := centre - eye
		if to.length() > reach + BODY_RADIUS:
			continue
		var flat := Vector2(to.x, to.z)
		if flat.length() < 0.2:
			hits.append(i)
			continue
		if absf(flat_look.angle_to(flat.normalized())) <= half_arc:
			hits.append(i)
	return hits


## Index of the first body a pistol ball along `look` from `eye` strikes, or -1 (out to `range`).
static func pistol_hit(eye: Vector3, look: Vector3, feet: Array, range := PISTOL_RANGE) -> int:
	var best := -1
	var best_t := range
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

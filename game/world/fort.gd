class_name Fort
extends RefCounted
## Fuerte del Cuervo, the Admiral's fort (story Act II): where its walls, gate, towers, cells,
## vault and gun platform stand on its island. One layout shared by the island's collision, the
## model's placement, the story's objects and the skeletons' footing. All island-local (x, z)
## around the island's centre unless a function says world.

## The gate faces west (-x), toward the rest of the Isles.
const FACING := PI
const WALL_R := 13.0
const WALL_H := 5.0
const WALL_T := 1.4
const GATE_HALF := 2.2
## The two gun towers, either side of the gate.
const TOWER_SPREAD := 0.9
const TOWER_R := 2.6
const TOWER_H := 8.0
## The flat top the fort stands on (ground height inside this radius).
const PLATEAU_Y := 2.6
const PLATEAU_R := 24.0
## Buildings inside: [angle from the gate's direction, distance from the centre, size x, size z].
const CELLS := [PI + 0.65, 8.0, 5.0, 3.5]
const VAULT := [PI - 0.65, 8.0, 4.0, 3.0]
const BUILDING_H := 4.0
## The gunner's raised platform in the middle of the courtyard.
const PLATFORM := Vector3(3.0, 1.2, 3.0)


static func index() -> int:
	for i in Islands.LAYOUT.size():
		if Islands.LAYOUT[i].get("fort", false):
			return i
	return -1


static func centre() -> Vector3:
	var spec: Dictionary = Islands.LAYOUT[index()]
	return Vector3(spec.x, PLATEAU_Y, spec.z)


## Island-local point at angle `a` from the gate's direction, `r` from the centre.
static func local(a: float, r: float) -> Vector2:
	return Vector2(cos(FACING + a), sin(FACING + a)) * r


static func world(a: float, r: float, up := 0.0) -> Vector3:
	var p := local(a, r)
	var c := centre()
	return Vector3(c.x + p.x, PLATEAU_Y + up, c.z + p.y)


static func gate_pos() -> Vector3:
	return world(0.0, WALL_R)


static func tower_pos(side: int) -> Vector3:
	return world(TOWER_SPREAD * side, WALL_R)


static func gun_pos(side: int) -> Vector3:
	return tower_pos(side) + Vector3(0, TOWER_H, 0)


static func building_pos(spec_row: Array) -> Vector3:
	return world(spec_row[0], spec_row[1])


## Where you stand to work a building's door: on its courtyard side.
static func door_pos(spec_row: Array) -> Vector3:
	return world(spec_row[0], spec_row[1] - spec_row[3] * 0.5 - 0.8)


## A spot on a ring round the courtyard (world), `a` radians round from east, moved round the
## ring until it is clear of the buildings (the dead must stand where they can walk).
static func ring_spot(a: float, r: float) -> Vector3:
	var c := centre()
	for k in 24:
		var p := Vector2(cos(a), sin(a)) * r
		if not blocked(p.x, p.y, false):
			return Vector3(c.x + p.x, PLATEAU_Y, c.z + p.y)
		a += 0.15
	return c


## Where Isabel keeps the fort once the story is done (world): in the courtyard, inside the gate.
static func isabel_pos() -> Vector3:
	return world(0.0, 5.5)


## The fort's supply barrels once it is a friendly port (world): inside the wall, by the gate.
static func barrels() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for a: float in [0.3, 0.38, 0.46]:
		out.append(world(a, 10.2))
	return out


static func platform_pos() -> Vector3:
	return centre() + Vector3(0, PLATFORM.y, 0)


## Is island-local (x, z) inside a wall, tower or building (where no one can stand)? The gate's
## gap is open only once the gate is blown.
static func blocked(x: float, z: float, gate_open: bool) -> bool:
	var p := Vector2(x, z)
	var r := p.length()
	var a := angle_difference(FACING, atan2(z, x))
	if absf(r - WALL_R) < WALL_T * 0.5 + 0.3:
		var along := absf(a) * WALL_R
		if along > GATE_HALF or not gate_open:
			return true
	for side: int in [-1, 1]:
		if p.distance_to(local(TOWER_SPREAD * side, WALL_R)) < TOWER_R + 0.3:
			return true
	for row: Array in [CELLS, VAULT]:
		var c := local(row[0], row[1])
		var d := (p - c).rotated(-(FACING + float(row[0])))
		if absf(d.x) < row[3] * 0.5 + 0.2 and absf(d.y) < row[2] * 0.5 + 0.2:
			return true
	return false


## Collision boxes for the island's solid mesh: [centre (island-local, y up), half size, yaw].
static func boxes() -> Array:
	var out := []
	# The wall as a ring of segments, leaving the gate's gap.
	var segments := 36
	for k in segments:
		var a := TAU * (k + 0.5) / segments - PI
		if absf(a) * WALL_R < GATE_HALF + 0.6:
			continue
		var p := local(a, WALL_R)
		var half_len := PI * WALL_R / segments + 0.15
		out.append([Vector3(p.x, PLATEAU_Y + WALL_H * 0.5, p.y), Vector3(WALL_T * 0.5, WALL_H * 0.5, half_len), FACING + a])
	for side: int in [-1, 1]:
		var t := local(TOWER_SPREAD * side, WALL_R)
		out.append([Vector3(t.x, PLATEAU_Y + TOWER_H * 0.5, t.y), Vector3(TOWER_R, TOWER_H * 0.5, TOWER_R), 0.0])
	for row: Array in [CELLS, VAULT]:
		var c := local(row[0], row[1])
		out.append([Vector3(c.x, PLATEAU_Y + BUILDING_H * 0.5, c.y), Vector3(row[3] * 0.5, BUILDING_H * 0.5, row[2] * 0.5), FACING + float(row[0])])
	out.append([Vector3(0, PLATEAU_Y + PLATFORM.y * 0.5, 0), PLATFORM * 0.5, 0.0])
	return out

class_name Calavera
extends RefCounted
## Isla Calavera (story Act IV): the skull-shaped rock, the tooth-stones on the beach before it,
## the carvings of the pilot's riddle and his grave. Its model (art/blender/places.py, calavera)
## is built looking along -Z; here it is turned to look out along FACING. Island-local unless a
## function says world.

## The direction (round the island) the skull's face looks out to sea.
const FACING := 0.6
## The rock's centre lies this far behind the island's centre.
const ROCK_BACK := 7.0
## The rock's footprint for collision: half sizes across, up and front-to-back.
const HALF := Vector3(11.0, 7.0, 8.0)


static func index() -> int:
	for i in Islands.LAYOUT.size():
		if Islands.LAYOUT[i].get("skull", false):
			return i
	return -1


## The skull's frame, island-local: origin at the rock's centre on the ground, -Z out of its face.
static func frame() -> Transform3D:
	var out := Vector3(cos(FACING), 0, sin(FACING))
	var at := -out * ROCK_BACK
	var spec: Dictionary = Islands.LAYOUT[index()]
	var face := at + out * 7.0
	at.y = IslandMesh.ground(spec, face.x, face.z) - 0.6
	return Transform3D(Basis(Vector3.UP, atan2(out.x, out.z) + PI), at)


static func _world(local: Vector3) -> Vector3:
	var spec: Dictionary = Islands.LAYOUT[index()]
	var p := frame() * local
	return Vector3(spec.x + p.x, IslandMesh.ground(spec, p.x, p.z), spec.z + p.z)


## On the ground before an eye hollow (side -1 the skull's left as you face it, +1 its right).
static func eye(side: int) -> Vector3:
	return _world(Vector3(side * 4.4, 0, -9.2))


## The tooth-stones along the beach before the skull (0-5, left to right as you face it).
static func tooth(i: int) -> Vector3:
	return _world(tooth_local(i))


static func tooth_local(i: int) -> Vector3:
	return Vector3(-6.0 + 2.4 * i, 0, -16.0 + 0.25 * (i - 2.5) * (i - 2.5))


## The pilot's grave: in the sand between the skull's teeth and the tooth-stones.
static func grave() -> Vector3:
	return _world(Vector3(0.5, 0, -12.5))


## Collision for the rock (island-local): [centre, half size, yaw].
static func box() -> Array:
	var f := frame()
	return [f * Vector3(0, HALF.y, 2.0), HALF, -f.basis.get_euler().y]

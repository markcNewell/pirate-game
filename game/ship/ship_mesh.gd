class_name ShipMesh
extends RefCounted
## What is left of the code-built galleon now its model comes from Blender (art/blender/ship.py):
## the palette in use, the sail sizes, the crew emblem on the main course, the flood water's
## outline and where the name goes on the stern.

const SAIL_BELLY := 0.9

## Colours for the ship being built: Toon.PALETTE, with any overrides from a palette
## (Toon.SKELETON for the enemy). Set by the public builders before they run.
static var _pal := {}


static func _c(name: String) -> Color:
	return _pal.get(name, Toon.color(name))


static func use_palette(pal: Dictionary) -> void:
	_pal = pal


## Lower and upper sail per mast: [top height above deck, height, width].
static func sails_for(mast: int) -> Array:
	var h: float = ShipShape.MAST_HEIGHT[mast]
	return [
		[0.55 * h, 0.55 * h - 0.2 * h, 9.0 + mast * 1.0],
		[0.85 * h, 0.85 * h - 0.6 * h - 0.3, 7.0 + mast * 1.0],
	]


## The flat outline of the lower deck at y = 0, raised by ShipView to the water level.
static func flood_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var z := ShipShape.LOWER_Z0
	while z < ShipShape.LOWER_Z1 - 1e-3:
		var z1 := minf(z + 0.5, ShipShape.LOWER_Z1)
		var w0 := ShipShape.lower_wall_x(z)
		var w1 := ShipShape.lower_wall_x(z1)
		verts.append_array([Vector3(-w0, 0, z), Vector3(w1, 0, z1), Vector3(w0, 0, z)])
		verts.append_array([Vector3(-w0, 0, z), Vector3(-w1, 0, z1), Vector3(w1, 0, z1)])
		z = z1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m



## Centre of the board on the transom where the ship's name is painted.
static func name_board() -> Vector3:
	return Vector3(0, ShipShape.DECK_Y + 0.1, ShipShape.HALF_LENGTH + 0.06)


## A round skull-and-bones emblem for the main course sail: one disc just in front of the
## sail's bulge and one just behind it, so it shows from both sides. Centred on the sail's
## middle (the bulge is deepest there, SAIL_BELLY).
static func emblem() -> ArrayMesh:
	var b := MeshBuilder.new()
	var depth := SAIL_BELLY * 0.99
	for side: float in [-1.0, 1.0]:
		# Front (bow side, -z) sits beyond the bulge; back (+z) sits inside the hollow.
		var z := -depth - 0.08 if side < 0.0 else -depth + 0.15
		var face := Vector3(0, 0, z)
		b.cylinder(face, face + Vector3(0, 0, side * 0.01), 1.15, 1.15, 20, _c("flag"), true)
		b.ellipsoid(face + Vector3(0, 0.15, side * 0.015), 0.42, Vector3(1.0, 1.0, 0.08), 6, 10, _c("bone"))
		for k in 2:
			b.ellipsoid(face + Vector3((k - 0.5) * 0.3, 0.2, side * 0.035), 0.09, Vector3(1, 1.2, 0.2), 4, 6, _c("flag"))
		for a: float in [0.7, -0.7]:
			b.box(face + Vector3(0, -0.45, side * 0.015), Vector3(0.6, 0.07, 0.015), _c("bone"), Basis(Vector3.BACK, a))
	return b.build()

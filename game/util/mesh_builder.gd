class_name MeshBuilder
extends RefCounted
## Collects coloured triangles and turns them into one ArrayMesh for the toon shader.
##
## Every triangle is given an outward direction and its winding is fixed to match, so callers
## never think about Godot's clockwise front faces. build() also stores a smoothed copy of the
## normals in CUSTOM0 for the outline pass: hard-edged boxes then get a closed ink outline
## instead of cracks at their corners.

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()


func is_empty() -> bool:
	return _verts.is_empty()


## One triangle. `outward` only needs to point roughly away from the solid.
## Pass `normals` (three of them) for smooth shading, or leave it empty for a flat face.
func tri(
	a: Vector3, b: Vector3, c: Vector3, color: Color, outward: Vector3,
	normals: PackedVector3Array = PackedVector3Array()
) -> void:
	var face := (c - a).cross(b - a)
	if face.length_squared() < 1e-12:
		return
	if face.dot(outward) < 0.0:
		var swap := b
		b = c
		c = swap
		if normals.size() == 3:
			normals = PackedVector3Array([normals[0], normals[2], normals[1]])
		face = -face
	var flat := face.normalized()
	var linear := color.srgb_to_linear()
	for i in 3:
		_verts.append([a, b, c][i])
		_normals.append(normals[i] if normals.size() == 3 else flat)
		_colors.append(linear)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, outward: Vector3) -> void:
	tri(a, b, c, color, outward)
	tri(a, c, d, color, outward)


## A box, optionally rotated by `basis` around its centre.
func box(centre: Vector3, half: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
	var corners: Array[Vector3] = []
	for i in 8:
		var local := Vector3(
			half.x * (1 if i & 1 else -1), half.y * (1 if i & 2 else -1), half.z * (1 if i & 4 else -1)
		)
		corners.append(centre + basis * local)
	# Faces as corner indices: -x, +x, -y, +y, -z, +z.
	for f in [[0, 2, 6, 4], [1, 5, 7, 3], [0, 4, 5, 1], [2, 3, 7, 6], [0, 1, 3, 2], [4, 6, 7, 5]]:
		var a: Vector3 = corners[f[0]]
		var c: Vector3 = corners[f[2]]
		quad(a, corners[f[1]], c, corners[f[3]], color, (a + c) * 0.5 - centre)


## A (possibly tapered) tube from `bottom` to `top`, smooth around, with flat caps.
func cylinder(
	bottom: Vector3, top: Vector3, r_bottom: float, r_top: float, sides: int, color: Color,
	caps := true
) -> void:
	var axis := (top - bottom).normalized()
	var side_a := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var side_b := axis.cross(side_a)
	var slope := (r_bottom - r_top) / maxf(1e-4, bottom.distance_to(top))
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := side_a * cos(a0) + side_b * sin(a0)
		var d1 := side_a * cos(a1) + side_b * sin(a1)
		var n0 := (d0 + axis * slope).normalized()
		var n1 := (d1 + axis * slope).normalized()
		var p0 := bottom + d0 * r_bottom
		var p1 := bottom + d1 * r_bottom
		var q0 := top + d0 * r_top
		var q1 := top + d1 * r_top
		tri(p0, p1, q1, color, d0 + d1, PackedVector3Array([n0, n1, n1]))
		tri(p0, q1, q0, color, d0 + d1, PackedVector3Array([n0, n1, n0]))
		if caps:
			tri(bottom, p0, p1, color, -axis)
			tri(top, q0, q1, color, axis)


## A smooth ellipsoid: a sphere of `radius` stretched by `stretch`.
func ellipsoid(centre: Vector3, radius: float, stretch: Vector3, rings: int, sectors: int, color: Color) -> void:
	var point := func(r: int, s: int) -> Vector3:
		var lat := PI * r / rings - PI / 2.0
		var lon := TAU * s / sectors
		return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
	for r in rings:
		for s in sectors:
			var u: Array[Vector3] = [point.call(r, s), point.call(r, s + 1), point.call(r + 1, s + 1), point.call(r + 1, s)]
			var p: Array[Vector3] = []
			var n := PackedVector3Array()
			for v in u:
				p.append(centre + v * radius * stretch)
				n.append((v / stretch).normalized())
			var out := (u[0] + u[2]).normalized()
			tri(p[0], p[1], p[2], color, out, PackedVector3Array([n[0], n[1], n[2]]))
			tri(p[0], p[2], p[3], color, out, PackedVector3Array([n[0], n[2], n[3]]))


## A smooth surface from a grid of points (rows x columns). `normal_at` returns the outward
## normal for a point; triangles take their winding from it.
func grid(rows: Array, color_at: Callable, normal_at: Callable) -> void:
	for r in rows.size() - 1:
		var row: PackedVector3Array = rows[r]
		var next: PackedVector3Array = rows[r + 1]
		for c in row.size() - 1:
			var p := [row[c], row[c + 1], next[c + 1], next[c]]
			var n := PackedVector3Array()
			for q in p:
				n.append(normal_at.call(q))
			var color: Color = color_at.call((p[0] + p[2]) * 0.5)
			var out := (n[0] + n[2]).normalized()
			tri(p[0], p[1], p[2], color, out, PackedVector3Array([n[0], n[1], n[2]]))
			tri(p[0], p[2], p[3], color, out, PackedVector3Array([n[0], n[2], n[3]]))


## Triangles for a ConcavePolygonShape3D, without colours.
func faces() -> PackedVector3Array:
	# A copy: packed arrays are shared, and callers append to this.
	return _verts.duplicate()


func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_CUSTOM0] = _outline_normals()
	var flags := Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return mesh


func _outline_normals() -> PackedFloat32Array:
	var sums := {}
	for i in _verts.size():
		var key := _verts[i].snappedf(0.001)
		sums[key] = sums.get(key, Vector3.ZERO) + _normals[i]
	var out := PackedFloat32Array()
	out.resize(_verts.size() * 3)
	for i in _verts.size():
		var n: Vector3 = sums[_verts[i].snappedf(0.001)]
		n = n.normalized() if n.length_squared() > 1e-8 else _normals[i]
		out[i * 3] = n.x
		out[i * 3 + 1] = n.y
		out[i * 3 + 2] = n.z
	return out

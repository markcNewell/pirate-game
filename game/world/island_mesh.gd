class_name IslandMesh
extends RefCounted
## Builds one island from its layout entry: a sandy beach shelving into the sea, a grass mound
## (plus a hill on the big one), palms and rocks. Island-local coordinates: centre at the
## origin, waterline at y = 0. Returns the model and the walkable collision triangles.

const BEACH_SLOPE := 0.33
const SAND_TOP := 1.2
const SEA_FLOOR := -4.0


## The ground height at a point, from the island's radial profile plus a little wobble so
## the coastline is not a perfect circle. ocean.gdshader uses the same wobble for its foam.
static func ground(spec: Dictionary, x: float, z: float) -> float:
	var radius: float = spec.radius
	var r := Vector2(x, z).length() / (1.0 + 0.04 * sin(5.0 * atan2(z, x)))
	if r >= radius:
		return maxf(SEA_FLOOR, -(r - radius) * BEACH_SLOPE)
	var beach := minf(SAND_TOP, (radius - r) * BEACH_SLOPE)
	var a := radius - 6.0
	var mound := -1.5 + 0.28 * a * sqrt(maxf(0.0, 1.0 - (r / a) * (r / a)))
	var y := maxf(beach, mound)
	if spec.hill:
		var d := Vector2(x + 0.25 * radius, z - 0.3 * radius).length() / (0.4 * radius)
		y = maxf(y, 0.25 * radius * (1.0 - d * d) - 1.0)
	return y


static func is_grass(spec: Dictionary, x: float, z: float) -> bool:
	return ground(spec, x, z) > SAND_TOP + 0.08


static func build(spec: Dictionary) -> Dictionary:
	var ground_b := MeshBuilder.new()
	var decor := MeshBuilder.new()
	var solid := MeshBuilder.new()
	_ground(ground_b, spec)
	var rng := RandomNumberGenerator.new()
	rng.seed = spec.seed
	_palms(decor, solid, spec, rng)
	_rocks(decor, solid, spec, rng)
	_bushes(decor, spec, rng)
	var fire: Variant = null
	if not spec.get("outpost", false):
		fire = _camp(decor, solid, spec, rng)
	var faces := ground_b.faces()
	faces.append_array(solid.faces())
	return {"ground": ground_b.build(), "decor": decor.build(), "faces": faces, "fire": fire}


static func _ground(b: MeshBuilder, spec: Dictionary) -> void:
	var radius: float = spec.radius
	var sectors := 72 if radius > 40.0 else 48
	var step := 1.5 if radius > 40.0 else 1.0
	var rings: Array[float] = [0.0]
	var r := 2.0
	while r < radius + 12.0:
		rings.append(r)
		r += step if r > radius - 8.0 else step * 2.0
	rings.append(radius + 12.0)

	var rows := []
	for ring in rings:
		var row := PackedVector3Array()
		for s in sectors + 1:
			var a := TAU * s / sectors
			var wob := 1.0 + 0.04 * sin(5.0 * a)
			var x := cos(a) * ring * wob
			var z := sin(a) * ring * wob
			row.append(Vector3(x, ground(spec, x, z), z))
		rows.append(row)

	var color_at := func(p: Vector3) -> Color:
		if p.y < 0.25:
			return Toon.color("wet_sand")
		if is_grass(spec, p.x, p.z):
			# Two-tone patches, like brush strokes on a cartoon background.
			var patch := sin(p.x * 0.21 + sin(p.z * 0.17) * 2.0) * sin(p.z * 0.19 + sin(p.x * 0.13) * 2.0)
			return Toon.color("grass_dark") if patch > 0.25 else Toon.color("grass")
		return Toon.color("sand")
	var normal_at := func(p: Vector3) -> Vector3:
		var e := 0.2
		var dx := (ground(spec, p.x + e, p.z) - ground(spec, p.x - e, p.z)) / (2.0 * e)
		var dz := (ground(spec, p.x, p.z + e) - ground(spec, p.x, p.z - e)) / (2.0 * e)
		return Vector3(-dx, 1.0, -dz).normalized()
	b.grid(rows, color_at, normal_at)


static func _palms(decor: MeshBuilder, solid: MeshBuilder, spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var radius: float = spec.radius
	var count := int(radius / 4.0)
	var placed := 0
	var tries := 0
	while placed < count and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.15, 0.85) * (radius - 4.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var y := ground(spec, x, z)
		if y < SAND_TOP - 0.1:
			continue
		# Keep the outpost's pier and hut clear of palms.
		if spec.get("outpost", false) and absf(angle_difference(0.3, a)) < 0.75:
			continue
		_palm(decor, Vector3(x, y - 0.2, z), rng.randf_range(6.0, 9.5), rng.randf() * TAU, rng.randf_range(1.0, 2.6))
		solid.box(Vector3(x, y + 1.0, z), Vector3(0.35, 1.2, 0.35), Color.BLACK)
		placed += 1


static func _palm(b: MeshBuilder, base: Vector3, height: float, turn: float, lean: float) -> void:
	var bend := Basis(Vector3.UP, turn)
	var segments := 6
	var prev := base
	for i in segments:
		var t := float(i + 1) / segments
		var p := base + bend * Vector3(lean * t * t, height * t, 0)
		var shade := Toon.color("trunk") if i % 2 == 0 else Toon.color("trunk").darkened(0.12)
		b.cylinder(prev, p, 0.42 - 0.04 * i, 0.38 - 0.04 * i, 8, shade)
		prev = p
	var crown := prev
	for i in 7:
		var dir := Basis(Vector3.UP, turn + TAU * i / 7.0)
		var leaf_centre := crown + dir * Vector3(2.0, -0.55, 0)
		var tilt := dir * Basis(Vector3.BACK, -0.42)
		_leaf(b, leaf_centre, tilt)
	for i in 3:
		var nut := crown + Basis(Vector3.UP, TAU * i / 3.0) * Vector3(0.35, -0.35, 0)
		b.ellipsoid(nut, 0.24, Vector3.ONE, 5, 7, Toon.color("hull_dark"))


static func _leaf(b: MeshBuilder, centre: Vector3, basis: Basis) -> void:
	# A flattened ellipsoid, rotated to droop away from the crown.
	var rings := 4
	var sectors := 8
	var stretch := Vector3(2.4, 0.16, 0.6)
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
				p.append(centre + basis * (v * stretch))
				n.append((basis * (v / stretch)).normalized())
			var out := basis * (u[0] + u[2]).normalized()
			b.tri(p[0], p[1], p[2], Toon.color("leaf"), out, PackedVector3Array([n[0], n[1], n[2]]))
			b.tri(p[0], p[2], p[3], Toon.color("leaf"), out, PackedVector3Array([n[0], n[2], n[3]]))


static func _rocks(decor: MeshBuilder, solid: MeshBuilder, spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var radius: float = spec.radius
	for i in int(radius / 6.0) + 2:
		var a := rng.randf() * TAU
		var r := rng.randf_range(radius - 4.0, radius + 3.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var size := rng.randf_range(0.8, 2.2)
		var centre := Vector3(x, ground(spec, x, z) + size * 0.3, z)
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		for target: MeshBuilder in [decor, solid]:
			_rock(target, centre, size, spin)


## A faceted lump: a coarse ellipsoid with flat faces.
static func _rock(b: MeshBuilder, centre: Vector3, size: float, spin: Basis) -> void:
	var rings := 3
	var sectors := 6
	var stretch := Vector3(1.2, 0.75, 1.0) * size
	var point := func(r: int, s: int) -> Vector3:
		var lat := PI * r / rings - PI / 2.0
		var lon := TAU * s / sectors + r * 0.5
		return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
	for r in rings:
		for s in sectors:
			var u: Array[Vector3] = [point.call(r, s), point.call(r, s + 1), point.call(r + 1, s + 1), point.call(r + 1, s)]
			var p: Array[Vector3] = []
			for v in u:
				p.append(centre + spin * (v * stretch))
			var out := spin * (u[0] + u[2])
			b.tri(p[0], p[1], p[2], Toon.color("rock"), out)
			b.tri(p[0], p[2], p[3], Toon.color("rock"), out)



## Round toon bushes and little clumps of flowers on the grass.
static func _bushes(b: MeshBuilder, spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var radius: float = spec.radius
	var flowers: Array[Color] = [Color("ff6b6b"), Color("ffd84a"), Color("f2f2ff"), Color("ff9ad5")]
	for i in int(radius / 2.5):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.1, 0.85) * (radius - 4.0)
		var x := cos(a) * r
		var z := sin(a) * r
		if not is_grass(spec, x, z):
			continue
		if spec.get("outpost", false) and absf(angle_difference(0.3, a)) < 0.75:
			continue
		var y := ground(spec, x, z)
		if i % 3 == 0:
			var c: Color = flowers[rng.randi() % flowers.size()]
			for k in 5:
				var p := Vector3(x + rng.randf_range(-0.6, 0.6), y + 0.12, z + rng.randf_range(-0.6, 0.6))
				b.cylinder(p - Vector3(0, 0.12, 0), p, 0.02, 0.02, 4, Color("2f6b26"), false)
				b.ellipsoid(p + Vector3(0, 0.05, 0), 0.09, Vector3(1, 0.6, 1), 3, 6, c)
			continue
		var size := rng.randf_range(0.6, 1.1)
		var green := Color("3f8a35") if i % 2 == 0 else Color("4a9a3a")
		for k in 3:
			var off := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)) * size
			b.ellipsoid(Vector3(x, y + 0.35 * size, z) + off, 0.55 * size, Vector3(1, 0.8, 1), 5, 8, green)


## A skeleton camp: a tattered tent, a ring of stones round a fire (lit at night), and a few
## bones. Returns where the fire is, relative to the island's centre.
static func _camp(b: MeshBuilder, solid: MeshBuilder, spec: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var radius: float = spec.radius
	var a := rng.randf() * TAU
	var r := 0.35 * radius
	var at := Vector3(cos(a) * r, 0, sin(a) * r)
	at.y = ground(spec, at.x, at.z)
	var cloth := Color("8a7f6a")
	var turn := Basis(Vector3.UP, a + PI / 2.0)
	# Tent: a ridge pole on two posts with sloping cloth sides.
	var tent := at + turn * Vector3(3.0, 0, 0)
	for s: float in [-1.2, 1.2]:
		b.cylinder(tent + turn * Vector3(0, 0, s), tent + turn * Vector3(0, 1.8, s), 0.06, 0.06, 5, Color("5e4630"))
	b.cylinder(tent + turn * Vector3(0, 1.8, -1.3), tent + turn * Vector3(0, 1.8, 1.3), 0.05, 0.05, 5, Color("5e4630"))
	for side: float in [-1.0, 1.0]:
		var c := turn * Basis(Vector3.BACK, side * 0.75)
		b.box(tent + turn * Vector3(side * 0.62, 0.95, 0), Vector3(0.03, 1.1, 1.25), cloth if side < 0 else cloth.darkened(0.15), c)
	solid.box(tent + Vector3(0, 0.9, 0), Vector3(0.9, 0.9, 0.9), Color.BLACK, turn)
	# Fire ring and charred logs.
	for k in 8:
		var ang := TAU * k / 8.0
		b.ellipsoid(at + Vector3(cos(ang) * 0.75, 0.1, sin(ang) * 0.75), 0.18, Vector3(1.2, 0.7, 1), 3, 5, Color("7d7a76"))
	for k in 3:
		var ang := TAU * k / 3.0 + 0.4
		b.box(at + Vector3(0, 0.12, 0), Vector3(0.45, 0.07, 0.07), Color("2b2018"), Basis(Vector3.UP, ang))
	# Scattered bones.
	for k in 3:
		var p := at + Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))
		p.y = ground(spec, p.x, p.z) + 0.05
		b.box(p, Vector3(0.25, 0.035, 0.035), Color("efe8d2"), Basis(Vector3.UP, rng.randf() * TAU))
	return at

class_name IslandMesh
extends RefCounted
## Builds one island from its layout entry: a sandy beach shelving into the sea, a grass mound
## (plus a hill on the big one), palms and rocks. Island-local coordinates: centre at the
## origin, waterline at y = 0. Returns the ground model, where each piece of scenery stands
## (Blender models, art/blender/nature.py, drawn by World in batches) and the walkable
## collision triangles.

## Which model file each scenery piece comes from.
const PROP_FILES := {
	"palm_0": "palms", "palm_1": "palms", "palm_2": "palms",
	"rock_0": "rocks", "rock_1": "rocks", "rock_2": "rocks", "rock_3": "rocks",
	"bush_0": "bushes", "bush_1": "bushes", "bush_2": "bushes",
	"flowers_0": "flowers", "flowers_1": "flowers", "flowers_2": "flowers", "flowers_3": "flowers",
	"tuft_0": "tufts", "tuft_1": "tufts", "camp": "camp", "wreck": "wreck", "mast_log": "wreck",
	"starfish_0": "beach", "starfish_1": "beach", "shell_0": "beach", "shell_1": "beach",
	"pebbles_0": "beach", "driftwood_0": "beach",
}
## What washes up on the beaches, picked in turn.
const BEACH_BITS := ["shell_0", "pebbles_0", "starfish_0", "shell_1", "pebbles_0", "starfish_1", "shell_0", "driftwood_0"]
## On the outpost, keep scenery off the beach from the mystic round past the pier to the hut.
const OUTPOST_CLEAR := 0.1
const OUTPOST_CLEAR_HALF := 1.0
## Heights the three palm models are built to (art/blender/nature.py).
const PALM_HEIGHTS: Array[float] = [6.5, 8.0, 9.5]

const BEACH_SLOPE := 0.33
const SAND_TOP := 1.2
const SEA_FLOOR := -4.0
const GRASS_EDGE := Color("367a2c")
const GRASS_LIGHT := Color("5cad46")
const DRY_SAND := Color("eed59c")


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


## Scenery pieces placed while building: [model name, Transform3D]. Reset per build().
static var _props: Array = []


static func build(spec: Dictionary) -> Dictionary:
	var ground_b := MeshBuilder.new()
	var decor := MeshBuilder.new()
	var solid := MeshBuilder.new()
	_props = []
	_ground(ground_b, spec)
	var rng := RandomNumberGenerator.new()
	rng.seed = spec.seed
	_palms(decor, solid, spec, rng)
	_rocks(decor, solid, spec, rng)
	_bushes(decor, spec, rng)
	var fire: Variant = null
	if not spec.get("outpost", false):
		fire = _camp(decor, solid, spec, rng)
		if spec.radius > 24.0:
			_wreck(decor, solid, spec, rng)
	match spec.get("landmark", ""):
		"arch":
			_arch(decor, solid, spec, rng)
		"stacks":
			_stacks(decor, solid, spec, rng)
	_tufts(spec)
	_beach(spec)
	var faces := ground_b.faces()
	faces.append_array(solid.faces())
	return {"ground": ground_b.build(), "decor": decor.build(), "props": _props, "faces": faces, "fire": fire}


static func _prop(model: String, at: Transform3D) -> void:
	_props.append([model, at])


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

	var noise := FastNoiseLite.new()
	noise.seed = int(spec.seed)
	noise.frequency = 0.045
	noise.fractal_octaves = 2
	var color_at := func(p: Vector3) -> Color:
		if p.y < 0.25:
			return Toon.color("wet_sand")
		if is_grass(spec, p.x, p.z):
			# A darker rim where the lawn meets the sand, like an inked edge.
			if p.y < SAND_TOP + 0.3:
				return GRASS_EDGE
			# Patches in three greens, like brush strokes on a cartoon background.
			var patch := noise.get_noise_2d(p.x, p.z)
			if patch > 0.22:
				return Toon.color("grass_dark")
			if patch < -0.3:
				return GRASS_LIGHT
			return Toon.color("grass")
		# Sand drier and paler away from the water, with a few darker drifts.
		if p.y > SAND_TOP - 0.15:
			return DRY_SAND
		return Toon.color("sand").darkened(0.05) if noise.get_noise_2d(p.x * 2.0, p.z * 2.0) > 0.35 else Toon.color("sand")
	var normal_at := func(p: Vector3) -> Vector3:
		var e := 0.2
		var dx := (ground(spec, p.x + e, p.z) - ground(spec, p.x - e, p.z)) / (2.0 * e)
		var dz := (ground(spec, p.x, p.z + e) - ground(spec, p.x, p.z - e)) / (2.0 * e)
		return Vector3(-dx, 1.0, -dz).normalized()
	b.grid(rows, color_at, normal_at)


static func _palms(_decor: MeshBuilder, solid: MeshBuilder, spec: Dictionary, rng: RandomNumberGenerator) -> void:
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
		if spec.get("outpost", false) and absf(angle_difference(OUTPOST_CLEAR, a)) < OUTPOST_CLEAR_HALF:
			continue
		var height := rng.randf_range(6.0, 9.5)
		var turn := rng.randf() * TAU
		rng.randf_range(1.0, 2.6)
		var kind := 0 if height < 7.2 else (1 if height < 8.7 else 2)
		var grow := height / PALM_HEIGHTS[kind]
		_prop("palm_%d" % kind, Transform3D(Basis(Vector3.UP, turn).scaled(Vector3(grow, grow, grow)), Vector3(x, y - 0.2, z)))
		solid.box(Vector3(x, y + 1.0, z), Vector3(0.35, 1.2, 0.35), Color.BLACK)
		placed += 1


static func _rocks(_decor: MeshBuilder, solid: MeshBuilder, spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var radius: float = spec.radius
	for i in int(radius / 6.0) + 2:
		var a := rng.randf() * TAU
		var r := rng.randf_range(radius - 4.0, radius + 3.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var size := rng.randf_range(0.8, 2.2)
		var centre := Vector3(x, ground(spec, x, z) + size * 0.3, z)
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		_rock(solid, centre, size, spin)
		_rock_prop(centre, size, spin, i)


## An old wreck run aground on the beach: the bare ribs of a hull lying over on its side, a
## few planks still on, half sunk in the sand, with its snapped mast lying beside it.
static func _wreck(_b: MeshBuilder, solid: MeshBuilder, spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var radius: float = spec.radius
	var a := rng.randf() * TAU
	var r := radius - 4.0
	var at := Vector3(cos(a) * r, 0.0, sin(a) * r)
	at.y = ground(spec, at.x, at.z) - 0.6
	# Keel along the shore, heeled over toward the sea and bow-down into the sand.
	var frame := Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, 0.55) * Basis(Vector3.RIGHT, 0.12)
	var w := 3.3
	var h := 3.6
	_prop("wreck", Transform3D(frame, at))
	for i in 9:
		if rng.randf() < 0.5:
			rng.randi_range(4, 8)
	# The mast, snapped off and lying in the sand.
	var foot := at + frame * Vector3(0, 0.5, 1.4)
	var tip := foot + Basis(Vector3.UP, -a + 0.4) * Vector3(0, 0, 9.5)
	tip.y = ground(spec, tip.x, tip.z) + 0.25
	_prop("mast_log", Transform3D(Basis.looking_at(foot - tip), foot))
	solid.box(at + frame * Vector3(0, h * 0.35, 0), Vector3(w * 0.8, h * 0.4, 6.2), Color.BLACK, frame)


## A rock arch standing on the beach: two pillars of piled boulders joined by a curve of them.
static func _arch(_b: MeshBuilder, solid: MeshBuilder, spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var radius: float = spec.radius
	# Facing south-east, so ships coming from the outpost see through it.
	var a := 0.9
	var mid := Vector3(cos(a) * (radius - 1.0), 0.0, sin(a) * (radius - 1.0))
	var along := Vector3(-sin(a), 0.0, cos(a))
	var span := 4.2
	var height := 6.5
	for side: float in [-1.0, 1.0]:
		var foot := mid + along * span * side
		foot.y = ground(spec, foot.x, foot.z) - 0.4
		var y := 0.0
		while y < height:
			var size := rng.randf_range(1.25, 1.6)
			_rock_prop(foot + Vector3(rng.randf_range(-0.2, 0.2), y + size * 0.5, rng.randf_range(-0.2, 0.2)), size, Basis(Vector3.UP, rng.randf() * TAU), int(y * 3.0))
			y += size * 0.95
		solid.box(foot + Vector3(0, height * 0.5, 0), Vector3(1.3, height * 0.5, 1.3), Color.BLACK)
	var top := mid + Vector3(0, ground(spec, mid.x, mid.z) + height, 0)
	for k in 9:
		var t := PI * k / 8.0
		var p := top + along * (-cos(t) * span) + Vector3(0, sin(t) * 2.2, 0)
		_rock_prop(p, rng.randf_range(1.1, 1.4), Basis(Vector3.UP, rng.randf() * TAU), k)


## Tall rocks standing in the shallows, each topped with a tuft of grass.
static func _stacks(_b: MeshBuilder, solid: MeshBuilder, spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var radius: float = spec.radius
	var a0 := rng.randf() * TAU
	for i in 3:
		var a := a0 + i * 0.5 + rng.randf_range(-0.1, 0.1)
		var r := radius + 1.5 + rng.randf() * 1.0
		var foot := Vector3(cos(a) * r, SEA_FLOOR * 0.5, sin(a) * r)
		var height := rng.randf_range(7.0, 11.0) - i * 1.5
		var y := 0.0
		var size := 2.2
		while y < height - foot.y:
			_rock_prop(foot + Vector3(0, y, 0), size, Basis(Vector3.UP, rng.randf() * TAU), int(y))
			y += size * 0.9
			size = maxf(1.0, size * 0.88)
		_prop("bush_%d" % (i % 2), Transform3D(Basis.IDENTITY.scaled(Vector3(size, size * 0.6, size)), foot + Vector3(0, y - size * 0.5, 0)))
		solid.box(foot + Vector3(0, (y) * 0.5, 0), Vector3(1.6, y * 0.5, 1.6), Color.BLACK)


## Tufts of long grass over the grass, from their own random sequence (so adding them moved
## nothing else).
static func _tufts(spec: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.seed) * 31 + 7
	var radius: float = spec.radius
	for i in int(radius * 3.0):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (radius - 3.0)
		var x := cos(a) * r
		var z := sin(a) * r
		if not is_grass(spec, x, z):
			continue
		if spec.get("outpost", false) and absf(angle_difference(OUTPOST_CLEAR, a)) < OUTPOST_CLEAR_HALF:
			continue
		var grow := rng.randf_range(0.7, 1.4)
		_prop("tuft_%d" % (i % 2), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(grow, grow, grow)), Vector3(x, ground(spec, x, z) - 0.03, z)))


## Shells, starfish, pebbles and the odd bit of driftwood on the dry sand (their own random
## sequence too).
static func _beach(spec: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.seed) * 53 + 11
	var radius: float = spec.radius
	var placed := 0
	for i in int(radius * 2.5):
		var a := rng.randf() * TAU
		var r := rng.randf_range(radius - 9.0, radius + 1.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var y := ground(spec, x, z)
		if y < 0.35 or is_grass(spec, x, z):
			continue
		if spec.get("outpost", false) and absf(angle_difference(0.0, a)) < 0.25:
			continue
		var bit: String = BEACH_BITS[placed % BEACH_BITS.size()]
		placed += 1
		var grow := rng.randf_range(0.8, 1.3) if bit != "driftwood_0" else rng.randf_range(0.9, 1.6)
		_prop(bit, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(grow, grow, grow)), Vector3(x, y - 0.02, z)))


## A Blender rock standing where _rock's lump would be (its centre `centre`), half buried.
static func _rock_prop(centre: Vector3, size: float, spin: Basis, variant: int) -> void:
	var base := centre - Vector3(0, size * 0.75, 0)
	_prop("rock_%d" % (variant % 4), Transform3D(spin.scaled(Vector3(size, size, size)), base))


## A faceted lump: a coarse ellipsoid with flat faces (now only for collision).
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
static func _bushes(_b: MeshBuilder, spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var radius: float = spec.radius
	var flowers := [0, 1, 2, 3]
	for i in int(radius / 2.5):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.1, 0.85) * (radius - 4.0)
		var x := cos(a) * r
		var z := sin(a) * r
		if not is_grass(spec, x, z):
			continue
		if spec.get("outpost", false) and absf(angle_difference(OUTPOST_CLEAR, a)) < OUTPOST_CLEAR_HALF:
			continue
		var y := ground(spec, x, z)
		if i % 3 == 0:
			var colour := rng.randi() % flowers.size()
			for k in 5:
				rng.randf_range(-0.6, 0.6)
				rng.randf_range(-0.6, 0.6)
			_prop("flowers_%d" % colour, Transform3D(Basis(Vector3.UP, x * 7.0 + z), Vector3(x, y - 0.02, z)))
			continue
		var size := rng.randf_range(0.6, 1.1)
		for k in 3:
			rng.randf_range(-0.5, 0.5)
			rng.randf_range(-0.5, 0.5)
		var grow := size * 1.3
		_prop("bush_%d" % (i % 3), Transform3D(Basis(Vector3.UP, x * 3.0 - z).scaled(Vector3(grow, grow, grow)), Vector3(x, y - 0.1, z)))


## A skeleton camp: a tattered tent, a ring of stones round a fire (lit at night), and a few
## bones. Returns where the fire is, relative to the island's centre.
static func _camp(_b: MeshBuilder, solid: MeshBuilder, spec: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var radius: float = spec.radius
	var a := rng.randf() * TAU
	var r := 0.35 * radius
	var at := Vector3(cos(a) * r, 0, sin(a) * r)
	at.y = ground(spec, at.x, at.z)
	var turn := Basis(Vector3.UP, a + PI / 2.0)
	# The camp model: its fire at the origin, the tent 3 m out along its own x.
	_prop("camp", Transform3D(turn, at))
	var tent := at + turn * Vector3(3.0, 0, 0)
	solid.box(tent + Vector3(0, 0.9, 0), Vector3(0.9, 0.9, 0.9), Color.BLACK, turn)
	for k in 3:
		rng.randf_range(-2.5, 2.5)
		rng.randf_range(-2.5, 2.5)
		rng.randf()
	return at

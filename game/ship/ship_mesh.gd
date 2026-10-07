class_name ShipMesh
extends RefCounted
## Builds the galleon's model from code (see ShipShape for the layout). The hull and fittings
## are one static mesh; sails, wheel, capstan and flag are separate so ShipView can move them.

const SAIL_BELLY := 0.9
const SAIL_THICKNESS := 0.08

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


static func hull() -> ArrayMesh:
	var b := MeshBuilder.new()
	var zs := _hull_z_samples()
	for side: int in [-1, 1]:
		_hull_side(b, zs, side)
		_bulwark_inside(b, zs, side)
		_ladder(b, side)
		_cannon_ports(b, side)
	_ends_and_bottom(b, zs)
	_decks(b, zs)
	_stairs(b)
	_masts_and_rigging(b)
	_fittings(b)
	_hatch(b)
	_lower_deck(b)
	_cannon_carriages(b)
	_clutter(b)
	_bow_and_stern(b)
	return b.build()


static func _hull_z_samples() -> Array[float]:
	var zs: Array[float] = []
	var z := -ShipShape.HALF_LENGTH
	while z < ShipShape.HALF_LENGTH:
		zs.append(z)
		z += 0.5
	zs.append(ShipShape.HALF_LENGTH)
	var g := ShipShape.LADDER_GAP
	for cut: float in [
		ShipShape.LADDER_Z - g - 0.02, ShipShape.LADDER_Z - g + 0.02,
		ShipShape.LADDER_Z + g - 0.02, ShipShape.LADDER_Z + g + 0.02,
		ShipShape.QUARTER_Z - 0.02, ShipShape.QUARTER_Z + 0.02,
	]:
		zs.append(cut)
	zs.sort()
	return zs


static func _side_normal(p: Vector3, side: int) -> Vector3:
	var e := 0.01
	var dy := (ShipShape.half_width(p.z, p.y + e) - ShipShape.half_width(p.z, p.y - e)) / (2.0 * e)
	var dz := (ShipShape.half_width(p.z + e, p.y) - ShipShape.half_width(p.z - e, p.y)) / (2.0 * e)
	return Vector3(side, -dy, -dz).normalized()


## The outside of one side, in colour bands: red bottom paint, wood, a gold stripe,
## darker wood, then the bulwark up to the rail.
static func _hull_side(b: MeshBuilder, zs: Array[float], side: int) -> void:
	var bands := [
		[ShipShape.KEEL_Y, 0.15, "bottom", 3],
		[0.15, 2.15, "hull", 4],
		[2.15, 2.5, "stripe", 1],
		[2.5, ShipShape.DECK_Y, "hull_dark", 1],
		[ShipShape.DECK_Y, -1.0, "rail", 2],  # -1: up to the rail top, which varies along z
	]
	for band in bands:
		var rows := []
		for z in zs:
			var top: float = ShipShape.rail_top(z) if band[2] == "rail" else band[1]
			var row := PackedVector3Array()
			for k in band[3] + 1:
				var y: float = lerpf(band[0], top, float(k) / band[3])
				row.append(Vector3(side * ShipShape.half_width(z, y), y, z))
			rows.append(row)
		var c := _c(band[2])
		# Planking: every other strake a shade darker.
		var plank := func(p: Vector3) -> Color:
			return c if int(floor((p.y + 3.0) / 0.42)) % 2 == 0 else c.darkened(0.07)
		b.grid(rows, plank, func(p: Vector3) -> Vector3: return _side_normal(p, side))


## Inner face and top cap of the bulwark.
static func _bulwark_inside(b: MeshBuilder, zs: Array[float], side: int) -> void:
	var t := ShipShape.RAIL_THICKNESS
	var rail := _c("rail")
	var cap := _c("hull_dark")
	for i in zs.size() - 1:
		var z0 := zs[i]
		var z1 := zs[i + 1]
		var w0 := ShipShape.half_width(z0, ShipShape.DECK_Y)
		var w1 := ShipShape.half_width(z1, ShipShape.DECK_Y)
		var top0 := ShipShape.rail_top(z0)
		var top1 := ShipShape.rail_top(z1)
		var floor0 := ShipShape.QUARTER_Y if z0 >= ShipShape.QUARTER_Z else ShipShape.DECK_Y
		var inner0 := Vector3(side * (w0 - t), 0, z0)
		var inner1 := Vector3(side * (w1 - t), 0, z1)
		b.quad(
			inner0 + Vector3.UP * floor0, inner1 + Vector3.UP * floor0,
			inner1 + Vector3.UP * top1, inner0 + Vector3.UP * top0, rail, Vector3(-side, 0, 0),
		)
		b.quad(
			inner0 + Vector3.UP * top0, inner1 + Vector3.UP * top1,
			Vector3(side * w1, top1, z1), Vector3(side * w0, top0, z0), cap, Vector3.UP,
		)


static func _ends_and_bottom(b: MeshBuilder, zs: Array[float]) -> void:
	var keel := ShipShape.KEEL_Y
	for i in zs.size() - 1:
		var w0 := ShipShape.half_width(zs[i], keel)
		var w1 := ShipShape.half_width(zs[i + 1], keel)
		b.quad(
			Vector3(-w0, keel, zs[i]), Vector3(w0, keel, zs[i]), Vector3(w1, keel, zs[i + 1]),
			Vector3(-w1, keel, zs[i + 1]), _c("bottom"), Vector3.DOWN,
		)
	# Close the narrow bow and the square transom with strips across the hull.
	for end in [[-ShipShape.HALF_LENGTH, Vector3.FORWARD], [ShipShape.HALF_LENGTH, Vector3.BACK]]:
		var z: float = end[0]
		var top := ShipShape.rail_top(z)
		var ys: Array[float] = [keel, 0.15, 1.0, 2.15, 2.5, ShipShape.DECK_Y, top]
		for k in ys.size() - 1:
			var y0 := ys[k]
			var y1 := ys[k + 1]
			var w0 := ShipShape.half_width(z, y0)
			var w1 := ShipShape.half_width(z, y1)
			var band_name := "bottom" if y1 <= 0.15 else ("stripe" if y0 == 2.15 else "hull_dark")
			b.quad(
				Vector3(-w0, y0, z), Vector3(w0, y0, z), Vector3(w1, y1, z), Vector3(-w1, y1, z),
				_c(band_name), end[1],
			)
	# Stern windows: dark panes with a gold frame across the transom.
	for x: float in [-1.8, -0.6, 0.6, 1.8]:
		b.box(Vector3(x, ShipShape.DECK_Y + 0.9, ShipShape.HALF_LENGTH + 0.04), Vector3(0.42, 0.42, 0.04), _c("gold"))
		b.box(Vector3(x, ShipShape.DECK_Y + 0.9, ShipShape.HALF_LENGTH + 0.07), Vector3(0.3, 0.3, 0.04), _c("trim"))


static func _decks(b: MeshBuilder, zs: Array[float]) -> void:
	var t := ShipShape.RAIL_THICKNESS
	# Straight planks of equal width running bow to stern, trimmed where the hull narrows.
	var plank := 0.55
	var count := int(ceil(ShipShape.BEAM / plank))
	for i in zs.size() - 1:
		var z0 := zs[i]
		var z1 := zs[i + 1]
		var y := ShipShape.QUARTER_Y if z0 >= ShipShape.QUARTER_Z else ShipShape.DECK_Y
		var w0 := ShipShape.half_width(z0, ShipShape.DECK_Y) - t
		var w1 := ShipShape.half_width(z1, ShipShape.DECK_Y) - t
		for p in count:
			var x0 := -count * plank * 0.5 + p * plank
			var x1 := x0 + plank
			var a0 := clampf(x0, -w0, w0)
			var b0 := clampf(x1, -w0, w0)
			var a1 := clampf(x0, -w1, w1)
			var b1 := clampf(x1, -w1, w1)
			if b0 - a0 < 1e-3 and b1 - a1 < 1e-3:
				continue
			var in_hatch := z0 >= ShipShape.HATCH_Z0 - 1e-3 and z1 <= ShipShape.HATCH_Z1 + 1e-3 \
				and x0 >= -ShipShape.HATCH_X - 1e-3 and x1 <= ShipShape.HATCH_X + 1e-3
			if in_hatch:
				continue
			var c := _c("deck") if p % 2 == 0 else _c("deck").darkened(0.07)
			b.quad(Vector3(a0, y, z0), Vector3(b0, y, z0), Vector3(b1, y, z1), Vector3(a1, y, z1), c, Vector3.UP)
	# Front face of the quarterdeck, with a gold trim along its edge.
	var qz := ShipShape.QUARTER_Z
	var wq := ShipShape.half_width(qz, ShipShape.DECK_Y) - t
	b.quad(
		Vector3(-wq, ShipShape.DECK_Y, qz), Vector3(wq, ShipShape.DECK_Y, qz),
		Vector3(wq, ShipShape.QUARTER_Y, qz), Vector3(-wq, ShipShape.QUARTER_Y, qz),
		_c("hull_dark"), Vector3.FORWARD,
	)
	b.box(Vector3(0, ShipShape.QUARTER_Y - 0.08, qz - 0.06), Vector3(wq, 0.08, 0.08), _c("stripe"))
	# A rail along the quarterdeck front, open at the stairs.
	var s := ShipShape.STAIR_HALF_WIDTH
	for side: int in [-1, 1]:
		var mid := side * (s + wq) * 0.5
		b.box(Vector3(mid, ShipShape.QUARTER_Y + 0.85, qz + 0.05), Vector3((wq - s) * 0.5, 0.06, 0.06), _c("rail"))
		for x: float in [s + 0.1, (s + wq) * 0.5, wq - 0.1]:
			b.box(Vector3(side * x, ShipShape.QUARTER_Y + 0.42, qz + 0.05), Vector3(0.05, 0.42, 0.05), _c("rail"))


static func _stairs(b: MeshBuilder) -> void:
	var n := 6
	var rise := (ShipShape.QUARTER_Y - ShipShape.DECK_Y) / n
	var run := (ShipShape.QUARTER_Z - ShipShape.STAIR_BOTTOM_Z) / n
	for i in n:
		var top := ShipShape.DECK_Y + rise * (i + 1)
		var z := ShipShape.STAIR_BOTTOM_Z + run * (i + 0.5)
		var c := _c("deck") if i % 2 == 0 else _c("deck").darkened(0.08)
		b.box(
			Vector3(0, (ShipShape.DECK_Y + top) * 0.5, z),
			Vector3(ShipShape.STAIR_HALF_WIDTH, (top - ShipShape.DECK_Y) * 0.5, run * 0.5), c,
		)


static func _masts_and_rigging(b: MeshBuilder) -> void:
	var deck := ShipShape.DECK_Y
	var rope := _c("rope")
	var tops: Array[Vector3] = []
	for m in ShipShape.MAST_Z.size():
		var z: float = ShipShape.MAST_Z[m]
		var h: float = ShipShape.MAST_HEIGHT[m]
		b.cylinder(Vector3(0, ShipShape.LOWER_Y, z), Vector3(0, deck + h, z), ShipShape.MAST_RADIUS, 0.2, 10, _c("mast"))
		b.cylinder(Vector3(0, deck + h, z), Vector3(0, deck + h + 0.3, z), 0.3, 0.3, 10, _c("hull_dark"))
		tops.append(Vector3(0, deck + h, z))
		# Shrouds: three ropes each side from high on the mast down to the rail.
		for side: int in [-1, 1]:
			for dz: float in [-0.9, 0.0, 0.9]:
				var foot := Vector3(side * (ShipShape.half_width(z + dz, deck) - 0.05), ShipShape.rail_top(z + dz), z + dz)
				b.cylinder(foot, Vector3(0, deck + 0.62 * h, z), 0.03, 0.03, 4, rope, false)
	# Crow's nest on the main mast.
	var nest := Vector3(0, deck + 0.72 * ShipShape.MAST_HEIGHT[1], ShipShape.MAST_Z[1])
	b.cylinder(nest, nest + Vector3(0, 0.9, 0), 1.1, 1.2, 14, _c("hull_dark"))
	b.cylinder(nest + Vector3(0, 0.9, 0), nest + Vector3(0, 1.0, 0), 1.25, 1.25, 14, _c("stripe"))
	# Bowsprit and the stays from the mast tops.
	var sprit_root := Vector3(0, deck + 0.6, -12.2)
	var sprit_tip := Vector3(0, deck + 3.8, -19.5)
	b.cylinder(sprit_root, sprit_tip, 0.26, 0.12, 8, _c("mast"))
	b.cylinder(tops[0], sprit_tip, 0.03, 0.03, 4, rope, false)
	b.cylinder(tops[1], tops[0], 0.03, 0.03, 4, rope, false)
	b.cylinder(tops[1], Vector3(0, ShipShape.QUARTER_Y + 1.0, ShipShape.STERN_Z), 0.03, 0.03, 4, rope, false)


static func _fittings(b: MeshBuilder) -> void:
	for m in ShipShape.MAST_Z.size():
		var post := ShipShape.sail_post(m)
		b.cylinder(post, post + Vector3(0, 1.3, 0), 0.14, 0.12, 8, _c("hull_dark"))
		b.box(post + Vector3(0, 0.9, 0), Vector3(0.32, 0.05, 0.06), _c("rope"))
		b.box(post + Vector3(0, 1.1, 0), Vector3(0.32, 0.05, 0.06), _c("rope"))
	var w := ShipShape.WHEEL
	b.box(w + Vector3(0, 0.6, 0), Vector3(0.25, 0.6, 0.22), _c("hull_dark"))
	# The map table: a top on four legs with a chart and a red X on it.
	var t := ShipShape.MAP_TABLE
	b.box(t + Vector3(0, 0.88, 0), Vector3(0.6, 0.05, 0.4), _c("mast"))
	for lx: float in [-0.5, 0.5]:
		for lz: float in [-0.3, 0.3]:
			b.box(t + Vector3(lx, 0.42, lz), Vector3(0.05, 0.42, 0.05), _c("hull_dark"))
	b.box(t + Vector3(0, 0.94, 0), Vector3(0.42, 0.012, 0.3), Color("f2e2b8"), Basis(Vector3.UP, 0.15))
	for a: float in [0.7, -0.7]:
		b.box(t + Vector3(0.12, 0.955, 0.05), Vector3(0.09, 0.006, 0.018), Color("c8302a"), Basis(Vector3.UP, a))
	var lamp := Vector3(0, ShipShape.QUARTER_Y + ShipShape.RAIL_HEIGHT, ShipShape.STERN_Z + 0.2)
	b.cylinder(lamp, lamp + Vector3(0, 0.9, 0), 0.06, 0.06, 6, _c("trim"))
	b.box(lamp + Vector3(0, 1.1, 0), Vector3(0.22, 0.05, 0.22), _c("trim"))


static func _ladder(b: MeshBuilder, side: int) -> void:
	var z := ShipShape.LADDER_Z
	var rail := _c("hull_dark")
	var y := -0.8
	var prev := {}
	while y <= ShipShape.DECK_Y + 0.15:
		for dz: float in [-0.38, 0.38]:
			var p := Vector3(side * (ShipShape.half_width(z + dz, y) + 0.12), y, z + dz)
			if prev.has(dz):
				b.cylinder(prev[dz], p, 0.05, 0.05, 5, rail, false)
			prev[dz] = p
		var rung_x := side * (ShipShape.half_width(z, y) + 0.12)
		b.box(Vector3(rung_x, y, z), Vector3(0.05, 0.04, 0.4), _c("rope"))
		y += 0.35


static func _cannon_ports(b: MeshBuilder, side: int) -> void:
	for z: float in [-8.6, -5.6, 0.4, 3.4, 6.6, 9.6]:
		var x := side * (ShipShape.half_width(z, 1.6) + 0.02)
		b.box(Vector3(x, 1.6, z), Vector3(0.06, 0.34, 0.42), _c("stripe"))
		b.box(Vector3(x + side * 0.03, 1.6, z), Vector3(0.05, 0.26, 0.33), _c("trim"))


## One sail as a thin closed slab (so the outline works from both sides), hanging down from
## its yard at local y = 0, bellied toward the bow.
static func sail(width: float, height: float) -> ArrayMesh:
	var b := MeshBuilder.new()
	var cols := 12
	var rows := 8
	var front := []
	var back := []
	for r in rows + 1:
		var v := float(r) / rows
		var f_row := PackedVector3Array()
		var b_row := PackedVector3Array()
		for c in cols + 1:
			var u := float(c) / cols
			var belly := SAIL_BELLY * sin(PI * u) * (0.45 + 0.55 * sin(PI * clampf(v * 1.1, 0.0, 1.0)))
			var p := Vector3((u - 0.5) * width, -v * height, -belly)
			f_row.append(p + Vector3(0, 0, -SAIL_THICKNESS * 0.5))
			b_row.append(p + Vector3(0, 0, SAIL_THICKNESS * 0.5))
		front.append(f_row)
		back.append(b_row)
	var cream := _c("sail")
	var tattered: bool = _pal.get("tattered", false)
	# Cloth in vertical panels, every other one a shade darker; skeleton sails are torn,
	# shown as dark ragged patches.
	var shade := func(p: Vector3) -> Color:
		var u := p.x / width + 0.5
		var v := -p.y / height
		if tattered and sin(u * 9.0 + v * 4.0 + 1.3) * sin(v * 7.5 - u * 3.0) > 0.62:
			return Color("1c1a18")
		return cream if int(floor(u * 7.0)) % 2 == 0 else cream.darkened(0.06)
	var n_front := func(p: Vector3) -> Vector3: return _sail_normal(p, width, height, -1.0)
	var n_back := func(p: Vector3) -> Vector3: return _sail_normal(p, width, height, 1.0)
	b.grid(front, shade, n_front)
	b.grid(back, shade, n_back)
	# Edges joining the two faces.
	for r in rows:
		for edge: int in [0, cols]:
			b.quad(front[r][edge], front[r + 1][edge], back[r + 1][edge], back[r][edge], cream, Vector3(signf(edge - 0.5), 0, 0))
	for c in cols:
		for edge: int in [0, rows]:
			b.quad(front[edge][c], front[edge][c + 1], back[edge][c + 1], back[edge][c], cream, Vector3(0, 1.0 if edge == 0 else -1.0, 0))
	return b.build()


static func _sail_normal(p: Vector3, width: float, height: float, facing: float) -> Vector3:
	var u := clampf(p.x / width + 0.5, 0.0, 1.0)
	# The belly curves across the sail, tipping the normal sideways near the edges.
	# `facing` is -1 for the bow-side face and +1 for the stern-side face.
	var dzdx := -SAIL_BELLY * PI / width * cos(PI * u)
	return Vector3(-dzdx * facing, 0.0, facing).normalized()


static func yard(width: float) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.cylinder(Vector3(-width * 0.5 - 0.4, 0, 0), Vector3(width * 0.5 + 0.4, 0, 0), 0.16, 0.16, 8, _c("mast"))
	return b.build()


## The ship's wheel in its own frame: axle along z, centre at the origin.
static func wheel() -> ArrayMesh:
	var b := MeshBuilder.new()
	var wood := _c("mast")
	var segments := 16
	var r := 0.5
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		b.cylinder(Vector3(cos(a0) * r, sin(a0) * r, 0), Vector3(cos(a1) * r, sin(a1) * r, 0), 0.045, 0.045, 6, wood, false)
	for i in 8:
		var a := TAU * i / 8
		var dir := Vector3(cos(a), sin(a), 0)
		b.cylinder(Vector3.ZERO, dir * (r + 0.12), 0.035, 0.035, 5, wood, false)
		b.cylinder(dir * (r + 0.05), dir * (r + 0.2), 0.045, 0.04, 6, _c("hull_dark"))
	b.cylinder(Vector3(0, 0, -0.1), Vector3(0, 0, 0.1), 0.09, 0.09, 10, _c("hull_dark"))
	b.cylinder(Vector3(0, 0, 0.1), Vector3(0, 0, 0.13), 0.06, 0.06, 10, _c("stripe"))
	return b.build()


## The anchor capstan: a drum with four bars, turning about its own y axis.
static func capstan() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.cylinder(Vector3.ZERO, Vector3(0, 0.75, 0), 0.5, 0.42, 14, _c("hull_dark"))
	b.cylinder(Vector3(0, 0.75, 0), Vector3(0, 0.95, 0), 0.62, 0.62, 14, _c("mast"))
	for i in 4:
		var a := TAU * i / 4
		b.box(Vector3(cos(a) * 0.95, 0.85, sin(a) * 0.95), Vector3(0.5, 0.05, 0.05), _c("mast"), Basis(Vector3.UP, -a))
	return b.build()


## A black flag with a skull and crossed bones, flying toward +x from its pole.
static func flag() -> ArrayMesh:
	var b := MeshBuilder.new()
	# A thin slab cut into strips so the cloth shader has vertices to ripple.
	var cols := 12
	var rows := 3
	var w := 2.4
	var h := 0.75
	var t := 0.03
	var cloth := _c("flag")
	for i in cols:
		var x0 := w * i / cols
		var x1 := w * (i + 1) / cols
		for j in rows:
			var y0 := -h + 2.0 * h * j / rows
			var y1 := -h + 2.0 * h * (j + 1) / rows
			for side: float in [-1.0, 1.0]:
				var z := side * t
				b.quad(Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), cloth, Vector3(0, 0, side))
		for edge: float in [-1.0, 1.0]:
			var y := edge * h
			b.quad(Vector3(x0, y, -t), Vector3(x1, y, -t), Vector3(x1, y, t), Vector3(x0, y, t), cloth, Vector3(0, edge, 0))
	for end: float in [0.0, 1.0]:
		var x := end * w
		b.quad(Vector3(x, -h, -t), Vector3(x, h, -t), Vector3(x, h, t), Vector3(x, -h, t), cloth, Vector3(end * 2.0 - 1.0, 0, 0))
	for z: float in [-0.05, 0.05]:
		var face := Vector3(1.2, 0.08, z)
		b.ellipsoid(face, 0.3, Vector3(1.0, 1.0, 0.15), 6, 10, _c("bone"))
		for a: float in [0.7, -0.7]:
			b.box(face + Vector3(0, -0.38, 0), Vector3(0.45, 0.05, 0.03), _c("bone"), Basis(Vector3.BACK, a))
	return b.build()


static func _hatch(b: MeshBuilder) -> void:
	var x := ShipShape.HATCH_X
	var z0 := ShipShape.HATCH_Z0
	var z1 := ShipShape.HATCH_Z1
	var y := ShipShape.DECK_Y + ShipShape.COAMING * 0.5
	var rim := _c("hull_dark")
	var t := 0.08
	b.box(Vector3(-x - t, y, (z0 + z1) * 0.5), Vector3(t, ShipShape.COAMING * 0.5, (z1 - z0) * 0.5 + 2.0 * t), rim)
	b.box(Vector3(x + t, y, (z0 + z1) * 0.5), Vector3(t, ShipShape.COAMING * 0.5, (z1 - z0) * 0.5 + 2.0 * t), rim)
	b.box(Vector3(0, y, z0 - t), Vector3(x, ShipShape.COAMING * 0.5, t), rim)
	b.box(Vector3(0, y, z1 + t), Vector3(x, ShipShape.COAMING * 0.5, t), rim)
	# The ladder down, against the aft edge of the opening.
	var lz := z1 - 0.12
	for lx: float in [-0.32, 0.32]:
		b.cylinder(Vector3(lx, ShipShape.LOWER_Y, lz), Vector3(lx, ShipShape.DECK_Y + 0.3, lz), 0.05, 0.05, 5, _c("mast"), false)
	var ry := ShipShape.LOWER_Y + 0.3
	while ry < ShipShape.DECK_Y:
		b.box(Vector3(0, ry, lz), Vector3(0.32, 0.035, 0.035), _c("rope"))
		ry += 0.35


## The lower deck seen from inside: plank floor, plank walls, the underside of the main deck,
## beams, and a few barrels and crates at the bow end.
static func _lower_deck(b: MeshBuilder) -> void:
	var floor_y := ShipShape.LOWER_Y
	var top := ShipShape.DECK_Y
	var wood := _c("deck").darkened(0.45)
	var wall := _c("hull_dark").darkened(0.15)
	var z := ShipShape.LOWER_Z0
	var step := 0.5
	while z < ShipShape.LOWER_Z1 - 1e-3:
		var z1 := minf(z + step, ShipShape.LOWER_Z1)
		var w0 := ShipShape.lower_wall_x(z)
		var w1 := ShipShape.lower_wall_x(z1)
		var planks := 8
		for p in planks:
			var u0 := -1.0 + 2.0 * p / planks
			var u1 := -1.0 + 2.0 * (p + 1) / planks
			var c := wood if p % 2 == 0 else wood.darkened(0.08)
			b.quad(Vector3(u0 * w0, floor_y, z), Vector3(u1 * w0, floor_y, z), Vector3(u1 * w1, floor_y, z1), Vector3(u0 * w1, floor_y, z1), c, Vector3.UP)
		# Underside of the main deck (left open over the hatch).
		var over_hatch := z >= ShipShape.HATCH_Z0 - 1e-3 and z1 <= ShipShape.HATCH_Z1 + 1e-3
		var cw0 := ShipShape.half_width(z, top) - ShipShape.RAIL_THICKNESS
		var cw1 := ShipShape.half_width(z1, top) - ShipShape.RAIL_THICKNESS
		if over_hatch:
			for side: int in [-1, 1]:
				b.quad(Vector3(side * ShipShape.HATCH_X, top - 0.02, z), Vector3(side * cw0, top - 0.02, z), Vector3(side * cw1, top - 0.02, z1), Vector3(side * ShipShape.HATCH_X, top - 0.02, z1), wood.darkened(0.15), Vector3.DOWN)
		else:
			b.quad(Vector3(-cw0, top - 0.02, z), Vector3(cw0, top - 0.02, z), Vector3(cw1, top - 0.02, z1), Vector3(-cw1, top - 0.02, z1), wood.darkened(0.15), Vector3.DOWN)
		# Walls in horizontal planks, facing in.
		var bands := 6
		for side: int in [-1, 1]:
			for k in bands:
				var y0 := lerpf(floor_y, top, float(k) / bands)
				var y1 := lerpf(floor_y, top, float(k + 1) / bands)
				var c := wall if k % 2 == 0 else wall.darkened(0.1)
				b.quad(Vector3(side * w0, y0, z), Vector3(side * w1, y0, z1), Vector3(side * w1, y1, z1), Vector3(side * w0, y1, z), c, Vector3(-side, 0, 0))
		z = z1
	for end: float in [ShipShape.LOWER_Z0, ShipShape.LOWER_Z1]:
		var w := ShipShape.lower_wall_x(end)
		var inward := Vector3.BACK if end < 0.0 else Vector3.FORWARD
		b.quad(Vector3(-w, floor_y, end), Vector3(w, floor_y, end), Vector3(w, top, end), Vector3(-w, top, end), wall.darkened(0.1), inward)
	# Beams under the deck.
	var bz := ShipShape.LOWER_Z0 + 1.0
	while bz < ShipShape.LOWER_Z1:
		if bz < ShipShape.HATCH_Z0 - 0.3 or bz > ShipShape.HATCH_Z1 + 0.3:
			var w := ShipShape.half_width(bz, top) - ShipShape.RAIL_THICKNESS
			b.box(Vector3(0, top - 0.17, bz), Vector3(w, 0.15, 0.13), _c("mast").darkened(0.15))
		bz += 2.0
	# Frames standing against the walls every so often, so the hold reads as a hull.
	var fz := ShipShape.LOWER_Z0 + 0.8
	while fz < ShipShape.LOWER_Z1 - 0.3:
		var fw := ShipShape.lower_wall_x(fz)
		for side: int in [-1, 1]:
			b.box(Vector3(side * (fw - 0.06), (floor_y + top) * 0.5 - 0.1, fz), Vector3(0.07, (top - floor_y) * 0.5 - 0.1, 0.09), _c("hull_dark").darkened(0.35))
		fz += 1.6
	# Crew hammocks slung high along the walls, clear of anyone walking beneath.
	for hammock: Array in [[-1, -6.4], [1, -6.0], [-1, -3.4]]:
		_hammock(b, int(hammock[0]), float(hammock[1]), floor_y + 2.35)
	# Stores at the bow end.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for spot: Vector3 in [Vector3(-0.75, 0, -8.3), Vector3(0.05, 0, -8.6), Vector3(0.8, 0, -8.1), Vector3(-0.9, 0, -7.3)]:
		var base := Vector3(spot.x, floor_y, spot.z)
		b.cylinder(base, base + Vector3(0, 0.9, 0), 0.34, 0.38, 10, _c("trunk"))
		b.cylinder(base + Vector3(0, 0.25, 0), base + Vector3(0, 0.33, 0), 0.39, 0.39, 10, _c("trim"))
		b.cylinder(base + Vector3(0, 0.62, 0), base + Vector3(0, 0.7, 0), 0.39, 0.39, 10, _c("trim"))
	# The banana barrel: an open barrel heaped with yellow bunches.
	var bb := ShipShape.BANANA_BARREL
	b.cylinder(bb, bb + Vector3(0, 0.8, 0), 0.4, 0.44, 10, _c("trunk"))
	b.cylinder(bb + Vector3(0, 0.2, 0), bb + Vector3(0, 0.27, 0), 0.45, 0.45, 10, _c("trim"))
	for k in 5:
		var a := TAU * k / 5.0
		b.ellipsoid(bb + Vector3(cos(a) * 0.18, 0.86, sin(a) * 0.18), 0.17, Vector3(1.4, 0.6, 0.6), 4, 7, Color("ffd84a"))
	b.box(Vector3(-1.1, floor_y + 0.3, 4.9), Vector3(0.35, 0.3, 0.35), _c("deck").darkened(0.2), Basis(Vector3.UP, -0.2))


## A canvas hammock along the wall on `side`, from `z0` toward the stern, its top edge at `y`,
## hanging from ropes tied up to the frames.
static func _hammock(b: MeshBuilder, side: int, z0: float, y: float) -> void:
	var length := 1.9
	var cloth := Color("e9dcc0")
	var steps := 8
	var x_out := side * (ShipShape.lower_wall_x(z0) - 0.25)
	var x_in := side * (ShipShape.lower_wall_x(z0) - 1.0)
	var sag := 0.35
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var za := z0 + t0 * length
		var zb := z0 + t1 * length
		var ya := y - sag * sin(t0 * PI)
		var yb := y - sag * sin(t1 * PI)
		# The cloth dips in the middle across its width as well as along it.
		var dip := 0.12
		for half: Array in [[x_out, (x_out + x_in) * 0.5], [(x_out + x_in) * 0.5, x_in]]:
			var xa: float = half[0]
			var xb: float = half[1]
			var da := dip if xa != x_out and xa != x_in else 0.0
			var db := dip if xb != x_out and xb != x_in else 0.0
			b.quad(Vector3(xa, ya - da, za), Vector3(xb, ya - db, za), Vector3(xb, yb - db, zb), Vector3(xa, yb - da, zb), cloth, Vector3.UP)
			b.quad(Vector3(xa, ya - da - 0.02, za), Vector3(xa, yb - da - 0.02, zb), Vector3(xb, yb - db - 0.02, zb), Vector3(xb, ya - db - 0.02, za), cloth.darkened(0.15), Vector3.DOWN)
	for end: float in [z0, z0 + length]:
		var tie := Vector3((x_out + x_in) * 0.5, y, end)
		b.cylinder(tie, tie + Vector3(side * 0.3, 0.45, (end - z0 - length * 0.5) * 0.25), 0.02, 0.02, 4, _c("rope"))


## The fixed part of each deck cannon: a wooden carriage on four little wheels.
static func _cannon_carriages(b: MeshBuilder) -> void:
	for gun in ShipShape.cannon_count():
		var side := ShipShape.cannon_side(gun)
		var pivot := ShipShape.cannon_pivot_of(gun)
		var deck := ShipShape.DECK_Y
		b.box(Vector3(pivot.x - side * 0.05, deck + 0.5, pivot.z), Vector3(0.55, 0.28, 0.36), _c("hull_dark"))
		b.box(Vector3(pivot.x - side * 0.05, pivot.y - 0.2, pivot.z), Vector3(0.2, 0.22, 0.4), _c("hull_dark"))
		for dx: float in [-0.38, 0.38]:
			for dz: float in [-0.4, 0.4]:
				var c := Vector3(pivot.x + dx, deck + 0.22, pivot.z + dz)
				b.cylinder(c - Vector3(0, 0, 0.06 * signf(dz)), c + Vector3(0, 0, 0.06 * signf(dz)), 0.22, 0.22, 10, _c("trim"))


## A cannon barrel along -Z from its trunnions (origin), muzzle at -BARREL_LENGTH.
static func barrel() -> ArrayMesh:
	var b := MeshBuilder.new()
	var iron := _c("iron")
	b.cylinder(Vector3(0, 0, 0.55), Vector3(0, 0, -ShipShape.BARREL_LENGTH), 0.25, 0.17, 12, iron)
	b.cylinder(Vector3(0, 0, -ShipShape.BARREL_LENGTH + 0.12), Vector3(0, 0, -ShipShape.BARREL_LENGTH), 0.22, 0.22, 12, iron.lightened(0.1))
	b.ellipsoid(Vector3(0, 0, 0.62), 0.14, Vector3.ONE, 5, 8, iron)
	b.cylinder(Vector3(-0.32, 0, 0), Vector3(0.32, 0, 0), 0.08, 0.08, 6, iron)
	return b.build()


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



## Barrels, crates and coils of rope stowed along the main deck.
static func _clutter(b: MeshBuilder) -> void:
	for c in ShipShape.CLUTTER:
		var centre: Vector3 = c[0]
		var half: Vector3 = c[1]
		match c[2]:
			"barrel":
				var foot := centre - Vector3(0, half.y, 0)
				b.cylinder(foot, foot + Vector3(0, half.y, 0), half.x * 0.9, half.x, 10, _c("trunk"))
				b.cylinder(foot + Vector3(0, half.y, 0), foot + Vector3(0, half.y * 2.0, 0), half.x, half.x * 0.9, 10, _c("trunk"))
				for h: float in [0.25, 0.75]:
					b.cylinder(foot + Vector3(0, half.y * 2.0 * h, 0), foot + Vector3(0, half.y * 2.0 * h + 0.06, 0), half.x + 0.01, half.x + 0.01, 10, _c("trim"))
			"crate":
				b.box(centre, half, _c("deck").darkened(0.1))
				for s: float in [-1.0, 1.0]:
					b.box(centre + Vector3(0, 0, s * (half.z + 0.005)), Vector3(half.x * 0.95, 0.04, 0.01), _c("hull_dark"), Basis(Vector3.BACK, 0.7))
			"rope":
				for k in 3:
					var r := half.x - k * 0.12
					b.cylinder(centre + Vector3(0, -0.08 + k * 0.06, 0), centre + Vector3(0, -0.02 + k * 0.06, 0), r, r, 14, _c("rope").darkened(0.05 * k), true)


## A golden figurehead under the bowsprit, an anchor hung at the bow, and a name board on
## the stern.
static func _bow_and_stern(b: MeshBuilder) -> void:
	var gold := _c("gold")
	var head := Vector3(0, ShipShape.DECK_Y - 0.1, -13.15)
	b.ellipsoid(head, 0.45, Vector3(0.5, 1.4, 0.6), 6, 8, gold)
	b.ellipsoid(head + Vector3(0, 0.75, -0.3), 0.26, Vector3.ONE, 6, 8, gold)
	for side: float in [-1.0, 1.0]:
		b.box(head + Vector3(side * 0.3, 0.35, 0.15), Vector3(0.05, 0.4, 0.35), gold, Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.BACK, side * 0.4))
	# Anchor on the starboard bow: shank, stock, curved arms and a ring.
	var iron := _c("iron")
	var top := Vector3(ShipShape.half_width(-10.5, 2.0) + 0.15, 2.4, -10.5)
	b.cylinder(top, top + Vector3(0, -1.6, 0), 0.07, 0.07, 6, iron)
	b.box(top + Vector3(0, -0.1, 0), Vector3(0.05, 0.05, 0.45), iron)
	b.cylinder(top + Vector3(0, 0.15, 0), top + Vector3(0, 0.22, 0), 0.14, 0.14, 8, iron)
	for s: float in [-1.0, 1.0]:
		b.box(top + Vector3(0, -1.45, s * 0.3), Vector3(0.05, 0.05, 0.32), iron, Basis(Vector3.RIGHT, s * 0.6))
		b.box(top + Vector3(0, -1.2, s * 0.55), Vector3(0.06, 0.12, 0.08), iron)
	# Name board under the stern windows; ShipView letters the name on it.
	b.box(name_board(), Vector3(1.8, 0.25, 0.03), _c("hull_dark"))


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

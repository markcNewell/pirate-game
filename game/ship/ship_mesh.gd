class_name ShipMesh
extends RefCounted
## Builds the galleon's model from code (see ShipShape for the layout). The hull and fittings
## are one static mesh; sails, wheel, capstan and flag are separate so ShipView can move them.

const SAIL_BELLY := 0.9
const SAIL_THICKNESS := 0.08


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
		var c := Toon.color(band[2])
		b.grid(rows, func(_p: Vector3) -> Color: return c, func(p: Vector3) -> Vector3: return _side_normal(p, side))


## Inner face and top cap of the bulwark.
static func _bulwark_inside(b: MeshBuilder, zs: Array[float], side: int) -> void:
	var t := ShipShape.RAIL_THICKNESS
	var rail := Toon.color("rail")
	var cap := Toon.color("hull_dark")
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
			Vector3(-w1, keel, zs[i + 1]), Toon.color("bottom"), Vector3.DOWN,
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
				Toon.color(band_name), end[1],
			)
	# Stern windows: dark panes with a gold frame across the transom.
	for x: float in [-1.8, -0.6, 0.6, 1.8]:
		b.box(Vector3(x, ShipShape.DECK_Y + 0.9, ShipShape.HALF_LENGTH + 0.04), Vector3(0.42, 0.42, 0.04), Toon.color("gold"))
		b.box(Vector3(x, ShipShape.DECK_Y + 0.9, ShipShape.HALF_LENGTH + 0.07), Vector3(0.3, 0.3, 0.04), Toon.color("trim"))


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
			var c := Toon.color("deck") if p % 2 == 0 else Toon.color("deck").darkened(0.07)
			b.quad(Vector3(a0, y, z0), Vector3(b0, y, z0), Vector3(b1, y, z1), Vector3(a1, y, z1), c, Vector3.UP)
	# Front face of the quarterdeck, with a gold trim along its edge.
	var qz := ShipShape.QUARTER_Z
	var wq := ShipShape.half_width(qz, ShipShape.DECK_Y) - t
	b.quad(
		Vector3(-wq, ShipShape.DECK_Y, qz), Vector3(wq, ShipShape.DECK_Y, qz),
		Vector3(wq, ShipShape.QUARTER_Y, qz), Vector3(-wq, ShipShape.QUARTER_Y, qz),
		Toon.color("hull_dark"), Vector3.FORWARD,
	)
	b.box(Vector3(0, ShipShape.QUARTER_Y - 0.08, qz - 0.06), Vector3(wq, 0.08, 0.08), Toon.color("stripe"))
	# A rail along the quarterdeck front, open at the stairs.
	var s := ShipShape.STAIR_HALF_WIDTH
	for side: int in [-1, 1]:
		var mid := side * (s + wq) * 0.5
		b.box(Vector3(mid, ShipShape.QUARTER_Y + 0.85, qz + 0.05), Vector3((wq - s) * 0.5, 0.06, 0.06), Toon.color("rail"))
		for x: float in [s + 0.1, (s + wq) * 0.5, wq - 0.1]:
			b.box(Vector3(side * x, ShipShape.QUARTER_Y + 0.42, qz + 0.05), Vector3(0.05, 0.42, 0.05), Toon.color("rail"))


static func _stairs(b: MeshBuilder) -> void:
	var n := 6
	var rise := (ShipShape.QUARTER_Y - ShipShape.DECK_Y) / n
	var run := (ShipShape.QUARTER_Z - ShipShape.STAIR_BOTTOM_Z) / n
	for i in n:
		var top := ShipShape.DECK_Y + rise * (i + 1)
		var z := ShipShape.STAIR_BOTTOM_Z + run * (i + 0.5)
		var c := Toon.color("deck") if i % 2 == 0 else Toon.color("deck").darkened(0.08)
		b.box(
			Vector3(0, (ShipShape.DECK_Y + top) * 0.5, z),
			Vector3(ShipShape.STAIR_HALF_WIDTH, (top - ShipShape.DECK_Y) * 0.5, run * 0.5), c,
		)


static func _masts_and_rigging(b: MeshBuilder) -> void:
	var deck := ShipShape.DECK_Y
	var rope := Toon.color("rope")
	var tops: Array[Vector3] = []
	for m in ShipShape.MAST_Z.size():
		var z: float = ShipShape.MAST_Z[m]
		var h: float = ShipShape.MAST_HEIGHT[m]
		b.cylinder(Vector3(0, deck - 0.5, z), Vector3(0, deck + h, z), ShipShape.MAST_RADIUS, 0.2, 10, Toon.color("mast"))
		b.cylinder(Vector3(0, deck + h, z), Vector3(0, deck + h + 0.3, z), 0.3, 0.3, 10, Toon.color("hull_dark"))
		tops.append(Vector3(0, deck + h, z))
		# Shrouds: three ropes each side from high on the mast down to the rail.
		for side: int in [-1, 1]:
			for dz: float in [-0.9, 0.0, 0.9]:
				var foot := Vector3(side * (ShipShape.half_width(z + dz, deck) - 0.05), ShipShape.rail_top(z + dz), z + dz)
				b.cylinder(foot, Vector3(0, deck + 0.62 * h, z), 0.03, 0.03, 4, rope, false)
	# Crow's nest on the main mast.
	var nest := Vector3(0, deck + 0.72 * ShipShape.MAST_HEIGHT[1], ShipShape.MAST_Z[1])
	b.cylinder(nest, nest + Vector3(0, 0.9, 0), 1.1, 1.2, 14, Toon.color("hull_dark"))
	b.cylinder(nest + Vector3(0, 0.9, 0), nest + Vector3(0, 1.0, 0), 1.25, 1.25, 14, Toon.color("stripe"))
	# Bowsprit and the stays from the mast tops.
	var sprit_root := Vector3(0, deck + 0.6, -12.2)
	var sprit_tip := Vector3(0, deck + 3.8, -19.5)
	b.cylinder(sprit_root, sprit_tip, 0.26, 0.12, 8, Toon.color("mast"))
	b.cylinder(tops[0], sprit_tip, 0.03, 0.03, 4, rope, false)
	b.cylinder(tops[1], tops[0], 0.03, 0.03, 4, rope, false)
	b.cylinder(tops[1], Vector3(0, ShipShape.QUARTER_Y + 1.0, ShipShape.STERN_Z), 0.03, 0.03, 4, rope, false)


static func _fittings(b: MeshBuilder) -> void:
	for m in ShipShape.MAST_Z.size():
		var post := ShipShape.sail_post(m)
		b.cylinder(post, post + Vector3(0, 1.3, 0), 0.14, 0.12, 8, Toon.color("hull_dark"))
		b.box(post + Vector3(0, 0.9, 0), Vector3(0.32, 0.05, 0.06), Toon.color("rope"))
		b.box(post + Vector3(0, 1.1, 0), Vector3(0.32, 0.05, 0.06), Toon.color("rope"))
	var w := ShipShape.WHEEL
	b.box(w + Vector3(0, 0.6, 0), Vector3(0.25, 0.6, 0.22), Toon.color("hull_dark"))
	var lamp := Vector3(0, ShipShape.QUARTER_Y + ShipShape.RAIL_HEIGHT, ShipShape.STERN_Z + 0.2)
	b.cylinder(lamp, lamp + Vector3(0, 0.9, 0), 0.06, 0.06, 6, Toon.color("trim"))
	b.box(lamp + Vector3(0, 1.1, 0), Vector3(0.22, 0.05, 0.22), Toon.color("trim"))


static func _ladder(b: MeshBuilder, side: int) -> void:
	var z := ShipShape.LADDER_Z
	var rail := Toon.color("hull_dark")
	var y := -0.8
	var prev := {}
	while y <= ShipShape.DECK_Y + 0.15:
		for dz: float in [-0.38, 0.38]:
			var p := Vector3(side * (ShipShape.half_width(z + dz, y) + 0.12), y, z + dz)
			if prev.has(dz):
				b.cylinder(prev[dz], p, 0.05, 0.05, 5, rail, false)
			prev[dz] = p
		var rung_x := side * (ShipShape.half_width(z, y) + 0.12)
		b.box(Vector3(rung_x, y, z), Vector3(0.05, 0.04, 0.4), Toon.color("rope"))
		y += 0.35


static func _cannon_ports(b: MeshBuilder, side: int) -> void:
	for z: float in [-8.6, -5.6, 0.4, 3.4, 6.6, 9.6]:
		var x := side * (ShipShape.half_width(z, 1.6) + 0.02)
		b.box(Vector3(x, 1.6, z), Vector3(0.06, 0.34, 0.42), Toon.color("stripe"))
		b.box(Vector3(x + side * 0.03, 1.6, z), Vector3(0.05, 0.26, 0.33), Toon.color("trim"))


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
	var cream := Toon.color("sail")
	var shade := func(p: Vector3) -> Color: return cream
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
	b.cylinder(Vector3(-width * 0.5 - 0.4, 0, 0), Vector3(width * 0.5 + 0.4, 0, 0), 0.16, 0.16, 8, Toon.color("mast"))
	return b.build()


## The ship's wheel in its own frame: axle along z, centre at the origin.
static func wheel() -> ArrayMesh:
	var b := MeshBuilder.new()
	var wood := Toon.color("mast")
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
		b.cylinder(dir * (r + 0.05), dir * (r + 0.2), 0.045, 0.04, 6, Toon.color("hull_dark"))
	b.cylinder(Vector3(0, 0, -0.1), Vector3(0, 0, 0.1), 0.09, 0.09, 10, Toon.color("hull_dark"))
	b.cylinder(Vector3(0, 0, 0.1), Vector3(0, 0, 0.13), 0.06, 0.06, 10, Toon.color("stripe"))
	return b.build()


## The anchor capstan: a drum with four bars, turning about its own y axis.
static func capstan() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.cylinder(Vector3.ZERO, Vector3(0, 0.75, 0), 0.5, 0.42, 14, Toon.color("hull_dark"))
	b.cylinder(Vector3(0, 0.75, 0), Vector3(0, 0.95, 0), 0.62, 0.62, 14, Toon.color("mast"))
	for i in 4:
		var a := TAU * i / 4
		b.box(Vector3(cos(a) * 0.95, 0.85, sin(a) * 0.95), Vector3(0.5, 0.05, 0.05), Toon.color("mast"), Basis(Vector3.UP, -a))
	return b.build()


## A black flag with a skull and crossed bones, flying toward +x from its pole.
static func flag() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.box(Vector3(1.2, 0, 0), Vector3(1.2, 0.75, 0.03), Toon.color("flag"))
	for z: float in [-0.05, 0.05]:
		var face := Vector3(1.2, 0.08, z)
		b.ellipsoid(face, 0.3, Vector3(1.0, 1.0, 0.15), 6, 10, Toon.color("bone"))
		for a: float in [0.7, -0.7]:
			b.box(face + Vector3(0, -0.38, 0), Vector3(0.45, 0.05, 0.03), Toon.color("bone"), Basis(Vector3.BACK, a))
	return b.build()

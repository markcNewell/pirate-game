class_name BotNav
extends RefCounted
## Grid pathfinding on the galleon's decks, for test bots. Two flat maps in the ship frame:
## the upper decks (main deck, stairs and quarterdeck) and the lower deck. Obstacles are
## rectangles grown by a body's radius; A* runs on a half-metre grid.

const CELL := 0.5
const RADIUS := 0.45

static var _upper: Array[Rect2] = []
static var _lower: Array[Rect2] = []


static func _centred(centre: Vector2, half: Vector2) -> Rect2:
	return Rect2(centre - half, half * 2.0)


static func _obstacles(lower: bool) -> Array[Rect2]:
	if lower and not _lower.is_empty():
		return _lower
	if not lower and not _upper.is_empty():
		return _upper
	var r: Array[Rect2] = []
	for z in ShipShape.MAST_Z:
		r.append(_centred(Vector2(0, z), Vector2(ShipShape.MAST_RADIUS, ShipShape.MAST_RADIUS)))
	if lower:
		r.append(_centred(Vector2(0, -8.0), Vector2(1.3, 1.2)))  # barrels at the bow
		r.append(_centred(Vector2(1.0, 4.6), Vector2(0.5, 0.5)))
		r.append(_centred(Vector2(-1.1, 4.9), Vector2(0.45, 0.45)))
		r.append(_centred(Vector2(0, ShipShape.HATCH_Z1 - 0.12), Vector2(0.4, 0.1)))
		_lower = r
		return r
	r.append(_centred(Vector2(0, (ShipShape.HATCH_Z0 + ShipShape.HATCH_Z1) * 0.5),
		Vector2(ShipShape.HATCH_X + 0.16, (ShipShape.HATCH_Z1 - ShipShape.HATCH_Z0) * 0.5 + 0.16)))
	r.append(_centred(Vector2(0, ShipShape.CAPSTAN.z), Vector2(0.6, 0.6)))
	r.append(_centred(Vector2(0, ShipShape.WHEEL.z), Vector2(0.3, 0.25)))
	r.append(_centred(Vector2(ShipShape.MAP_TABLE.x, ShipShape.MAP_TABLE.z), Vector2(0.6, 0.4)))
	for c in ShipShape.CLUTTER:
		if c[2] != "rope":
			var centre: Vector3 = c[0]
			var half: Vector3 = c[1]
			r.append(_centred(Vector2(centre.x, centre.z), Vector2(half.x, half.z)))
	for m in ShipShape.MAST_Z.size():
		var post := ShipShape.sail_post(m)
		r.append(_centred(Vector2(post.x, post.z), Vector2(0.15, 0.15)))
	for gun in ShipShape.cannon_count():
		var pivot := ShipShape.cannon_pivot_of(gun)
		r.append(_centred(Vector2(pivot.x - ShipShape.cannon_side(gun) * 0.05, pivot.z), Vector2(0.6, 0.45)))
	var wq := ShipShape.half_width(ShipShape.QUARTER_Z, ShipShape.DECK_Y)
	var s := ShipShape.STAIR_HALF_WIDTH
	for side: int in [-1, 1]:
		r.append(_centred(Vector2(side * (s + wq) * 0.5, ShipShape.QUARTER_Z), Vector2((wq - s) * 0.5, 0.15)))
		r.append(_centred(Vector2(side * (s + 0.05), 4.5), Vector2(0.05, 1.5)))
	_upper = r
	return r


static func walkable(p: Vector2, lower: bool) -> bool:
	if lower:
		if p.y < ShipShape.LOWER_Z0 + 0.5 or p.y > ShipShape.LOWER_Z1 - 0.5:
			return false
		if absf(p.x) > ShipShape.lower_wall_x(p.y) - RADIUS:
			return false
	else:
		if p.y < ShipShape.BOW_DECK_Z + 0.6 or p.y > ShipShape.STERN_Z - 0.5:
			return false
		if absf(p.x) > ShipShape.half_width(p.y, ShipShape.DECK_Y) - ShipShape.RAIL_THICKNESS - RADIUS:
			return false
	for rect in _obstacles(lower):
		if rect.grow(RADIUS).has_point(p):
			return false
	return true


## The rectangles that really are solid (they have collision), for checking where players say
## they stand. A subset of the bots' obstacles, which also steer round loose barrels.
static func solids(lower: bool) -> Array[Rect2]:
	var all := _obstacles(lower)
	if lower:
		return all.slice(0, ShipShape.MAST_Z.size())
	# Upper deck: everything except the ramp's open sides (the last two entries per side pair).
	var out: Array[Rect2] = []
	for rect in all:
		if rect.size.x > 0.11 or rect.size.y < 2.9:
			out.append(rect)
	return out


## A list of ship-frame points from `from` to `to` (both on the same deck), or [] if no way.
static func find_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var lower := from.y < 1.5
	var start := _nearest_open(Vector2i(roundi(from.x / CELL), roundi(from.z / CELL)), lower)
	var goal := _nearest_open(Vector2i(roundi(to.x / CELL), roundi(to.z / CELL)), lower)
	if start.x == 9999 or goal.x == 9999:
		return []
	var came := {start: start}
	var cost := {start: 0.0}
	var open: Array[Vector2i] = [start]
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if cost[open[i]] + Vector2(open[i] - goal).length() < cost[open[best]] + Vector2(open[best] - goal).length():
				best = i
		var cur: Vector2i = open[best]
		open.remove_at(best)
		if cur == goal:
			break
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var nxt := cur + Vector2i(dx, dz)
				var mid := (Vector2(cur) + Vector2(nxt)) * 0.5 * CELL
				if not walkable(Vector2(nxt) * CELL, lower) or not walkable(mid, lower):
					continue
				var c: float = cost[cur] + Vector2(dx, dz).length()
				if not cost.has(nxt) or c < cost[nxt]:
					cost[nxt] = c
					came[nxt] = cur
					if not open.has(nxt):
						open.append(nxt)
	if not came.has(goal):
		return []
	var cells: Array[Vector2i] = [goal]
	while cells.back() != start:
		cells.append(came[cells.back()])
	cells.reverse()
	var out: Array[Vector3] = []
	for i in cells.size():
		# Keep only the corners of the path.
		if i > 0 and i < cells.size() - 1 and cells[i] - cells[i - 1] == cells[i + 1] - cells[i]:
			continue
		var p := Vector2(cells[i]) * CELL
		out.append(Vector3(p.x, _floor(p, lower), p.y))
	out.append(to)
	return out


static func _floor(p: Vector2, lower: bool) -> float:
	return ShipShape.LOWER_Y if lower else ShipShape.floor_y(p.y, p.x)


static func _nearest_open(cell: Vector2i, lower: bool) -> Vector2i:
	for r in 6:
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var c := cell + Vector2i(dx, dz)
				if walkable(Vector2(c) * CELL, lower):
					return c
	return Vector2i(9999, 9999)

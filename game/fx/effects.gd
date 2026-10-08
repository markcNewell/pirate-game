class_name Effects
extends Node3D
## Short-lived toon effects: cannonballs, muzzle smoke, splashes, splinters and sand puffs.
## Each effect is a handful of meshes animated here (the solid pieces from art/blender/props.py).

enum Impact { WATER, HULL, SPLINTERS, SAND }

const SMOKE := Color("f2f0ea")
const SPLASH := Color("ffffff")
const SAND := Color("e8cf98")

var _items: Array[Dictionary] = []
var _ball_mesh: ArrayMesh
var _puff_mesh: SphereMesh
var _splinter_mesh: ArrayMesh
var _plank_mesh: ArrayMesh


func _ready() -> void:
	_ball_mesh = Models.part("fx", "cannonball")
	_puff_mesh = SphereMesh.new()
	_puff_mesh.radial_segments = 12
	_puff_mesh.rings = 6
	_splinter_mesh = Models.part("fx", "splinter")
	_plank_mesh = Models.part("fx", "wreck_plank")


func cannonball() -> Node3D:
	var ball := Toon.instance(_ball_mesh)
	ball.visible = false
	add_child(ball)
	return ball


func muzzle_smoke(pos: Vector3, dir: Vector3) -> void:
	# A short orange flash that lights up the deck and the water around the gun.
	var flash := OmniLight3D.new()
	flash.light_color = Color("ffb35a")
	flash.light_energy = 4.0
	flash.omni_range = 14.0
	flash.position = pos + dir * 0.8
	add_child(flash)
	_items.append({"node": flash, "age": 0.0, "life": 0.2, "kind": "flash"})
	for i in 6:
		var p := pos + dir * (0.4 + i * 0.45) + _jitter(0.25)
		_puff(p, SMOKE, 0.35 + i * 0.05, 1.3 + i * 0.12, 1.6 + randf() * 0.5, dir * (2.5 - i * 0.3) + Vector3.UP * 0.6)


## One puff of a cannonball's smoke trail.
func trail(pos: Vector3) -> void:
	_puff(pos, SMOKE, 0.18, 0.85, 0.9, Vector3.UP * 0.3)


## Bubbles breaking the surface over a sinking ship.
func bubbles(at: Vector3) -> void:
	for i in 3:
		var p := Vector3(at.x, 0.15, at.z) + Vector3(randf_range(-4, 4), 0.0, randf_range(-9, 9))
		_puff(p, SPLASH, 0.2, 0.9, 0.7, Vector3.UP * 0.6)


## Planks and barrels left floating where a ship went down; they drift, bob on the waves and
## sink away after a while.
func wreckage(at: Vector3) -> void:
	for i in 12:
		var barrel := i % 4 == 0
		var piece := Toon.instance(LootView.mesh_for(Loot.Kind.BARREL, 0) if barrel else _plank_mesh)
		var spot := Vector2(at.x, at.z) + Vector2(randf_range(-6, 6), randf_range(-10, 10))
		piece.position = Vector3(spot.x, 0.0, spot.y)
		piece.rotation = Vector3(PI / 2.0 if barrel else 0.0, randf() * TAU, 0.0)
		add_child(piece)
		_items.append({
			"node": piece, "age": 0.0, "life": randf_range(35.0, 50.0), "kind": "float", "at": spot,
			"drift": Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)), "spin": randf_range(-0.3, 0.3),
			"lift": 0.0 if barrel else 0.05,
		})


func impact(kind: int, pos: Vector3) -> void:
	match kind:
		Impact.WATER:
			_splash(pos)
		Impact.HULL:
			_splinters(pos, 12)
			for i in 4:
				_puff(pos + _jitter(0.6), Color("d8d2c4"), 0.4, 1.4, 1.2 + randf() * 0.4, Vector3.UP * 0.8)
		Impact.SPLINTERS:
			_splinters(pos, 7)
		Impact.SAND:
			for i in 6:
				_puff(pos + _jitter(0.8), SAND, 0.4, 1.6, 1.0 + randf() * 0.4, _jitter(1.0) + Vector3.UP * 1.5)


func _splash(pos: Vector3) -> void:
	# A white column that rises and falls, with a ring of drops around it.
	var column := _fading_mesh(_puff_mesh, SPLASH)
	column.position = pos
	column.scale = Vector3(0.6, 0.1, 0.6)
	_items.append({"node": column, "age": 0.0, "life": 1.1, "kind": "column", "base": pos})
	for i in 10:
		var a := TAU * i / 10.0
		var drop := _fading_mesh(_puff_mesh, SPLASH)
		drop.position = pos
		drop.scale = Vector3.ONE * 0.25
		var vel := Vector3(cos(a) * 3.0, 6.0 + randf() * 3.0, sin(a) * 3.0)
		_items.append({"node": drop, "age": 0.0, "life": 1.4, "kind": "drop", "vel": vel})


func _splinters(pos: Vector3, count: int) -> void:
	for i in count:
		var piece := Toon.instance(_splinter_mesh)
		piece.position = pos
		piece.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		add_child(piece)
		var vel := _jitter(5.0) + Vector3.UP * 4.0
		var spin := _jitter(12.0)
		_items.append({"node": piece, "age": 0.0, "life": 2.5, "kind": "splinter", "vel": vel, "spin": spin})


## A grey wisp rising from something put out (a doused green fire).
func smoke(pos: Vector3) -> void:
	_puff(pos + _jitter(0.2), Color(0.55, 0.6, 0.55, 0.6), 0.25, 0.9, 2.2, Vector3(0, 0.9, 0) + _jitter(0.15))


func _puff(pos: Vector3, color: Color, start: float, end: float, life: float, vel: Vector3) -> void:
	var puff := _fading_mesh(_puff_mesh, color)
	puff.position = pos
	puff.scale = Vector3.ONE * start
	_items.append({
		"node": puff, "age": 0.0, "life": life, "kind": "puff", "vel": vel, "start": start, "end": end,
	})


func _fading_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for item in _items:
		item.age += delta
		var node: Node3D = item.node
		var k: float = item.age / item.life
		if k >= 1.0:
			node.queue_free()
			continue
		match item.kind:
			"puff":
				item.vel *= 1.0 - minf(1.0, 2.0 * delta)
				node.position += item.vel * delta
				node.scale = Vector3.ONE * lerpf(item.start, item.end, 1.0 - pow(1.0 - k, 3.0))
				_fade(node, 1.0 - k * k)
			"column":
				var h := sin(k * PI) * 5.0
				node.scale = Vector3(0.9 - k * 0.4, maxf(0.1, h), 0.9 - k * 0.4)
				node.position = item.base + Vector3.UP * h * 0.5
				_fade(node, 1.0 - k)
			"drop":
				item.vel.y -= 9.81 * delta
				node.position += item.vel * delta
				_fade(node, 1.0 - k)
			"float":
				item.at += item.drift * delta
				var sea := Waves.height(item.at.x, item.at.y, _sea_time())
				# Ride the waves, then slip under in the last few seconds.
				var under := maxf(0.0, item.age - (item.life - 4.0)) * 0.4
				node.position = Vector3(item.at.x, sea + item.lift - under, item.at.y)
				node.rotation.y += item.spin * delta
			"flash":
				(node as OmniLight3D).light_energy = 4.0 * (1.0 - k)
			"splinter":
				item.vel.y -= 9.81 * delta
				node.position += item.vel * delta
				node.rotation += item.spin * delta
		keep.append(item)
	_items = keep


func _sea_time() -> float:
	var game := get_parent() as Game
	return game.render_time if game else Time.get_ticks_msec() / 1000.0


func _fade(node: Node3D, alpha: float) -> void:
	var m := (node as MeshInstance3D).material_override as StandardMaterial3D
	m.albedo_color.a = clampf(alpha, 0.0, 1.0)


func _jitter(r: float) -> Vector3:
	return Vector3(randf_range(-r, r), randf_range(-r, r), randf_range(-r, r))

class_name Effects
extends Node3D
## Short-lived toon effects: cannonballs, muzzle smoke, splashes, splinters and sand puffs.
## Each effect is a handful of simple meshes animated here, so there is nothing to author.

enum Impact { WATER, HULL, SPLINTERS, SAND }

const SMOKE := Color("f2f0ea")
const SPLASH := Color("ffffff")
const SAND := Color("e8cf98")

var _items: Array[Dictionary] = []
var _ball_mesh: ArrayMesh
var _puff_mesh: SphereMesh
var _splinter_mesh: ArrayMesh


func _ready() -> void:
	var b := MeshBuilder.new()
	b.ellipsoid(Vector3.ZERO, 0.24, Vector3.ONE, 6, 10, Color("2b2b30"))
	_ball_mesh = b.build()
	_puff_mesh = SphereMesh.new()
	_puff_mesh.radial_segments = 12
	_puff_mesh.rings = 6
	var s := MeshBuilder.new()
	s.box(Vector3.ZERO, Vector3(0.05, 0.05, 0.22), Toon.color("trunk"))
	_splinter_mesh = s.build()


func cannonball() -> Node3D:
	var ball := Toon.instance(_ball_mesh)
	ball.visible = false
	add_child(ball)
	return ball


func muzzle_smoke(pos: Vector3, dir: Vector3) -> void:
	for i in 6:
		var p := pos + dir * (0.4 + i * 0.45) + _jitter(0.25)
		_puff(p, SMOKE, 0.35 + i * 0.05, 1.3 + i * 0.12, 1.6 + randf() * 0.5, dir * (2.5 - i * 0.3) + Vector3.UP * 0.6)


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
			"splinter":
				item.vel.y -= 9.81 * delta
				node.position += item.vel * delta
				node.rotation += item.spin * delta
		keep.append(item)
	_items = keep


func _fade(node: Node3D, alpha: float) -> void:
	var m := (node as MeshInstance3D).material_override as StandardMaterial3D
	m.albedo_color.a = clampf(alpha, 0.0, 1.0)


func _jitter(r: float) -> Vector3:
	return Vector3(randf_range(-r, r), randf_range(-r, r), randf_range(-r, r))

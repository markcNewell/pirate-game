class_name Whale
extends Node3D
## Now and then a whale breaks the surface far out from the camera, blows a spout and rolls
## back under. Only scenery; each player sees their own.

const GAP_MIN := 50.0
const GAP_MAX := 120.0
const SHOW := 6.0

## For screenshots: surface soon, in front of the camera.
static var eager := false

var _wait := 0.0
var _left := 0.0
var _at := Vector3.ZERO
var _heading := 0.0
var _back: MeshInstance3D
var _spout: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_wait = 2.0 if eager else _rng.randf_range(20.0, GAP_MAX)
	var b := MeshBuilder.new()
	var skin := Color("3e5a78")
	b.ellipsoid(Vector3.ZERO, 2.2, Vector3(1.0, 0.55, 3.6), 8, 14, skin)
	b.ellipsoid(Vector3(0, -0.5, -0.5), 1.9, Vector3(0.9, 0.35, 3.0), 6, 10, Color("c9d6de"))
	b.box(Vector3(0, 1.0, 3.6), Vector3(0.08, 0.5, 0.6), skin, Basis(Vector3.RIGHT, 0.5))
	_back = Toon.instance(b.build())
	_back.visible = false
	add_child(_back)
	var s := MeshBuilder.new()
	s.cylinder(Vector3.ZERO, Vector3(0, 4.0, 0), 0.25, 1.1, 8, Color.WHITE)
	s.ellipsoid(Vector3(0, 4.2, 0), 1.3, Vector3(1.0, 0.6, 1.0), 5, 8, Color.WHITE)
	_spout = MeshInstance3D.new()
	_spout.mesh = s.build()
	_spout.material_override = Toon.clear_material(Color(1, 1, 1, 0.7))
	_spout.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spout.visible = false
	add_child(_spout)


func follow(camera_pos: Vector3, sea_time: float, delta: float) -> void:
	if _left <= 0.0:
		_back.visible = false
		_spout.visible = false
		_wait -= delta
		if _wait > 0.0:
			return
		var a := _rng.randf() * TAU
		var cam := get_viewport().get_camera_3d()
		if eager and cam:
			var f := -cam.global_basis.z
			a = atan2(f.z, f.x)
		_at = camera_pos + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(120.0, 220.0)
		if Islands.island_at(_at.x, _at.z) >= 0:
			_wait = 5.0
			return
		_heading = _rng.randf() * TAU
		_left = SHOW
		_wait = _rng.randf_range(GAP_MIN, GAP_MAX)
	_left -= delta
	var k := 1.0 - _left / SHOW
	var sea := Waves.height(_at.x, _at.z, sea_time)
	# Rise, linger, roll under; moving forward the whole time.
	var rise := sin(k * PI)
	var ahead := Vector3(sin(_heading), 0.0, cos(_heading)) * k * 10.0
	_back.visible = true
	_back.global_transform = Transform3D(
		Basis(Vector3.UP, _heading) * Basis(Vector3.RIGHT, (k - 0.5) * 0.5),
		_at + ahead + Vector3(0, sea - 1.6 + rise * 1.6, 0))
	var blowing := k > 0.3 and k < 0.6
	_spout.visible = blowing
	if blowing:
		var puff := sin((k - 0.3) / 0.3 * PI)
		_spout.global_position = _at + ahead + Vector3(0, sea + 0.4, 0) + Vector3(sin(_heading), 0, cos(_heading)) * -1.5
		_spout.scale = Vector3(1.0, maxf(0.05, puff), 1.0)

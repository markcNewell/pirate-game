class_name Dolphins
extends Node3D
## Now and then a pod of dolphins finds the ship you are on (or nearest) while it is under way,
## and leaps alongside it for a while before peeling off. Each player sees their own pod; it is
## only scenery.

const POD := 3
const VISIT := 16.0
## Seconds between visits, at random within this range.
const GAP_MIN := 45.0
const GAP_MAX := 110.0
const LEAP_PERIOD := 2.3
## The part of each leap spent in the air.
const AIR := 0.42

## For screenshots: a visit starts straight away.
static var eager := false

var _swimmers: Array[Node3D] = []
var _wait := 0.0
var _left := 0.0
var _side := 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_wait = 2.0 if eager else _rng.randf_range(GAP_MIN * 0.5, GAP_MAX)
	var mesh := dolphin_mesh()
	for i in POD:
		var d := Toon.instance(mesh)
		d.visible = false
		add_child(d)
		_swimmers.append(d)


## Call every frame with the camera position, the sea clock and the ships (id -> ShipState).
func follow(camera_pos: Vector3, sea_time: float, ships: Dictionary, delta: float) -> void:
	var ship := _nearest_moving(camera_pos, ships)
	if _left <= 0.0:
		for d in _swimmers:
			d.visible = false
		_wait -= delta
		if _wait <= 0.0 and ship:
			_left = VISIT
			_side = -1.0 if _rng.randf() < 0.5 else 1.0
		elif _wait <= 0.0:
			_wait = 5.0
		return
	if ship == null:
		_left = 0.0
		_wait = _rng.randf_range(GAP_MIN, GAP_MAX)
		return
	_left -= delta
	if _left <= 0.0:
		_wait = _rng.randf_range(GAP_MIN, GAP_MAX)
	var fwd2 := ShipPhysics.forward(ship.yaw)
	var fwd := Vector3(fwd2.x, 0.0, fwd2.y)
	var right := fwd.cross(Vector3.UP)
	var age := VISIT - _left
	for i in POD:
		# Keep pace with the ship, working slowly up from the stern to the bow, then drift off.
		var along := -10.0 + i * 2.6 + age * 1.1
		var out := _side * (6.5 + i * 1.7 + maxf(0.0, age - VISIT + 3.0) * 4.0)
		var base := Vector3(ship.x, 0.0, ship.z) + fwd * along + right * out
		var u := fposmod(age / LEAP_PERIOD + i * 0.31, 1.0)
		var d := _swimmers[i]
		var surface := Waves.height(base.x, base.z, sea_time)
		if u > AIR:
			d.visible = false
			continue
		var arc := u / AIR
		var lift := sin(arc * PI) * 1.9 - 0.5
		# Nose up on the way out, down on the way in.
		var pitch := cos(arc * PI) * 0.9
		d.visible = true
		var turn := (Basis.looking_at(fwd) * Basis(Vector3.RIGHT, pitch)).scaled(Vector3.ONE * 1.3)
		d.global_transform = Transform3D(turn, base + Vector3(0, surface + lift, 0))


func _nearest_moving(camera_pos: Vector3, ships: Dictionary) -> ShipState:
	var best: ShipState = null
	var best_d := 60.0
	for id in ships:
		var s: ShipState = ships[id]
		var d := Vector2(s.x - camera_pos.x, s.z - camera_pos.z).length()
		if d < best_d and s.speed > 2.0 and s.sink <= 0.0:
			best = s
			best_d = d
	return best


## A toon dolphin facing -z: blue-grey back, pale belly, beak, dorsal fin and flukes.
static func dolphin_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	var back := Color("6c7d8e")
	var belly := Color("dbe6ec")
	b.ellipsoid(Vector3(0, 0, 0), 0.34, Vector3(0.8, 0.85, 3.0), 6, 12, back)
	b.ellipsoid(Vector3(0, -0.09, -0.1), 0.3, Vector3(0.78, 0.6, 2.8), 5, 10, belly)
	b.ellipsoid(Vector3(0, -0.05, -1.08), 0.11, Vector3(0.8, 0.7, 1.6), 4, 6, back)
	b.box(Vector3(0, 0.36, 0.1), Vector3(0.025, 0.2, 0.17), back, Basis(Vector3.RIGHT, -0.5))
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 0.3, -0.15, -0.35), Vector3(0.16, 0.02, 0.08), back, Basis(Vector3.UP, side * 0.5))
		b.box(Vector3(side * 0.18, 0.0, 1.12), Vector3(0.18, 0.025, 0.09), back, Basis(Vector3.UP, -side * 0.45))
		b.ellipsoid(Vector3(side * 0.17, 0.06, -0.8), 0.03, Vector3.ONE, 3, 5, Color("1a1a24"))
	return b.build()

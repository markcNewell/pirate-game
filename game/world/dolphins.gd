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
var _was_up: Array[bool] = []
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
		_was_up.append(false)


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
		var up := u <= AIR
		if up != _was_up[i]:
			# A splash as each one leaves the water and as it dives back in.
			_was_up[i] = up
			Audio.play_at("splash", base + Vector3(0, surface, 0), -14.0, 1.4)
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


## A toon dolphin facing -z (art/blender/wildlife.py).
static func dolphin_mesh() -> ArrayMesh:
	return Models.mesh("dolphin")

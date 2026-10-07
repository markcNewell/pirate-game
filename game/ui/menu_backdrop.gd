class_name MenuBackdrop
extends Node3D
## The live scene behind the title menu: the crew's galleon under full sail circling off
## Cutlass Cay, a skeleton ship prowling further out, and a camera drifting round them.

const CIRCLE_CENTRE := Vector2(40.0, -320.0)
const CIRCLE_RADIUS := 95.0
const SPEED := 6.0

var _world: World
var _ship: ShipView
var _skeleton: ShipView
var _camera: Camera3D
var _time := 0.0


func _ready() -> void:
	_world = World.new()
	add_child(_world)
	_ship = ShipView.new()
	_ship.kind = ShipState.Kind.CREW
	_ship.crew = 1
	add_child(_ship)
	_skeleton = ShipView.new()
	_skeleton.kind = ShipState.Kind.SKELETON
	_skeleton.crew = 0
	add_child(_skeleton)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.far = 3000.0
	add_child(_camera)
	_camera.make_current()


func _process(delta: float) -> void:
	_time += delta
	var ship := _sailing(_time * SPEED / CIRCLE_RADIUS, CIRCLE_RADIUS, 1)
	var skel := _sailing(_time * SPEED * 0.8 / 260.0 + 2.0, 260.0, 0)
	var wind := Game.wind_dir(_time)
	_ship.apply(ship, ShipPhysics.pose_of(ship, _time), wind, delta)
	_skeleton.apply(skel, ShipPhysics.pose_of(skel, _time), wind, delta)
	# Drift round the ship from its starboard quarter, slowly swinging forward.
	var swing := 0.6 + 0.5 * sin(_time * 0.05)
	var dir := ShipPhysics.forward(ship.yaw).rotated(swing + PI * 0.5)
	var at := Vector3(ship.x, 6.0, ship.z)
	var eye := at + Vector3(dir.x, 0, dir.y) * 38.0 + Vector3(0, 9.0, 0)
	# Aim left of the ship so it sails in the clear right-hand side of the screen.
	var right := (at - eye).cross(Vector3.UP).normalized()
	_camera.look_at_from_position(eye, at - right * 15.0 + Vector3(0, 3.0, 0))
	# Late afternoon, the sun low and golden behind the ships.
	_world.follow(_camera.global_position, _time, {1: ship, 10: skel}, 0.7)


## A ship under sail at angle `a` round the circle (counter-clockwise), heading along it.
func _sailing(a: float, radius: float, crew: int) -> ShipState:
	var s := ShipState.new()
	s.kind = ShipState.Kind.CREW if crew > 0 else ShipState.Kind.SKELETON
	s.crew = crew
	s.x = CIRCLE_CENTRE.x + cos(a) * radius
	s.z = CIRCLE_CENTRE.y + sin(a) * radius
	# Tangent to the circle, counter-clockwise seen from above: heading = atan2(-dx, -dz).
	var tangent := Vector2(-sin(a), cos(a))
	s.yaw = atan2(-tangent.x, -tangent.y)
	s.speed = SPEED
	s.anchored = false
	s.sail_height = [1.0, 1.0]
	s.rudder = 0.25
	return s

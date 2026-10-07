class_name ShipPhysics
extends RefCounted
## Sailing maths, kept free of nodes so it is easy to test and identical everywhere.
## The server steps it; clients only use pose(), which needs no state but the shared clock.

const MAX_SPEED := 8.0
## Acceleration (m/s²) from both masts at full sail with the wind straight behind.
const SAIL_PUSH := 1.4
const DRAG := SAIL_PUSH / (MAX_SPEED * MAX_SPEED)
## Even sails facing straight into the wind catch this share, so you can creep upwind.
const MIN_WIND_EFFICIENCY := 0.25
const MAX_SAIL_ANGLE := PI / 4.0

const RUDDER_RATE := 0.6
const TURN_RATE := 0.12
## Speed (m/s) at which the rudder reaches full effect.
const TURN_SPEED := 4.0
const SAIL_RATE := 0.5
const SAIL_TURN_RATE := 0.6

const ANCHOR_DECEL := 2.0
const ANCHOR_WINCH_TIME := 4.0

## Water rises this fast (m/s) per open hole; the ship goes down at SINK_LEVEL metres.
const LEAK_RATE := 0.012
const SINK_LEVEL := 2.4
const SINK_TIME := 12.0
## A ship full to the sinking point loses this share of its sail push.
const WATER_DRAG := 0.4

## Distance from mid-ship to the point that hits islands first.
const BOW_PROBE := 12.0
## Sea samples for the pose: half the hull length and half the beam.
const POSE_HALF_LENGTH := 11.0
const POSE_HALF_BEAM := 3.5


static func forward(yaw: float) -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


static func starboard(yaw: float) -> Vector2:
	var f := forward(yaw)
	return Vector2(-f.y, f.x)


## How much of the wind a mast catches: 1 with the sails square to it, never below the minimum.
static func sail_efficiency(yaw: float, angle: float, wind_dir: Vector2) -> float:
	var facing := forward(yaw - angle * MAX_SAIL_ANGLE)
	return MIN_WIND_EFFICIENCY + (1.0 - MIN_WIND_EFFICIENCY) * maxf(0.0, facing.dot(wind_dir))


## Advance one tick. `wind_dir` is the unit direction the wind blows toward and
## `wind_strength` scales its push (gusts in the storm). `islands` holds dictionaries with x, z
## and radius (the waterline circle).
static func step(
	s: ShipState, c: ShipControls, wind_dir: Vector2, dt: float, islands: Array, wind_strength := 1.0
) -> void:
	for g in ShipState.GUNS:
		s.gun_reload[g] = maxf(0.0, s.gun_reload[g] - dt)
	if s.is_sinking():
		# Going down: no more sailing, just drift to a stop as she slips under.
		s.sink = minf(1.0, s.sink + dt / SINK_TIME)
		s.speed = move_toward(s.speed, 0.0, 1.5 * dt)
		var drift := Vector2(s.x, s.z) + forward(s.yaw) * s.speed * dt
		s.x = drift.x
		s.z = drift.y
		return
	s.water = clampf(s.water + s.leaks() * LEAK_RATE * dt - c.bail, 0.0, SINK_LEVEL)
	if s.water >= SINK_LEVEL:
		s.sink = 1e-3
	s.rudder = clampf(s.rudder + c.wheel * RUDDER_RATE * dt, -1.0, 1.0)
	for m in ShipState.MASTS:
		s.sail_height[m] = clampf(s.sail_height[m] + c.sail_raise[m] * SAIL_RATE * dt, 0.0, 1.0)
		s.sail_angle[m] = clampf(s.sail_angle[m] + c.sail_turn[m] * SAIL_TURN_RATE * dt, -1.0, 1.0)

	if c.anchor_drop and not s.anchored:
		s.anchored = true
		s.anchor_progress = 0.0
	if s.anchored and c.anchor_winch:
		s.anchor_progress += dt / ANCHOR_WINCH_TIME
		if s.anchor_progress >= 1.0:
			s.anchored = false
			s.anchor_progress = 0.0

	var push := 0.0
	if not s.anchored:
		for m in ShipState.MASTS:
			push += 0.5 * SAIL_PUSH * s.sail_height[m] * sail_efficiency(s.yaw, s.sail_angle[m], wind_dir)
	push *= wind_strength * (1.0 - WATER_DRAG * s.water / SINK_LEVEL)
	s.speed += (push - DRAG * s.speed * absf(s.speed)) * dt
	if s.anchored:
		s.speed = move_toward(s.speed, 0.0, ANCHOR_DECEL * dt)

	var steer := clampf(absf(s.speed) / TURN_SPEED, 0.0, 1.0) * (1.0 if s.speed >= 0.0 else -1.0)
	s.yaw = wrapf(s.yaw - s.rudder * TURN_RATE * steer * dt, -PI, PI)

	var pos := Vector2(s.x, s.z) + forward(s.yaw) * s.speed * dt
	pos = _keep_off_islands(pos, s, islands)
	s.x = pos.x
	s.z = pos.y


static func _keep_off_islands(pos: Vector2, s: ShipState, islands: Array) -> Vector2:
	var f := forward(s.yaw)
	for island: Dictionary in islands:
		var centre := Vector2(island.x, island.z)
		var bow := pos + f * BOW_PROBE
		var gap: float = bow.distance_to(centre) - island.radius
		if gap < 0.0:
			# Back the whole ship out along the bow-to-island line and kill the speed: no
			# damage until milestone 2, just a dead stop.
			pos += (bow - centre).normalized() * -gap
			s.speed = 0.0
	return pos


## Where the hull sits on the waves. Stateless, so every machine agrees given the same clock.
## Water inside makes her sit lower; while sinking she slides under bow first.
static func pose(x: float, z: float, yaw: float, t: float, water := 0.0, sink := 0.0) -> Transform3D:
	var p := Vector2(x, z)
	var f := forward(yaw) * POSE_HALF_LENGTH
	var r := starboard(yaw) * POSE_HALF_BEAM
	var h_mid := Waves.height(p.x, p.y, t)
	var h_bow := Waves.height(p.x + f.x, p.y + f.y, t)
	var h_stern := Waves.height(p.x - f.x, p.y - f.y, t)
	var h_port := Waves.height(p.x - r.x, p.y - r.y, t)
	var h_star := Waves.height(p.x + r.x, p.y + r.y, t)

	# Averaging five points across a 26 m hull smooths out the short waves, so the ship
	# feels heavy without a spring that would need per-machine state.
	var heave := 0.4 * h_mid + 0.15 * (h_bow + h_stern + h_port + h_star)
	var pitch := atan2(h_bow - h_stern, 2.0 * POSE_HALF_LENGTH) * 0.9
	var roll := atan2(h_star - h_port, 2.0 * POSE_HALF_BEAM) * 0.8
	heave -= water * 0.3 + sink * sink * 22.0
	pitch -= sink * 0.45
	roll += sink * 0.2
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	return Transform3D(basis, Vector3(x, heave, z))


## Pose for a ship state, including its water and sinking.
static func pose_of(s: ShipState, t: float) -> Transform3D:
	return pose(s.x, s.z, s.yaw, t, s.water, s.sink)


## World velocity of the ship (m/s), for things it launches.
static func velocity_of(s: ShipState) -> Vector3:
	var f := forward(s.yaw) * s.speed
	return Vector3(f.x, 0.0, f.y)

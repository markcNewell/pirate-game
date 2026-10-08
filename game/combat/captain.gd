class_name Captain
extends RefCounted
## Sails a skeleton ship: closes on the crew's ship, holds its broadside off it and fires.
## Pure decision-making: the server applies the controls and fires the guns it asks for.

const APPROACH_RANGE := 220.0
const FAR := 140.0
const NEAR := 70.0
const FIRE_RANGE := 280.0
const RELOAD := 6.0
const AIM_ERROR_YAW := 0.05
const AIM_ERROR_PITCH := 0.02
## Bails this many metres a second, and patches a hole this often, so it takes several
## leaking hits at once to sink her.
const BAIL_RATE := 0.02
const PATCH_EVERY := 25.0
## Aim at the hull just above the waterline.
const AIM_HEIGHT := 0.8

var rng := RandomNumberGenerator.new()
## A Spanish galleon bails this many times as fast and reloads this much faster.
var bail_scale := 1.0
var reload_scale := 1.0
## A treasure galleon runs from the crews instead of fighting, at three quarters of the sail.
var fleeing := false
## Scales the deliberate aiming error (0 = perfect aim, for tests).
var error_scale := 1.0
var _patch_timer := 0.0


func _init(seed_value := 0) -> void:
	rng.seed = seed_value


## The heading (yaw) that points the bow from `from` toward `to`.
static func bearing(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(-d.x, -d.y)


## Fill `c` for this tick and return the guns to fire as [{gun, yaw, pitch}].
func think(
	me: ShipState, target: ShipState, wind: Vector2, t: float, dt: float, islands: Array, c: ShipControls
) -> Array:
	c.anchor_winch = me.anchored
	var pos := Vector2(me.x, me.z)
	var desired := me.yaw
	var sail := 0.5
	if fleeing and target != null and not target.is_sinking():
		desired = bearing(Vector2(target.x, target.z), pos)
		sail = 0.75
	elif target != null and not target.is_sinking():
		var dist := pos.distance_to(Vector2(target.x, target.z))
		var to_target := bearing(pos, Vector2(target.x, target.z))
		if dist > APPROACH_RANGE:
			desired = to_target
			sail = 1.0
		else:
			desired = broadside_heading(me.yaw, to_target)
			var inward := signf(angle_difference(desired, to_target))
			if dist > FAR:
				desired += inward * 0.45
			elif dist < NEAR:
				desired -= inward * 0.45
			sail = 0.65
	desired = _avoid_islands(pos, desired, islands)

	var err := angle_difference(me.yaw, desired)
	var rudder_target := clampf(-err * 2.5, -1.0, 1.0)
	c.wheel = clampf((rudder_target - me.rudder) * 5.0, -1.0, 1.0)
	var trim := best_sail_angle(me.yaw, wind)
	for m in ShipState.MASTS:
		c.sail_raise[m] = clampf((sail - me.sail_height[m]) * 4.0, -1.0, 1.0)
		c.sail_turn[m] = clampf((trim - me.sail_angle[m]) * 4.0, -1.0, 1.0)

	c.bail = BAIL_RATE * bail_scale * dt
	_patch_timer += dt
	if _patch_timer >= PATCH_EVERY and not me.holes.is_empty():
		_patch_timer = 0.0
		me.holes.pop_front()

	if target == null or target.is_sinking():
		return []
	if fleeing:
		return []  # a treasure galleon runs; her escorts do the shooting
	return _guns(me, target, t)


## Of the two headings that put the target abeam, the one nearer the current heading.
static func broadside_heading(yaw: float, to_target: float) -> float:
	var a := wrapf(to_target + PI / 2.0, -PI, PI)
	var b := wrapf(to_target - PI / 2.0, -PI, PI)
	return a if absf(angle_difference(yaw, a)) < absf(angle_difference(yaw, b)) else b


static func best_sail_angle(yaw: float, wind: Vector2) -> float:
	var best := 0.0
	var best_eff := -1.0
	for i in 9:
		var a := -1.0 + i * 0.25
		var eff := ShipPhysics.sail_efficiency(yaw, a, wind)
		if eff > best_eff + 1e-4:
			best_eff = eff
			best = a
	return best


func _avoid_islands(pos: Vector2, desired: float, islands: Array) -> float:
	for island: Dictionary in islands:
		var centre := Vector2(island.x, island.z)
		var probe := pos + ShipPhysics.forward(desired) * 70.0
		if probe.distance_to(centre) < island.radius + 45.0:
			# Turn away from the island's side of our course.
			var away := signf(angle_difference(bearing(pos, centre), desired))
			desired += (away if away != 0.0 else 1.0) * 0.9
	return wrapf(desired, -PI, PI)


func _guns(me: ShipState, target: ShipState, t: float) -> Array:
	var shots := []
	var pose := ShipPhysics.pose_of(me, t)
	var aim_point := Vector3(target.x, AIM_HEIGHT, target.z)
	if Vector2(me.x, me.z).distance_to(Vector2(target.x, target.z)) > FIRE_RANGE:
		return shots
	for gun in ShipShape.cannon_count():
		if me.gun_reload[gun] > 0.0:
			continue
		var muzzle := pose * ShipShape.muzzle(gun, 0.0, 0.1)
		var sol := Gunnery.solve(muzzle, ShipPhysics.velocity_of(me), aim_point, ShipPhysics.velocity_of(target))
		if not sol.ok:
			continue
		var angles := Gunnery.to_gun_angles(pose, gun, sol.dir)
		if not angles.ok:
			continue
		shots.append({
			"gun": gun,
			"yaw": angles.yaw + rng.randf_range(-AIM_ERROR_YAW, AIM_ERROR_YAW) * error_scale,
			"pitch": angles.pitch + rng.randf_range(-AIM_ERROR_PITCH, AIM_ERROR_PITCH) * error_scale,
		})
	return shots

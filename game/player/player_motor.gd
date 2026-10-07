class_name PlayerMotor
extends RefCounted
## Movement rules for a pirate on foot or in the water, free of nodes so they are easy to test.
## Velocities are in whatever frame the player is in (ship frame on board, world otherwise).

const WALK := 4.5
const RUN := 7.0
const SWIM := 3.0
const JUMP := 5.5
const GRAVITY := 15.0
const GROUND_ACCEL := 40.0
const AIR_ACCEL := 8.0
const WATER_ACCEL := 10.0
## While swimming the feet hang this far below the surface, keeping the eyes just above it.
const FLOAT_DEPTH := 1.25
## Water deeper than this over your feet and you swim instead of wading.
const SWIM_DEPTH := 0.9


## `wish`: x = strafe right, y = forward, each -1..1. `yaw`: heading, 0 faces -Z.
static func wish_direction(wish: Vector2, yaw: float) -> Vector3:
	var v := Vector3(wish.x, 0.0, -wish.y)
	if v.length_squared() > 1.0:
		v = v.normalized()
	return Basis(Vector3.UP, yaw) * v


static func walk(
	velocity: Vector3, wish: Vector2, yaw: float, run: bool, on_floor: bool, jump: bool, dt: float,
	speed_scale := 1.0
) -> Vector3:
	var target := wish_direction(wish, yaw) * (RUN if run else WALK) * speed_scale
	var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, accel * dt)
	var y := velocity.y
	if on_floor:
		y = JUMP if jump else -0.1
	else:
		y -= GRAVITY * dt
	return Vector3(flat.x, y, flat.z)


static func swim(
	velocity: Vector3, wish: Vector2, yaw: float, feet_y: float, surface_y: float, dt: float,
	speed_scale := 1.0
) -> Vector3:
	var target := wish_direction(wish, yaw) * SWIM * speed_scale
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, WATER_ACCEL * dt)
	# Bob toward floating depth; the lerp soaks up the speed of a fall into the sea.
	var rise := clampf((surface_y - FLOAT_DEPTH - feet_y) * 3.0, -4.0, 2.5)
	var y := lerpf(velocity.y, rise, minf(1.0, 6.0 * dt))
	return Vector3(flat.x, y, flat.z)


static func is_swimming(feet_y: float, surface_y: float) -> bool:
	return feet_y < surface_y - SWIM_DEPTH

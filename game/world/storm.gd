class_name Storm
extends RefCounted
## One storm roams the sea on a slow loop, worked out from the shared server clock so every
## player sees it in the same place. It is only weather for now: rain, gloom and lightning, with
## no effect on the waves or the ships.

const RADIUS := 150.0
## How long the storm takes to go once round its loop.
const LOOP_TIME := 2400.0
## How far out of the storm the gloom starts, as a fraction of RADIUS.
const EDGE := 1.5
## Lightning: one chance per FLASH_SLOT seconds.
const FLASH_SLOT := 3.0
const FLASH_LENGTH := 0.18

## For screenshots: pins the storm's centre here instead of letting it roam.
static var pin := Vector2.INF


## The storm's centre on the sea at server time `t`: a wide figure of eight through the islands.
static func centre(t: float) -> Vector2:
	if pin != Vector2.INF:
		return pin
	var a := TAU * t / LOOP_TIME + 1.3
	return Vector2(sin(a) * 420.0, sin(a * 2.0) * 260.0 - 150.0)


## 1 deep inside the storm, falling to 0 at its edge (EDGE x RADIUS from the centre).
static func amount(pos: Vector2, t: float) -> float:
	var d := pos.distance_to(centre(t)) / RADIUS
	return 1.0 - smoothstep(0.7, EDGE, d)


## Whether lightning is striking at time `t`, and where (as an offset from the centre).
## Same answer on every client, since it only depends on the clock.
static func flash(t: float) -> Dictionary:
	var slot := floori(t / FLASH_SLOT)
	var r := _hash(slot)
	var start := slot * FLASH_SLOT + r * (FLASH_SLOT - FLASH_LENGTH)
	var on := r > 0.35 and t >= start and t < start + FLASH_LENGTH
	var a := _hash(slot + 7919) * TAU
	var off := Vector2(cos(a), sin(a)) * _hash(slot + 104729) * RADIUS * 0.8
	return {"on": on, "offset": off, "seed": slot}


static func _hash(n: int) -> float:
	var x := sin(float(n) * 12.9898) * 43758.5453
	return x - floorf(x)

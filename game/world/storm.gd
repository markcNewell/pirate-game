class_name Storm
extends RefCounted
## One storm roams the sea on a slow loop, worked out from the shared server clock so every
## player sees it in the same place. Inside it the waves grow, the wind swirls and gusts, and
## lightning can strike a ship (the server decides strikes; see docs/specs/2026-10-07-storm.md).

const RADIUS := 150.0
## How long the storm takes to go once round its loop.
const LOOP_TIME := 2400.0
## How far out of the storm the gloom starts, as a fraction of RADIUS.
const EDGE := 1.5
## Lightning: one chance per FLASH_SLOT seconds.
const FLASH_SLOT := 3.0
const FLASH_LENGTH := 0.18
## Waves at the heart are this much higher again (2.6 times in all).
const WAVE_GAIN := 1.6
## At the heart the wind turns this far from the open-sea wind toward swirling round the centre.
const SWIRL := 0.7
## Chance that a flash strikes a ship deep in the storm, and how deep "deep" is.
const STRIKE_CHANCE := 0.34
const STRIKE_DEPTH := 0.5

## Off for calm test seas (--calm); the server tells clients, so everyone's waves agree.
static var enabled := true

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
	if not enabled:
		return 0.0
	var d := pos.distance_to(centre(t)) / RADIUS
	return 1.0 - smoothstep(0.7, EDGE, d)


## How much higher than usual the waves are at a point: 1 outside the storm.
static func wave_factor(x: float, z: float, t: float) -> float:
	return 1.0 + WAVE_GAIN * amount(Vector2(x, z), t)


## The wind's strength in the storm, wandering smoothly between 0.5 and 1.5.
static func gust(t: float) -> float:
	return 1.0 + 0.5 * sin(t * 0.9 + 2.0 * sin(t * 0.37)) * (0.6 + 0.4 * sin(t * 0.53 + 1.0))


## The wind at a point: the open-sea direction `base` (a unit vector) bent toward swirling
## anticlockwise round the storm's centre, with length = its strength (1 outside the storm).
static func wind(pos: Vector2, t: float, base: Vector2) -> Vector2:
	var s := amount(pos, t)
	if s <= 0.0:
		return base
	var from_centre := pos - centre(t)
	var swirl := Vector2(from_centre.y, -from_centre.x).normalized() if from_centre.length() > 1.0 else base
	return base.lerp(swirl, SWIRL * s).normalized() * lerpf(1.0, gust(t), s)


## Whether the flash in slot `seed` strikes a ship (if one is deep enough in the storm).
static func strikes(seed: int) -> bool:
	return _hash(seed + 31337) < STRIKE_CHANCE


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

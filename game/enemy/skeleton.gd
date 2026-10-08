class_name Skeleton
extends RefCounted
## A skeleton on foot: where it stands, its health, and its simple mind. Island skeletons live
## in world coordinates and keep to dry land; ship skeletons live in their ship's frame and keep
## to its decks. The server steps them; snapshots carry them to clients.

const HEALTH := 60
const SPEED := 3.0
const CHASE_RANGE := 30.0
const SWING_REACH := 1.8
const SWING_DAMAGE := 20
const SWING_COOLDOWN := 1.3
## Stay this far above the waves at the shoreline.
const SHORE := 0.35
const CORPSE_TIME := 2.0
## The sergeant's shield covers this far either side of straight ahead (radians).
const SHIELD_ARC := 1.2217  # 70 degrees
const SHIELD_DOWN := 3.0

var id := 0
## -1 for an island skeleton (world coordinates), else the id of the ship it crews.
var frame := -1
var pos := Vector3.ZERO
var yaw := 0.0
var hp := HEALTH
## Island index it guards (island skeletons), for respawning the camp.
var home := -1
var cooldown := 0.0
## Time it fell, or -1 while it stands.
var fell := -1.0
var walking := false
## A bounty's skeleton captain: tougher, harder-hitting, slower, and he drops his skull.
var captain := false
## One of the Spanish dead (helmet and breastplate).
var spanish := false
## Server only: a Spanish thief that runs for a fallen captain's skull and carries it to
## `boat`; the item it holds (or -1); the crew whose chapter raised it (0 for none).
var thief := false
var holding := -1
var boat := Vector3.ZERO
var story_crew := 0
## A Spanish digger: it digs up `target_item` (a buried chest) for `dig_left` seconds, then runs
## it to `boat`. Digging shows to clients as its own state.
var digger := false
var target_item := -1
var dig_left := 0.0
var digging := false
## Sargento Calavera: his tower shield turns blows from in front while it is up; a shot knocks
## it aside until server time `shield_down_until`.
var sergeant := false
var shield_up := false
## Not a skeleton at all: a crab (the tales), small, quick and running from you; or Fat Gideon
## the smuggler, a living man who runs and gives up when beaten.
var crab := false
var gideon := false
## El Polvorín, the fort's gunner: throws bombs.
var bomber := false
var next_bomb := 0.0
var shield_down_until := -1.0
var damage := SWING_DAMAGE
var swing_cooldown := SWING_COOLDOWN


## Make this skeleton Sargento Calavera: big, slow, hard-hitting, behind a tower shield.
func make_sergeant() -> void:
	sergeant = true
	shield_up = true
	spanish = true
	hp = 300
	damage = 35
	swing_cooldown = 2.0


## Make this skeleton El Polvorín: huge, slow, and lobbing bombs.
func make_bomber() -> void:
	bomber = true
	spanish = true
	hp = 350
	damage = 30
	swing_cooldown = 2.2


## Make this skeleton a bounty's captain.
func make_captain() -> void:
	captain = true
	hp = Missions.CAPTAIN_HEALTH
	damage = Missions.CAPTAIN_DAMAGE
	swing_cooldown = Missions.CAPTAIN_COOLDOWN


func alive() -> bool:
	return fell < 0.0


func to_array() -> Array:
	var state := 2 if not alive() else (3 if digging else (1 if walking else 0))
	return [id, frame, pos.x, pos.y, pos.z, yaw, hp, state, 1 if captain else 0, look_code(), holding, 1 if shield_up else 0]


## What it wears, for clients: 0 a pirate's rags, 1 Spanish, 2 a Spanish digger, 3 the sergeant.
func look_code() -> int:
	if bomber:
		return 6
	if gideon:
		return 5
	if crab:
		return 4
	if sergeant:
		return 3
	if digger:
		return 2
	return 1 if spanish else 0


## Does the shield stop a blow struck from `from` (same frame)? Only from within SHIELD_ARC of
## straight ahead, and only while it is up.
func blocks(from: Vector3) -> bool:
	if not shield_up:
		return false
	var to := Vector2(from.x - pos.x, from.z - pos.z)
	if to.length() < 0.01:
		return true
	var facing := Vector2(-sin(yaw), -cos(yaw))
	return facing.dot(to.normalized()) > cos(SHIELD_ARC)


static func from_array(a: Array) -> Skeleton:
	var s := Skeleton.new()
	s.id = a[0]
	s.frame = a[1]
	s.pos = Vector3(a[2], a[3], a[4])
	s.yaw = a[5]
	s.hp = a[6]
	s.fell = 0.0 if int(a[7]) == 2 else -1.0
	s.walking = int(a[7]) == 1
	s.digging = int(a[7]) == 3
	s.captain = a.size() > 8 and int(a[8]) == 1
	var look := int(a[9]) if a.size() > 9 else 0
	s.spanish = look >= 1
	s.digger = look == 2
	s.sergeant = look == 3
	s.crab = look == 4
	s.gideon = look == 5
	s.bomber = look == 6
	s.holding = int(a[10]) if a.size() > 10 else -1
	s.shield_up = a.size() > 11 and int(a[11]) == 1
	return s


## Walk toward `target` (same frame) and report whether a swing lands this tick.
## `floor_at(x, z)` gives the floor height there, or NAN where the skeleton may not go.
func step(target: Variant, dt: float, floor_at: Callable) -> bool:
	cooldown = maxf(0.0, cooldown - dt)
	walking = false
	if not alive() or target == null:
		return false
	var goal: Vector3 = target
	var flat := Vector2(goal.x - pos.x, goal.z - pos.z)
	var dist := flat.length()
	if dist > CHASE_RANGE:
		return false
	yaw = atan2(-flat.x, -flat.y)
	if dist <= SWING_REACH:
		if cooldown <= 0.0 and absf(goal.y - pos.y) < 2.0:
			cooldown = swing_cooldown
			return true
		return false
	var step_len := minf(SPEED * dt, dist - SWING_REACH * 0.8)
	var next := Vector2(pos.x, pos.z) + flat / dist * step_len
	var ground: float = floor_at.call(next.x, next.y)
	if not is_nan(ground):
		pos = Vector3(next.x, ground, next.y)
		walking = true
	return false


## Walk straight for `goal` (same frame) at `speed`, right up to it; returns how far is left.
## Stops where the floor gives out (`floor_at` is NAN there), as `step` does.
func walk_to(goal: Vector3, dt: float, floor_at: Callable, speed := SPEED) -> float:
	cooldown = maxf(0.0, cooldown - dt)
	walking = false
	var flat := Vector2(goal.x - pos.x, goal.z - pos.z)
	var dist := flat.length()
	if dist < 0.05:
		return dist
	yaw = atan2(-flat.x, -flat.y)
	var step_len := minf(speed * dt, dist)
	var next := Vector2(pos.x, pos.z) + flat / dist * step_len
	var ground: float = floor_at.call(next.x, next.y)
	if is_nan(ground):
		return dist
	pos = Vector3(next.x, ground, next.y)
	walking = true
	return dist - step_len

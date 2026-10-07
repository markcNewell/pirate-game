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
var damage := SWING_DAMAGE
var swing_cooldown := SWING_COOLDOWN


## Make this skeleton a bounty's captain.
func make_captain() -> void:
	captain = true
	hp = Missions.CAPTAIN_HEALTH
	damage = Missions.CAPTAIN_DAMAGE
	swing_cooldown = Missions.CAPTAIN_COOLDOWN


func alive() -> bool:
	return fell < 0.0


func to_array() -> Array:
	var state := 2 if not alive() else (1 if walking else 0)
	return [id, frame, pos.x, pos.y, pos.z, yaw, hp, state, 1 if captain else 0]


static func from_array(a: Array) -> Skeleton:
	var s := Skeleton.new()
	s.id = a[0]
	s.frame = a[1]
	s.pos = Vector3(a[2], a[3], a[4])
	s.yaw = a[5]
	s.hp = a[6]
	s.fell = 0.0 if int(a[7]) == 2 else -1.0
	s.walking = int(a[7]) == 1
	s.captain = a.size() > 8 and int(a[8]) == 1
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

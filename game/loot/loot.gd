class_name Loot
extends RefCounted
## A thing in the world you can find, carry or open: a treasure chest or a supply barrel.
## The server owns every item; snapshots carry all but the buried ones.

enum Kind { CHEST, BARREL }
enum State { BURIED, GROUND, FLOATING, CARRIED, ON_SHIP }

const CHEST_NAMES := ["castaway's chest", "seafarer's chest", "captain's chest"]
## Floating loot sinks out of sight after this long (s).
const FLOAT_LIFE := 600.0

var id := 0
var kind := Kind.CHEST
var state := State.GROUND
## World position, or ship-frame position when ON_SHIP; ignored while CARRIED.
var pos := Vector3.ZERO
var yaw := 0.0
var carrier := -1
var value := 0
## Server only: when it started floating.
var born := 0.0


static func chest_tier(gold: int) -> int:
	if gold >= 450:
		return 2
	if gold >= 200:
		return 1
	return 0


func label() -> String:
	return CHEST_NAMES[chest_tier(value)] if kind == Kind.CHEST else "supply barrel"


func to_array() -> Array:
	return [id, kind, state, pos.x, pos.y, pos.z, yaw, carrier, value]


static func from_array(a: Array) -> Loot:
	var l := Loot.new()
	l.id = a[0]
	l.kind = a[1]
	l.state = a[2]
	l.pos = Vector3(a[3], a[4], a[5])
	l.yaw = a[6]
	l.carrier = a[7]
	l.value = a[8]
	return l

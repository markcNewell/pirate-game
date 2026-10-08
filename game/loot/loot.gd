class_name Loot
extends RefCounted
## A thing in the world you can find, carry or open: a treasure chest, a supply barrel, a
## skeleton captain's skull (bounties) or a crate of cargo. The server owns every item;
## snapshots carry all but the buried ones.

enum Kind { CHEST, BARREL, SKULL, CRATE, COCONUT, PLANKS, OIL, CANNON, BRONZE, BRINE, BARRICADE }
## HELD: in a skeleton's arms (`carrier` is the skeleton's id).
enum State { BURIED, GROUND, FLOATING, CARRIED, ON_SHIP, HELD }

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
## The ship it is stowed on (ON_SHIP).
var ship := -1
## A crate's goods (Missions.GOODS), else 0.
var variant := 0
## A crate that has been in the sea: it pays less.
var soaked := false
## Server only: breaks if put down anywhere but a ship's deck (the Governor's tea).
var fragile := false
## Server only: when it started floating.
var born := 0.0


static func chest_tier(gold: int) -> int:
	if gold >= 450:
		return 2
	if gold >= 200:
		return 1
	return 0


func label() -> String:
	match kind:
		Kind.CHEST:
			return CHEST_NAMES[chest_tier(value)]
		Kind.SKULL:
			return "captain's skull"
		Kind.CRATE:
			if variant == Missions.HUESO:
				return "rattling crate"
			return "%scrate of %s" % ["soaked " if soaked else "", Missions.GOODS[variant % Missions.GOODS.size()]]
		Kind.COCONUT:
			return "coconut with a face"
		Kind.PLANKS:
			return "bundle of planks"
		Kind.OIL:
			return "jar of lamp oil"
		Kind.CANNON:
			return "cannon"
		Kind.BRONZE:
			return "piece of drowned bell"
		Kind.BRINE:
			return "barrel of brine"
		Kind.BARRICADE:
			return "barricade"
	return "supply barrel"


## Carried in both arms, like a chest (everything but a barrel, which is opened where it lies).
func carried() -> bool:
	return kind != Kind.BARREL


func to_array() -> Array:
	return [id, kind, state, pos.x, pos.y, pos.z, yaw, carrier, value, ship, variant, 1 if soaked else 0]


static func from_array(a: Array) -> Loot:
	var l := Loot.new()
	l.id = a[0]
	l.kind = a[1]
	l.state = a[2]
	l.pos = Vector3(a[3], a[4], a[5])
	l.yaw = a[6]
	l.carrier = a[7]
	l.value = a[8]
	l.ship = a[9]
	if a.size() > 11:
		l.variant = a[10]
		l.soaked = int(a[11]) == 1
	return l

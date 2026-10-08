class_name StoryObject
extends RefCounted
## A thing a story chapter puts in the world for everyone to see: a green fire on a grave, a
## journal lying on the sand, the Spanish rowing boat drawn up on a beach. The server owns them;
## snapshots carry them.

## FIRE a green grave fire, BOOK a journal, BOAT the Spanish rowing boat, GRAVE an open (1) or
## salted (0) grave, KEG a powder keg (2 while its fuse burns), STORE the powder store's
## sailcloth and rocks, BONFIRE a camp's great fire (state: buckets still to douse), CAMP the dig
## camp's palisade and tents, BOTTLE a letter bobbing in the sea.
## Act II: ISABEL Isabel herself (in her boat, or on a ship's deck: `ship`), WRECK the half-sunk
## San Telmo, BELL a drowned bell (1 hanging, 0 shot down), SEARCH a crate to search, GATE the
## fort's gate (1 shut, 0 blown), GUN a fort tower gun (hits left before it is silenced), CELL and
## VAULT the fort's doors (1 shut, 0 open), BOMB El Polvorín's bomb (fizzing).
enum Kind { FIRE, BOOK, BOAT, GRAVE, KEG, STORE, BONFIRE, CAMP, BOTTLE, ISABEL, WRECK, BELL, SEARCH, GATE, GUN, CELL, VAULT, BOMB }

var id := 0
var kind := Kind.FIRE
## World position (on the ground).
var pos := Vector3.ZERO
var yaw := 0.0
## A fire: 1 while it burns, 0 once doused.
var state := 1
## The ship whose deck it stands on (pos is then in the ship's frame), or -1.
var ship := -1
## Server only: the crew whose chapter made it.
var crew := 0


func to_array() -> Array:
	return [id, kind, pos.x, pos.y, pos.z, yaw, state, ship]


static func from_array(a: Array) -> StoryObject:
	var o := StoryObject.new()
	o.id = a[0]
	o.kind = a[1]
	o.pos = Vector3(a[2], a[3], a[4])
	o.yaw = a[5]
	o.state = a[6]
	o.ship = int(a[7]) if a.size() > 7 else -1
	return o

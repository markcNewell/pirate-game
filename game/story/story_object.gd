class_name StoryObject
extends RefCounted
## A thing a story chapter puts in the world for everyone to see: a green fire on a grave, a
## journal lying on the sand, the Spanish rowing boat drawn up on a beach. The server owns them;
## snapshots carry them.

## FIRE a green grave fire, BOOK a journal, BOAT the Spanish rowing boat, GRAVE an open (1) or
## salted (0) grave, KEG a powder keg (2 while its fuse burns), STORE the powder store's
## sailcloth and rocks, BONFIRE a camp's great fire (state: buckets still to douse), CAMP the dig
## camp's palisade and tents, BOTTLE a letter bobbing in the sea.
enum Kind { FIRE, BOOK, BOAT, GRAVE, KEG, STORE, BONFIRE, CAMP, BOTTLE }

var id := 0
var kind := Kind.FIRE
## World position (on the ground).
var pos := Vector3.ZERO
var yaw := 0.0
## A fire: 1 while it burns, 0 once doused.
var state := 1
## Server only: the crew whose chapter made it.
var crew := 0


func to_array() -> Array:
	return [id, kind, pos.x, pos.y, pos.z, yaw, state]


static func from_array(a: Array) -> StoryObject:
	var o := StoryObject.new()
	o.id = a[0]
	o.kind = a[1]
	o.pos = Vector3(a[2], a[3], a[4])
	o.yaw = a[5]
	o.state = a[6]
	return o

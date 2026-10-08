class_name Deeds
extends RefCounted
## Long goals that earn a title (docs/specs/2026-10-08-story.md, "Deeds"): douse fifty green
## fires, sink twenty-five Spanish galleons... Counted per pirate in profile.deeds, whatever
## crew they sail with. Pure data; ServerSim counts and awards.

## [id, what is counted, how many, the title it earns, the look it gives (a Shop or Shipwright
## key: a gift, never sold)]
const LIST := [
	["fires", "Green fires doused", 50, "Firewatch", "dye11"],
	["skeletons", "The dead felled", 500, "Bonebreaker", "hull6"],
	["galleons", "Spanish galleons sunk", 25, "Scourge of the Raven", "flag6"],
	["ghosts", "Ghost galleons sunk", 10, "Ghost-Sinker", "sails8"],
	["skulls", "Skulls laid to rest with Wren", 100, "Friend of the Lantern", "dye13"],
	["chests", "Chests sold to Silas", 100, "Silas's Favourite", "dye12"],
	["crates", "Crates delivered", 200, "Merrow's Own Merchant", "flag7"],
	["heart", "The Heart carried into the Maw", 1, "Heart-Carrier", "sails9"],
]


static func find(id: String) -> Array:
	for d: Array in LIST:
		if d[0] == id:
			return d
	return []


## The name of a deed's gift ("Ember shirt dye", "Ghost-green sails"...).
static func gift_name(item_key: String) -> String:
	var i := Shop.index_of(item_key)
	if i >= 0:
		return "%s %s" % [Shop.ITEMS[i][2], ["outfit", "shirt dye"][Shop.ITEMS[i][0]]]
	i = Shipwright.index_of(item_key)
	if i >= 0:
		return "%s %s" % [Shipwright.ITEMS[i][2], ["sails", "hull paint", "flag", "figurehead"][Shipwright.ITEMS[i][0]]]
	return item_key


static func count(profile: Dictionary, id: String) -> int:
	return int(profile.get("deeds", {}).get(id, 0))


## The deeds page: one line each, done or how far along.
static func page(deeds: Dictionary) -> String:
	var lines: Array[String] = []
	for d: Array in LIST:
		var n := mini(int(deeds.get(d[0], 0)), int(d[2]))
		if n >= int(d[2]):
			lines.append("%s: done. Title: %s; %s" % [d[1], d[3], gift_name(d[4])])
		else:
			lines.append("%s: %d of %d (title: %s; %s)" % [d[1], n, d[2], d[3], gift_name(d[4])])
	return "\n\n".join(lines)

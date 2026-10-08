class_name Deeds
extends RefCounted
## Long goals that earn a title (docs/specs/2026-10-08-story.md, "Deeds"): douse fifty green
## fires, sink twenty-five Spanish galleons... Counted per pirate in profile.deeds, whatever
## crew they sail with. Pure data; ServerSim counts and awards.

## [id, what is counted, how many, the title it earns]
const LIST := [
	["fires", "Green fires doused", 50, "Firewatch"],
	["skeletons", "The dead felled", 500, "Bonebreaker"],
	["galleons", "Spanish galleons sunk", 25, "Scourge of the Raven"],
	["ghosts", "Ghost galleons sunk", 10, "Ghost-Sinker"],
	["skulls", "Skulls laid to rest with Wren", 100, "Friend of the Lantern"],
	["chests", "Chests sold to Silas", 100, "Silas's Favourite"],
	["crates", "Crates delivered", 200, "Merrow's Own Merchant"],
	["heart", "The Heart carried into the Maw", 1, "Heart-Carrier"],
]


static func find(id: String) -> Array:
	for d: Array in LIST:
		if d[0] == id:
			return d
	return []


static func count(profile: Dictionary, id: String) -> int:
	return int(profile.get("deeds", {}).get(id, 0))


## The deeds page: one line each, done or how far along.
static func page(deeds: Dictionary) -> String:
	var lines: Array[String] = []
	for d: Array in LIST:
		var n := mini(int(deeds.get(d[0], 0)), int(d[2]))
		if n >= int(d[2]):
			lines.append("%s: done. Title: %s" % [d[1], d[3]])
		else:
			lines.append("%s: %d of %d (title: %s)" % [d[1], n, d[2], d[3]])
	return "\n\n".join(lines)

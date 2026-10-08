class_name Shipwright
extends RefCounted
## Old Hobb's yard on Port Merrow's pier: looks for a crew's ship, never speed or strength
## (docs/specs/2026-10-08-m19-shipwright.md), and the story's trophies that go up on it. Pure
## rules: ServerSim sells and fits, ShipView paints.

enum Kind { SAILS, HULL, FLAG, FIGUREHEAD }
## Trophies as bits, for the ship_look event.
enum Trophy { HALBERD = 1, RAVEN = 2, LANTERN = 4 }

## Each: [kind, which, name, price]. Which 0 of each kind is the crew's own colours, everyone's;
## a price of 0 otherwise is a deed's gift (Deeds.LIST), never sold.
const ITEMS := [
	[Kind.SAILS, 0, "The crew's own", 0],
	[Kind.SAILS, 1, "Bone white", 500],
	[Kind.SAILS, 2, "Crimson", 500],
	[Kind.SAILS, 3, "Sky", 500],
	[Kind.SAILS, 4, "Saffron", 600],
	[Kind.SAILS, 5, "Sea-green", 600],
	[Kind.SAILS, 6, "Royal purple", 800],
	[Kind.SAILS, 7, "Black", 900],
	[Kind.SAILS, 8, "Ghost-green", 0],
	[Kind.SAILS, 9, "Ash grey", 0],
	[Kind.HULL, 0, "The crew's own", 0],
	[Kind.HULL, 1, "Tar black", 800],
	[Kind.HULL, 2, "Navy", 800],
	[Kind.HULL, 3, "Oxblood", 800],
	[Kind.HULL, 4, "Sea-green", 900],
	[Kind.HULL, 5, "Ivory and gold", 1500],
	[Kind.HULL, 6, "Bone and black", 0],
	[Kind.FLAG, 0, "The crew's own", 0],
	[Kind.FLAG, 1, "Crimson", 300],
	[Kind.FLAG, 2, "Navy", 300],
	[Kind.FLAG, 3, "Bottle green", 300],
	[Kind.FLAG, 4, "Purple", 300],
	[Kind.FLAG, 5, "Bone", 300],
	[Kind.FLAG, 6, "Raven gold", 0],
	[Kind.FLAG, 7, "Merrow blue", 0],
	[Kind.FIGUREHEAD, 0, "The mermaid", 0],
	[Kind.FIGUREHEAD, 1, "Gilded lion", 1200],
	[Kind.FIGUREHEAD, 2, "Sea serpent", 1400],
	[Kind.FIGUREHEAD, 3, "Leaping dolphin", 1000],
]
## The ship part for each figurehead (ShipView); the raven is a story trophy, not for sale.
const FIGUREHEADS: Array[String] = ["figurehead", "figurehead_lion", "figurehead_serpent", "figurehead_dolphin"]
## Which of a ship's looks is which: [sails, hull, flag, figurehead].
const LOOKS := 4
const SAILS: Array[Color] = [
	Color(), Color("f4efe2"), Color("c8382e"), Color("6aa8e8"), Color("e8b020"), Color("3aa88a"),
	Color("6a3a9a"), Color("2a2630"), Color("8adca0"), Color("6a6460"),
]
const HULLS: Array[Dictionary] = [
	{},
	{"hull": Color("3a3432"), "hull_dark": Color("26221f"), "bottom": Color("181514")},
	{"hull": Color("2e4a7a"), "hull_dark": Color("1e3256"), "bottom": Color("16243e")},
	{"hull": Color("7a2a24"), "hull_dark": Color("561c18"), "bottom": Color("3e1412")},
	{"hull": Color("2e7a6a"), "hull_dark": Color("1e564a"), "bottom": Color("143e36")},
	{"hull": Color("efe6d0"), "hull_dark": Color("cfc2a2"), "bottom": Color("3a2a22"), "stripe": Color("ffd23a")},
	{"hull": Color("e8e0cc"), "hull_dark": Color("2a2622"), "bottom": Color("1a1614"), "stripe": Color("1a1614")},
]
const FLAGS: Array[Color] = [
	Color(), Color("a8221c"), Color("1a2c5a"), Color("1a4a26"), Color("4a1e6a"), Color("e8e0cc"),
	Color("d8a83a"), Color("3c6fd6"),
]
## The chapter that earns each trophy: the Sergeant's halberd (Act I's finale), the Admiral's
## raven figurehead (Act IV's) and Linnet's green lantern (The Other Lantern's end).
const TROPHIES := {Trophy.HALBERD: "a6", Trophy.RAVEN: "d6", Trophy.LANTERN: "t11"}
const REACH := 3.5


## The ITEMS index for a key such as "sails7", or -1.
static func index_of(item_key: String) -> int:
	for i in ITEMS.size():
		if key(i) == item_key:
			return i
	return -1


static func key(i: int) -> String:
	return "%s%d" % [["sails", "hull", "flag", "figurehead"][ITEMS[i][0]], ITEMS[i][1]]


## The figurehead a ship carries: one fitted at Hobb's, else the Admiral's raven if someone
## aboard earned it, else the mermaid she was built with.
static func figurehead_part(looks: Array, trophy_bits: int) -> String:
	var fitted := int(looks[Kind.FIGUREHEAD]) if looks.size() > Kind.FIGUREHEAD else 0
	if fitted > 0 and fitted < FIGUREHEADS.size():
		return FIGUREHEADS[fitted]
	return "figurehead_raven" if trophy_bits & Trophy.RAVEN else FIGUREHEADS[0]


## Does a pirate have this look: bought, or the crew's own (everyone's)?
static func has(profile: Dictionary, i: int) -> bool:
	return ITEMS[i][1] == 0 or profile.get("owned", []).has(key(i))


## A crew's ship colours: its crew's, with the fitted looks ([sails, hull, flag]) over them.
static func palette(crew: int, looks: Array) -> Dictionary:
	var p: Dictionary = Toon.crew_palette(crew).duplicate()
	if looks.size() < 3:
		return p
	if int(looks[0]) > 0 and int(looks[0]) < SAILS.size():
		p["sail"] = SAILS[int(looks[0])]
	if int(looks[1]) > 0 and int(looks[1]) < HULLS.size():
		p.merge(HULLS[int(looks[1])], true)
	if int(looks[2]) > 0 and int(looks[2]) < FLAGS.size():
		p["flag"] = FLAGS[int(looks[2])]
	return p


## The trophies a crew's ship shows: every one earned by anyone in `chapter_lists`.
static func trophies(chapter_lists: Array) -> int:
	var bits := 0
	for bit: int in TROPHIES:
		for done: Array in chapter_lists:
			if done.has(TROPHIES[bit]):
				bits |= bit
				break
	return bits

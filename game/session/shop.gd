class_name Shop
extends RefCounted
## Big Martha's back room at the Drowned Rat: what gold buys. Looks only (outfits and dyes), so
## nobody can buy their way stronger (docs/specs/2026-10-08-story.md, decision 1). Pure rules:
## ServerSim sells, the HUD shows the counter, avatars wear what was bought.

enum Kind { OUTFIT, DYE }

## The pirate outfits (Avatar looks 0-9) and the shirt dyes. Each: [kind, which, name, price];
## a price of 0 is a gift from the story, never sold (Silas's cap, from Penny's Hoard; the raven
## cloak, from the story's end).
const ITEMS := [
	[Kind.OUTFIT, 0, "Tricorn and waistcoat", 400],
	[Kind.OUTFIT, 1, "Bandana and eyepatch", 450],
	[Kind.OUTFIT, 2, "Captain's coat and bicorne", 1200],
	[Kind.OUTFIT, 3, "Headscarf and braces", 400],
	[Kind.OUTFIT, 4, "Straw hat and sash", 350],
	[Kind.OUTFIT, 5, "Knitted cap and beard", 450],
	[Kind.OUTFIT, 6, "Cavalier's feathered hat", 1000],
	[Kind.OUTFIT, 7, "The bruiser", 600],
	[Kind.OUTFIT, 8, "Silas's cabin-boy cap", 0],
	[Kind.OUTFIT, 9, "The Admiral's raven cloak", 0],
	[Kind.DYE, 0, "Crimson", 250],
	[Kind.DYE, 1, "Navy", 250],
	[Kind.DYE, 2, "Emerald", 250],
	[Kind.DYE, 3, "Violet", 250],
	[Kind.DYE, 4, "Saffron", 300],
	[Kind.DYE, 5, "Ivory", 300],
	[Kind.DYE, 6, "Midnight", 350],
	[Kind.DYE, 7, "Teal", 300],
	[Kind.DYE, 8, "Rust", 250],
	[Kind.DYE, 9, "Rose", 300],
]
const DYES: Array[Color] = [
	Color("d63c3c"), Color("3c6fd6"), Color("3cae5a"), Color("9a4fd0"), Color("e8b020"),
	Color("efe8d8"), Color("2a2a3a"), Color("2a9a9a"), Color("b0582a"), Color("e07aa0"),
]
const REACH := 3.5


## The ITEMS index for a key such as "outfit8", or -1.
static func index_of(item_key: String) -> int:
	for i in ITEMS.size():
		if key(i) == item_key:
			return i
	return -1


static func key(i: int) -> String:
	return "%s%d" % ["outfit" if ITEMS[i][0] == Kind.OUTFIT else "dye", ITEMS[i][1]]


## The look a pirate wears: their chosen outfit, or `fallback` (their place in the roster).
static func outfit_of(profile: Dictionary, fallback: int) -> int:
	return int(profile.get("look", -1)) if int(profile.get("look", -1)) >= 0 else fallback


## Their shirt colour: their chosen dye, or the roster colour for `fallback`.
static func shirt_of(dye: int, fallback: int) -> Color:
	return DYES[dye] if dye >= 0 and dye < DYES.size() else Avatar.SHIRTS[fallback % Avatar.SHIRTS.size()]

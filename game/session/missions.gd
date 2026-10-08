class_name Missions
extends RefCounted
## The three trading companies, their offers, reputation and the rules of each kind of mission
## (docs/specs/2026-10-07-m6-missions.md). Pure rules: ServerSim runs missions with them, the
## HUD and map describe them, and the tests check them.

enum Company { GOLD, SOULS, MERCHANT }
enum Kind { TREASURE, BOUNTY, CARGO, STORY }

const COMPANY_NAMES := ["Gilded Hand", "Lantern Order", "Merrow Traders"]
const COMPANY_COLOURS := [Color("ffd23a"), Color("9cff8a"), Color("7ab8ff")]
## Each company's kind of mission, by company.
const COMPANY_KIND := [Kind.TREASURE, Kind.BOUNTY, Kind.CARGO]

const LEVEL_POINTS := 300
const MAX_LEVEL := 5
## Reputation for finishing a mission, for each of its items handed in, and for any chest sold.
const FINISH_POINTS := 150
const ITEM_POINTS := 50
const CHEST_POINTS := 30

## By level (index 0 = level 1): treasure islands, bounty crew, cargo crates, pay factor.
const TREASURE_ISLANDS: Array[int] = [1, 1, 2, 2, 3]
const BOUNTY_CREW: Array[int] = [2, 3, 3, 4, 4]
const CARGO_CRATES: Array[int] = [1, 2, 2, 3, 3]
const PAY: Array[float] = [1.0, 1.2, 1.4, 1.6, 2.0]

## Gold before the pay factor.
const CHEST_GOLD := Vector2i(80, 320)
const SKULL_GOLD := Vector2i(250, 450)
const CRATE_GOLD := Vector2i(120, 200)

## The skeleton captain of a bounty.
const CAPTAIN_HEALTH := 200
const CAPTAIN_DAMAGE := 30
const CAPTAIN_COOLDOWN := 1.8
const CAPTAINS := [
	"Captain Grimbone", "Black-Eyed Bess", "Old Rattlejaw", "Captain Marrowdeep",
	"Salty Sal Skullface", "Captain Hollowbell",
]

## Cargo: time allowed, and what late or soaked crates pay (a fraction).
const CARGO_BASE_TIME := 360.0
const CARGO_TIME_PER_CRATE := 120.0
const LATE_PAY := 0.5
const SOAKED_PAY := 0.5
## What the crates hold (Loot.variant for a crate). Salt is the story's: Quill's crates for
## Gull Isle's graves.
const GOODS := ["rum", "silk", "spice", "salt"]
const SALT := 3
## The goods a cargo run may carry (not salt).
const CARGO_GOODS := 3


static func level(points: int) -> int:
	return clampi(1 + points / LEVEL_POINTS, 1, MAX_LEVEL)


static func pay(level_now: int) -> float:
	return PAY[clampi(level_now, 1, MAX_LEVEL) - 1]


static func cargo_time(crates: int) -> float:
	return CARGO_BASE_TIME + CARGO_TIME_PER_CRATE * crates


## What a crate pays when handed over: its value, halved if it arrives after the deadline.
static func crate_pay(value: int, now: float, deadline: float) -> int:
	return int(round(value * (LATE_PAY if now > deadline else 1.0)))


## Three offers, one per company, sized by the crew's level with each. `islands` are the
## islands missions may go to (not the outpost). `levels` holds a level per company. With
## `first`, every mission goes to that island first (tests).
static func make_offers(levels: Array, islands: Array[int], rng: RandomNumberGenerator, first := -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for company in COMPANY_NAMES.size():
		out.append(make_offer(company, int(levels[company]), islands, rng, first))
	return out


static func make_offer(company: int, lvl: int, islands: Array[int], rng: RandomNumberGenerator, first := -1) -> Dictionary:
	var kind: int = COMPANY_KIND[company]
	var i := clampi(lvl, 1, MAX_LEVEL) - 1
	var shuffled := islands.duplicate()
	for k in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t: int = shuffled[k]
		shuffled[k] = shuffled[j]
		shuffled[j] = t
	if first >= 0 and shuffled.has(first):
		shuffled.erase(first)
		shuffled.push_front(first)
	var offer := {"company": company, "kind": kind, "level": lvl, "pay": PAY[i]}
	match kind:
		Kind.TREASURE:
			var count := mini(TREASURE_ISLANDS[i], shuffled.size())
			offer.islands = shuffled.slice(0, count)
			offer.size = count
			var name: String = Islands.LAYOUT[offer.islands[0]].name
			offer.title = "The hoard of %s" % name if count == 1 else "A %d-island hoard" % count
			offer.gold = Vector2i(int(CHEST_GOLD.x * PAY[i]) * count, int(CHEST_GOLD.y * PAY[i]) * count)
		Kind.BOUNTY:
			offer.islands = [shuffled[0]]
			offer.size = BOUNTY_CREW[i]
			offer.captain = CAPTAINS[rng.randi() % CAPTAINS.size()]
			offer.title = "Bounty: %s" % offer.captain
			offer.gold = Vector2i(int(SKULL_GOLD.x * PAY[i]), int(SKULL_GOLD.y * PAY[i]))
		Kind.CARGO:
			offer.islands = [shuffled[0]]
			offer.size = CARGO_CRATES[i]
			offer.goods = rng.randi() % CARGO_GOODS
			offer.title = "%s for %s" % [GOODS[offer.goods].capitalize(), Islands.LAYOUT[offer.islands[0]].name]
			offer.gold = Vector2i(int(CRATE_GOLD.x * PAY[i]) * offer.size, int(CRATE_GOLD.y * PAY[i]) * offer.size)
	return offer


## One line describing an offer on the board.
static func describe(offer: Dictionary) -> String:
	var where: Array[String] = []
	for island: int in offer.islands:
		where.append(Islands.LAYOUT[island].name)
	match int(offer.kind):
		Kind.TREASURE:
			return "Dig up %d chest%s on %s" % [offer.size, "" if offer.size == 1 else "s", ", ".join(where)]
		Kind.BOUNTY:
			return "%s and %d skeletons on %s; bring back his skull" % [offer.captain, offer.size, where[0]]
		_:
			return "Carry %d crate%s of %s from Port Merrow to %s in %d minutes" % [
				offer.size, "" if offer.size == 1 else "s", GOODS[offer.goods], where[0], int(cargo_time(offer.size) / 60.0)]


## Offers over the network (the board): arrays of plain values.
static func offer_to_array(offer: Dictionary) -> Array:
	return [offer.company, offer.kind, offer.level, offer.title, offer.gold.x, offer.gold.y, describe(offer)]


static func offer_from_array(a: Array) -> Dictionary:
	return {"company": int(a[0]), "kind": int(a[1]), "level": int(a[2]), "title": str(a[3]),
		"gold": Vector2i(int(a[4]), int(a[5])), "text": str(a[6])}

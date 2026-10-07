class_name Progress
extends RefCounted
## Pirate levels, titles and what earns XP (docs/specs/2026-10-08-m7-pirates-life.md). Pure
## rules: levels show who you are and never make you stronger.

const MAX_LEVEL := 30
## Level n to n+1 takes BASE + STEP x n XP.
const BASE := 300
const STEP := 100

## Titles by the level they come at.
const TITLES := [
	[1, "Deckhand"], [3, "Swabbie"], [5, "Powder Monkey"], [8, "Able Seaman"], [11, "Bosun"],
	[14, "Quartermaster"], [18, "First Mate"], [22, "Captain"], [26, "Commodore"],
	[30, "Legend of the Isles"],
]

## XP for each thing (the story doc's table).
const XP_SKELETON := 10
const XP_SPANISH := 15
const XP_CAPTAIN := 50
const XP_PLAYER := 25
const XP_SKELETON_SHIP := 150
const XP_PLAYER_SHIP := 200
const XP_MISSION := 150
const XP_MISSION_ITEM := 50
## Knocking down the same pirate pays again only after this long (s).
const PLAYER_XP_COOLDOWN := 300.0

## The pirate level an act needs (index = act; 0 is the prologue).
const ACT_LEVEL: Array[int] = [1, 1, 5, 10, 14, 18]


## Total XP needed to reach `lvl`.
static func xp_for(lvl: int) -> int:
	var n := clampi(lvl, 1, MAX_LEVEL) - 1
	# Sum of BASE + STEP x k for k = 1..n.
	return BASE * n + STEP * n * (n + 1) / 2


static func level(xp: int) -> int:
	var lvl := 1
	while lvl < MAX_LEVEL and xp >= xp_for(lvl + 1):
		lvl += 1
	return lvl


## How far through the current level, 0..1 (1 at the top level).
static func level_fraction(xp: int) -> float:
	var lvl := level(xp)
	if lvl >= MAX_LEVEL:
		return 1.0
	var lo := xp_for(lvl)
	return float(xp - lo) / float(xp_for(lvl + 1) - lo)


## The level title for a level.
static func title_for(lvl: int) -> String:
	var out: String = TITLES[0][1]
	for t: Array in TITLES:
		if lvl >= int(t[0]):
			out = t[1]
	return out

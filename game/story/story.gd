class_name Story
extends RefCounted
## The Ash Fleet (docs/specs/2026-10-08-story.md): the people of Port Merrow, and the story's
## chapters as data. Each chapter is a list of steps of a few kinds; ServerSim runs them, the
## HUD describes them. Pure data and rules, the same on every machine.

enum Step { TALK, READ, DOUSE, BOUNTY }

## Who you can talk to. `where` names the Outpost function giving where they stand.
const PEOPLE := {
	"moll": {"name": "Moll Tinder", "what": "the lighthouse keeper"},
	"wren": {"name": "Mother Wren", "what": "the Lantern Order"},
	"silas": {"name": "Silas Penny", "what": "the Gilded Hand"},
	"quill": {"name": "Abel Quill", "what": "the Merrow Traders"},
}
## The order the people are numbered in over the network.
const PEOPLE_IDS: Array[String] = ["moll", "wren", "silas", "quill"]
const TALK_REACH := 3.2
## What each says when they have no chapter for you.
const CHATTER := {
	"moll": ["Moll Tinder", "Forty years on this light and I've never seen the sea so restless."],
	"wren": ["Mother Wren", "The dead are quiet tonight. I don't trust it."],
	"silas": ["Silas Penny", "Gold's gold, friend. Bring me chests and I'll give you coin for them."],
	"quill": ["Abel Quill", "Cargo on time, crates kept dry, and the ledger balances. That's all I ask."],
}
## What they say when your crew is already on a mission.
const BUSY := "Finish what you're about first, then come back to me."

const ACT_NAMES := ["Prologue", "Act I", "Act II", "Act III", "Act IV", "Act V"]
const COLOUR := Color("9cff8a")

## The chapters in story order. Lines are [speaker, text] pairs flattened; "intro" is said by
## the giver when the chapter starts. A TALK step's lines are said when you come back.
const CHAPTERS: Array[Dictionary] = [
	{
		"id": "p1", "act": 0, "title": "Strange Lights", "giver": "moll", "xp": 300, "gold": 150,
		"intro": [
			"Moll Tinder", "Three nights now. Green lights on Gull Isle, low down, like lanterns lying on the ground.",
			"Moll Tinder", "Nobody believes an old keeper. But you've a ship. Go and look, and come back and tell me I'm wrong.",
		],
		"steps": [
			{"kind": Step.READ, "island": 2, "title": "A Spanish sailor's journal", "text":
				"12th June. The Doctor had us digging all night again. Pirates' graves he wants, the older the better.\n\n" +
				"13th June. I saw it tonight. He lit the green fire on a grave and the bones sat up like a man woken early. Sanchez says the fire needs gold to burn, and a captain's skull to make a captain.\n\n" +
				"14th June. The Admiral wants a hundred captains. Tonight they go for the grave of Black-Eyed Bess, on the rock with the tall stacks.\n\n" +
				"15th June. The ones that sit up watch us while we dig. I think when we have dug enough, we will be next."},
			{"kind": Step.DOUSE, "island": 2, "fires": 1, "rise": 3},
			{"kind": Step.TALK, "who": "moll", "lines": [
				"Moll Tinder", "Spanish, you say. Digging up graves, and the dead getting up to help.",
				"Moll Tinder", "Then it's not my eyes that are going. Take that journal to Mother Wren on the beach. If anyone knows what wakes the dead, it's her.",
			]},
		],
	},
	{
		"id": "p2", "act": 0, "title": "Black-Eyed Bess", "giver": "wren", "xp": 400, "gold": 0,
		"intro": [
			"Mother Wren", "Show me. ...Green fire. I hoped I would never see its like again.",
			"Mother Wren", "'A captain's skull to make a captain.' They mean to wake Black-Eyed Bess on Parrot Rock. If they have, she is already walking.",
			"Mother Wren", "Beat her down, and bring me her skull before the Spanish take it to their boat. I'll see she sleeps.",
		],
		"steps": [
			{"kind": Step.BOUNTY, "island": 1, "captain": "Black-Eyed Bess", "crew": 0, "thieves": 2, "to": "wren", "lines": [
				"Mother Wren", "There. Hush now, Bess. Nobody will wake you again.",
				"Mother Wren", "Whoever this Doctor is, he has the Heart of Ash, or something like it. Gold for its fire and skulls for its captains.",
				"Mother Wren", "Silas will want to hear that someone's after his gold. Go and see him when you're ready.",
			]},
		],
	},
]


static func index_of(id: String) -> int:
	for i in CHAPTERS.size():
		if CHAPTERS[i].id == id:
			return i
	return -1


static func chapter(id: String) -> Dictionary:
	var i := index_of(id)
	return CHAPTERS[i] if i >= 0 else {}


static func person_name(who: String) -> String:
	return PEOPLE[who].name if PEOPLE.has(who) else who


## Where someone stands (world), on Port Merrow.
static func person_pos(who: String) -> Vector3:
	match who:
		"moll":
			return Outpost.keeper_pos()
		"wren":
			return Outpost.mystic_pos()
		"silas":
			return Outpost.merchant_pos()
		"quill":
			return Outpost.agent_pos()
	return Vector3.ZERO


## May a crew start chapter `i`, given each pirate's finished chapters? The first always; any
## other once someone aboard has finished the one before it.
static func open_for(i: int, done_lists: Array) -> bool:
	if i <= 0:
		return i == 0
	var before: String = CHAPTERS[i - 1].id
	for done: Array in done_lists:
		if done.has(before):
			return true
	return false


## The crew's next chapter: the first that is open and not yet finished by all of them, or -1.
static func next_for(done_lists: Array) -> int:
	for i in CHAPTERS.size():
		if not open_for(i, done_lists):
			return -1
		for done: Array in done_lists:
			if not done.has(CHAPTERS[i].id):
				return i
	return -1


## The chapter `who` would start for a crew: their first open one not finished by everyone,
## else the last open one they give (to play again), or -1.
static func offered_by(who: String, done_lists: Array) -> int:
	var replay := -1
	for i in CHAPTERS.size():
		if CHAPTERS[i].giver != who or not open_for(i, done_lists):
			continue
		for done: Array in done_lists:
			if not done.has(CHAPTERS[i].id):
				return i
		replay = i
	return replay


## The mission card's line for a step: `lit` green fires still burning and `standing` dead
## still up, for a douse.
static func step_text(step: Dictionary, lit := 0, standing := 0) -> String:
	match int(step.kind):
		Step.TALK:
			return "Talk to %s at Port Merrow" % person_name(step.who)
		Step.READ:
			return "Search %s for what the lights were" % Islands.LAYOUT[step.island].name
		Step.DOUSE:
			if lit > 0:
				return "Douse the green fire on %s (fill your bucket in the sea)" % Islands.LAYOUT[step.island].name
			return "Fell the dead (%d left)" % standing
		Step.BOUNTY:
			return "Fell %s on %s and bring the skull to %s" % [step.captain, Islands.LAYOUT[step.island].name, person_name(step.to)]
	return ""

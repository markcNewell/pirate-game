class_name Story
extends RefCounted
## The Ash Fleet (docs/specs/2026-10-08-story.md): the people of Port Merrow, and the story's
## chapters as data. Each chapter is a list of steps of a few kinds; ServerSim runs them, the
## HUD describes them. Pure data and rules, the same on every machine.

enum Step { TALK, READ, DOUSE, BOUNTY, DIG_RACE, SALT, KEGS, SINK, VIGIL, BONFIRE, BOSS }

## Who you can talk to. `where` names the Outpost function giving where they stand.
const PEOPLE := {
	"moll": {"name": "Moll Tinder", "what": "the lighthouse keeper"},
	"wren": {"name": "Mother Wren", "what": "the Lantern Order"},
	"silas": {"name": "Silas Penny", "what": "the Gilded Hand"},
	"quill": {"name": "Abel Quill", "what": "the Merrow Traders"},
	"jonah": {"name": "Jonah Salt", "what": "a castaway trader, visiting"},
}
## The order the people are numbered in over the network.
const PEOPLE_IDS: Array[String] = ["moll", "wren", "silas", "quill", "jonah"]
const TALK_REACH := 3.2
## What each says when they have no chapter for you.
const CHATTER := {
	"moll": ["Moll Tinder", "Forty years on this light and I've never seen the sea so restless."],
	"wren": ["Mother Wren", "The dead are quiet tonight. I don't trust it."],
	"silas": ["Silas Penny", "Gold's gold, friend. Bring me chests and I'll give you coin for them."],
	"quill": ["Abel Quill", "Cargo on time, crates kept dry, and the ledger balances. That's all I ask."],
	"jonah": ["Jonah Salt", "Captain Coco says hello. He doesn't say much else. He's a coconut."],
}
## What a giver says when their chapter wants the night.
const WAIT_FOR_DUSK := "Not in daylight. Come back to me when the sun is down."
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
	{
		"id": "a1", "act": 1, "title": "Dig Faster", "giver": "silas", "xp": 400, "gold": 0,
		"intro": [
			"Silas Penny", "Mother Wren sent you? Then you've heard. Somebody is digging up the old hoards, and it isn't my customers.",
			"Silas Penny", "Three hoards on Cutlass Cay that I know of. The Spanish will know of them too by now. Get there first.",
			"Silas Penny", "Every chest you bring me is a chest their fire doesn't eat. And I pay well. Go!",
		],
		"steps": [
			{"kind": Step.DIG_RACE, "island": 0, "chests": 3, "to": "silas", "lines": [
				"Silas Penny", "Not all of them, but enough. They dig like men with a deadline.",
				"Silas Penny", "Quill was asking after you. Something about salt. Don't let him bore you to death.",
			]},
		],
	},
	{
		"id": "a2", "act": 1, "title": "Salt the Earth", "giver": "quill", "xp": 400, "gold": 150,
		"intro": [
			"Abel Quill", "I read Wren's notes. Fascinating. And, if I may say, a question of inventory.",
			"Abel Quill", "Salt keeps the dead in the ground. Gull Isle's old graveyard has three graves already open. I have three crates of salt on the pier.",
			"Abel Quill", "Carry them over, pour one on each open grave, and do try not to drop them in the sea. Salt is not cheap.",
		],
		"steps": [
			{"kind": Step.SALT, "island": 2, "graves": 3, "rise_every": 15.0, "max_up": 4, "lines": [
				"Abel Quill", "Three crates, three graves, no losses. Do you know how rare that is?",
				"Abel Quill", "Jonah Salt came in on the morning tide with a story about a black ship. You'll find him on the beach.",
			]},
		],
	},
	{
		"id": "a3", "act": 1, "title": "Captain Coco's Warning", "giver": "jonah", "xp": 450, "gold": 100,
		"intro": [
			"Jonah Salt", "A black ship, I tell you, with a gold bird on her sails. Anchored off Cutlass Cay three nights back.",
			"Jonah Salt", "Men rowing barrels ashore. Gunpowder, Captain Coco reckons, and he's never wrong about barrels.",
			"Jonah Salt", "I wrote down where they went. Don't lose it, it's on the back of my last letter home.",
		],
		"steps": [
			{"kind": Step.KEGS, "island": 0, "kegs": 4, "title": "Jonah's directions", "text":
				"Where the two grey rocks lean together like old friends, on the side the sun goes down, they stacked the barrels under a sailcloth.\n\nThey went in and out all night. Captain Coco says: barrels go BANG. Mind your eyebrows."},
			{"kind": Step.READ, "where": "here", "title": "Orders, singed", "text":
				"To the dig parties of the Isles.\n\nPowder for the camps, as the Doctor asks. Every coin found goes to the Fort, every captain's grave to the Doctor. The Heart grows. Do not let the pirates see the ships.\n\nA. de C., Admiral of the Isles"},
			{"kind": Step.TALK, "who": "jonah", "lines": [
				"Jonah Salt", "A. de C.? Admiral of the Isles? There hasn't been an admiral out here since the treasure fleet went down. Thirty years.",
				"Jonah Salt", "Silas will want to see this. He was a boy when that fleet sank. He remembers.",
			]},
		],
	},
	{
		"id": "a4", "act": 1, "title": "The Raven Sails", "giver": "silas", "xp": 500, "gold": 200,
		"intro": [
			"Silas Penny", "Admiral of the Isles. I hoped never to hear that again. The fleet went down on the Black Reef the year I first went to sea.",
			"Silas Penny", "If he's back, his ships are back. Black sails, a raven in gold. One's been seen west of here.",
			"Silas Penny", "Sink her. And if her captain kept letters, I want to read them.",
		],
		"steps": [
			{"kind": Step.SINK},
			{"kind": Step.READ, "where": "sea", "title": "A letter in a bottle", "text":
				"Capitan,\n\nEvery coin to the Fort. Every chest dug, every hoard found. The Doctor says the Heart grows with every crown it burns, and that by the night the storm sits on the Black Reef it will be ready.\n\nThe pirates of Merrow are a nuisance. Sink any that follow you.\n\nCuervo"},
			{"kind": Step.TALK, "who": "wren", "lines": [
				"Mother Wren", "Cuervo. The Raven. And a Heart that grows when it burns gold.",
				"Mother Wren", "I have heard of it, in old songs. The Heart of Ash. The sea gave it up once, and drowned a fleet to get it back.",
			]},
		],
	},
	{
		"id": "a5", "act": 1, "title": "Wren's Vigil", "giver": "wren", "xp": 500, "gold": 0, "night": true,
		"intro": [
			"Mother Wren", "I feel them stirring. Three great captains in three graves, and the Spanish going for them tonight.",
			"Mother Wren", "If they rise as the Doctor's officers, we will never be rid of them. Beat them, and bring me all three skulls before dawn.",
		],
		"steps": [
			{"kind": Step.VIGIL, "islands": [1, 2, 0], "captains": ["Old Rattlejaw", "Captain Marrowdeep", "Salty Sal Skullface"], "to": "wren", "lines": [
				"Mother Wren", "Three more who will sleep. Thank you.",
				"Mother Wren", "But the Spanish are not stopping. There is a camp on Cutlass Cay's hill, raising them by the dozen. Come back when you are ready to end it.",
			]},
		],
	},
	{
		"id": "a6", "act": 1, "title": "The Sergeant's Camp", "giver": "wren", "xp": 1000, "gold": 300, "reward": "Gravewarden",
		"intro": [
			"Mother Wren", "The camp on the hill. A great green fire, and a sergeant who will not fall.",
			"Mother Wren", "Put out the fire first, or the dead will keep coming. Three buckets, I think. Then the sergeant.",
			"Mother Wren", "His shield turns any blow from the front. Go round him, or knock it aside with a shot. Go well.",
		],
		"steps": [
			{"kind": Step.BONFIRE, "island": 0, "buckets": 3, "rise_every": 20.0, "rise": 2, "max_up": 6},
			{"kind": Step.BOSS, "island": 0, "boss": "Sargento Calavera", "guards": 2},
			{"kind": Step.READ, "where": "here", "title": "The Sergeant's orders", "text":
				"Sargento,\n\nWhen the hill is dug out, bring every coin and every skull to Fuerte del Cuervo. The Admiral will have his fleet by the storm's night.\n\nThe Doctor"},
			{"kind": Step.TALK, "who": "wren", "lines": [
				"Mother Wren", "Fuerte del Cuervo. The Raven's Fort. And a fleet.",
				"Mother Wren", "Rest a while, Gravewarden. This is only the beginning of it.",
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
		"jonah":
			return Outpost.jonah_pos()
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


## The mission card's line for a step: `lit` (fires burning, graves open, chests buried...) and
## `standing` (dead still up) give its counts; a finished step (`done`) reads without them.
static func step_text(step: Dictionary, lit := 0, standing := 0, done := false) -> String:
	if done:
		match int(step.kind):
			Step.DOUSE:
				return "Douse the green fire on %s" % Islands.LAYOUT[step.island].name
			Step.DIG_RACE:
				return "Race the Spanish for the hoards on %s" % Islands.LAYOUT[step.island].name
			Step.SALT:
				return "Salt the graves on %s" % Islands.LAYOUT[step.island].name
			Step.VIGIL:
				return "Keep the vigil"
			Step.BONFIRE:
				return "Put out the bonfire on %s's hill" % Islands.LAYOUT[step.island].name
	match int(step.kind):
		Step.TALK:
			return "Talk to %s at Port Merrow" % person_name(step.who)
		Step.READ:
			match str(step.get("where", "dry")):
				"sea":
					return "Fish the bottle out of the wreckage"
				"here":
					return "Search what's left"
			return "Search %s for what the lights were" % Islands.LAYOUT[step.island].name
		Step.DOUSE:
			if lit > 0:
				return "Douse the green fire on %s (fill your bucket in the sea)" % Islands.LAYOUT[step.island].name
			return "Fell the dead (%d left)" % standing
		Step.BOUNTY:
			return "Fell %s on %s and bring the skull to %s" % [step.captain, Islands.LAYOUT[step.island].name, person_name(step.to)]
		Step.DIG_RACE:
			if lit > 0:
				return "Dig up the hoards on %s before the Spanish (%d left)" % [Islands.LAYOUT[step.island].name, lit]
			return "Sell what you saved to %s" % person_name(step.to)
		Step.SALT:
			if lit > 0:
				return "Salt the open graves on %s (%d left; salt on Port Merrow's pier)" % [Islands.LAYOUT[step.island].name, lit]
			return "Fell the dead still up (%d left)" % standing
		Step.KEGS:
			return "Find the powder store on %s and blow it up" % Islands.LAYOUT[step.island].name
		Step.SINK:
			return "Sink the Spanish galleon"
		Step.VIGIL:
			return "Bring Wren three captains' skulls before dawn (%d left)" % maxi(lit, 0)
		Step.BONFIRE:
			if lit > 0:
				return "Douse the bonfire on %s's hill (%d buckets)" % [Islands.LAYOUT[step.island].name, lit]
			return "Fell the dead of the camp (%d left)" % standing
		Step.BOSS:
			return "Beat %s" % step.boss
	return ""

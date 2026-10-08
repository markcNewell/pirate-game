class_name Story
extends RefCounted
## The Ash Fleet (docs/specs/2026-10-08-story.md): the people of Port Merrow, and the story's
## chapters as data. Each chapter is a list of steps of a few kinds; ServerSim runs them, the
## HUD describes them. Pure data and rules, the same on every machine.

enum Step {
	TALK, READ, DOUSE, BOUNTY, DIG_RACE, SALT, KEGS, SINK, VIGIL, BONFIRE, BOSS, CHASE, GATHER,
	RESCUE, FERRY, DIVE, CONVOY, BELLS, ASK, SEARCH, BREACH, USE,
}

## Who you can talk to. `where` names the Outpost function giving where they stand.
const PEOPLE := {
	"moll": {"name": "Moll Tinder", "what": "the lighthouse keeper"},
	"wren": {"name": "Mother Wren", "what": "the Lantern Order"},
	"silas": {"name": "Silas Penny", "what": "the Gilded Hand"},
	"quill": {"name": "Abel Quill", "what": "the Merrow Traders"},
	"jonah": {"name": "Jonah Salt", "what": "a castaway trader, visiting"},
	"isabel": {"name": "Isabel Montero", "what": "a Spanish deserter, at the tavern"},
	"martha": {"name": "Big Martha", "what": "the Drowned Rat (outfits and dyes)"},
}
## The order the people are numbered in over the network.
const PEOPLE_IDS: Array[String] = ["moll", "wren", "silas", "quill", "jonah", "isabel", "martha"]
const TALK_REACH := 3.2
## What each says when they have no chapter for you.
const CHATTER := {
	"moll": ["Moll Tinder", "Forty years on this light and I've never seen the sea so restless."],
	"wren": ["Mother Wren", "The dead are quiet tonight. I don't trust it."],
	"silas": ["Silas Penny", "Gold's gold, friend. Bring me chests and I'll give you coin for them."],
	"quill": ["Abel Quill", "Cargo on time, crates kept dry, and the ledger balances. That's all I ask."],
	"jonah": ["Jonah Salt", "Captain Coco says hello. He doesn't say much else. He's a coconut."],
	"isabel": ["Isabel Montero", "Martha's rum is terrible. I am drinking it anyway. Come back when you are ready to hurt the Admiral."],
	"martha": ["Big Martha", "Coats, hats, dyes. Gold on the counter, and no fighting in my back room."],
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
	# --- Act II: The Raven's Due (pirate level 5) ---
	{
		"id": "b1", "act": 2, "title": "A Deserter at Dawn", "giver": "moll", "xp": 500, "gold": 200,
		"intro": [
			"Moll Tinder", "A rowing boat, adrift off Cutlass Cay. Someone in it, waving. And a skeleton ship coming up behind.",
			"Moll Tinder", "Whoever it is, the dead want them badly. Get there first and bring them here.",
		],
		"steps": [
			{"kind": Step.RESCUE, "at": Vector3(120.0, 0.0, -330.0)},
			{"kind": Step.FERRY, "lines": [
				"Isabel Montero", "Teniente Isabel Montero, marines of the San Telmo. Or I was, until this morning.",
				"Isabel Montero", "Thank you. I will be at the tavern, drinking whatever they have. Come and find me: you will want to hear what I know.",
			]},
		],
	},
	{
		"id": "b2", "act": 2, "title": "The Admiral's Story", "giver": "isabel", "xp": 500, "gold": 150,
		"intro": [
			"Isabel Montero", "Thirty years ago the Silver Fleet anchored on the Black Reef to pull something out of the sea. A stone heart, burning green.",
			"Isabel Montero", "That night a hurricane came out of nowhere and sank all twelve ships. One boy lived, clinging to the Heart's chest. Alonso de Cuervo.",
			"Isabel Montero", "He came back an Admiral, with the King's alchemist, Doctor Ocaso. The Doctor feeds the Heart gold, and the dead get up and obey.",
			"Isabel Montero", "My captain refused to dig up graves. Cuervo shot him, and the Doctor raised him. I ran.",
			"Isabel Montero", "His logbook went down with the San Telmo, off Gull Isle's arch. It has the fort's soundings in it. I need it.",
		],
		"steps": [
			{"kind": Step.DIVE, "at": Vector3(-282.0, 0.0, 167.0), "title": "The San Telmo's log", "text":
				"Capitán Rodrigo Vela, San Telmo.\n\nThe Admiral keeps his gold at Fuerte del Cuervo, and his Heart aboard the Cuervo Negro, never ashore.\n\nThe fort's gate faces west. The powder is kept outside it, which is madness; I have said so.\n\nTonight he has ordered me to dig. I will not. God keep my crew."},
			{"kind": Step.TALK, "who": "isabel", "lines": [
				"Isabel Montero", "Rodrigo. Stubborn to the end.",
				"Isabel Montero", "The gold goes to the fort. If you want to hurt Cuervo, stop the gold first. Silas will help with that, I think.",
			]},
		],
	},
	{
		"id": "b3", "act": 2, "title": "Starve the Fire", "giver": "silas", "xp": 600, "gold": 0,
		"intro": [
			"Silas Penny", "A convoy, Isabel says. A treasure galleon and two escorts, carrying every coin they've dug up to the fort.",
			"Silas Penny", "Take it. Board her, or sink her and fish the chests out. Bring the gold to me and I'll pay you its worth and then some.",
		],
		"steps": [
			{"kind": Step.CONVOY, "chests": 3, "to": "silas", "lines": [
				"Silas Penny", "Look at that. Spanish gold, in my strongbox, where it can't feed anything.",
				"Silas Penny", "Mother Wren's been asking after you. Something about bells.",
			]},
		],
	},
	{
		"id": "b4", "act": 2, "title": "The Drowned Bells", "giver": "wren", "xp": 550, "gold": 150,
		"intro": [
			"Mother Wren", "Do you hear them? Bells. Green bronze, hung where the dead can hear.",
			"Mother Wren", "Three of them: Parrot Rock, Gull Isle, Cutlass Cay. Every ring raises more. Shoot them down.",
		],
		"steps": [
			{"kind": Step.BELLS, "islands": [1, 2, 0], "rise_every": 20.0, "rise": 2, "max_up": 6, "lines": [
				"Mother Wren", "Quiet. Thank you. Quill has a worry too, I think. Something about his ledger.",
			]},
		],
	},
	{
		"id": "b5", "act": 2, "title": "Spies in Merrow", "giver": "quill", "xp": 550, "gold": 200,
		"intro": [
			"Abel Quill", "Salt is going missing from my pier. Not a lot. Exactly one crate a night. The ledger does not lie.",
			"Abel Quill", "Somebody in Merrow is selling to the Spanish. Ask about. Jonah, Moll and Silas see everything that moves.",
		],
		"steps": [
			{"kind": Step.ASK, "who": ["jonah", "moll", "silas"], "lines": {
				"jonah": ["Jonah Salt", "A man rowed out from the pier at midnight with a crate. Fat fellow. Captain Coco didn't like the look of him."],
				"moll": ["Moll Tinder", "Lights on Gull Isle's south cove last night. Not green. A lantern, and a rowing boat."],
				"silas": ["Silas Penny", "Fat Gideon's been spending Spanish silver in the tavern. Silver with a bird on it."],
			}},
			{"kind": Step.SEARCH, "crates": 3, "title": "A raven coin", "text":
				"Under the salt, wrapped in oilcloth: a silver coin stamped with a raven, and a note in a bad hand.\n\n'Gideon. One crate a night to the south cove of Gull Isle. They pay in silver.'"},
			{"kind": Step.BOSS, "island": 2, "boss": "Fat Gideon", "where": "cove", "guards": 3, "lines": [
				"Fat Gideon", "All right! All right! I give up! They paid well, and they never tried to eat me. Mostly.",
				"Fat Gideon", "The fort. Fuerte del Cuervo. That's where the salt goes, for the walls. The dead don't like to cross salt.",
			]},
			{"kind": Step.TALK, "who": "quill", "lines": [
				"Abel Quill", "Gideon. I should have known. He always paid his bar tab in cash.",
				"Abel Quill", "Isabel will want to hear about the fort. I believe she has plans.",
			]},
		],
	},
	{
		"id": "b6", "act": 2, "title": "Fuerte del Cuervo", "giver": "isabel", "xp": 1000, "gold": 300, "reward": "Fort-Breaker",
		"intro": [
			"Isabel Montero", "The fort. Walls on a rock, two guns on the towers, a gate facing west, and the powder kept outside it. Rodrigo was right: madness.",
			"Isabel Montero", "Blow the gate with their own powder. Inside, the gunner El Polvorín. He throws bombs. Keep moving.",
			"Isabel Montero", "There are living men in the cells, sailors who said no to Cuervo. Let them out. And the vault... take it all.",
		],
		"steps": [
			{"kind": Step.BREACH},
			{"kind": Step.BOSS, "island": -1, "boss": "El Polvorín", "where": "fort", "guards": 5},
			{"kind": Step.USE, "object": "cells", "lines": [
				"Spanish sailor", "Teniente Montero sent you? God bless her. We'll take the boats. Tell her we're with her.",
			]},
			{"kind": Step.USE, "object": "vault"},
			{"kind": Step.TALK, "who": "isabel", "lines": [
				"Isabel Montero", "My men are free, and the Admiral's gold is in Silas's strongbox. You have done more in a night than Spain did in a year.",
				"Isabel Montero", "But the vault told me something worse. The Heart is not at the fort. It is aboard the Cuervo Negro, and the fleet rises the night the storm sits on the Black Reef.",
			]},
		],
	},
	# --- Tales: side stories, each opening after the chapter in "after". ---
	{
		"id": "t1", "act": 0, "title": "Coconut Thieves", "giver": "jonah", "xp": 250, "gold": 50, "tale": "Captain Coco", "after": "p1",
		"intro": [
			"Jonah Salt", "Terrible news. Terrible. The crabs of Gull Isle have taken Captain Coco.",
			"Jonah Salt", "I set him down to admire the sunset and when I looked round, a crab was carrying him off. A big one. Smug.",
			"Jonah Salt", "Bring him back to me? He can't swim. He's a coconut.",
		],
		"steps": [
			{"kind": Step.CHASE, "island": 2, "to": "jonah", "lines": [
				"Jonah Salt", "Coco! You're safe! ...He says thank you. Well, he would if he could.",
				"Jonah Salt", "Now, there's another thing I've been meaning to ask you. About a raft.",
			]},
		],
	},
	{
		"id": "t2", "act": 0, "title": "A Raft for Jonah", "giver": "jonah", "xp": 300, "gold": 100, "tale": "Captain Coco", "after": "t1",
		"intro": [
			"Jonah Salt", "Eleven years on that island. Time I went home, wherever home is. I need a raft.",
			"Jonah Salt", "There are wrecks on Parrot Rock, Gull Isle and Cutlass Cay with good planks in them. Bring me a bundle from each?",
		],
		"steps": [
			{"kind": Step.GATHER, "item": "planks", "where": "wrecks", "islands": [1, 2, 0], "to": "jonah", "lines": [
				"Jonah Salt", "Beautiful planks. I'll lash them together tonight and sail at dawn.",
				"Jonah Salt", "...Actually, I've been thinking. The island's not so bad. And Coco likes the view. Keep the gold, and thank you.",
			]},
		],
	},
	{
		"id": "t3", "act": 1, "title": "The Missing Tea", "giver": "quill", "xp": 300, "gold": 120, "tale": "Quill's Ledger", "after": "a2",
		"intro": [
			"Abel Quill", "Twenty crates of Merrow's finest tea left Gull Isle a week ago. None arrived. The ledger is most upset.",
			"Abel Quill", "A fisherman saw crates floating between here and Gull Isle. Fish out three, if they're still dry, and bring them to me.",
		],
		"steps": [
			{"kind": Step.GATHER, "item": "tea", "where": "sea", "count": 3, "to": "quill", "lines": [
				"Abel Quill", "Three crates. Damp, but drinkable. One of them is rattling. Tea does not rattle.",
				"Abel Quill", "Come and see me when you have a moment. I have... a delicate matter.",
			]},
		],
	},
	{
		"id": "t4", "act": 1, "title": "Señor Hueso", "giver": "quill", "xp": 300, "gold": 120, "tale": "Quill's Ledger", "after": "t3",
		"intro": [
			"Abel Quill", "The rattling crate. I opened it. There is a skeleton inside, and it is very polite.",
			"Señor Hueso", "Buenos días. I am Hueso. I was the cook on the San Telmo. They woke me, but they forgot to give me orders. So I cook.",
			"Abel Quill", "He would like to open a kitchen on Gull Isle, by Jonah's beach. Please take him there. Gently. He comes apart.",
		],
		"steps": [
			{"kind": Step.GATHER, "item": "hueso", "where": "pier", "count": 1, "to": "beach:2", "lines": [
				"Señor Hueso", "Ah, the sand, the palms, a castaway with a coconut. Perfect. I will make a stew.",
				"Señor Hueso", "Tell Quill: if he wants tea for a fancy party, my kitchen will keep it fine.",
			]},
		],
	},
	{
		"id": "t5", "act": 1, "title": "The Governor's Ball", "giver": "quill", "xp": 400, "gold": 250, "tale": "Quill's Ledger", "after": "t4", "reward": "Purveyor of Fine Goods",
		"intro": [
			"Abel Quill", "The Governor's ball is tonight, at the Drowned Rat, and I promised them the finest tea in the Isles.",
			"Abel Quill", "Hueso has two crates waiting at his kitchen on Gull Isle. They are porcelain-packed. If you put one down anywhere but your deck, it breaks.",
			"Abel Quill", "Six minutes. I am not panicking. Go.",
		],
		"steps": [
			{"kind": Step.GATHER, "item": "fine_tea", "where": "beach", "island": 2, "count": 2, "to": "quill", "time": 360.0, "fragile": true, "lines": [
				"Abel Quill", "Intact! Both of them! The Governor will never know how close we came.",
				"Abel Quill", "A purveyor of fine goods. That's what you are. I shall write it in the ledger.",
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
		"isabel":
			return Outpost.isabel_pos()
		"martha":
			return Outpost.martha_pos()
	return Vector3.ZERO


## May a crew start chapter `i`, given each pirate's finished chapters? The first always; a tale
## once someone aboard has finished the chapter it follows ("after"); any other once someone has
## finished the story chapter before it.
static func open_for(i: int, done_lists: Array) -> bool:
	if i < 0 or i >= CHAPTERS.size():
		return false
	var before := str(CHAPTERS[i].get("after", ""))
	if before == "":
		var k := i - 1
		while k >= 0 and CHAPTERS[k].has("tale"):
			k -= 1
		if k < 0:
			return true
		before = CHAPTERS[k].id
	for done: Array in done_lists:
		if done.has(before):
			return true
	return false


## The crew's next story chapter (tales aside): the first that is open and not yet finished by
## all of them, or -1.
static func next_for(done_lists: Array) -> int:
	for i in CHAPTERS.size():
		if CHAPTERS[i].has("tale"):
			continue
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
		Step.RESCUE:
			return "Reach the drifting boat off Cutlass Cay and take its passenger aboard"
		Step.FERRY:
			return "Bring Isabel safely to Port Merrow"
		Step.DIVE:
			return "Dive at the San Telmo's wreck off Gull Isle (hold E over it)"
		Step.CONVOY:
			return "Take the convoy's gold to %s (%d chests left)" % [person_name(step.to), lit] if lit > 0 else "Take the convoy's gold to %s" % person_name(step.to)
		Step.BELLS:
			return "Shoot down the drowned bells (%d left)" % lit if lit > 0 else "Shoot down the drowned bells"
		Step.ASK:
			return "Ask Jonah, Moll and Silas what they saw (%d left)" % lit if lit > 0 else "Ask about Merrow"
		Step.SEARCH:
			return "Search the crates on Port Merrow's pier"
		Step.BREACH:
			return "Blow open the fort's gate (its powder is outside)"
		Step.USE:
			return "Free the prisoners in the cells" if step.object == "cells" else "Open the vault"
		Step.CHASE:
			return "Catch the crab with Captain Coco on %s and bring him to %s" % [Islands.LAYOUT[step.island].name, person_name(step.to)]
		Step.GATHER:
			var what: String = {"planks": "a bundle of planks from each wreck", "tea": "floating tea crates (%d left)" % lit,
				"hueso": "Señor Hueso's crate (on the pier)", "fine_tea": "the fine tea from Hueso's kitchen (%d left)" % lit}[step.item]
			var to: String = "Gull Isle's beach" if str(step.to).begins_with("beach") else person_name(step.to)
			return "Bring %s to %s" % [what, to]
	return ""

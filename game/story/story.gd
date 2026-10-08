class_name Story
extends RefCounted
## The Ash Fleet (docs/specs/2026-10-08-story.md): the people of Port Merrow, and the story's
## chapters as data. Each chapter is a list of steps of a few kinds; ServerSim runs them, the
## HUD describes them. Pure data and rules, the same on every machine.

enum Step {
	TALK, READ, DOUSE, BOUNTY, DIG_RACE, SALT, KEGS, SINK, VIGIL, BONFIRE, BOSS, CHASE, GATHER,
	RESCUE, FERRY, DIVE, CONVOY, BELLS, ASK, SEARCH, BREACH, USE,
	SIEGE_SEA, SIEGE_BEACH, SNIPER, DOCTOR,
	HULK, GHOST, LANTERNS, GAMBIT, RISEN, CRIPPLE, ADMIRAL,
	ASHEN, OCASO, BEACONS, ASH_FLAGSHIP, COLOSSUS, ASH_DUEL, HEART,
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
	"hobb": {"name": "Old Hobb", "what": "the shipwright, on the pier (sails, paint and flags)"},
}
## The order the people are numbered in over the network.
const PEOPLE_IDS: Array[String] = ["moll", "wren", "silas", "quill", "jonah", "isabel", "martha", "hobb"]
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
	"hobb": ["Old Hobb", "Paint won't make her faster, mind. But she'll look a sight better going down."],
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
	# --- Act III: The Siege of Merrow (pirate level 10) ---
	{
		"id": "c1", "act": 3, "title": "Ashes on the Wind", "giver": "moll", "xp": 600, "gold": 200,
		"intro": [
			"Moll Tinder", "Ash on the wind, and my light burning green. Someone's been up my tower and poisoned the lamp.",
			"Moll Tinder", "Green light tells their ships the way in. Climb up, put it out, and bring oil from the tavern to light it true.",
			"Moll Tinder", "And take water up with you. You won't find the sea at the top.",
		],
		"steps": [
			{"kind": Step.DOUSE, "where": "lamp", "fires": 1, "rise": 0},
			{"kind": Step.GATHER, "item": "oil", "where": "tavern", "count": 1, "to": "lamp", "lines": [
				"Moll Tinder", "There she burns, gold and true. Let them try to find the harbour now.",
				"Moll Tinder", "Quill was asking for strong arms. He's bought some guns, God help us.",
			]},
		],
	},
	{
		"id": "c2", "act": 3, "title": "Powder and Shot", "giver": "quill", "xp": 700, "gold": 250,
		"intro": [
			"Abel Quill", "Merrow needs guns of its own. I have bought four, at a very good price, from the old dig camp on Cutlass Cay.",
			"Abel Quill", "The previous owner, a sergeant, raised no objection. Please carry them to the beach past Silas's hut. Skeleton ships have been sighted; do hurry.",
		],
		"steps": [
			{"kind": Step.GATHER, "item": "cannon", "where": "camp", "island": 0, "count": 4, "to": "battery", "raids": 120.0, "lines": [
				"Abel Quill", "Four guns on the beach. Merrow has teeth. I have entered them in the ledger as 'deterrence'.",
			]},
		],
	},
	{
		"id": "c3", "act": 3, "title": "Saltshot", "giver": "wren", "xp": 600, "gold": 150,
		"intro": [
			"Mother Wren", "Isabel and I have been talking. Shot packed with sea salt would burst a dead ship's planks like dry bread.",
			"Mother Wren", "Bring me a crate of Quill's salt, a piece of a drowned bell from Gull Isle, and a barrel of brine from the edge of the Black Reef, far to the south-east, where the sea is saltiest.",
		],
		"steps": [
			{"kind": Step.GATHER, "item": "saltshot", "where": "saltshot", "count": 3, "to": "wren", "lines": [
				"Mother Wren", "Salt, bronze and brine. Your cannonballs will hurt the dead now. Not the living: they are only cannonballs to them.",
				"Mother Wren", "I feel another great captain stirring. Hollowbell. Come back when you are ready.",
			]},
		],
	},
	{
		"id": "c4", "act": 3, "title": "The Pressed Dead", "giver": "wren", "xp": 700, "gold": 0,
		"intro": [
			"Mother Wren", "They've dug up Hollowbell. The best pirate these Isles ever had, and now he leads the Spanish dead on Parrot Rock.",
			"Mother Wren", "Bring me his skull. Be kind to it. He was a better man than most.",
		],
		"steps": [
			{"kind": Step.BOUNTY, "island": 1, "captain": "Captain Hollowbell", "pronoun": "him", "crew": 3, "thieves": 0, "to": "wren", "talking": [
				"Free! Free as a gull! Who's carrying me? Mind the bumps.",
				"You sail like a cow swims, my friend.",
				"The Admiral's flagship anchors off Cutlass Cay at night. Black hull, gold stern. You can't miss her.",
				"He means to burn Merrow, you know. I heard the Doctor say so while I was still in his pocket.",
				"I left a hoard once, for my cabin boy. Little Silas. I wonder what became of him.",
				"Is it much further? I've no legs to stretch, but I'd like to stretch them.",
			], "lines": [
				"Mother Wren", "Rest, Hollowbell. You've earned it twice over.",
				"Mother Wren", "And he's right: they mean to burn Merrow. Isabel is at the tavern. Talk to her.",
			]},
		],
	},
	{
		"id": "c5", "act": 3, "title": "The Last Night of Peace", "giver": "isabel", "xp": 400, "gold": 100,
		"intro": [
			"Isabel Montero", "Martha has opened the tavern to everyone tonight. Rum, music, and a table of crews who were strangers a month ago.",
			"Isabel Montero", "To the crews of Merrow. ...Listen. That's the harbour bell. Raven sails on the horizon.",
			"Isabel Montero", "Barricades on the pier, quickly: three of them, by the tavern door.",
		],
		"steps": [
			{"kind": Step.GATHER, "item": "barricade", "where": "tavern", "count": 3, "to": "pier", "lines": [
				"Isabel Montero", "Good. Now find your ships and your courage. Come to me when you are ready: they will come with the dark.",
			]},
		],
	},
	{
		"id": "c6", "act": 3, "title": "The Siege of Port Merrow", "giver": "isabel", "xp": 1000, "gold": 400, "night": true, "shared": true, "reward": "Defender of Merrow",
		"intro": [
			"Isabel Montero", "Here they come. Three galleons, and the Cuervo Negro behind them. Every crew in the Isles, to the harbour!",
			"Isabel Montero", "The battery will help if someone stands by it. Sink the galleons first; then the dead will try the beach.",
		],
		"steps": [
			{"kind": Step.SIEGE_SEA, "galleons": 3},
			{"kind": Step.SIEGE_BEACH, "waves": 3, "size": 6},
			{"kind": Step.SNIPER, "boss": "La Viuda"},
			{"kind": Step.DOCTOR, "raise": 4, "lines": [
				"Doctor Ocaso", "Bravo. Bravo! Such spirit. It will make you excellent servants, in time.",
				"Doctor Ocaso", "Teniente Montero. The Admiral would like a word. Do come quietly.",
				"Isabel Montero", "Let go of me, you-",
			], "end": [
				"Moll Tinder", "Merrow stands. Scorched, but standing.",
				"Moll Tinder", "But they took Isabel. The flagship went south, into the fog off Isla Ceniza.",
			]},
		],
	},
	# --- Act IV: The Drowned Fleet (docs/specs/2026-10-08-m11-the-drowned-fleet.md). ---
	{
		"id": "d1", "act": 4, "title": "The Prison Hulk", "giver": "moll", "xp": 800, "gold": 250,
		"intro": [
			"Moll Tinder", "Hollowbell's skull said it, before Wren laid him down: the Admiral keeps his prisoners in an old hulk, in the fog off Isla Ceniza.",
			"Moll Tinder", "She'll be there. Go quietly. Guards walk that deck with lanterns, and if one sees you he'll ring for every ship they have.",
			"Moll Tinder", "The jailer keeps the keys at the stern. Bring her home.",
		],
		"steps": [
			{"kind": Step.HULK, "guards": 3, "boss": "the jailer", "lines": [
				"Isabel Montero", "You took your time. ...The keys. On his belt. Quickly, before his friends come looking.",
			]},
			{"kind": Step.USE, "object": "hulk", "lines": [
				"Isabel Montero", "Out. Thank you. I owe you a ship's worth of thanks and I mean to pay it.",
			]},
			{"kind": Step.FERRY, "lines": [
				"Isabel Montero", "Merrow. Still standing. Good.",
				"Isabel Montero", "Find me at the tavern once I've slept. I know where the fleet is going, and how we get there before it.",
			]},
		],
	},
	{
		"id": "d2", "act": 4, "title": "The Pilot's Chart", "giver": "isabel", "xp": 800, "gold": 200,
		"intro": [
			"Isabel Montero", "The drowned fleet lies inside the Black Reef. One channel runs in safely, and only its pilot knew it: Mateo Brisa. He's buried on Isla Calavera with his chart.",
			"Isabel Montero", "The sailors had a song about him. 'Look out of the skull's left eye, count the teeth to the third, and dig where the third tooth points.' Or close enough.",
		],
		"steps": [
			{"kind": Step.READ, "where": "calavera_eye", "hint": "Find the carving before the skull's left eye on Isla Calavera", "title": "Cut in the rock below the left eye", "text":
				"A skull over an arrow, and under it, in Spanish:\n\nTHE PILOT KEEPS HIS CHART WHERE THE SKULL CANNOT SEE IT.\nCOUNT THE TEETH FROM THE LEFT.\nTHE THIRD ONE KNOWS."},
			{"kind": Step.READ, "where": "calavera_tooth", "hint": "Find the third tooth-stone, counting from the left", "title": "Scratched on the third tooth-stone", "text":
				"Three notches and an arrow, pointing back toward the skull's chin.\n\nBETWEEN THE TEETH AND THE STONES, MATEO SLEEPS. DIG GENTLY. HE BITES."},
			{"kind": Step.GATHER, "item": "chart", "where": "grave", "count": 1, "to": "isabel", "lines": [
				"Isabel Montero", "The channel. Every rock, every turn, in his hand. With this the Reef won't touch you.",
				"Isabel Montero", "Pass it round your crew. And keep away from storms for a while. I hear things are rising in them.",
			]},
		],
	},
	{
		"id": "d3", "act": 4, "title": "Ghost Lights", "giver": "wren", "xp": 800, "gold": 250,
		"intro": [
			"Mother Wren", "Sailors are seeing green lights inside the storm. Not lightning. Lanterns, on a ship that isn't there in the morning.",
			"Mother Wren", "The drowned fleet is waking, one ship at a time. Find the storm. When she rises, put her back down.",
		],
		"steps": [
			{"kind": Step.GHOST, "lines": [
				"Mother Wren", "Down again. She'll lie quieter now. But there were forty ships in that fleet.",
			]},
		],
	},
	{
		"id": "d4", "act": 4, "title": "Lanterns of the Deep", "giver": "wren", "xp": 900, "gold": 300,
		"intro": [
			"Mother Wren", "Ocaso has set great lanterns on the sea stacks round the Black Reef: green fire, to light the drowned fleet up from the bottom.",
			"Mother Wren", "Three of them, each with a guard. Smash them all before the storm closes over the Reef: twelve minutes, no more.",
		],
		"steps": [
			{"kind": Step.LANTERNS, "islands": [7, 8, 9], "garrison": 3, "time": 720.0, "lines": [
				"Mother Wren", "Dark again. Whatever is down there will have to find its own way up.",
			]},
		],
	},
	{
		"id": "d5", "act": 4, "title": "The Merchant's Gambit", "giver": "quill", "xp": 1000, "gold": 350,
		"intro": [
			"Abel Quill", "I have filled twelve crates with lead and painted them gold, and let it be known in the right taverns that a treasure ship sails from Merrow tonight.",
			"Abel Quill", "You are the treasure ship. Sail close to the Black Reef. When the Cuervo Negro comes out for you, run. Bring her east of the fort, where Isabel waits.",
			"Abel Quill", "Please don't get sunk. The crates were expensive.",
		],
		"steps": [
			{"kind": Step.GAMBIT, "holes": 10, "lines": [
				"Isabel Montero", "She's running back into the Reef, holed like a sieve! Quill's lead and your nerve. Well done.",
				"Abel Quill", "Twelve crates of lead, one admiral, considerably annoyed. I call that a profit.",
			]},
		],
	},
	{
		"id": "d6", "act": 4, "title": "The Battle of the Black Reef", "giver": "isabel", "xp": 1500, "gold": 500, "shared": "reef", "reward": "Raven-Breaker",
		"intro": [
			"Isabel Montero", "The storm sits on the Reef and won't move. Tonight they raise the fleet. Every crew in the Isles, to the Black Reef!",
			"Isabel Montero", "Sink what rises. Then the Cuervo Negro: break her, board her, and end this with the Admiral himself.",
		],
		"steps": [
			{"kind": Step.RISEN, "galleons": 3},
			{"kind": Step.CRIPPLE, "holes": 14},
			{"kind": Step.ADMIRAL, "marines": 4, "boss": "The Raven Admiral", "lines": [
				"Isabel Montero", "He's over the side! And the Cuervo Negro's going down with her colours still up.",
				"Isabel Montero", "There, in the smoke: a rowing boat, pulling hard for Isla Ceniza. Green light in it. Ocaso, and the Heart.",
				"Isabel Montero", "Let him run. Tonight we won. Tomorrow we finish it.",
			]},
		],
	},
	# --- Act V: The Heart of Ash, and the epilogue (docs/specs/2026-10-08-m12-the-heart-of-ash.md). ---
	{
		"id": "e1", "act": 5, "title": "What the Admiral Knew", "giver": "wren", "xp": 900, "gold": 250,
		"intro": [
			"Mother Wren", "The Admiral kept a journal. Every captain does. It went down with the Cuervo Negro, in the heart of the Reef.",
			"Mother Wren", "Dive for it. Whatever he knew about the Heart, we need to know it too.",
		],
		"steps": [
			{"kind": Step.DIVE, "at": Vector3(805.0, 0.0, 650.0), "hint": "Dive on the Cuervo Negro's wreck in the heart of the Black Reef (hold E over her)", "title": "The Admiral's journal", "text":
				"I have served the Doctor for thirty years thinking he served the King. He does not. He serves the stone.\n\n" +
				"He says it speaks. He says it remembers every soul the sea has ever drowned, and wants them all to walk again: every sailor, every fisherman, every child.\n\n" +
				"I brought it back to the Isles for gold and glory. God forgive me, I think it brought me."},
			{"kind": Step.TALK, "who": "wren", "lines": [
				"Mother Wren", "Every soul the sea ever drowned. My sister. Your grandfathers. All of them.",
				"Mother Wren", "Then it goes back. Back to the Maw it came from. But first, the Doctor. He's on Isla Ceniza, and Isabel knows the way in.",
			]},
		],
	},
	{
		"id": "e2", "act": 5, "title": "Isla Ceniza", "giver": "isabel", "xp": 1100, "gold": 350,
		"intro": [
			"Isabel Montero", "Isla Ceniza. I was a prisoner there for a week. Ash falls all day, and the dead are burned black and full of fire.",
			"Isabel Montero", "His workshop is in the hill. He keeps three braziers burning round it; while they burn, nothing touches him. Bring buckets.",
		],
		"steps": [
			{"kind": Step.ASHEN, "waves": 2, "size": 4},
			{"kind": Step.OCASO, "boss": "Doctor Ocaso", "lines": [
				"Doctor Ocaso", "Ha! Ha ha! You fools. You think the Heart is here? It went home. Home to the Maw.",
				"Doctor Ocaso", "And the dead are answering. All of them. Listen...",
				"Isabel Montero", "He's gone. Laughing. ...I can hear it too. Bells, under the sea.",
			]},
		],
	},
	{
		"id": "e3", "act": 5, "title": "Every Hand", "giver": "quill", "xp": 1000, "gold": 300,
		"intro": [
			"Abel Quill", "One last push, and it needs everyone. Three jobs, one for each company, and I have written them down because I am that sort of man.",
			"Abel Quill", "First: saltshot for every ship. Three crates on the pier, to the battery, where the crews are loading.",
		],
		"steps": [
			{"kind": Step.GATHER, "item": "saltshot_crates", "where": "pier", "count": 3, "to": "battery", "lines": [
				"Abel Quill", "Second: the beacons. Cutlass Cay, Parrot Rock and Gull Isle. Light them and every crew in the Isles will come.",
			]},
			{"kind": Step.BEACONS, "lines": [
				"Mother Wren", "Third: my lantern. Carry it to the edge of the Black Reef. Its light will show us where the Heart lies.",
			]},
			{"kind": Step.GATHER, "item": "wren_lantern", "where": "wren", "count": 1, "to": "reef_edge", "lines": [
				"Mother Wren", "There. Look where the light bends: the Maw. It's down there, and it's waking.",
				"Isabel Montero", "My sailors from the fort are ready, and La Golondrina with them. Tomorrow night we end it.",
			]},
		],
	},
	{
		"id": "e4", "act": 5, "title": "The Ash Admiral", "giver": "isabel", "xp": 1300, "gold": 400,
		"intro": [
			"Isabel Montero", "Lookouts say the Heart has raised him. Cuervo. Burned black, a crown of green fire, and the whole drowned fleet at his back.",
			"Isabel Montero", "Break the fleet at the Maw before it sails on Merrow. Every ship you sink is one less at our door.",
		],
		"steps": [
			{"kind": Step.RISEN, "galleons": 4},
			{"kind": Step.ASH_FLAGSHIP, "lines": [
				"Isabel Montero", "His flagship's going down! But look, in the Maw. Something's coming up. Something big.",
			]},
		],
	},
	{
		"id": "e5", "act": 5, "title": "The Bone Colossus", "giver": "wren", "xp": 2000, "gold": 800, "shared": "end", "reward": "Heartbreaker", "gift": "outfit9",
		"intro": [
			"Mother Wren", "Every bone of the drowned fleet, pulled together into one. It's standing up out of the Maw.",
			"Mother Wren", "Every crew in the Isles, to the Reef! Break its joints with your guns. When it falls, someone has to carry the Heart back into the Maw. It will burn. Carry it anyway.",
		],
		"steps": [
			{"kind": Step.COLOSSUS},
			{"kind": Step.ASH_DUEL, "guards": 3, "boss": "The Ash Admiral"},
			{"kind": Step.HEART, "lines": [
				"Mother Wren", "The green light's going out. All of it, everywhere.",
				"Isabel Montero", "Every skeleton on the sea just fell to dust. It's over. It's actually over.",
				"Mother Wren", "Here. His cloak, fished off the rock. You've earned the right to wear a raven.",
			]},
		],
	},
	{
		"id": "e6", "act": 5, "title": "Quiet Waters", "giver": "martha", "xp": 500, "gold": 200, "night": true,
		"intro": [
			"Big Martha", "Drinks are on the house tonight. Don't get used to it.",
			"Big Martha", "Go and find your friends, love. They've all been asking after you.",
		],
		"steps": [
			{"kind": Step.ASK, "who": ["isabel", "silas", "quill", "wren"], "hint": "Talk to Isabel, Silas, Quill and Wren at the party", "lines": {
				"isabel": ["Isabel Montero", "The fort is mine now, by Merrow's say-so. Come and trade there; my sailors would like to meet the people who saved them."],
				"silas": ["Silas Penny", "I've counted it twice. Not the gold. The crews. Every one of them came. ...Then I counted the gold."],
				"quill": ["Abel Quill", "Twelve crates of lead, one Colossus, zero losses. The ledger has never balanced so beautifully."],
				"wren": ["Mother Wren", "The Heart wasn't the only thing the sea keeps. Skeletons will still turn up, here and there. The sea remembers. But tonight, it sleeps."],
			}},
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
	# --- Penny's Hoard (Silas), after The Pressed Dead. ---
	{
		"id": "t6", "act": 3, "title": "My Boy Silas", "giver": "silas", "xp": 400, "gold": 0, "tale": "Penny's Hoard", "after": "c4",
		"intro": [
			"Silas Penny", "That skull you carried past my hut. Hollowbell's. It said my name.",
			"Silas Penny", "'Little Silas Penny. My cabin boy. There's a hoard for him.' I was his cabin boy, forty years ago. I'd made myself forget.",
			"Silas Penny", "He cut his mark in the rock wherever he hid things. Parrot Rock, by the tall stacks. Go and look. I'll... mind the hut.",
		],
		"steps": [
			{"kind": Step.READ, "island": 1, "hint": "Find Hollowbell's mark on Parrot Rock", "title": "A bell, cut in the rock", "text":
				"A bell, cut deep, and under it:\n\nWHERE THE SEA RUNS THROUGH THE STONE\nAND THE GULLS KEEP WATCH ALONE,\nDIG FOR THE BOY WHAT THE BELL LEFT BEHIND.\n\n" +
				"Underneath, scratched more recently, in Spanish: 'el arco, Gull Isle'. Someone else has read it too."},
			{"kind": Step.DIG_RACE, "island": 2, "chests": 1, "to": "silas", "lines": [
				"Silas Penny", "It's light. Too light for Hollowbell. ...There's a note, in his hand.",
				"Silas Penny", "'The rest is with the lads, Silas, under the hill on Cutlass Cay. They'll keep it for you.' The lads. His crew. They went down with him.",
			]},
		],
	},
	{
		"id": "t7", "act": 3, "title": "The Old Crew", "giver": "silas", "xp": 500, "gold": 150, "tale": "Penny's Hoard", "after": "t6",
		"intro": [
			"Silas Penny", "Hollowbell's lads. Bosun Grieve, who taught me my knots. Cookie. The twins. If the Doctor's fire has been near that hill, they're up.",
			"Silas Penny", "Put them down gently, if you can. And bring me Grieve's skull. He'd want to see I turned out rich.",
		],
		"steps": [
			{"kind": Step.BOUNTY, "island": 0, "captain": "Bosun Grieve", "pronoun": "him", "crew": 4, "thieves": 0, "to": "silas", "talking": [
				"Little Silas? Silas Penny? Is he still small?",
				"I stopped swinging when you said his name. Did you see? I stopped.",
				"Mind your knots. Always mind your knots.",
				"We kept it for him. Every coin. Didn't spend one. Well. Cookie spent one.",
				"Is the captain with you? No? He'll be along. He always is.",
			], "lines": [
				"Silas Penny", "Grieve. You old fool. You stopped fighting, didn't you? When they said my name.",
				"Silas Penny", "...The hoard's under the old camp on the hill. He always was good at keeping things.",
			]},
		],
	},
	{
		"id": "t8", "act": 3, "title": "Silas Cries", "giver": "silas", "xp": 400, "gold": 300, "tale": "Penny's Hoard", "after": "t7", "gift": "outfit8",
		"intro": [
			"Silas Penny", "Three chests under the old camp on Cutlass Cay. Bring them here. Carefully.",
			"Silas Penny", "And don't sell them to me. I mean it. Don't.",
		],
		"steps": [
			{"kind": Step.GATHER, "item": "hoard", "where": "camp", "island": 0, "count": 3, "to": "silas", "lines": [
				"Silas Penny", "Oh. Oh, look at it. Look how it shines.",
				"Silas Penny", "I'm not crying about Hollowbell. I'm crying because it's beautiful. ...It's a bit about Hollowbell.",
				"Silas Penny", "This was at the bottom of the last one. My old cap. It doesn't fit me any more. It'll fit you.",
			]},
		],
	},
	# --- The Other Lantern (Mother Wren), after the siege. ---
	{
		"id": "t9", "act": 3, "title": "Two Lights", "giver": "wren", "xp": 300, "gold": 50, "tale": "The Other Lantern", "after": "c6",
		"intro": [
			"Mother Wren", "In the siege, among the dead on the beach. Did you see it? A second green light.",
			"Mother Wren", "Moll will have seen it from her lighthouse. Ask her where it went. I need to hear it from someone else.",
		],
		"steps": [
			{"kind": Step.TALK, "who": "moll", "lines": [
				"Moll Tinder", "I saw it. A lantern, carried low, the way you'd carry it along a beach looking for someone.",
				"Moll Tinder", "It went off toward Gull Isle once the fighting stopped. Go gently with Wren when you tell her.",
			]},
			{"kind": Step.TALK, "who": "wren", "lines": [
				"Mother Wren", "Gull Isle. Where we grew up. Linnet and I. My sister. My twin.",
				"Mother Wren", "She drowned off the arch ten years ago, out in a storm with a lantern looking for me. The Doctor has given her back her lantern. And nothing else.",
			]},
		],
	},
	{
		"id": "t10", "act": 3, "title": "Linnet", "giver": "wren", "xp": 600, "gold": 150, "tale": "The Other Lantern", "after": "t9", "night": true,
		"intro": [
			"Mother Wren", "She walks at night. Follow her light from Gull Isle. She won't let you near: come close and she goes on to the next island.",
			"Mother Wren", "Where she stops is where she means to stay. Don't look into her lantern; it blinds. Shoot it from her hand, then let her rest, and bring her home to me.",
		],
		"steps": [
			{"kind": Step.BOUNTY, "linnet": true, "islands": [2, 1, 0], "island": 0, "captain": "Linnet", "crew": 3, "thieves": 0, "to": "wren", "lines": [
				"Mother Wren", "Linnet. Hello, little sister. You found me after all.",
				"Mother Wren", "Leave us a while. Come back at dusk; I'll want someone with me at the water's edge.",
			]},
		],
	},
	{
		"id": "t11", "act": 3, "title": "Rest", "giver": "wren", "xp": 300, "gold": 0, "tale": "The Other Lantern", "after": "t10", "night": true, "reward": "Lantern-Bearer",
		"intro": [
			"Mother Wren", "Dusk. Good. Stand with me a while, down by the water.",
		],
		"steps": [
			{"kind": Step.TALK, "who": "wren", "lines": [
				"Mother Wren", "We lit lanterns for the fishing boats, she and I. One each side of the arch, so they could find the gap.",
				"Mother Wren", "There. She's in the sea now, where she always wanted to be. No fire. No Doctor. Just the tide.",
				"Mother Wren", "Her lantern, mended. Carry it; light it for anyone lost out there. That's what she'd want. That's what you are now: a lantern-bearer.",
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
		"hobb":
			return Outpost.hobb_pos()
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
			Step.DOUSE when str(step.get("where", "")) == "lamp":
				return "Douse the green fire in Moll's lamp"
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
		Step.DOUSE when str(step.get("where", "")) == "lamp":
			return "Climb the lighthouse and douse the green fire in the lamp (take water up)"
		Step.READ:
			if step.has("hint"):
				return step.hint
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
		Step.BOUNTY when step.get("linnet", false):
			return "Follow Linnet's light; shoot the lantern from her hand and bring her skull to %s" % person_name(step.to)
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
			return step.get("hint", "Dive at the San Telmo's wreck off Gull Isle (hold E over it)")
		Step.CONVOY:
			return "Take the convoy's gold to %s (%d chests left)" % [person_name(step.to), lit] if lit > 0 else "Take the convoy's gold to %s" % person_name(step.to)
		Step.BELLS:
			return "Shoot down the drowned bells (%d left)" % lit if lit > 0 else "Shoot down the drowned bells"
		Step.ASK:
			if step.has("hint"):
				return "%s (%d left)" % [step.hint, lit] if lit > 0 else step.hint
			return "Ask Jonah, Moll and Silas what they saw (%d left)" % lit if lit > 0 else "Ask about Merrow"
		Step.SEARCH:
			return "Search the crates on Port Merrow's pier"
		Step.BREACH:
			return "Blow open the fort's gate (its powder is outside)"
		Step.USE:
			match str(step.object):
				"cells":
					return "Free the prisoners in the cells"
				"hulk":
					return "Open Isabel's cell on the hulk's deck"
			return "Open the vault"
		Step.SIEGE_SEA:
			return "Sink the Spanish galleons in Merrow's bay (%d left)" % lit if lit > 0 else "Sink the Spanish galleons"
		Step.SIEGE_BEACH:
			return "Hold Merrow's beach against the dead (%d up)" % standing if standing > 0 else "Hold Merrow's beach"
		Step.SNIPER:
			return "Shoot La Viuda down from the flagship's quarterdeck"
		Step.DOCTOR:
			return "Fell what the Doctor raises (%d up)" % standing
		Step.CHASE:
			return "Catch the crab with Captain Coco on %s and bring him to %s" % [Islands.LAYOUT[step.island].name, person_name(step.to)]
		Step.HULK:
			return "Board the prison hulk in the fog off Isla Ceniza unseen, and fell the jailer at her stern"
		Step.GHOST:
			return "Find the storm, and sink the ghost galleon that rises in it" if lit == 0 else "Sink the ghost galleon"
		Step.LANTERNS:
			return "Smash the green lanterns on the Black Reef's sea stacks (%d left)" % lit if lit > 0 else "Smash the green lanterns"
		Step.GAMBIT:
			match lit:
				0:
					return "Sail close to the Black Reef, the bait for the Cuervo Negro"
				1:
					return "Run! Lead the Cuervo Negro to Isabel's ambush east of the fort"
			return "Hole the Cuervo Negro with La Golondrina (%d more)" % standing if standing > 0 else "Hole the Cuervo Negro"
		Step.RISEN:
			return "Sail into the Black Reef and sink the risen galleons (%d left)" % lit if lit > 0 else "Sail into the Black Reef's storm"
		Step.CRIPPLE:
			return "Cripple the Cuervo Negro (%d more holes)" % lit if lit > 0 else "Cripple the Cuervo Negro"
		Step.ADMIRAL:
			return "Board the Cuervo Negro and beat the Raven Admiral (strike from the side or behind)"
		Step.ASHEN:
			return "Land on Isla Ceniza and beat the ashen dead (%d up)" % standing if standing > 0 else "Land on Isla Ceniza"
		Step.OCASO:
			return "Douse Ocaso's braziers (%d burning), then beat him" % lit if lit > 0 else "Beat Doctor Ocaso"
		Step.BEACONS:
			return "Light the beacons on Cutlass Cay, Parrot Rock and Gull Isle (%d left)" % lit if lit > 0 else "Light the beacons"
		Step.ASH_FLAGSHIP:
			return "Sink the Ash Admiral's flagship at the Maw"
		Step.COLOSSUS:
			return "Break the Bone Colossus's glowing joints with cannon (%d left)" % lit if lit > 0 else "Break the Bone Colossus"
		Step.ASH_DUEL:
			return "Land on the Anvil and beat the Ash Admiral (strike from the side or behind)"
		Step.HEART:
			return "Carry the Heart of Ash to the Maw's edge and throw it in (it burns)"
		Step.GATHER:
			var what: String = {"planks": "a bundle of planks from each wreck", "tea": "floating tea crates (%d left)" % lit,
				"hueso": "Señor Hueso's crate (on the pier)", "fine_tea": "the fine tea from Hueso's kitchen (%d left)" % lit,
				"oil": "lamp oil from the tavern door", "cannon": "the cannons from Cutlass Cay's old camp (%d left)" % lit,
				"saltshot": "salt, a piece of drowned bell and the Black Reef's brine (%d left)" % lit,
				"barricade": "barricades from the tavern door (%d left)" % lit,
				"hoard": "Hollowbell's hoard from Cutlass Cay's old camp (%d left)" % lit,
				"chart": "the pilot's chart, dug from his grave on Isla Calavera",
				"saltshot_crates": "the saltshot from the pier (%d left)" % lit,
				"wren_lantern": "Wren's lantern"}[step.item]
			var to: String = {"lamp": "the lighthouse lamp", "battery": "Merrow's battery", "pier": "the pier", "reef_edge": "the edge of the Black Reef (the West Stack)"}.get(str(step.to), "")
			if to == "":
				to = "Gull Isle's beach" if str(step.to).begins_with("beach") else person_name(step.to)
			return "Bring %s to %s" % [what, to]
	return ""

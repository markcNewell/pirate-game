class_name Music
extends RefCounted
## The score (docs/specs/2026-10-08-m23-music.md): which music fits what is going on around you,
## and the tracks for each. Pure rules: Game says what is near, Audio plays and crossfades.
## Every track is Kevin MacLeod's (incompetech.com), licensed under Creative Commons: By
## Attribution 4.0 (CREDITS.md).

enum Mood { NONE, TITLE, DAY, NIGHT, STORM, DEAD, BATTLE, BOSS }

## Tracks in art/music for each mood, played in turn.
const TRACKS := {
	Mood.TITLE: ["title_celtic_impulse"],
	Mood.DAY: ["sail_fiddles_mcginty", "sail_achaidh_cheide"],
	Mood.NIGHT: ["night_errigal"],
	Mood.STORM: ["storm_the_pyre"],
	Mood.DEAD: ["dead_one_eyed_maestro"],
	Mood.BATTLE: ["battle_five_armies"],
	Mood.BOSS: ["boss_danse_macabre"],
}
## The tavern's music at Port Merrow (heard from the Drowned Rat, not the score).
const TAVERN := "tavern_galway"
## Played over the score when you level up.
const STING := "sting_discovery_hit"
## Calm moods rest between tracks, so the sea and the wind get a turn (seconds of quiet).
const REST := {Mood.DAY: 50.0, Mood.NIGHT: 60.0}
## Danger keeps its music this long after it has passed, so a lull doesn't flip the score.
const LINGER := {Mood.BOSS: 12.0, Mood.BATTLE: 12.0, Mood.DEAD: 8.0}
## How near danger must be (metres): a skeleton ship to your ship, the dead to you, a boss to you.
const SHIP_NEAR := 230.0
const DEAD_NEAR := 30.0
const BOSS_NEAR := 120.0
const COLOSSUS_NEAR := 450.0
## A storm this strong where you are (Storm.amount) brings the storm music.
const STORM_AT := 0.45
## Near Port Merrow the score falls silent and the tavern plays.
const PORT_NEAR := 70.0

## Credits for CREDITS.md and the title screen: file -> title.
const TITLES := {
	"title_celtic_impulse": "Celtic Impulse", "sail_fiddles_mcginty": "Fiddles McGinty",
	"sail_achaidh_cheide": "Achaidh Cheide", "night_errigal": "Errigal", "storm_the_pyre": "The Pyre",
	"dead_one_eyed_maestro": "One-eyed Maestro", "battle_five_armies": "Five Armies",
	"boss_danse_macabre": "Danse Macabre", "tavern_galway": "Galway", "sting_discovery_hit": "Discovery Hit",
}
const CREDIT := "Music by Kevin MacLeod (incompetech.com), licensed under Creative Commons: By Attribution 4.0"


## The mood for what is around you. `state`: boss, battle, dead (bool: danger near now),
## storm (0-1), night (bool), port (bool), and since (mood -> the time its danger was last
## near) with now (the time), for lingering.
static func pick(state: Dictionary) -> int:
	var now: float = state.get("now", 0.0)
	var since: Dictionary = state.get("since", {})
	for mood: int in [Mood.BOSS, Mood.BATTLE, Mood.DEAD]:
		var key: String = {Mood.BOSS: "boss", Mood.BATTLE: "battle", Mood.DEAD: "dead"}[mood]
		if state.get(key, false) or now - float(since.get(mood, -1e9)) < LINGER[mood]:
			return mood
	if float(state.get("storm", 0.0)) >= STORM_AT:
		return Mood.STORM
	if state.get("port", false):
		return Mood.NONE
	return Mood.NIGHT if state.get("night", false) else Mood.DAY


## The track to play next for `mood`, after `last` (in turn), or "" for none.
static func next_track(mood: int, last: String) -> String:
	var list: Array = TRACKS.get(mood, [])
	if list.is_empty():
		return ""
	var i := list.find(last)
	return list[(i + 1) % list.size()]

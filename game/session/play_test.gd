class_name PlayTest
extends RefCounted
## The title screen's play-test options (docs/specs/2026-10-08-m22-play-test.md): host straight
## into any chapter with everything before it done, with gold to spend, or with a world event
## under way. Pure rules: the menu turns a choice into server options (the test hooks).

## World events that can be started at once ("" for none), as named for --event.
const EVENTS: Array[String] = ["", "green_fire", "patrol", "convoy", "raid", "fort", "maw"]


## Every chapter that must be done before `id`: for a story chapter, the story chapters before
## it; for a tale, the chapter it follows and everything before that.
static func done_before(id: String) -> Array[String]:
	var out: Array[String] = []
	var ch := Story.chapter(id)
	if ch.is_empty():
		return out
	if ch.has("after"):
		var before: String = ch.after
		out.append_array(done_before(before))
		out.append(before)
		return out
	for c: Dictionary in Story.CHAPTERS:
		if c.id == id:
			break
		if not c.has("after"):
			out.append(c.id)
	return out


## The server options for a play-test game: never saved; the chapter started for crew 1 by its
## first island, with what came before it done and the level its act asks for.
static func options_for(chapter_id: String, gold: int, event: String) -> Dictionary:
	var out := {"no-save": true}
	var ch := Story.chapter(chapter_id)
	if not ch.is_empty():
		out["chapter"] = chapter_id
		out["jump"] = true
		var done := done_before(chapter_id)
		if not done.is_empty():
			out["done"] = ",".join(done)
		out["xp"] = Progress.xp_for(Progress.ACT_LEVEL[int(ch.act)])
	if gold > 0:
		out["gold"] = gold
	if event in EVENTS and event != "":
		out["event"] = event
	return out


## The WorldEvents kind for an EVENTS name.
static func event_kind(event: String) -> int:
	return {
		"green_fire": WorldEvents.Kind.GREEN_FIRE, "patrol": WorldEvents.Kind.PATROL, "convoy": WorldEvents.Kind.CONVOY,
		"raid": WorldEvents.Kind.RAID, "fort": WorldEvents.Kind.FORT, "maw": WorldEvents.Kind.MAW,
	}.get(event, WorldEvents.Kind.NONE)


## "P1  Strange Lights", "T6  Penny's Hoard: ..." for the menu's list.
static func label(i: int) -> String:
	var ch: Dictionary = Story.CHAPTERS[i]
	var tale := " (%s)" % ch.tale if ch.has("tale") else ""
	return "%s  %s%s" % [str(ch.id).to_upper(), ch.title, tale]

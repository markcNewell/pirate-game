extends "res://tests/support/case.gd"
## The title screen's play-test options (docs/specs/2026-10-08-m22-play-test.md).


func test_a_story_chapter_needs_the_ones_before_it() -> void:
	check_eq(PlayTest.done_before("p1"), [] as Array[String], "the first needs nothing")
	check_eq(PlayTest.done_before("b1"), ["p1", "p2", "a1", "a2", "a3", "a4", "a5", "a6"] as Array[String], "Act II needs the prologue and Act I")
	check(not PlayTest.done_before("e6").has("t1"), "no tales needed for the story")


func test_a_tale_needs_its_own_chain() -> void:
	var done := PlayTest.done_before("t11")
	for id: String in ["t10", "t9", "c6", "c1", "b6", "p1"]:
		check(done.has(id), "t11 needs %s" % id)
	check(not done.has("d1"), "but nothing after the siege")
	check(not done.has("t6"), "nor another tale")


func test_options_never_save_and_set_the_level() -> void:
	var o := PlayTest.options_for("d2", 3000, "patrol")
	check(o.has("no-save"), "a play-test game never saves your pirate")
	check_eq(o.chapter, "d2")
	check_eq(o.gold, 3000)
	check_eq(o.event, "patrol")
	check_eq(Progress.level(int(o.xp)), Progress.ACT_LEVEL[4], "the level Act IV asks for")
	check(str(o.done).split(",").has("d1"), "with d1 done")
	check_eq(PlayTest.options_for("", 0, ""), {"no-save": true}, "nothing chosen: just don't save")


func test_jumping_into_a_chapter() -> void:
	var sim := ServerSim.new(PlayTest.options_for("d2", 500, "").merged({"no-ai": true, "calm": true}))
	sim.add_player(1, "Anne", 1, "a")
	var m: Dictionary = sim.crews[ServerSim.CREW].mission
	check(not m.is_empty() and Story.CHAPTERS[m.chapter].id == "d2", "the chapter is under way")
	var p: Dictionary = sim.players[1].profile
	check(p.chapters.has("d1") and p.chapters.has("c6"), "everything before it done")
	check_eq(int(p.gold), 500)
	var ship: ShipState = sim.ships[ServerSim.CREW]
	if not m.get("islands", []).is_empty():
		var spec: Dictionary = Islands.LAYOUT[int(m.islands[0])]
		check(Vector2(ship.x - spec.x, ship.z - spec.z).length() < float(spec.radius) + 60.0, "the ship starts by its island")


func test_every_chapter_can_be_jumped_to() -> void:
	for ch: Dictionary in Story.CHAPTERS:
		var sim := ServerSim.new(PlayTest.options_for(ch.id, 0, "").merged({"no-ai": true, "calm": true}))
		check(not sim.crews[ServerSim.CREW].mission.is_empty(), "%s starts" % ch.id)


func test_every_event_can_be_started() -> void:
	for e: String in PlayTest.EVENTS:
		if e != "":
			check(PlayTest.event_kind(e) != WorldEvents.Kind.NONE, "%s is an event" % e)

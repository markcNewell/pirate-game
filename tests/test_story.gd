extends "res://tests/support/case.gd"

const DT := 1.0 / 30.0


func _sim(options := {}) -> ServerSim:
	options["no-ai"] = true
	options["calm"] = true
	var sim := ServerSim.new(options)
	sim.add_player(1, "Anne", 1, "a")
	return sim


## Put a player ashore at a world point.
func _ashore(sim: ServerSim, id: int, at: Vector3) -> Dictionary:
	var r: Dictionary = sim.players[id]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = at
	return r


func _talk(sim: ServerSim, id: int, who: String) -> void:
	_ashore(sim, id, Story.person_pos(who))
	sim.request(id, "talk", Story.PEOPLE_IDS.find(who), [])


func _object(sim: ServerSim, kind: int) -> StoryObject:
	for id in sim.story.objects:
		if sim.story.objects[id].kind == kind:
			return sim.story.objects[id]
	return null


func test_chapters_open_in_order() -> void:
	check_eq(Story.next_for([[]]), 0, "a new pirate starts at the prologue")
	check(Story.open_for(0, [[]]), "the prologue is open")
	check(not Story.open_for(1, [[]]), "P2 waits for P1")
	check(Story.open_for(1, [[], ["p1"]]), "but anyone aboard who has done P1 opens it")
	check_eq(Story.next_for([["p1"], []]), 0, "the crew's next is the first not everyone has done")
	check_eq(Story.next_for([["p1"]]), 1)
	check_eq(Story.offered_by("moll", [[]]), 0, "Moll gives P1")
	check_eq(Story.offered_by("wren", [[]]), -1, "Wren has nothing yet")
	check_eq(Story.offered_by("wren", [["p1"]]), 1)
	check_eq(Story.offered_by("moll", [["p1", "p2"]]), 0, "done chapters can be played again")
	for ch: Dictionary in Story.CHAPTERS:
		check(Story.PEOPLE.has(ch.giver), "%s has a giver" % ch.id)
		check(not ch.steps.is_empty(), "%s has steps" % ch.id)


func test_people_stand_on_dry_land() -> void:
	var isl := Islands.outpost_index()
	for who: String in Story.PEOPLE_IDS:
		var at := Story.person_pos(who)
		var dry := Islands.ground_at(isl, at.x, at.z) > Waves.max_height() or at.y >= Outpost.PIER_Y
		check(dry, "%s stands on dry land or the pier" % who)
	check(Story.person_pos("moll").distance_to(Story.person_pos("wren")) > 6.0, "Moll is not at Wren's elbow")


func test_strange_lights_from_moll_to_moll() -> void:
	var sim := _sim()
	_talk(sim, 1, "moll")
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.kind, Missions.Kind.STORY, "Moll starts the chapter")
	check_eq(m.name, "p1")
	check_eq(m.step, 0)

	# Read the journal on Gull Isle.
	var book := _object(sim, StoryObject.Kind.BOOK)
	check(book != null, "a journal lies on Gull Isle")
	check_eq(Islands.island_at(book.pos.x, book.pos.z), 2)
	_ashore(sim, 1, book.pos)
	sim.request(1, "read", book.id, [])
	check_eq(m.step, 1, "read")
	check(not sim.story.objects.has(book.id), "the journal is taken")

	# Douse the green fire: the bucket is filled from the sea first.
	var fire := _object(sim, StoryObject.Kind.FIRE)
	check(fire != null and fire.state == 1, "a green fire burns")
	var r := _ashore(sim, 1, fire.pos)
	sim.request(1, "douse", fire.id, [])
	check_eq(fire.state, 1, "no water, no dousing")
	var spec: Dictionary = Islands.LAYOUT[2]
	r.pos = Vector3(spec.x + spec.radius + 6.0, -0.6, spec.z)
	sim.request(1, "scoop", 0, [])
	check(r.bucket, "a bucket filled in the sea")
	r.pos = fire.pos
	sim.request(1, "douse", fire.id, [])
	check_eq(fire.state, 0, "the fire is out")
	check(not r.bucket, "the bucket is empty")
	check_eq(sim.story.standing(m), 3, "three dead climb out")
	check_eq(m.step, 1, "still to fell them")
	for sid: int in m.raised.duplicate():
		check(sim.skeletons[sid].spanish, "Spanish dead")
		sim._hurt_skeleton(sid, 999, "Anne", 1)
	check_eq(m.step, 2, "the dead are down")
	check_eq(sim.players[1].profile.xp, 3 * Progress.XP_SPANISH, "XP for the Spanish dead")

	# Back to Moll.
	_talk(sim, 1, "moll")
	check(sim.crews[1].mission.is_empty(), "the chapter is over")
	var p: Dictionary = sim.players[1].profile
	check(p.chapters.has("p1"), "ticked off")
	check_eq(p.xp, 3 * Progress.XP_SPANISH + 300, "chapter XP")
	check_eq(p.gold, 150, "and gold")
	check(not sim.story.objects.has(fire.id), "the cold grave goes with the chapter")


func test_a_busy_crew_is_told_to_come_back() -> void:
	var sim := _sim({"mission": "cargo"})
	sim.players[1].pos = ShipShape.MAP_TABLE + Vector3(0.9, 0, 0.6)
	sim.request(1, "voyage", Missions.Company.MERCHANT, [])
	_talk(sim, 1, "moll")
	check_eq(sim.crews[1].mission.kind, Missions.Kind.CARGO, "the cargo run carries on")


func test_bess_her_skull_and_the_thieves() -> void:
	var sim := _sim()
	sim.players[1].profile.chapters.append("p1")
	_talk(sim, 1, "wren")
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.name, "p2", "Wren starts Black-Eyed Bess")
	var bess: Skeleton = sim.skeletons[m.captain]
	check(bess.captain, "Bess walks")
	check_eq(m.thieves.size(), 2, "two Spanish thieves")
	check(_object(sim, StoryObject.Kind.BOAT) != null, "with their boat")

	# Bess falls far from anyone; a thief runs for her skull and makes off with it.
	sim._hurt_skeleton(bess.id, 999, "Anne", 1)
	check(m.skull >= 0, "her skull lies on the sand")
	var skull_id: int = m.skull
	for i in 30 * 60:
		sim._step_skeletons(DT)
		if not sim.items.has(skull_id):
			break
	check_eq(sim.stats.thefts, 1, "a thief got it to the boat")
	check_eq(sim.crews[1].mission.name, "p2", "the chapter carries on")
	check(sim.skeletons.has(m.captain) and sim.skeletons[m.captain].captain, "Bess rises again")

	# This time catch the thief: it drops the skull, and Wren gets it.
	bess = sim.skeletons[m.captain]
	sim._hurt_skeleton(bess.id, 999, "Anne", 1)
	skull_id = m.skull
	var thief: Skeleton = null
	for i in 30 * 30:
		sim._step_skeletons(DT)
		for sid: int in sim.skeletons:
			if sim.skeletons[sid].holding == skull_id:
				thief = sim.skeletons[sid]
		if thief:
			break
	check(thief != null, "a thief grabbed it again")
	check_eq(sim.items[skull_id].state, Loot.State.HELD, "held in its arms")
	sim._hurt_skeleton(thief.id, 999, "Anne", 1)
	check_eq(sim.items[skull_id].state, Loot.State.GROUND, "dropped when it falls")
	var r := _ashore(sim, 1, sim.items[skull_id].pos)
	sim.request(1, "pickup", skull_id, [])
	check_eq(r.carry, skull_id)
	r.pos = Outpost.mystic_spot()
	sim.request(1, "sell", 0, [])
	check(sim.crews[1].mission.is_empty(), "Wren takes it and the chapter ends")
	check(sim.players[1].profile.chapters.has("p2"), "ticked off")
	check(sim.players[1].profile.gold > 0, "paid for the skull")


func test_the_board_names_the_next_chapter() -> void:
	var sim := _sim()
	var entry: Array = sim.story.board_entry(1)
	check_eq(entry[3], "Strange Lights")
	check(str(entry[6]).contains("Moll Tinder"), "who to see")
	sim.players[1].profile.chapters.append_array(["p1", "p2"])
	check_eq(sim.story.board_entry(1)[3], "Dig Faster", "then Act I")


func test_chapter_test_hook() -> void:
	var sim := _sim({"chapter": "p1", "chapter-step": "1"})
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.step, 1, "starts at the douse")
	check(_object(sim, StoryObject.Kind.FIRE) != null, "the fire is lit")
	var arr := sim._mission_array(1)
	var decoded := Game._decode_mission(arr)
	check_eq(decoded.kind, Missions.Kind.STORY)
	check_eq(decoded.captain, "p1", "the chapter id rides in the name")
	check_eq(decoded.handled, 1, "and the step")
	check_eq(decoded.total, 1, "one fire lit")

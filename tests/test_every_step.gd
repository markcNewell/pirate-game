extends "res://tests/support/case.gd"
## Every chapter can be started at every one of its steps, and what each step puts in the world
## is somewhere sensible: on the map, nothing NaN, and the dead standing on ground they can walk
## (a safety net under the per-act tests; Claude's QA pass before play-testing).

const DT := 1.0 / 30.0
const MAP := 1400.0


func _check_world(sim: ServerSim, where: String) -> void:
	for id in sim.story.objects:
		var o: StoryObject = sim.story.objects[id]
		var p := o.pos
		check(is_finite(p.x) and is_finite(p.y) and is_finite(p.z), "%s: object %d (kind %d) has a position" % [where, id, o.kind])
		if o.ship < 0:
			check(absf(p.x) < MAP and absf(p.z) < MAP, "%s: object %d (kind %d) is on the map at %s" % [where, id, o.kind, p])
	for sid in sim.skeletons:
		var sk: Skeleton = sim.skeletons[sid]
		check(is_finite(sk.pos.x) and is_finite(sk.pos.y) and is_finite(sk.pos.z), "%s: skeleton %d has a position" % [where, sid])
		if sk.frame < 0 and sk.alive():
			var floor_y: float = sim._floor_for(sk).call(sk.pos.x, sk.pos.z)
			check(is_finite(floor_y), "%s: skeleton %d (home %d, story crew %d) stands on something at %s" % [where, sid, sk.home, sk.story_crew, sk.pos])
	for id in sim.ships:
		var s: ShipState = sim.ships[id]
		check(is_finite(s.x) and is_finite(s.z) and absf(s.x) < MAP and absf(s.z) < MAP, "%s: ship %d is on the map" % [where, id])
	for id in sim.items:
		var it: Loot = sim.items[id]
		check(is_finite(it.pos.x) and is_finite(it.pos.y) and is_finite(it.pos.z), "%s: item %d has a position" % [where, id])


## Things a pirate walks up to and presses E at: they must be on dry land you can stand on.
const ON_LAND: Array[int] = [
	StoryObject.Kind.FIRE, StoryObject.Kind.BOOK, StoryObject.Kind.GRAVE, StoryObject.Kind.KEG,
	StoryObject.Kind.STORE, StoryObject.Kind.BONFIRE, StoryObject.Kind.SEARCH, StoryObject.Kind.CELL,
	StoryObject.Kind.VAULT, StoryObject.Kind.BATTERY, StoryObject.Kind.CARVING, StoryObject.Kind.BRAZIER,
	StoryObject.Kind.BEACON,
]


func _check_reachable(sim: ServerSim, where: String) -> void:
	for id in sim.story.objects:
		var o: StoryObject = sim.story.objects[id]
		if o.ship >= 0 or o.kind not in ON_LAND:
			continue
		if o.kind == StoryObject.Kind.BOOK and sim.crews[ServerSim.CREW].mission.get("spot", Vector3.ZERO) == Vector3.ZERO and o.pos.length() < 2.0:
			continue  # dropped "here", where the step before (not played in this test) ended
		if Outpost.on_pier(o.pos.x, o.pos.z):
			continue  # on Merrow's pier
		var island := Islands.island_at(o.pos.x, o.pos.z)
		check(island >= 0, "%s: object %d (kind %d) is on an island at %s" % [where, id, o.kind, o.pos])
		if island < 0:
			continue
		var ground := Islands.ground_at(island, o.pos.x, o.pos.z)
		var sea := Waves.height(o.pos.x, o.pos.z, sim.time)
		check(ground > sea + 0.1, "%s: object %d (kind %d) is above the sea at %s (ground %.2f, sea %.2f)" % [where, id, o.kind, o.pos, ground, sea])
		var spec: Dictionary = Islands.LAYOUT[island]
		if spec.get("fort", false) and o.kind not in [StoryObject.Kind.KEG]:
			check(not Fort.blocked(o.pos.x - spec.x, o.pos.z - spec.z, true), "%s: object %d (kind %d) is not inside the fort's walls" % [where, id, o.kind])
	for id in sim.items:
		var it: Loot = sim.items[id]
		if it.state != Loot.State.GROUND or Outpost.on_pier(it.pos.x, it.pos.z):
			continue
		var island := Islands.island_at(it.pos.x, it.pos.z)
		if island >= 0:
			check(Islands.ground_at(island, it.pos.x, it.pos.z) > Waves.height(it.pos.x, it.pos.z, sim.time), "%s: item %d (%s) lies above the sea" % [where, id, it.label()])


func test_every_step_of_every_chapter() -> void:
	for i in Story.CHAPTERS.size():
		var ch: Dictionary = Story.CHAPTERS[i]
		for step in ch.steps.size():
			var sim := ServerSim.new({"no-ai": true, "calm": true})
			sim.add_player(1, "Anne", 1, "a")
			sim.story.start(ServerSim.CREW, i, step)
			for n in 30:
				sim.time += DT
				sim.story.tick(DT)
				sim._step_skeletons(DT)
			_check_world(sim, "%s step %d" % [ch.id, step])
			_check_reachable(sim, "%s step %d" % [ch.id, step])


func test_every_world_event() -> void:
	for e: String in PlayTest.EVENTS:
		if e == "":
			continue
		var sim := ServerSim.new({"no-ai": true, "calm": true})
		sim.add_player(1, "Anne", 1, "a")
		sim.world.start(PlayTest.event_kind(e), Vector3(sim.ships[ServerSim.CREW].x, 0, sim.ships[ServerSim.CREW].z))
		for n in 30:
			sim.time += DT
			sim.world.tick(DT)
			sim._step_skeletons(DT)
		_check_world(sim, e)
		_check_reachable(sim, e)


func test_every_step_says_what_to_do() -> void:
	for ch: Dictionary in Story.CHAPTERS:
		for step: Dictionary in ch.steps:
			for done: bool in [false, true]:
				var text := Story.step_text(step, 1, 2, done)
				var where := "%s step kind %d%s" % [ch.id, step.kind, " (done)" if done else ""]
				check(text.strip_edges() != "", "%s: says something" % where)
				check(not text.contains("%") and not text.contains("{") and not text.contains("<null>"), "%s: no unfilled gaps: %s" % [where, text])
				check(text.length() <= 140, "%s: fits the card (%d letters): %s" % [where, text.length(), text])


func test_the_mission_card_for_every_step() -> void:
	# What the HUD shows as a chapter goes on (bots have no HUD, so the smoke tests never draw it).
	for ch: Dictionary in Story.CHAPTERS:
		for handled in ch.steps.size() + 1:
			for deadline: float in [-1.0, 90.0]:
				var m := {"kind": Missions.Kind.STORY, "captain": ch.id, "handled": handled, "total": 2, "standing": 1, "deadline": deadline}
				var lines: Array = Hud.MissionCard.steps(m, 0.0)
				check(not lines.is_empty(), "%s after %d steps: the card says something" % [ch.id, handled])
				for line: Array in lines:
					check(str(line[0]).strip_edges() != "", "%s after %d steps: no blank line" % [ch.id, handled])
		check(Hud.MissionCard.act_name({"captain": ch.id}) != "", "%s has an act name" % ch.id)


func test_everyone_the_story_names_exists() -> void:
	for ch: Dictionary in Story.CHAPTERS:
		check(Story.PEOPLE.has(ch.giver), "%s: its giver %s is one of Merrow's people" % [ch.id, ch.giver])
		for step: Dictionary in ch.steps:
			if step.has("who"):
				var whom: Array = step.who if step.who is Array else [step.who]
				for who: String in whom:
					check(Story.PEOPLE.has(who), "%s: %s is one of Merrow's people" % [ch.id, who])
			if step.has("to"):
				var to: String = step.to
				var place := to in ["lamp", "reef_edge", "battery", "pier"] or (to.begins_with("beach:") and int(to.trim_prefix("beach:")) < Islands.LAYOUT.size())
				check(Story.PEOPLE.has(to) or place, "%s: things go to %s, someone or somewhere real" % [ch.id, to])
			if step.has("island"):
				# -1: the step finds its own island (the fort, say).
				check(int(step.island) >= -1 and int(step.island) < Islands.LAYOUT.size(), "%s: island %d exists" % [ch.id, step.island])
		if ch.has("after"):
			check(Story.index_of(ch.after) >= 0, "%s follows %s, which exists" % [ch.id, ch.after])
		if ch.has("gift"):
			check(Shop.index_of(ch.gift) >= 0, "%s's gift %s is in Martha's book" % [ch.id, ch.gift])


func test_the_mission_card_for_every_board_mission() -> void:
	# Every company's mission with each of the war's twists, as the HUD would show it.
	var twists := {
		Missions.Kind.TREASURE: [{}, {"diggers": true}, {"cache": true}, {"wreck": true}],
		Missions.Kind.BOUNTY: [{}, {"officer": true, "captain": "Teniente Ruiz"}, {"pressed": true, "captain": "Captain Hollowbell"}, {"ghost": true, "captain": Missions.GHOST_CAPTAIN}],
		Missions.Kind.CARGO: [{}, {"goods": 3}, {"raided": true}],
	}
	for company in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var base := Missions.make_offer(company, 2, Islands.mission_islands(), rng)
		for twist: Dictionary in twists[int(base.kind)]:
			var sim := ServerSim.new({"no-ai": true, "calm": true})
			sim.add_player(1, "Anne", 1, "a")
			var offer := base.duplicate(true)
			offer.merge(twist, true)
			sim._start_mission(ServerSim.CREW, offer)
			var where := "%s %s" % [offer.title, twist.keys()]
			var m := Game._decode_mission(sim._mission_array(ServerSim.CREW))
			check(not m.is_empty(), "%s: sent to the crew" % where)
			if m.is_empty():
				continue
			var lines: Array = Hud.MissionCard.steps(m, 0.0)
			check(not lines.is_empty(), "%s: the card says something" % where)
			for t: Dictionary in m.targets:
				check(not t.done, "%s: nothing found yet" % where)
			if twist.get("ghost", false):
				check(not lines[0][1], "%s: the ghost isn't sunk yet" % where)
				var ghost: ShipState = sim.ships[int(sim.crews[ServerSim.CREW].mission.ghost)]
				check(Vector2(m.targets[0].x, m.targets[0].z).distance_to(Vector2(ghost.x, ghost.z)) < 1.0, "%s: the mark is on her" % where)

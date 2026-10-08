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

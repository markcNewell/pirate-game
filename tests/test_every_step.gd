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

extends "res://tests/support/case.gd"
## Act II of the story, chapter by chapter (docs/specs/2026-10-08-m9-the-ravens-due.md).

const DT := 1.0 / 30.0


func _sim(chapter: String, step := 0) -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true, "chapter": chapter, "chapter-step": str(step)})
	sim.add_player(1, "Anne", 1, "a")
	return sim


func _ashore(sim: ServerSim, at: Vector3) -> Dictionary:
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = at
	return r


func _first(sim: ServerSim, kind: int) -> StoryObject:
	for o: StoryObject in sim.story.objects.values():
		if o.kind == kind:
			return o
	return null


func _all(sim: ServerSim, kind: int) -> Array[StoryObject]:
	var out: Array[StoryObject] = []
	for o: StoryObject in sim.story.objects.values():
		if o.kind == kind:
			out.append(o)
	return out


func _run(sim: ServerSim, seconds: float) -> void:
	for i in int(seconds / DT):
		sim.time += DT
		sim.story.tick(DT)
		sim._step_skeletons(DT)
		sim._step_projectiles()


func _fell_all(sim: ServerSim) -> void:
	for sid in sim.skeletons.keys():
		if sim.skeletons.has(sid) and sim.skeletons[sid].alive() and not sim.skeletons[sid].bomber:
			sim._hurt_skeleton(sid, 9999, "Anne", 1)


func test_act_two_needs_level_five_and_act_one() -> void:
	var b1 := Story.index_of("b1")
	check(Story.open_for(b1, [["a6"]]), "Act II follows the Sergeant's camp")
	check_eq(Story.CHAPTERS[b1].act, 2)
	var sim := ServerSim.new({"no-ai": true, "calm": true})
	sim.add_player(1, "Anne", 1, "a")
	sim.players[1].profile.chapters.append_array(["p1", "p2", "a1", "a2", "a3", "a4", "a5", "a6"])
	_ashore(sim, Story.person_pos("moll"))
	sim.request(1, "talk", Story.PEOPLE_IDS.find("moll"), [])
	check(sim.crews[1].mission.is_empty(), "not at level 1")
	sim._award(1, Progress.xp_for(5), "a test")
	sim.request(1, "talk", Story.PEOPLE_IDS.find("moll"), [])
	check_eq(sim.crews[1].mission.get("name", ""), "b1", "at level 5 Moll sends you for the deserter")


func test_the_fort_island_and_its_walls() -> void:
	var fort := Fort.index()
	check(fort >= 0, "Fuerte del Cuervo is on the map")
	check(not Islands.mission_islands().has(fort), "no treasure or bounties there")
	var spec: Dictionary = Islands.LAYOUT[fort]
	check(absf(Islands.ground_at(fort, spec.x, spec.z) - Fort.PLATEAU_Y) < 0.01, "a flat top")
	var gate := Fort.local(0.0, Fort.WALL_R)
	check(Fort.blocked(gate.x, gate.y, false), "the gate shut blocks the way")
	check(not Fort.blocked(gate.x, gate.y, true), "blown, it lets you through")
	var wall := Fort.local(PI / 2.0, Fort.WALL_R)
	check(Fort.blocked(wall.x, wall.y, true), "the walls always block")
	check(not Fort.blocked(0.0, 4.5, true), "the courtyard is open")


func test_a_deserter_at_dawn() -> void:
	var sim := _sim("b1")
	var m: Dictionary = sim.crews[1].mission
	var boat := _first(sim, StoryObject.Kind.BOAT)
	var isabel := _first(sim, StoryObject.Kind.ISABEL)
	check(boat != null and isabel != null, "Isabel in a drifting boat")
	var hunter: ShipState = sim.ships.get(m.ship)
	check(hunter != null and hunter.flag == 0, "a skeleton ship hunting her")
	var r := _ashore(sim, boat.pos + Vector3(20, 0, 0))
	sim.request(1, "rescue", 0, [])
	check_eq(m.step, 0, "too far to help her")
	r.pos = boat.pos + Vector3(3, -1.0, 0)
	sim.request(1, "rescue", 0, [])
	check_eq(m.step, 1, "she is aboard")
	check_eq(isabel.ship, 1, "on our deck")
	# Sink with her aboard: she is lost and the boat is adrift again.
	sim.crew_ship().sink = 0.01
	sim._handle_sinking()
	check_eq(m.step, 0, "lost with the ship: back to the boat")
	check(_first(sim, StoryObject.Kind.BOAT) != null, "another boat adrift")
	# Rescue again and sail home.
	sim.crew_ship().sink = 0.0
	r.pos = _first(sim, StoryObject.Kind.BOAT).pos + Vector3(2, -1.0, 0)
	sim.request(1, "rescue", 0, [])
	var ship := sim.crew_ship()
	ship.x = Outpost.spec().x + 50.0
	ship.z = Outpost.spec().z
	sim.story.tick(DT)
	check(sim.crews[1].mission.is_empty(), "Isabel is ashore at Port Merrow")
	check(sim.players[1].profile.chapters.has("b1"), "ticked off")


func test_the_admirals_story_dive() -> void:
	var sim := _sim("b2")
	var m: Dictionary = sim.crews[1].mission
	var wreck := _first(sim, StoryObject.Kind.WRECK)
	check(wreck != null, "the San Telmo's wreck")
	var r := _ashore(sim, wreck.pos + Vector3(1.0, -1.2, 0))
	for i in int(StoryRun.DIVE_TIME / 0.3) + 2:
		sim.time += 0.3
		sim.request(1, "dive", 0, [])
	check_eq(m.step, 1, "the logbook found")
	check_eq(sim.stats.dives, 1)
	r.pos = Story.person_pos("isabel")
	sim.request(1, "talk", Story.PEOPLE_IDS.find("isabel"), [])
	check(sim.crews[1].mission.is_empty(), "told to Isabel")


func test_starve_the_fire_convoy() -> void:
	var sim := _sim("b3")
	var m: Dictionary = sim.crews[1].mission
	var g: ShipState = sim.ships[m.ship]
	check(sim.captains[m.ship].fleeing, "the treasure galleon runs")
	check_eq(g.flag, 1)
	var escorts := 0
	for id in sim.ships:
		if not sim.crews.has(id) and id != m.ship:
			escorts += 1
	check_eq(escorts, 2, "two escorts")
	check_eq(m.items.size(), 3, "three chests on her deck")
	# Sink her: the chests float; fish one out and sell it, the others drift away.
	g.sink = 0.01
	sim._handle_sinking()
	for id: int in m.items:
		check_eq(sim.items[id].state, Loot.State.FLOATING, "afloat when she goes down")
	var first: Loot = sim.items[m.items[0]]
	var r := _ashore(sim, first.pos + Vector3(0, 0.2, 0))
	sim.request(1, "pickup", first.id, [])
	r.pos = Outpost.sell_spot()
	sim.request(1, "sell", 0, [])
	for id: int in m.items.duplicate():
		sim._mission_item_done(sim.items[id], 0, false)
		sim.items.erase(id)
	check(sim.crews[1].mission.is_empty(), "one chest saved is enough")


func test_the_drowned_bells() -> void:
	var sim := _sim("b4")
	var m: Dictionary = sim.crews[1].mission
	var bells := _all(sim, StoryObject.Kind.BELL)
	check_eq(bells.size(), 3, "three bells")
	_ashore(sim, bells[0].pos + Vector3(3, -StoryRun.BELL_HEIGHT, 0))
	_run(sim, 5.0)
	check(sim.story.standing(m) >= 2, "a bell rings and the dead rise")
	for b in bells:
		sim.story.strike_bell(b.id)
	check(sim.crews[1].mission.is_empty(), "all three down: done")
	check_eq(sim.stats.bells, 3)


func test_spies_in_merrow() -> void:
	var sim := _sim("b5")
	var m: Dictionary = sim.crews[1].mission
	for who: String in ["jonah", "moll", "silas"]:
		_ashore(sim, Story.person_pos(who))
		sim.request(1, "talk", Story.PEOPLE_IDS.find(who), [])
	check_eq(m.step, 1, "all three asked")
	var crates := _all(sim, StoryObject.Kind.SEARCH)
	check_eq(crates.size(), 3, "three crates on the pier")
	var r: Dictionary = sim.players[1]
	for c in crates:
		r.pos = c.pos
		sim.request(1, "search", c.id, [])
		if m.step == 2:
			break
	check_eq(m.step, 2, "the raven coin found")
	var gideon: Skeleton = sim.skeletons[m.captain]
	check(gideon.gideon, "Fat Gideon at his cove")
	sim._hurt_skeleton(gideon.id, 9999, "Anne", 1)
	check_eq(m.step, 3, "he gives up")
	_ashore(sim, Story.person_pos("quill"))
	sim.request(1, "talk", Story.PEOPLE_IDS.find("quill"), [])
	check(sim.crews[1].mission.is_empty(), "Quill is told")


func test_fuerte_del_cuervo() -> void:
	var sim := _sim("b6")
	var m: Dictionary = sim.crews[1].mission
	var gate := _first(sim, StoryObject.Kind.GATE)
	var guns := _all(sim, StoryObject.Kind.GUN)
	check(gate != null and gate.state == 1, "the gate is shut")
	check_eq(guns.size(), 2, "two tower guns")
	# The guns fire at our ship when it comes in range.
	var ship := sim.crew_ship()
	var spec: Dictionary = Islands.LAYOUT[Fort.index()]
	ship.x = spec.x - 150.0
	ship.z = spec.z
	_run(sim, 10.0)
	check(sim.stats.fort_shots >= 1, "the fort's guns fire (%d)" % sim.stats.fort_shots)
	# Two cannonballs silence a gun.
	sim._splash(guns[0].pos)
	sim._splash(guns[0].pos)
	check_eq(guns[0].state, 0, "silenced")
	# The powder outside the gate blows it in.
	var keg := _first(sim, StoryObject.Kind.KEG)
	sim.story.strike_keg(keg.id)
	_run(sim, 2.5)
	check_eq(gate.state, 0, "the gate is down")
	check(sim.story.fort_gate_open(), "and the way in open")
	check_eq(m.step, 1, "El Polvorín's turn")
	var boss: Skeleton = sim.skeletons[m.captain]
	check(boss.bomber, "El Polvorín on his platform")
	var r := _ashore(sim, Fort.centre() + Vector3(5, 0, 0))
	_run(sim, 6.0)
	check(_first(sim, StoryObject.Kind.BOMB) != null or sim.stats.explosions > 1, "he throws bombs")
	sim._hurt_skeleton(boss.id, 9999, "Anne", 1)
	check_eq(m.step, 2, "the cells")
	# His bombs may well have knocked us down; back on our feet.
	r.dead_until = -1.0
	r.hp = ServerSim.HEALTH
	var cell := _first(sim, StoryObject.Kind.CELL)
	var vault := _first(sim, StoryObject.Kind.VAULT)
	r.pos = vault.pos
	sim.request(1, "use", vault.id, [])
	check_eq(vault.state, 1, "the cells first")
	r.pos = cell.pos
	sim.request(1, "use", cell.id, [])
	check_eq(m.step, 3, "the prisoners are free")
	var before := sim.items.size()
	r.pos = vault.pos
	sim.request(1, "use", vault.id, [])
	check_eq(m.step, 4, "the vault open")
	check_eq(sim.items.size() - before, 4, "four chests of gold")
	r.pos = Story.person_pos("isabel")
	sim.request(1, "talk", Story.PEOPLE_IDS.find("isabel"), [])
	check(sim.crews[1].mission.is_empty(), "the act is done")
	check_eq(sim.players[1].profile.title, "Fort-Breaker")

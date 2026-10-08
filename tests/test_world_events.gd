extends "res://tests/support/case.gd"
## World events (docs/specs/2026-10-08-m13-world-events.md).

const DT := 1.0 / 30.0


func _sim(options := {}) -> ServerSim:
	options["calm"] = true
	var sim := ServerSim.new(options)
	sim.add_player(1, "Anne", 1, "a")
	return sim


func _ashore(sim: ServerSim, at: Vector3) -> Dictionary:
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = at
	r.dead_until = -1.0
	r.hp = ServerSim.HEALTH
	return r


func _run(sim: ServerSim, seconds: float) -> void:
	for i in int(seconds / DT):
		sim.time += DT
		sim.world.tick(DT)
		sim._step_skeletons(DT)


func test_the_clock_starts_one_after_a_while() -> void:
	var sim := _sim()
	sim.ai_enabled = false  # no random skeleton ships in the way
	check(sim.world.enabled, "on in a real game")
	sim.world.tick(DT)
	check_eq(sim.world.kind, WorldEvents.Kind.NONE, "not straight away")
	sim.time += WorldEvents.FIRST_DELAY + 1.0
	sim.world.tick(DT)
	check(sim.world.kind != WorldEvents.Kind.NONE, "five minutes in: %s" % WorldEvents.NAMES.get(sim.world.kind, "none"))
	check_eq(sim.stats.world_events, 1)


func test_no_ai_means_no_clock() -> void:
	var sim := _sim({"no-ai": true})
	sim.time += WorldEvents.FIRST_DELAY * 3.0
	sim.world.tick(DT)
	sim.world.tick(DT)
	check_eq(sim.world.kind, WorldEvents.Kind.NONE, "tests keep the sea quiet")


func test_green_fire_by_night_only_and_the_raid_after_the_siege() -> void:
	var sim := _sim({"no-ai": true})
	while StoryRun.is_night(sim.time):
		sim.time += 30.0
	for i in 40:
		check(sim.world._pick() != WorldEvents.Kind.GREEN_FIRE, "no green fire by day")
		check(sim.world._pick() != WorldEvents.Kind.RAID, "no raid before anyone has held Merrow")
	sim.players[1].profile.chapters.append("c6")
	var raided := false
	for i in 60:
		raided = raided or sim.world._pick() == WorldEvents.Kind.RAID
	check(raided, "the raid once someone has")


func test_green_fire_doused_pays_and_raises_dead() -> void:
	var sim := _sim({"no-ai": true})
	sim.world.start(WorldEvents.Kind.GREEN_FIRE)
	check_eq(sim.world.objects.size(), WorldEvents.FIRES, "three fires")
	var fires: Array[StoryObject] = []
	for oid in sim.world.objects:
		fires.append(sim.story.objects[oid])
	check_eq(fires[0].crew, 0, "nobody's in particular")
	var r := _ashore(sim, fires[0].pos + Vector3(1.0, 0, 0))
	_run(sim, WorldEvents.FIRE_RISE_EVERY + 0.5)
	check(sim.world._standing() >= 2, "the dead climb out while they burn")
	for o in fires:
		r.pos = o.pos + Vector3(1.0, 0, 0)
		r.bucket = true
		sim.request(1, "douse", o.id, [])
	var xp_before: int = r.profile.xp
	var chests := 0
	for it: Loot in sim.items.values():
		if it.kind == Loot.Kind.CHEST:
			chests += 1
	_run(sim, 0.1)
	check_eq(sim.world.kind, WorldEvents.Kind.NONE, "won")
	check_eq(int(r.profile.xp) - xp_before, WorldEvents.FIRE_XP, "XP for taking part")
	var after := 0
	for it: Loot in sim.items.values():
		if it.kind == Loot.Kind.CHEST:
			after += 1
	check_eq(after, chests + 1, "a chest on the beach")
	check(not sim.story.objects.has(fires[0].id), "the fires are gone")


func test_the_patrol_keeps_its_rounds_then_turns_on_you() -> void:
	var sim := _sim({"no-ai": true})
	sim.world.start(WorldEvents.Kind.PATROL)
	var id: int = sim.world.ships[0]
	var g: ShipState = sim.ships[id]
	check_eq(g.flag, 1, "a Spanish galleon")
	var cap: Captain = sim.captains[id]
	check_eq(cap.waypoints.size(), 5, "a loop round the Isles")
	var own: ShipState = sim.ships[ServerSim.CREW]
	own.x = g.x + 600.0
	own.z = g.z
	var c := ShipControls.new()
	cap.think(g, own, Vector2(1, 0), sim.time, DT, Islands.LAYOUT, c)
	check(not cap.hostile, "far off: she minds her rounds")
	own.x = g.x + 100.0
	cap.think(g, own, Vector2(1, 0), sim.time, DT, Islands.LAYOUT, c)
	check(cap.hostile, "close: she comes for you")
	g.sink = 0.01
	sim._handle_sinking()
	check_eq(sim.world.kind, WorldEvents.Kind.NONE, "sunk: won")
	check_eq(sim.stats.world_won, 1)


func test_the_convoy_pays_for_each_chest_and_ends_empty() -> void:
	var sim := _sim({"no-ai": true})
	sim.world.start(WorldEvents.Kind.CONVOY)
	check_eq(sim.world.ships.size(), 3, "the treasure galleon and two escorts")
	check_eq(sim.world.chests.size(), WorldEvents.CONVOY_CHESTS)
	check(sim.captains[sim.world.ships[0]].aggro_range == 0.0, "she runs rather than fights")
	var xp: int = sim.players[1].profile.xp
	for cid in sim.world.chests:
		var chest: Loot = sim.items[cid]
		chest.ship = ServerSim.CREW
	_run(sim, 0.1)
	check_eq(int(sim.players[1].profile.xp) - xp, WorldEvents.CONVOY_CHEST_XP * WorldEvents.CONVOY_CHESTS, "XP for every chest stowed")
	check_eq(sim.world.kind, WorldEvents.Kind.NONE, "her deck is bare: won")


func test_the_convoy_that_reaches_the_fort_is_lost() -> void:
	var sim := _sim({"no-ai": true})
	sim.world.start(WorldEvents.Kind.CONVOY)
	var g: ShipState = sim.ships[sim.world.ships[0]]
	var fort: Dictionary = Islands.LAYOUT[Fort.index()]
	g.x = fort.x + float(fort.radius) + 50.0
	g.z = fort.z
	_run(sim, 0.1)
	check_eq(sim.world.kind, WorldEvents.Kind.NONE, "she made port")
	check_eq(sim.stats.world_won, 0, "lost")
	check(not sim.ships.has(sim.world.ships[0]), "and sailed off")


func test_the_raid_pays_its_defenders_only() -> void:
	var sim := _sim({"no-ai": true})
	sim.add_player(2, "Bart", 2, "b")
	sim.world.start(WorldEvents.Kind.RAID)
	check_eq(sim.world._standing(), WorldEvents.RAID_SIZE, "a boat of the dead")
	var anne := _ashore(sim, Outpost.merchant_pos())
	var bart: Dictionary = sim.players[2]
	bart.mode = LocalPlayer.Mode.WORLD
	bart.ship = -1
	bart.pos = Vector3(0, 0, 0)  # far away
	for w in WorldEvents.RAID_WAVES:
		for sid in sim.world.raised:
			if sim.skeletons.has(sid) and sim.skeletons[sid].alive():
				sim._hurt_skeleton(sid, 9999, "Anne", 1)
		_run(sim, 0.1)
	check_eq(sim.world.kind, WorldEvents.Kind.NONE, "both waves down")
	check(int(anne.profile.gold) >= WorldEvents.RAID_GOLD, "the defender is paid")
	check_eq(int(bart.profile.gold), 0, "not someone who wasn't there")


func test_ghost_galleon_rises_in_the_storm_and_leaves_a_skull() -> void:
	var sim := _sim()
	sim.ai_enabled = false
	var own: ShipState = sim.ships[ServerSim.CREW]
	Storm.enabled = true
	Storm.pin = Vector2(own.x, own.z)
	sim.world.tick(DT)
	Storm.pin = Vector2.INF
	Storm.enabled = false
	check_eq(sim.world.kind, WorldEvents.Kind.GHOST, "a ghost rises")
	var id: int = sim.world.ships[0]
	check_eq(sim.ships[id].flag, 3)
	var skulls := 0
	sim.ships[id].sink = 0.01
	sim._handle_sinking()
	for it: Loot in sim.items.values():
		if it.kind == Loot.Kind.SKULL and it.state == Loot.State.FLOATING:
			skulls += 1
	check_eq(skulls, 1, "her captain's skull floats up")
	check_eq(sim.world.kind, WorldEvents.Kind.NONE)


func test_an_event_nobody_wins_ends_by_itself() -> void:
	var sim := _sim({"no-ai": true})
	sim.world.start(WorldEvents.Kind.PATROL)
	var id: int = sim.world.ships[0]
	sim.time += WorldEvents.LIFETIME + 1.0
	sim.world.tick(DT)
	check_eq(sim.world.kind, WorldEvents.Kind.NONE, "over")
	check(not sim.ships.has(id), "she sailed off")
	check(sim.world.next_at > sim.time, "the next one is on the clock")

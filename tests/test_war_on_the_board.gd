extends "res://tests/support/case.gd"
## The war on the board (docs/specs/2026-10-08-m16-war-on-the-board.md).


func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true})
	sim.add_player(1, "Anne", 1, "a")
	return sim


## An offer of `company` with this twist forced on.
func _offer(company: int, twist: String, stage := 4) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	for seed in 400:
		rng.seed = seed
		var offer := Missions.make_offer(company, 2, Islands.mission_islands(), rng)
		Missions.add_twists(offer, stage, rng)
		if offer.get(twist, false):
			return offer
	return {}


func test_the_war_stage_follows_the_story() -> void:
	check_eq(Missions.war_stage([[]]), 0)
	check_eq(Missions.war_stage([["p1", "p2"]]), 1)
	check_eq(Missions.war_stage([["p2", "a6"], []]), 2, "anyone aboard counts")
	check_eq(Missions.war_stage([["b6"]]), 3)
	check_eq(Missions.war_stage([["c6", "d1"]]), 4)


func test_nothing_comes_before_its_stage() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in 200:
		rng.seed = seed
		for company in 3:
			var offer := Missions.make_offer(company, 2, Islands.mission_islands(), rng)
			Missions.add_twists(offer, 1, rng)
			for twist: String in ["cache", "wreck", "officer", "pressed", "ghost", "raided"]:
				check(not offer.get(twist, false), "no %s at stage 1" % twist)


func test_a_spanish_cache_has_guards_at_each_x() -> void:
	var sim := _sim()
	var offer := _offer(Missions.Company.GOLD, "cache", 2)
	check(not offer.is_empty(), "a cache comes up")
	var before := sim.skeletons.size()
	sim._start_mission(1, offer)
	check_eq(sim.skeletons.size() - before, 2 * int(offer.size), "two guards at each X")
	for sk: Skeleton in sim.skeletons.values():
		check(sk.spanish, "Spanish dead")
	check(Missions.describe(offer).contains("guard"), "the board says so")


func test_wreck_gold_floats_at_the_reefs_edge() -> void:
	var sim := _sim()
	var offer := _offer(Missions.Company.GOLD, "wreck")
	check(not offer.is_empty(), "wreck gold comes up")
	sim._start_mission(1, offer)
	var m: Dictionary = sim.crews[1].mission
	for id: int in m.items:
		var chest: Loot = sim.items[id]
		check_eq(chest.state, Loot.State.FLOATING, "afloat")
		check(Vector2(chest.pos.x, chest.pos.z).distance_to(Vector2(StoryRun.REEF_EDGE.x, StoryRun.REEF_EDGE.z)) < 60.0, "at the Reef's edge")


func test_officers_and_the_pressed_lead_spanish_dead() -> void:
	for twist: String in ["officer", "pressed"]:
		var sim := _sim()
		var offer := _offer(Missions.Company.SOULS, twist, 3 if twist == "pressed" else 2)
		check(not offer.is_empty(), "%s comes up" % twist)
		sim._start_mission(1, offer)
		var m: Dictionary = sim.crews[1].mission
		var escorts := 0
		for sk: Skeleton in sim.skeletons.values():
			if sk.id != m.captain and sk.spanish:
				escorts += 1
		check_eq(escorts, int(offer.size), "%s: Spanish escorts" % twist)
		check(sim.skeletons[m.captain].captain, "led by a captain")


func test_a_ghost_ship_bounty_ends_with_her_skull_sold() -> void:
	var sim := _sim()
	var offer := _offer(Missions.Company.SOULS, "ghost")
	check(not offer.is_empty(), "a ghost ship comes up")
	sim._start_mission(1, offer)
	var m: Dictionary = sim.crews[1].mission
	check(sim.ships.has(m.ghost) and sim.ships[m.ghost].flag == 3, "she rises")
	var ghost: int = m.ghost
	sim.ships[ghost].sink = 0.01
	sim._handle_sinking()
	check_eq(m.items.size(), 1, "her captain's skull floats up")
	var skull: Loot = sim.items[m.items[0]]
	check_eq(skull.state, Loot.State.FLOATING)
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = skull.pos
	skull.state = Loot.State.GROUND
	sim.request(1, "pickup", skull.id, [])
	r.pos = Outpost.mystic_spot()
	sim.request(1, "sell", 0, [])
	check(sim.crews[1].mission.is_empty(), "sold to Wren: done")


func test_a_raided_cargo_run_brings_a_skeleton_ship() -> void:
	var sim := _sim()
	var offer := _offer(Missions.Company.MERCHANT, "raided", 3)
	check(not offer.is_empty(), "a raided run comes up")
	var ships := sim.ships.size()
	sim._start_mission(1, offer)
	check_eq(sim.ships.size(), ships + 1, "a skeleton ship on the route")
	check(Missions.describe(offer).contains("raiding"), "the board says so")

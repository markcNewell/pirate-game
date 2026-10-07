extends "res://tests/support/case.gd"

const DT := 1.0 / 60.0


func _sim(options := {}) -> ServerSim:
	options["no-ai"] = true
	var sim := ServerSim.new(options)
	sim.add_player(1, "Anne")
	sim.players[1].pos = ShipShape.MAP_TABLE + Vector3(0.9, 0, 0.6)
	return sim


func test_levels_from_points() -> void:
	check_eq(Missions.level(0), 1)
	check_eq(Missions.level(Missions.LEVEL_POINTS - 1), 1)
	check_eq(Missions.level(Missions.LEVEL_POINTS), 2)
	check_eq(Missions.level(99999), Missions.MAX_LEVEL, "capped")


func test_offers_grow_with_level() -> void:
	var rng := RandomNumberGenerator.new()
	var islands := Islands.mission_islands()
	var low := Missions.make_offers([1, 1, 1], islands, rng)
	var high := Missions.make_offers([5, 5, 5], islands, rng)
	check_eq(low.size(), 3, "one offer per company")
	for i in 3:
		check_eq(low[i].company, i)
		check_eq(low[i].kind, Missions.COMPANY_KIND[i])
		check(high[i].size > low[i].size, "%s: bigger at level 5" % Missions.COMPANY_NAMES[i])
		check(high[i].gold.y > low[i].gold.y, "%s: better paid at level 5" % Missions.COMPANY_NAMES[i])
		for island: int in high[i].islands:
			check(not Islands.LAYOUT[island].outpost, "never to the outpost")
	check_eq(high[Missions.Company.GOLD].islands.size(), 3, "three islands of treasure at level 5")
	var round_trip := Missions.offer_from_array(Missions.offer_to_array(low[1]))
	check_eq(round_trip.title, low[1].title)


func test_offers_can_be_pinned_to_an_island() -> void:
	var offers := Missions.make_offers([3, 3, 3], Islands.mission_islands(), RandomNumberGenerator.new(), 2)
	for offer: Dictionary in offers:
		check_eq(offer.islands[0], 2)


func test_cargo_pay_late_and_soaked() -> void:
	check_eq(Missions.crate_pay(200, 10.0, 20.0), 200, "on time")
	check_eq(Missions.crate_pay(200, 30.0, 20.0), 100, "late pays half")
	check(Missions.cargo_time(3) > Missions.cargo_time(1), "more crates, more time")
	var sim := _sim()
	var crate := sim._new_item(Loot.Kind.CRATE, Loot.State.GROUND, Vector3(0, 0, 0), 180)
	sim._set_floating(crate, Vector3(0, 0, 0))
	check(crate.soaked, "in the sea it is soaked")
	check_eq(crate.value, 90, "and worth half")
	sim._set_floating(crate, Vector3(1, 0, 0))
	check_eq(crate.value, 90, "only once")


func test_board_and_taking_an_offer() -> void:
	var sim := _sim()
	sim.request(1, "board", 0, [])
	check_eq(sim.crews[1].offers.size(), 3, "the board shows three offers")
	sim.request(1, "voyage", Missions.Company.MERCHANT, [])
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.kind, Missions.Kind.CARGO, "took the cargo run")
	check(m.deadline > sim.time, "with a deadline")
	sim.request(1, "voyage", Missions.Company.GOLD, [])
	check_eq(sim.crews[1].mission.kind, Missions.Kind.CARGO, "one mission at a time")
	sim.request(1, "abandon", 0, [])
	check(sim.crews[1].mission.is_empty(), "given up")


func test_bounty_captain_skull_and_the_order() -> void:
	var sim := _sim({"voyage-island": "1"})
	sim.request(1, "voyage", Missions.Company.SOULS, [])
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.kind, Missions.Kind.BOUNTY)
	var captain: Skeleton = sim.skeletons[m.captain]
	check(captain.captain, "the captain stands")
	check_eq(captain.hp, Missions.CAPTAIN_HEALTH)
	var crew := 0
	for id in sim.skeletons:
		if sim.skeletons[id].home == 1 and not sim.skeletons[id].captain:
			crew += 1
	check_eq(crew, Missions.BOUNTY_CREW[0], "with his crew")
	var arr: Array = Skeleton.from_array(captain.to_array()).to_array()
	check(Skeleton.from_array(arr).captain, "captains survive the snapshot")

	sim._hurt_skeleton(m.captain, 999, "Anne")
	check_eq(m.items.size(), 1, "he dropped his skull")
	var skull: Loot = sim.items[m.items[0]]
	check_eq(skull.kind, Loot.Kind.SKULL)
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.pos = skull.pos
	sim.request(1, "pickup", skull.id, [])
	check_eq(r.carry, skull.id, "picked up the skull")
	r.pos = Outpost.sell_spot()
	sim.request(1, "sell", 0, [])
	check_eq(r.carry, skull.id, "the Gold Hoarder does not buy skulls")
	r.pos = Outpost.mystic_spot()
	sim.request(1, "sell", 0, [])
	check_eq(sim.crews[1].purse, skull.value, "the Order pays")
	check(sim.crews[1].mission.is_empty(), "bounty done")
	check_eq(sim.crews[1].rep[Missions.Company.SOULS], Missions.ITEM_POINTS + Missions.FINISH_POINTS)


func test_cargo_collect_and_deliver() -> void:
	var sim := _sim({"voyage-island": "2"})
	sim.request(1, "voyage", Missions.Company.MERCHANT, [])
	var m: Dictionary = sim.crews[1].mission
	var crate: Loot = sim.items[m.items[0]]
	check_eq(crate.kind, Loot.Kind.CRATE)
	check(crate.pos.distance_to(Outpost.cargo_spot(0)) < 0.1, "waiting on the pier")
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.pos = crate.pos
	sim.request(1, "pickup", crate.id, [])
	check_eq(r.carry, crate.id)
	r.pos = Outpost.sell_spot()
	sim.request(1, "deliver", 0, [])
	check_eq(r.carry, crate.id, "only the trader takes it")
	r.pos = Islands.trader_spot(2)
	sim.request(1, "deliver", 0, [])
	check_eq(sim.crews[1].purse, crate.value, "paid in full on time")
	check(sim.crews[1].mission.is_empty(), "the run is done")
	check_eq(sim.crews[1].rep[Missions.Company.MERCHANT], Missions.ITEM_POINTS + Missions.FINISH_POINTS)


func test_mission_spots_make_sense() -> void:
	for i in Islands.mission_islands():
		var t := Islands.trader_spot(i)
		check(t.y > Waves.max_height(), "%s: the trader stands on dry sand" % Islands.LAYOUT[i].name)
	var isl := Islands.outpost_index()
	var mystic := Outpost.mystic_spot()
	check(Islands.ground_at(isl, mystic.x, mystic.z) > Waves.max_height(), "you sell skulls on dry sand")
	check(Outpost.mystic_spot().distance_to(Outpost.sell_spot()) > 6.0, "the mystic is not at the stall")
	for k in 3:
		var c := Outpost.cargo_spot(k)
		var spec: Dictionary = Islands.LAYOUT[isl]
		check(Vector2(c.x - spec.x, c.z - spec.z).length() < spec.radius + Outpost.PIER_END, "crates on the pier")

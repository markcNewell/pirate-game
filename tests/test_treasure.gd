extends "res://tests/support/case.gd"

const DT := 1.0 / 60.0


func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true})
	sim.add_player(1, "Anne")
	return sim


func _hold(sim: ServerSim, action: String, seconds: float, arg := 0) -> void:
	var t := 0.0
	while t < seconds:
		sim.tick(0.2)
		sim.request(1, action, arg, [])
		t += 0.2


func test_loot_round_trip_and_tiers() -> void:
	var l := Loot.new()
	l.id = 7
	l.kind = Loot.Kind.CHEST
	l.state = Loot.State.ON_SHIP
	l.pos = Vector3(1, 2, 3)
	l.yaw = 0.5
	l.carrier = -1
	l.value = 300
	check_eq(Loot.from_array(l.to_array()).to_array(), l.to_array())
	check_eq(Loot.chest_tier(100), 0)
	check_eq(Loot.chest_tier(250), 1)
	check_eq(Loot.chest_tier(600), 2)


func test_dig_spots_are_dry_land() -> void:
	var rng := RandomNumberGenerator.new()
	for i in Islands.LAYOUT.size():
		if Islands.LAYOUT[i].outpost:
			continue
		for n in 20:
			rng.seed = n * 31 + i
			var spot := Islands.dig_spot(i, rng)
			check_eq(Islands.island_at(spot.x, spot.y), i, "spot on %s" % Islands.LAYOUT[i].name)
			check(Islands.ground_at(i, spot.x, spot.y) >= Islands.DIG_GROUND, "dry ground")


func test_outpost_spots_make_sense() -> void:
	var sell := Outpost.sell_spot()
	var isl := Islands.outpost_index()
	check(Islands.ground_at(isl, sell.x, sell.z) > Waves.max_height(), "you sell standing on dry sand")
	var anchor := Outpost.anchorage()
	var spec: Dictionary = Islands.LAYOUT[isl]
	check(Vector2(anchor.x - spec.x, anchor.z - spec.z).length() > spec.radius + Islands.SHIP_CLEARANCE + 15.0, "anchorage clear of the island")
	for p in Outpost.barrels():
		check(Vector2(p.x - spec.x, p.z - spec.z).length() < spec.radius + Outpost.PIER_END, "barrels on the pier")


func test_voyage_dig_carry_and_sell() -> void:
	var sim := _sim()
	sim.options_island = 1
	var r: Dictionary = sim.players[1]
	r.pos = ShipShape.MAP_TABLE + Vector3(0.9, 0, 0.6)
	sim.request(1, "voyage", Missions.Company.GOLD, [])
	var m: Dictionary = sim.crews[1].mission
	check(not m.is_empty(), "the map table gives a treasure voyage")
	check_eq(m.kind, Missions.Kind.TREASURE)
	check_eq(m.islands[0], 1)

	# Dig in the wrong place first: nothing.
	var spec: Dictionary = Islands.LAYOUT[1]
	r.mode = LocalPlayer.Mode.WORLD
	var buried: Loot = sim.items[m.items[0]]
	var x: float = buried.pos.x
	var z: float = buried.pos.z
	var wrong := Vector2(x, z) + (Vector2(spec.x, spec.z) - Vector2(x, z)).normalized() * 8.0
	r.pos = Vector3(wrong.x, Islands.ground_at(1, wrong.x, wrong.y) + 0.05, wrong.y)
	_hold(sim, "dig", 2.6)
	check_eq(sim.stats.dug, 0, "nothing 8 m from the X")

	r.pos = Vector3(x + 1.0, Islands.ground_at(1, x + 1.0, z) + 0.05, z)
	_hold(sim, "dig", 2.6)
	check_eq(sim.stats.dug, 1, "a chest at the X")
	var chest: Loot = sim.items[m.items[0]]
	check_eq(chest.state, Loot.State.GROUND)

	sim.request(1, "pickup", chest.id, [])
	check_eq(r.carry, chest.id, "picked up")
	r.pos = Outpost.sell_spot()
	sim.request(1, "sell", 0, [])
	check_eq(r.profile.gold, chest.value, "sold for its value")
	check(sim.crews[1].mission.is_empty(), "voyage over")
	check_eq(r.carry, -1)
	check_eq(r.profile.rep[Missions.Company.GOLD], Missions.CHEST_POINTS + Missions.ITEM_POINTS + Missions.FINISH_POINTS, "the Gilded Hand is pleased")


func test_chest_put_down_aboard_rides_with_the_ship() -> void:
	var sim := _sim()
	var chest := sim._new_item(Loot.Kind.CHEST, Loot.State.ON_SHIP, Vector3(0, ShipShape.DECK_Y, -2.0), 100)
	chest.ship = ServerSim.CREW
	var r: Dictionary = sim.players[1]
	r.pos = Vector3(0.5, ShipShape.DECK_Y, -1.0)
	sim.request(1, "pickup", chest.id, [])
	check_eq(chest.state, Loot.State.CARRIED)
	sim.request(1, "drop", 0, [])
	check_eq(chest.state, Loot.State.ON_SHIP, "put down on deck it stays aboard")
	sim.crew_ship().holes = [[1, 2, 0, 0, 0.0]]
	sim.crew_ship().water = ShipPhysics.SINK_LEVEL
	for i in 10:
		sim.tick(DT)
	check_eq(chest.state, Loot.State.FLOATING, "it floats up when the ship sinks")


func test_firing_and_patching_use_supplies_and_barrels_restock() -> void:
	var sim := _sim()
	var ship := sim.crew_ship()
	var r: Dictionary = sim.players[1]
	var st: Dictionary = ShipShape.stations()[5]
	r.pos = st.stand
	sim.request(1, "station", 5, [])
	var before := ship.cannonballs
	sim.request(1, "fire", 5, [0.0, 0.1])
	check_eq(ship.cannonballs, before - 1, "a shot uses a cannonball")
	ship.gun_reload[st.gun] = 0.0
	ship.cannonballs = 0
	sim.request(1, "fire", 5, [0.0, 0.1])
	check_eq(sim.stats.shots, 1, "no cannonballs, no shot")

	sim.request(1, "leave", 5, [])
	ship.planks = 1
	var h := ShipShape.hole_point(Vector3(2, 0, 1))
	ship.holes = [[1, h.x, h.y, h.z, 0.0]]
	r.pos = Vector3(h.x - 0.8, ShipShape.LOWER_Y, h.z)
	_hold(sim, "patch", 2.6, 1)
	check(ship.holes.is_empty(), "patched")
	check_eq(ship.planks, 0, "a patch uses a plank")

	var barrel := sim._new_item(Loot.Kind.BARREL, Loot.State.FLOATING, Vector3(ship.x + 20, 0, ship.z))
	r.mode = LocalPlayer.Mode.WORLD
	r.pos = barrel.pos + Vector3(1, 0, 0)
	sim.request(1, "open", barrel.id, [])
	check_eq(ship.cannonballs, ServerSim.BARREL_BALLS, "a floating barrel gives cannonballs")
	check(not sim.items.has(barrel.id), "and is used up")


func test_a_sunk_skeleton_leaves_loot() -> void:
	var sim := _sim()
	var skel := ShipState.new()
	skel.kind = ShipState.Kind.SKELETON
	skel.x = 200.0
	skel.sink = 1.0
	sim.ships[10] = skel
	sim.captains[10] = Captain.new()
	sim.tick(DT)
	check_eq(sim.stats.loot_spawned, 3)
	var chests := 0
	for id in sim.items:
		var item: Loot = sim.items[id]
		check_eq(item.state, Loot.State.FLOATING)
		if item.kind == Loot.Kind.CHEST:
			chests += 1
			check_eq(Loot.chest_tier(item.value), 2, "a captain's chest")
	check_eq(chests, 1)

extends "res://tests/support/case.gd"
## Shipyards and the first playtest's fixes (docs/specs/2026-10-12-m26-shipyards.md).

const DT := 1.0 / 60.0


func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true})
	sim.add_player(1, "Anne", 1, "a")
	return sim


# --- buckets ---

func test_one_bailer_keeps_ahead_of_two_holes() -> void:
	for hull: Hull in [Hull.galleon(), Hull.sloop()]:
		var trip := maxf(Hull.BAIL_TRIP if hull.has_hold else 0.0, hull.bail_every)
		var per_second := hull.bucket / trip
		check(per_second > 1.5 * hull.leak_rate,
			"%s: a bucket every %.1f s takes %.3f m/s against a hole's %.3f" % [hull.name, trip, per_second, hull.leak_rate])


func test_a_bucket_thrown_takes_out_its_water() -> void:
	var sim := _sim()
	var ship: ShipState = sim.ships[1]
	ship.water = 1.0
	var r: Dictionary = sim.players[1]
	r.pos = ShipShape.HATCH_BOTTOM
	sim.request(1, "scoop", 0, [])
	check(r.bucket, "filled below")
	r.pos = ShipShape.SPAWNS[0]
	sim.request(1, "throw", 0, [])
	sim.tick(DT)
	check_near(ship.water, 1.0 - Hull.galleon().bucket, 0.01, "one bucket's worth gone")


func _harbour(gold := 0) -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true, "harbour": true, "gold": gold})
	sim.add_player(1, "Anne", 1, "a")
	return sim


## Sinks crew 1's ship to the bottom.
func _sink(sim: ServerSim) -> void:
	sim.ships[1].sink = 1.0
	sim._evacuated[1] = true


func _to_yard(sim: ServerSim, id: int, yard: int) -> void:
	sim.players[id].mode = LocalPlayer.Mode.WORLD
	sim.players[id].pos = Shipyards.wright_pos(yard)


# --- the start ---

func test_a_new_crew_starts_on_merrows_pier_by_its_ship() -> void:
	var sim := _harbour()
	sim.add_player(2, "Ben", 2, "b")
	for id: int in [1, 2]:
		var r: Dictionary = sim.players[id]
		check_eq(r.mode, LocalPlayer.Mode.WORLD, "%s is ashore" % r.name)
		check(Outpost.on_pier(r.pos.x, r.pos.z), "%s stands on the pier" % r.name)
		var b := Shipyards.merrow_berth(r.crew)
		var s: ShipState = sim.ships[r.crew]
		check_near(Vector2(s.x, s.z).distance_to(Vector2(b.x, b.z)), 0.0, 0.01, "crew %d's ship at her berth" % r.crew)
		check(sim._moored_at_merrow(r.crew), "and moored there")
	var gap := Vector2(sim.ships[1].x, sim.ships[1].z).distance_to(Vector2(sim.ships[2].x, sim.ships[2].z))
	check(gap > 2.0 * ShipShape.BEAM * 0.5 + Outpost.PIER_HALF_WIDTH * 2.0, "the two berths are clear of each other (%.1f m)" % gap)


func test_the_first_ships_ladder_reaches_the_pier() -> void:
	var sim := _harbour()
	var r: Dictionary = sim.players[1]
	var s: ShipState = sim.ships[1]
	var nearest := INF
	for side: int in [-1, 1]:
		var bottom := ShipPhysics.pose_of(s, sim.time) * Hull.of(s).ladder_bottom(side)
		nearest = minf(nearest, Vector2(bottom.x - r.pos.x, bottom.z - r.pos.z).length())
	check(nearest < 5.0, "a ladder a few steps along the pier (%.1f m)" % nearest)
	r.pos = Vector3(Shipyards.merrow_berth(1).x, Outpost.PIER_Y, r.pos.z)
	sim.request(1, "climb", -1, [1])
	sim.request(1, "climb", 1, [1])
	check_eq(r.mode, LocalPlayer.Mode.ON_SHIP, "climbed aboard from the pier")


func test_at_sea_is_still_the_tests_start() -> void:
	var sim := _sim()
	check_eq(sim.players[1].mode, LocalPlayer.Mode.ON_SHIP, "aboard")
	check_near(sim.ships[1].x, 0.0, 0.01, "out at sea")


# --- sinking, dying, buying ---

func test_a_sunk_ship_does_not_come_back_by_herself() -> void:
	var sim := _harbour()
	sim.ships[1].water = Hull.galleon().sink_level
	for i in int(ShipPhysics.SINK_TIME / DT) + int(ServerSim.CREW_RESPAWN_DELAY / DT) + 120:
		sim.tick(DT)
	check(sim.ships[1].sink >= 1.0, "still on the bottom")
	check(not sim.has_ship(1), "the crew has no ship")


func test_dying_with_no_ship_wakes_you_on_merrows_pier() -> void:
	var sim := _harbour()
	_sink(sim)
	sim.players[1].mode = LocalPlayer.Mode.WORLD
	sim.players[1].pos = Vector3(200, 0, 200)
	sim._hurt_player(1, 1000, "a test")
	for i in int((ServerSim.GHOST_TIME + 1.0) / DT):
		sim.tick(DT)
	var r: Dictionary = sim.players[1]
	check(r.dead_until < 0.0, "back from the brink")
	check(Outpost.on_pier(r.pos.x, r.pos.z), "on the pier")


func test_the_sloop_is_free_and_the_galleon_costs_500() -> void:
	var sim := _harbour()
	_sink(sim)
	_to_yard(sim, 1, 3)
	sim.request(1, "ship", Hull.Type.GALLEON, [])
	check(not sim.has_ship(1), "no galleon for 0 gold")
	sim.request(1, "ship", Hull.Type.SLOOP, [])
	check(sim.has_ship(1), "a sloop for nothing")
	var s: ShipState = sim.ships[1]
	check_eq(s.hull, Hull.Type.SLOOP, "she's a sloop")
	check_eq(s.cannonballs, 0, "no guns, no shot")
	var b := Shipyards.berth(3, Hull.sloop())
	check_near(Vector2(s.x, s.z).distance_to(Vector2(b.x, b.z)), 0.0, 0.01, "moored at Gull Isle's yard")
	check_eq(sim.players[1].mode, LocalPlayer.Mode.ON_SHIP, "the buyer is aboard")
	check_eq(sim.players[1].ship, 1, "aboard her")


func test_trading_a_sloop_up_and_one_ship_a_crew() -> void:
	var sim := _harbour(600)
	_sink(sim)
	_to_yard(sim, 1, 1)
	sim.request(1, "ship", Hull.Type.SLOOP, [])
	sim.add_player(2, "Ben", 1, "b")
	_to_yard(sim, 2, 1)
	sim.request(2, "ship", Hull.Type.SLOOP, [])
	check_eq(sim.stats.ships_bought, 1, "no second sloop while the first is afloat")
	sim.players[1].mode = LocalPlayer.Mode.ON_SHIP
	sim.players[1].ship = 1
	sim.players[1].pos = Hull.sloop().spawns[0]
	sim.request(2, "ship", Hull.Type.GALLEON, [])
	check_eq(sim.ships[1].hull, Hull.Type.GALLEON, "traded up")
	check_eq(int(sim.players[2].profile.gold), 100, "500 from the buyer's own gold")
	check_eq(int(sim.players[1].profile.gold), 600, "nobody else's")
	check_eq(sim.players[1].mode, LocalPlayer.Mode.ON_SHIP, "who was aboard the sloop is aboard the galleon")
	check(Hull.galleon().is_on_board(sim.players[1].pos), "on her deck")
	_to_yard(sim, 2, 1)
	sim.request(2, "ship", Hull.Type.GALLEON, [])
	check_eq(sim.stats.ships_bought, 2, "no second galleon while one is afloat")


func test_buying_needs_a_shipwright() -> void:
	var sim := _harbour()
	_sink(sim)
	sim.players[1].mode = LocalPlayer.Mode.WORLD
	sim.players[1].pos = Shipyards.wright_pos(1) + Vector3(8, 0, 8)
	sim.request(1, "ship", Hull.Type.SLOOP, [])
	check(not sim.has_ship(1), "too far from the shipwright")


func test_a_new_galleon_keeps_the_crews_refits() -> void:
	var sim := _harbour(600)
	sim.crews[1].looks = [7, 1, 1, 0]
	_sink(sim)
	_to_yard(sim, 1, 0)
	sim.request(1, "ship", Hull.Type.GALLEON, [])
	check_eq(sim.ships[1].hull, Hull.Type.GALLEON, "bought from Old Hobb")
	check_eq(sim.crews[1].looks, [7, 1, 1, 0], "her looks are the crew's, so the new ship wears them")
	var b := Shipyards.merrow_berth(1)
	check_near(Vector2(sim.ships[1].x, sim.ships[1].z).distance_to(Vector2(b.x, b.z)), 0.0, 0.01, "at the crew's own Merrow berth")


# --- the yards ---

func test_every_yard_has_deep_water_and_dry_land() -> void:
	for i in Shipyards.count():
		var w := Shipyards.wright_pos(i)
		check(w.y > 0.3, "%s stands on dry ground (%.2f)" % [Shipyards.wright_name(i), w.y])
		for hull: Hull in [Hull.galleon(), Hull.sloop()]:
			var b := Shipyards.berth(i, hull)
			var at := Vector2(b.x, b.z)
			for j in Islands.LAYOUT.size():
				var isl: Dictionary = Islands.LAYOUT[j]
				var gap := at.distance_to(Vector2(isl.x, isl.z)) - float(isl.radius)
				check(gap > hull.half_length * 0.2, "%s's %s berth is afloat, clear of %s (%.1f m)" % [Shipyards.wright_name(i), hull.name, isl.name, gap])


func test_berths_put_a_ladder_by_the_jetty() -> void:
	for i in range(1, Shipyards.count()):
		for hull: Hull in [Hull.galleon(), Hull.sloop()]:
			var b := Shipyards.berth(i, hull)
			var pose := ShipPhysics.pose(b.x, b.z, b.yaw, 0.0, 0.0, 0.0, hull)
			var best := INF
			for side: int in [-1, 1]:
				var bottom := pose * hull.ladder_bottom(side)
				var ends := Shipyards.jetty(i)
				var p := Vector2(bottom.x, bottom.z)
				var a := Vector2(ends[0].x, ends[0].z)
				var c := Vector2(ends[1].x, ends[1].z)
				var t := clampf((p - a).dot(c - a) / (c - a).length_squared(), 0.0, 1.0)
				best = minf(best, p.distance_to(a.lerp(c, t)))
			check(best < 3.0, "%s: the %s's ladder is %.1f m from the jetty" % [Shipyards.wright_name(i), hull.name, best])


# --- the sloop ---

func test_the_sloop_has_the_wheel_sail_and_anchor_but_no_guns() -> void:
	var hull := Hull.sloop()
	var ids := hull.stations().map(func(st: Dictionary) -> int: return st.id)
	check_eq(ids, [0, 1, 3], "wheel, sail, anchor")
	check_eq(hull.guns, 0, "no guns")
	check(not hull.has_hold, "no hold")
	for st: Dictionary in hull.stations():
		check(hull.plausible_position(st.stand), "you can stand at the %s" % st.label)
	for spot in hull.spawns:
		check(hull.plausible_position(spot), "a spawn spot on deck: %s" % spot)
	for side: int in [-1, 1]:
		check(hull.plausible_position(hull.ladder_top(side)), "the ladder's top is on deck")


func test_a_sloops_holes_are_patched_and_bailed_from_the_deck() -> void:
	var hull := Hull.sloop()
	var hit := Vector3(1.2, 0.2, 1.0)
	check(hull.inside_hull(hit), "a hit low on her side is in the hull")
	check(hull.makes_hole(hit), "and holes her")
	var hole := hull.hole_point(hit)
	check(hull.is_on_board(hole) and absf(hole.y - hull.deck_y) < 0.3, "the hole shows on deck by the rail")
	check(hull.can_scoop(Vector3(0, hull.deck_y, 0), 0.2), "scoop from the deck")
	check(not hull.can_scoop(Vector3(0, hull.deck_y, 0), 0.0), "not from a dry hull")


func test_the_sloop_is_quick_and_fragile() -> void:
	var g := ShipState.new()
	var s := ShipState.new()
	s.hull = Hull.Type.SLOOP
	for ship: ShipState in [g, s]:
		ship.anchored = false
		ship.sail_height = [1.0, 1.0]
	for i in 3600:
		ShipPhysics.step(g, ShipControls.new(), Vector2(0, -1), DT, [])
		ShipPhysics.step(s, ShipControls.new(), Vector2(0, -1), DT, [])
	check(s.speed > g.speed * 1.1, "faster before the wind: %.2f vs %.2f" % [s.speed, g.speed])
	var holed := ShipState.new()
	holed.hull = Hull.Type.SLOOP
	holed.holes = [[1, 1, 1, 1, 0.0], [2, 1, 1, 1, 0.0], [3, 1, 1, 1, 0.0]]
	var t := 0.0
	while not holed.is_sinking() and t < 300.0:
		ShipPhysics.step(holed, ShipControls.new(), Vector2(0, -1), DT, [])
		t += DT
	check(t < 20.0, "three holes sink her in %.0f s" % t)


func test_the_hull_rides_along_in_snapshots_and_teleports() -> void:
	var s := ShipState.new()
	s.hull = Hull.Type.SLOOP
	check_eq(ShipState.from_array(s.to_array()).hull, Hull.Type.SLOOP, "in the ship's state")
	var sim := ServerSim.new({"no-ai": true, "calm": true, "sloop": true})
	sim.add_player(1, "Anne", 1, "a")
	check_eq(sim.ships[1].hull, Hull.Type.SLOOP, "the test hook's first ship")
	check_eq(sim.players[1].pos, Hull.sloop().spawns[0], "aboard her, on her deck")


# --- the way to the first mission ---

func test_next_points_at_moll_until_the_story_starts() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var game := Game.new()
	var hud := Hud.new()
	hud.game = game
	var next := hud.next_chapter()
	check(str(next.get("text", "")).begins_with("Speak to Moll Tinder"), "first, Moll: %s" % next)
	check_eq(next.get("at"), Story.person_pos("moll"), "the mark is on her")
	game.mission = {"kind": Missions.Kind.STORY, "company": -1}
	check(hud.next_chapter().is_empty(), "nothing while a chapter is under way")
	game.mission = {}
	# Everything before Act II (which opens at a higher pirate level) done, at level 1.
	game.chapters = Story.CHAPTERS.filter(func(c: Dictionary) -> bool: return int(c.act) < 2 and not c.has("tale")).map(func(c: Dictionary) -> String: return c.id)
	var later := hud.next_chapter()
	check(later.get("at") == null and str(later.get("text", "")).contains("opens at pirate level"), "the next act waits for a level: %s" % later)
	hud.free()
	game.free()
	tree.root.propagate_notification(0)

extends "res://tests/support/case.gd"
## The fort as a friendly port after the story (docs/specs/2026-10-08-m21-fort-port.md).


func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true})
	sim.add_player(1, "Anne", 1, "a")
	return sim


func _ashore(sim: ServerSim, at: Vector3) -> Dictionary:
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = at
	return r


func test_only_after_the_story() -> void:
	var sim := _sim()
	check(not sim.fort_port(1), "not before the story's end")
	sim.players[1].profile.chapters.append("e6")
	check(sim.fort_port(1), "after it")
	sim.add_player(2, "Bo", 1, "b")
	check(sim.fort_port(1), "the whole crew is welcome")
	sim.add_player(3, "Cal", 2, "c")
	check(not sim.fort_port(2), "not another crew who hasn't finished it")


func test_closed_while_the_dead_hold_it() -> void:
	var sim := _sim()
	sim.players[1].profile.chapters.append("e6")
	sim.world.start(WorldEvents.Kind.FORT)
	check(not sim.fort_port(1), "the dead hold the fort")


func test_isabel_sells_arms_not_coats() -> void:
	var sim := _sim()
	var r := _ashore(sim, Fort.isabel_pos())
	r.profile.gold = 2000
	sim.request(1, "buy", Shop.index_of("blade1"), [])
	check(not r.profile.owned.has("blade1"), "nothing before the story's end")
	r.profile.chapters.append("e6")
	sim.request(1, "buy", Shop.index_of("blade1"), [])
	check(r.profile.owned.has("blade1"), "a rapier from Isabel")
	check_eq(int(r.profile.blade), 1, "carried")
	sim.request(1, "buy", Shop.index_of("outfit2"), [])
	check(not r.profile.owned.has("outfit2"), "coats are Martha's")


func test_the_forts_barrels_restock_the_ship() -> void:
	var sim := _sim()
	var ship: ShipState = sim.ships[1]
	var at: Vector3 = Fort.barrels()[0]
	ship.x = at.x - 60.0
	ship.z = at.z
	ship.cannonballs = 0
	var r := _ashore(sim, at)
	sim.request(1, "restock", ServerSim.FORT_BARRELS, [])
	check_eq(ship.cannonballs, 0, "not our port yet")
	r.profile.chapters.append("e6")
	sim.request(1, "restock", ServerSim.FORT_BARRELS, [])
	check_eq(ship.cannonballs, ShipState.MAX_CANNONBALLS, "loaded from the fort's barrels")


func test_each_pirate_is_told() -> void:
	var sim := _sim()
	sim._send_fort_ports()
	check(not sim._fort_open.get(1, false), "closed")
	sim.players[1].profile.chapters.append("e6")
	sim._send_fort_ports()
	check(sim._fort_open[1], "open, and told")


func test_the_port_is_inside_the_walls() -> void:
	for p: Vector3 in [Fort.isabel_pos()] + Fort.barrels():
		var spec: Dictionary = Islands.LAYOUT[Fort.index()]
		check(not Fort.blocked(p.x - spec.x, p.z - spec.z, false), "%s is somewhere you can stand" % p)
		check(Vector2(p.x - spec.x, p.z - spec.z).length() < Fort.WALL_R, "inside the walls")

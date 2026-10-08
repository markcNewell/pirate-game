extends "res://tests/support/case.gd"
## The shipwright (docs/specs/2026-10-08-m19-shipwright.md): looks for a crew's ship, and the
## story's trophies on it.


func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true})
	sim.add_player(1, "Anne", 1, "a")
	return sim


func _at_hobb(sim: ServerSim, id: int) -> Dictionary:
	var r: Dictionary = sim.players[id]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = Outpost.hobb_pos()
	return r


func test_every_crew_starts_in_its_own_colours_for_free() -> void:
	for kind: int in [Shipwright.Kind.SAILS, Shipwright.Kind.HULL, Shipwright.Kind.FLAG]:
		var found := false
		for i in Shipwright.ITEMS.size():
			if Shipwright.ITEMS[i][0] == kind and Shipwright.ITEMS[i][1] == 0:
				found = true
				check(Shipwright.has({"owned": []}, i), "the crew's own is everyone's")
		check(found, "kind %d has the crew's own" % kind)
	check_eq(Shipwright.palette(2, [0, 0, 0]), Toon.crew_palette(2), "unfitted: the crew's colours")


func test_a_look_changes_only_colours() -> void:
	var p := Shipwright.palette(2, [7, 1, 3])
	check_eq(p.sail, Shipwright.SAILS[7], "black sails")
	check_eq(p.hull, Shipwright.HULLS[1].hull, "tarred hull")
	check_eq(p.flag, Shipwright.FLAGS[3], "a green flag")
	for k in p:
		check(typeof(p[k]) == TYPE_COLOR, "%s is a colour, nothing else" % k)


func test_buying_and_fitting() -> void:
	var sim := _sim()
	var r := _at_hobb(sim, 1)
	var black := Shipwright.index_of("sails7")
	sim.request(1, "wright", black, [])
	check(not r.profile.owned.has("sails7"), "no gold, no sails")
	r.profile.gold = 1000
	sim.request(1, "wright", black, [])
	check_eq(int(r.profile.gold), 100, "paid for them")
	check(r.profile.owned.has("sails7"), "they are ours")
	check_eq(sim.crews[1].looks, [7, 0, 0], "and on our ship")
	check_eq(r.profile.ship, [7, 0, 0], "remembered as our choice")
	sim.request(1, "wright", Shipwright.index_of("sails0"), [])
	check_eq(sim.crews[1].looks[0], 0, "back to the crew's own, free")
	check_eq(int(r.profile.gold), 100)
	sim.request(1, "wright", black, [])
	check_eq(int(r.profile.gold), 100, "fitting what you own costs nothing")
	check_eq(sim.crews[1].looks[0], 7)


func test_far_from_hobb_nothing_happens() -> void:
	var sim := _sim()
	var r := _at_hobb(sim, 1)
	r.profile.gold = 1000
	r.pos = Outpost.martha_pos()
	sim.request(1, "wright", Shipwright.index_of("sails7"), [])
	check_eq(int(r.profile.gold), 1000, "Hobb is on the pier")


func test_everyone_is_told_and_late_joiners_too() -> void:
	var sim := _sim()
	var r := _at_hobb(sim, 1)
	r.profile.gold = 1000
	sim.request(1, "wright", Shipwright.index_of("hull2"), [])
	check_eq(sim._ship_looks[1], [1, 0, 2, 0, 0], "the crew's ship look as sent")


func test_looks_survive_a_sinking() -> void:
	var sim := _sim()
	var r := _at_hobb(sim, 1)
	r.profile.gold = 1000
	sim.request(1, "wright", Shipwright.index_of("flag1"), [])
	sim._launch_crew_ship(1)
	check_eq(sim.crews[1].looks[2], 1, "the new ship flies the same flag")


func test_a_new_ship_takes_its_first_pirates_looks() -> void:
	var sim := _sim()
	sim.players[1].profile.ship = [3, 4, 5]
	sim.add_player(2, "Bo", 2, "b")
	check_eq(sim.crews[2].looks, [0, 0, 0], "Bo has never fitted anything")
	var p: Dictionary = sim.profiles.get_or_make("Cal", "c")
	p.ship = [6, 1, 2]
	sim.add_player(3, "Cal", 3, "c")
	check_eq(sim.crews[3].looks, [6, 1, 2], "Cal's saved looks on crew 3's new ship")
	sim.add_player(4, "Di", 3, "d")
	check_eq(sim.crews[3].looks, [6, 1, 2], "a second pirate aboard changes nothing")


func test_trophies_while_their_earner_is_aboard() -> void:
	var sim := _sim()
	sim._send_ship_looks()
	check_eq(sim._ship_looks[1][4], 0, "nothing earned yet")
	sim.players[1].profile.chapters.append_array(["a6", "t11"])
	sim._send_ship_looks()
	check_eq(sim._ship_looks[1][4], Shipwright.Trophy.HALBERD | Shipwright.Trophy.LANTERN, "the halberd and the lantern")
	sim.add_player(2, "Bo", 1, "b")
	sim.players[2].profile.chapters.append("d6")
	sim._send_ship_looks()
	check_eq(sim._ship_looks[1][4], 7, "and Bo's raven figurehead")
	sim.remove_player(2)
	sim._send_ship_looks()
	check_eq(sim._ship_looks[1][4], Shipwright.Trophy.HALBERD | Shipwright.Trophy.LANTERN, "Bo gone, the raven with him")


func test_hobb_is_on_the_pier() -> void:
	check(Story.PEOPLE_IDS.has("hobb"), "one of Merrow's people")
	var pier := Outpost.pier_spot()
	check(absf(Outpost.hobb_pos().y - pier.y) < 0.01, "standing on the pier")

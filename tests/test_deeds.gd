extends "res://tests/support/case.gd"
## Deeds: long goals that earn a title.


func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true})
	sim.add_player(1, "Anne", 1, "a")
	return sim


func test_every_deed_has_a_goal_and_a_title() -> void:
	for d: Array in Deeds.LIST:
		check(int(d[2]) > 0 and str(d[3]) != "", "%s: %d for %s" % [d[1], d[2], d[3]])
	check(Deeds.page({"fires": 3}).contains("3 of 50"), "the page counts")


func test_felling_the_dead_counts_and_earns_a_title() -> void:
	var sim := _sim()
	var p: Dictionary = sim.players[1].profile
	for n in 499:
		var sk := sim._new_skeleton(-1, Vector3(0, 0, 0))
		sim._hurt_skeleton(sk.id, 9999, "Anne", 1)
	check_eq(Deeds.count(p, "skeletons"), 499)
	check(not p.titles.has("Bonebreaker"), "not yet")
	var last := sim._new_skeleton(-1, Vector3(0, 0, 0))
	sim._hurt_skeleton(last.id, 9999, "Anne", 1)
	check(p.titles.has("Bonebreaker"), "five hundred: Bonebreaker")
	check_eq(p.title, "Bonebreaker", "and wears it")
	check_eq(sim.stats.deeds, 1)
	var more := sim._new_skeleton(-1, Vector3(0, 0, 0))
	sim._hurt_skeleton(more.id, 9999, "Anne", 1)
	check_eq(sim.stats.deeds, 1, "only once")


func test_sinking_galleons_counts_for_the_whole_crew() -> void:
	var sim := _sim()
	sim.add_player(2, "Bart", 1, "b")
	var id := sim.spawn_galleon(1, 200.0, 1)
	sim._last_hit_by[id] = 1
	sim.ships[id].sink = 0.01
	sim._handle_sinking()
	check_eq(Deeds.count(sim.players[1].profile, "galleons"), 1, "Anne's crew sank her")
	check_eq(Deeds.count(sim.players[2].profile, "galleons"), 1, "Bart too: same crew")


func test_dousing_and_selling_count() -> void:
	var sim := ServerSim.new({"no-ai": true, "calm": true, "chapter": "p1", "chapter-step": "1"})
	sim.add_player(1, "Anne", 1, "a")
	var r: Dictionary = sim.players[1]
	for o: StoryObject in sim.story.objects.values():
		if o.kind == StoryObject.Kind.FIRE:
			r.mode = LocalPlayer.Mode.WORLD
			r.ship = -1
			r.pos = o.pos + Vector3(1, 0, 0)
			r.bucket = true
			sim.request(1, "douse", o.id, [])
	check_eq(Deeds.count(r.profile, "fires"), 1, "a green fire")
	var chest := sim._new_item(Loot.Kind.CHEST, Loot.State.CARRIED, Outpost.sell_spot(), 300)
	r.carry = chest.id
	chest.carrier = 1
	r.pos = Outpost.sell_spot()
	sim.request(1, "sell", 0, [])
	check_eq(Deeds.count(r.profile, "chests"), 1, "a chest for Silas")

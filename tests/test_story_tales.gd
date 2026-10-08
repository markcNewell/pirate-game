extends "res://tests/support/case.gd"
## The tales from Port Merrow: Captain Coco (Jonah) and Quill's Ledger.

const DT := 1.0 / 30.0


func _sim(chapter: String, options := {}) -> ServerSim:
	options["no-ai"] = true
	options["calm"] = true
	options["chapter"] = chapter
	var sim := ServerSim.new(options)
	sim.add_player(1, "Anne", 1, "a")
	return sim


func _ashore(sim: ServerSim, at: Vector3) -> Dictionary:
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = at
	return r


## Carry item `id` to where the step wants it and hand it over.
func _deliver(sim: ServerSim, id: int, to: Vector3) -> void:
	var item: Loot = sim.items[id]
	var r := _ashore(sim, item.pos if item.state != Loot.State.FLOATING else item.pos + Vector3(0, 0.2, 0))
	sim.request(1, "pickup", id, [])
	r.pos = to
	sim.request(1, "give", 0, [])


func test_tales_open_after_their_chapters() -> void:
	var t1 := Story.index_of("t1")
	check(not Story.open_for(t1, [[]]), "Captain Coco waits for the prologue's first chapter")
	check(Story.open_for(t1, [["p1"]]), "and opens after it")
	check(Story.open_for(Story.index_of("t3"), [["p1", "p2", "a1", "a2"]]), "Quill's Ledger after Salt the Earth")
	check_eq(Story.next_for([["p1", "p2"]]), Story.index_of("a1"), "tales are not the board's next chapter")
	check_eq(Story.offered_by("jonah", [["p1"]]), t1, "Jonah gives Coconut Thieves")
	check(Story.open_for(Story.index_of("a2"), [["a1"]]), "a story chapter still follows the chapter before it")


func test_coconut_thieves() -> void:
	var sim := _sim("t1")
	var m: Dictionary = sim.crews[1].mission
	var crab: Skeleton = sim.skeletons[m.thieves[0]]
	check(crab.crab, "a crab")
	var coco: Loot = sim.items[m.items[0]]
	check_eq(coco.kind, Loot.Kind.COCONUT)
	check_eq(coco.carrier, crab.id, "in its claws")
	# It runs from us.
	var r := _ashore(sim, crab.pos + Vector3(4.0, 0, 0))
	var before := crab.pos.distance_to(r.pos)
	for i in 30:
		sim._step_skeletons(DT)
	check(crab.pos.distance_to(r.pos) > before, "the crab scuttles away")
	sim._hurt_skeleton(crab.id, 1, "Anne", 1)
	check_eq(coco.state, Loot.State.GROUND, "it lets go")
	check_eq(sim.players[1].profile.xp, 0, "no XP for bullying crabs")
	_deliver(sim, coco.id, Story.person_pos("jonah"))
	check(sim.crews[1].mission.is_empty(), "Captain Coco is home")
	check(sim.players[1].profile.chapters.has("t1"), "ticked off")


func test_a_raft_for_jonah() -> void:
	var sim := _sim("t2")
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.items.size(), 3, "a bundle of planks on each of three islands")
	var islands := {}
	for id: int in m.items.duplicate():
		islands[Islands.island_at(sim.items[id].pos.x, sim.items[id].pos.z, 4.0)] = true
		_deliver(sim, id, Story.person_pos("jonah"))
	check_eq(islands.size(), 3, "three different islands")
	check(sim.crews[1].mission.is_empty(), "the raft is built")


func test_the_missing_tea_floats() -> void:
	var sim := _sim("t3")
	var m: Dictionary = sim.crews[1].mission
	for id: int in m.items:
		check_eq(sim.items[id].state, Loot.State.FLOATING, "afloat")
		check_eq(sim.items[id].variant, Missions.TEA)
	for id: int in m.items.duplicate():
		_deliver(sim, id, Story.person_pos("quill"))
	check(sim.crews[1].mission.is_empty(), "three crates of tea for Quill")


func test_senor_hueso_goes_to_the_beach() -> void:
	var sim := _sim("t4")
	var m: Dictionary = sim.crews[1].mission
	var crate: Loot = sim.items[m.items[0]]
	check_eq(crate.variant, Missions.HUESO)
	check_eq(crate.label(), "rattling crate")
	_deliver(sim, crate.id, Story.person_pos("quill"))
	check(not sim.crews[1].mission.is_empty(), "Quill does not want him back")
	var r: Dictionary = sim.players[1]
	r.pos = Islands.trader_spot(2)
	sim.request(1, "give", 0, [])
	check(sim.crews[1].mission.is_empty(), "Hueso opens his kitchen")


func test_the_governors_ball_breaks_and_times_out() -> void:
	var sim := _sim("t5")
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.items.size(), 2, "two crates at Hueso's kitchen")
	check(m.deadline > sim.time, "against the clock")
	var first: int = m.items[0]
	var r := _ashore(sim, sim.items[first].pos)
	sim.request(1, "pickup", first, [])
	sim.request(1, "drop", 0, [])
	check(not sim.items.has(first), "put down on the sand: broken")
	check_eq(sim.stats.broken, 1)
	check_eq(m.items.size(), 2, "two fresh crates")
	sim.time = m.deadline + 1.0
	sim.story.tick(DT)
	check(m.deadline > sim.time, "too late: the clock starts again")
	for id: int in m.items.duplicate():
		_deliver(sim, id, Story.person_pos("quill"))
	check(sim.crews[1].mission.is_empty(), "the ball is saved")
	check_eq(sim.players[1].profile.title, "Purveyor of Fine Goods")


func test_board_treasure_with_spanish_diggers() -> void:
	var sim := ServerSim.new({"no-ai": true, "calm": true, "mission": "treasure", "voyage-island": "1"})
	sim.add_player(1, "Anne", 1, "a")
	sim.players[1].profile.chapters.append_array(["p1", "p2"])
	var offers := sim._make_offers(1)
	offers[0].diggers = true
	sim._start_mission(1, offers[0])
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.thieves.size(), m.items.size(), "a digger for each chest")
	check(not m.objects.is_empty(), "their boat on the beach")
	check(Missions.describe(offers[0]).contains("Spanish diggers"), "the board says so")
	sim.request(1, "abandon", 0, [])
	check(sim.story.objects.is_empty(), "given up: the boat goes")

extends "res://tests/support/case.gd"
## Act V and the epilogue, chapter by chapter (docs/specs/2026-10-08-m12-the-heart-of-ash.md).

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
	r.dead_until = -1.0
	r.hp = ServerSim.HEALTH
	return r


func _objects(sim: ServerSim, kind: int) -> Array[StoryObject]:
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


func _fell_all(sim: ServerSim) -> void:
	for sid in sim.skeletons.keys():
		if sim.skeletons.has(sid) and sim.skeletons[sid].alive():
			sim._hurt_skeleton(sid, 9999, "Anne", 1)


## Carry item `id` (wherever it is) to `to` and hand it over.
func _deliver(sim: ServerSim, id: int, to: Vector3) -> void:
	var item: Loot = sim.items[id]
	var r := _ashore(sim, item.pos + Vector3(0, 0.1, 0))
	sim.request(1, "pickup", id, [])
	r.pos = to
	sim.request(1, "give", 0, [])


## [yaw, pitch] for `r` to look from their eye at `at`.
func _look(r: Dictionary, at: Vector3) -> Array:
	var to: Vector3 = at - (r.pos + Vector3.UP * Weapons.EYE_HEIGHT)
	return [atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length())]


func test_act_five_waits_for_level_eighteen() -> void:
	check_eq(Story.chapter("e1").act, 5)
	check(Story.open_for(Story.index_of("e1"), [["d6"]]), "after the Battle of the Black Reef")
	check_eq(Progress.ACT_LEVEL[5], 18)


func test_what_the_admiral_knew() -> void:
	var sim := _sim("e1")
	var m: Dictionary = sim.crews[1].mission
	var wreck := _objects(sim, StoryObject.Kind.WRECK)
	check_eq(wreck.size(), 1, "the Cuervo Negro on the bottom")
	check(Vector2(wreck[0].pos.x, wreck[0].pos.z).distance_to(Reef.CENTRE) < Reef.HEART, "in the Reef's heart")
	check_eq(Story.step_text(Story.chapter("e1").steps[0]).begins_with("Dive on the Cuervo Negro"), true)
	sim.story.start(1, Story.index_of("e1"), 1)
	_ashore(sim, Story.person_pos("wren"))
	sim.request(1, "talk", Story.PEOPLE_IDS.find("wren"), [])
	check(sim.crews[1].mission.is_empty(), "Wren knows what the Heart wants")
	check(m.size() > 0, "the chapter ran")


func test_isla_ceniza_the_ashen_and_the_doctor() -> void:
	var sim := _sim("e2")
	var m: Dictionary = sim.crews[1].mission
	_run(sim, 0.5)
	check_eq(sim.story.standing(m), 0, "nothing until we land")
	var r := _ashore(sim, StoryAct5.on_ceniza(Vector3(0, 0, 0)))
	_run(sim, 0.2)
	check_eq(sim.story.standing(m), 4, "the first wave of ashen dead")
	var ashen := 0
	for sk: Skeleton in sim.skeletons.values():
		if sk.ashen and sk.alive():
			ashen += 1
	check_eq(ashen, 4)
	_fell_all(sim)
	_run(sim, 0.2)
	check_eq(sim.story.standing(m), 4, "the second")
	_fell_all(sim)
	_run(sim, 0.2)
	check_eq(m.step, 1, "the beach is ours: the workshop")
	var braziers := _objects(sim, StoryObject.Kind.BRAZIER)
	check_eq(braziers.size(), 3, "three braziers")
	var doctor: Skeleton = sim.skeletons[m.captain]
	check(doctor.doctor, "Doctor Ocaso")
	_run(sim, 0.1)
	check(doctor.shield_up, "safe while they burn")
	# A blow does nothing while a brazier burns.
	r.pos = doctor.pos + Vector3(1.2, 0, 0)
	r.weapon = Weapons.Kind.CUTLASS
	r.next_attack = 0.0
	sim.request(1, "attack", 0, _look(r, doctor.pos + Vector3(0, 1.0, 0)))
	check_eq(doctor.hp, StoryAct5.OCASO_HEALTH, "the blade passes through green fire")
	# He jumps and raises the dead.
	var before := doctor.pos
	_run(sim, StoryAct5.OCASO_JUMP_EVERY + 0.2)
	check(sim.stats.blinks >= 1, "he jumps")
	check(sim.story.standing(m) >= 2, "raising the dead where he lands")
	check(doctor.pos != before, "somewhere else")
	# Douse all three.
	for b in braziers:
		r.pos = b.pos + Vector3(1.0, 0, 0)
		r.bucket = true
		sim.request(1, "douse", b.id, [])
	check_eq(sim.stats.braziers, 3, "all doused")
	_run(sim, 0.1)
	check(not doctor.shield_up, "now he can be hurt")
	sim._hurt_skeleton(doctor.id, 9999, "Anne", 1)
	check(sim.crews[1].mission.is_empty(), "Ocaso is beaten")


func test_every_hand() -> void:
	var sim := _sim("e3")
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.items.size(), 3, "three crates of saltshot on the pier")
	for id: int in m.items.duplicate():
		_deliver(sim, id, Outpost.battery_centre())
	check_eq(m.step, 1, "loaded: the beacons")
	var beacons := _objects(sim, StoryObject.Kind.BEACON)
	check_eq(beacons.size(), 3, "a beacon on each island")
	for b in beacons:
		check(Islands.island_at(b.pos.x, b.pos.z) in StoryAct5.BEACON_ISLANDS, "on its island")
		_ashore(sim, b.pos + Vector3(1.0, 0, 0))
		sim.request(1, "light", b.id, [])
	check_eq(m.step, 2, "every crew called: Wren's lantern")
	var lantern: Loot = sim.items[m.items[0]]
	check_eq(lantern.kind, Loot.Kind.LANTERN)
	_deliver(sim, lantern.id, StoryAct5.reef_edge())
	check(sim.crews[1].mission.is_empty(), "the lantern shows the Maw")


func test_the_ash_admiral_at_the_maw() -> void:
	var sim := _sim("e4")
	var m: Dictionary = sim.crews[1].mission
	sim.players[1].profile.chapters.append("d2")
	var own: ShipState = sim.ships[ServerSim.CREW]
	own.x = Reef.CENTRE.x - 200.0
	own.z = Reef.CENTRE.y
	_run(sim, StoryAct4.RISE_EVERY * 3.0 + 1.0)
	check_eq(int(m.wave), 4, "four risen galleons")
	for id: int in m.ships.duplicate():
		sim.ships[id].sink = 0.01
	sim._handle_sinking()
	_run(sim, 0.2)
	check_eq(m.step, 1, "then his flagship")
	_run(sim, 0.2)
	check(m.ship >= 0 and sim.ships[m.ship].flag == 6, "the Ash Admiral's flagship")
	var ashen := 0
	for sk: Skeleton in sim.skeletons.values():
		if sk.frame == m.ship and sk.ashen:
			ashen += 1
	check(ashen > 0, "crewed by the ashen dead")
	sim.ships[m.ship].sink = 0.01
	sim._handle_sinking()
	check(sim.crews[1].mission.is_empty(), "she goes down")


func test_the_bone_colossus_and_the_heart() -> void:
	var sim := _sim("e5")
	sim.add_player(2, "Bart", 2, "b")
	var m: Dictionary = sim.crews[1].mission
	var giant := _objects(sim, StoryObject.Kind.COLOSSUS)[0]
	var own: ShipState = sim.ships[ServerSim.CREW]
	own.x = Reef.CENTRE.x - 30.0
	own.z = Reef.CENTRE.y
	# Close by: the fist.
	var holes := own.holes.size()
	sim.time = m.next_shot + 0.1
	sim.story.tick(DT)
	check_eq(sim.stats.slams, 1, "a fist slam")
	check(own.holes.size() > holes, "it holes us")
	# Further out: wreckage thrown.
	own.x = Reef.CENTRE.x - 90.0
	sim.time = m.next_shot + 0.1
	sim.story.tick(DT)
	check_eq(sim.stats.throws, 1, "wreckage thrown")
	# Cannonballs at its joints.
	for i in 4:
		var at := StoryAct5.joint_world(giant, i)
		for k in StoryAct5.JOINT_HITS:
			check(sim.story.act5.projectile_hit(at + Vector3(0.5, 0, 0)), "a joint hit")
	check(giant.state & StoryAct5.KNEEL, "it falls")
	check_eq(m.step, 1, "on the Anvil: the Ash Admiral")
	var admiral: Skeleton = sim.skeletons[m.captain]
	check(admiral.ash and admiral.admiral, "the Ash Admiral")
	check_eq(Islands.island_at(admiral.pos.x, admiral.pos.z), StoryAct5.anvil(), "on the Anvil")
	sim._hurt_skeleton(admiral.id, 9999, "Anne", 1)
	check_eq(m.step, 2, "he falls: the Heart")
	_fell_all(sim)  # his ashen guard
	var heart: Loot = sim.items[m.skull]
	check_eq(heart.kind, Loot.Kind.HEART)
	var r := _ashore(sim, heart.pos)
	sim.request(1, "pickup", heart.id, [])
	check_eq(r.carry, heart.id, "carried")
	var hp: int = r.hp
	_run(sim, StoryAct5.HEART_RAISE_EVERY + 0.5)
	check(r.hp < hp, "it burns")
	check(sim.story.standing(m) >= 2, "and the dead rise round the carrier")
	r.pos = StoryAct5.maw_edge()
	var bart: Dictionary = sim.players[2]
	sim.ships[2].x = Reef.CENTRE.x + 100.0
	sim.ships[2].z = Reef.CENTRE.y
	bart.mode = LocalPlayer.Mode.ON_SHIP
	bart.ship = 2
	sim.request(1, "give", 0, [])
	check(sim.crews[1].mission.is_empty(), "the Heart goes into the Maw")
	var standing := 0
	for sk: Skeleton in sim.skeletons.values():
		if sk.alive():
			standing += 1
	check_eq(standing, 0, "every skeleton crumbles")
	check_eq(sim.players[1].profile.title, "Heartbreaker")
	check(sim.players[1].profile.owned.has("outfit9"), "the raven cloak")
	check_eq(int(sim.players[2].profile.gold), StoryAct5.SHARED_GOLD, "Bart shares the end")


func test_the_heart_is_too_heavy_to_climb_with() -> void:
	var sim := _sim("e5", 2)
	var r := _ashore(sim, Vector3(0, 0, 0))
	var heart := sim._new_item(Loot.Kind.HEART, Loot.State.CARRIED, Vector3.ZERO, 0)
	r.carry = heart.id
	var own: ShipState = sim.ships[ServerSim.CREW]
	r.pos = ShipPhysics.pose_of(own, sim.time) * ShipShape.ladder_bottom(1)
	sim.request(1, "climb", 1, [])
	check_eq(r.mode, LocalPlayer.Mode.WORLD, "no climbing with the Heart")


func test_quiet_waters() -> void:
	var sim := _sim("e1")
	sim.crews[1].mission = {}
	sim.players[1].profile.chapters.append_array(["e1", "e2", "e3", "e4", "e5"])
	sim.players[1].profile.xp = Progress.xp_for(18)
	var r := _ashore(sim, Outpost.martha_pos())
	while not StoryRun.is_night(sim.time):
		sim.time += 30.0  # the party is at night
	sim.request(1, "talk", Story.PEOPLE_IDS.find("martha"), [])
	var m: Dictionary = sim.crews[1].mission
	check(not m.is_empty() and Story.CHAPTERS[m.chapter].id == "e6", "Martha starts the party")
	for who: String in ["isabel", "silas", "quill", "wren"]:
		r.pos = Story.person_pos(who)
		sim.request(1, "talk", Story.PEOPLE_IDS.find(who), [])
	check(sim.crews[1].mission.is_empty(), "a word with everyone")
	r.pos = Outpost.martha_pos()
	sim.request(1, "talk", Story.PEOPLE_IDS.find("martha"), [])
	check(sim.crews[1].mission.is_empty(), "after the party Martha's counter is open again")

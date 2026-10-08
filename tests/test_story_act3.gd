extends "res://tests/support/case.gd"
## Act III of the story, chapter by chapter (docs/specs/2026-10-08-m10-the-siege.md).

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


func _first(sim: ServerSim, kind: int) -> StoryObject:
	for o: StoryObject in sim.story.objects.values():
		if o.kind == kind:
			return o
	return null


func _run(sim: ServerSim, seconds: float) -> void:
	for i in int(seconds / DT):
		sim.time += DT
		sim.story.tick(DT)
		sim._step_skeletons(DT)


func _fell_all(sim: ServerSim) -> void:
	for sid in sim.skeletons.keys():
		if sim.skeletons.has(sid) and sim.skeletons[sid].alive() and sim.skeletons[sid].frame < 0:
			sim._hurt_skeleton(sid, 9999, "Anne", 1)


## Carry item `id` (wherever it is) to `to` and hand it over.
func _deliver(sim: ServerSim, id: int, to: Vector3) -> void:
	var item: Loot = sim.items[id]
	var r := _ashore(sim, item.pos + Vector3(0, 0.1, 0))
	sim.request(1, "pickup", id, [])
	r.pos = to
	sim.request(1, "give", 0, [])


func test_ashes_on_the_wind() -> void:
	var sim := _sim("c1")
	var m: Dictionary = sim.crews[1].mission
	var lamp := _first(sim, StoryObject.Kind.LAMP)
	check(lamp != null, "the lamp burns green")
	# Fill a bucket, climb, douse.
	var r := _ashore(sim, Outpost.lighthouse_door())
	r.bucket = true
	sim.request(1, "climb_light", 0, [])
	check(r.pos.distance_to(Outpost.gallery_spot()) < 0.1, "up on the gallery")
	check(r.bucket, "with the water")
	sim.request(1, "douse", lamp.id, [])
	check_eq(m.step, 1, "the green fire is out")
	sim.request(1, "climb_light", 1, [])
	check(r.pos.distance_to(Outpost.lighthouse_door()) < 0.1, "back down")
	var oil: int = m.items[0]
	check_eq(sim.items[oil].kind, Loot.Kind.OIL)
	_deliver(sim, oil, Outpost.gallery_spot())
	check(sim.crews[1].mission.is_empty(), "the lamp burns true")


func test_powder_and_shot_with_raids() -> void:
	var sim := _sim("c2")
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.items.size(), 4, "four cannons at the old camp")
	sim.time = m.next_raid + 0.1
	sim.story.tick(DT)
	check(m.ship >= 0 and sim.ships.has(m.ship), "a skeleton ship raids")
	var raider: int = m.ship
	sim.story.tick(DT)
	check_eq(m.ship, raider, "one at a time")
	for id: int in m.items.duplicate():
		_deliver(sim, id, Outpost.battery_centre())
	check(sim.crews[1].mission.is_empty(), "four guns on the headland")


func test_saltshot_doubles_holes_in_the_dead() -> void:
	var sim := _sim("c3")
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.items.size(), 3, "salt, bronze and brine")
	var brine: Loot = null
	for id: int in m.items:
		if sim.items[id].kind == Loot.Kind.BRINE:
			brine = sim.items[id]
	check(brine != null and brine.state == Loot.State.FLOATING, "the brine floats at the reef's edge")
	for id: int in m.items.duplicate():
		_deliver(sim, id, Story.person_pos("wren"))
	check(sim.crews[1].mission.is_empty(), "saltshot brewed")
	check(sim.players[1].profile.chapters.has("c3"), "ticked off")
	# Against the dead's ships: two holes a hit.
	var enemy := sim.spawn_galleon(1, 100.0, 0)
	var holes: int = sim.ships[enemy].holes.size()
	sim._hull_hit({"id": 1, "ship": ServerSim.CREW}, enemy, Vector3(1.5, 0.3, 0), Vector3.ZERO)
	check_eq(sim.ships[enemy].holes.size() - holes, 2, "saltshot holes twice")


func test_hollowbells_skull_talks() -> void:
	var sim := _sim("c4")
	var m: Dictionary = sim.crews[1].mission
	_fell_all(sim)  # Hollowbell and his officers
	var skull: Loot = sim.items[m.skull]
	var r := _ashore(sim, skull.pos)
	sim.request(1, "pickup", skull.id, [])
	_run(sim, StoryRun.SKULL_TALK_EVERY * 2.0 + 4.0)
	check(m.talk_i >= 2, "the skull chats as it is carried (%d)" % m.talk_i)
	r.pos = Outpost.mystic_spot()
	sim.request(1, "sell", 0, [])
	check(sim.crews[1].mission.is_empty(), "Hollowbell rests")


func test_the_last_night_of_peace() -> void:
	var sim := _sim("c5")
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.items.size(), 3, "three barricades")
	for id: int in m.items.duplicate():
		_deliver(sim, id, Outpost.pier_spot())
	check(sim.crews[1].mission.is_empty(), "the pier is barricaded")


func test_the_siege_of_port_merrow() -> void:
	var sim := _sim("c6")
	sim.add_player(2, "Bart", 2, "b")
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.ships.size(), 3, "three galleons in the bay")
	var batteries := 0
	for o: StoryObject in sim.story.objects.values():
		if o.kind == StoryObject.Kind.BATTERY:
			batteries += 1
	check_eq(batteries, 4, "Merrow's battery")
	# Someone stands by the battery: it fires on the galleons once they come in range.
	_ashore(sim, Outpost.battery_spot(1) + Vector3(1, 0, 0))
	for id: int in m.ships:
		var g: ShipState = sim.ships[id]
		var merrow := Outpost.spec()
		g.x = merrow.x + 150.0
		g.z = merrow.z - 80.0
	_run(sim, 8.0)
	check(sim.stats.battery_shots >= 1, "the battery fires (%d)" % sim.stats.battery_shots)
	for id: int in m.ships.duplicate():
		sim.ships[id].sink = 0.01
	sim._handle_sinking()
	check_eq(m.step, 1, "the galleons are sunk: the beach")
	_run(sim, 1.0)
	for w in 3:
		check(sim.story.standing(m) >= 6, "wave %d lands" % (w + 1))
		_fell_all(sim)
		_run(sim, 0.5)
	check_eq(m.step, 2, "the beach is held: La Viuda")
	var viuda: Skeleton = sim.skeletons[m.captain]
	check(viuda.sniper and viuda.frame == m.ship, "on the flagship's quarterdeck")
	# Another crew's pirate comes to help, on the pier.
	var bart: Dictionary = sim.players[2]
	bart.mode = LocalPlayer.Mode.WORLD
	bart.ship = -1
	bart.pos = Outpost.pier_spot()
	check_eq(sim.ships[m.ship].flag, 2, "the Cuervo Negro")
	var r := _ashore(sim, Outpost.pier_spot() + Vector3(10, 0, 0))
	var hp_before: int = r.hp
	_run(sim, 6.0)
	check(r.hp < hp_before or r.dead_until >= 0.0, "she shoots")
	sim._hurt_skeleton(viuda.id, 9999, "Anne", 1)
	check_eq(m.step, 3, "La Viuda falls: the Doctor")
	check(_first(sim, StoryObject.Kind.OCASO) != null, "Ocaso on the pier")
	_fell_all(sim)
	_run(sim, 0.2)
	check(sim.crews[1].mission.is_empty(), "the siege is over")
	check_eq(sim.players[1].profile.title, "Defender of Merrow")
	check_eq(sim.players[2].profile.gold, 150, "another crew near Merrow shares the reward")
	var flagships := 0
	for id in sim.ships:
		if sim.ships[id].flag == 2:
			flagships += 1
	check_eq(flagships, 0, "the flagship sails away")

extends "res://tests/support/case.gd"
## Act I of the story, chapter by chapter (docs/specs/2026-10-08-m8-bones-in-the-sand.md).

const DT := 1.0 / 30.0


func _sim(chapter: String, step := 0, options := {}) -> ServerSim:
	options["no-ai"] = true
	options["calm"] = true
	options["chapter"] = chapter
	options["chapter-step"] = str(step)
	var sim := ServerSim.new(options)
	sim.add_player(1, "Anne", 1, "a")
	return sim


func _ashore(sim: ServerSim, at: Vector3) -> Dictionary:
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = at
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


func _bucket(sim: ServerSim, r: Dictionary) -> void:
	r.bucket = true


func test_act_one_has_six_chapters_in_order() -> void:
	var ids: Array[String] = []
	for ch: Dictionary in Story.CHAPTERS:
		if ch.act == 1 and not ch.has("tale"):
			ids.append(ch.id)
	check_eq(ids, ["a1", "a2", "a3", "a4", "a5", "a6"])
	check(Story.open_for(Story.index_of("a1"), [["p1", "p2"]]), "Act I follows the prologue")


func test_dig_faster_diggers_and_the_race() -> void:
	var sim := _sim("a1")
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.items.size(), 3, "three hoards buried")
	check_eq(m.thieves.size(), 3, "a digger for each")
	for sid: int in m.thieves:
		check(sim.skeletons[sid].digger, "a Spanish digger")
	# Dig one ourselves first and sell it.
	var mine: Loot = sim.items[m.items[0]]
	var r := _ashore(sim, mine.pos + Vector3(0.5, 0.05, 0))
	mine.state = Loot.State.GROUND
	sim.request(1, "pickup", mine.id, [])
	check_eq(r.carry, mine.id, "picked up our chest")
	r.pos = Outpost.sell_spot()
	sim.request(1, "sell", 0, [])
	check_eq(m.saved, 1, "one saved")
	# The diggers dig the rest and row off with them.
	_run(sim, 90.0)
	check(sim.stats.thefts >= 1, "the Spanish dug and stole (%d)" % sim.stats.thefts)
	_run(sim, 60.0)
	check(sim.crews[1].mission.is_empty(), "with every chest dealt with and one saved, the chapter is done")
	check(sim.players[1].profile.chapters.has("a1"), "ticked off")


func test_a_digger_drops_its_chest_when_felled() -> void:
	var sim := _sim("a1")
	var m: Dictionary = sim.crews[1].mission
	var digger: Skeleton = sim.skeletons[m.thieves[0]]
	var target: Loot = sim.items[digger.target_item]
	_run(sim, 1.0)
	var dug := false
	for i in 30 * 40:
		sim.time += DT
		sim._step_skeletons(DT)
		if digger.holding >= 0:
			dug = true
			break
	check(dug, "it dug its chest up")
	check_eq(target.state, Loot.State.HELD)
	sim._hurt_skeleton(digger.id, 999, "Anne", 1)
	check_eq(target.state, Loot.State.GROUND, "and dropped it")


func test_salt_the_earth() -> void:
	var sim := _sim("a2")
	var m: Dictionary = sim.crews[1].mission
	var graves := _objects(sim, StoryObject.Kind.GRAVE)
	check_eq(graves.size(), 3, "three open graves")
	for g in graves:
		check(Islands.ground_at(2, g.pos.x, g.pos.z) > Waves.max_height(), "a grave on dry land")
	check_eq(m.items.size(), 3, "three salt crates")
	var crate: Loot = sim.items[m.items[0]]
	check_eq(crate.variant, Missions.SALT)
	check(crate.pos.distance_to(Outpost.cargo_spot(0)) < 0.1, "on the pier")
	# The dead rise from open graves while we are near.
	var r := _ashore(sim, graves[0].pos + Vector3(1.5, 0, 0))
	_run(sim, 16.0)
	check(sim.story.standing(m) >= 1, "a dead climbs out")
	_fell_all(sim)
	# Salt every grave.
	for g in graves:
		var c: Loot = sim._new_item(Loot.Kind.CRATE, Loot.State.CARRIED, r.pos, 0)
		c.variant = Missions.SALT
		c.carrier = 1
		r.carry = c.id
		r.pos = g.pos + Vector3(1.0, 0, 0)
		sim.request(1, "salt", g.id, [])
		check_eq(g.state, 0, "salted")
		check_eq(r.carry, -1, "the crate is used up")
	check(sim.crews[1].mission.is_empty(), "graves salted and the dead down: done")
	check_eq(sim.players[1].profile.gold, 150)


func test_the_powder_store() -> void:
	var sim := _sim("a3")
	var m: Dictionary = sim.crews[1].mission
	var kegs := _objects(sim, StoryObject.Kind.KEG)
	check_eq(kegs.size(), 4, "four kegs under the sailcloth")
	check_eq(_objects(sim, StoryObject.Kind.STORE).size(), 1)
	var r := _ashore(sim, kegs[0].pos + Vector3(3.0, 0, 0))
	r.hp = 100
	sim.story.strike_keg(kegs[0].id)
	_run(sim, 1.0)
	check_eq(sim.stats.explosions, 0, "a fuse burns first")
	_run(sim, 2.5)
	check_eq(sim.stats.explosions, 4, "and the whole store goes up together")
	check(sim.players[1].hp < 100, "too close: we are hurt")
	check_eq(m.step, 1, "on to the orders in the wreckage")
	var book := _objects(sim, StoryObject.Kind.BOOK)[0]
	check(book.pos.distance_to(m.spot) < 2.0, "lying where the store was")


func test_shooting_a_keg_and_cannonballs() -> void:
	var sim := _sim("a3")
	var kegs := _objects(sim, StoryObject.Kind.KEG)
	sim._splash(kegs[1].pos)
	check_eq(kegs[1].state, 2, "a cannonball lights it")
	var r := _ashore(sim, kegs[2].pos + Vector3(0, 0, 4.0))
	r.weapon = Weapons.Kind.PISTOL
	r.next_attack = 0.0
	var to: Vector3 = kegs[2].pos + Vector3(0, -0.5 + 1.0, 0) - (r.pos + Vector3.UP * Weapons.EYE_HEIGHT)
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	sim.request(1, "attack", 0, [yaw, pitch])
	check(kegs[2].state == 2 or not sim.story.objects.has(kegs[2].id), "a pistol shot sets one off")


func test_the_raven_sails() -> void:
	var sim := _sim("a4")
	var m: Dictionary = sim.crews[1].mission
	var g: ShipState = sim.ships.get(m.ship)
	check(g != null and g.flag == 1, "a Spanish galleon under the raven")
	check_eq(sim.captains[m.ship].bail_scale, 2.0, "tougher than a skeleton ship")
	var spanish := 0
	for sk: Skeleton in sim.skeletons.values():
		if sk.frame == m.ship and sk.spanish:
			spanish += 1
	check_eq(spanish, StoryRun.GALLEON_CREW, "with the Spanish dead aboard")
	g.sink = 0.01
	var at := Vector3(g.x, 0, g.z)
	sim._handle_sinking()
	check_eq(m.step, 1, "sunk: on to the bottle")
	var bottle := _objects(sim, StoryObject.Kind.BOTTLE)[0]
	check(Vector2(bottle.pos.x - at.x, bottle.pos.z - at.z).length() < 1.0, "bobbing where she went down")
	_ashore(sim, Vector3(bottle.pos.x + 1.0, -1.0, bottle.pos.z))
	sim.request(1, "read", bottle.id, [])
	check_eq(m.step, 2, "the letter read; back to Wren")


func test_wrens_vigil_is_a_night_job() -> void:
	var sim := _sim("a5")
	sim.crews[1].mission = {}
	sim.players[1].profile.chapters.append_array(["p1", "p2", "a1", "a2", "a3", "a4"])
	sim.time = 0.5 * Daylight.DAY_LENGTH - Daylight.START * Daylight.DAY_LENGTH
	check(not StoryRun.is_night(sim.time), "midday")
	_ashore(sim, Story.person_pos("wren"))
	sim.request(1, "talk", Story.PEOPLE_IDS.find("wren"), [])
	check(sim.crews[1].mission.is_empty(), "not in daylight")
	sim.time = (0.9 - Daylight.START) * Daylight.DAY_LENGTH
	check(StoryRun.is_night(sim.time), "night")
	sim.request(1, "talk", Story.PEOPLE_IDS.find("wren"), [])
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.name, "a5", "the vigil begins")
	check_eq(m.captains.size(), 3, "a captain on each of three islands")
	check(m.deadline > sim.time, "with dawn as the deadline")
	sim.time = m.deadline + 1.0
	sim.story.tick(DT)
	check(sim.crews[1].mission.is_empty(), "dawn ends a failed vigil")


func test_vigil_three_skulls() -> void:
	var sim := _sim("a5")
	var m: Dictionary = sim.crews[1].mission
	var r := _ashore(sim, Outpost.mystic_spot())
	for sid: int in m.captains.duplicate():
		sim._hurt_skeleton(sid, 9999, "Anne", 1)
	check_eq(m.items.size(), 3, "three skulls on three islands")
	for id: int in m.items.duplicate():
		var skull: Loot = sim.items[id]
		skull.state = Loot.State.CARRIED
		skull.carrier = 1
		r.carry = id
		sim.request(1, "sell", 0, [])
	check(sim.crews[1].mission.is_empty(), "three skulls to Wren: done")


func test_the_sergeants_camp() -> void:
	var sim := _sim("a6")
	var m: Dictionary = sim.crews[1].mission
	var fire := _objects(sim, StoryObject.Kind.BONFIRE)[0]
	check_eq(fire.state, 3, "three buckets to put it out")
	check_eq(_objects(sim, StoryObject.Kind.CAMP).size(), 1, "the dig camp stands round it")
	var r := _ashore(sim, fire.pos + Vector3(2.5, 0, 0))
	_run(sim, 3.0)
	check(sim.story.standing(m) >= 2, "the bonfire raises the dead")
	for n in 3:
		r.bucket = true
		sim.request(1, "douse", fire.id, [])
	check_eq(fire.state, 0, "out after three buckets")
	check_eq(m.step, 0, "its dead still stand")
	_fell_all(sim)
	check_eq(m.step, 1, "the sergeant's turn")
	var boss: Skeleton = sim.skeletons[m.captain]
	check(boss.sergeant and boss.shield_up, "Calavera behind his shield")
	check_eq(boss.hp, 300)
	# From the front: the blade rings off; a shot knocks the shield aside.
	var front := boss.pos + Vector3(-sin(boss.yaw), 0, -cos(boss.yaw)) * 1.5
	r.pos = front
	r.next_attack = 0.0
	r.weapon = Weapons.Kind.CUTLASS
	var to: Vector3 = boss.pos + Vector3.UP * 1.0 - (r.pos + Vector3.UP * Weapons.EYE_HEIGHT)
	var look := [atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length())]
	sim.request(1, "attack", 0, look)
	check_eq(boss.hp, 300, "blocked")
	r.weapon = Weapons.Kind.PISTOL
	r.next_attack = 0.0
	sim.request(1, "attack", 0, look)
	check(not boss.shield_up, "a shot knocks the shield aside")
	r.weapon = Weapons.Kind.CUTLASS
	r.next_attack = 0.0
	sim.request(1, "attack", 0, look)
	check(boss.hp < 300, "now the blade bites")
	sim.time += Skeleton.SHIELD_DOWN + 0.1
	sim.story.tick(DT)
	check(boss.shield_up, "and the shield comes back up")
	sim._hurt_skeleton(boss.id, 9999, "Anne", 1)
	check_eq(m.step, 2, "Calavera falls: his orders")
	check(_objects(sim, StoryObject.Kind.BOOK).size() == 1, "on his body")
	var book := _objects(sim, StoryObject.Kind.BOOK)[0]
	r.pos = book.pos
	sim.request(1, "read", book.id, [])
	_ashore(sim, Story.person_pos("wren"))
	sim.request(1, "talk", Story.PEOPLE_IDS.find("wren"), [])
	check(sim.crews[1].mission.is_empty(), "the act is done")
	check(sim.players[1].profile.titles.has("Gravewarden"), "a title")
	check_eq(sim.players[1].profile.title, "Gravewarden", "worn")

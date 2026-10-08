extends "res://tests/support/case.gd"
## The Act III tales: Penny's Hoard (Silas) and The Other Lantern (Mother Wren).

const DT := 1.0 / 30.0


func _sim(chapter: String) -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true, "chapter": chapter})
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


## [yaw, pitch] for `r` to look from their eye at `at`.
func _look(r: Dictionary, at: Vector3) -> Array:
	var to: Vector3 = at - (r.pos + Vector3.UP * Weapons.EYE_HEIGHT)
	return [atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length())]


func _fell_all(sim: ServerSim) -> void:
	for sid in sim.skeletons.keys():
		if sim.skeletons.has(sid) and sim.skeletons[sid].alive():
			sim._hurt_skeleton(sid, 9999, "Anne", 1)


func test_the_tales_open_after_hollowbell_and_the_siege() -> void:
	check(Story.open_for(Story.index_of("t6"), [["c1", "c2", "c3", "c4"]]), "Penny's Hoard after The Pressed Dead")
	check(not Story.open_for(Story.index_of("t6"), [["c1", "c2", "c3"]]), "and not before")
	check(Story.open_for(Story.index_of("t9"), [["c6"]]), "The Other Lantern after the siege")
	check_eq(Story.offered_by("silas", [["c4"]]), Story.index_of("t6"), "Silas tells it")


func test_my_boy_silas() -> void:
	var sim := _sim("t6")
	var m: Dictionary = sim.crews[1].mission
	var mark := _first(sim, StoryObject.Kind.BOOK)
	check(mark != null and Islands.island_at(mark.pos.x, mark.pos.z) == 1, "Hollowbell's mark on Parrot Rock")
	_ashore(sim, mark.pos)
	sim.request(1, "read", mark.id, [])
	check_eq(m.step, 1, "the riddle read: the arch on Gull Isle")
	check_eq(m.items.size(), 1, "one chest buried")
	check_eq(m.thieves.size(), 1, "and a Spanish digger after it")
	var chest: Loot = sim.items[m.items[0]]
	check(Islands.island_at(chest.pos.x, chest.pos.z) == 2, "on Gull Isle")
	var r := _ashore(sim, chest.pos + Vector3(0.5, 0.05, 0))
	chest.state = Loot.State.GROUND
	sim.request(1, "pickup", chest.id, [])
	r.pos = Outpost.sell_spot()
	sim.request(1, "sell", 0, [])
	check(sim.crews[1].mission.is_empty(), "the note found: the rest is with the lads")


func test_the_old_crew_and_the_bosuns_skull() -> void:
	var sim := _sim("t7")
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.raised.size(), 5, "Bosun Grieve and four of the lads")
	_fell_all(sim)
	var skull: Loot = sim.items[m.skull]
	var r := _ashore(sim, skull.pos)
	sim.request(1, "pickup", skull.id, [])
	_run(sim, StoryRun.SKULL_TALK_EVERY + 4.0)
	check(m.talk_i >= 1, "the bosun's skull talks")
	r.pos = Outpost.mystic_spot()
	sim.request(1, "sell", 0, [])
	check_eq(r.carry, skull.id, "not Wren's to buy")
	r.pos = Story.person_pos("silas")
	sim.request(1, "give", 0, [])
	check(sim.crews[1].mission.is_empty(), "Silas has his bosun back")


func test_silas_cries_and_gives_his_cap() -> void:
	var sim := _sim("t8")
	var m: Dictionary = sim.crews[1].mission
	check_eq(m.items.size(), 3, "three chests under the old camp")
	var first: Loot = sim.items[m.items[0]]
	check_eq(first.kind, Loot.Kind.CHEST)
	var r := _ashore(sim, first.pos + Vector3(0, 0.05, 0))
	sim.request(1, "pickup", first.id, [])
	r.pos = Outpost.sell_spot()
	sim.request(1, "sell", 0, [])
	check_eq(r.carry, first.id, "Silas won't buy his own hoard")
	check_eq(int(r.profile.gold), 0, "no gold for trying")
	for id: int in m.items.duplicate():
		var item: Loot = sim.items[id]
		if r.carry != id:
			_ashore(sim, item.pos + Vector3(0, 0.05, 0))
			sim.request(1, "pickup", id, [])
		r.pos = Story.person_pos("silas")
		sim.request(1, "give", 0, [])
	check(sim.crews[1].mission.is_empty(), "the hoard is home")
	check(r.profile.owned.has("outfit8"), "Silas's old cap is ours")
	r.pos = Outpost.martha_pos()
	sim.request(1, "wear", Shop.index_of("outfit8"), [])
	check_eq(r.profile.look, 8, "and we wear it")


func test_two_lights_is_talk() -> void:
	var sim := _sim("t9")
	var m: Dictionary = sim.crews[1].mission
	_ashore(sim, Story.person_pos("moll"))
	sim.request(1, "talk", Story.PEOPLE_IDS.find("moll"), [])
	check_eq(m.step, 1, "Moll saw the second light")
	_ashore(sim, Story.person_pos("wren"))
	sim.request(1, "talk", Story.PEOPLE_IDS.find("wren"), [])
	check(sim.crews[1].mission.is_empty(), "Wren knows it: Linnet")


func test_linnet_moves_on_flares_and_falls() -> void:
	var sim := _sim("t10")
	var m: Dictionary = sim.crews[1].mission
	var linnet: Skeleton = sim.skeletons[m.captain]
	check(linnet.linnet and linnet.shield_up, "Linnet, her lantern lit")
	check_eq(Islands.island_at(linnet.pos.x, linnet.pos.z), 2, "on Gull Isle first")
	# Come near and she goes on: Parrot Rock, then Cutlass Cay.
	var r := _ashore(sim, linnet.pos + Vector3(5, 0, 0))
	_run(sim, 0.1)
	check_eq(Islands.island_at(linnet.pos.x, linnet.pos.z), 1, "on to Parrot Rock")
	r.pos = linnet.pos + Vector3(5, 0, 0)
	_run(sim, 0.1)
	check_eq(Islands.island_at(linnet.pos.x, linnet.pos.z), 0, "then Cutlass Cay, where she stays")
	check_eq(sim.story.standing(m), 4, "with three of the drowned round her")
	r.pos = linnet.pos + Vector3(5, 0, 0)
	_run(sim, 0.1)
	check_eq(Islands.island_at(linnet.pos.x, linnet.pos.z), 0, "she goes no further")
	for sid: int in m.raised:
		if sid != linnet.id:
			sim._hurt_skeleton(sid, 9999, "Anne", 1)
	# Looking at her when the lantern flares blinds; looking away doesn't.
	var to: Vector3 = linnet.pos - r.pos
	r.yaw = atan2(-to.x, -to.z)
	_run(sim, StoryRun.LINNET_FLASH_EVERY + StoryRun.LINNET_GLINT + 0.5)
	check(sim.stats.blinded >= 1, "blinded by her lantern")
	var blinded: int = sim.stats.blinded
	r.yaw += PI
	_run(sim, StoryRun.LINNET_FLASH_EVERY + 0.5)
	check_eq(sim.stats.blinded, blinded, "not with our back to her")
	# A blade passes through the light; a shot knocks the lantern from her hand.
	r.pos = linnet.pos + Vector3(1.2, 0, 0)
	r.weapon = Weapons.Kind.CUTLASS
	r.next_attack = 0.0
	sim.request(1, "attack", 0, _look(r, linnet.pos + Vector3(0, 1.0, 0)))
	check_eq(linnet.hp, StoryRun.LINNET_HEALTH, "the blade passes through her light")
	r.pos = linnet.pos + Vector3(8, 0, 0)
	r.weapon = Weapons.Kind.PISTOL
	r.next_attack = 0.0
	sim.request(1, "attack", 0, _look(r, linnet.pos + Vector3(0, 1.1, 0)))
	check(not linnet.shield_up, "the lantern is shot from her hand")
	check_eq(sim.stats.lanterns, 1)
	r.pos = linnet.pos + Vector3(1.2, 0, 0)
	r.weapon = Weapons.Kind.CUTLASS
	r.next_attack = 0.0
	sim.request(1, "attack", 0, _look(r, linnet.pos + Vector3(0, 1.0, 0)))
	check(linnet.hp < StoryRun.LINNET_HEALTH, "now the blade bites")
	_fell_all(sim)
	var skull: Loot = sim.items[m.skull]
	_ashore(sim, skull.pos)
	sim.request(1, "pickup", skull.id, [])
	r.pos = Outpost.mystic_spot()
	sim.request(1, "sell", 0, [])
	check(sim.crews[1].mission.is_empty(), "Linnet is home with her sister")


func test_rest_makes_a_lantern_bearer() -> void:
	var sim := _sim("t11")
	_ashore(sim, Story.person_pos("wren"))
	sim.request(1, "talk", Story.PEOPLE_IDS.find("wren"), [])
	check(sim.crews[1].mission.is_empty(), "Linnet rests")
	check_eq(sim.players[1].profile.title, "Lantern-Bearer")

extends "res://tests/support/case.gd"


func _sim(options := {}) -> ServerSim:
	options["no-ai"] = true
	var sim := ServerSim.new(options)
	sim.add_player(1, "Anne", 1, "anne-token")
	return sim


func test_levels_and_titles() -> void:
	check_eq(Progress.level(0), 1)
	check_eq(Progress.xp_for(2), 400, "level 2 at 400 XP")
	check_eq(Progress.xp_for(5), 2200, "level 5 at 2,200 XP")
	check_eq(Progress.xp_for(10), 7200, "level 10 at 7,200 XP")
	check_eq(Progress.level(Progress.xp_for(5) - 1), 4)
	check_eq(Progress.level(Progress.xp_for(5)), 5)
	check_eq(Progress.level(10000000), Progress.MAX_LEVEL, "capped")
	check_eq(Progress.title_for(1), "Deckhand")
	check_eq(Progress.title_for(5), "Powder Monkey")
	check_eq(Progress.title_for(7), "Powder Monkey", "a title lasts until the next")
	check_eq(Progress.title_for(30), "Legend of the Isles")
	check(absf(Progress.level_fraction(Progress.xp_for(3) + 300) - 0.5) < 0.001, "halfway through level 3")


func test_profiles_keep_a_name_to_its_token() -> void:
	var p := Profiles.new()
	check_eq(p.check("Anne", "a"), "", "a new name is free")
	var anne := p.get_or_make("Anne", "a")
	check_eq(anne.xp, 0)
	check_eq(p.check("anne", "a"), "", "same token, any case")
	check(p.check("ANNE ", "b") != "", "another token is refused")
	check(p.get_or_make("Anne", "a") == anne, "the same profile comes back")
	check_eq(Profiles.key_for("Black Bess!"), "black_bess_")


func test_profiles_save_and_load() -> void:
	var dir := "user://test_profiles_%d" % Time.get_ticks_usec()
	var first := Profiles.new(dir)
	var anne := first.get_or_make("Anne", "a")
	anne.xp = 1234
	anne.gold = 567
	anne.rep[1] = 300
	anne.chapters.append("p1")
	first.changed("Anne")
	first.tick(0.0)
	check(not FileAccess.file_exists(dir.path_join("anne.json")), "waits before writing")
	first.tick(Profiles.SAVE_DELAY + 0.1)
	check(FileAccess.file_exists(dir.path_join("anne.json")), "written after the delay")
	var second := Profiles.new(dir)
	check_eq(second.check("Anne", "b"), "That name belongs to another pirate on this server. Pick another name.")
	var back := second.get_or_make("Anne", "a")
	check_eq(back.xp, 1234, "XP remembered")
	check_eq(back.gold, 567, "gold remembered")
	check_eq(back.rep, [0, 300, 0], "standing remembered")
	check_eq(back.chapters, ["p1"], "chapters remembered")
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func test_joining_checks_the_name() -> void:
	var sim := _sim()
	check(sim.can_join(GameConfig.VERSION, "Anne", "anne-token") != "", "Anne is already aboard")
	sim.remove_player(1)
	check_eq(sim.can_join(GameConfig.VERSION, "Anne", "anne-token"), "", "Anne may come back")
	check(sim.can_join(GameConfig.VERSION, "Anne", "someone-else") != "", "but not as someone else")
	check_eq(sim.can_join(GameConfig.VERSION, "Bart", "b"), "")


func test_every_crew_member_gets_the_gold() -> void:
	var sim := _sim()
	sim.add_player(2, "Bart", 1, "b")
	sim.add_player(3, "Cora", 2, "c")
	var chest := sim._new_item(Loot.Kind.CHEST, Loot.State.GROUND, Outpost.sell_spot(), 240)
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.pos = chest.pos
	sim.request(1, "pickup", chest.id, [])
	sim.request(1, "sell", 0, [])
	check_eq(sim.players[1].profile.gold, 240, "the seller")
	check_eq(sim.players[2].profile.gold, 240, "a crewmate gets the full price too")
	check_eq(sim.players[3].profile.gold, 0, "another crew gets nothing")
	check_eq(sim.players[2].profile.rep[Missions.Company.GOLD], Missions.CHEST_POINTS, "and the standing")


func test_xp_for_felling_skeletons() -> void:
	var sim := _sim()
	var sk := sim._new_skeleton(-1, Vector3(0, 2, 0))
	sim._hurt_skeleton(sk.id, 999, "Anne", 1)
	check_eq(sim.players[1].profile.xp, Progress.XP_SKELETON)
	var cap := sim._new_skeleton(-1, Vector3(0, 2, 0))
	cap.make_captain()
	sim._hurt_skeleton(cap.id, 999, "Anne", 1)
	check_eq(sim.players[1].profile.xp, Progress.XP_SKELETON + Progress.XP_CAPTAIN)
	var cannon := sim._new_skeleton(-1, Vector3(0, 2, 0))
	sim._hurt_skeleton(cannon.id, 999, "a cannonball")
	check_eq(sim.players[1].profile.xp, Progress.XP_SKELETON + Progress.XP_CAPTAIN, "nobody's blow, nobody's XP")


func test_xp_for_knocking_down_pirates_once_in_a_while() -> void:
	var sim := _sim()
	sim.add_player(2, "Bart", 2, "b")
	sim._hurt_player(2, 999, "Anne", 1)
	check_eq(sim.players[1].profile.xp, Progress.XP_PLAYER)
	sim.players[2].dead_until = -1.0
	sim.players[2].hp = ServerSim.HEALTH
	sim._hurt_player(2, 999, "Anne", 1)
	check_eq(sim.players[1].profile.xp, Progress.XP_PLAYER, "not again so soon")
	sim.time += Progress.PLAYER_XP_COOLDOWN + 1.0
	sim.players[2].dead_until = -1.0
	sim.players[2].hp = ServerSim.HEALTH
	sim._hurt_player(2, 999, "Anne", 1)
	check_eq(sim.players[1].profile.xp, 2 * Progress.XP_PLAYER, "but later, yes")


func test_xp_for_sinking_a_ship_goes_to_the_crew_that_hit_it() -> void:
	var sim := _sim({"test-boarding": true})
	sim.add_player(2, "Bart", 1, "b")
	var enemy := -1
	for id in sim.ships:
		if not sim.crews.has(id):
			enemy = id
	check(enemy > 0, "a skeleton ship lies alongside")
	sim._hull_hit({"id": 1, "ship": ServerSim.CREW}, enemy, Vector3(0, 0.5, 0), Vector3.ZERO)
	sim.ships[enemy].water = ShipPhysics.SINK_LEVEL
	sim.ships[enemy].sink = 0.01
	sim._handle_sinking()
	check_eq(sim.players[1].profile.xp, Progress.XP_SKELETON_SHIP)
	check_eq(sim.players[2].profile.xp, Progress.XP_SKELETON_SHIP, "the whole crew")


func test_level_up_titles_the_pirate() -> void:
	var sim := _sim()
	sim._award(1, Progress.xp_for(5), "a test")
	check_eq(Progress.level(sim.players[1].profile.xp), 5)
	check_eq(sim.players[1].profile.title, "Powder Monkey")
	check_eq(sim.tags[1], [5, "Powder Monkey"], "everyone sees it")
	check_eq(sim.stats.levels, 1)

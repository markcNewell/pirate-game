extends "res://tests/support/case.gd"

const DT := 1.0 / 60.0


func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true})
	sim.add_player(1, "Anne")
	return sim


func test_cutlass_reaches_in_front_not_behind() -> void:
	var eye := Vector3(0, 1.6, 0)
	var look := Vector3(0, 0, -1)
	var feet := [Vector3(0, 0, -1.8), Vector3(0, 0, 1.5), Vector3(1.0, 0, -1.6), Vector3(0, 0, -4.0)]
	var hits := Weapons.cutlass_hits(eye, look, feet)
	check(hits.has(0), "straight ahead in reach")
	check(not hits.has(1), "not behind")
	check(hits.has(2), "within the arc")
	check(not hits.has(3), "out of reach")


func test_pistol_hits_the_first_body_along_the_aim() -> void:
	var eye := Vector3(0, 1.6, 0)
	var feet := [Vector3(0.2, 0, -20), Vector3(0, 0, -10), Vector3(3, 0, -10)]
	check_eq(Weapons.pistol_hit(eye, Vector3(0, 0, -1), feet), 1, "the nearer one in line")
	check_eq(Weapons.pistol_hit(eye, Vector3(1, 0, 0), feet), -1, "nothing to the side")
	check_eq(Weapons.pistol_hit(eye, Vector3(0, 0, -1), [Vector3(0, 0, -80)]), -1, "beyond range")


func test_splash_damage_falls_off() -> void:
	check_eq(Weapons.splash_damage(0.5), 70)
	check_eq(Weapons.splash_damage(2.5), 30)
	check_eq(Weapons.splash_damage(5.0), 0)


func test_skeleton_walks_up_and_swings() -> void:
	var sk := Skeleton.new()
	sk.pos = Vector3(0, 1, 0)
	var flat := func(x: float, z: float) -> float: return 1.0
	var swings := 0
	for i in int(6.0 / DT):
		if sk.step(Vector3(10, 1, 0), DT, flat):
			swings += 1
	check(sk.pos.x > 8.0, "it closed in, x=%f" % sk.pos.x)
	check(swings >= 2, "and swung at least twice, %d" % swings)


func test_skeleton_keeps_off_the_water() -> void:
	var sk := Skeleton.new()
	sk.pos = Vector3(0, 1, 0)
	var shore := func(x: float, z: float) -> float: return 1.0 if x < 5.0 else NAN
	for i in int(6.0 / DT):
		sk.step(Vector3(15, 0, 0), DT, shore)
	check(sk.pos.x < 5.0, "stops at the shore, x=%f" % sk.pos.x)


func test_skeleton_ignores_far_targets() -> void:
	var sk := Skeleton.new()
	var flat := func(x: float, z: float) -> float: return 0.0
	sk.step(Vector3(Skeleton.CHASE_RANGE + 5.0, 0, 0), DT, flat)
	check_eq(sk.pos, Vector3.ZERO)


func test_island_camp_wakes_and_fights() -> void:
	var sim := _sim()
	var r: Dictionary = sim.players[1]
	var spec: Dictionary = Islands.LAYOUT[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = Vector3(spec.x, Islands.ground_at(1, spec.x, spec.z), spec.z)
	sim.tick(DT)
	var awake := 0
	for id in sim.skeletons:
		awake += 1
	check_eq(awake, ServerSim.CAMP_SIZE, "a camp of skeletons wakes")
	# Stand still among them for a while: they come and hit us.
	for i in int(20.0 / DT):
		sim.tick(DT)
		r.time = sim.time
	check(sim.stats.skeleton_swings > 0, "they swung")
	check(r.hp < ServerSim.HEALTH or r.dead_until >= 0.0 or sim.stats.falls > 0, "and it hurt")


func test_cutlass_fells_a_skeleton_in_three_cuts() -> void:
	var sim := _sim()
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = Vector3(500, 0, 500)
	var sk := sim._new_skeleton(-1, Vector3(500, 0, 498.5), -1)
	for n in 3:
		sim.time += Weapons.CUTLASS_COOLDOWN + 0.05
		sim.request(1, "attack", Weapons.Kind.CUTLASS, [0.0, 0.0])
	check(not sk.alive(), "three cuts fell it (hp %d)" % sk.hp)
	check_eq(sim.stats.kills, 1)


func test_attacks_respect_the_cooldown() -> void:
	var sim := _sim()
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = Vector3(500, 0, 500)
	var sk := sim._new_skeleton(-1, Vector3(500, 0, 498.5), -1)
	for n in 5:
		sim.request(1, "attack", Weapons.Kind.CUTLASS, [0.0, 0.0])
	check_eq(sk.hp, Skeleton.HEALTH - Weapons.CUTLASS_DAMAGE, "spamming lands one cut")


func test_falling_makes_a_ghost_then_back_aboard() -> void:
	var sim := _sim()
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = Vector3(300, 0, 300)
	sim._hurt_player(1, 150, "a test")
	check(r.dead_until >= 0.0, "fallen")
	sim.request(1, "voyage", 0, [])
	check(sim.voyage.is_empty(), "ghosts cannot act")
	for i in int((ServerSim.GHOST_TIME + 0.5) / DT):
		sim.tick(DT)
	check_eq(r.dead_until, -1.0, "back again")
	check_eq(r.hp, ServerSim.HEALTH)
	check_eq(r.mode, LocalPlayer.Mode.ON_SHIP)
	check_eq(r.ship, ServerSim.CREW)


func test_bananas_heal() -> void:
	var sim := _sim()
	var r: Dictionary = sim.players[1]
	r.hp = 30
	r.pos = ShipShape.BANANA_BARREL + Vector3(-0.9, 0, 0)
	var before := sim.crew_ship().bananas
	sim.request(1, "eat", 0, [])
	check_eq(r.hp, 80)
	check_eq(sim.crew_ship().bananas, before - 1)


func test_boarding_a_skeleton_ship_by_its_ladder() -> void:
	var sim := ServerSim.new({"no-ai": true, "test-boarding": true})
	sim.add_player(1, "Anne")
	var r: Dictionary = sim.players[1]
	var skel_id := -1
	for id in sim.ships:
		if id != ServerSim.CREW:
			skel_id = id
	check(skel_id > 0, "a skeleton ship lies alongside")
	var crewed := 0
	for id in sim.skeletons:
		if sim.skeletons[id].frame == skel_id:
			crewed += 1
	check_eq(crewed, ServerSim.SHIP_SKELETONS, "with its crew aboard")
	var bottom := ShipPhysics.pose_of(sim.ships[skel_id], sim.time) * ShipShape.ladder_bottom(1)
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = bottom + Vector3(0.5, -1.0, 0)
	sim.request(1, "climb", 1, [])
	check_eq(r.mode, LocalPlayer.Mode.ON_SHIP)
	check_eq(r.ship, skel_id, "standing on the skeleton ship")
	sim.request(1, "station", 0, [])
	check_eq(r.station, -1, "no taking the enemy's wheel")

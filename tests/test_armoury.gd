extends "res://tests/support/case.gd"
## The armoury (docs/specs/2026-10-08-m14-the-armoury.md): fair choices, never upgrades.


func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true})
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


## A skeleton standing at `at` on Parrot Rock's ground, doing nothing.
func _dummy(sim: ServerSim, at: Vector3) -> Skeleton:
	var island := Islands.island_at(at.x, at.z)
	at.y = Islands.ground_at(maxi(0, island), at.x, at.z)
	var sk := sim._new_skeleton(-1, at)
	sk.cooldown = 1e6
	sk.hp = 1000
	return sk


## Attack once with hand `hand`, looking from the eye at `at`.
func _attack(sim: ServerSim, r: Dictionary, hand: int, at: Vector3) -> void:
	r.weapon = hand
	r.next_attack = 0.0
	var to: Vector3 = at - (r.pos + Vector3.UP * Weapons.EYE_HEIGHT)
	sim.request(1, "attack", 0, [atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length())])


func test_blades_are_fair_choices() -> void:
	var base := float(Weapons.BLADES[0].damage) / float(Weapons.BLADES[0].every)
	for b: Dictionary in Weapons.BLADES:
		var dps := float(b.damage) / float(b.every)
		check(absf(dps - base) / base < 0.05, "%s: %.1f a second against the cutlass's %.1f" % [b.name, dps, base])
	check(Weapons.BLADES[1].reach > Weapons.BLADES[0].reach and Weapons.BLADES[1].half_arc < Weapons.BLADES[0].half_arc, "the rapier reaches further but you must aim it")
	check(Weapons.BLADES[2].half_arc > Weapons.BLADES[0].half_arc and Weapons.BLADES[2].reach < Weapons.BLADES[0].reach, "the axe sweeps wider but shorter")


func test_guns_trade_range_for_punch() -> void:
	var pistol := float(Weapons.GUNS[0].damage) / float(Weapons.GUNS[0].every)
	var musket := float(Weapons.GUNS[2].damage) / float(Weapons.GUNS[2].every)
	check(absf(musket - pistol) / pistol < 0.1, "the musket's %.1f a second is the pistol's %.1f" % [musket, pistol])
	check(Weapons.GUNS[2].range > Weapons.GUNS[0].range, "but it reaches further")
	check(Weapons.GUNS[1].range < 20.0, "the blunderbuss is for close work only")
	check_eq(Weapons.pellet_dirs(Vector3.FORWARD, 6, 0.12).size(), 6, "six pellets")
	for d in Weapons.pellet_dirs(Vector3.FORWARD, 6, 0.12):
		check(d.angle_to(Vector3.FORWARD) <= 0.121, "inside the spray")


func test_buying_and_carrying_arms() -> void:
	var sim := _sim()
	var r := _ashore(sim, Outpost.martha_pos())
	var rapier := Shop.index_of("blade1")
	sim.request(1, "buy", rapier, [])
	check(not r.profile.owned.has("blade1"), "no gold, no rapier")
	r.profile.gold = 700
	sim.request(1, "buy", rapier, [])
	check_eq(int(r.profile.gold), 100, "paid for it")
	check_eq(int(r.profile.blade), 1, "and carries it")
	check_eq(sim.tags[1][4], 1, "everyone sees it")
	sim.request(1, "buy", Shop.index_of("blade0"), [])
	check_eq(int(r.profile.blade), 0, "back to the cutlass, free: it was always ours")
	check_eq(int(r.profile.gold), 100)


func test_the_rapier_reaches_further_and_strikes_quicker() -> void:
	var sim := _sim()
	var spec: Dictionary = Islands.LAYOUT[1]
	var r := _ashore(sim, Vector3(spec.x, 0, spec.z))
	r.pos.y = Islands.ground_at(1, r.pos.x, r.pos.z)
	var sk := _dummy(sim, r.pos + Vector3(2.75, 0, 0))
	_attack(sim, r, Weapons.Kind.CUTLASS, sk.pos + Vector3(0, 1.0, 0))
	check_eq(sk.hp, 1000, "out of the cutlass's reach")
	r.profile.blade = 1
	_attack(sim, r, Weapons.Kind.CUTLASS, sk.pos + Vector3(0, 1.0, 0))
	check_eq(sk.hp, 1000 - 15, "the rapier reaches")
	check(absf(r.next_attack - sim.time - 0.36) < 0.01, "and is ready again sooner")


func test_the_axe_sweeps_two_at_once() -> void:
	var sim := _sim()
	var spec: Dictionary = Islands.LAYOUT[1]
	var r := _ashore(sim, Vector3(spec.x, 0, spec.z))
	r.pos.y = Islands.ground_at(1, r.pos.x, r.pos.z)
	var a := _dummy(sim, r.pos + Vector3(1.4, 0, -1.2))
	var b := _dummy(sim, r.pos + Vector3(1.4, 0, 1.2))
	r.profile.blade = 2
	_attack(sim, r, Weapons.Kind.CUTLASS, r.pos + Vector3(1.8, 1.6, 0))
	check_eq(a.hp, 1000 - 45, "the axe catches one")
	check_eq(b.hp, 1000 - 45, "and the other")


func test_the_blunderbuss_sprays_close_and_misses_far() -> void:
	var sim := _sim()
	var spec: Dictionary = Islands.LAYOUT[0]
	var r := _ashore(sim, Vector3(spec.x, 0, spec.z))
	r.pos.y = Islands.ground_at(0, r.pos.x, r.pos.z)
	var near := _dummy(sim, r.pos + Vector3(4.0, 0, 0))
	r.profile.gun = 1
	_attack(sim, r, Weapons.Kind.PISTOL, near.pos + Vector3(0, 1.0, 0))
	check(near.hp <= 1000 - 24, "several pellets land up close (%d)" % (1000 - near.hp))
	var far := _dummy(sim, r.pos + Vector3(0, 0, 24.0))
	_attack(sim, r, Weapons.Kind.PISTOL, far.pos + Vector3(0, 1.0, 0))
	check_eq(far.hp, 1000, "nothing at 24 m")


func test_the_musket_picks_off_at_range() -> void:
	var sim := _sim()
	var spec: Dictionary = Islands.LAYOUT[0]
	var r := _ashore(sim, Vector3(spec.x - 40.0, 0, spec.z))
	r.pos.y = Islands.ground_at(0, r.pos.x, r.pos.z)
	var target := _dummy(sim, r.pos + Vector3(80.0, 0, 0))
	_attack(sim, r, Weapons.Kind.PISTOL, target.pos + Vector3(0, 1.0, 0))
	check_eq(target.hp, 1000, "too far for a pistol")
	r.profile.gun = 2
	_attack(sim, r, Weapons.Kind.PISTOL, target.pos + Vector3(0, 1.0, 0))
	check_eq(target.hp, 1000 - 75, "the musket reaches")


func test_any_gun_knocks_a_lantern_away() -> void:
	var sim := ServerSim.new({"no-ai": true, "calm": true, "chapter": "t10"})
	sim.add_player(1, "Anne", 1, "a")
	var m: Dictionary = sim.crews[1].mission
	var linnet: Skeleton = sim.skeletons[m.captain]
	var r := _ashore(sim, linnet.pos + Vector3(6.0, 0, 0))
	r.profile.gun = 1
	_attack(sim, r, Weapons.Kind.PISTOL, linnet.pos + Vector3(0, 1.1, 0))
	check(not linnet.shield_up, "a blunderbuss does what a pistol does")


func test_armour_is_a_trade() -> void:
	for a: Dictionary in Weapons.ARMOURS:
		check(absf(float(a.blade) + float(a.shot) - 2.0) < 0.001, "%s: what it saves one way it costs the other" % a.name)
	var sim := _sim()
	var r := _ashore(sim, Outpost.martha_pos())
	r.profile.gold = 1000
	sim.request(1, "buy", Shop.index_of("armour1"), [])
	check_eq(int(r.profile.armour), 1, "a padded coat")
	check_eq(sim.tags[1][6], 1, "worn where everyone can see it")
	sim._hurt_player(1, 20, "a skeleton", -1, Weapons.Hit.BLADE)
	check_eq(int(r.hp), ServerSim.HEALTH - 14, "softer against blades")
	r.hp = ServerSim.HEALTH
	sim._hurt_player(1, 30, "a cannonball", -1, Weapons.Hit.SHOT)
	check_eq(int(r.hp), ServerSim.HEALTH - 39, "harder against shot")
	r.hp = ServerSim.HEALTH
	sim._hurt_player(1, 25, "lightning")
	check_eq(int(r.hp), ServerSim.HEALTH - 25, "and nothing against lightning")

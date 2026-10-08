extends "res://tests/support/case.gd"
## The last two world events (docs/specs/2026-10-08-m18-fort-and-maw.md): the dead re-taking
## Fuerte del Cuervo, and the Maw stirring after the story.

const DT := 1.0 / 30.0


func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true})
	sim.add_player(1, "Anne", 1, "a")
	return sim


func _ashore(sim: ServerSim, id: int, at: Vector3) -> Dictionary:
	var r: Dictionary = sim.players[id]
	r.mode = LocalPlayer.Mode.WORLD
	r.ship = -1
	r.pos = at
	r.dead_until = -1.0
	r.hp = ServerSim.HEALTH
	return r


func _run(sim: ServerSim, seconds: float) -> void:
	for i in int(seconds / DT):
		sim.time += DT
		sim.world.tick(DT)


func _fell_all(sim: ServerSim) -> void:
	for sid in sim.world.raised:
		if sim.skeletons.has(sid) and sim.skeletons[sid].alive():
			sim._hurt_skeleton(sid, 1000, "a test")


func _chests(sim: ServerSim) -> int:
	var n := 0
	for it: Loot in sim.items.values():
		if it.kind == Loot.Kind.CHEST:
			n += 1
	return n


func _night(sim: ServerSim, night: bool) -> void:
	while StoryRun.is_night(sim.time) != night:
		sim.time += 30.0


func test_the_fort_only_once_someone_has_stormed_it() -> void:
	var sim := _sim()
	for i in 60:
		check(sim.world._pick() != WorldEvents.Kind.FORT, "not before Act II's finale")
	sim.players[1].profile.chapters.append("b6")
	var seen := false
	for i in 80:
		seen = seen or sim.world._pick() == WorldEvents.Kind.FORT
	check(seen, "once someone has stormed it")


func test_the_maw_only_at_night_after_the_story() -> void:
	var sim := _sim()
	_night(sim, true)
	for i in 60:
		check(sim.world._pick() != WorldEvents.Kind.MAW, "not before the story's end")
	sim.players[1].profile.chapters.append("e6")
	var seen := false
	for i in 80:
		seen = seen or sim.world._pick() == WorldEvents.Kind.MAW
	check(seen, "by night, once someone has finished it")
	_night(sim, false)
	for i in 60:
		check(sim.world._pick() != WorldEvents.Kind.MAW, "never by day")


func test_the_fort_guns_fire_and_can_be_silenced() -> void:
	var sim := _sim()
	sim.world.start(WorldEvents.Kind.FORT)
	var guns: Array[StoryObject] = []
	for oid in sim.world.objects:
		guns.append(sim.story.objects[oid])
	check_eq(guns.size(), 2, "two tower guns")
	check_eq(guns[0].kind, StoryObject.Kind.GUN)
	check_eq(guns[0].crew, 0, "nobody's in particular")
	var own: ShipState = sim.ships[ServerSim.CREW]
	own.x = guns[0].pos.x - 120.0
	own.z = guns[0].pos.z
	sim.time += 10.0
	var before := sim.projectiles.size()
	sim.story._fort_guns()
	check(sim.projectiles.size() > before, "they fire at a ship in range")
	sim.story.splash(guns[0].pos)
	sim.story.splash(guns[0].pos)
	check_eq(guns[0].state, 0, "two hits silence one")


func test_two_waves_then_the_vault() -> void:
	var sim := _sim()
	sim.world.start(WorldEvents.Kind.FORT)
	check_eq(sim.world.raised.size(), WorldEvents.FORT_SIZE, "a garrison in the courtyard")
	check(sim.skeletons[sim.world.raised[0]].spanish, "of the Spanish dead")
	var r := _ashore(sim, 1, Fort.centre() + Vector3(4.0, 0, 0))
	var xp: int = r.profile.xp
	var chests := _chests(sim)
	_fell_all(sim)
	_run(sim, 0.1)
	check_eq(sim.world.kind, WorldEvents.Kind.FORT, "not yet")
	check_eq(sim.world._standing(), WorldEvents.FORT_SIZE, "a second wave")
	_fell_all(sim)
	_run(sim, 0.1)
	check_eq(sim.world.kind, WorldEvents.Kind.NONE, "won")
	check_eq(_chests(sim) - chests, WorldEvents.FORT_CHESTS, "the vault's chests")
	check_eq(int(r.profile.xp) - xp, WorldEvents.FORT_XP, "XP for retaking it")
	check(sim.world.objects.is_empty() or not sim.story.objects.has(sim.world.objects[0]), "the guns are gone")


func test_the_garrison_that_holds_crumbles_away() -> void:
	var sim := _sim()
	sim.world.start(WorldEvents.Kind.FORT)
	_run(sim, WorldEvents.LIFETIME + 1.0)
	check_eq(sim.world.kind, WorldEvents.Kind.NONE, "over")
	check_eq(sim.stats.world_won, 0, "lost")
	check(not sim.skeletons[sim.world.raised[0]].alive(), "the garrison crumbles")


func test_the_maw_brings_a_giant_and_ghosts() -> void:
	var sim := _sim()
	sim.world.start(WorldEvents.Kind.MAW)
	var g := sim.world.giant()
	check(g != null and g.kind == StoryObject.Kind.COLOSSUS, "a giant in the Maw")
	check(Vector2(g.pos.x, g.pos.z).distance_to(Reef.CENTRE) < 1.0, "standing in the whirlpool")
	check_eq(sim.world.ships.size(), WorldEvents.MAW_GHOSTS, "ghosts at the Reef's edge")
	for id in sim.world.ships:
		check_eq(sim.ships[id].flag, 3, "ghost galleons")


func test_four_hits_break_a_joint_and_four_joints_fell_it() -> void:
	var sim := _sim()
	sim.add_player(2, "Bo", 2, "b")
	sim.world.start(WorldEvents.Kind.MAW)
	var g := sim.world.giant()
	var near := _ashore(sim, 1, Vector3(Reef.CENTRE.x + 120.0, 0, Reef.CENTRE.y))
	var far := _ashore(sim, 2, Vector3(Reef.CENTRE.x + 600.0, 0, Reef.CENTRE.y))
	var xp: int = near.profile.xp
	for i in WorldEvents.MAW_JOINT_HITS - 1:
		check(sim.world.projectile_hit(StoryAct5.joint_world(g, 0)), "a hit")
	check_eq(g.state & 1, 0, "three hits: still whole")
	sim.world.projectile_hit(StoryAct5.joint_world(g, 0))
	check_eq(g.state & 1, 1, "four: broken")
	check(not sim.world.projectile_hit(StoryAct5.joint_world(g, 0) + Vector3(0, 30, 0)), "a miss is a miss")
	for j in range(1, 4):
		for i in WorldEvents.MAW_JOINT_HITS:
			sim.world.projectile_hit(StoryAct5.joint_world(g, j))
	check(g.state & StoryAct5.KNEEL, "on its knees")
	var chests := _chests(sim)
	_run(sim, WorldEvents.MAW_FALL + 0.5)
	check_eq(sim.world.kind, WorldEvents.Kind.NONE, "won")
	check_eq(_chests(sim) - chests, 1, "a great chest comes up")
	check_eq(int(near.profile.xp) - xp, WorldEvents.MAW_XP, "XP for those who fought")
	check(near.profile.owned.has(WorldEvents.MAW_DYE), "and the Maw-green dye")
	check(not far.profile.owned.has(WorldEvents.MAW_DYE), "but not for those far off")
	check(sim.world.ships.all(func(id: int) -> bool: return not sim.ships.has(id)), "the ghosts go down with it")


func test_the_giant_attacks_the_nearest_ship() -> void:
	var sim := _sim()
	sim.world.start(WorldEvents.Kind.MAW)
	var own: ShipState = sim.ships[ServerSim.CREW]
	own.x = Reef.CENTRE.x + 80.0
	own.z = Reef.CENTRE.y
	var before := sim.projectiles.size()
	_run(sim, StoryAct5.ATTACK_EVERY + 0.5)
	check(sim.projectiles.size() > before or sim.stats.throws > 0, "wreckage thrown at the ship")


func test_dawn_sends_the_giant_back_down() -> void:
	var sim := _sim()
	sim.world.start(WorldEvents.Kind.MAW)
	_run(sim, WorldEvents.LIFETIME + 1.0)
	check_eq(sim.world.kind, WorldEvents.Kind.NONE, "over")
	check_eq(sim.stats.world_won, 0, "lost")
	check(sim.world.ships.all(func(id: int) -> bool: return not sim.ships.has(id)), "the ghosts go too")

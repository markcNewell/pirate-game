extends "res://tests/support/case.gd"
## Act IV of the story, chapter by chapter (docs/specs/2026-10-08-m11-the-drowned-fleet.md).

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


## Put Anne on another ship's deck at `local` (that ship's frame).
func _aboard(sim: ServerSim, ship: int, local: Vector3) -> Dictionary:
	var r: Dictionary = sim.players[1]
	r.mode = LocalPlayer.Mode.ON_SHIP
	r.ship = ship
	r.pos = local
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


## Move the crew's ship to a point on the sea.
func _sail_to(sim: ServerSim, at: Vector2) -> ShipState:
	var s: ShipState = sim.ships[ServerSim.CREW]
	s.x = at.x
	s.z = at.y
	return s


## A cannonball from `from_ship` holing `ship` below the waterline.
func _hole(sim: ServerSim, from_ship: int, ship: int) -> void:
	sim._hull_hit({"id": 1, "ship": from_ship}, ship, Vector3(1.5, 0.3, sim._rng.randf_range(-6.0, 6.0)), Vector3.ZERO)


## [yaw, pitch] for `r` to look from their eye at `at` (same frame).
func _look(r: Dictionary, at: Vector3) -> Array:
	var to: Vector3 = at - (r.pos + Vector3.UP * Weapons.EYE_HEIGHT)
	return [atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length())]


func test_act_four_waits_for_level_fourteen() -> void:
	check_eq(Story.chapter("d1").act, 4)
	check(Story.open_for(Story.index_of("d1"), [["c6"]]), "after the siege")
	check_eq(Progress.ACT_LEVEL[4], 14)


func test_the_reef_tears_without_the_chart() -> void:
	var sim := _sim("d3")
	var s := _sail_to(sim, Reef.CENTRE + Vector2(30, 0))
	s.holes.clear()
	_run(sim, Reef.TEAR_EVERY + 3.0)
	check(s.holes.size() >= 1, "the Reef's rocks tear the hull (%d)" % s.holes.size())
	s.holes.clear()
	sim.players[1].profile.chapters.append("d2")
	_run(sim, Reef.TEAR_EVERY * 2.0)
	check_eq(s.holes.size(), 0, "with the chart, the channel is safe")
	check(not Islands.mission_islands().has(Calavera.index() + 1), "no board missions to Isla Ceniza")
	check(Islands.mission_islands().has(Calavera.index()), "Isla Calavera has treasure like any island")


func test_the_hulk_guards_ring_the_alarm() -> void:
	var sim := _sim("d1")
	var m: Dictionary = sim.crews[1].mission
	var hulk: ShipState = sim.ships[m.ship]
	check_eq(hulk.flag, 5, "the prison hulk")
	check(not sim.captains.has(m.ship), "she does not sail or fight")
	var guards := 0
	for sk: Skeleton in sim.skeletons.values():
		if sk.guard:
			guards += 1
	check_eq(guards, 3, "three lantern guards")
	var ships_before := sim.ships.size()
	# Walk out in front of a guard.
	var g: Skeleton = null
	for sk: Skeleton in sim.skeletons.values():
		if sk.guard:
			g = sk
	var ahead := Vector3(-sin(g.yaw), 0, -cos(g.yaw))
	_aboard(sim, m.ship, g.pos + ahead * 3.0)
	_run(sim, 0.2)
	check(m.alarm, "seen: the alarm")
	check_eq(sim.stats.alarms, 1)
	check_eq(sim.ships.size(), ships_before + StoryAct4.ALARM_SHIPS, "two skeleton ships come")


func test_the_hulk_sneak_free_isabel_and_ferry() -> void:
	var sim := _sim("d1")
	var m: Dictionary = sim.crews[1].mission
	# Behind the guards, up to the stern: the jailer falls.
	sim._hurt_skeleton(m.captain, 9999, "Anne", 1)
	check(not m.alarm, "quietly")
	check_eq(m.step, 1, "the keys: the cage")
	var cage := _first(sim, StoryObject.Kind.CAGE)
	check(cage != null and cage.ship == m.ship, "a cage on the hulk's deck")
	_aboard(sim, m.ship, cage.pos + Vector3(1.0, 0, 0))
	sim.request(1, "use", cage.id, [])
	check_eq(m.step, 2, "Isabel is out")
	var isabel := _first(sim, StoryObject.Kind.ISABEL)
	check_eq(isabel.ship, ServerSim.CREW, "aboard our ship")
	var merrow := Outpost.spec()
	_sail_to(sim, Vector2(merrow.x + 40.0, merrow.z))
	_run(sim, 0.5)
	check(sim.crews[1].mission.is_empty(), "home to Merrow")


func test_the_pilots_chart() -> void:
	var sim := _sim("d2")
	var m: Dictionary = sim.crews[1].mission
	var eye := _first(sim, StoryObject.Kind.CARVING)
	check(eye != null and eye.pos.distance_to(Calavera.eye(-1)) < 0.5, "a carving before the left eye")
	_ashore(sim, eye.pos)
	sim.request(1, "read", eye.id, [])
	check_eq(m.step, 1)
	var tooth := _first(sim, StoryObject.Kind.CARVING)
	check(tooth.pos.distance_to(Calavera.tooth(2)) < 2.0, "then the third tooth-stone")
	_ashore(sim, tooth.pos)
	sim.request(1, "read", tooth.id, [])
	check_eq(m.step, 2, "the grave")
	var chart: Loot = sim.items[m.items[0]]
	check_eq(chart.state, Loot.State.BURIED, "the chart is buried")
	var r := _ashore(sim, Calavera.grave())
	for i in 200:
		sim.time += 0.2
		sim.request(1, "dig", 0, [])
		if chart.state != Loot.State.BURIED:
			break
	check_eq(chart.state, Loot.State.GROUND, "dug up")
	check(sim.story.standing(m) >= 3, "the pilot and two of his crew climb out (%d)" % sim.story.standing(m))
	sim.request(1, "pickup", chart.id, [])
	r.pos = Story.person_pos("isabel")
	sim.request(1, "give", 0, [])
	check(sim.crews[1].mission.is_empty(), "Isabel has the channel")


func test_ghost_lights_rise_in_the_storm() -> void:
	var sim := _sim("d3")
	var m: Dictionary = sim.crews[1].mission
	_run(sim, 1.0)
	check_eq(m.ship, -1, "no ghost in calm seas")
	Storm.enabled = true
	var own: ShipState = sim.ships[ServerSim.CREW]
	Storm.pin = Vector2(own.x, own.z)
	_run(sim, 0.2)
	Storm.pin = Vector2.INF
	Storm.enabled = false
	check(m.ship >= 0, "a ghost galleon rises")
	var ghost: ShipState = sim.ships[m.ship]
	check_eq(ghost.flag, 3)
	check(ghost.sink < 0.0, "still under the water")
	_run(sim, StoryAct4.GHOST_RISE + 0.5)
	check_eq(ghost.sink, 0.0, "risen")
	check(not sim._passive.has(m.ship), "and fighting")
	ghost.sink = 0.01
	sim._handle_sinking()
	check(sim.crews[1].mission.is_empty(), "sunk again")


func test_lanterns_of_the_deep_and_the_clock() -> void:
	var sim := _sim("d4")
	var m: Dictionary = sim.crews[1].mission
	var lanterns: Array[StoryObject] = []
	for o: StoryObject in sim.story.objects.values():
		if o.kind == StoryObject.Kind.GLANTERN:
			lanterns.append(o)
	check_eq(lanterns.size(), 3, "a lantern on each stack")
	check_eq(sim.story.standing(m), 9, "three guards each")
	sim.story.act4.strike_lantern(lanterns[0].id)
	check_eq(lanterns[0].state, StoryAct4.LANTERN_HITS - 1)
	sim.time = m.deadline + 0.1
	sim.story.tick(DT)
	check_eq(lanterns[0].state, StoryAct4.LANTERN_HITS, "too slow: relit")
	# A pistol shot at a lantern's head counts.
	var spec: Dictionary = Islands.LAYOUT[7]
	var r := _ashore(sim, lanterns[0].pos + Vector3(5, 0, 0))
	r.weapon = Weapons.Kind.PISTOL
	r.next_attack = 0.0
	sim.request(1, "attack", 0, _look(r, lanterns[0].pos + Vector3(0, 3.6, 0)))
	check_eq(lanterns[0].state, StoryAct4.LANTERN_HITS - 1, "shot (%s)" % spec.name)
	for o in lanterns:
		while o.state > 0:
			sim.story.act4.strike_lantern(o.id)
	check(sim.crews[1].mission.is_empty(), "all three smashed")


func test_the_merchants_gambit() -> void:
	var sim := _sim("d5")
	var m: Dictionary = sim.crews[1].mission
	_run(sim, 0.5)
	check_eq(int(m.stage), 0, "waiting for the bait")
	_sail_to(sim, Reef.CENTRE + Vector2(-350, 0))
	_run(sim, 0.1)
	check_eq(int(m.stage), 1, "she comes out")
	var flag: ShipState = sim.ships[m.ship]
	check_eq(flag.flag, 2, "the Cuervo Negro")
	# Run to the ambush with her following.
	_sail_to(sim, StoryAct4.AMBUSH + Vector2(10, 0))
	flag.x = StoryAct4.AMBUSH.x + 150.0
	flag.z = StoryAct4.AMBUSH.y
	_run(sim, 0.1)
	check_eq(int(m.stage), 2, "Isabel's ambush")
	var ally: int = m.ships[0]
	check_eq(sim.ships[ally].flag, 4, "La Golondrina")
	# Her shots never hole us; ours never hole her.
	var own: ShipState = sim.ships[ServerSim.CREW]
	own.holes.clear()
	_hole(sim, ally, ServerSim.CREW)
	check_eq(own.holes.size(), 0, "no friendly fire from her")
	_hole(sim, ServerSim.CREW, ally)
	check_eq(sim.ships[ally].holes.size(), 0, "nor at her")
	check(sim._nearest_enemy_ship(sim.ships[ally]) == flag, "she goes for the flagship")
	for i in 10:
		_hole(sim, ServerSim.CREW, m.ship)
	check(sim.crews[1].mission.is_empty(), "holed ten times, the flagship runs")
	check(sim.captains[m.ship].fleeing, "for the Reef")


func test_the_flagship_cannot_be_holed_outside_a_fight() -> void:
	var sim := _sim("d1")
	var id := sim.spawn_galleon(ServerSim.CREW, 200.0, 2)
	_hole(sim, ServerSim.CREW, id)
	check_eq(sim.ships[id].holes.size(), 0, "the Cuervo Negro shrugs it off")


func test_the_battle_of_the_black_reef() -> void:
	var sim := _sim("d6")
	sim.add_player(2, "Bart", 2, "b")
	var m: Dictionary = sim.crews[1].mission
	sim.players[1].profile.chapters.append("d2")  # no tearing on the rocks
	_sail_to(sim, Reef.CENTRE + Vector2(-200, 0))
	_run(sim, StoryAct4.RISE_EVERY * 2.0 + 1.0)
	check_eq(int(m.wave), 3, "three galleons rise, one after another")
	for id: int in m.ships.duplicate():
		sim.ships[id].sink = 0.01
	sim._handle_sinking()
	_run(sim, 0.1)
	check_eq(m.step, 1, "the risen fleet sunk: the flagship")
	var flag: ShipState = sim.ships[m.ship]
	check_eq(flag.flag, 2)
	for i in 14:
		_hole(sim, ServerSim.CREW, m.ship)
	check_eq(m.step, 2, "crippled: board her")
	check(not sim.captains.has(m.ship), "dead in the water")
	check_eq(flag.speed, 0.0)
	var admiral: Skeleton = sim.skeletons[m.captain]
	check(admiral.admiral and admiral.frame == m.ship, "the Raven Admiral on her quarterdeck")
	check_eq(sim.story.standing(m), 4, "with four marines")
	# A blade from the front is parried; from behind it lands.
	var front := admiral.pos + Vector3(-sin(admiral.yaw), 0, -cos(admiral.yaw)) * 1.3
	var r := _aboard(sim, m.ship, front)
	r.weapon = Weapons.Kind.CUTLASS
	r.next_attack = 0.0
	sim.request(1, "attack", 0, _look(r, admiral.pos + Vector3(0, 1.0, 0)))
	check_eq(admiral.hp, StoryAct4.ADMIRAL_HEALTH, "parried")
	check_eq(sim.stats.parried, 1)
	r.pos = admiral.pos - Vector3(-sin(admiral.yaw), 0, -cos(admiral.yaw)) * 1.3
	r.next_attack = 0.0
	sim.request(1, "attack", 0, _look(r, admiral.pos + Vector3(0, 1.0, 0)))
	check(admiral.hp < StoryAct4.ADMIRAL_HEALTH, "from behind it lands")
	# He lunges at whoever is close.
	r.pos = admiral.pos + Vector3(0, 0, -3.0)
	admiral.next_lunge = 0.0
	var hp_before: int = r.hp
	_run(sim, StoryAct4.LUNGE_WARN + 1.0)
	check(sim.stats.lunges >= 1, "he lunges")
	check(r.hp < hp_before or r.dead_until >= 0.0, "and the rapier finds us")
	# Bart, of another crew, is near the Reef for the end.
	var bart: Dictionary = sim.players[2]
	bart.mode = LocalPlayer.Mode.ON_SHIP
	bart.ship = 2
	sim.ships[2].x = Reef.CENTRE.x - 100.0
	sim.ships[2].z = Reef.CENTRE.y
	sim._hurt_skeleton(admiral.id, 9999, "Anne", 1)
	check(sim.crews[1].mission.is_empty(), "the Admiral is beaten")
	check_eq(sim.players[1].profile.title, "Raven-Breaker")
	check_eq(int(sim.players[2].profile.gold), StoryAct4.SHARED_GOLD, "Bart shares the battle")
	check(flag.sink > 0.0, "the Cuervo Negro goes down")

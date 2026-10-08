class_name StoryAct4
extends RefCounted
## Act IV's steps (docs/specs/2026-10-08-m11-the-drowned-fleet.md), run for StoryRun: the prison
## hulk and its lantern guards, Isla Calavera's riddle, ghost galleons, the lanterns of the deep,
## the merchant's gambit, and the Battle of the Black Reef with the Raven Admiral.

## Lantern guards see a pirate on the hulk's deck this near, within this angle of straight ahead.
const GUARD_SIGHT := 9.0
const GUARD_ARC := 0.87
const GUARD_SPEED := 1.3
## The guards' loop round the hulk's forward deck, about Isabel's cage (ship frame); the jailer
## keeps the quarterdeck, where the rope from her stern comes up out of the guards' sight.
const PATROL: Array[Vector3] = [
	Vector3(-1.9, ShipShape.DECK_Y, -9.0), Vector3(1.9, ShipShape.DECK_Y, -9.0),
	Vector3(1.9, ShipShape.DECK_Y, -3.5), Vector3(-1.9, ShipShape.DECK_Y, -3.5),
]
const JAILER_AT := Vector3(0.0, ShipShape.QUARTER_Y, 8.5)
const JAILER_HEALTH := 160
const CAGE_AT := Vector3(0.0, ShipShape.DECK_Y, -6.3)
const ALARM_SHIPS := 2
## A ghost galleon rises from this far down (as ShipState.sink) over GHOST_RISE seconds.
const GHOST_DEPTH := -0.75
const GHOST_RISE := 8.0
## Each lantern of the deep takes this many hits.
const LANTERN_HITS := 3
## The gambit: the flagship comes out when you sail this near the Reef; Isabel waits here.
const BAIT_RANGE := 400.0
const AMBUSH := Vector2(430.0, 380.0)
const AMBUSH_REACH := 60.0
const FOLLOW_RANGE := 300.0
## The battle: the dead rise once a crew is this near the Reef, one galleon every RISE_EVERY s.
const BATTLE_RANGE := 260.0
const RISE_EVERY := 25.0
## The Raven Admiral: parries blades from within this angle of his front; lunges every
## LUNGE_EVERY s at a pirate within LUNGE_RANGE, after LUNGE_WARN s, LUNGE_DASH metres.
const ADMIRAL_HEALTH := 400
const PARRY_ARC := 1.05
const LUNGE_EVERY := 5.0
const LUNGE_RANGE := 6.0
const LUNGE_WARN := 0.5
const LUNGE_DASH := 3.5
const LUNGE_SPEED := 9.0
const LUNGE_DAMAGE := 40
## Everyone this near the Reef when the Admiral falls shares the battle's reward.
const SHARED_REACH := 300.0
const SHARED_XP := 400
const SHARED_GOLD := 200

var story: StoryRun
var sim: ServerSim
## Flagship hit counter (ship id -> holes made) and when allies sail home (ship id -> time).
var _holes_made := {}
var _ally_until := {}
## When the Reef's rocks next tear each crew ship in its heart (crew -> time).
var _teeth := {}


func _init(run: StoryRun) -> void:
	story = run
	sim = run.sim


# --- entering steps ---------------------------------------------------------------------

func enter(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	m.stage = 0
	match int(step.kind):
		Story.Step.HULK:
			_enter_hulk(crew, step)
		Story.Step.GHOST:
			m.islands = []
			m.ship = -1
			sim._tell_crew(crew, "Find the storm. The ghost will find you.")
		Story.Step.LANTERNS:
			_enter_lanterns(crew, step)
		Story.Step.GAMBIT:
			m.islands = [Fort.index()]
			m.ship = -1
			m.left = int(step.holes)
			sim._tell_crew(crew, "Sail close to the Black Reef. Look rich.")
		Story.Step.RISEN:
			m.islands = []
			m.ships = []
			m.wave = 0
			sim._tell_crew(crew, "To the Black Reef! The drowned fleet is rising.")
		Story.Step.CRIPPLE:
			_enter_cripple(crew, step)
		Story.Step.ADMIRAL:
			_enter_admiral(crew, step)


## The prison hulk at anchor in the fog: no masts to speak of, three lantern guards walking her
## deck, the jailer at her stern, and Isabel in a cage amidships.
func _enter_hulk(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	m.islands = [_nearest_island(StoryRun.HULK_FOG)]
	var id: int = sim.spawn_galleon(crew, 0.0, 5, Vector3(StoryRun.HULK_FOG.x, 0, StoryRun.HULK_FOG.y))
	var hulk: ShipState = sim.ships[id]
	hulk.anchored = true
	hulk.speed = 0.0
	hulk.sail_height = [0.0, 0.0]
	hulk.yaw = 0.4
	sim.captains.erase(id)
	sim._passive[id] = true
	for sid in sim.skeletons.keys():
		if sim.skeletons[sid].frame == id:
			sim.skeletons.erase(sid)
	m.ship = id
	m.alarm = false
	for n in int(step.guards):
		var g := sim._new_skeleton(id, PATROL[n % PATROL.size()])
		g.spanish = true
		g.guard = true
		g.patrol = n % PATROL.size()
		g.story_crew = crew
		m.raised.append(g.id)
	var jailer := sim._new_skeleton(id, JAILER_AT)
	jailer.spanish = true
	jailer.jailer = true
	jailer.hp = JAILER_HEALTH
	jailer.story_crew = crew
	m.captain = jailer.id
	var cage := story._add_object(crew, StoryObject.Kind.CAGE, CAGE_AT, 0.0)
	cage.ship = id
	var isabel := story._add_object(crew, StoryObject.Kind.ISABEL, CAGE_AT, PI)
	isabel.ship = id
	print("[server] crew %d: the prison hulk lies in the fog off Isla Ceniza" % crew)


func _enter_lanterns(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	m.islands = step.islands.duplicate()
	for island: int in step.islands:
		var spec: Dictionary = Islands.LAYOUT[island]
		var top := Vector3(spec.x, IslandMesh.ground(spec, 0.0, 0.0), spec.z)
		story._add_object(crew, StoryObject.Kind.GLANTERN, top, sim._rng.randf() * TAU).state = LANTERN_HITS
		for n in int(step.garrison):
			var a := TAU * n / float(step.garrison)
			var at := top + Vector3(cos(a), 0, sin(a)) * 3.0
			story._spanish_at(crew, island, at)
	m.deadline = sim.time + float(step.time)
	sim._tell_crew(crew, "Three green lanterns burn on the Reef's stacks. Smash them all!")


func _enter_cripple(crew: int, _step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	m.islands = []
	var own: ShipState = sim.ships.get(crew)
	var at := Vector3(Reef.CENTRE.x, 0, Reef.CENTRE.y)
	if own:
		var to := (Reef.CENTRE - Vector2(own.x, own.z)).normalized()
		at = Vector3(own.x + to.x * 180.0, 0, own.z + to.y * 180.0)
	var id: int = sim.spawn_galleon(crew, 0.0, 2, at)
	sim.captains[id].bail_scale = 0.6
	m.ship = id
	m.left = int(_step_of(m).holes)
	_holes_made[id] = 0
	sim._tell_crew(crew, "The Cuervo Negro comes out of the storm. Break her!")


## On the crippled flagship's quarterdeck: the Raven Admiral and his marines.
func _enter_admiral(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	if not sim.ships.has(m.ship):
		# Started here (tests, screenshots): the flagship already broken, off the crew's bow.
		var own: ShipState = sim.ships.get(crew)
		var at := Vector3(own.x + 40.0, 0, own.z) if own else Vector3(Reef.CENTRE.x, 0, Reef.CENTRE.y)
		m.ship = sim.spawn_galleon(crew, 0.0, 2, at)
		cripple(m.ship)
	var id: int = m.ship
	var admiral := sim._new_skeleton(id, Vector3(0.0, ShipShape.QUARTER_Y, 7.5))
	admiral.admiral = true
	admiral.spanish = true
	admiral.hp = ADMIRAL_HEALTH
	admiral.damage = 30
	admiral.story_crew = crew
	admiral.next_lunge = sim.time + LUNGE_EVERY
	m.captain = admiral.id
	var spots: Array[Vector3] = [
		Vector3(-1.6, ShipShape.QUARTER_Y, 6.0), Vector3(1.6, ShipShape.QUARTER_Y, 6.0),
		Vector3(-1.5, ShipShape.DECK_Y, 0.0), Vector3(1.5, ShipShape.DECK_Y, 0.0),
	]
	for n in int(step.marines):
		var marine := sim._new_skeleton(id, spots[n % spots.size()])
		marine.spanish = true
		marine.story_crew = crew
		m.raised.append(marine.id)
	print("[server] crew %d: the Raven Admiral waits on his quarterdeck" % crew)
	sim._tell_crew(crew, "She's dead in the water! Board her: the Admiral is on the quarterdeck.")


# --- every tick ---------------------------------------------------------------------------

func tick(dt: float) -> void:
	_rise_ghosts(dt)
	_send_allies_home()
	_reef_teeth()
	for c in sim.crews.keys():
		var m := story._mission_of(c)
		if m.is_empty():
			continue
		var step := story._step(m)
		match int(step.kind):
			Story.Step.GHOST:
				_ghost_tick(c, m)
			Story.Step.LANTERNS:
				_lanterns_tick(c, m, step)
			Story.Step.GAMBIT:
				_gambit_tick(c, m)
			Story.Step.RISEN:
				_risen_tick(c, m, step)


## Ghost galleons coming up out of the sea: rising, then fighting.
func _rise_ghosts(dt: float) -> void:
	for id in sim.ships:
		var s: ShipState = sim.ships[id]
		if s.flag != 3 or s.sink >= 0.0:
			continue
		s.sink = minf(0.0, s.sink - GHOST_DEPTH * dt / GHOST_RISE)
		if s.sink >= 0.0:
			sim._passive.erase(id)


## The Black Reef's rocks: a crew ship in its heart takes a hole every Reef.TEAR_EVERY s,
## unless someone aboard has the pilot's chart (chapter d2).
func _reef_teeth() -> void:
	for c in sim.crews:
		var s: ShipState = sim.ships.get(c)
		if s == null or s.is_sinking() or not Reef.in_heart(Vector2(s.x, s.z)) or has_chart(c):
			_teeth.erase(c)
			continue
		if not _teeth.has(c):
			_teeth[c] = sim.time + 2.0
			sim._tell_crew(c, "Rocks under the keel! Without the pilot's chart the Reef will tear us apart!")
			continue
		if sim.time < float(_teeth[c]):
			continue
		_teeth[c] = sim.time + Reef.TEAR_EVERY
		if s.holes.size() < ServerSim.MAX_HOLES:
			var side := 1.0 if sim._rng.randf() < 0.5 else -1.0
			var h := ShipShape.hole_point(Vector3(side, 0.0, sim._rng.randf_range(-8.0, 8.0)))
			s.holes.append([s.next_hole_id, h.x, h.y, h.z, 0.0])
			s.next_hole_id += 1
		sim.stats.reef_tears += 1
		sim._tell_crew(c, "The Reef tears at the hull! Water on the lower deck!")


## Has anyone aboard this crew's ship finished The Pilot's Chart?
func has_chart(crew: int) -> bool:
	for id in sim._crew_members(crew):
		if sim.players[id].profile.chapters.has("d2"):
			return true
	return false


func _send_allies_home() -> void:
	for id in _ally_until.keys():
		if sim.time >= float(_ally_until[id]) and sim.ships.has(id):
			sim.ships.erase(id)
			sim.captains.erase(id)
			_ally_until.erase(id)


## A ghost galleon, rising beside a crew ship in a storm.
func spawn_ghost(crew: int, near: ShipState, distance: float) -> int:
	var a := sim._rng.randf() * TAU
	var at := Vector3(near.x + cos(a) * distance, 0, near.z + sin(a) * distance)
	var id: int = sim.spawn_galleon(crew, 0.0, 3, at)
	var g: ShipState = sim.ships[id]
	g.sink = GHOST_DEPTH
	g.speed = 0.0
	sim.captains[id].bail_scale = 1.5
	sim._passive[id] = true
	Net.send_event("ghost", [id])
	print("[server] a ghost galleon rises at (%.0f, %.0f)" % [at.x, at.z])
	return id


func _ghost_tick(crew: int, m: Dictionary) -> void:
	if m.ship >= 0:
		return
	var own: ShipState = sim.ships.get(crew)
	if own == null or own.is_sinking() or Storm.amount(Vector2(own.x, own.z), sim.time) < 0.5:
		return
	m.ship = spawn_ghost(crew, own, 90.0)
	sim._tell_crew(crew, "Green lights under the water... A ghost galleon is rising!")


func _lanterns_tick(crew: int, m: Dictionary, step: Dictionary) -> void:
	if m.deadline < 0.0 or sim.time < m.deadline:
		return
	# Too slow: the storm closes, and Ocaso's men light them again.
	for oid: int in m.objects:
		var o: StoryObject = story.objects.get(oid)
		if o and o.kind == StoryObject.Kind.GLANTERN and o.state != LANTERN_HITS:
			o.state = LANTERN_HITS
			Net.send_event("lantern_hit", [o.id, o.state])
	m.deadline = sim.time + float(step.time)
	print("[server] crew %d: the lanterns of the deep burn again" % crew)
	sim._tell_crew(crew, "Too slow! The lanterns burn again. Twelve more minutes.")


func lanterns_left(m: Dictionary) -> int:
	var n := 0
	for oid: int in m.objects:
		var o: StoryObject = story.objects.get(oid)
		if o and o.kind == StoryObject.Kind.GLANTERN and o.state > 0:
			n += 1
	return n


## The lanterns of the deep still burning: [object id, world point], for weapons to aim at.
func lanterns() -> Array:
	var out := []
	for id in story.objects:
		var o: StoryObject = story.objects[id]
		if o.kind == StoryObject.Kind.GLANTERN and o.state > 0:
			out.append([o.id, o.pos])
	return out


func strike_lantern(oid: int) -> void:
	var o: StoryObject = story.objects.get(oid)
	if o == null or o.state <= 0:
		return
	o.state -= 1
	Net.send_event("lantern_hit", [o.id, o.state])
	if o.state > 0:
		return
	sim.stats.lanterns_smashed += 1
	print("[server] a lantern of the deep was smashed")
	sim._tell_crew(o.crew, "A lantern of the deep shatters!")
	var m := story._mission_of(o.crew)
	if not m.is_empty() and int(story._step(m).kind) == Story.Step.LANTERNS and lanterns_left(m) == 0:
		m.deadline = -1.0
		for pid in sim._crew_members(o.crew):
			story._say(pid, story._step(m).get("lines", []))
		story._next_step(o.crew)


## The bait: out comes the flagship; run to the ambush; Isabel's ship joins in.
func _gambit_tick(crew: int, m: Dictionary) -> void:
	var own: ShipState = sim.ships.get(crew)
	if own == null or own.is_sinking():
		return
	var pos := Vector2(own.x, own.z)
	match int(m.stage):
		0:
			if pos.distance_to(Reef.CENTRE) > BAIT_RANGE:
				return
			var to := (Reef.CENTRE - pos).normalized()
			var id: int = sim.spawn_galleon(crew, 0.0, 2, Vector3(own.x + to.x * 200.0, 0, own.z + to.y * 200.0))
			sim.captains[id].reload_scale = 1.6
			_holes_made[id] = 0
			m.ship = id
			m.stage = 1
			print("[server] crew %d: the Cuervo Negro takes the bait" % crew)
			sim._tell_crew(crew, "The Cuervo Negro! She's taken the bait. Run for the fort!")
		1:
			if not sim.ships.has(m.ship):
				return
			var flag: ShipState = sim.ships[m.ship]
			if pos.distance_to(AMBUSH) > AMBUSH_REACH or pos.distance_to(Vector2(flag.x, flag.z)) > FOLLOW_RANGE:
				return
			var ally: int = sim.spawn_galleon(crew, 0.0, 4, Vector3(AMBUSH.x + 60.0, 0, AMBUSH.y - 50.0))
			for sid in sim.skeletons.keys():
				if sim.skeletons[sid].frame == ally:
					sim.skeletons.erase(sid)
			m.ships = [ally]
			m.stage = 2
			print("[server] crew %d sprang Isabel's ambush" % crew)
			sim._tell_crew(crew, "La Golondrina comes out from behind the fort, guns run out! Hole the Cuervo Negro!")


func _risen_tick(crew: int, m: Dictionary, step: Dictionary) -> void:
	var own: ShipState = sim.ships.get(crew)
	if own == null:
		return
	if int(m.wave) < int(step.galleons):
		if m.wave == 0 and Vector2(own.x, own.z).distance_to(Reef.CENTRE) > BATTLE_RANGE:
			return
		if sim.time < m.next_rise:
			return
		m.ships.append(spawn_ghost(crew, own, 110.0 + 20.0 * m.wave))
		m.wave += 1
		m.next_rise = sim.time + RISE_EVERY
		sim._tell_crew(crew, "A drowned galleon breaks the surface! (%d of %d)" % [m.wave, int(step.galleons)])
		return
	if m.ships.is_empty():
		print("[server] crew %d sank the risen fleet" % crew)
		story._next_step(crew)


# --- hooks from ServerSim and StoryRun -------------------------------------------------------

## A ship went down: a ghost of the GHOST step, or one of the risen fleet.
func on_ship_sunk(c: int, m: Dictionary, step: Dictionary, ship_id: int) -> bool:
	match int(step.kind):
		Story.Step.GHOST:
			if m.ship == ship_id:
				print("[server] crew %d sank the ghost galleon" % c)
				m.ship = -1
				for pid in sim._crew_members(c):
					story._say(pid, step.get("lines", []))
				story._next_step(c)
				return true
		Story.Step.RISEN:
			if m.ships.has(ship_id):
				m.ships.erase(ship_id)
				print("[server] a risen galleon went down (%d up)" % m.ships.size())
				return true
		Story.Step.HULK, Story.Step.USE:
			if m.ship == ship_id:
				# The hulk went down with Isabel in her: the step begins again.
				sim._tell_crew(c, "The hulk is sinking with Isabel aboard! Moll swears; another hulk is found...")
				story._clear_step(m)
				story._enter_step(c)
				return true
	return false


## A new hole in a ship. The flagship can only be holed while a chapter is fighting her.
func flagship_holeable(ship_id: int) -> bool:
	for c in sim.crews:
		var m := story._mission_of(c)
		if m.is_empty() or m.ship != ship_id:
			continue
		var kind := int(story._step(m).kind)
		if kind == Story.Step.GAMBIT and int(m.stage) >= 1 or kind == Story.Step.CRIPPLE:
			return true
	return false


## The flagship may only go down at the very end of the battle.
func flagship_may_sink(ship_id: int) -> bool:
	return _holes_made.get(ship_id, 0) < 0


func on_hole(ship_id: int) -> void:
	if not _holes_made.has(ship_id):
		return
	_holes_made[ship_id] += 1
	for c in sim.crews:
		var m := story._mission_of(c)
		if m.is_empty() or m.ship != ship_id:
			continue
		var step := story._step(m)
		match int(step.kind):
			Story.Step.GAMBIT:
				if int(m.stage) < 2:
					return
				m.left = int(m.left) - 1
				if m.left > 0:
					return
				# Holed like a sieve: she runs for the Reef, and Isabel heads home.
				sim.captains[ship_id].fleeing = true
				sim.captains[ship_id].reload_scale = 3.0
				for ally: int in m.ships:
					_ally_until[ally] = sim.time + 60.0
				print("[server] crew %d: the Cuervo Negro flees into the Reef" % c)
				for pid in sim._crew_members(c):
					story._say(pid, step.get("lines", []))
				story._next_step(c)
			Story.Step.CRIPPLE:
				m.left = int(m.left) - 1
				if m.left > 0:
					return
				cripple(ship_id)
				print("[server] crew %d crippled the Cuervo Negro" % c)
				story._next_step(c)


## Dead in the water: no captain, no sails, no more sinking.
func cripple(ship_id: int) -> void:
	var s: ShipState = sim.ships[ship_id]
	sim.captains.erase(ship_id)
	sim._passive[ship_id] = true
	s.anchored = true
	s.speed = 0.0
	s.sail_height = [0.0, 0.0]
	s.holes.clear()
	s.water = 0.0
	Net.send_event("crippled", [ship_id])


## The Admiral has fallen: over the side he goes, and his ship follows him down.
func on_admiral_fell(m: Dictionary) -> void:
	if not sim.ships.has(m.ship):
		return
	_holes_made[m.ship] = -1
	sim.ships[m.ship].sink = 1e-3
	Net.send_message(0, "The Raven Admiral goes over the side, and the Cuervo Negro follows him down!")


## Isla Calavera's grave dug open: the pilot climbs out with two of his drowned crew.
func on_dug(item: Loot) -> void:
	if item.kind != Loot.Kind.CHART:
		return
	for c in sim.crews:
		var m := story._mission_of(c)
		if m.is_empty() or not m.items.has(item.id):
			continue
		var island := Calavera.index()
		var pilot := story._raise_captain(c, island)
		pilot.pos = item.pos + Vector3(2.0, 0, 1.0)
		pilot.pos.y = Islands.ground_at(island, pilot.pos.x, pilot.pos.z)
		for n in 2:
			var dead := sim._new_skeleton(-1, item.pos + Vector3(-2.0 + 4.0 * n, 0, -1.5))
			dead.pos.y = Islands.ground_at(island, dead.pos.x, dead.pos.z)
			dead.story_crew = c
			m.raised.append(dead.id)
		Net.send_event("risen", [item.pos.x, item.pos.y, item.pos.z])
		sim._tell_crew(c, "The grave heaves: Mateo Brisa climbs out, and he bites!")
		print("[server] crew %d woke the pilot" % c)


## The pilot's chart, buried in his grave on Isla Calavera (GATHER, where "grave").
func bury_chart(crew: int) -> Loot:
	var at := Calavera.grave()
	var chart := sim._new_item(Loot.Kind.CHART, Loot.State.BURIED, at - Vector3(0, 0.4, 0), 0)
	sim.crews[crew].mission.items.append(chart.id)
	return chart


# --- the guards and the Admiral ------------------------------------------------------------

## A lantern guard walks his loop of the hulk's deck until he sees someone, then rings the alarm.
## True while he is on his rounds (ServerSim leaves him be); false once he fights.
func step_guard(sk: Skeleton, dt: float) -> bool:
	var m := story._mission_of(sk.story_crew)
	if m.is_empty() or m.get("alarm", true) or int(story._step(m).kind) != Story.Step.HULK:
		return false
	var goal: Vector3 = PATROL[sk.patrol]
	var to := goal - sk.pos
	if Vector2(to.x, to.z).length() < 0.3:
		sk.patrol = (sk.patrol + 1) % PATROL.size()
	else:
		var step := Vector3(to.x, 0, to.z).normalized() * minf(GUARD_SPEED * dt, Vector2(to.x, to.z).length())
		sk.pos += step
		sk.yaw = atan2(-to.x, -to.z)
		sk.walking = true
	for id in sim.players:
		var r: Dictionary = sim.players[id]
		if r.dead_until >= 0.0 or r.mode != LocalPlayer.Mode.ON_SHIP or r.ship != sk.frame:
			continue
		var off := Vector2(r.pos.x - sk.pos.x, r.pos.z - sk.pos.z)
		if off.length() < GUARD_SIGHT and Vector2(-sin(sk.yaw), -cos(sk.yaw)).dot(off.normalized()) > cos(GUARD_ARC):
			raise_alarm(sk.story_crew, r.name)
			return false
	return true


## A guard saw someone (or was struck): the bell, and two skeleton ships out of the fog.
func raise_alarm(crew: int, seen: String) -> void:
	var m := story._mission_of(crew)
	if m.is_empty() or m.get("alarm", true):
		return
	m.alarm = true
	sim.stats.alarms += 1
	print("[server] a lantern guard saw %s: the alarm!" % seen)
	Net.send_event("alarm", [])
	sim._tell_crew(crew, "The alarm bell! Skeleton ships are coming out of the fog!")
	var hulk: ShipState = sim.ships.get(m.ship)
	for n in ALARM_SHIPS:
		var a := sim._rng.randf() * TAU
		var at := Vector3(hulk.x + cos(a) * 250.0, 0, hulk.z + sin(a) * 250.0) if hulk else Vector3.INF
		sim.spawn_galleon(crew, 250.0, 0, at)


## The Admiral's turn: draw back, then lunge at a pirate close by. True while lunging (ServerSim
## leaves him be).
func step_admiral(sk: Skeleton, dt: float) -> bool:
	if sk.lunge_at >= 0.0:
		if sim.time < sk.lunge_at:
			return true
		var travel := minf(LUNGE_SPEED * dt, sk.lunge_left)
		sk.pos += sk.lunge_dir * travel
		sk.lunge_left -= travel
		for id in sim.players:
			var r: Dictionary = sim.players[id]
			if r.dead_until < 0.0 and _same_frame(r, sk) and sim._pos_in_frame(r, sk.frame).distance_to(sk.pos) < 1.2 and id == sk.lunge_target:
				sim._hurt_player(id, LUNGE_DAMAGE, "the Raven Admiral's rapier", -1, Weapons.Hit.BLADE)
				sk.lunge_left = 0.0
		if sk.lunge_left <= 0.0:
			sk.lunge_at = -1.0
			sk.next_lunge = sim.time + (StoryAct5.ASH_LUNGE_EVERY if sk.ash else LUNGE_EVERY)
		return true
	if sim.time < sk.next_lunge:
		return false
	for id in sim.players:
		var r: Dictionary = sim.players[id]
		if r.dead_until >= 0.0 or not _same_frame(r, sk):
			continue
		var off: Vector3 = sim._pos_in_frame(r, sk.frame) - sk.pos
		if off.length() < LUNGE_RANGE:
			sk.lunge_dir = Vector3(off.x, 0, off.z).normalized()
			sk.lunge_left = LUNGE_DASH
			sk.lunge_at = sim.time + LUNGE_WARN
			sk.lunge_target = id
			sk.yaw = atan2(-off.x, -off.z)
			sim.stats.lunges += 1
			Net.send_event("lunge", [sk.id])
			return true
	return false


## Is this pirate where the Admiral stands: on his deck, or (the Ash Admiral) ashore?
static func _same_frame(r: Dictionary, sk: Skeleton) -> bool:
	if sk.frame >= 0:
		return r.mode == LocalPlayer.Mode.ON_SHIP and r.ship == sk.frame
	return r.mode == LocalPlayer.Mode.WORLD


## Does the Admiral parry a blade struck from `from` (his frame)?
static func parries(sk: Skeleton, from: Vector3) -> bool:
	var to := Vector2(from.x - sk.pos.x, from.z - sk.pos.z)
	if to.length() < 0.01:
		return true
	return Vector2(-sin(sk.yaw), -cos(sk.yaw)).dot(to.normalized()) > cos(PARRY_ARC)


# --- helpers ----------------------------------------------------------------------------

func _step_of(m: Dictionary) -> Dictionary:
	return story._step(m)


func _nearest_island(at: Vector2) -> int:
	return story._nearest_island(Vector3(at.x, 0, at.y))


## Everyone near the Reef when the battle is won shares it, whichever crew they sail with.
func share_battle(crew: int) -> void:
	for id in sim.players:
		var r: Dictionary = sim.players[id]
		if r.crew == crew:
			continue
		var w := sim._world_pos(r)
		if Vector2(w.x, w.z).distance_to(Reef.CENTRE) < SHARED_REACH:
			r.profile.gold = int(r.profile.gold) + SHARED_GOLD
			sim.profiles.changed(r.name)
			sim._award(id, SHARED_XP, "the Battle of the Black Reef")
			Net.send_message(id, "The Isles thank you: %d XP and %d gold." % [SHARED_XP, SHARED_GOLD])

class_name WorldEvents
extends RefCounted
## Things that happen on the shared sea for every crew to join (docs/specs/2026-10-08-m13-world-
## events.md): green fires on an island at night, a Spanish patrol, a gold convoy, a raid on
## Port Merrow, a ghost galleon rising in the storm. One at a time, on a clock (but the ghost
## comes when a crew sails deep into the storm). Run by ServerSim each tick.

enum Kind { NONE, GREEN_FIRE, PATROL, CONVOY, RAID, GHOST }

const NAMES := {
	Kind.GREEN_FIRE: "Green Fire", Kind.PATROL: "Raven Patrol", Kind.CONVOY: "Gold Convoy",
	Kind.RAID: "Raid on Merrow", Kind.GHOST: "Ghost Galleon",
}
const FIRST_DELAY := 300.0
const GAP := 480.0
const LIFETIME := 600.0
## Taking part: within this of the event's place when it is won.
const REACH := 150.0
const FIRES := 3
const FIRE_RISE_EVERY := 20.0
const FIRE_NEAR := 40.0
const FIRE_MAX_UP := 8
const FIRE_XP := 200
const PATROL_AGGRO := 150.0
const CONVOY_CHESTS := 3
const CONVOY_CHEST_XP := 150
const RAID_WAVES := 2
const RAID_SIZE := 6
const RAID_XP := 300
const RAID_GOLD := 150
const GHOST_EVERY := 600.0
const GHOST_DEPTH := 0.5

var sim: ServerSim
var kind := Kind.NONE
var started := -1.0
## When the next event starts (server time); below 0 until someone is on the server.
var next_at := -1.0
## Off for tests (--no-ai), but `start` still works.
var enabled := true
var place := Vector3.ZERO
var island := -1
var text := ""
var objects: Array[int] = []
var raised: Array[int] = []
var ships: Array[int] = []
var chests: Array[int] = []
var _paid: Dictionary = {}  # chest id -> crew that took it
var wave := 0
var next_rise := 0.0
var last_ghost := -1e9
var _near := Vector3.INF


func _init(server: ServerSim) -> void:
	sim = server


func tick(_dt: float) -> void:
	if kind != Kind.NONE:
		_run()
		return
	_ghost_watch()
	if not enabled or sim.players.is_empty():
		return
	if next_at < 0.0:
		next_at = sim.time + FIRST_DELAY
		return
	if sim.time >= next_at:
		start(_pick())


## Which event comes next: green fire only at night, the raid only once someone online has
## finished the siege (chapter 18).
func _pick() -> int:
	var choices: Array[int] = [Kind.PATROL, Kind.CONVOY]
	if StoryRun.is_night(sim.time):
		choices.append(Kind.GREEN_FIRE)
	for id in sim.players:
		if sim.players[id].profile.chapters.has("c6"):
			choices.append(Kind.RAID)
			break
	return choices[sim._rng.randi() % choices.size()]


## Start an event. `near` (tests): put it by this point (the nearest island or patrol point).
func start(what: int, near := Vector3.INF) -> void:
	_near = near
	kind = what
	started = sim.time
	objects.clear()
	raised.clear()
	ships.clear()
	chests.clear()
	_paid.clear()
	wave = 0
	match what:
		Kind.GREEN_FIRE:
			_start_fires()
		Kind.PATROL:
			_start_patrol()
		Kind.CONVOY:
			_start_convoy()
		Kind.RAID:
			_start_raid()
	sim.stats.world_events += 1
	print("[server] world event: %s (%s)" % [NAMES[kind], text])
	Net.send_message(0, "World event: %s! %s" % [NAMES[kind], text])
	_tell_clients()


## Tell one pirate (just joined) about the event under way, if any.
func tell(id: int) -> void:
	if kind != Kind.NONE:
		Net.send_event_to(id, "world_event", [NAMES[kind], text, place.x, place.z])


func _tell_clients() -> void:
	if kind == Kind.NONE:
		Net.send_event("world_event", [])
	else:
		Net.send_event("world_event", [NAMES[kind], text, place.x, place.z])


func _start_fires() -> void:
	var free: Array[int] = []
	for i in Islands.mission_islands():
		if not sim.story.busy_island(i):
			free.append(i)
	island = free[sim._rng.randi() % free.size()] if not free.is_empty() else 0
	if _near != Vector3.INF:
		for i in free:
			var a: Dictionary = Islands.LAYOUT[i]
			var b: Dictionary = Islands.LAYOUT[island]
			if Vector2(a.x - _near.x, a.z - _near.z).length() < Vector2(b.x - _near.x, b.z - _near.z).length():
				island = i
	var spec: Dictionary = Islands.LAYOUT[island]
	place = Vector3(spec.x, 0, spec.z)
	for n in FIRES:
		objects.append(sim.story.add_world_object(StoryObject.Kind.FIRE, sim.story._dry_spot(island), sim._rng.randf() * TAU).id)
	next_rise = sim.time + FIRE_RISE_EVERY
	text = "Green fires burn on %s. Douse them before the dead finish rising." % spec.name


## The loop round the Isles: off each of the main islands in turn.
static func patrol_loop() -> Array[Vector2]:
	var loop: Array[Vector2] = []
	for i: int in [0, 1, Fort.index(), 2, Islands.outpost_index()]:
		var spec: Dictionary = Islands.LAYOUT[i]
		var out := Vector2(spec.x, spec.z).normalized() if Vector2(spec.x, spec.z).length() > 1.0 else Vector2(1, 0)
		loop.append(Vector2(spec.x, spec.z) + out * (float(spec.radius) + 110.0))
	return loop


func _start_patrol() -> void:
	var loop := patrol_loop()
	var at := loop[sim._rng.randi() % loop.size()]
	if _near != Vector3.INF:
		# Tests: on her loop's nearest point, or close enough to see the crew from it.
		var here := Vector2(_near.x, _near.z)
		for p in loop:
			if p.distance_to(here) < at.distance_to(here):
				at = p
		if at.distance_to(here) > PATROL_AGGRO - 20.0:
			at = here + (at - here).normalized() * (PATROL_AGGRO - 20.0)
	var id: int = sim.spawn_galleon(0, 0.0, 1, Vector3(at.x, 0, at.y))
	var cap: Captain = sim.captains[id]
	cap.waypoints = loop
	cap.aggro_range = PATROL_AGGRO
	ships.append(id)
	place = Vector3(at.x, 0, at.y)
	text = "A Spanish galleon is patrolling the Isles."


func _start_convoy() -> void:
	var cay: Dictionary = Islands.LAYOUT[0]
	var fort := Islands.LAYOUT[Fort.index()]
	var toward := (Vector2(fort.x, fort.z) - Vector2(cay.x, cay.z)).normalized()
	var at := Vector2(cay.x, cay.z) + toward * (float(cay.radius) + 90.0)
	var id: int = sim.spawn_galleon(0, 0.0, 1, Vector3(at.x, 0, at.y))
	var cap: Captain = sim.captains[id]
	cap.waypoints = [Vector2(fort.x, fort.z) - toward * (float(fort.radius) + 70.0)]
	cap.aggro_range = 0.0  # she runs, she never fights
	ships.append(id)
	for n in CONVOY_CHESTS:
		var chest := sim._new_item(Loot.Kind.CHEST, Loot.State.ON_SHIP, Vector3(-1.0 + 1.0 * n, ShipShape.DECK_Y, -2.5 + 0.8 * (n % 2)), sim._rng.randi_range(250, 450))
		chest.ship = id
		chests.append(chest.id)
	for side: float in [-1.0, 1.0]:
		ships.append(sim.spawn_galleon(0, 0.0, 0, Vector3(at.x + 40.0 * side, 0, at.y + 30.0)))
	place = Vector3(at.x, 0, at.y)
	text = "A treasure galleon is running from Cutlass Cay for the fort, with two escorts."


func _start_raid() -> void:
	island = Islands.outpost_index()
	var spec: Dictionary = Islands.LAYOUT[island]
	place = Vector3(spec.x, 0, spec.z)
	_raid_wave()
	text = "The dead are landing on Port Merrow's beach! Defend the port."


func _raid_wave() -> void:
	wave += 1
	for n in RAID_SIZE:
		var sk := sim._new_skeleton(-1, sim.story._dry_spot(island))
		sk.spanish = true
		raised.append(sk.id)
	Net.send_event("risen", [place.x, 1.0, place.z])


func _standing() -> int:
	var n := 0
	for sid in raised:
		if sim.skeletons.has(sid) and sim.skeletons[sid].alive():
			n += 1
	return n


func _run() -> void:
	match kind:
		Kind.GREEN_FIRE:
			_run_fires()
		Kind.PATROL:
			var cap: Captain = sim.captains.get(ships[0]) if not ships.is_empty() else null
			if cap and cap.hostile and wave == 0:
				wave = 1  # (the patrol's way of remembering it has said so)
				print("[server] the Raven Patrol turns on a crew")
				Net.send_message(0, "The Raven Patrol has seen you! She's coming about!")
		Kind.CONVOY:
			_run_convoy()
		Kind.RAID:
			if _standing() == 0:
				if wave < RAID_WAVES:
					_raid_wave()
					Net.send_message(0, "Another boat of the dead grounds on Merrow's beach!")
				else:
					_reward(RAID_XP, RAID_GOLD, "the defence of Port Merrow")
					_end(true, "Port Merrow is safe. Every defender is paid.")
					return
	if kind != Kind.NONE and sim.time - started > LIFETIME:
		_time_up()


func _run_fires() -> void:
	var lit: Array[StoryObject] = []
	for oid in objects:
		var o: StoryObject = sim.story.objects.get(oid)
		if o and o.state > 0:
			lit.append(o)
	if lit.is_empty():
		var spec: Dictionary = Islands.LAYOUT[island]
		var beach := Islands.trader_spot(island)
		sim._new_item(Loot.Kind.CHEST, Loot.State.GROUND, beach + Vector3(0, 0.05, 0), sim._rng.randi_range(250, 450))
		_reward(FIRE_XP, 0, "putting out the green fire")
		_end(true, "The green fires on %s are out. A chest washes up on the beach." % spec.name)
		return
	if sim.time < next_rise:
		return
	next_rise = sim.time + FIRE_RISE_EVERY
	if _standing() >= FIRE_MAX_UP:
		return
	var near := false
	for id in sim.players:
		var r: Dictionary = sim.players[id]
		if r.dead_until < 0.0 and sim._world_pos(r).distance_to(lit[0].pos) < FIRE_NEAR:
			near = true
	if not near:
		return
	for n in 2:
		var o: StoryObject = lit[sim._rng.randi() % lit.size()]
		var a := sim._rng.randf() * TAU
		var p := o.pos + Vector3(cos(a), 0, sin(a)) * 1.5
		p.y = Islands.ground_at(island, p.x, p.z)
		raised.append(sim._new_skeleton(-1, p).id)
	Net.send_event("risen", [lit[0].pos.x, lit[0].pos.y, lit[0].pos.z])


## The convoy: chests carried off her deck pay whoever stows them; empty, or at the fort, it ends.
func _run_convoy() -> void:
	var aboard := 0
	for cid in chests:
		var chest: Loot = sim.items.get(cid)
		if chest == null:
			continue
		if chest.state == Loot.State.ON_SHIP and ships.size() > 0 and chest.ship == ships[0]:
			aboard += 1
		elif chest.state == Loot.State.ON_SHIP and sim.crews.has(chest.ship) and not _paid.has(cid):
			_paid[cid] = chest.ship
			sim._award_crew(chest.ship, CONVOY_CHEST_XP, "a convoy chest")
	if aboard == 0:
		_end(true, "The convoy's gold is taken!")
		return
	var g: ShipState = sim.ships.get(ships[0]) if not ships.is_empty() else null
	if g == null:
		return
	var fort := Islands.LAYOUT[Fort.index()]
	if Vector2(g.x - fort.x, g.z - fort.z).length() < float(fort.radius) + 90.0:
		_sail_off()
		_end(false, "The convoy reaches the fort. The Admiral's gold is safe, this time.")


func _time_up() -> void:
	match kind:
		Kind.GREEN_FIRE:
			for oid in objects:
				if sim.story.objects.has(oid):
					sim.story.objects[oid].state = 0
			_end(false, "The green fires burn themselves out.")
		Kind.RAID:
			for sid in raised:
				if sim.skeletons.has(sid) and sim.skeletons[sid].alive():
					sim.skeletons[sid].fell = sim.time
			_end(false, "Dawn comes, and the raiders crumble.")
		_:
			_sail_off()
			_end(false, "The %s sails off over the horizon." % ("patrol" if kind == Kind.PATROL else "ghost"))


## Ships and what is on their decks go over the horizon.
func _sail_off() -> void:
	for id in ships:
		if not sim.ships.has(id) or sim.ships[id].is_sinking():
			continue
		for sid in sim.skeletons.keys():
			if sim.skeletons[sid].frame == id:
				sim.skeletons.erase(sid)
		for iid in sim.items.keys():
			var it: Loot = sim.items[iid]
			if it.state == Loot.State.ON_SHIP and it.ship == id:
				sim.items.erase(iid)
		sim.ships.erase(id)
		sim.captains.erase(id)


func _end(won: bool, how: String) -> void:
	if won:
		sim.stats.world_won += 1
	print("[server] world event over: %s (%s)" % [NAMES[kind], "won" if won else "lost"])
	Net.send_message(0, how)
	for oid in objects:
		sim.story.objects.erase(oid)
	kind = Kind.NONE
	next_at = sim.time + GAP
	_tell_clients()


## Everyone within REACH of the event's place, whichever crew: XP and gold.
func _reward(xp: int, gold: int, why: String) -> void:
	for id in sim.players:
		var w := sim._world_pos(sim.players[id])
		if Vector2(w.x - place.x, w.z - place.z).length() > REACH:
			continue
		var r: Dictionary = sim.players[id]
		if gold > 0:
			r.profile.gold = int(r.profile.gold) + gold
			sim.profiles.changed(r.name)
		sim._award(id, xp, why)
		sim._send_profile(id)


## The ghost galleon: when a crew is deep in a storm and nothing else is on, one rises.
func _ghost_watch() -> void:
	if not enabled or sim.time - last_ghost < GHOST_EVERY:
		return
	for c in sim.crews:
		var s: ShipState = sim.ships.get(c)
		if s == null or s.is_sinking() or sim._crew_members(c).is_empty():
			continue
		if Storm.amount(Vector2(s.x, s.z), sim.time) < GHOST_DEPTH:
			continue
		var m: Dictionary = sim.crews[c].mission
		if not m.is_empty() and m.kind == Missions.Kind.STORY:
			continue  # a chapter's own ghosts are enough
		last_ghost = sim.time
		start_ghost(c, s)
		return


func start_ghost(crew: int, near: ShipState) -> void:
	kind = Kind.GHOST
	started = sim.time
	objects.clear()
	raised.clear()
	chests.clear()
	ships = [sim.story.act4.spawn_ghost(crew, near, 90.0)]
	place = Vector3(near.x, 0, near.z)
	text = "A ghost galleon rises out of the storm!"
	sim.stats.world_events += 1
	print("[server] world event: %s (%s)" % [NAMES[kind], text])
	Net.send_message(0, "World event: %s! %s" % [NAMES[kind], text])
	_tell_clients()


func on_ship_sunk(ship_id: int, at: Vector3) -> void:
	if kind == Kind.NONE or not ships.has(ship_id) or ships[0] != ship_id:
		return
	match kind:
		Kind.PATROL:
			_end(true, "The Raven Patrol is sunk!")
		Kind.GHOST:
			var skull := sim._new_item(Loot.Kind.SKULL, Loot.State.GROUND, at, sim._rng.randi_range(300, 500))
			sim._set_floating(skull, at)
			_end(true, "The ghost galleon goes down, and her captain's skull bobs up glowing.")
		Kind.CONVOY:
			pass  # her chests float; taking them is the win

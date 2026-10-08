class_name WorldEvents
extends RefCounted
## Things that happen on the shared sea for every crew to join (docs/specs/2026-10-08-m13-world-
## events.md): green fires on an island at night, a Spanish patrol, a gold convoy, a raid on
## Port Merrow, a ghost galleon rising in the storm; and for crews further on, the dead
## re-taking the fort and the Maw stirring (docs/specs/2026-10-08-m18-fort-and-maw.md). One at a
## time, on a clock (but the ghost comes when a crew sails deep into the storm). Run by ServerSim
## each tick.

enum Kind { NONE, GREEN_FIRE, PATROL, CONVOY, RAID, GHOST, FORT, MAW }

const NAMES := {
	Kind.GREEN_FIRE: "Green Fire", Kind.PATROL: "Raven Patrol", Kind.CONVOY: "Gold Convoy",
	Kind.RAID: "Raid on Merrow", Kind.GHOST: "Ghost Galleon", Kind.FORT: "Fuerte del Cuervo",
	Kind.MAW: "The Maw Stirs",
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
const FORT_WAVES := 2
const FORT_SIZE := 6
const FORT_CHESTS := 4
const FORT_XP := 300
const MAW_GHOSTS := 2
## Cannonballs to break one of the lesser colossus's joints (the story's giant takes 8).
const MAW_JOINT_HITS := 4
const MAW_REACH := 300.0
const MAW_XP := 400
## How long the felled giant kneels before it sinks and the event ends.
const MAW_FALL := 8.0
## The gift for felling it: a shirt dye never sold.
const MAW_DYE := "dye10"

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
## The lesser colossus: hits on each joint, when it next attacks, when it sinks once felled.
var joints: Array[int] = [0, 0, 0, 0]
var next_shot := 0.0
var fell_at := -1.0


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
## finished the siege (c6), the fort once someone has stormed it (b6) and nobody's chapter is
## there, the Maw only at night once someone has finished the story (e6).
func _pick() -> int:
	var choices: Array[int] = [Kind.PATROL, Kind.CONVOY]
	var night := StoryRun.is_night(sim.time)
	if night:
		choices.append(Kind.GREEN_FIRE)
	if _anyone_done("c6"):
		choices.append(Kind.RAID)
	if _anyone_done("b6") and not sim.story.busy_island(Fort.index()):
		choices.append(Kind.FORT)
	if night and _anyone_done("e6"):
		choices.append(Kind.MAW)
	return choices[sim._rng.randi() % choices.size()]


func _anyone_done(chapter: String) -> bool:
	for id in sim.players:
		if sim.players[id].profile.chapters.has(chapter):
			return true
	return false


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
	fell_at = -1.0
	match what:
		Kind.GREEN_FIRE:
			_start_fires()
		Kind.PATROL:
			_start_patrol()
		Kind.CONVOY:
			_start_convoy()
		Kind.RAID:
			_start_raid()
		Kind.FORT:
			_start_fort()
		Kind.MAW:
			_start_maw()
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


## The dead hold Fuerte del Cuervo again: its tower guns run out, the courtyard garrisoned.
func _start_fort() -> void:
	island = Fort.index()
	var c := Fort.centre()
	place = Vector3(c.x, 0, c.z)
	for side: int in [-1, 1]:
		var gun := sim.story.add_world_object(StoryObject.Kind.GUN, Fort.gun_pos(side), Fort.FACING + Fort.TOWER_SPREAD * side)
		gun.state = 2
		sim.story._gun_ready[gun.id] = sim.time + 4.0 + 2.0 * side
		objects.append(gun.id)
	_fort_wave()
	text = "The dead hold Fuerte del Cuervo again. Its guns are run out and its vault is full."


## Six of the Spanish dead in a ring round the courtyard's platform.
func _fort_wave() -> void:
	wave += 1
	print("[server] the fort's garrison: wave %d" % wave)
	for n in FORT_SIZE:
		var p := Fort.ring_spot(TAU * n / float(FORT_SIZE) + 0.5 * wave, 6.5)
		p.y = Islands.ground_at(island, p.x, p.z)
		var sk := sim._new_skeleton(-1, p)
		sk.spanish = true
		raised.append(sk.id)
	Net.send_event("risen", [place.x, Fort.PLATEAU_Y, place.z])


## The fort taken back: the vault's chests at its door, and pay for everyone there.
func _fort_won() -> void:
	var door := Fort.door_pos(Fort.VAULT)
	for n in FORT_CHESTS:
		var at := door + Vector3(-0.9 + 0.6 * n, 0.05, 0.3 * (n % 2))
		at.y = Islands.ground_at(island, at.x, at.z) + 0.05
		sim._new_item(Loot.Kind.CHEST, Loot.State.GROUND, at, sim._rng.randi_range(300, 520))
	_reward(FORT_XP, 0, "retaking Fuerte del Cuervo")
	_end(true, "Fuerte del Cuervo is ours again, and its vault stands open!")


## The Black Reef wakes: a lesser colossus in the Maw and ghost galleons at the Reef's edge.
func _start_maw() -> void:
	place = Vector3(Reef.CENTRE.x, 0, Reef.CENTRE.y)
	var giant := sim.story.add_world_object(StoryObject.Kind.COLOSSUS, Vector3(Reef.CENTRE.x, StoryAct5.ROOT_Y, Reef.CENTRE.y), 0.0)
	giant.state = 0
	objects.append(giant.id)
	joints = [0, 0, 0, 0]
	next_shot = sim.time + StoryAct5.ATTACK_EVERY
	Net.send_event("colossus", [giant.id])
	for n in MAW_GHOSTS:
		var a := TAU * n / float(MAW_GHOSTS) + sim._rng.randf()
		var edge := Reef.CENTRE + Vector2(cos(a), sin(a)) * Reef.STORM_RADIUS
		ships.append(sim.story.act4.spawn_ghost_at(Vector3(edge.x, 0, edge.y)))
	text = "The Black Reef wakes! Ghost galleons rise at its edge, and a giant of bones stands in the Maw."


func giant() -> StoryObject:
	if kind != Kind.MAW or objects.is_empty():
		return null
	return sim.story.objects.get(objects[0])


## A cannonball in flight at `pos`: does it strike one of the giant's glowing joints?
func projectile_hit(pos: Vector3) -> bool:
	var g := giant()
	if g == null or g.state & StoryAct5.KNEEL:
		return false
	for i in StoryAct5.JOINTS.size():
		if g.state & (1 << i) or pos.distance_to(StoryAct5.joint_world(g, i)) >= StoryAct5.JOINT_REACH:
			continue
		joints[i] += 1
		sim.stats.joint_hits += 1
		Net.send_event("joint_hit", [g.id, i, joints[i]])
		if joints[i] >= MAW_JOINT_HITS:
			g.state |= 1 << i
			var broken := StoryAct5._broken(g)
			print("[server] a joint of the lesser colossus breaks (%d of 4)" % broken)
			Net.send_message(0, "A joint of the giant shatters! (%d of 4)" % broken)
			if broken == 4:
				g.state |= StoryAct5.KNEEL
				fell_at = sim.time
				Net.send_message(0, "The giant goes down on its knees in the Maw!")
		return true
	return false


func _run_maw() -> void:
	var g := giant()
	if g == null:
		return
	if fell_at >= 0.0:
		if sim.time - fell_at < MAW_FALL:
			return
		var edge := StoryAct5.maw_edge()
		var chest := sim._new_item(Loot.Kind.CHEST, Loot.State.GROUND, edge, sim._rng.randi_range(900, 1300))
		sim._set_floating(chest, edge)
		_reward(MAW_XP, 0, "felling the giant in the Maw", MAW_REACH, MAW_DYE)
		_sail_off()
		_end(true, "The giant sinks into the Maw, and a great chest comes up in the whirlpool!")
		return
	sim.story.act5.giant_attack(g, self)


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
		Kind.FORT:
			if _standing() == 0:
				if wave < FORT_WAVES:
					_fort_wave()
					Net.send_message(0, "More of the dead climb up from the fort's cells!")
				else:
					_fort_won()
					return
		Kind.MAW:
			_run_maw()
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
			_crumble_raised()
			_end(false, "Dawn comes, and the raiders crumble.")
		Kind.FORT:
			_crumble_raised()
			_end(false, "The garrison holds Fuerte del Cuervo, and its guns fall silent. For now.")
		Kind.MAW:
			_sail_off()
			_end(false, "The giant sinks back into the Maw, and the ghosts go down with it.")
		_:
			_sail_off()
			_end(false, "The %s sails off over the horizon." % ("patrol" if kind == Kind.PATROL else "ghost"))


func _crumble_raised() -> void:
	for sid in raised:
		if sim.skeletons.has(sid) and sim.skeletons[sid].alive():
			sim.skeletons[sid].fell = sim.time


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


## Everyone within `reach` of the event's place, whichever crew: XP, gold and maybe a gift.
func _reward(xp: int, gold: int, why: String, reach := REACH, gift := "") -> void:
	for id in sim.players:
		var w := sim._world_pos(sim.players[id])
		if Vector2(w.x - place.x, w.z - place.z).length() > reach:
			continue
		var r: Dictionary = sim.players[id]
		if gold > 0:
			r.profile.gold = int(r.profile.gold) + gold
		if gift != "" and not r.profile.owned.has(gift):
			r.profile.owned.append(gift)
			Net.send_message(id, "A gift: %s." % Shop.ITEMS[Shop.index_of(gift)][2])
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

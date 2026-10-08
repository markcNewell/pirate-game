class_name StoryAct5
extends RefCounted
## Act V's steps (docs/specs/2026-10-08-m12-the-heart-of-ash.md), run for StoryRun: Isla
## Ceniza's ashen dead and Doctor Ocaso among his braziers, the beacons, the Ash Admiral's
## flagship, the Bone Colossus, the Ash Admiral on the Anvil and the Heart thrown into the Maw.

## Where the Cuervo Negro lies on the bottom of the Reef (chapter 25's dive).
const WRECK_AT := Vector3(805.0, 0.0, 650.0)
## The ashen dead: two waves of four on Isla Ceniza's beach once a pirate lands.
const ASHEN_HEALTH := 80
## Doctor Ocaso among his braziers (island-local to Isla Ceniza, round his workshop's door).
const OCASO_HEALTH := 300
const OCASO_JUMP_EVERY := 6.0
const OCASO_RAISE := 2
const OCASO_MAX_UP := 6
## He wakes when a pirate comes this near his workshop.
const OCASO_WAKE := 45.0
## The workshop door on Isla Ceniza's hill, island-local, and the braziers round it.
const WORKSHOP := Vector3(-8.0, 0.0, 9.0)
const BRAZIERS: Array[Vector3] = [Vector3(-14.0, 0.0, 2.0), Vector3(-2.0, 0.0, 3.0), Vector3(-6.0, 0.0, -4.0)]
## Beacons: on the heights of Cutlass Cay, Parrot Rock and Gull Isle.
const BEACON_ISLANDS: Array[int] = [0, 1, 2]
## The Colossus stands in the Maw, knee-deep (its feet ROOT_Y below the sea); its joints, from
## its feet at SCALE times life size, take hits: shoulders 20 m above the sea, knees 3 m.
const SCALE := 18.0
const ROOT_Y := -6.0
const JOINTS: Array[Vector3] = [Vector3(4.0, 26.0, 0.0), Vector3(-4.0, 26.0, 0.0), Vector3(1.8, 9.0, -0.3), Vector3(-1.8, 9.0, -0.3)]
const JOINT_HITS := 8
const JOINT_REACH := 5.0
const KNEEL := 16
const ATTACK_EVERY := 7.0
const ATTACK_RANGE := 120.0
const SLAM_RANGE := 35.0
const SLAM_HURT := 15
## The Ash Admiral: the Raven Admiral again, tougher and quicker.
const ASH_ADMIRAL_HEALTH := 500
const ASH_LUNGE_EVERY := 3.5
## The Heart: burns its carrier, raises the dead near them.
const HEART_BURN := 4
const HEART_RAISE_EVERY := 5.0
const HEART_MAX_UP := 8
const SHARED_REACH := 300.0
const SHARED_XP := 500
const SHARED_GOLD := 300

var story: StoryRun
var sim: ServerSim
var _burn := 0.0


func _init(run: StoryRun) -> void:
	story = run
	sim = run.sim


static func anvil() -> int:
	for i in Islands.LAYOUT.size():
		if Islands.LAYOUT[i].get("anvil", false):
			return i
	return -1


static func ceniza() -> int:
	for i in Islands.LAYOUT.size():
		if Islands.LAYOUT[i].get("ash", false):
			return i
	return -1


## A point on Isla Ceniza's ground, from island-local (x, z).
static func on_ceniza(local: Vector3) -> Vector3:
	var spec: Dictionary = Islands.LAYOUT[ceniza()]
	return Vector3(spec.x + local.x, IslandMesh.ground(spec, local.x, local.z), spec.z + local.z)


## The edge of the Black Reef, where Wren's lantern goes: the West Stack's top (world).
static func reef_edge() -> Vector3:
	var spec: Dictionary = Islands.LAYOUT[7]
	return Vector3(spec.x, IslandMesh.ground(spec, 0.0, 0.0), spec.z)


## The Maw's edge on the Anvil, where the Heart goes in (world).
static func maw_edge() -> Vector3:
	var spec: Dictionary = Islands.LAYOUT[anvil()]
	var toward := (Reef.CENTRE - Vector2(spec.x, spec.z)).normalized() * (float(spec.radius) - 4.0)
	return Vector3(spec.x + toward.x, IslandMesh.ground(spec, toward.x, toward.y), spec.z + toward.y)


## Where the Colossus lies once it has fallen across the Anvil (world, on the rock's top).
static func fallen_at() -> Vector3:
	var spec: Dictionary = Islands.LAYOUT[anvil()]
	return Vector3(spec.x, IslandMesh.ground(spec, 0.0, 0.0), spec.z)


# --- entering steps ---------------------------------------------------------------------

func enter(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	m.stage = 0
	match int(step.kind):
		Story.Step.ASHEN:
			m.islands = [ceniza()]
			m.wave = 0
			sim._tell_crew(crew, "Isla Ceniza. Ash falls like snow. Land, and keep your lanterns lit.")
		Story.Step.OCASO:
			_enter_ocaso(crew)
		Story.Step.BEACONS:
			m.islands = BEACON_ISLANDS.duplicate()
			for island in BEACON_ISLANDS:
				story._add_object(crew, StoryObject.Kind.BEACON, beacon_spot(island), 0.0).state = 0
			sim._tell_crew(crew, "Light the beacons on Cutlass Cay, Parrot Rock and Gull Isle!")
		Story.Step.ASH_FLAGSHIP:
			m.islands = []
			m.ship = -1
			sim._tell_crew(crew, "The Ash Admiral's flagship is coming out of the Maw!")
		Story.Step.COLOSSUS:
			m.islands = [anvil()]
			var giant := story._add_object(crew, StoryObject.Kind.COLOSSUS, Vector3(Reef.CENTRE.x, ROOT_Y, Reef.CENTRE.y), 0.0)
			giant.state = 0
			m.joints = [0, 0, 0, 0]
			m.next_shot = sim.time + ATTACK_EVERY
			print("[server] crew %d: the Bone Colossus rises from the Maw" % crew)
			Net.send_event("colossus", [giant.id])
			sim._tell_crew(crew, "Out of the Maw: a giant of bones! Break its glowing joints with your guns!")
		Story.Step.ASH_DUEL:
			_enter_ash_duel(crew, step)
		Story.Step.HEART:
			m.islands = [anvil()]
			m.next_rise = sim.time + HEART_RAISE_EVERY


## The beacon on an island's height: its hill, or the ground well up from the beach.
static func beacon_spot(island: int) -> Vector3:
	var spec: Dictionary = Islands.LAYOUT[island]
	var best := Vector3(spec.x, 0, spec.z)
	var best_y := -INF
	for k in 24:
		var a := TAU * k / 24.0
		for r: float in [0.15, 0.3, 0.45]:
			var x := cos(a) * r * float(spec.radius)
			var z := sin(a) * r * float(spec.radius)
			var y := IslandMesh.ground(spec, x, z)
			if y > best_y and not IslandMesh.story_site(spec, x, z):
				best_y = y
				best = Vector3(spec.x + x, y, spec.z + z)
	return best


func _enter_ocaso(crew: int) -> void:
	var m: Dictionary = sim.crews[crew].mission
	m.islands = [ceniza()]
	for b in BRAZIERS:
		story._add_object(crew, StoryObject.Kind.BRAZIER, on_ceniza(b), 0.0).state = 1
	var doctor := sim._new_skeleton(-1, on_ceniza(WORKSHOP + Vector3(0, 0, -2.0)))
	doctor.doctor = true
	doctor.hp = OCASO_HEALTH
	doctor.cooldown = 1e6  # he does not fight with his hands
	doctor.story_crew = crew
	m.captain = doctor.id
	m.next_shot = sim.time + OCASO_JUMP_EVERY
	print("[server] crew %d: Doctor Ocaso waits at his workshop" % crew)
	sim._tell_crew(crew, "Ocaso! Douse his braziers, or nothing will touch him.")


func _enter_ash_duel(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	m.islands = [anvil()]
	var top := fallen_at()
	var admiral := sim._new_skeleton(-1, top + Vector3(0, 0, 2.0))
	admiral.admiral = true
	admiral.ash = true
	admiral.spanish = true
	admiral.hp = ASH_ADMIRAL_HEALTH
	admiral.damage = 30
	admiral.story_crew = crew
	admiral.next_lunge = sim.time + ASH_LUNGE_EVERY
	m.captain = admiral.id
	for n in int(step.get("guards", 0)):
		var a := TAU * n / maxf(1.0, float(step.guards))
		var dead := sim._new_skeleton(-1, top + Vector3(cos(a), 0, sin(a)) * 4.0)
		dead.ashen = true
		dead.spanish = true
		dead.hp = ASHEN_HEALTH
		dead.story_crew = crew
		m.raised.append(dead.id)
	print("[server] crew %d: the Ash Admiral stands on the Anvil" % crew)
	sim._tell_crew(crew, "The Colossus falls across the Anvil, and on its ribs: the Ash Admiral!")


# --- every tick ---------------------------------------------------------------------------

func tick(dt: float) -> void:
	_burn_heart_carriers(dt)
	for c in sim.crews.keys():
		var m := story._mission_of(c)
		if m.is_empty():
			continue
		var step := story._step(m)
		match int(step.kind):
			Story.Step.ASHEN:
				_ashen_tick(c, m, step)
			Story.Step.OCASO:
				_ocaso_tick(c, m)
			Story.Step.ASH_FLAGSHIP:
				_ash_flagship_tick(c, m)
			Story.Step.COLOSSUS:
				_colossus_tick(c, m)
			Story.Step.HEART:
				_heart_tick(c, m)


func _ashen_tick(crew: int, m: Dictionary, step: Dictionary) -> void:
	var island := ceniza()
	if int(m.wave) == 0:
		var landed := false
		for id in sim._crew_members(crew):
			var r: Dictionary = sim.players[id]
			if r.mode == LocalPlayer.Mode.WORLD and Islands.island_at(r.pos.x, r.pos.z) == island:
				landed = true
		if not landed:
			return
	if story.standing(m) > 0:
		return
	if int(m.wave) >= int(step.waves):
		print("[server] crew %d beat the ashen dead" % crew)
		story._next_step(crew)
		return
	m.wave += 1
	for n in int(step.size):
		var a := sim._rng.randf() * TAU
		var dead := sim._new_skeleton(-1, story._dry_spot(island) + Vector3(cos(a), 0, sin(a)) * 1.5)
		dead.ashen = true
		dead.spanish = true
		dead.hp = ASHEN_HEALTH
		dead.story_crew = crew
		m.raised.append(dead.id)
	Net.send_event("risen", [Islands.LAYOUT[island].x, 2.0, Islands.LAYOUT[island].z])
	sim._tell_crew(crew, "The ashen dead climb out of the ash! (wave %d of %d)" % [m.wave, int(step.waves)])


func lit_braziers(m: Dictionary) -> Array[StoryObject]:
	var out: Array[StoryObject] = []
	for oid: int in m.objects:
		var o: StoryObject = story.objects.get(oid)
		if o and o.kind == StoryObject.Kind.BRAZIER and o.state > 0:
			out.append(o)
	return out


## Ocaso's turn: every few seconds a burst of green fire, and he stands by another brazier,
## raising the dead where he lands.
func _ocaso_tick(crew: int, m: Dictionary) -> void:
	var doctor: Skeleton = sim.skeletons.get(m.captain)
	if doctor == null or not doctor.alive():
		return
	doctor.shield_up = not lit_braziers(m).is_empty()
	var near := false
	for id in sim._crew_members(crew):
		var r: Dictionary = sim.players[id]
		if r.dead_until < 0.0 and sim._world_pos(r).distance_to(on_ceniza(WORKSHOP)) < OCASO_WAKE:
			near = true
	if not near:
		m.next_shot = maxf(m.next_shot, sim.time + 2.0)  # asleep at his bench until someone comes
		return
	if sim.time < m.next_shot:
		return
	m.next_shot = sim.time + OCASO_JUMP_EVERY
	var choices := lit_braziers(m)
	if choices.is_empty():
		for oid: int in m.objects:
			var o: StoryObject = story.objects.get(oid)
			if o and o.kind == StoryObject.Kind.BRAZIER:
				choices.append(o)
	if choices.is_empty():
		return
	var to: StoryObject = choices[sim._rng.randi() % choices.size()]
	Net.send_event("blink", [doctor.pos.x, doctor.pos.y, doctor.pos.z, to.pos.x, to.pos.y, to.pos.z])
	doctor.pos = to.pos + Vector3(1.2, 0, 0.6)
	doctor.pos.y = Islands.ground_at(ceniza(), doctor.pos.x, doctor.pos.z)
	sim.stats.blinks += 1
	for n in mini(OCASO_RAISE, maxi(0, OCASO_MAX_UP - story.standing(m))):
		var a := sim._rng.randf() * TAU
		var dead := sim._new_skeleton(-1, to.pos + Vector3(cos(a), 0, sin(a)) * 2.5)
		dead.pos.y = Islands.ground_at(ceniza(), dead.pos.x, dead.pos.z)
		dead.ashen = true
		dead.spanish = true
		dead.hp = ASHEN_HEALTH
		dead.story_crew = crew
		m.raised.append(dead.id)


## A bucket on one of Ocaso's braziers.
func douse_brazier(o: StoryObject) -> void:
	o.state = 0
	sim.stats.braziers += 1
	print("[server] a brazier was doused (%d still burning)" % lit_braziers(story._mission_of(o.crew)).size())
	var m := story._mission_of(o.crew)
	if not m.is_empty() and lit_braziers(m).is_empty():
		sim._tell_crew(o.crew, "The last brazier hisses out! Ocaso can be hurt now!")


func _ash_flagship_tick(crew: int, m: Dictionary) -> void:
	if m.ship >= 0:
		return
	var own: ShipState = sim.ships.get(crew)
	if own == null or Vector2(own.x, own.z).distance_to(Reef.CENTRE) > 300.0:
		return
	var at := Vector3(Reef.CENTRE.x, 0, Reef.CENTRE.y) + Vector3(own.x - Reef.CENTRE.x, 0, own.z - Reef.CENTRE.y).normalized() * 60.0
	m.ship = sim.spawn_galleon(crew, 0.0, 6, at)
	sim.captains[m.ship].bail_scale = 1.5
	print("[server] crew %d: the Ash Admiral's flagship comes out of the Maw" % crew)


## The Colossus: turning to the nearest crew ship; a fist for those close, wreckage for the rest.
func _colossus_tick(_crew: int, m: Dictionary) -> void:
	var giant := colossus(m)
	if giant == null or giant.state & KNEEL:
		return
	giant_attack(giant, m)


## A giant's turn (the story's, or the Maw's lesser one): `state` holds when it next attacks.
func giant_attack(giant: StoryObject, state: Variant) -> void:
	var target: ShipState = null
	var target_id := -1
	var best := ATTACK_RANGE
	for c in sim.crews:
		var s: ShipState = sim.ships.get(c)
		if s == null or s.is_sinking():
			continue
		var d := Vector2(s.x - giant.pos.x, s.z - giant.pos.z).length()
		if d < best:
			best = d
			target = s
			target_id = c
	if target == null:
		return
	giant.yaw = atan2(-(target.x - giant.pos.x), -(target.z - giant.pos.z))
	if sim.time < state.next_shot:
		return
	state.next_shot = sim.time + ATTACK_EVERY
	if best < SLAM_RANGE:
		sim.stats.slams += 1
		Net.send_event("slam", [giant.id, target.x, target.z])
		if target.holes.size() < ServerSim.MAX_HOLES:
			var h := ShipShape.hole_point(Vector3(1.0 if sim._rng.randf() < 0.5 else -1.0, 0.0, sim._rng.randf_range(-6.0, 6.0)))
			target.holes.append([target.next_hole_id, h.x, h.y, h.z, 0.0])
			target.next_hole_id += 1
		for id in sim._crew_members(target_id):
			var r: Dictionary = sim.players[id]
			if r.mode == LocalPlayer.Mode.ON_SHIP and r.ship == target_id and r.dead_until < 0.0:
				sim._hurt_player(id, SLAM_HURT, "the Bone Colossus's fist")
	else:
		sim.stats.throws += 1
		var hand := joint_world(giant, 0) + Vector3(0, 4.0, 0)
		sim.fire_from(hand, Vector3(target.x, 0.8, target.z), 0.06)


func colossus(m: Dictionary) -> StoryObject:
	for oid: int in m.objects:
		var o: StoryObject = story.objects.get(oid)
		if o and o.kind == StoryObject.Kind.COLOSSUS:
			return o
	return null


## Where joint `i` is in the world: shoulders 0-1, knees 2-3.
static func joint_world(giant: StoryObject, i: int) -> Vector3:
	return giant.pos + Basis(Vector3.UP, giant.yaw) * JOINTS[i]


## A cannonball in flight at `pos`: does it strike a glowing joint? True if it did (it is spent).
func projectile_hit(pos: Vector3) -> bool:
	for c in sim.crews:
		var m := story._mission_of(c)
		if m.is_empty() or int(story._step(m).kind) != Story.Step.COLOSSUS:
			continue
		var giant := colossus(m)
		if giant == null or giant.state & KNEEL:
			continue
		for i in JOINTS.size():
			if giant.state & (1 << i):
				continue
			if pos.distance_to(joint_world(giant, i)) < JOINT_REACH:
				m.joints[i] += 1
				sim.stats.joint_hits += 1
				Net.send_event("joint_hit", [giant.id, i, m.joints[i]])
				if m.joints[i] >= JOINT_HITS:
					giant.state |= 1 << i
					print("[server] a joint of the Colossus breaks (%d of 4)" % _broken(giant))
					sim._tell_crew(c, "A joint shatters in green fire! (%d of 4)" % _broken(giant))
					if _broken(giant) == 4:
						_fall(c, m, giant)
				return true
	return false


static func _broken(giant: StoryObject) -> int:
	var n := 0
	for i in 4:
		if giant.state & (1 << i):
			n += 1
	return n


func _fall(crew: int, m: Dictionary, giant: StoryObject) -> void:
	giant.state |= KNEEL
	giant.pos = fallen_at()
	print("[server] crew %d felled the Bone Colossus" % crew)
	story._next_step(crew)


## The Heart's carriers burn, and while it is carried the dead rise round them.
func _burn_heart_carriers(dt: float) -> void:
	_burn += dt
	if _burn < 1.0:
		return
	_burn -= 1.0
	for id in sim.players:
		var r: Dictionary = sim.players[id]
		if r.carry >= 0 and sim.items.has(r.carry) and sim.items[r.carry].kind == Loot.Kind.HEART and r.dead_until < 0.0:
			sim._hurt_player(id, HEART_BURN, "the Heart of Ash")


func _heart_tick(crew: int, m: Dictionary) -> void:
	if sim.time < m.next_rise:
		return
	m.next_rise = sim.time + HEART_RAISE_EVERY
	if not sim.items.has(m.skull) or sim.items[m.skull].state != Loot.State.CARRIED:
		return
	if story.standing(m) >= HEART_MAX_UP:
		return
	var at: Vector3 = sim.items[m.skull].pos
	for n in 2:
		var a := sim._rng.randf() * TAU
		var p := at + Vector3(cos(a), 0, sin(a)) * 6.0
		var island := Islands.island_at(p.x, p.z)
		if island < 0:
			continue
		p.y = Islands.ground_at(island, p.x, p.z)
		var dead := sim._new_skeleton(-1, p)
		dead.ashen = true
		dead.spanish = true
		dead.hp = ASHEN_HEALTH
		dead.story_crew = crew
		m.raised.append(dead.id)


func beacons_left(m: Dictionary) -> int:
	var n := 0
	for oid: int in m.objects:
		var o: StoryObject = story.objects.get(oid)
		if o and o.kind == StoryObject.Kind.BEACON and o.state == 0:
			n += 1
	return n


## E at an unlit beacon: up it goes, calling every crew in the Isles.
func light_beacon(id: int, r: Dictionary, object_id: int) -> void:
	var o: StoryObject = story.objects.get(object_id)
	var m := story._mission_of(r.crew)
	if o == null or o.kind != StoryObject.Kind.BEACON or o.state != 0 or m.is_empty() or o.crew != r.crew:
		return
	if r.mode != LocalPlayer.Mode.WORLD or r.pos.distance_to(o.pos) > StoryRun.USE_REACH + 1.5:
		return
	o.state = 1
	sim.stats.beacons += 1
	Net.send_event("beacon", [o.id])
	print("[server] %s lit the beacon on %s" % [r.name, Islands.LAYOUT[maxi(0, Islands.island_at(o.pos.x, o.pos.z))].name])
	sim._tell_crew(r.crew, "A beacon blazes up! (%d left)" % beacons_left(m))
	if beacons_left(m) == 0:
		for pid in sim._crew_members(r.crew):
			story._say(pid, story._step(m).get("lines", []))
		story._next_step(r.crew)


# --- hooks ------------------------------------------------------------------------------

## The Ash Admiral has fallen: the Heart drops where he stood.
func on_ash_admiral_fell(m: Dictionary, sk: Skeleton) -> void:
	var heart := sim._new_item(Loot.Kind.HEART, Loot.State.GROUND, sk.pos + Vector3(0, 0.05, 0), 0)
	m.items.append(heart.id)
	m.skull = heart.id
	Net.send_message(0, "The Ash Admiral falls, and the Heart of Ash rolls burning across the rock!")


## E at the Maw's edge with the Heart: in it goes, and the dead are only bones again.
func throw_heart(id: int, r: Dictionary) -> bool:
	var m := story._mission_of(r.crew)
	if m.is_empty() or int(story._step(m).kind) != Story.Step.HEART or r.carry != m.skull or r.carry < 0:
		return false
	if r.mode != LocalPlayer.Mode.WORLD or r.pos.distance_to(maw_edge()) > StoryRun.GIVE_REACH + 3.0:
		return false
	sim.items.erase(r.carry)
	m.items.erase(r.carry)
	r.carry = -1
	print("[server] %s threw the Heart of Ash into the Maw" % r.name)
	sim._deed(id, "heart")
	crumble()
	for pid in sim._crew_members(r.crew):
		story._say(pid, story._step(m).get("lines", []))
	story._next_step(r.crew)
	return true


## Every skeleton on the sea falls at once.
func crumble() -> void:
	var n := 0
	for sid in sim.skeletons:
		var sk: Skeleton = sim.skeletons[sid]
		if sk.alive() and not sk.crab and not sk.gideon:
			sk.fell = sim.time
			n += 1
	sim.stats.crumbled += n
	Net.send_event("crumble", [])
	Net.send_message(0, "The green light goes out. Every skeleton on the sea crumbles to dust.")


## Everyone near the Reef when the Heart goes in shares the end, whichever crew they sail with.
func share_end(crew: int) -> void:
	for id in sim.players:
		var r: Dictionary = sim.players[id]
		if r.crew == crew:
			continue
		var w := sim._world_pos(r)
		if Vector2(w.x, w.z).distance_to(Reef.CENTRE) < SHARED_REACH:
			r.profile.gold = int(r.profile.gold) + SHARED_GOLD
			sim.profiles.changed(r.name)
			sim._award(id, SHARED_XP, "the end of the Ash Fleet")
			Net.send_message(id, "The Isles are free: %d XP and %d gold." % [SHARED_XP, SHARED_GOLD])


func on_ship_sunk(c: int, m: Dictionary, step: Dictionary, ship_id: int) -> bool:
	if int(step.kind) == Story.Step.ASH_FLAGSHIP and m.ship == ship_id:
		print("[server] crew %d sank the Ash Admiral's flagship" % c)
		m.ship = -1
		for pid in sim._crew_members(c):
			story._say(pid, step.get("lines", []))
		story._next_step(c)
		return true
	return false

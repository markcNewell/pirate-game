class_name StoryRun
extends RefCounted
## Runs the story's chapters on the server (Story holds them as data). A chapter is a crew's
## mission of kind STORY: {"chapter" (index), "step", "objects" (StoryObject ids), "raised"
## (skeletons a step woke), "captain", "skull", "spot" (where the last step left off), ...}.
## ServerSim hands it requests and happenings (a skeleton fell, an item was sold, a ship sank)
## and it moves the steps along; `tick` runs what goes on by itself (risings, fuses, dawn).

const SCOOP_DEPTH := 0.15
const DOUSE_REACH := 2.8
const READ_REACH := 2.6
const SALT_REACH := 2.6
## The dead a green fire wakes stand up this far round it (m).
const RISE_RING := 3.0
## Thieves look for a skull this far off, and give up a boat this close as reached.
const THIEF_SIGHT := 60.0
const BOAT_REACH := 1.2
## A skeleton with a skull in its arms is slower, so you can catch it.
const CARRY_SPEED := 2.3
## A digger's work at an X (s).
const DIG_TIME := 12.0
## Risings (graveyard, bonfire) happen only with a crew member this near (m).
const RISE_NEAR := 60.0
## Powder kegs: the fuse once struck, the blast's reach and hurt, and how far one sets off another.
const FUSE := 1.5
const CHAIN_FUSE := 0.3
const BLAST_REACH := 4.0
const BLAST_DAMAGE := 40
const CHAIN_REACH := 3.0
## The Spanish galleon: how far from the crew it appears, and how much tougher it is.
const GALLEON_DISTANCE := 300.0
const GALLEON_CREW := 5
## Night (time of day, 0 midnight .. 1): dusk when the sun sets, dawn when it rises.
const DUSK := 0.78
const DAWN := 0.24

var sim: ServerSim
var objects := {}  # object id -> StoryObject
var _next_object := 1
## Kegs whose fuse is burning: object id -> server time it goes off.
var _fuses := {}


func _init(server: ServerSim) -> void:
	sim = server


static func is_night(server_time: float) -> bool:
	var t := Daylight.time_of_day(server_time)
	return t >= DUSK or t < DAWN


## Seconds from `server_time` to the next dawn.
static func until_dawn(server_time: float) -> float:
	var t := Daylight.time_of_day(server_time)
	var left := DAWN - t
	if left < 0.0:
		left += 1.0
	return left * Daylight.DAY_LENGTH


# --- starting, talking, finishing -------------------------------------------------------

## Everyone online in a crew: their finished chapters, for Story.open_for and next_for.
func done_lists(crew: int) -> Array:
	var out := []
	for id in sim._crew_members(crew):
		out.append(sim.players[id].profile.chapters)
	return out


func best_level(crew: int) -> int:
	var best := 1
	for id in sim._crew_members(crew):
		best = maxi(best, Progress.level(int(sim.players[id].profile.xp)))
	return best


## E at one of Port Merrow's people: their part in a running chapter, a new chapter, or a word.
func talk(id: int, r: Dictionary, who: String) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or not Story.PEOPLE.has(who) or r.carry >= 0:
		return
	if r.pos.distance_to(Story.person_pos(who)) > Story.TALK_REACH + 1.0:
		return
	var m: Dictionary = sim.crews[r.crew].mission
	if not m.is_empty() and m.kind == Missions.Kind.STORY:
		var step := _step(m)
		if int(step.kind) == Story.Step.TALK and step.who == who:
			_say(id, step.lines)
			_next_step(r.crew)
			return
	var i := Story.offered_by(who, done_lists(r.crew))
	if i < 0:
		_say(id, Story.CHATTER[who])
		return
	var ch: Dictionary = Story.CHAPTERS[i]
	var name := Story.person_name(who)
	if best_level(r.crew) < Progress.ACT_LEVEL[ch.act]:
		_say(id, [name, "Come back with a bit more salt in you. %s is for pirates of level %d." % [Story.ACT_NAMES[ch.act], Progress.ACT_LEVEL[ch.act]]])
		return
	if not m.is_empty():
		_say(id, [name, Story.BUSY])
		return
	if ch.get("night", false) and not is_night(sim.time):
		_say(id, [name, Story.WAIT_FOR_DUSK])
		return
	_say(id, ch.intro)
	start(r.crew, i)


## Start chapter `index` for a crew at step `first` (tests start part-way through).
func start(crew: int, index: int, first := 0) -> void:
	var ch: Dictionary = Story.CHAPTERS[index]
	sim.crews[crew].mission = {
		"kind": Missions.Kind.STORY, "company": -1, "title": ch.title, "chapter": index, "step": first,
		"items": [], "total": 0, "handled": 0, "own": 0, "deadline": -1.0, "captain": -1,
		"name": ch.id, "islands": [], "objects": [], "raised": [], "thieves": [], "skull": -1,
		"spot": Vector3.ZERO, "saved": 0, "next_rise": 0.0, "ship": -1, "captains": [], "left": 0,
	}
	sim.crews[crew].offers = []
	sim.stats.chapters_started += 1
	print("[server] crew %d began chapter %s: %s" % [crew, ch.id, ch.title])
	_enter_step(crew)


func _step(m: Dictionary) -> Dictionary:
	return Story.CHAPTERS[m.chapter].steps[m.step]


func _next_step(crew: int) -> void:
	var m: Dictionary = sim.crews[crew].mission
	_clear_step(m)
	m.step += 1
	if m.step >= Story.CHAPTERS[m.chapter].steps.size():
		_finish(crew)
	else:
		_enter_step(crew)


## Put out what a step needs: a journal, fires, a captain and his thieves, a graveyard...
func _enter_step(crew: int) -> void:
	var m: Dictionary = sim.crews[crew].mission
	var step := _step(m)
	print("[server] crew %d: chapter %s step %d" % [crew, m.name, m.step + 1])
	m.deadline = -1.0
	match int(step.kind):
		Story.Step.TALK:
			m.islands = [Islands.outpost_index()]
		Story.Step.READ:
			_enter_read(crew, step)
		Story.Step.DOUSE:
			var island: int = step.island
			m.islands = [island]
			for n in int(step.fires):
				_add_object(crew, StoryObject.Kind.FIRE, _dry_spot(island), sim._rng.randf() * TAU)
			sim._tell_crew(crew, "Green fire burns on %s. Fill a bucket in the sea and douse it." % Islands.LAYOUT[island].name)
		Story.Step.BOUNTY:
			_raise_bounty(crew, step)
		Story.Step.DIG_RACE:
			_enter_dig_race(crew, step)
		Story.Step.SALT:
			_enter_salt(crew, step)
		Story.Step.KEGS:
			_enter_kegs(crew, step)
		Story.Step.SINK:
			_enter_sink(crew)
		Story.Step.VIGIL:
			_enter_vigil(crew, step)
		Story.Step.BONFIRE:
			_enter_bonfire(crew, step)
		Story.Step.BOSS:
			_enter_boss(crew, step)


func _enter_read(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	match str(step.get("where", "dry")):
		"here":
			var at: Vector3 = m.spot
			m.islands = [maxi(0, Islands.island_at(at.x, at.z, 6.0))]
			_add_object(crew, StoryObject.Kind.BOOK, at + Vector3(0.6, 0, 0.4), sim._rng.randf() * TAU)
		"sea":
			var at: Vector3 = m.spot
			at.y = 0.0
			m.islands = [_nearest_island(at)]
			_add_object(crew, StoryObject.Kind.BOTTLE, at, 0.0)
			sim._tell_crew(crew, "Something bobs in the wreckage: a bottle with a letter in it.")
		_:
			var island: int = step.island
			m.islands = [island]
			_add_object(crew, StoryObject.Kind.BOOK, _dry_spot(island), sim._rng.randf() * TAU)


func _raise_bounty(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	var island: int = step.island
	var spec: Dictionary = Islands.LAYOUT[island]
	m.islands = [island]
	m.skull = -1
	var cap := _raise_captain(crew, island)
	m.captain = cap.id
	for n in int(step.crew):
		var sk := sim._new_skeleton(-1, _dry_spot(island))
		sk.story_crew = crew
		m.raised.append(sk.id)
	if int(step.thieves) > 0:
		var out := (Vector2(spec.x, spec.z) - Vector2(cap.pos.x, cap.pos.z)).normalized()
		if out.length() < 0.5:
			out = Vector2(1, 0)
		var landing := _add_boat(crew, island, out)
		for n in int(step.thieves):
			var sk := _spanish_at(crew, island, landing + Vector3(out.y, 0, -out.x) * (1.5 * (n - 0.5)))
			sk.thief = true
			sk.boat = landing
			m.thieves.append(sk.id)
	sim._tell_crew(crew, "%s walks on %s. Fell her and bring the skull to %s!" % [step.captain, spec.name, Story.person_name(step.to)])


## A captain raised near the middle of an island, counted among the step's dead.
func _raise_captain(crew: int, island: int) -> Skeleton:
	var m: Dictionary = sim.crews[crew].mission
	var spec: Dictionary = Islands.LAYOUT[island]
	var spot := Islands.dig_spot(island, sim._rng)
	spot = Vector2(spec.x, spec.z) + (spot - Vector2(spec.x, spec.z)) * 0.4
	var cap := sim._new_skeleton(-1, Vector3(spot.x, Islands.ground_at(island, spot.x, spot.y), spot.y))
	cap.make_captain()
	cap.story_crew = crew
	m.raised.append(cap.id)
	return cap


## One of the Spanish dead at a point on an island, counted among the step's dead.
func _spanish_at(crew: int, island: int, at: Vector3) -> Skeleton:
	at.y = Islands.ground_at(island, at.x, at.z)
	var sk := sim._new_skeleton(-1, at)
	sk.spanish = true
	sk.story_crew = crew
	sim.crews[crew].mission.raised.append(sk.id)
	return sk


## The Spanish rowing boat drawn up on the beach on the `out` side; returns where its crew
## step ashore.
func _add_boat(crew: int, island: int, out: Vector2) -> Vector3:
	var landing := landing_spot(island, out)
	var boat_at: Vector3 = landing + Vector3(out.x, 0, out.y) * 3.0
	boat_at.y = maxf(Islands.ground_at(island, boat_at.x, boat_at.z) - 0.05, -0.1)
	_add_object(crew, StoryObject.Kind.BOAT, boat_at, atan2(-out.x, -out.y))
	return landing


## Three chests buried on an island, a Spanish digger heading for each from their boat.
func _enter_dig_race(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	var island: int = step.island
	var spec: Dictionary = Islands.LAYOUT[island]
	m.islands = [island]
	m.items = []
	m.saved = 0
	var out := Vector2(1, 0).rotated(sim._rng.randf() * TAU)
	var landing := _add_boat(crew, island, out)
	for n in int(step.chests):
		var spot := Islands.dig_spot(island, sim._rng)
		var gold := sim._rng.randi_range(Missions.CHEST_GOLD.x, Missions.CHEST_GOLD.y)
		var chest := sim._new_item(Loot.Kind.CHEST, Loot.State.BURIED, Vector3(spot.x, Islands.ground_at(island, spot.x, spot.y), spot.y), gold)
		m.items.append(chest.id)
		var sk := _spanish_at(crew, island, landing + Vector3(out.y, 0, -out.x) * (1.2 * (n - 1)))
		sk.digger = true
		sk.thief = true
		sk.target_item = chest.id
		sk.dig_left = DIG_TIME
		sk.boat = landing
		m.thieves.append(sk.id)
	sim._tell_crew(crew, "Spanish diggers have landed on %s! Dig the hoards up first." % spec.name)


## The graveyard's open graves, and salt crates waiting on the pier.
func _enter_salt(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	var island: int = step.island
	m.islands = [island]
	m.next_rise = sim.time + float(step.rise_every)
	for at: Vector3 in graveyard(island, int(step.graves)):
		_add_object(crew, StoryObject.Kind.GRAVE, at, graveyard_yaw(island))
	for n in int(step.graves):
		_salt_crate(crew, n)
	sim._tell_crew(crew, "Three crates of salt wait on Port Merrow's pier for Gull Isle's graves.")


func _salt_crate(crew: int, n: int) -> Loot:
	var crate := sim._new_item(Loot.Kind.CRATE, Loot.State.GROUND, Outpost.cargo_spot(n), 0)
	crate.variant = Missions.SALT
	crate.yaw = 0.1 * n
	sim.crews[crew].mission.items.append(crate.id)
	return crate


## Where an island's old graveyard lies: a row of graves on dry ground, the first `count`.
static func graveyard(island: int, count: int) -> Array[Vector3]:
	var spec: Dictionary = Islands.LAYOUT[island]
	var out: Array[Vector3] = []
	var a := graveyard_yaw(island)
	var centre := Vector2(spec.x, spec.z) + Vector2(cos(a), sin(a)) * float(spec.radius) * 0.35
	var along := Vector2(-sin(a), cos(a))
	for n in count:
		var p := centre + along * (2.4 * (n - (count - 1) * 0.5))
		out.append(Vector3(p.x, Islands.ground_at(island, p.x, p.y), p.y))
	return out


static func graveyard_yaw(island: int) -> float:
	return 0.9 + island * 1.7


## The powder store under its sailcloth, kegs round it, on the island's sunset (west) side.
func _enter_kegs(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	var island: int = step.island
	m.islands = [island]
	var at := powder_store(island)
	m.spot = at
	_add_object(crew, StoryObject.Kind.STORE, at, 0.0)
	for n in int(step.kegs):
		var a := TAU * n / float(step.kegs) + 0.4
		var k := at + Vector3(cos(a) * 1.4, 0, sin(a) * 1.0)
		k.y = Islands.ground_at(island, k.x, k.z)
		_add_object(crew, StoryObject.Kind.KEG, k, a)
	for id in sim._crew_members(crew):
		Net.send_event_to(id, "journal", [step.title, step.text])


static func powder_store(island: int) -> Vector3:
	var spec: Dictionary = Islands.LAYOUT[island]
	var x: float = spec.x - float(spec.radius) * 0.55
	var z: float = spec.z + float(spec.radius) * 0.1
	return Vector3(x, Islands.ground_at(island, x, z), z)


## A Spanish galleon comes out to meet the crew.
func _enter_sink(crew: int) -> void:
	var m: Dictionary = sim.crews[crew].mission
	var id := sim.spawn_galleon(crew, GALLEON_DISTANCE)
	m.ship = id
	m.islands = []
	sim._tell_crew(crew, "Black sails on the horizon: the Admiral's raven!")


## At night: a captain on each island; every skull to Wren before dawn.
func _enter_vigil(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	m.islands = step.islands.duplicate()
	m.captains = []
	m.left = step.islands.size()
	m.deadline = sim.time + until_dawn(sim.time)
	for island: int in step.islands:
		m.captains.append(_raise_captain(crew, island).id)
	sim._tell_crew(crew, "Three captains rise tonight. Their skulls to Wren before dawn!")


## The dig camp on the hill, its green bonfire raising the dead.
func _enter_bonfire(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	var island: int = step.island
	m.islands = [island]
	var at := camp_spot(island)
	m.spot = at
	_add_object(crew, StoryObject.Kind.CAMP, at, 0.3)
	var fire := _add_object(crew, StoryObject.Kind.BONFIRE, at, 0.0)
	fire.state = int(step.buckets)
	m.next_rise = sim.time + 2.0
	sim._tell_crew(crew, "A great green fire burns on %s's hill." % Islands.LAYOUT[island].name)


static func camp_spot(island: int) -> Vector3:
	var spec: Dictionary = Islands.LAYOUT[island]
	var x: float = spec.x + float(spec.radius) * 0.12
	var z: float = spec.z - float(spec.radius) * 0.08
	return Vector3(x, Islands.ground_at(island, x, z), z)


## Sargento Calavera by the dead bonfire, two guards with him.
func _enter_boss(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	var island: int = step.island
	m.islands = [island]
	if m.spot == Vector3.ZERO:
		m.spot = camp_spot(island)
	var has_camp := false
	for oid: int in m.objects:
		has_camp = has_camp or (objects.has(oid) and objects[oid].kind == StoryObject.Kind.CAMP)
	if not has_camp:
		_add_object(crew, StoryObject.Kind.CAMP, m.spot, 0.3)
	# In the open ground of the camp between the bonfire and the gate, clear of the tents.
	var at: Vector3 = m.spot + Vector3(1.5, 0, -2.5)
	var boss := _spanish_at(crew, island, at)
	boss.make_sergeant()
	m.captain = boss.id
	for n in int(step.guards):
		_spanish_at(crew, island, at + Vector3(-1.8 + 3.6 * n, 0, -1.5))
	sim._tell_crew(crew, "%s steps out from behind his shield." % step.boss)


## The last dry ground on a line from an island's centre out along `out`, well up the beach
## (clear of a storm's bigger waves): where a boat's crew would step ashore.
static func landing_spot(island: int, out: Vector2) -> Vector3:
	var spec: Dictionary = Islands.LAYOUT[island]
	var r: float = spec.radius
	while r > 2.0:
		var x: float = spec.x + out.x * r
		var z: float = spec.z + out.y * r
		var g := Islands.ground_at(island, x, z)
		if g > Waves.max_height() + 1.2:
			return Vector3(x, g, z)
		r -= 0.5
	return Vector3(spec.x, Islands.ground_at(island, spec.x, spec.z), spec.z)


## Is a chapter being played out on this island? Its own camp stays asleep meanwhile: the story
## brings its own dead.
func busy_island(island: int) -> bool:
	for c in sim.crews:
		var m: Dictionary = sim.crews[c].mission
		if not m.is_empty() and m.kind == Missions.Kind.STORY and m.islands.has(island) and island != Islands.outpost_index():
			return true
	return false


func _dry_spot(island: int) -> Vector3:
	var s := Islands.dig_spot(island, sim._rng)
	return Vector3(s.x, Islands.ground_at(island, s.x, s.y), s.y)


func _nearest_island(at: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in Islands.LAYOUT.size():
		var spec: Dictionary = Islands.LAYOUT[i]
		var d := Vector2(spec.x - at.x, spec.z - at.z).length()
		if d < best_d:
			best = i
			best_d = d
	return best


func _finish(crew: int) -> void:
	var m: Dictionary = sim.crews[crew].mission
	var ch: Dictionary = Story.CHAPTERS[m.chapter]
	cleanup(m)
	sim.crews[crew].mission = {}
	sim.stats.chapters += 1
	print("[server] crew %d finished chapter %s: %s" % [crew, ch.id, ch.title])
	for id in sim._crew_members(crew):
		var profile: Dictionary = sim.players[id].profile
		if not profile.chapters.has(ch.id):
			profile.chapters.append(ch.id)
		if int(ch.gold) > 0:
			profile.gold = int(profile.gold) + int(ch.gold)
		sim.profiles.changed(profile.name)
		sim._award(id, int(ch.xp), "the chapter " + ch.title)
		# After the XP, so a level gained at the same moment does not take the title's place.
		if ch.has("reward") and not profile.titles.has(ch.reward):
			profile.titles.append(ch.reward)
			profile.title = ch.reward
			Net.send_message(id, "You have earned a title: %s!" % ch.reward)
			sim._update_tag(id)
		sim._send_profile(id)
	sim._tell_crew(crew, "Chapter done: %s" % ch.title)


## Give up a chapter or end it: take back what it put in the world (the dead it raised stay
## until felled, but no longer count for anything; a galleon sails on as a plain enemy).
func cleanup(m: Dictionary) -> void:
	for oid: int in m.get("objects", []):
		objects.erase(oid)
		_fuses.erase(oid)
	m.objects = []
	for sid: int in m.get("thieves", []):
		if sim.skeletons.has(sid):
			sim.skeletons[sid].thief = false
			sim.skeletons[sid].digger = false
	m.thieves = []
	m.raised = []


func _clear_step(m: Dictionary) -> void:
	# Doused fires (cold graves, the dead bonfire) and the dig camp stay until the chapter ends;
	# everything else goes.
	var kept := []
	for oid: int in m.objects:
		if objects.has(oid) and objects[oid].kind in [StoryObject.Kind.FIRE, StoryObject.Kind.BONFIRE, StoryObject.Kind.CAMP]:
			kept.append(oid)
		else:
			objects.erase(oid)
			_fuses.erase(oid)
	m.objects = kept
	m.raised = []
	m.thieves = []
	m.captains = []


func _add_object(crew: int, kind: int, pos: Vector3, yaw: float) -> StoryObject:
	var o := StoryObject.new()
	o.id = _next_object
	_next_object += 1
	o.kind = kind
	o.pos = pos
	o.yaw = yaw
	o.crew = crew
	objects[o.id] = o
	sim.crews[crew].mission.objects.append(o.id)
	return o


func _say(id: int, lines: Array) -> void:
	if lines.size() >= 2:
		Net.send_event_to(id, "talk", lines)


func _mission_of(crew: int) -> Dictionary:
	var m: Dictionary = sim.crews.get(crew, {}).get("mission", {})
	return m if not m.is_empty() and m.kind == Missions.Kind.STORY else {}


# --- what players do ------------------------------------------------------------------

## E on a journal or a bottle: everyone in the crew reads it.
func read(r: Dictionary, object_id: int) -> void:
	var o: StoryObject = objects.get(object_id)
	if o == null or o.kind not in [StoryObject.Kind.BOOK, StoryObject.Kind.BOTTLE] or r.mode != LocalPlayer.Mode.WORLD:
		return
	var reach: float = Vector2(r.pos.x - o.pos.x, r.pos.z - o.pos.z).length() if o.kind == StoryObject.Kind.BOTTLE else r.pos.distance_to(o.pos)
	if reach > READ_REACH + 1.0 or o.crew != r.crew:
		return
	var m: Dictionary = sim.crews[r.crew].mission
	var step := _step(m)
	for id in sim._crew_members(r.crew):
		Net.send_event_to(id, "journal", [step.title, step.text])
	print("[server] %s read %s" % [r.name, step.title])
	sim._tell_crew(r.crew, "%s found %s." % [r.name, "a letter" if o.kind == StoryObject.Kind.BOTTLE else "a journal"])
	_next_step(r.crew)


## E in the shallows: fill the bucket from the sea.
func scoop(r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or r.bucket or r.carry >= 0:
		return
	if Waves.height(r.pos.x, r.pos.z, sim.time) > r.pos.y + SCOOP_DEPTH:
		r.bucket = true


## E at a green fire (or bonfire) with a full bucket: it hisses out, or down a little.
func douse(r: Dictionary, object_id: int) -> void:
	var o: StoryObject = objects.get(object_id)
	if o == null or o.kind not in [StoryObject.Kind.FIRE, StoryObject.Kind.BONFIRE] or o.state <= 0 or not r.bucket:
		return
	var reach := DOUSE_REACH + (2.0 if o.kind == StoryObject.Kind.BONFIRE else 0.0)
	if r.mode != LocalPlayer.Mode.WORLD or r.pos.distance_to(o.pos) > reach + 1.0:
		return
	r.bucket = false
	r.last_bail = sim.time
	o.state = 0 if o.kind == StoryObject.Kind.FIRE else o.state - 1
	sim.stats.doused += 1
	Net.send_event("doused", [o.id, o.pos.x, o.pos.y, o.pos.z, o.state])
	var m := _mission_of(o.crew)
	if m.is_empty():
		return
	print("[server] %s doused a green fire" % r.name)
	if o.kind == StoryObject.Kind.BONFIRE:
		if o.state > 0:
			sim._tell_crew(o.crew, "The bonfire gutters. %d more bucket%s!" % [o.state, "" if o.state == 1 else "s"])
		else:
			sim._tell_crew(o.crew, "The bonfire is out! Now its dead.")
		_check_dead_step(o.crew)
		return
	var step := _step(m)
	var island := Islands.island_at(o.pos.x, o.pos.z)
	for n in int(step.get("rise", 0)):
		var a := TAU * n / maxf(1.0, float(step.rise)) + sim._rng.randf() * 0.5
		var at := o.pos + Vector3(cos(a), 0, sin(a)) * RISE_RING
		var sk := _spanish_at(o.crew, maxi(island, 0), at)
		sk.yaw = atan2(-(r.pos.x - at.x), -(r.pos.z - at.z))
	sim._tell_crew(o.crew, "The fire hisses out, and the dead climb from their graves!")
	_check_dead_step(o.crew)


## E at an open grave with a crate of salt: the crate is used up and the grave sealed.
func salt(r: Dictionary, object_id: int) -> void:
	var o: StoryObject = objects.get(object_id)
	if o == null or o.kind != StoryObject.Kind.GRAVE or o.state != 1 or r.carry < 0:
		return
	var crate: Loot = sim.items.get(r.carry)
	if crate == null or crate.kind != Loot.Kind.CRATE or crate.variant != Missions.SALT:
		return
	if r.mode != LocalPlayer.Mode.WORLD or r.pos.distance_to(o.pos) > SALT_REACH + 1.0:
		return
	var m := _mission_of(o.crew)
	sim.items.erase(crate.id)
	r.carry = -1
	o.state = 0
	sim.stats.salted += 1
	Net.send_event("salted", [o.id, o.pos.x, o.pos.y, o.pos.z])
	print("[server] %s salted a grave" % r.name)
	if not m.is_empty():
		m.items.erase(crate.id)
		sim._tell_crew(o.crew, "The salt hisses on the grave. %d to go." % open_graves(m))
		_check_dead_step(o.crew)


func open_graves(m: Dictionary) -> int:
	var n := 0
	for oid: int in m.get("objects", []):
		if objects.has(oid) and objects[oid].kind == StoryObject.Kind.GRAVE and objects[oid].state == 1:
			n += 1
	return n


## A keg struck by a blade, a shot or a blast: it goes off after its fuse.
func strike_keg(object_id: int, fuse := FUSE) -> void:
	var o: StoryObject = objects.get(object_id)
	if o == null or o.kind != StoryObject.Kind.KEG or o.state != 1:
		return
	o.state = 2
	_fuses[o.id] = sim.time + fuse
	Net.send_event("fuse", [o.id])


## Kegs that may be struck: [object id, position] for ServerSim's attacks.
func kegs() -> Array:
	var out := []
	for id in objects:
		var o: StoryObject = objects[id]
		if o.kind == StoryObject.Kind.KEG and o.state == 1:
			out.append([o.id, o.pos])
	return out


func _explode(o: StoryObject) -> void:
	objects.erase(o.id)
	_fuses.erase(o.id)
	sim.stats.explosions += 1
	print("[server] a powder keg exploded")
	Net.send_event("explode", [o.pos.x, o.pos.y, o.pos.z])
	for id in sim.players.keys():
		var w := sim._world_pos(sim.players[id])
		var d := w.distance_to(o.pos)
		if d < BLAST_REACH:
			sim._hurt_player(id, int(BLAST_DAMAGE * (1.0 - 0.5 * d / BLAST_REACH)), "a powder keg")
	for sid in sim.skeletons.keys():
		var sk: Skeleton = sim.skeletons[sid]
		if sk.alive() and sk.frame < 0 and sk.pos.distance_to(o.pos) < BLAST_REACH:
			sim._hurt_skeleton(sid, int(BLAST_DAMAGE * 1.5), "a powder keg")
	for key in objects.keys():
		var k: StoryObject = objects[key]
		if k.kind == StoryObject.Kind.KEG and k.state == 1 and k.pos.distance_to(o.pos) < CHAIN_REACH:
			strike_keg(k.id, CHAIN_FUSE)
	# The store is gone once its last keg is.
	var m := _mission_of(o.crew)
	if not m.is_empty() and int(_step(m).kind) == Story.Step.KEGS:
		for id in m.objects:
			if objects.has(id) and objects[id].kind == StoryObject.Kind.KEG:
				return
		print("[server] crew %d blew up the powder store" % o.crew)
		sim._tell_crew(o.crew, "The powder store goes up! Something's left in the wreckage.")
		_next_step(o.crew)


# --- happenings ---------------------------------------------------------------------------

## Things that go on by themselves: fuses, the dead rising from graves and the bonfire, dawn.
func tick(_dt: float) -> void:
	for id in _fuses.keys():
		if sim.time >= _fuses[id] and objects.has(id):
			_explode(objects[id])
	for c in sim.crews.keys():
		var m := _mission_of(c)
		if m.is_empty():
			continue
		var step := _step(m)
		match int(step.kind):
			Story.Step.SALT:
				if open_graves(m) > 0:
					_rise_from(c, m, StoryObject.Kind.GRAVE, step, 1)
			Story.Step.BONFIRE:
				_rise_from(c, m, StoryObject.Kind.BONFIRE, step, int(step.rise))
			Story.Step.VIGIL:
				if sim.time > m.deadline:
					print("[server] crew %d: dawn ended the vigil" % c)
					sim._tell_crew(c, "Dawn. The vigil has failed; Wren will try again at dusk.")
					cleanup(m)
					sim.crews[c].mission = {}
		for sid: int in m.get("thieves", []):
			_shield_tick(sid)
		if m.captain >= 0:
			_shield_tick(m.captain)


func _shield_tick(sid: int) -> void:
	var sk: Skeleton = sim.skeletons.get(sid)
	if sk and sk.sergeant and not sk.shield_up and sim.time >= sk.shield_down_until:
		sk.shield_up = true


## Every so often while a crew member is near, the dead climb from a grave or the bonfire.
func _rise_from(crew: int, m: Dictionary, kind: int, step: Dictionary, count: int) -> void:
	if sim.time < m.next_rise:
		return
	m.next_rise = sim.time + float(step.rise_every)
	var sources: Array[StoryObject] = []
	for oid: int in m.objects:
		var o: StoryObject = objects.get(oid)
		if o and o.kind == kind and (o.state == 1 if kind == StoryObject.Kind.GRAVE else o.state > 0):
			sources.append(o)
	if sources.is_empty() or standing(m) >= int(step.max_up):
		return
	var near := false
	for id in sim._crew_members(crew):
		if sim._world_pos(sim.players[id]).distance_to(sources[0].pos) < RISE_NEAR:
			near = true
	if not near:
		return
	var island := Islands.island_at(sources[0].pos.x, sources[0].pos.z)
	for n in mini(count, int(step.max_up) - standing(m)):
		var o: StoryObject = sources[sim._rng.randi() % sources.size()]
		var a := sim._rng.randf() * TAU
		_spanish_at(crew, maxi(island, 0), o.pos + Vector3(cos(a), 0, sin(a)) * (RISE_RING if kind == StoryObject.Kind.BONFIRE else 1.2))
	Net.send_event("risen", [sources[0].pos.x, sources[0].pos.y, sources[0].pos.z])


## A step that ends when its fires are out (or graves salted) and the dead it woke are down.
func _check_dead_step(crew: int) -> void:
	var m := _mission_of(crew)
	if m.is_empty():
		return
	match int(_step(m).kind):
		Story.Step.DOUSE, Story.Step.BONFIRE:
			if lit(m) == 0 and standing(m) == 0:
				print("[server] crew %d put out the green fire and beat its dead" % crew)
				_next_step(crew)
		Story.Step.SALT:
			if open_graves(m) == 0 and standing(m) == 0:
				print("[server] crew %d salted every grave" % crew)
				_next_step(crew)


func lit(m: Dictionary) -> int:
	var n := 0
	for oid: int in m.get("objects", []):
		var o: StoryObject = objects.get(oid)
		if o and o.kind == StoryObject.Kind.FIRE and o.state == 1:
			n += 1
		elif o and o.kind == StoryObject.Kind.BONFIRE:
			n += o.state
	return n


func standing(m: Dictionary) -> int:
	var n := 0
	for sid: int in m.get("raised", []):
		if sim.skeletons.has(sid) and sim.skeletons[sid].alive():
			n += 1
	return n


## A skeleton fell: drop what it held, and count it for its chapter.
func on_skeleton_fell(sk: Skeleton) -> void:
	if sk.holding >= 0 and sim.items.has(sk.holding):
		var item: Loot = sim.items[sk.holding]
		item.state = Loot.State.GROUND
		item.carrier = -1
		item.pos = sk.pos + Vector3(0, 0.05, 0)
		if sk.story_crew > 0:
			sim._tell_crew(sk.story_crew, "The %s tumbles onto the sand!" % item.label())
	sk.holding = -1
	if sk.story_crew <= 0:
		return
	var m := _mission_of(sk.story_crew)
	if m.is_empty():
		return
	if sk.sergeant and m.captain == sk.id:
		print("[server] %s has fallen" % _step(m).boss)
		Net.send_message(0, "%s has fallen!" % _step(m).boss)
		m.spot = sk.pos
		m.captain = -1
		_next_step(sk.story_crew)
		return
	_check_dead_step(sk.story_crew)


## A chapter's captain fell: her skull lies where she fell. True if it was a story captain.
func on_captain_fell(sk: Skeleton) -> bool:
	for c in sim.crews:
		var m := _mission_of(c)
		if m.is_empty() or not (m.captain == sk.id or m.captains.has(sk.id)):
			continue
		var gold := sim._rng.randi_range(Missions.SKULL_GOLD.x, Missions.SKULL_GOLD.y)
		var skull := sim._new_item(Loot.Kind.SKULL, Loot.State.GROUND, sk.pos + Vector3(0, 0.05, 0), gold)
		m.items.append(skull.id)
		sim.stats.skulls += 1
		var step := _step(m)
		var who: String = step.get("captain", "A captain")
		if m.captain == sk.id:
			m.skull = skull.id
			m.captain = -1
		else:
			who = step.captains[m.captains.find(sk.id)]
		print("[server] %s has fallen; her skull is worth %d" % [who, gold])
		Net.send_message(0, "%s has fallen! The skull glows on the sand." % who)
		return true
	return false


## A chapter's item left play: handed in by `by_crew`, or lost (`handed_in` false).
func on_item_done(crew: int, item: Loot, by_crew: int, handed_in: bool) -> void:
	var m: Dictionary = sim.crews[crew].mission
	m.items.erase(item.id)
	var step := _step(m)
	match int(step.kind):
		Story.Step.BOUNTY:
			if m.skull != item.id:
				return
			m.skull = -1
			if handed_in and by_crew == crew:
				_say_near(crew, step.to, step.get("lines", []))
				_next_step(crew)
				return
			# Gone: to the Spanish, the sea or another crew. She rises again.
			sim._tell_crew(crew, "The skull is lost! %s feels %s stirring again on %s." % [
				Story.person_name(step.to), step.captain, Islands.LAYOUT[step.island].name])
			print("[server] crew %d lost the skull of %s" % [crew, step.captain])
			_clear_step(m)
			_enter_step(crew)
		Story.Step.DIG_RACE:
			if handed_in and by_crew == crew:
				m.saved += 1
			var left := 0
			for id: int in m.items:
				if sim.items.has(id) and sim.items[id].kind == Loot.Kind.CHEST:
					left += 1
			if left > 0:
				return
			if m.saved > 0:
				print("[server] crew %d saved %d hoards from the Spanish" % [crew, m.saved])
				_say_near(crew, step.to, step.get("lines", []))
				_next_step(crew)
			else:
				sim._tell_crew(crew, "The Spanish got every chest! Silas has heard of more on %s." % Islands.LAYOUT[step.island].name)
				_clear_step(m)
				_enter_step(crew)
		Story.Step.SALT:
			if item.kind == Loot.Kind.CRATE and not handed_in:
				# Lost at sea: Quill sighs and puts another on the pier.
				sim._tell_crew(crew, "A crate of salt is lost. Quill puts another on the pier.")
				_salt_crate(crew, 0)
		Story.Step.VIGIL:
			if handed_in and by_crew == crew:
				m.left -= 1
				if m.left <= 0:
					_say_near(crew, step.to, step.get("lines", []))
					_next_step(crew)
			else:
				# A skull lost: that captain rises again, wherever she lay.
				sim._tell_crew(crew, "A skull is lost! Its captain will rise again.")
				m.captains.append(_raise_captain(crew, _nearest_island(item.pos)).id)


func _say_near(crew: int, who: String, lines: Array) -> void:
	for id in sim._crew_members(crew):
		if sim.players[id].pos.distance_to(Story.person_pos(who)) < 8.0:
			_say(id, lines)


## A ship went down: the chapter's galleon leaves its letter bobbing where she sank.
func on_ship_sunk(ship_id: int, at: Vector3) -> void:
	for c in sim.crews:
		var m := _mission_of(c)
		if m.is_empty() or m.ship != ship_id:
			continue
		print("[server] crew %d sank the Spanish galleon" % c)
		m.ship = -1
		m.spot = at
		_next_step(c)


## A thief's turn: dig at its X, or go for a skull or chest lying loose, then run it to the
## boat. False to fight instead.
func step_thief(sk: Skeleton, dt: float, floor_at: Callable) -> bool:
	sk.digging = false
	if sk.holding >= 0:
		if not sim.items.has(sk.holding):
			sk.holding = -1
			return false
		var item: Loot = sim.items[sk.holding]
		var left := sk.walk_to(sk.boat, dt, floor_at, CARRY_SPEED)
		item.pos = sk.pos
		if left < BOAT_REACH:
			print("[server] a Spanish skeleton reached its boat with the %s" % item.label())
			sim.stats.thefts += 1
			sim.items.erase(item.id)
			sim.skeletons.erase(sk.id)
			sim._mission_item_done(item, 0, false)
		return true
	var m := _mission_of(sk.story_crew)
	if m.is_empty():
		return false
	# A digger works at its X while the chest is still in the ground.
	if sk.digger and sim.items.has(sk.target_item) and sim.items[sk.target_item].state == Loot.State.BURIED:
		var chest: Loot = sim.items[sk.target_item]
		if sk.walk_to(chest.pos, dt, floor_at) < 1.2:
			sk.walking = false
			sk.digging = true
			sk.dig_left -= dt
			if sk.dig_left <= 0.0:
				chest.state = Loot.State.HELD
				chest.carrier = sk.id
				chest.pos.y = Islands.ground_at(maxi(0, Islands.island_at(chest.pos.x, chest.pos.z)), chest.pos.x, chest.pos.z)
				sk.holding = chest.id
				sk.digging = false
				print("[server] a Spanish digger dug up a chest")
				sim._tell_crew(sk.story_crew, "A Spanish digger has a chest! Stop it before it reaches the boat!")
		return true
	# Anything of the chapter's lying loose nearby: a skull, or a chest someone dug and left.
	var best: Loot = null
	var best_d := THIEF_SIGHT
	for id: int in m.items:
		var it: Loot = sim.items.get(id)
		if it == null or it.state != Loot.State.GROUND or it.kind not in [Loot.Kind.SKULL, Loot.Kind.CHEST]:
			continue
		var d := Vector2(it.pos.x - sk.pos.x, it.pos.z - sk.pos.z).length()
		if d < best_d:
			best = it
			best_d = d
	if best == null:
		return false
	if sk.walk_to(best.pos, dt, floor_at) < 1.0:
		best.state = Loot.State.HELD
		best.carrier = sk.id
		sk.holding = best.id
		print("[server] a Spanish skeleton grabbed the %s" % best.label())
		sim._tell_crew(sk.story_crew, "A Spanish skeleton has the %s! Stop it before it reaches the boat!" % best.label())
	return true


# --- what clients see -------------------------------------------------------------------

## Map targets [island, x, z, done] for the step under way.
func targets(m: Dictionary) -> Array:
	var step := _step(m)
	var out := []
	match int(step.kind):
		Story.Step.TALK:
			var at := Story.person_pos(step.who)
			out.append_array([Islands.outpost_index(), at.x, at.z, 0])
		Story.Step.READ, Story.Step.DOUSE, Story.Step.SALT, Story.Step.BONFIRE:
			for oid: int in m.objects:
				var o: StoryObject = objects.get(oid)
				if o and o.kind != StoryObject.Kind.CAMP:
					var done := (o.kind == StoryObject.Kind.FIRE or o.kind == StoryObject.Kind.GRAVE) and o.state == 0
					out.append_array([m.islands[0] if not m.islands.is_empty() else _nearest_island(o.pos), o.pos.x, o.pos.z, 1 if done else 0])
		Story.Step.BOUNTY, Story.Step.KEGS, Story.Step.BOSS:
			var spec: Dictionary = Islands.LAYOUT[step.island]
			out.append_array([step.island, spec.x, spec.z, 0])
		Story.Step.DIG_RACE:
			for id: int in m.items:
				var it: Loot = sim.items.get(id)
				if it:
					out.append_array([step.island, it.pos.x, it.pos.z, 0 if it.state == Loot.State.BURIED else 1])
		Story.Step.VIGIL:
			for k in step.islands.size():
				var spec: Dictionary = Islands.LAYOUT[step.islands[k]]
				out.append_array([step.islands[k], spec.x, spec.z, 0])
		Story.Step.SINK:
			var s: ShipState = sim.ships.get(m.ship)
			if s:
				out.append_array([_nearest_island(Vector3(s.x, 0, s.z)), s.x, s.z, 0])
	return out


## The card's two counts for the step: [the main count, the dead standing].
func counts(m: Dictionary) -> Array:
	var step := _step(m)
	match int(step.kind):
		Story.Step.DIG_RACE:
			var buried := 0
			for id: int in m.items:
				if sim.items.has(id) and sim.items[id].state == Loot.State.BURIED:
					buried += 1
			return [buried, standing(m)]
		Story.Step.SALT:
			return [open_graves(m), standing(m)]
		Story.Step.VIGIL:
			return [m.left, standing(m)]
	return [lit(m), standing(m)]


## The board's story line for a crew: [-1, STORY, act, title, 0, 0, what to do], or [].
func board_entry(crew: int) -> Array:
	var i := Story.next_for(done_lists(crew))
	if i < 0:
		return []
	var ch: Dictionary = Story.CHAPTERS[i]
	var text := "Speak to %s at Port Merrow" % Story.person_name(ch.giver)
	if best_level(crew) < Progress.ACT_LEVEL[ch.act]:
		text = "%s opens at pirate level %d" % [Story.ACT_NAMES[ch.act], Progress.ACT_LEVEL[ch.act]]
	elif ch.get("night", false):
		text += " after dark"
	return [-1, Missions.Kind.STORY, ch.act, ch.title, 0, 0, text]

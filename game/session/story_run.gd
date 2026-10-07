class_name StoryRun
extends RefCounted
## Runs the story's chapters on the server (Story holds them as data). A chapter is a crew's
## mission of kind STORY: {"chapter" (index), "step", "objects" (StoryObject ids), "raised"
## (skeletons a step woke), "captain", "skull", ...}. ServerSim hands it requests and happenings
## (a skeleton fell, a skull was sold) and it moves the steps along.

const SCOOP_DEPTH := 0.15
const DOUSE_REACH := 2.8
const READ_REACH := 2.6
## The dead a green fire wakes stand up this far round it (m).
const RISE_RING := 3.0
## Thieves look for a skull this far off, and give up a boat this close as reached.
const THIEF_SIGHT := 60.0
const BOAT_REACH := 1.2
## A skeleton with a skull in its arms is slower, so you can catch it.
const CARRY_SPEED := 2.3

var sim: ServerSim
var objects := {}  # object id -> StoryObject
var _next_object := 1


func _init(server: ServerSim) -> void:
	sim = server


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
	if best_level(r.crew) < Progress.ACT_LEVEL[ch.act]:
		_say(id, [Story.person_name(who), "Come back with a bit more salt in you. %s is for pirates of level %d." % [Story.ACT_NAMES[ch.act], Progress.ACT_LEVEL[ch.act]]])
		return
	if not m.is_empty():
		_say(id, [Story.person_name(who), Story.BUSY])
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


## Put out what a step needs: a journal, a fire, a captain and his thieves.
func _enter_step(crew: int) -> void:
	var m: Dictionary = sim.crews[crew].mission
	var step := _step(m)
	print("[server] crew %d: chapter %s step %d" % [crew, m.name, m.step + 1])
	match int(step.kind):
		Story.Step.TALK:
			m.islands = [Islands.outpost_index()]
		Story.Step.READ:
			var island: int = step.island
			m.islands = [island]
			var spot := _dry_spot(island)
			_add_object(crew, StoryObject.Kind.BOOK, spot, sim._rng.randf() * TAU)
		Story.Step.DOUSE:
			var island: int = step.island
			m.islands = [island]
			for n in int(step.fires):
				_add_object(crew, StoryObject.Kind.FIRE, _dry_spot(island), sim._rng.randf() * TAU)
			sim._tell_crew(crew, "Green fire burns on %s. Fill a bucket in the sea and douse it." % Islands.LAYOUT[island].name)
		Story.Step.BOUNTY:
			_raise_bounty(crew, step)


func _raise_bounty(crew: int, step: Dictionary) -> void:
	var m: Dictionary = sim.crews[crew].mission
	var island: int = step.island
	var spec: Dictionary = Islands.LAYOUT[island]
	m.islands = [island]
	m.skull = -1
	var spot := Islands.dig_spot(island, sim._rng)
	spot = Vector2(spec.x, spec.z) + (spot - Vector2(spec.x, spec.z)) * 0.4
	var cap := sim._new_skeleton(-1, Vector3(spot.x, Islands.ground_at(island, spot.x, spot.y), spot.y))
	cap.make_captain()
	cap.story_crew = crew
	m.captain = cap.id
	m.raised.append(cap.id)
	for n in int(step.crew):
		var s := _dry_spot(island)
		var sk := sim._new_skeleton(-1, s)
		sk.story_crew = crew
		m.raised.append(sk.id)
	if int(step.thieves) > 0:
		# Their boat drawn up on the beach, on the side away from the captain.
		var out := (Vector2(spec.x, spec.z) - spot).normalized()
		if out.length() < 0.5:
			out = Vector2(1, 0)
		var landing := landing_spot(island, out)
		var boat_at: Vector3 = Vector3(spec.x, 0, spec.z) + Vector3(out.x, 0, out.y) * (float(spec.radius) + 0.5)
		boat_at.y = 0.0
		_add_object(crew, StoryObject.Kind.BOAT, boat_at, atan2(-out.x, -out.y))
		for n in int(step.thieves):
			var at := landing + Vector3(out.y, 0, -out.x) * (1.5 * (n - 0.5))
			at.y = Islands.ground_at(island, at.x, at.z)
			var sk := sim._new_skeleton(-1, at)
			sk.spanish = true
			sk.thief = true
			sk.boat = landing
			sk.story_crew = crew
			m.raised.append(sk.id)
			m.thieves.append(sk.id)
	sim._tell_crew(crew, "%s walks on %s. Fell her and bring the skull to %s!" % [step.captain, spec.name, Story.person_name(step.to)])


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


func _dry_spot(island: int) -> Vector3:
	var s := Islands.dig_spot(island, sim._rng)
	return Vector3(s.x, Islands.ground_at(island, s.x, s.y), s.y)


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
		sim._send_profile(id)
	sim._tell_crew(crew, "Chapter done: %s" % ch.title)


## Take back what a chapter put in the world (the dead it raised stay until felled, but no
## longer count for anything).
func cleanup(m: Dictionary) -> void:
	for oid: int in m.get("objects", []):
		objects.erase(oid)
	m.objects = []
	for sid: int in m.get("thieves", []):
		if sim.skeletons.has(sid):
			sim.skeletons[sid].thief = false
	m.thieves = []
	m.raised = []


func _clear_step(m: Dictionary) -> void:
	for oid: int in m.objects:
		if objects.has(oid) and objects[oid].kind != StoryObject.Kind.FIRE:
			objects.erase(oid)
	# Doused fires stay as cold graves until the chapter ends.
	var kept := []
	for oid: int in m.objects:
		if objects.has(oid):
			kept.append(oid)
	m.objects = kept
	m.raised = []
	m.thieves = []


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
	Net.send_event_to(id, "talk", lines)


# --- what players do ------------------------------------------------------------------

## E on a journal: everyone in the crew reads it.
func read(r: Dictionary, object_id: int) -> void:
	var o: StoryObject = objects.get(object_id)
	if o == null or o.kind != StoryObject.Kind.BOOK or r.mode != LocalPlayer.Mode.WORLD:
		return
	if r.pos.distance_to(o.pos) > READ_REACH + 1.0 or o.crew != r.crew:
		return
	var m: Dictionary = sim.crews[r.crew].mission
	var step := _step(m)
	for id in sim._crew_members(r.crew):
		Net.send_event_to(id, "journal", [step.title, step.text])
	print("[server] %s read %s" % [r.name, step.title])
	sim._tell_crew(r.crew, "%s found a journal." % r.name)
	_next_step(r.crew)


## E in the shallows: fill the bucket from the sea.
func scoop(r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or r.bucket or r.carry >= 0:
		return
	if Waves.height(r.pos.x, r.pos.z, sim.time) > r.pos.y + SCOOP_DEPTH:
		r.bucket = true


## E at a green fire with a full bucket: it hisses out, and the dead it was raising stand up.
func douse(r: Dictionary, object_id: int) -> void:
	var o: StoryObject = objects.get(object_id)
	if o == null or o.kind != StoryObject.Kind.FIRE or o.state == 0 or not r.bucket:
		return
	if r.mode != LocalPlayer.Mode.WORLD or r.pos.distance_to(o.pos) > DOUSE_REACH + 1.0:
		return
	r.bucket = false
	r.last_bail = sim.time
	o.state = 0
	sim.stats.doused += 1
	Net.send_event("doused", [o.id, o.pos.x, o.pos.y, o.pos.z])
	var m: Dictionary = sim.crews[o.crew].mission
	if m.is_empty() or m.kind != Missions.Kind.STORY:
		return
	var step := _step(m)
	print("[server] %s doused a green fire" % r.name)
	var island := Islands.island_at(o.pos.x, o.pos.z)
	for n in int(step.get("rise", 0)):
		var a := TAU * n / maxf(1.0, float(step.rise)) + sim._rng.randf() * 0.5
		var x := o.pos.x + cos(a) * RISE_RING
		var z := o.pos.z + sin(a) * RISE_RING
		var g := Islands.ground_at(island, x, z) if island >= 0 else o.pos.y
		var sk := sim._new_skeleton(-1, Vector3(x, maxf(g, o.pos.y - 1.0), z))
		sk.spanish = true
		sk.story_crew = o.crew
		sk.yaw = atan2(-(r.pos.x - x), -(r.pos.z - z))
		m.raised.append(sk.id)
	sim._tell_crew(o.crew, "The fire hisses out, and the dead climb from their graves!")
	_check_douse(o.crew)


## A douse step is done once its fires are out and the dead they woke are down.
func _check_douse(crew: int) -> void:
	var m: Dictionary = sim.crews[crew].mission
	if m.is_empty() or m.kind != Missions.Kind.STORY or int(_step(m).kind) != Story.Step.DOUSE:
		return
	if lit(m) == 0 and standing(m) == 0:
		print("[server] crew %d put out the green fire and beat its dead" % crew)
		_next_step(crew)


func lit(m: Dictionary) -> int:
	var n := 0
	for oid: int in m.get("objects", []):
		if objects.has(oid) and objects[oid].kind == StoryObject.Kind.FIRE and objects[oid].state == 1:
			n += 1
	return n


func standing(m: Dictionary) -> int:
	var n := 0
	for sid: int in m.get("raised", []):
		if sim.skeletons.has(sid) and sim.skeletons[sid].alive():
			n += 1
	return n


# --- happenings ---------------------------------------------------------------------------

## A skeleton fell: drop what it held, and count it for its chapter.
func on_skeleton_fell(sk: Skeleton) -> void:
	if sk.holding >= 0 and sim.items.has(sk.holding):
		var item: Loot = sim.items[sk.holding]
		item.state = Loot.State.GROUND
		item.carrier = -1
		item.pos = sk.pos + Vector3(0, 0.05, 0)
		if sk.story_crew > 0:
			sim._tell_crew(sk.story_crew, "The skull tumbles onto the sand!")
	sk.holding = -1
	if sk.story_crew > 0:
		_check_douse(sk.story_crew)


## A chapter's captain fell: her skull lies where she fell. True if it was a story captain.
func on_captain_fell(sk: Skeleton) -> bool:
	for c in sim.crews:
		var m: Dictionary = sim.crews[c].mission
		if m.is_empty() or m.kind != Missions.Kind.STORY or m.captain != sk.id:
			continue
		var gold := sim._rng.randi_range(Missions.SKULL_GOLD.x, Missions.SKULL_GOLD.y)
		var skull := sim._new_item(Loot.Kind.SKULL, Loot.State.GROUND, sk.pos + Vector3(0, 0.05, 0), gold)
		m.items.append(skull.id)
		m.skull = skull.id
		m.captain = -1
		sim.stats.skulls += 1
		var step := _step(m)
		print("[server] %s has fallen; her skull is worth %d" % [step.captain, gold])
		Net.send_message(0, "%s has fallen! Her skull glows on the sand." % step.captain)
		return true
	return false


## A chapter's item left play: handed in by `by_crew`, or lost (`handed_in` false).
func on_item_done(crew: int, item: Loot, by_crew: int, handed_in: bool) -> void:
	var m: Dictionary = sim.crews[crew].mission
	m.items.erase(item.id)
	if m.skull != item.id:
		return
	m.skull = -1
	var step := _step(m)
	if handed_in and by_crew == crew:
		for id in sim._crew_members(crew):
			if sim.players[id].pos.distance_to(Story.person_pos(step.to)) < 8.0:
				_say(id, step.get("lines", []))
		_next_step(crew)
		return
	# Gone: to the Spanish, the sea or another crew. The chapter goes back a step: she rises again.
	sim._tell_crew(crew, "The skull is lost! %s feels %s stirring again on %s." % [
		Story.person_name(step.to), step.captain, Islands.LAYOUT[step.island].name])
	print("[server] crew %d lost the skull of %s" % [crew, step.captain])
	_clear_step(m)
	_enter_step(crew)


## A thief's turn: go for a skull lying loose, then run it to the boat. False to fight instead.
func step_thief(sk: Skeleton, dt: float, floor_at: Callable) -> bool:
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
	var m: Dictionary = sim.crews.get(sk.story_crew, {}).get("mission", {})
	if m.is_empty() or int(m.get("skull", -1)) < 0 or not sim.items.has(m.skull):
		return false
	var skull: Loot = sim.items[m.skull]
	if skull.state != Loot.State.GROUND or Vector2(skull.pos.x - sk.pos.x, skull.pos.z - sk.pos.z).length() > THIEF_SIGHT:
		return false
	if sk.walk_to(skull.pos, dt, floor_at) < 1.0:
		skull.state = Loot.State.HELD
		skull.carrier = sk.id
		sk.holding = skull.id
		print("[server] a Spanish skeleton grabbed the skull")
		sim._tell_crew(sk.story_crew, "A Spanish skeleton has the skull! Stop it before it reaches the boat!")
	return true


# --- what clients see -------------------------------------------------------------------

## [chapter id, step, fires lit, dead standing] plus map targets [island, x, z, done] for the
## step under way.
func targets(m: Dictionary) -> Array:
	var step := _step(m)
	var out := []
	match int(step.kind):
		Story.Step.TALK:
			var at := Story.person_pos(step.who)
			out.append_array([Islands.outpost_index(), at.x, at.z, 0])
		Story.Step.READ, Story.Step.DOUSE:
			for oid: int in m.objects:
				var o: StoryObject = objects.get(oid)
				if o:
					out.append_array([step.island, o.pos.x, o.pos.z, 1 if o.kind == StoryObject.Kind.FIRE and o.state == 0 else 0])
		Story.Step.BOUNTY:
			var spec: Dictionary = Islands.LAYOUT[step.island]
			out.append_array([step.island, spec.x, spec.z, 0])
	return out


## The board's story line for a crew: [-1, STORY, act, title, 0, 0, what to do], or [].
func board_entry(crew: int) -> Array:
	var i := Story.next_for(done_lists(crew))
	if i < 0:
		return []
	var ch: Dictionary = Story.CHAPTERS[i]
	var text := "Speak to %s at Port Merrow" % Story.person_name(ch.giver)
	if best_level(crew) < Progress.ACT_LEVEL[ch.act]:
		text = "%s opens at pirate level %d" % [Story.ACT_NAMES[ch.act], Progress.ACT_LEVEL[ch.act]]
	return [-1, Missions.Kind.STORY, ch.act, ch.title, 0, 0, text]

class_name ServerSim
extends RefCounted
## The authoritative world, run only on the server (dedicated or host): the ships and their
## damage, the skeleton captains, cannonballs in flight, the crew list and what each player
## is doing. Game feeds it ticks and player messages; it answers through Net.

## The first crew's ship id. Crew ships take their crew's number (1-4) as their id;
## skeleton ships are numbered from 10.
const CREW := 1
const MAX_CREWS := 4
const CREW_SIZE := 4
const CREW_NAMES := ["The Salty Maiden", "The Crimson Wren", "The Blue Petrel", "The Green Gull"]
const CREW_SPAWNS := [Vector2(0, 0), Vector2(180, 120), Vector2(-180, 120), Vector2(0, 260)]
## Test hook: crews start within boarding distance of each other.
const CREW_SPAWNS_CLOSE := [Vector2(0, 0), Vector2(45, 0), Vector2(-45, 0), Vector2(0, 45)]
const EMPTY_CREW_TIMEOUT := 60.0
const STATION_INPUT_TIMEOUT := 0.5
const MAX_PLAYER_SPEED := 15.0
const LADDER_TOLERANCE := 6.0
const HATCH_REACH := 2.6
const PATCH_REACH := 2.6
const PATCH_TIME := 2.0
const BUCKET := 0.06
const MAX_HOLES := 12
const PLAYER_RELOAD := 3.0
const CREW_RESPAWN_DELAY := 10.0
const AI_FIRST_DELAY := 60.0
const AI_RESPAWN_DELAY := 90.0
const AI_SPAWN_DISTANCE := 450.0
## Ships closer than this (between any of bow, middle and stern) are pushed apart.
const SHIP_CONTACT := 6.5
const ITEM_REACH := 3.0
const DIG_REACH := 3.0
const DIG_TIME := 2.0
const SELL_REACH := 4.0
const RESTOCK_SHIP_RANGE := 80.0
const OPEN_SHIP_RANGE := 60.0
const BARREL_BALLS := 15
const BARREL_PLANKS := 8
const MAP_TABLE_REACH := 3.0
const HEALTH := 100
const GHOST_TIME := 8.0
const BANANA_HEAL := 50
const EAT_REACH := 2.2
const CAMP_SIZE := 3
const CAMP_WAKE := 80.0
const CAMP_RESPAWN := 180.0
const SHIP_SKELETONS := 3
const ATTACK_SLACK := 0.1

var time := 0.0
var ships := {}  # ship id -> ShipState
var captains := {}  # ship id -> Captain (skeleton ships only)
var players := {}  # peer id -> record (see add_player)
var roster := {}  # peer id -> name
## Crews by number (1-4): {"purse", "voyage" ({} or {island, x, z, item}), "respawn_at", "empty_since"}.
var crews := {}
var station_owner := {}  # ship id * 100 + station id -> peer id
var station_input := {}  # peer id -> {axes, aim, time}
var projectiles: Array[Dictionary] = []
var stats := {
	"max_speed": 0.0, "stations_taken": 0, "climbs": 0, "corrections": 0, "shots": 0,
	"hits": 0, "holes": 0, "patched": 0, "bailed": 0, "ai_spawned": 0, "ai_sunk": 0, "crew_sunk": 0,
	"voyages": 0, "dug": 0, "sold": 0, "restocked": 0, "loot_spawned": 0, "stowed": 0,
	"kills": 0, "falls": 0, "eaten": 0, "boarded": 0, "skeleton_swings": 0, "pvp_falls": 0, "stolen": 0,
}
var items := {}  # item id -> Loot
## Test hook: the island the next voyage goes to (-1 for random).
var options_island := -1
var _next_item := 1
var skeletons := {}  # skeleton id -> Skeleton
var camps := {}  # island index -> {"alive": int, "wake": time it may next wake}
var _next_skeleton := 1
var _passive := {}  # skeleton ships that only sit there (tests)

var ai_enabled := true
var next_ai_time := AI_FIRST_DELAY
var _next_ship_id := 10
var _spawns: Array = CREW_SPAWNS
var _next_projectile := 1
var _evacuated := {}
var _pending_bail := {}
var _stations := ShipShape.stations()
var _rng := RandomNumberGenerator.new()


func _init(options: Dictionary = {}) -> void:
	_rng.seed = 12345
	ai_enabled = not options.get("no-ai", false)
	next_ai_time = float(options.get("ai-delay", AI_FIRST_DELAY))
	if options.has("crews-close"):
		_spawns = CREW_SPAWNS_CLOSE
	_ensure_crew(CREW)
	# Test hooks: start near an island or the outpost, with a chest aboard.
	if options.has("voyage-island"):
		options_island = int(options["voyage-island"])
	if options.has("start-near"):
		var where := str(options["start-near"])
		var spot := Outpost.anchorage() if where == "outpost" else _anchorage(int(where))
		crew_ship().x = spot.x
		crew_ship().z = spot.z
		crew_ship().yaw = Captain.bearing(Vector2(spot.x, spot.z), _island_xz(where))
	if options.has("test-boarding"):
		_spawn_passive_skeleton_ship()
	if options.has("test-chest"):
		_new_item(Loot.Kind.CHEST, Loot.State.ON_SHIP, Vector3(-1.2, ShipShape.DECK_Y, -2.2), 250).ship = CREW
	if options.has("test-steal"):
		# Crew 2 starts with a chest on its deck for crew 1 to steal (and stays put meanwhile).
		_ensure_crew(2)
		crews[2].pinned = true
		_new_item(Loot.Kind.CHEST, Loot.State.ON_SHIP, Vector3(-1.2, ShipShape.DECK_Y, -2.2), 300).ship = 2
	# Test hook: start with this many holes in the crew's ship.
	for i in int(options.get("test-holes", 0)):
		var h := ShipShape.hole_point(Vector3(1.0 if i % 2 == 0 else -1.0, 0.0, -6.0 + i * 1.5))
		crew_ship().holes.append([crew_ship().next_hole_id, h.x, h.y, h.z, 0.0])
		crew_ship().next_hole_id += 1


## A crew's ship (crew 1 by default).
func crew_ship(crew := CREW) -> ShipState:
	return ships.get(crew)


## The ship belonging to a player's crew.
func _own(r: Dictionary) -> ShipState:
	return ships.get(r.crew)


func _ensure_crew(crew: int) -> void:
	if crews.has(crew):
		return
	crews[crew] = {"purse": 0, "voyage": {}, "respawn_at": -1.0, "empty_since": -1.0, "pinned": false}
	_launch_crew_ship(crew)


func _launch_crew_ship(crew: int) -> void:
	var s := ShipState.new()
	s.crew = crew
	var spot: Vector2 = _spawns[crew - 1]
	s.x = spot.x
	s.z = spot.y
	ships[crew] = s
	_evacuated.erase(crew)
	for key in station_owner.keys():
		if key / 100 == crew:
			station_owner.erase(key)


func _crew_members(crew: int) -> Array:
	var out := []
	for id in players:
		if players[id].crew == crew:
			out.append(id)
	return out


func _tell_crew(crew: int, text: String) -> void:
	for id in _crew_members(crew):
		Net.send_message(id, text)


## A crew's view of the purse and voyage, for its own members' HUDs.
func crew_name(crew: int) -> String:
	return CREW_NAMES[crew - 1]


# =====================================================================================
# Ticking
# =====================================================================================

func tick(dt: float) -> void:
	time += dt
	var wind := Game.wind_dir(time)
	_maybe_spawn_skeleton()
	_maybe_respawn_crews()
	_retire_empty_crews()

	for id in ships.keys():
		var s: ShipState = ships[id]
		var c := _crew_controls(id) if crews.has(id) else ShipControls.new()
		if captains.has(id) and not s.is_sinking() and not _passive.has(id):
			var orders: Array = captains[id].think(s, _nearest_crew_ship(s), wind, time, dt, Islands.LAYOUT, c)
			for shot: Dictionary in orders:
				_fire(id, shot.gun, shot.yaw, shot.pitch, Captain.RELOAD + _rng.randf())
		c.bail += _pending_bail.get(id, 0.0)
		_pending_bail.erase(id)
		ShipPhysics.step(s, c, wind, dt, Islands.ship_blockers())
	stats.max_speed = maxf(stats.max_speed, crew_ship().speed)

	_separate_ships()
	_step_projectiles()
	_handle_sinking()
	_step_items(dt)
	_wake_camps()
	_step_skeletons(dt)
	_step_ghosts()


func _crew_controls(ship_id: int) -> ShipControls:
	var c := ShipControls.new()
	for key in station_owner:
		if key / 100 != ship_id:
			continue
		var id: int = key % 100
		var peer: int = station_owner[key]
		var input: Dictionary = station_input.get(peer, {})
		if input.is_empty() or time - input.time > STATION_INPUT_TIMEOUT:
			continue
		var axes: Vector2 = input.axes
		var st: Dictionary = _stations[id]
		match st.kind:
			ShipShape.Kind.WHEEL:
				c.wheel = axes.x
			ShipShape.Kind.SAILS:
				c.sail_raise[st.mast] = axes.y
				c.sail_turn[st.mast] = axes.x
			ShipShape.Kind.ANCHOR:
				c.anchor_winch = axes.y > 0.5
				c.anchor_drop = axes.y < -0.5
	return c


func snapshot() -> Array:
	var ship_list := []
	for id in ships:
		ship_list.append([id, ships[id].to_array()])
	var list := []
	for id in players:
		var r: Dictionary = players[id]
		list.append([
			id, r.mode, r.ship, r.pos.x, r.pos.y, r.pos.z, r.yaw, r.pitch, r.station, 1 if r.bucket else 0,
			r.carry, r.hp, 1 if r.dead_until >= 0.0 else 0, r.weapon, r.crew,
		])
	var item_list := []
	for id in items:
		var item: Loot = items[id]
		if item.state != Loot.State.BURIED:
			item_list.append(item.to_array())
	var crew_list := []
	for c in crews:
		var v: Dictionary = crews[c].voyage
		crew_list.append([c, crews[c].purse] + ([] if v.is_empty() else [v.island, v.x, v.z]))
	var bones := []
	for id in skeletons:
		bones.append(skeletons[id].to_array())
	return [time, ship_list, list, item_list, crew_list, bones]


func log_line() -> String:
	var s := crew_ship()
	var skel := ""
	for id in captains:
		var k: ShipState = ships[id]
		skel += " skeleton%d=(%.0f, %.0f, water %.2f, holes %d)" % [id, k.x, k.z, k.water, k.leaks()]
	return "t=%.0f players=%d ship=(%.1f, %.1f) speed=%.2f anchored=%s sails=%.2f/%.2f water=%.2f holes=%d stations=%s%s" % [
		time, players.size(), s.x, s.z, s.speed, s.anchored, s.sail_height[0], s.sail_height[1],
		s.water, s.leaks(), station_owner, skel,
	]


# =====================================================================================
# Skeleton ships and the crew's ship coming back
# =====================================================================================

## The nearest crew ship afloat (what a skeleton captain hunts), or null.
func _nearest_crew_ship(from: ShipState) -> ShipState:
	var best: ShipState = null
	var best_d := INF
	for c in crews:
		var s: ShipState = ships.get(c)
		if s == null or s.is_sinking():
			continue
		var d := Vector2(s.x - from.x, s.z - from.z).length()
		if d < best_d:
			best = s
			best_d = d
	return best


func _maybe_spawn_skeleton() -> void:
	if not ai_enabled or time < next_ai_time or not captains.is_empty():
		return
	# Hunt a crew that has players aboard.
	var targets := []
	for c in crews:
		if not _crew_members(c).is_empty() and ships.has(c) and not ships[c].is_sinking():
			targets.append(c)
	if targets.is_empty():
		return
	var crew: ShipState = ships[targets[_rng.randi() % targets.size()]]
	var origin := Vector2(crew.x, crew.z)
	var spot := origin
	for attempt in 12:
		var angle := _rng.randf() * TAU
		spot = origin + Vector2(cos(angle), sin(angle)) * AI_SPAWN_DISTANCE
		var clear := true
		for island in Islands.LAYOUT:
			if spot.distance_to(Vector2(island.x, island.z)) < island.radius + 80.0:
				clear = false
		if clear:
			break
	var s := ShipState.new()
	s.kind = ShipState.Kind.SKELETON
	s.x = spot.x
	s.z = spot.y
	s.yaw = Captain.bearing(spot, origin)
	s.anchored = false
	s.sail_height = [1.0, 1.0]
	s.speed = 4.0
	var id := _next_ship_id
	_next_ship_id += 1
	ships[id] = s
	captains[id] = Captain.new(id)
	_crew_skeleton_ship(id)
	stats.ai_spawned += 1
	var from := spot - origin
	print("[server] skeleton ship %d spawned at (%.0f, %.0f)" % [id, spot.x, spot.y])
	Net.send_message(0, "A skeleton ship approaches from the %s!" % compass_name(atan2(from.x, -from.y)))


func _maybe_respawn_crews() -> void:
	for c in crews:
		var crew: Dictionary = crews[c]
		if crew.respawn_at < 0.0 or time < crew.respawn_at:
			continue
		crew.respawn_at = -1.0
		_launch_crew_ship(c)
		print("[server] the crew's ship is back (crew %d)" % c)
		_tell_crew(c, "The ship is back. All hands on deck!")
		for id in _crew_members(c):
			players[id].station = -1
			players[id].bucket = false
			if players[id].dead_until < 0.0:
				_teleport(id, LocalPlayer.Mode.ON_SHIP, _free_spawn(id), 0.0)


## A crew with nobody left in it loses its ship after a while (crew 1 always stays).
func _retire_empty_crews() -> void:
	for c in crews.keys():
		if c == CREW:
			continue
		var crew: Dictionary = crews[c]
		if not _crew_members(c).is_empty() or crew.pinned:
			crew.empty_since = -1.0
			continue
		if crew.empty_since < 0.0:
			crew.empty_since = time
		elif time - crew.empty_since > EMPTY_CREW_TIMEOUT:
			if ships.has(c):
				_evacuate(c)
				ships.erase(c)
			crews.erase(c)
			print("[server] crew %d sailed away" % c)


func _handle_sinking() -> void:
	for id in ships.keys():
		var s: ShipState = ships[id]
		if not s.is_sinking():
			continue
		if not _evacuated.has(id):
			_evacuated[id] = true
			_evacuate(id)
			if crews.has(id):
				stats.crew_sunk += 1
				_tell_crew(id, "We're sinking! Abandon ship!")
				Net.send_message(0, "%s is going down!" % crew_name(id))
			else:
				Net.send_message(0, "The skeleton ship is going down!")
		if s.sink >= 1.0:
			if crews.has(id):
				if crews[id].respawn_at < 0.0:
					crews[id].respawn_at = time + CREW_RESPAWN_DELAY
			else:
				_drop_wreck_loot(s)
				for sid in skeletons.keys():
					if skeletons[sid].frame == id:
						skeletons.erase(sid)
				ships.erase(id)
				captains.erase(id)
				_evacuated.erase(id)
				stats.ai_sunk += 1
				next_ai_time = time + AI_RESPAWN_DELAY
				print("[server] skeleton ship %d sunk" % id)


## Everyone aboard a sinking ship goes into the sea where they stood.
func _evacuate(ship_id: int) -> void:
	var pose := ShipPhysics.pose_of(ships[ship_id], time)
	# Anything stowed aboard floats up where it was.
	for iid in items:
		var item: Loot = items[iid]
		if item.state == Loot.State.ON_SHIP and item.ship == ship_id:
			_set_floating(item, pose * item.pos)
	for id in players:
		var r: Dictionary = players[id]
		if r.mode != LocalPlayer.Mode.ON_SHIP or r.ship != ship_id:
			continue
		_free_station_of(id)
		r.bucket = false
		var world: Vector3 = pose * r.pos
		world.y = maxf(world.y, Waves.height(world.x, world.z, time) + 0.5)
		_teleport(id, LocalPlayer.Mode.WORLD, world, r.yaw + ships[ship_id].yaw, -1)


func _separate_ships() -> void:
	var ids := ships.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: ShipState = ships[ids[i]]
			var b: ShipState = ships[ids[j]]
			if a.is_sinking() or b.is_sinking():
				continue
			var pa := Vector2(a.x, a.z)
			var pb := Vector2(b.x, b.z)
			if pa.distance_to(pb) > 2.0 * ShipShape.HALF_LENGTH + SHIP_CONTACT:
				continue
			var closest := INF
			for da: float in [-9.0, 0.0, 9.0]:
				for db: float in [-9.0, 0.0, 9.0]:
					var qa := pa + ShipPhysics.forward(a.yaw) * da
					var qb := pb + ShipPhysics.forward(b.yaw) * db
					closest = minf(closest, qa.distance_to(qb))
			if closest >= SHIP_CONTACT:
				continue
			var push := (pb - pa).normalized() * (SHIP_CONTACT - closest) * 0.5
			a.x -= push.x
			a.z -= push.y
			b.x += push.x
			b.z += push.y
			a.speed *= 0.5
			b.speed *= 0.5


# =====================================================================================
# Cannonballs
# =====================================================================================

func _fire(ship_id: int, gun: int, yaw: float, pitch: float, reload: float) -> void:
	var s: ShipState = ships[ship_id]
	yaw = clampf(yaw, -ShipShape.CANNON_YAW_LIMIT, ShipShape.CANNON_YAW_LIMIT)
	pitch = clampf(pitch, ShipShape.CANNON_PITCH_MIN, ShipShape.CANNON_PITCH_MAX)
	s.gun_yaw[gun] = yaw
	s.gun_pitch[gun] = pitch
	s.gun_reload[gun] = reload
	var pose := ShipPhysics.pose_of(s, time)
	var muzzle := pose * ShipShape.muzzle(gun, yaw, pitch)
	var dir := pose.basis * ShipShape.barrel_direction(gun, yaw, pitch)
	var v0 := dir * Ballistics.MUZZLE_SPEED + ShipPhysics.velocity_of(s)
	var id := _next_projectile
	_next_projectile += 1
	projectiles.append({"id": id, "t0": time, "p0": muzzle, "v0": v0, "ship": ship_id, "prev": muzzle})
	stats.shots += 1
	Net.send_event("shot", [id, time, muzzle.x, muzzle.y, muzzle.z, v0.x, v0.y, v0.z, ship_id, gun])


func _step_projectiles() -> void:
	var poses := {}
	for id in ships:
		poses[id] = ShipPhysics.pose_of(ships[id], time)
	var keep: Array[Dictionary] = []
	for p in projectiles:
		var age: float = time - p.t0
		var pos := Ballistics.position(p.p0, p.v0, age)
		if not _projectile_hits(p, pos, age, poses):
			if age < Ballistics.LIFETIME:
				p.prev = pos
				keep.append(p)
	projectiles = keep


## True if the ball hit something this tick (and reports it).
func _projectile_hits(p: Dictionary, pos: Vector3, age: float, poses: Dictionary) -> bool:
	for id in ships:
		var s: ShipState = ships[id]
		if s.sink > 0.5 or (id == p.ship and age < 0.4):
			continue
		var pose: Transform3D = poses[id]
		var inv := pose.affine_inverse()
		var local := inv * pos
		if local.length() > 25.0 or not ShipShape.inside_hull(local):
			continue
		# Walk back along this tick's path to where the ball met the hull.
		var outside: Vector3 = inv * p.prev
		var inside := local
		for i in 10:
			var mid := (outside + inside) * 0.5
			if ShipShape.inside_hull(mid):
				inside = mid
			else:
				outside = mid
		_hull_hit(p, id, inside, pose * inside)
		return true
	if pos.y < Waves.height(pos.x, pos.z, time):
		Net.send_event("impact", [p.id, 0, pos.x, pos.y, pos.z, -1, time])
		_splash(pos, _crew_of_ship(p.ship))
		return true
	for island in Islands.LAYOUT:
		var dx: float = pos.x - island.x
		var dz: float = pos.z - island.z
		if dx * dx + dz * dz < (island.radius + 14.0) ** 2 and pos.y < IslandMesh.ground(island, dx, dz) + 0.3:
			Net.send_event("impact", [p.id, 3, pos.x, pos.y, pos.z, -1, time])
			_splash(pos, _crew_of_ship(p.ship))
			return true
	return false


func _hull_hit(p: Dictionary, ship_id: int, local: Vector3, world: Vector3) -> void:
	var s: ShipState = ships[ship_id]
	var kind := 2
	if ShipShape.makes_hole(local):
		kind = 1
		stats.hits += 1
		if s.holes.size() < MAX_HOLES:
			var h := ShipShape.hole_point(local)
			s.holes.append([s.next_hole_id, h.x, h.y, h.z, 0.0])
			s.next_hole_id += 1
			stats.holes += 1
			if crews.has(ship_id):
				_tell_crew(ship_id, "We're hit! Water on the lower deck!")
		else:
			s.water = minf(ShipPhysics.SINK_LEVEL, s.water + 0.15)
	Net.send_event("impact", [p.id, kind, world.x, world.y, world.z, ship_id, time])
	_splash(world, _crew_of_ship(p.ship))


# =====================================================================================
# Players
# =====================================================================================

## "" if a new player may join, otherwise the reason they may not.
func can_join(version: String) -> String:
	if version != GameConfig.VERSION:
		return "This server runs version %s; you have %s." % [GameConfig.VERSION, version]
	if players.size() >= GameConfig.MAX_PLAYERS:
		return "The server is full (%d players)." % GameConfig.MAX_PLAYERS
	return ""


## Which crew a joining player goes to: the one asked for if it has room, otherwise the
## lowest-numbered crew with room (so friends who pick "any" end up together).
func pick_crew(wanted: int) -> int:
	if wanted >= 1 and wanted <= MAX_CREWS and _crew_members(wanted).size() < CREW_SIZE:
		return wanted
	for c in range(1, MAX_CREWS + 1):
		if _crew_members(c).size() < CREW_SIZE:
			return c
	return -1


func add_player(id: int, player_name: String, wanted_crew := 0) -> void:
	var clean := player_name.strip_edges().substr(0, 20)
	if clean == "":
		clean = "Pirate %d" % (players.size() + 1)
	var crew := maxi(1, pick_crew(wanted_crew))
	_ensure_crew(crew)
	players[id] = {
		"name": clean, "crew": crew, "mode": LocalPlayer.Mode.ON_SHIP, "ship": crew, "pos": Vector3.ZERO,
		"yaw": 0.0, "pitch": 0.0, "station": -1, "seq": 0, "time": time, "bucket": false,
		"last_patch": -1.0, "carry": -1, "dig": 0.0, "last_dig": -1.0,
		"hp": HEALTH, "dead_until": -1.0, "weapon": Weapons.Kind.CUTLASS, "next_attack": 0.0,
	}
	roster[id] = clean
	print("[server] %s joined crew %d (peer %d)" % [clean, crew, id])
	Net.send_roster(roster)
	var ship: ShipState = ships[crew]
	if ship.is_sinking():
		_teleport(id, LocalPlayer.Mode.WORLD, Vector3(ship.x + 12.0, 0.5, ship.z), 0.0)
	else:
		_teleport(id, LocalPlayer.Mode.ON_SHIP, _free_spawn(id), 0.0)
	Net.send_message(0, "%s joined %s" % [clean, crew_name(crew)])


## Returns the name of the player who left, or "".
func remove_player(id: int) -> String:
	if not players.has(id):
		return ""
	_free_station_of(id)
	_drop_carried(id)
	var who: String = players[id].name
	print("[server] %s left (peer %d)" % [who, id])
	players.erase(id)
	roster.erase(id)
	station_input.erase(id)
	return who


## A player reports where they are: [teleport seq, mode, x, y, z, yaw, pitch].
func player_state(id: int, data: Array) -> void:
	if not players.has(id) or data.size() != 7:
		return
	var r: Dictionary = players[id]
	if int(data[0]) != r.seq or r.dead_until >= 0.0:
		return  # from before our last teleport, or a ghost that may not move
	var mode := int(data[1])
	var pos := Vector3(data[2], data[3], data[4])
	var elapsed := maxf(time - r.time, 1.0 / GameConfig.PLAYER_SEND_RATE)
	var crew: ShipState = ships.get(r.ship, _own(r))

	var ok := true
	if mode == r.mode:
		ok = pos.distance_to(r.pos) <= MAX_PLAYER_SPEED * elapsed + 2.0
		if mode == LocalPlayer.Mode.ON_SHIP:
			ok = ok and ShipShape.plausible_position(pos)
		else:
			ok = ok and _plausible_in_world(pos)
	elif r.mode == LocalPlayer.Mode.ON_SHIP and mode == LocalPlayer.Mode.WORLD:
		ok = crew != null and Vector2(pos.x, pos.z).distance_to(Vector2(crew.x, crew.z)) < 40.0
	else:
		ok = false  # only the server moves people back aboard

	if not ok:
		stats.corrections += 1
		_teleport(id, r.mode, r.pos, r.yaw)
		return
	if mode == LocalPlayer.Mode.WORLD:
		_free_station_of(id)
		r.bucket = false
		r.ship = -1
	r.mode = mode
	r.pos = pos
	r.yaw = float(data[5])
	r.pitch = float(data[6])
	r.time = time


func set_station_input(id: int, axes: Vector2, aim: Vector2) -> void:
	if not players.has(id):
		return
	station_input[id] = {"axes": axes.limit_length(1.4), "aim": aim, "time": time}
	var r: Dictionary = players[id]
	if r.station >= 0 and _stations[r.station].kind == ShipShape.Kind.CANNON:
		var gun: int = _stations[r.station].gun
		_own(r).gun_yaw[gun] = clampf(aim.x, -ShipShape.CANNON_YAW_LIMIT, ShipShape.CANNON_YAW_LIMIT)
		_own(r).gun_pitch[gun] = clampf(aim.y, ShipShape.CANNON_PITCH_MIN, ShipShape.CANNON_PITCH_MAX)


func request(id: int, action: String, arg: int, data: Array) -> void:
	if not players.has(id):
		return
	var r: Dictionary = players[id]
	if r.dead_until >= 0.0:
		return
	if r.mode == LocalPlayer.Mode.ON_SHIP and r.ship != r.crew and action not in ["attack", "weapon", "drop", "respawn", "pickup"]:
		return  # aboard someone else's ship: fight, but no working their gear
	match action:
		"station":
			_take_station(id, r, arg)
		"leave":
			if r.station == arg:
				_free_station_of(id)
		"climb":
			_climb(id, r, arg, int(data[0]) if data.size() == 1 else -1)
		"respawn":
			_free_station_of(id)
			r.bucket = false
			if _own(r) and not _own(r).is_sinking():
				_teleport(id, LocalPlayer.Mode.ON_SHIP, _free_spawn(id), 0.0)
		"hatch":
			_hatch(id, r, arg)
		"patch":
			_patch(r, arg)
		"scoop":
			_scoop(r)
		"throw":
			_throw(r)
		"fire":
			_player_fire(r, arg, data)
		"voyage":
			_take_voyage(r)
		"dig":
			_dig(r)
		"pickup":
			_pickup(id, r, arg)
		"drop":
			_drop_carried(id)
		"sell":
			_sell(r)
		"restock":
			_restock(r, arg)
		"open":
			_open_barrel(r, arg)
		"weapon":
			if arg == Weapons.Kind.CUTLASS or arg == Weapons.Kind.PISTOL:
				r.weapon = arg
		"attack":
			_attack(id, r, data)
		"eat":
			_eat(r)


func _take_station(id: int, r: Dictionary, station: int) -> void:
	if station < 0 or station >= _stations.size() or r.mode != LocalPlayer.Mode.ON_SHIP:
		return
	if _own(r).is_sinking() or r.station == station:
		return
	if r.carry >= 0:
		Net.send_message(id, "Put the chest down first")
		return
	var st: Dictionary = _stations[station]
	var key: int = r.crew * 100 + station
	if station_owner.has(key) and station_owner[key] != id:
		Net.send_message(id, "%s is already on it" % roster.get(station_owner[key], "Someone"))
		return
	if r.pos.distance_to(st.stand) > 4.0:
		return
	_free_station_of(id)
	station_owner[key] = id
	r.station = station
	stats.stations_taken += 1
	print("[server] %s took station %d" % [r.name, station])
	var face := 0.0
	if st.kind == ShipShape.Kind.CANNON:
		face = -PI / 2.0 * st.side
	_teleport(id, LocalPlayer.Mode.ON_SHIP, st.stand, face)


## Up a ladder from the water: the ship asked for, or else whichever ladder is in reach.
func _climb(id: int, r: Dictionary, side: int, wanted := -1) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or absi(side) != 1:
		return
	var order: Array = ships.keys()
	if ships.has(wanted):
		order.erase(wanted)
		order.push_front(wanted)
	for ship_id in order:
		var s: ShipState = ships[ship_id]
		if s.is_sinking():
			continue
		var bottom := ShipPhysics.pose_of(s, time) * ShipShape.ladder_bottom(side)
		if Vector2(r.pos.x - bottom.x, r.pos.z - bottom.z).length() > LADDER_TOLERANCE:
			continue
		stats.climbs += 1
		if ship_id != r.crew:
			stats.boarded += 1
			var whose := crew_name(ship_id) if crews.has(ship_id) else "skeleton ship %d" % ship_id
			print("[server] %s boarded %s" % [r.name, whose])
		else:
			print("[server] %s climbed aboard" % r.name)
		# Face inboard: starboard ladder looks toward -x, which is a quarter turn left.
		_teleport(id, LocalPlayer.Mode.ON_SHIP, ShipShape.ladder_top(side), PI / 2.0 * side, ship_id)
		return


func _hatch(id: int, r: Dictionary, up: int) -> void:
	if r.mode != LocalPlayer.Mode.ON_SHIP or r.station >= 0:
		return
	if up == 0 and r.pos.distance_to(ShipShape.hatch_top_target()) < HATCH_REACH + 1.0:
		_teleport(id, LocalPlayer.Mode.ON_SHIP, ShipShape.HATCH_BOTTOM, PI)
	elif up == 1 and r.pos.distance_to(ShipShape.hatch_bottom_target()) < HATCH_REACH + 1.5:
		_teleport(id, LocalPlayer.Mode.ON_SHIP, ShipShape.HATCH_TOP, 0.0)


func _patch(r: Dictionary, hole_id: int) -> void:
	if r.mode != LocalPlayer.Mode.ON_SHIP:
		return
	var s := _own(r)
	for h: Array in s.holes:
		if int(h[0]) != hole_id:
			continue
		var at := Vector3(h[1], h[2], h[3])
		if r.pos.distance_to(at) > PATCH_REACH + 1.0:
			return
		# Credit the time since this player's last patch request, so the work rate is the
		# same however often the client asks.
		var gap: float = time - r.last_patch if r.last_patch >= 0.0 else 0.2
		r.last_patch = time
		h[4] = minf(float(h[4]) + clampf(gap, 0.0, 0.35) / PATCH_TIME, 1.0)
		if h[4] >= 1.0:
			if s.planks <= 0:
				h[4] = 0.95
				Net.send_message(players.find_key(r), "No planks left! Restock at Port Merrow.")
				return
			s.planks -= 1
			s.holes.erase(h)
			stats.patched += 1
			print("[server] %s patched hole %d" % [r.name, hole_id])
		return


func _scoop(r: Dictionary) -> void:
	var s := _own(r)
	if r.mode != LocalPlayer.Mode.ON_SHIP or r.bucket or s.water < 0.1:
		return
	if ShipShape.is_below_deck(r.pos) and r.pos.y < ShipShape.LOWER_Y + s.water + 0.3:
		r.bucket = true


func _throw(r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.ON_SHIP or not r.bucket or r.pos.y < ShipShape.DECK_Y - 0.5:
		return
	r.bucket = false
	_pending_bail[r.crew] = _pending_bail.get(r.crew, 0.0) + BUCKET
	stats.bailed += 1


func _player_fire(r: Dictionary, station: int, aim: Array) -> void:
	if r.station != station or station < 0 or aim.size() != 2:
		return
	var st: Dictionary = _stations[station]
	if st.kind != ShipShape.Kind.CANNON or _own(r).is_sinking():
		return
	if _own(r).gun_reload[st.gun] > 0.0:
		return
	if _own(r).cannonballs <= 0:
		Net.send_message(players.find_key(r), "Out of cannonballs! Restock at Port Merrow.")
		return
	_own(r).cannonballs -= 1
	_fire(r.crew, st.gun, float(aim[0]), float(aim[1]), PLAYER_RELOAD)


func _free_station_of(id: int) -> void:
	if not players.has(id):
		return
	var r: Dictionary = players[id]
	var key: int = r.crew * 100 + r.station
	if r.station >= 0 and station_owner.get(key) == id:
		station_owner.erase(key)
	r.station = -1
	station_input.erase(id)


func _free_spawn(for_id: int) -> Vector3:
	for spot in ShipShape.SPAWNS:
		var taken := false
		for id in players:
			var r: Dictionary = players[id]
			var same_ship: bool = r.ship == players[for_id].crew if players.has(for_id) else true
			if id != for_id and same_ship and r.mode == LocalPlayer.Mode.ON_SHIP and r.pos.distance_to(spot) < 0.8:
				taken = true
		if not taken:
			return spot
	return ShipShape.SPAWNS[0]


## Put a player somewhere. `ship` is the ship whose frame `pos` is in (ON_SHIP), else -1.
## -2 for `ship` means the player's own crew ship.
func _teleport(id: int, mode: int, pos: Vector3, yaw: float, ship := -2) -> void:
	var r: Dictionary = players[id]
	if ship == -2:
		ship = r.crew
	r.seq += 1
	r.mode = mode
	r.ship = ship if mode == LocalPlayer.Mode.ON_SHIP else -1
	r.pos = pos
	r.yaw = yaw
	r.time = time
	Net.send_teleport(id, [r.seq, mode, pos.x, pos.y, pos.z, yaw, r.ship])


static func compass_name(heading: float) -> String:
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	return names[int(round(fposmod(rad_to_deg(heading), 360.0) / 45.0)) % 8]


# =====================================================================================
# Treasure and supplies
# =====================================================================================

func _new_item(kind: int, state: int, pos: Vector3, value := 0) -> Loot:
	var item := Loot.new()
	item.id = _next_item
	_next_item += 1
	item.kind = kind
	item.state = state
	item.pos = pos
	item.value = value
	item.born = time
	items[item.id] = item
	return item


func _island_xz(where: String) -> Vector2:
	var index := Islands.outpost_index() if where == "outpost" else int(where)
	var spec: Dictionary = Islands.LAYOUT[index]
	return Vector2(spec.x, spec.z)


## A spot 40 m off an island's shore, on the side facing the start (for tests).
func _anchorage(index: int) -> Vector3:
	var spec: Dictionary = Islands.LAYOUT[index]
	var dir := -Vector2(spec.x, spec.z).normalized()
	var p: Vector2 = Vector2(spec.x, spec.z) + dir * (spec.radius + 40.0)
	return Vector3(p.x, 0.0, p.y)


func _set_floating(item: Loot, world: Vector3) -> void:
	item.state = Loot.State.FLOATING
	item.carrier = -1
	item.pos = Vector3(world.x, Waves.height(world.x, world.z, time) - 0.15, world.z)
	item.born = time


func _step_items(dt: float) -> void:
	var gone := []
	for id in items:
		var item: Loot = items[id]
		match item.state:
			Loot.State.FLOATING:
				item.pos.y = Waves.height(item.pos.x, item.pos.z, time) - 0.15
				item.yaw += 0.05 * dt
				if time - item.born > Loot.FLOAT_LIFE:
					gone.append(id)
			Loot.State.CARRIED:
				if players.has(item.carrier):
					item.pos = players[item.carrier].pos
				else:
					gone.append(id)
	for id in gone:
		items.erase(id)


## Where a player is in the world (converting from the ship frame when aboard).
func _world_pos(r: Dictionary) -> Vector3:
	if r.mode == LocalPlayer.Mode.ON_SHIP and ships.has(r.ship):
		return ShipPhysics.pose_of(ships[r.ship], time) * r.pos
	return r.pos


func _take_voyage(r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.ON_SHIP or not crews[r.crew].voyage.is_empty():
		return
	if r.pos.distance_to(ShipShape.map_table_target()) > MAP_TABLE_REACH + 1.0:
		return
	var choices: Array[int] = []
	for i in Islands.LAYOUT.size():
		if not Islands.LAYOUT[i].outpost:
			choices.append(i)
	var index: int = choices[_rng.randi() % choices.size()]
	if options_island >= 0:
		index = options_island
	var spot := Islands.dig_spot(index, _rng)
	var ground := Islands.ground_at(index, spot.x, spot.y)
	var gold := _rng.randi_range(80, 320)
	var chest := _new_item(Loot.Kind.CHEST, Loot.State.BURIED, Vector3(spot.x, ground, spot.y), gold)
	crews[r.crew].voyage = {"island": index, "x": spot.x, "z": spot.y, "item": chest.id}
	stats.voyages += 1
	print("[server] voyage to %s, X at (%.0f, %.0f)" % [Islands.LAYOUT[index].name, spot.x, spot.y])
	Net.send_message(0, "A treasure map! Hold M to read it.")


func _dig(r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or r.carry >= 0:
		return
	var island := Islands.island_at(r.pos.x, r.pos.z)
	if island < 0 or r.pos.y < Waves.height(r.pos.x, r.pos.z, time):
		return
	var gap: float = time - r.last_dig if r.last_dig >= 0.0 else 0.2
	r.last_dig = time
	if gap > 0.6:
		r.dig = 0.0
	r.dig += clampf(gap, 0.0, 0.35) / DIG_TIME
	if r.dig < 1.0:
		return
	r.dig = 0.0
	for id in items:
		var item: Loot = items[id]
		if item.state == Loot.State.BURIED and Vector2(item.pos.x - r.pos.x, item.pos.z - r.pos.z).length() < DIG_REACH:
			item.state = Loot.State.GROUND
			item.pos.y = Islands.ground_at(island, item.pos.x, item.pos.z) + 0.05
			stats.dug += 1
			print("[server] %s dug up a %s" % [r.name, item.label()])
			Net.send_message(0, "%s dug up a %s!" % [r.name, item.label()])
			return
	Net.send_message(players.find_key(r), "Nothing here.")


func _pickup(id: int, r: Dictionary, item_id: int) -> void:
	if r.carry >= 0 or r.station >= 0 or not items.has(item_id):
		return
	var item: Loot = items[item_id]
	if item.kind != Loot.Kind.CHEST:
		return
	var close := false
	match item.state:
		Loot.State.GROUND, Loot.State.FLOATING:
			close = r.mode == LocalPlayer.Mode.WORLD and r.pos.distance_to(item.pos) < ITEM_REACH + 1.0
		Loot.State.ON_SHIP:
			close = r.mode == LocalPlayer.Mode.ON_SHIP and r.ship == item.ship and r.pos.distance_to(item.pos) < ITEM_REACH + 1.0
	if not close:
		return
	var stolen: bool = item.state == Loot.State.ON_SHIP and item.ship != r.crew
	item.state = Loot.State.CARRIED
	item.carrier = id
	r.carry = item_id
	print("[server] %s %s a %s" % [r.name, "stole" if stolen else "picked up", item.label()])
	if stolen:
		stats.stolen += 1
		Net.send_message(0, "%s stole a %s from %s!" % [r.name, item.label(), crew_name(item.ship)])


func _drop_carried(id: int) -> void:
	if not players.has(id):
		return
	var r: Dictionary = players[id]
	if r.carry < 0 or not items.has(r.carry):
		r.carry = -1
		return
	var item: Loot = items[r.carry]
	r.carry = -1
	item.carrier = -1
	var ahead := Basis(Vector3.UP, r.yaw) * Vector3(0, 0, -0.8)
	if r.mode == LocalPlayer.Mode.ON_SHIP and ships.has(r.ship) and not ships[r.ship].is_sinking():
		item.state = Loot.State.ON_SHIP
		item.ship = r.ship
		var p: Vector3 = r.pos + ahead
		item.pos = Vector3(p.x, r.pos.y, p.z)
		item.yaw = r.yaw
		stats.stowed += 1
		print("[server] %s stowed a %s aboard ship %d" % [r.name, item.label(), r.ship])
		return
	var world: Vector3 = _world_pos(r) + ahead
	var island := Islands.island_at(world.x, world.z)
	var ground := Islands.ground_at(island, world.x, world.z) if island >= 0 else -99.0
	if ground > Waves.height(world.x, world.z, time):
		item.state = Loot.State.GROUND
		item.pos = Vector3(world.x, ground + 0.05, world.z)
		item.yaw = r.yaw
	else:
		_set_floating(item, world)


func _sell(r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or r.carry < 0 or not items.has(r.carry):
		return
	if r.pos.distance_to(Outpost.sell_spot()) > SELL_REACH + 1.0:
		return
	var item: Loot = items[r.carry]
	crews[r.crew].purse += item.value
	stats.sold += 1
	items.erase(item.id)
	r.carry = -1
	for c in crews:
		var v: Dictionary = crews[c].voyage
		if not v.is_empty() and v.item == item.id:
			crews[c].voyage = {}
	print("[server] %s sold a %s for %d gold (purse %d)" % [r.name, item.label(), item.value, crews[r.crew].purse])
	Net.send_message(0, "Sold a %s for %d gold!" % [item.label(), item.value])


func _restock(r: Dictionary, barrel: int) -> void:
	var spots := Outpost.barrels()
	if r.mode != LocalPlayer.Mode.WORLD or barrel < 0 or barrel >= spots.size():
		return
	if r.pos.distance_to(spots[barrel]) > ITEM_REACH + 1.0:
		return
	var ship := _own(r)
	if Vector2(ship.x - r.pos.x, ship.z - r.pos.z).length() > RESTOCK_SHIP_RANGE:
		Net.send_message(players.find_key(r), "Bring the ship closer to load supplies.")
		return
	ship.cannonballs = ShipState.MAX_CANNONBALLS
	ship.planks = ShipState.MAX_PLANKS
	ship.bananas = ShipState.MAX_BANANAS
	stats.restocked += 1
	Net.send_message(0, "Supplies loaded: %d cannonballs, %d planks." % [ship.cannonballs, ship.planks])


func _open_barrel(r: Dictionary, item_id: int) -> void:
	if not items.has(item_id) or r.mode != LocalPlayer.Mode.WORLD:
		return
	var item: Loot = items[item_id]
	if item.kind != Loot.Kind.BARREL or r.pos.distance_to(item.pos) > ITEM_REACH + 1.0:
		return
	var ship := _own(r)
	if Vector2(ship.x - r.pos.x, ship.z - r.pos.z).length() > OPEN_SHIP_RANGE:
		Net.send_message(players.find_key(r), "Too far from the ship to stow these supplies.")
		return
	ship.cannonballs = mini(ShipState.MAX_CANNONBALLS, ship.cannonballs + BARREL_BALLS)
	ship.planks = mini(ShipState.MAX_PLANKS, ship.planks + BARREL_PLANKS)
	ship.bananas = mini(ShipState.MAX_BANANAS, ship.bananas + 5)
	items.erase(item_id)
	stats.restocked += 1
	Net.send_message(0, "Supplies stowed: %d cannonballs, %d planks." % [ship.cannonballs, ship.planks])


## A sunk skeleton ship leaves a captain's chest and two supply barrels floating behind.
func _drop_wreck_loot(s: ShipState) -> void:
	var at := Vector3(s.x, 0.0, s.z)
	_set_floating(_new_item(Loot.Kind.CHEST, Loot.State.FLOATING, at, _rng.randi_range(480, 720)), at)
	for dx: float in [-6.0, 6.0]:
		var p := at + Vector3(dx, 0.0, _rng.randf_range(-5.0, 5.0))
		_set_floating(_new_item(Loot.Kind.BARREL, Loot.State.FLOATING, p), p)
	stats.loot_spawned += 3


# =====================================================================================
# Fighting on foot
# =====================================================================================

func _new_skeleton(frame: int, pos: Vector3, home := -1) -> Skeleton:
	var sk := Skeleton.new()
	sk.id = _next_skeleton
	_next_skeleton += 1
	sk.frame = frame
	sk.pos = pos
	sk.home = home
	sk.yaw = _rng.randf() * TAU
	skeletons[sk.id] = sk
	return sk


func _crew_skeleton_ship(ship_id: int) -> void:
	var spots: Array[Vector3] = [
		Vector3(-1.5, ShipShape.DECK_Y, -4.6), Vector3(1.8, ShipShape.DECK_Y, -0.2), Vector3(0, ShipShape.QUARTER_Y, 8.0),
	]
	for i in SHIP_SKELETONS:
		_new_skeleton(ship_id, spots[i % spots.size()])


## Test hook: a skeleton ship lying still beside the crew's ship, with its skeletons aboard.
func _spawn_passive_skeleton_ship() -> void:
	var crew := crew_ship()
	var s := ShipState.new()
	s.kind = ShipState.Kind.SKELETON
	s.x = crew.x + 40.0
	s.z = crew.z
	s.anchored = true
	var id := _next_ship_id
	_next_ship_id += 1
	ships[id] = s
	captains[id] = Captain.new(id)
	_passive[id] = true
	_crew_skeleton_ship(id)
	ai_enabled = false


## Wake an island's camp when a pirate comes near it and it has no skeletons standing.
func _wake_camps() -> void:
	for i in Islands.LAYOUT.size():
		var spec: Dictionary = Islands.LAYOUT[i]
		if spec.outpost:
			continue
		var camp: Dictionary = camps.get(i, {"alive": 0, "wake": 0.0})
		camps[i] = camp
		if camp.alive > 0 or time < camp.wake:
			continue
		var near := false
		for id in players:
			var w := _world_pos(players[id])
			if Vector2(w.x - spec.x, w.z - spec.z).length() < spec.radius + CAMP_WAKE:
				near = true
		if not near:
			continue
		for n in CAMP_SIZE:
			var spot := Islands.dig_spot(i, _rng)
			_new_skeleton(-1, Vector3(spot.x, Islands.ground_at(i, spot.x, spot.y), spot.y), i)
		camp.alive = CAMP_SIZE
		print("[server] the skeletons of %s awake" % spec.name)


func _step_skeletons(dt: float) -> void:
	for sid in skeletons.keys():
		var sk: Skeleton = skeletons[sid]
		if not sk.alive():
			if time - sk.fell > Skeleton.CORPSE_TIME:
				skeletons.erase(sid)
			continue
		if sk.frame >= 0 and not ships.has(sk.frame):
			skeletons.erase(sid)
			continue
		var target := _skeleton_target(sk)
		var goal: Variant = null if target < 0 else _pos_in_frame(players[target], sk.frame)
		if sk.step(goal, dt, _floor_for(sk)):
			stats.skeleton_swings += 1
			Net.send_event("swing", [sk.id])
			_hurt_player(target, Skeleton.SWING_DAMAGE, "a skeleton")


## The nearest living player the skeleton can get at, or -1.
func _skeleton_target(sk: Skeleton) -> int:
	var best := -1
	var best_d := Skeleton.CHASE_RANGE
	for id in players:
		var r: Dictionary = players[id]
		if r.dead_until >= 0.0:
			continue
		if sk.frame >= 0 and (r.mode != LocalPlayer.Mode.ON_SHIP or r.ship != sk.frame):
			continue
		if sk.frame < 0 and r.mode != LocalPlayer.Mode.WORLD:
			continue
		var d: float = r.pos.distance_to(sk.pos)
		if d < best_d:
			best = id
			best_d = d
	return best


func _pos_in_frame(r: Dictionary, frame: int) -> Vector3:
	if frame < 0:
		return _world_pos(r)
	return r.pos


## Where a skeleton may stand: dry land on islands, the decks on ships.
func _floor_for(sk: Skeleton) -> Callable:
	if sk.frame >= 0:
		return func(x: float, z: float) -> float:
			var p := Vector3(x, ShipShape.DECK_Y, z)
			if not ShipShape.is_on_board(p) or absf(x) > ShipShape.half_width(z, ShipShape.DECK_Y) - 0.5:
				return NAN
			return ShipShape.floor_y(z, x)
	var island := sk.home
	return func(x: float, z: float) -> float:
		var g := Islands.ground_at(island, x, z)
		return g if g > Waves.height(x, z, time) + Skeleton.SHORE else NAN


func _hurt_player(id: int, damage: int, by: String, attacker := -1) -> void:
	if not players.has(id):
		return
	var r: Dictionary = players[id]
	if r.dead_until >= 0.0:
		return
	r.hp = maxi(0, r.hp - damage)
	Net.send_event("hurt_player", [id, damage])
	if r.hp > 0:
		return
	stats.falls += 1
	if attacker >= 0:
		stats.pvp_falls += 1
	r.dead_until = time + GHOST_TIME
	_free_station_of(id)
	_drop_carried(id)
	r.bucket = false
	print("[server] %s was felled by %s" % [r.name, by])
	Net.send_message(0, "%s has fallen to %s!" % [r.name, by])


func _step_ghosts() -> void:
	for id in players:
		var r: Dictionary = players[id]
		var own: ShipState = ships.get(r.crew)
		if r.dead_until < 0.0 or time < r.dead_until or own == null or own.is_sinking():
			continue
		r.dead_until = -1.0
		r.hp = HEALTH
		_teleport(id, LocalPlayer.Mode.ON_SHIP, _free_spawn(id), 0.0)
		Net.send_message(id, "Back from the brink. Welcome aboard.")


## A swing or a shot: the client says where it looked; the server decides what it hit.
func _attack(id: int, r: Dictionary, look: Array) -> void:
	if look.size() != 2 or r.station >= 0 or r.carry >= 0 or time < r.next_attack - ATTACK_SLACK:
		return
	var weapon: int = r.weapon
	r.next_attack = time + (Weapons.CUTLASS_COOLDOWN if weapon == Weapons.Kind.CUTLASS else Weapons.PISTOL_RELOAD)
	var basis := Basis(Vector3.UP, float(look[0])) * Basis(Vector3.RIGHT, float(look[1]))
	var dir := basis * Vector3.FORWARD
	var eye := _world_pos(r) + Vector3.UP * Weapons.EYE_HEIGHT
	if r.mode == LocalPlayer.Mode.ON_SHIP and ships.has(r.ship):
		var pose := ShipPhysics.pose_of(ships[r.ship], time)
		dir = pose.basis * dir
		eye = pose * (r.pos + Vector3.UP * Weapons.EYE_HEIGHT)
	# Targets: standing skeletons (positive ids) and living players of other crews (negative).
	var ids: Array = []
	var feet: Array = []
	for sid in skeletons:
		var sk: Skeleton = skeletons[sid]
		if sk.alive():
			ids.append(sid)
			feet.append(_skeleton_world(sk))
	for pid in players:
		var other: Dictionary = players[pid]
		if pid != id and other.crew != r.crew and other.dead_until < 0.0:
			ids.append(-pid)
			feet.append(_world_pos(other))
	Net.send_event("attack", [id, weapon])
	var damage := Weapons.CUTLASS_DAMAGE if weapon == Weapons.Kind.CUTLASS else Weapons.PISTOL_DAMAGE
	var struck: Array[int] = []
	if weapon == Weapons.Kind.CUTLASS:
		struck = Weapons.cutlass_hits(eye, dir, feet)
	else:
		var i := Weapons.pistol_hit(eye, dir, feet)
		if i >= 0:
			struck.append(i)
	for i in struck:
		var target: int = ids[i]
		if target > 0:
			_hurt_skeleton(target, damage, r.name)
		else:
			_hurt_player(-target, damage, "%s of %s" % [r.name, crew_name(r.crew)], id)


func _skeleton_world(sk: Skeleton) -> Vector3:
	if sk.frame >= 0 and ships.has(sk.frame):
		return ShipPhysics.pose_of(ships[sk.frame], time) * sk.pos
	return sk.pos


func _hurt_skeleton(sid: int, damage: int, by: String) -> void:
	var sk: Skeleton = skeletons[sid]
	if not sk.alive():
		return
	sk.hp -= damage
	Net.send_event("hurt_skeleton", [sid, damage])
	if sk.hp > 0:
		return
	sk.fell = time
	stats.kills += 1
	print("[server] %s felled skeleton %d" % [by, sid])
	if sk.home >= 0 and camps.has(sk.home):
		camps[sk.home].alive -= 1
		if camps[sk.home].alive <= 0:
			camps[sk.home].wake = time + CAMP_RESPAWN
			Net.send_message(0, "The skeletons of %s are beaten!" % Islands.LAYOUT[sk.home].name)


func _crew_of_ship(ship_id: int) -> int:
	return ships[ship_id].crew if ships.has(ship_id) else 0


## A cannonball hurts anyone near where it lands, except the crew that fired it.
func _splash(world: Vector3, shooter_crew := 0) -> void:
	for id in players:
		var r: Dictionary = players[id]
		if r.crew == shooter_crew:
			continue
		var dmg := Weapons.splash_damage(_world_pos(r).distance_to(world))
		if dmg > 0:
			_hurt_player(id, dmg, "a cannonball")
	for sid in skeletons.keys():
		var sk: Skeleton = skeletons[sid]
		if sk.alive():
			var dmg := Weapons.splash_damage(_skeleton_world(sk).distance_to(world))
			if dmg > 0:
				_hurt_skeleton(sid, dmg, "a cannonball")


func _eat(r: Dictionary) -> void:
	var ship := _own(r)
	if r.mode != LocalPlayer.Mode.ON_SHIP or r.ship != r.crew or ship.bananas <= 0 or r.hp >= HEALTH:
		return
	if r.pos.distance_to(ShipShape.BANANA_BARREL) > EAT_REACH + 1.0:
		return
	ship.bananas -= 1
	r.hp = mini(HEALTH, r.hp + BANANA_HEAL)
	stats.eaten += 1
	Net.send_message(players.find_key(r), "Mmm, banana. (%d left)" % ship.bananas)



## Stricter checks on where a player says they are in the world: not inside an island.
func _plausible_in_world(p: Vector3) -> bool:
	var island := Islands.island_at(p.x, p.z)
	if island >= 0 and p.y < Islands.ground_at(island, p.x, p.z) - 0.6:
		return false
	return p.y > -6.0 and p.y < 60.0

class_name ServerSim
extends RefCounted
## The authoritative world, run only on the server (dedicated or host): the ships and their
## damage, the skeleton captains, cannonballs in flight, the crew list and what each player
## is doing. Game feeds it ticks and player messages; it answers through Net.

const CREW := 0
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

var time := 0.0
var ships := {}  # ship id -> ShipState
var captains := {}  # ship id -> Captain (skeleton ships only)
var players := {}  # peer id -> record (see add_player)
var roster := {}  # peer id -> name
var station_owner := {}  # station id -> peer id
var station_input := {}  # peer id -> {axes, aim, time}
var projectiles: Array[Dictionary] = []
var stats := {
	"max_speed": 0.0, "stations_taken": 0, "climbs": 0, "corrections": 0, "shots": 0,
	"hits": 0, "holes": 0, "patched": 0, "bailed": 0, "ai_spawned": 0, "ai_sunk": 0, "crew_sunk": 0,
}

var ai_enabled := true
var next_ai_time := AI_FIRST_DELAY
var _next_ship_id := 1
var _next_projectile := 1
var _crew_respawn_at := -1.0
var _evacuated := {}
var _pending_bail := {}
var _stations := ShipShape.stations()
var _rng := RandomNumberGenerator.new()


func _init(options: Dictionary = {}) -> void:
	_rng.seed = 12345
	ai_enabled = not options.get("no-ai", false)
	next_ai_time = float(options.get("ai-delay", AI_FIRST_DELAY))
	ships[CREW] = ShipState.new()
	# Test hook: start with this many holes in the crew's ship.
	for i in int(options.get("test-holes", 0)):
		var h := ShipShape.hole_point(Vector3(1.0 if i % 2 == 0 else -1.0, 0.0, -6.0 + i * 1.5))
		crew_ship().holes.append([crew_ship().next_hole_id, h.x, h.y, h.z, 0.0])
		crew_ship().next_hole_id += 1


func crew_ship() -> ShipState:
	return ships[CREW]


# =====================================================================================
# Ticking
# =====================================================================================

func tick(dt: float) -> void:
	time += dt
	var wind := Game.wind_dir(time)
	_maybe_spawn_skeleton()
	_maybe_respawn_crew()

	for id in ships.keys():
		var s: ShipState = ships[id]
		var c := _crew_controls() if id == CREW else ShipControls.new()
		if captains.has(id) and not s.is_sinking():
			var orders: Array = captains[id].think(s, crew_ship(), wind, time, dt, Islands.LAYOUT, c)
			for shot: Dictionary in orders:
				_fire(id, shot.gun, shot.yaw, shot.pitch, Captain.RELOAD + _rng.randf())
		c.bail += _pending_bail.get(id, 0.0)
		_pending_bail.erase(id)
		ShipPhysics.step(s, c, wind, dt, Islands.ship_blockers())
	stats.max_speed = maxf(stats.max_speed, crew_ship().speed)

	_separate_ships()
	_step_projectiles()
	_handle_sinking()


func _crew_controls() -> ShipControls:
	var c := ShipControls.new()
	for id in station_owner:
		var peer: int = station_owner[id]
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
		list.append([id, r.mode, r.ship, r.pos.x, r.pos.y, r.pos.z, r.yaw, r.pitch, r.station, 1 if r.bucket else 0])
	return [time, ship_list, list]


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

func _maybe_spawn_skeleton() -> void:
	if not ai_enabled or time < next_ai_time or not captains.is_empty() or crew_ship().is_sinking():
		return
	var crew := crew_ship()
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
	stats.ai_spawned += 1
	var from := spot - origin
	print("[server] skeleton ship %d spawned at (%.0f, %.0f)" % [id, spot.x, spot.y])
	Net.send_message(0, "A skeleton ship approaches from the %s!" % compass_name(atan2(from.x, -from.y)))


func _maybe_respawn_crew() -> void:
	if _crew_respawn_at < 0.0 or time < _crew_respawn_at:
		return
	_crew_respawn_at = -1.0
	ships[CREW] = ShipState.new()
	_evacuated.erase(CREW)
	station_owner.clear()
	print("[server] the crew's ship is back")
	Net.send_message(0, "The ship is back. All hands on deck!")
	for id in players:
		players[id].station = -1
		players[id].bucket = false
		_teleport(id, LocalPlayer.Mode.ON_SHIP, _free_spawn(id), 0.0)


func _handle_sinking() -> void:
	for id in ships.keys():
		var s: ShipState = ships[id]
		if not s.is_sinking():
			continue
		if not _evacuated.has(id):
			_evacuated[id] = true
			_evacuate(id)
			if id == CREW:
				stats.crew_sunk += 1
				Net.send_message(0, "We're sinking! Abandon ship!")
			else:
				Net.send_message(0, "The skeleton ship is going down!")
		if s.sink >= 1.0:
			if id == CREW:
				if _crew_respawn_at < 0.0:
					_crew_respawn_at = time + CREW_RESPAWN_DELAY
			else:
				ships.erase(id)
				captains.erase(id)
				_evacuated.erase(id)
				stats.ai_sunk += 1
				next_ai_time = time + AI_RESPAWN_DELAY
				print("[server] skeleton ship %d sunk" % id)


## Everyone aboard a sinking ship goes into the sea where they stood.
func _evacuate(ship_id: int) -> void:
	var pose := ShipPhysics.pose_of(ships[ship_id], time)
	for id in players:
		var r: Dictionary = players[id]
		if r.mode != LocalPlayer.Mode.ON_SHIP or r.ship != ship_id:
			continue
		_free_station_of(id)
		r.bucket = false
		var world: Vector3 = pose * r.pos
		world.y = maxf(world.y, Waves.height(world.x, world.z, time) + 0.5)
		_teleport(id, LocalPlayer.Mode.WORLD, world, r.yaw + ships[ship_id].yaw)


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
		return true
	for island in Islands.LAYOUT:
		var dx: float = pos.x - island.x
		var dz: float = pos.z - island.z
		if dx * dx + dz * dz < (island.radius + 14.0) ** 2 and pos.y < IslandMesh.ground(island, dx, dz) + 0.3:
			Net.send_event("impact", [p.id, 3, pos.x, pos.y, pos.z, -1, time])
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
			if ship_id == CREW:
				Net.send_message(0, "We're hit! Water on the lower deck!")
		else:
			s.water = minf(ShipPhysics.SINK_LEVEL, s.water + 0.15)
	Net.send_event("impact", [p.id, kind, world.x, world.y, world.z, ship_id, time])


# =====================================================================================
# Players
# =====================================================================================

## "" if a new player may join, otherwise the reason they may not.
func can_join(version: String) -> String:
	if version != GameConfig.VERSION:
		return "This server runs version %s; you have %s." % [GameConfig.VERSION, version]
	if players.size() >= GameConfig.MAX_PLAYERS:
		return "The crew is full (%d players)." % GameConfig.MAX_PLAYERS
	return ""


func add_player(id: int, player_name: String) -> void:
	var clean := player_name.strip_edges().substr(0, 20)
	if clean == "":
		clean = "Pirate %d" % (players.size() + 1)
	players[id] = {
		"name": clean, "mode": LocalPlayer.Mode.ON_SHIP, "ship": CREW, "pos": Vector3.ZERO,
		"yaw": 0.0, "pitch": 0.0, "station": -1, "seq": 0, "time": time, "bucket": false,
		"last_patch": -1.0,
	}
	roster[id] = clean
	print("[server] %s joined (peer %d)" % [clean, id])
	Net.send_roster(roster)
	if crew_ship().is_sinking():
		var c := crew_ship()
		_teleport(id, LocalPlayer.Mode.WORLD, Vector3(c.x + 12.0, 0.5, c.z), 0.0)
	else:
		_teleport(id, LocalPlayer.Mode.ON_SHIP, _free_spawn(id), 0.0)
	Net.send_message(0, "%s came aboard" % clean)


## Returns the name of the player who left, or "".
func remove_player(id: int) -> String:
	if not players.has(id):
		return ""
	_free_station_of(id)
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
	if int(data[0]) != r.seq:
		return  # still from before our last teleport
	var mode := int(data[1])
	var pos := Vector3(data[2], data[3], data[4])
	var elapsed := maxf(time - r.time, 1.0 / GameConfig.PLAYER_SEND_RATE)
	var crew := crew_ship()

	var ok := true
	if mode == r.mode:
		ok = pos.distance_to(r.pos) <= MAX_PLAYER_SPEED * elapsed + 2.0
		if mode == LocalPlayer.Mode.ON_SHIP:
			ok = ok and absf(pos.x) < 8.0 and absf(pos.z) < 22.0 and pos.y > -4.0 and pos.y < 40.0
	elif r.mode == LocalPlayer.Mode.ON_SHIP and mode == LocalPlayer.Mode.WORLD:
		ok = Vector2(pos.x, pos.z).distance_to(Vector2(crew.x, crew.z)) < 40.0
	else:
		ok = false  # only the server moves people back aboard

	if not ok:
		stats.corrections += 1
		_teleport(id, r.mode, r.pos, r.yaw)
		return
	if mode == LocalPlayer.Mode.WORLD:
		_free_station_of(id)
		r.bucket = false
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
		crew_ship().gun_yaw[gun] = clampf(aim.x, -ShipShape.CANNON_YAW_LIMIT, ShipShape.CANNON_YAW_LIMIT)
		crew_ship().gun_pitch[gun] = clampf(aim.y, ShipShape.CANNON_PITCH_MIN, ShipShape.CANNON_PITCH_MAX)


func request(id: int, action: String, arg: int, data: Array) -> void:
	if not players.has(id):
		return
	var r: Dictionary = players[id]
	match action:
		"station":
			_take_station(id, r, arg)
		"leave":
			if r.station == arg:
				_free_station_of(id)
		"climb":
			_climb(id, r, arg)
		"respawn":
			_free_station_of(id)
			r.bucket = false
			if not crew_ship().is_sinking():
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


func _take_station(id: int, r: Dictionary, station: int) -> void:
	if station < 0 or station >= _stations.size() or r.mode != LocalPlayer.Mode.ON_SHIP:
		return
	if crew_ship().is_sinking() or r.station == station:
		return
	var st: Dictionary = _stations[station]
	if station_owner.has(station) and station_owner[station] != id:
		Net.send_message(id, "%s is already on it" % roster.get(station_owner[station], "Someone"))
		return
	if r.pos.distance_to(st.stand) > 4.0:
		return
	_free_station_of(id)
	station_owner[station] = id
	r.station = station
	stats.stations_taken += 1
	print("[server] %s took station %d" % [r.name, station])
	var face := 0.0
	if st.kind == ShipShape.Kind.CANNON:
		face = -PI / 2.0 * st.side
	_teleport(id, LocalPlayer.Mode.ON_SHIP, st.stand, face)


func _climb(id: int, r: Dictionary, side: int) -> void:
	var crew := crew_ship()
	if r.mode != LocalPlayer.Mode.WORLD or absi(side) != 1 or crew.is_sinking():
		return
	var pose := ShipPhysics.pose_of(crew, time)
	var bottom := pose * ShipShape.ladder_bottom(side)
	if Vector2(r.pos.x - bottom.x, r.pos.z - bottom.z).length() > LADDER_TOLERANCE:
		return
	stats.climbs += 1
	print("[server] %s climbed aboard" % r.name)
	# Face inboard: starboard ladder looks toward -x, which is a quarter turn left.
	_teleport(id, LocalPlayer.Mode.ON_SHIP, ShipShape.ladder_top(side), PI / 2.0 * side)


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
	var s := crew_ship()
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
		h[4] = float(h[4]) + clampf(gap, 0.0, 0.35) / PATCH_TIME
		if h[4] >= 1.0:
			s.holes.erase(h)
			stats.patched += 1
			print("[server] %s patched hole %d" % [r.name, hole_id])
		return


func _scoop(r: Dictionary) -> void:
	var s := crew_ship()
	if r.mode != LocalPlayer.Mode.ON_SHIP or r.bucket or s.water < 0.1:
		return
	if ShipShape.is_below_deck(r.pos) and r.pos.y < ShipShape.LOWER_Y + s.water + 0.3:
		r.bucket = true


func _throw(r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.ON_SHIP or not r.bucket or r.pos.y < ShipShape.DECK_Y - 0.5:
		return
	r.bucket = false
	_pending_bail[CREW] = _pending_bail.get(CREW, 0.0) + BUCKET
	stats.bailed += 1


func _player_fire(r: Dictionary, station: int, aim: Array) -> void:
	if r.station != station or station < 0 or aim.size() != 2:
		return
	var st: Dictionary = _stations[station]
	if st.kind != ShipShape.Kind.CANNON or crew_ship().is_sinking():
		return
	if crew_ship().gun_reload[st.gun] > 0.0:
		return
	_fire(CREW, st.gun, float(aim[0]), float(aim[1]), PLAYER_RELOAD)


func _free_station_of(id: int) -> void:
	if not players.has(id):
		return
	var r: Dictionary = players[id]
	if r.station >= 0 and station_owner.get(r.station) == id:
		station_owner.erase(r.station)
	r.station = -1
	station_input.erase(id)


func _free_spawn(for_id: int) -> Vector3:
	for spot in ShipShape.SPAWNS:
		var taken := false
		for id in players:
			var r: Dictionary = players[id]
			if id != for_id and r.mode == LocalPlayer.Mode.ON_SHIP and r.pos.distance_to(spot) < 0.8:
				taken = true
		if not taken:
			return spot
	return ShipShape.SPAWNS[0]


func _teleport(id: int, mode: int, pos: Vector3, yaw: float) -> void:
	var r: Dictionary = players[id]
	r.seq += 1
	r.mode = mode
	r.ship = CREW
	r.pos = pos
	r.yaw = yaw
	r.time = time
	Net.send_teleport(id, [r.seq, mode, pos.x, pos.y, pos.z, yaw])


static func compass_name(heading: float) -> String:
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	return names[int(round(fposmod(rad_to_deg(heading), 360.0) / 45.0)) % 8]

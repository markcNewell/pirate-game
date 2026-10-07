class_name Game
extends Node3D
## One play session. The same node plays up to two parts:
##
## - Server (dedicated or host): owns the ship, the wind and the crew list, steps the sailing
##   physics, checks what players report, and sends snapshots ~30 times a second.
## - Client (joined or host): keeps a short buffer of snapshots, draws everything
##   GameConfig.RENDER_DELAY in the past by blending the two snapshots around that moment,
##   and runs the local player.
##
## The host does both, and feeds its own snapshots into its client half, so there is one
## drawing path for everybody.

enum Role { SERVER, CLIENT, HOST }

const WIND_TURN_SECONDS := 1200.0
const STATION_INPUT_TIMEOUT := 0.5
const MAX_PLAYER_SPEED := 15.0
const LADDER_TOLERANCE := 6.0

var role := Role.CLIENT
var local_id := 0
## Non-empty for a test bot: which job it heads for.
var bot_role := ""

var roster := {}  # peer id -> name

# --- what is drawn this frame (clients) ---
var render_time := 0.0
var view_ship := ShipState.new()
var view_wind := Vector2(0, -1)
var view_players := {}  # peer id -> {mode, pos, yaw, pitch, station}

var world: World
var ship_view: ShipView
var proxy: DeckProxy
var local_player: LocalPlayer
var hud: Hud
var avatars := {}  # peer id -> Avatar
var free_camera: Camera3D

# --- authoritative state (server) ---
var server_time := 0.0
var ship := ShipState.new()
var players := {}  # peer id -> record, see _new_record
var station_owner := {}  # station id -> peer id
var station_axes := {}  # peer id -> {"axes": Vector2, "time": float}
var _stations := ShipShape.stations()
var _snapshot_timer := 0.0
var _log_timer := 0.0
var _ship_start := Vector2.ZERO
var stats := {"max_speed": 0.0, "stations_taken": 0, "climbs": 0, "corrections": 0}

# --- snapshot buffer (clients) ---
var _snaps: Array[Dictionary] = []
var _clock_offset := 0.0
var _have_clock := false


func setup(r: Role, my_id: int, bot := "") -> Game:
	role = r
	local_id = my_id
	bot_role = bot
	return self


func is_server() -> bool:
	return role != Role.CLIENT


func has_view() -> bool:
	return role != Role.SERVER


func _ready() -> void:
	if has_view():
		_build_view()
	if is_server():
		ship = ShipState.new()
		_ship_start = Vector2(ship.x, ship.z)
		print("[server] session started, version %s" % GameConfig.VERSION)


func _build_view() -> void:
	world = World.new()
	add_child(world)
	ship_view = ShipView.new()
	add_child(ship_view)
	proxy = DeckProxy.new()
	add_child(proxy)
	local_player = LocalPlayer.new()
	local_player.game = self
	local_player.input.is_bot = bot_role != ""
	add_child(local_player)
	if bot_role != "":
		var bot := Bot.new()
		bot.setup(self, bot_role)
		add_child(bot)
	else:
		hud = Hud.new()
		hud.game = self
		add_child(hud)


static func wind_angle(t: float) -> float:
	return wrapf(t * TAU / WIND_TURN_SECONDS, -PI, PI)


static func wind_dir(t: float) -> Vector2:
	return ShipPhysics.forward(wind_angle(t))


# =====================================================================================
# Server
# =====================================================================================

func _physics_process(delta: float) -> void:
	if is_server():
		_server_tick(delta)


func _server_tick(dt: float) -> void:
	server_time += dt
	ShipPhysics.step(ship, _gather_controls(), wind_dir(server_time), dt, Islands.ship_blockers())
	stats.max_speed = maxf(stats.max_speed, ship.speed)

	_snapshot_timer += dt
	if _snapshot_timer >= 1.0 / GameConfig.SNAPSHOT_RATE:
		_snapshot_timer = 0.0
		var snap := _snapshot()
		Net.send_snapshot(snap)
		if has_view():
			client_on_snapshot(snap)

	_log_timer += dt
	if _log_timer >= 2.0 and (role == Role.SERVER or DisplayServer.get_name() == "headless"):
		_log_timer = 0.0
		print("[server] t=%.0f players=%d ship=(%.1f, %.1f) speed=%.2f anchored=%s sails=%.2f/%.2f stations=%s" % [
			server_time, players.size(), ship.x, ship.z, ship.speed, ship.anchored,
			ship.sail_height[0], ship.sail_height[1], station_owner,
		])


func _gather_controls() -> ShipControls:
	var c := ShipControls.new()
	for id in station_owner:
		var peer: int = station_owner[id]
		var input: Dictionary = station_axes.get(peer, {})
		if input.is_empty() or server_time - input.time > STATION_INPUT_TIMEOUT:
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


func _snapshot() -> Array:
	var list := []
	for id in players:
		var r: Dictionary = players[id]
		list.append([id, r.mode, r.pos.x, r.pos.y, r.pos.z, r.yaw, r.pitch, r.station])
	return [server_time, ship.to_array(), list]


## "" if a new player may join, otherwise the reason they may not.
func server_can_join(version: String) -> String:
	if version != GameConfig.VERSION:
		return "This server runs version %s; you have %s." % [GameConfig.VERSION, version]
	if players.size() >= GameConfig.MAX_PLAYERS:
		return "The crew is full (%d players)." % GameConfig.MAX_PLAYERS
	return ""


func server_add_player(id: int, player_name: String) -> void:
	var clean := player_name.strip_edges().substr(0, 20)
	if clean == "":
		clean = "Pirate %d" % (players.size() + 1)
	var spawn := _free_spawn()
	players[id] = {
		"name": clean, "mode": LocalPlayer.Mode.ON_SHIP, "pos": spawn, "yaw": 0.0, "pitch": 0.0,
		"station": -1, "seq": 0, "time": server_time,
	}
	roster[id] = clean
	print("[server] %s joined (peer %d)" % [clean, id])
	Net.send_roster(roster)
	_server_teleport(id, LocalPlayer.Mode.ON_SHIP, spawn, 0.0)
	Net.send_message(0, "%s came aboard" % clean)


func server_remove_player(id: int) -> void:
	if not players.has(id):
		return
	_free_station_of(id)
	var who: String = players[id].name
	print("[server] %s left (peer %d)" % [who, id])
	players.erase(id)
	roster.erase(id)
	station_axes.erase(id)
	# Tell the others next frame, once the departed peer is off the send list.
	_announce_departure.call_deferred(who)


func _announce_departure(who: String) -> void:
	if multiplayer.get_peers().is_empty() and not has_view():
		return
	Net.send_message(0, "%s left the crew" % who)
	Net.send_roster(roster)


## A player reports where they are: [teleport seq, mode, x, y, z, yaw, pitch].
func server_player_state(id: int, data: Array) -> void:
	if not players.has(id) or data.size() != 7:
		return
	var r: Dictionary = players[id]
	if int(data[0]) != r.seq:
		return  # still from before our last teleport
	var mode := int(data[1])
	var pos := Vector3(data[2], data[3], data[4])
	var elapsed := maxf(server_time - r.time, 1.0 / GameConfig.PLAYER_SEND_RATE)

	var ok := true
	if mode == r.mode:
		ok = pos.distance_to(r.pos) <= MAX_PLAYER_SPEED * elapsed + 2.0
		if mode == LocalPlayer.Mode.ON_SHIP:
			ok = ok and absf(pos.x) < 8.0 and absf(pos.z) < 22.0 and pos.y > -4.0 and pos.y < 40.0
	elif r.mode == LocalPlayer.Mode.ON_SHIP and mode == LocalPlayer.Mode.WORLD:
		ok = Vector2(pos.x, pos.z).distance_to(Vector2(ship.x, ship.z)) < 40.0
	else:
		ok = false  # only the server moves people back aboard

	if not ok:
		stats.corrections += 1
		_server_teleport(id, r.mode, r.pos, r.yaw)
		return
	if mode == LocalPlayer.Mode.WORLD:
		_free_station_of(id)
	r.mode = mode
	r.pos = pos
	r.yaw = float(data[5])
	r.pitch = float(data[6])
	r.time = server_time


func server_station_input(id: int, axes: Vector2) -> void:
	if players.has(id):
		station_axes[id] = {"axes": axes.limit_length(1.4), "time": server_time}


func server_request(id: int, action: String, arg: int) -> void:
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
			_server_teleport(id, LocalPlayer.Mode.ON_SHIP, _free_spawn(), 0.0)


func _take_station(id: int, r: Dictionary, station: int) -> void:
	if station < 0 or station >= _stations.size() or r.mode != LocalPlayer.Mode.ON_SHIP:
		return
	var st: Dictionary = _stations[station]
	if r.station == station:
		return
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
	_server_teleport(id, LocalPlayer.Mode.ON_SHIP, st.stand, 0.0)


func _climb(id: int, r: Dictionary, side: int) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or absi(side) != 1:
		return
	var pose := ShipPhysics.pose(ship.x, ship.z, ship.yaw, server_time)
	var bottom := pose * ShipShape.ladder_bottom(side)
	if Vector2(r.pos.x - bottom.x, r.pos.z - bottom.z).length() > LADDER_TOLERANCE:
		return
	stats.climbs += 1
	print("[server] %s climbed aboard" % r.name)
	# Face inboard: starboard ladder looks toward -x, which is a quarter turn left.
	_server_teleport(id, LocalPlayer.Mode.ON_SHIP, ShipShape.ladder_top(side), PI / 2.0 * side)


func _free_station_of(id: int) -> void:
	if not players.has(id):
		return
	var r: Dictionary = players[id]
	if r.station >= 0 and station_owner.get(r.station) == id:
		station_owner.erase(r.station)
	r.station = -1
	station_axes.erase(id)


func _free_spawn() -> Vector3:
	for spot in ShipShape.SPAWNS:
		var taken := false
		for id in players:
			var r: Dictionary = players[id]
			if r.mode == LocalPlayer.Mode.ON_SHIP and r.pos.distance_to(spot) < 0.8:
				taken = true
		if not taken:
			return spot
	return ShipShape.SPAWNS[0]


func _server_teleport(id: int, mode: int, pos: Vector3, yaw: float) -> void:
	var r: Dictionary = players[id]
	r.seq += 1
	r.mode = mode
	r.pos = pos
	r.yaw = yaw
	r.time = server_time
	Net.send_teleport(id, [r.seq, mode, pos.x, pos.y, pos.z, yaw])


# =====================================================================================
# Client
# =====================================================================================

func client_on_snapshot(data: Array) -> void:
	var t: float = data[0]
	var now := Time.get_ticks_usec() / 1e6
	var sample := t - now
	# Track the least-delayed packets: jump up at once, drift down slowly.
	if not _have_clock or sample > _clock_offset:
		_clock_offset = sample
		_have_clock = true
	else:
		_clock_offset = lerpf(_clock_offset, sample, 0.02)

	var snap_players := {}
	for p in data[2]:
		snap_players[int(p[0])] = {
			"mode": int(p[1]), "pos": Vector3(p[2], p[3], p[4]), "yaw": float(p[5]),
			"pitch": float(p[6]), "station": int(p[7]),
		}
	if not _snaps.is_empty() and t <= _snaps.back().t:
		return
	_snaps.append({"t": t, "ship": ShipState.from_array(data[1]), "players": snap_players})
	while _snaps.size() > 2 and _snaps[1].t < t - 1.0:
		_snaps.pop_front()


func client_on_teleport(data: Array) -> void:
	if local_player:
		local_player.apply_teleport(data)


func client_on_roster(new_roster: Dictionary) -> void:
	roster = new_roster
	if not has_view():
		return
	for id in avatars.keys():
		if not roster.has(id):
			avatars[id].queue_free()
			avatars.erase(id)
	var index := 0
	var ids := roster.keys()
	ids.sort()
	for id in ids:
		if id != local_id and not avatars.has(id):
			var avatar := Avatar.new(roster[id], index)
			avatar.visible = false
			add_child(avatar)
			avatars[id] = avatar
		index += 1


func client_on_message(text: String) -> void:
	if hud:
		hud.toast(text)
	elif bot_role != "":
		print("[bot %s] message: %s" % [bot_role, text])


func _process(delta: float) -> void:
	if not has_view() or _snaps.is_empty():
		return
	render_time = Time.get_ticks_usec() / 1e6 + _clock_offset - GameConfig.RENDER_DELAY
	_interpolate(render_time)
	view_wind = wind_dir(render_time)

	var pose := ShipPhysics.pose(view_ship.x, view_ship.z, view_ship.yaw, render_time)
	ship_view.apply(view_ship, pose, view_wind, delta)

	var me: Dictionary = view_players.get(local_id, {})
	if not me.is_empty():
		local_player.station = me.station if local_player.mode == LocalPlayer.Mode.ON_SHIP else -1
	local_player.update_view()

	for id in avatars:
		var avatar: Avatar = avatars[id]
		var p: Dictionary = view_players.get(id, {})
		avatar.visible = not p.is_empty()
		if p.is_empty():
			continue
		var feet := Transform3D(Basis(Vector3.UP, p.yaw), p.pos)
		avatar.place(ship_view.global_transform * feet if p.mode == LocalPlayer.Mode.ON_SHIP else feet, delta)

	var cam := get_viewport().get_camera_3d()
	world.follow(cam.global_position if cam else Vector3.ZERO, render_time, view_ship)


func _interpolate(t: float) -> void:
	var a: Dictionary = _snaps[0]
	var b: Dictionary = _snaps[0]
	var past_end: bool = t >= _snaps.back().t
	if past_end:
		a = _snaps.back()
		b = a
	else:
		for i in _snaps.size() - 1:
			if _snaps[i].t <= t and _snaps[i + 1].t >= t:
				a = _snaps[i]
				b = _snaps[i + 1]
				break
	var span: float = b.t - a.t
	var w := clampf((t - a.t) / span, 0.0, 1.0) if span > 1e-6 else 1.0
	view_ship = ShipState.blend(a.ship, b.ship, w)
	if past_end:
		# Ran past the newest snapshot (a late packet): coast along for a moment.
		var ahead := minf(t - b.t, 0.25)
		var f := ShipPhysics.forward(view_ship.yaw) * view_ship.speed * ahead
		view_ship.x += f.x
		view_ship.z += f.y

	view_players.clear()
	for id in b.players:
		var pb: Dictionary = b.players[id]
		var pa: Dictionary = a.players.get(id, pb)
		if pa.mode != pb.mode:
			pa = pb
		view_players[id] = {
			"mode": pb.mode, "pos": pa.pos.lerp(pb.pos, w), "yaw": lerp_angle(pa.yaw, pb.yaw, w),
			"pitch": lerpf(pa.pitch, pb.pitch, w), "station": pb.station,
		}


# --- client -> server, hiding whether the server is this process ---

func send_player_state(data: Array) -> void:
	if is_server():
		server_player_state(local_id, data)
	else:
		Net.send_player_state(data)


func send_station_input(axes: Vector2) -> void:
	if is_server():
		server_station_input(local_id, axes)
	else:
		Net.send_station_input(axes)


func send_request(action: String, arg: int) -> void:
	if is_server():
		server_request(local_id, action, arg)
	else:
		Net.send_request(action, arg)


## Distance from the local player to the ship (for the respawn offer).
func distance_to_ship() -> float:
	if local_player == null or local_player.mode == LocalPlayer.Mode.ON_SHIP:
		return 0.0
	var p := local_player.body.global_position
	return Vector2(p.x - view_ship.x, p.z - view_ship.z).length()

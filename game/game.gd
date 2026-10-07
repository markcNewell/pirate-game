class_name Game
extends Node3D
## One play session. The same node plays up to two parts:
##
## - Server (dedicated or host): runs the ServerSim (ships, cannonballs, skeletons, crew) and
##   sends snapshots ~30 times a second.
## - Client (joined or host): keeps a short buffer of snapshots, draws everything
##   GameConfig.RENDER_DELAY in the past by blending the two snapshots around that moment,
##   and runs the local player.
##
## The host does both, and feeds its own snapshots into its client half, so there is one
## drawing path for everybody.

enum Role { SERVER, CLIENT, HOST }

const WIND_TURN_SECONDS := 1200.0

var role := Role.CLIENT
var local_id := 0
## Non-empty for a test bot: which job it heads for.
var bot_role := ""
var options := {}

var roster := {}  # peer id -> name

# --- what is drawn this frame (clients) ---
var render_time := 0.0
var view_ships := {}  # ship id -> ShipState
var view_ship := ShipState.new()  # our crew's ship
## Our crew's number and its ship's id (the same number), once the server has placed us.
var own_crew := ServerSim.CREW
var own_ship := ServerSim.CREW
## Every crew's purse: crew -> gold.
var purses := {}
var view_wind := Vector2(0, -1)
var view_players := {}  # peer id -> {mode, ship, pos, yaw, pitch, station, bucket, carry}
var view_items := {}  # item id -> Loot
var view_skeletons := {}  # skeleton id -> Skeleton
## The crew's gold and current treasure hunt ({island, x, z} or empty), as last heard.
var purse := 0
var voyage := {}

var world: World
var ship_views := {}  # ship id -> ShipView
var ship_view: ShipView  # our crew's ship (null until the first snapshot)
var proxy: DeckProxy
var local_player: LocalPlayer
var hud: Hud
var effects: Effects
## Ships we have seen start to sink (id -> time since the last bubbles).
var _wrecked := {}
var _creak_wait := 5.0
var avatars := {}  # peer id -> Avatar
var _item_views := {}  # item id -> LootView
var _skeleton_views := {}  # skeleton id -> SkeletonView

# --- server ---
var sim: ServerSim
var _snapshot_timer := 0.0
var _log_timer := 0.0

# --- snapshot buffer and cannonballs in flight (clients) ---
var _snaps: Array[Dictionary] = []
var _clock_offset := 0.0
var _have_clock := false
var _balls := {}  # projectile id -> {t0, p0, v0, node, end}
var _pending_impacts := {}  # projectile id -> impact data that arrived before the shot


func setup(r: Role, my_id: int, bot := "", opts: Dictionary = {}) -> Game:
	role = r
	local_id = my_id
	bot_role = bot
	options = opts
	return self


func is_server() -> bool:
	return role != Role.CLIENT


func has_view() -> bool:
	return role != Role.SERVER


func _ready() -> void:
	if is_server():
		sim = ServerSim.new(options)
		print("[server] session started, version %s" % GameConfig.VERSION)
	if has_view():
		_build_view()


func _build_view() -> void:
	world = World.new()
	add_child(world)
	effects = Effects.new()
	add_child(effects)
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


func _ship_view_for(id: int, s: ShipState) -> ShipView:
	if not ship_views.has(id):
		var v := ShipView.new()
		v.kind = s.kind
		v.crew = s.crew
		add_child(v)
		ship_views[id] = v
	return ship_views[id]


static func wind_angle(t: float) -> float:
	return wrapf(t * TAU / WIND_TURN_SECONDS, -PI, PI)


static func wind_dir(t: float) -> Vector2:
	return ShipPhysics.forward(wind_angle(t))


# =====================================================================================
# Server side: thin wrappers around the sim
# =====================================================================================

func _physics_process(delta: float) -> void:
	if not is_server():
		return
	sim.tick(delta)
	_snapshot_timer += delta
	if _snapshot_timer >= 1.0 / GameConfig.SNAPSHOT_RATE:
		_snapshot_timer = 0.0
		var snap := sim.snapshot()
		Net.send_snapshot(snap)
		if has_view():
			client_on_snapshot(snap)
	_log_timer += delta
	if _log_timer >= 2.0 and (role == Role.SERVER or DisplayServer.get_name() == "headless"):
		_log_timer = 0.0
		print("[server] " + sim.log_line())


func server_can_join(version: String) -> String:
	return sim.can_join(version)


func server_add_player(id: int, player_name: String, crew := 0) -> void:
	sim.add_player(id, player_name, crew)
	roster = sim.roster


func server_remove_player(id: int) -> void:
	var who := sim.remove_player(id)
	roster = sim.roster
	if who != "":
		# Tell the others next frame, once the departed peer is off the send list.
		_announce_departure.call_deferred(who)


func _announce_departure(who: String) -> void:
	if multiplayer.get_peers().is_empty() and not has_view():
		return
	Net.send_message(0, "%s left the crew" % who)
	Net.send_roster(sim.roster)


func server_player_state(id: int, data: Array) -> void:
	sim.player_state(id, data)


func server_station_input(id: int, axes: Vector2, aim: Vector2) -> void:
	sim.set_station_input(id, axes, aim)


func server_request(id: int, action: String, arg: int, data: Array) -> void:
	sim.request(id, action, arg, data)


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

	if not _snaps.is_empty() and t <= _snaps.back().t:
		return
	var snap_ships := {}
	for entry in data[1]:
		snap_ships[int(entry[0])] = ShipState.from_array(entry[1])
	var snap_players := {}
	for p in data[2]:
		snap_players[int(p[0])] = {
			"mode": int(p[1]), "ship": int(p[2]), "pos": Vector3(p[3], p[4], p[5]), "yaw": float(p[6]),
			"pitch": float(p[7]), "station": int(p[8]), "bucket": int(p[9]) == 1, "carry": int(p[10]),
			"hp": int(p[11]), "dead": int(p[12]) == 1, "weapon": int(p[13]), "crew": int(p[14]),
			"act": int(p[15]) if p.size() > 15 else 0,
		}
	var snap_items := {}
	for entry in data[3]:
		var item := Loot.from_array(entry)
		snap_items[item.id] = item
	# Every crew's purse; our own crew's purse and treasure hunt.
	var mine: Dictionary = snap_players.get(local_id, {})
	if not mine.is_empty():
		own_crew = mine.crew
		own_ship = mine.crew
	for entry in data[4]:
		purses[int(entry[0])] = int(entry[1])
		if int(entry[0]) == own_crew:
			if int(entry[1]) > purse and has_view():
				Audio.play("coins", -2.0)
			purse = int(entry[1])
			voyage = {} if entry.size() < 5 else {"island": int(entry[2]), "x": float(entry[3]), "z": float(entry[4])}
	var snap_bones := {}
	for entry in data[5]:
		var sk := Skeleton.from_array(entry)
		snap_bones[sk.id] = sk
	_snaps.append({"t": t, "ships": snap_ships, "players": snap_players, "items": snap_items, "bones": snap_bones})
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
		if id == local_id and local_player and local_player.weapon_view:
			local_player.weapon_view.set_sleeve(Avatar.SHIRTS[index % Avatar.SHIRTS.size()], Avatar.skin_for(index))
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


## Reliable one-off happenings: a cannon fired, a ball landed.
func client_on_event(kind: String, data: Array) -> void:
	if not has_view():
		return
	match kind:
		"shot":
			var id: int = data[0]
			var ball := {
				"t0": float(data[1]), "p0": Vector3(data[2], data[3], data[4]),
				"v0": Vector3(data[5], data[6], data[7]), "ship": int(data[8]), "gun": int(data[9]),
				"node": effects.cannonball(), "end": {}, "fired": false,
			}
			_balls[id] = ball
			if _pending_impacts.has(id):
				ball.end = _pending_impacts[id]
				_pending_impacts.erase(id)
		"swing":
			if _skeleton_views.has(int(data[0])):
				_skeleton_views[int(data[0])].swing()
				Audio.play_at("swing", _skeleton_views[int(data[0])].global_position + Vector3.UP, -4.0, 0.8)
		"hurt_skeleton":
			if _skeleton_views.has(int(data[0])):
				_skeleton_views[int(data[0])].hurt()
				Audio.play_at("rattle", _skeleton_views[int(data[0])].global_position + Vector3.UP)
		"attack":
			if avatars.has(int(data[0])):
				var who: Avatar = avatars[int(data[0])]
				who.attack()
				var pistol := int(data[1]) == Weapons.Kind.PISTOL
				Audio.play_at("pistol" if pistol else "swing", who.global_position + Vector3.UP * 1.4, 0.0 if pistol else -4.0)
		"hurt_player":
			if int(data[0]) == local_id:
				Audio.play("thud", -2.0, 0.8)
			elif avatars.has(int(data[0])):
				avatars[int(data[0])].hurt()
				Audio.play_at("thud", avatars[int(data[0])].global_position + Vector3.UP)
		"alarm":
			Audio.play("bell", -3.0, 1.0, 0.0)
		"lightning":
			if world:
				world.strike(Vector3(data[1], data[2], data[3]))
		"impact":
			var id: int = data[0]
			var end := {"kind": int(data[1]), "pos": Vector3(data[2], data[3], data[4]), "ship": int(data[5]), "t": float(data[6])}
			if _balls.has(id):
				_balls[id].end = end
			else:
				_pending_impacts[id] = end


func _process(delta: float) -> void:
	if not has_view() or _snaps.is_empty():
		return
	render_time = Time.get_ticks_usec() / 1e6 + _clock_offset - GameConfig.RENDER_DELAY
	_interpolate(render_time)
	view_wind = wind_dir(render_time)

	for id in ship_views.keys():
		if not view_ships.has(id):
			ship_views[id].queue_free()
			ship_views.erase(id)
	for id in view_ships:
		var s: ShipState = view_ships[id]
		var v := _ship_view_for(id, s)
		var gale := Storm.wind(Vector2(s.x, s.z), render_time, view_wind).normalized()
		v.apply(s, ShipPhysics.pose_of(s, render_time), gale, delta)
		_sinking_effects(id, s, delta)
	view_ship = view_ships.get(own_ship, view_ship)
	ship_view = ship_views.get(own_ship)
	# The HUD's wind arrow shows the wind where our ship is, swirling if she is in the storm.
	view_wind = Storm.wind(Vector2(view_ship.x, view_ship.z), render_time, view_wind).normalized()
	_ship_sounds(delta)
	if ship_view == null:
		return

	var me: Dictionary = view_players.get(local_id, {})
	if not me.is_empty():
		local_player.station = me.station if local_player.mode == LocalPlayer.Mode.ON_SHIP else -1
		local_player.bucket = me.bucket
		local_player.carry = me.carry
		if me.hp < local_player.hp and hud:
			hud.flash_damage()
		if me.hp > local_player.hp and not me.dead and not local_player.dead:
			Audio.play("chomp", -4.0)
		if me.carry != local_player.carry:
			Audio.play("thud", -6.0)
		local_player.hp = me.hp
		local_player.dead = me.dead
	local_player.update_view()
	if local_player.station >= 0 and ShipShape.stations()[local_player.station].kind == ShipShape.Kind.CANNON:
		# Our own cannon follows the mouse at once rather than waiting for the server.
		var gun: int = ShipShape.stations()[local_player.station].gun
		ship_view.aim_gun(gun, local_player.cannon_aim())

	for id in avatars:
		var avatar: Avatar = avatars[id]
		var p: Dictionary = view_players.get(id, {})
		avatar.visible = not p.is_empty()
		if p.is_empty():
			continue
		var feet := Transform3D(Basis(Vector3.UP, p.yaw), p.pos)
		var on_ship: bool = p.mode == LocalPlayer.Mode.ON_SHIP and ship_views.has(p.ship)
		var kind: int = ShipShape.stations()[p.station].kind if p.station >= 0 else -1
		# Afloat out of their ship with the feet well below the sea's mean level: swimming.
		var swimming: bool = p.mode == LocalPlayer.Mode.WORLD and p.pos.y < -0.5
		avatar.set_state(kind, swimming, p.carry >= 0, p.act)
		avatar.place(ship_views[p.ship].global_transform * feet if on_ship else feet, delta, p.pos)
		avatar.set_bucket(p.bucket)
		avatar.set_hostile(p.crew != own_crew)
		avatar.set_weapon(p.weapon)
		avatar.set_pitch(p.pitch)
		avatar.visible = not p.dead

	_update_balls()
	_update_items()
	_update_skeletons(delta)
	var cam := get_viewport().get_camera_3d()
	world.follow(cam.global_position if cam else Vector3.ZERO, render_time, view_ships)


## The world transform of a ship's frame (our own ship's if that one is gone).
func frame_transform(ship_id: int) -> Transform3D:
	var v: ShipView = ship_views.get(ship_id, ship_view)
	return v.global_transform if v else Transform3D.IDENTITY


func _update_skeletons(delta: float) -> void:
	for id in _skeleton_views.keys():
		if not view_skeletons.has(id):
			_skeleton_views[id].queue_free()
			_skeleton_views.erase(id)
	for id in view_skeletons:
		var sk: Skeleton = view_skeletons[id]
		if not _skeleton_views.has(id):
			var v := SkeletonView.new()
			add_child(v)
			_skeleton_views[id] = v
		var at := Transform3D(Basis(Vector3.UP, sk.yaw), sk.pos)
		if sk.frame >= 0:
			if not ship_views.has(sk.frame):
				continue
			at = ship_views[sk.frame].global_transform * at
		_skeleton_views[id].place(at, sk.walking, not sk.alive(), delta)


## Place every chest and barrel: on the ground, afloat, stowed aboard or in someone's arms.
func _update_items() -> void:
	for id in _item_views.keys():
		if not view_items.has(id):
			_item_views[id].queue_free()
			_item_views.erase(id)
	for id in view_items:
		var item: Loot = view_items[id]
		if not _item_views.has(id):
			var v := LootView.new().setup(item.kind, item.value)
			add_child(v)
			_item_views[id] = v
		var view: LootView = _item_views[id]
		view.set_glint(item.state != Loot.State.CARRIED)
		var at := Transform3D(Basis(Vector3.UP, item.yaw), item.pos)
		match item.state:
			Loot.State.ON_SHIP:
				at = frame_transform(item.ship) * at
			Loot.State.CARRIED:
				if item.carrier == local_id:
					# In our own arms: low in front of the camera.
					var cam := local_player.camera.global_transform
					at = Transform3D(cam.basis, cam * Vector3(0.0, -0.75, -0.85))
				elif avatars.has(item.carrier):
					at = avatars[item.carrier].global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.75, -0.55))
		view.global_transform = at


## Bubbles while a ship goes down, and wreckage left floating where she went.
func _sinking_effects(id: int, s: ShipState, delta: float) -> void:
	if s.sink <= 0.0:
		_wrecked.erase(id)
		return
	if not _wrecked.has(id):
		_wrecked[id] = 0.0
		effects.wreckage(Vector3(s.x, 0.0, s.z))
	if s.sink < 1.0:
		_wrecked[id] += delta
		if _wrecked[id] > 0.15:
			_wrecked[id] = 0.0
			effects.bubbles(Vector3(s.x, 0.0, s.z))


## Aboard a ship: water rushing past the hull as she gathers speed, and her timbers creaking
## now and then, more often in a storm.
func _ship_sounds(delta: float) -> void:
	var aboard := local_player.mode == LocalPlayer.Mode.ON_SHIP and view_ships.has(local_player.ship_id)
	if not aboard:
		Audio.set_ambience("bow_wash", -80.0)
		return
	var s: ShipState = view_ships[local_player.ship_id]
	Audio.set_ambience("bow_wash", lerpf(-38.0, -9.0, clampf(absf(s.speed) / ShipPhysics.MAX_SPEED, 0.0, 1.0)))
	_creak_wait -= delta
	if _creak_wait <= 0.0:
		var storm := Storm.amount(Vector2(s.x, s.z), render_time)
		_creak_wait = randf_range(4.0, 11.0) * (1.0 - 0.65 * storm)
		Audio.play("creak", -18.0 + 9.0 * storm, randf_range(0.8, 1.25), 0.0)


func _impact_sound(kind: int, pos: Vector3) -> void:
	match kind:
		Effects.Impact.WATER:
			Audio.play_at("splash", pos, 0.0)
		Effects.Impact.HULL:
			Audio.play_at("hull_hit", pos, 4.0)
		Effects.Impact.SPLINTERS:
			Audio.play_at("hull_hit", pos, -2.0, 1.2)
		Effects.Impact.SAND:
			Audio.play_at("thud", pos, 0.0, 0.7)


func _update_balls() -> void:
	for id in _balls.keys():
		var b: Dictionary = _balls[id]
		var age: float = render_time - b.t0
		var node: Node3D = b.node
		node.visible = age >= 0.0
		if age < 0.0:
			continue
		if not b.fired:
			b.fired = true
			if ship_views.has(b.ship):
				ship_views[b.ship].recoil(b.gun)
			effects.muzzle_smoke(b.p0, b.v0.normalized())
			Audio.play_at("cannon", b.p0, 4.0, 1.0, 0.07)
		var end: Dictionary = b.end
		if not end.is_empty() and render_time >= end.t:
			effects.impact(end.kind, end.pos)
			_impact_sound(end.kind, end.pos)
			node.queue_free()
			_balls.erase(id)
			continue
		if age > Ballistics.LIFETIME + 1.0:
			node.queue_free()
			_balls.erase(id)
			continue
		node.global_position = Ballistics.position(b.p0, b.v0, age)
		# A thin trail of smoke puffs behind the ball, so you can follow its arc.
		if age - float(b.get("trail", -1.0)) > 0.025:
			b["trail"] = age
			effects.trail(node.global_position)


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

	view_ships = {}
	for id in b.ships:
		var sb: ShipState = b.ships[id]
		var s: ShipState = ShipState.blend(a.ships[id], sb, w) if a.ships.has(id) else sb.copy()
		if past_end:
			# Ran past the newest snapshot (a late packet): coast along for a moment.
			var ahead := minf(t - b.t, 0.25)
			var f := ShipPhysics.forward(s.yaw) * s.speed * ahead
			s.x += f.x
			s.z += f.y
		view_ships[id] = s

	view_items = {}
	for id in b.items:
		var ib: Loot = b.items[id]
		var ia: Loot = a.items.get(id)
		var item := Loot.from_array(ib.to_array())
		if ia and ia.state == ib.state:
			item.pos = ia.pos.lerp(ib.pos, w)
		view_items[id] = item

	view_skeletons = {}
	for id in b.bones:
		var kb: Skeleton = b.bones[id]
		var ka: Skeleton = a.bones.get(id)
		var sk := Skeleton.from_array(kb.to_array())
		if ka and ka.frame == kb.frame:
			sk.pos = ka.pos.lerp(kb.pos, w)
			sk.yaw = lerp_angle(ka.yaw, kb.yaw, w)
		view_skeletons[id] = sk

	view_players.clear()
	for id in b.players:
		var pb: Dictionary = b.players[id]
		var pa: Dictionary = a.players.get(id, pb)
		if pa.mode != pb.mode or pa.ship != pb.ship:
			pa = pb
		view_players[id] = {
			"mode": pb.mode, "ship": pb.ship, "pos": pa.pos.lerp(pb.pos, w),
			"yaw": lerp_angle(pa.yaw, pb.yaw, w), "pitch": lerpf(pa.pitch, pb.pitch, w),
			"station": pb.station, "bucket": pb.bucket, "carry": pb.carry,
			"hp": pb.hp, "dead": pb.dead, "weapon": pb.weapon, "crew": pb.crew, "act": pb.act,
		}


# --- client -> server, hiding whether the server is this process ---

func send_player_state(data: Array) -> void:
	if is_server():
		server_player_state(local_id, data)
	else:
		Net.send_player_state(data)


func send_station_input(axes: Vector2, aim: Vector2) -> void:
	if is_server():
		server_station_input(local_id, axes, aim)
	else:
		Net.send_station_input(axes, aim)


func send_request(action: String, arg: int, data: Array = []) -> void:
	if is_server():
		server_request(local_id, action, arg, data)
	else:
		Net.send_request(action, arg, data)


## Distance from the local player to the ship (for the respawn offer).
func distance_to_ship() -> float:
	if local_player == null or local_player.mode == LocalPlayer.Mode.ON_SHIP:
		return 0.0
	var p := local_player.body.global_position
	return Vector2(p.x - view_ship.x, p.z - view_ship.z).length()


## The nearest hostile ship being drawn (a skeleton ship or another crew's), or null.
func nearest_enemy() -> ShipState:
	var best: ShipState = null
	var best_d := INF
	for id in view_ships:
		var s: ShipState = view_ships[id]
		if id == own_ship or s.is_sinking():
			continue
		var d := Vector2(s.x - view_ship.x, s.z - view_ship.z).length()
		if d < best_d:
			best = s
			best_d = d
	return best



## Display name of a ship: its crew's ship name, or "Skeleton ship".
static func ship_name(s: ShipState) -> String:
	return ServerSim.CREW_NAMES[s.crew - 1] if s.crew > 0 else "Skeleton ship"

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
var view_wind := Vector2(0, -1)
var view_players := {}  # peer id -> {mode, ship, pos, yaw, pitch, station, bucket, carry}
var view_items := {}  # item id -> Loot
var view_skeletons := {}  # skeleton id -> Skeleton
## What the story has put in the world (fires, journals, boats): object id -> StoryObject.
var view_objects := {}
var _object_views := {}  # object id -> StoryObjectView
## Your own pirate as the server keeps them: XP, gold, the title you wear, standing with each
## company and the story chapters done (see ServerSim._send_profile).
var xp := 0
var purse := 0
var title := ""
var rep: Array = [0, 0, 0]
var chapters: Array = []
## What everyone shows over their heads and wears: peer id -> [pirate level, title, outfit, dye].
var tags := {}
## Your own: place in the roster, Martha's outfit and dye you wear (-1 your own), what you own.
var my_index := 0
var my_outfit := -1
var my_dye := -1
## The blade and gun we carry (Weapons.BLADES, Weapons.GUNS).
var my_blade := 0
var my_gun := 0
## How far along each deed we are (Deeds), from the server.
var deeds := {}
var owned: Array = []
## The crew's mission (see _decode_mission; empty with none), as last heard. `voyage` is the
## next X still to dig on a treasure voyage ({island, x, z} or empty).
var mission := {}
var voyage := {}
## Every crew's cargo run, for drawing the traders: crew -> {island, x, z}.
var traders := {}
## The mission board's offers when it was last opened (see Hud.show_board).
var offers: Array = []

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
		# Pirates are remembered between sessions unless told otherwise (tests).
		if not options.has("no-save") and not options.has("profiles"):
			options["profiles"] = "user://profiles"
		sim = ServerSim.new(options)
		print("[server] session started, version %s" % GameConfig.VERSION)
	if has_view():
		_build_view()


func _build_view() -> void:
	world = World.new()
	# Colour every ship's model now, so a ship sailing into view later does not stall a frame.
	ShipView.warm_up()
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
		v.flag = s.flag
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


func server_can_join(version: String, player_name := "", token := "") -> String:
	return sim.can_join(version, player_name, token)


func server_add_player(id: int, player_name: String, crew := 0, token := "") -> void:
	sim.add_player(id, player_name, crew, token)
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
	# Every crew's mission; our own crew's treasure hunt.
	var mine: Dictionary = snap_players.get(local_id, {})
	if not mine.is_empty():
		own_crew = mine.crew
		own_ship = mine.crew
	traders.clear()
	for entry in data[4]:
		var crew_mission := _decode_mission(entry.slice(1))
		if not crew_mission.is_empty() and crew_mission.kind == Missions.Kind.CARGO:
			traders[int(entry[0])] = crew_mission.targets[0]
		if int(entry[0]) == own_crew:
			mission = crew_mission
			voyage = {}
			var digging: bool = not mission.is_empty() and mission.kind == Missions.Kind.TREASURE
			if not mission.is_empty() and mission.kind == Missions.Kind.STORY:
				# A story step with chests to dig (Dig Faster) works the spade like a treasure map.
				var ch := Story.chapter(mission.captain)
				if not ch.is_empty() and mission.handled < ch.steps.size():
					var current: Dictionary = ch.steps[mission.handled]
					digging = int(current.kind) == Story.Step.DIG_RACE or (int(current.kind) == Story.Step.GATHER and str(current.get("where", "")) == "grave")
			if digging:
				for target: Dictionary in mission.targets:
					if not target.done:
						voyage = target
						break
	var snap_bones := {}
	for entry in data[5]:
		var sk := Skeleton.from_array(entry)
		snap_bones[sk.id] = sk
	# Story things stand still, so the newest snapshot's are drawn as they are.
	if data.size() > 6:
		view_objects.clear()
		for entry in data[6]:
			var o := StoryObject.from_array(entry)
			view_objects[o.id] = o
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
			my_index = index
			local_player.weapon_view.set_sleeve(Shop.shirt_of(my_dye, index), Avatar.skin_for(index))
		# Players take looks in order of id, so everyone's differs; when someone joins in
		# between, those after them change to keep it that way.
		if id != local_id and avatars.has(id) and avatars[id].index != index:
			avatars[id].queue_free()
			avatars.erase(id)
		if id != local_id and not avatars.has(id):
			_make_avatar(id, index)
		index += 1


## Another player's figure, in their own look or what they bought from Martha.
func _make_avatar(id: int, index: int) -> void:
	if avatars.has(id):
		avatars[id].queue_free()
	var t: Array = tags.get(id, [1, "", -1, -1, 0, 0])
	var avatar := Avatar.new(roster[id], index, t[2], t[3])
	avatar.visible = false
	add_child(avatar)
	avatars[id] = avatar
	avatar.set_tag(t[0], t[1])
	avatar.set_loadout(t[4], t[5])


func client_on_message(text: String) -> void:
	if hud:
		hud.toast(text)
	elif bot_role != "":
		print("[bot %s] message: %s" % [bot_role, text])


## Reliable one-off happenings: a cannon fired, a ball landed.
func client_on_event(kind: String, data: Array) -> void:
	if kind == "profile":
		# Bots have no view but report their gold, so take this first.
		if int(data[1]) > purse and hud:
			Audio.play("coins", -2.0)
		xp = int(data[0])
		purse = int(data[1])
		title = str(data[2])
		rep = [int(data[3]), int(data[4]), int(data[5])]
		chapters = data[6]
		if data.size() > 9:
			my_outfit = int(data[7])
			my_dye = int(data[8])
			owned = data[9]
			if data.size() > 12:
				deeds = data[12]
			if data.size() > 11 and (int(data[10]) != my_blade or int(data[11]) != my_gun):
				my_blade = int(data[10])
				my_gun = int(data[11])
				if local_player and local_player.weapon_view:
					local_player.weapon_view.set_loadout(my_blade, my_gun)
			if local_player and local_player.weapon_view:
				local_player.weapon_view.set_sleeve(Shop.shirt_of(my_dye, my_index), Avatar.skin_for(my_index))
		if world:
			# Ashore after A Deserter at Dawn; taken in the siege until Act IV frees her.
			world.set_isabel(chapters.has("b1") and (not chapters.has("c6") or chapters.has("d1")))
		if bot_role != "":
			print("[bot %s] profile xp=%d gold=%d chapters=%s" % [bot_role, xp, purse, chapters])
		return
	if not has_view():
		return
	match kind:
		"tags":
			tags.clear()
			for i in range(0, data.size() - 6, 7):
				tags[int(data[i])] = [int(data[i + 1]), str(data[i + 2]), int(data[i + 3]), int(data[i + 4]), int(data[i + 5]), int(data[i + 6])]
			for id in avatars.keys():
				if not tags.has(id):
					continue
				var t: Array = tags[id]
				var a: Avatar = avatars[id]
				if a.outfit != t[2] or a.dye != t[3]:
					# Dressed differently from Martha's: dress the figure again.
					_make_avatar(id, a.index)
				avatars[id].set_tag(t[0], t[1])
				avatars[id].set_loadout(t[4], t[5])
		"level":
			if hud:
				hud.level_up(int(data[0]), str(data[1]))
		"talk":
			if hud:
				hud.show_talk(data)
		"journal":
			if hud:
				hud.show_journal(str(data[0]), str(data[1]))
		"shop":
			if hud:
				hud.show_shop()
		"doused":
			if _object_views.has(int(data[0])):
				_object_views[int(data[0])].set_state(int(data[4]) if data.size() > 4 else 0)
			Audio.play_at("splash", Vector3(data[1], data[2], data[3]), -2.0, 0.7)
		"salted":
			var at := Vector3(data[1], data[2], data[3])
			for k in 6:
				effects.smoke(at + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-1.0, 1.0)))
			Audio.play_at("splash", at, -8.0, 1.6)
		"fuse":
			if _object_views.has(int(data[0])):
				_object_views[int(data[0])].set_state(2)
		"explode":
			var at := Vector3(data[0], data[1], data[2])
			effects.explosion(at)
			Audio.play_at("cannon", at, 2.0, 0.7)
		"risen":
			Audio.play_at("rattle", Vector3(data[0], data[1], data[2]), -2.0, 0.8)
		"glint":
			if _skeleton_views.has(int(data[0])):
				var sk: Skeleton = view_skeletons.get(int(data[0]))
				_skeleton_views[int(data[0])].glint(StoryRun.LINNET_GLINT if sk and sk.linnet else StoryRun.SNIPER_GLINT)
		"blind":
			if int(data[0]) == local_id and hud:
				hud.blind()
				Audio.play("bell", -6.0, 1.8, 0.0)
		"fade":
			var at := Vector3(data[0], data[1], data[2])
			for k in 8:
				effects.smoke(at + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 1.6), randf_range(-0.5, 0.5)))
		"parry":
			if _skeleton_views.has(int(data[0])):
				var v: Node3D = _skeleton_views[int(data[0])]
				v.shield_hit(false)
				Audio.play_at("clang", v.global_position + Vector3.UP * 1.3, 0.0, 1.4)
		"lunge":
			if _skeleton_views.has(int(data[0])):
				var v: Node3D = _skeleton_views[int(data[0])]
				v.lunge()
				Audio.play_at("swing", v.global_position + Vector3.UP, 2.0, 0.6)
		"lantern_hit":
			if _object_views.has(int(data[0])):
				var o: Node3D = _object_views[int(data[0])]
				o.set_state(int(data[1]))
				Audio.play_at("clang", o.global_position + Vector3.UP * 3.5, 0.0, 1.9 if int(data[1]) > 0 else 1.2)
		"world_event":
			if hud:
				hud.set_world_event(data)
		"blink":
			# Ocaso vanishes in green fire and appears by another brazier.
			for k in 2:
				var at := Vector3(data[k * 3], data[k * 3 + 1], data[k * 3 + 2])
				for n in 6:
					effects.smoke(at + Vector3(randf_range(-0.6, 0.6), randf_range(0.2, 1.8), randf_range(-0.6, 0.6)))
				Audio.play_at("splash", at, -4.0, 0.5)
		"ash_burst":
			var burst := Vector3(data[0], data[1], data[2])
			for n in 5:
				effects.smoke(burst + Vector3(randf_range(-0.4, 0.4), randf_range(0.3, 1.4), randf_range(-0.4, 0.4)))
		"slam":
			if _object_views.has(int(data[0])):
				_object_views[int(data[0])].slam()
			var where := Vector3(data[1], 0.0, data[2])
			effects.impact(0, where)
			Audio.play_at("cannon", where, 4.0, 0.4)
		"joint_hit":
			if _object_views.has(int(data[0])):
				_object_views[int(data[0])].joint_hit(int(data[1]))
		"colossus", "crumble":
			Audio.play("rattle", 6.0, 0.35, 0.0)
		"beacon":
			if _object_views.has(int(data[0])):
				Audio.play_at("fire", _object_views[int(data[0])].global_position, 0.0)
		"ghost":
			if view_ships.has(int(data[0])):
				var g: ShipState = view_ships[int(data[0])]
				Audio.play_at("rattle", Vector3(g.x, 0.0, g.z), 6.0, 0.4)
		"lantern_shot":
			if _skeleton_views.has(int(data[0])):
				var v: Node3D = _skeleton_views[int(data[0])]
				v.drop_lantern()
				effects.smoke(v.global_position + Vector3(-0.3, 1.0, -0.2))
				Audio.play_at("clang", v.global_position + Vector3.UP, -2.0, 1.6)
		"sniper_shot":
			var muzzle := Vector3(data[0], data[1], data[2])
			var aim := Vector3.UP
			if avatars.has(int(data[3])):
				aim = (avatars[int(data[3])].global_position + Vector3.UP - muzzle).normalized()
			effects.muzzle_smoke(muzzle, aim)
			Audio.play_at("pistol", muzzle, 6.0, 0.6)
		"shield":
			if _skeleton_views.has(int(data[0])):
				_skeleton_views[int(data[0])].shield_hit(int(data[1]) == 0)
				Audio.play_at("clang", _skeleton_views[int(data[0])].global_position + Vector3.UP, -2.0, 1.2)
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
		"board":
			offers = []
			for entry: Array in data:
				offers.append(Missions.offer_from_array(entry))
			if hud:
				hud.show_board()
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
	_update_objects()
	_update_skeletons(delta)
	_update_traders(delta)
	var cam := get_viewport().get_camera_3d()
	world.follow(cam.global_position if cam else Vector3.ZERO, render_time, view_ships)


## The world transform of a ship's frame (our own ship's if that one is gone).
func frame_transform(ship_id: int) -> Transform3D:
	var v: ShipView = ship_views.get(ship_id, ship_view)
	return v.global_transform if v else Transform3D.IDENTITY


## A castaway trader stands on the island of every crew's cargo run, waiting for the crates.
var _trader_views := {}  # crew -> Npc


func _update_traders(delta: float) -> void:
	for crew in _trader_views.keys():
		if not traders.has(crew) or traders[crew].island != _trader_views[crew].get_meta("island"):
			_trader_views[crew].queue_free()
			_trader_views.erase(crew)
	for crew in traders:
		if _trader_views.has(crew):
			continue
		var island: int = traders[crew].island
		var spec: Dictionary = Islands.LAYOUT[island]
		var at := Islands.trader_spot(island)
		var out := Vector3(at.x - spec.x, 0, at.z - spec.z).normalized()
		var npc := Npc.new("castaway", atan2(-out.x, -out.z))
		npc.set_meta("island", island)
		npc.position = at
		add_child(npc)
		_trader_views[crew] = npc
	var cam := get_viewport().get_camera_3d()
	for crew in _trader_views:
		_trader_views[crew].watch(cam.global_position if cam else Vector3.ZERO, delta)


func _update_skeletons(delta: float) -> void:
	for id in _skeleton_views.keys():
		if not view_skeletons.has(id):
			_skeleton_views[id].queue_free()
			_skeleton_views.erase(id)
	for id in view_skeletons:
		var sk: Skeleton = view_skeletons[id]
		if not _skeleton_views.has(id) and sk.crab:
			var crab := CrabView.new()
			add_child(crab)
			_skeleton_views[id] = crab
		if not _skeleton_views.has(id):
			var v := SkeletonView.new()
			v.look = id
			v.captain = sk.captain
			v.spanish = sk.spanish
			v.digger = sk.digger
			v.sergeant = sk.sergeant
			v.gideon = sk.gideon
			v.bomber = sk.bomber
			v.sniper = sk.sniper
			v.linnet = sk.linnet
			v.guard = sk.guard
			v.jailer = sk.jailer
			v.admiral = sk.admiral
			v.ashen = sk.ashen
			v.doctor = sk.doctor
			v.ash = sk.ash
			add_child(v)
			if sk.linnet and not sk.shield_up:
				v.drop_lantern()
			_skeleton_views[id] = v
		var at := Transform3D(Basis(Vector3.UP, sk.yaw), sk.pos)
		if sk.frame >= 0:
			if not ship_views.has(sk.frame):
				continue
			at = ship_views[sk.frame].global_transform * at
		_skeleton_views[id].place(at, sk.walking, not sk.alive(), delta)
		_skeleton_views[id].set_digging(sk.digging and sk.alive())


## The story's fires, journals and boats: made when they appear, gone when they go.
func _update_objects() -> void:
	var poisoned := false
	for id in _object_views.keys():
		if not view_objects.has(id):
			_object_views[id].queue_free()
			_object_views.erase(id)
	for id in view_objects:
		var o: StoryObject = view_objects[id]
		poisoned = poisoned or (o.kind == StoryObject.Kind.LAMP and o.state > 0)
		if not _object_views.has(id):
			var v := StoryObjectView.new(o.kind, o.state)
			add_child(v)
			_object_views[id] = v
		else:
			_object_views[id].set_state(o.state)
		# On a ship's deck (Isabel aboard), it rides with the ship.
		var at := Transform3D(Basis(Vector3.UP, o.yaw), o.pos)
		if o.ship >= 0 and ship_views.has(o.ship):
			at = frame_transform(o.ship) * at
		_object_views[id].place(at)
	if world:
		world.set_lamp_poisoned(poisoned)


## Place every chest and barrel: on the ground, afloat, stowed aboard or in someone's arms.
func _update_items() -> void:
	for id in _item_views.keys():
		if not view_items.has(id):
			_item_views[id].queue_free()
			_item_views.erase(id)
	for id in view_items:
		var item: Loot = view_items[id]
		if not _item_views.has(id):
			var v := LootView.new().setup(item.kind, item.value, item.variant)
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
			Loot.State.HELD:
				# In a Spanish skeleton's arms, running for its boat.
				if _skeleton_views.has(item.carrier):
					var held_at := Vector3(0, 0.32, -0.32) if _skeleton_views[item.carrier] is CrabView else Vector3(0, 1.0, -0.45)
					at = _skeleton_views[item.carrier].global_transform * Transform3D(Basis.IDENTITY, held_at)
		view.global_transform = at


## Bubbles while a ship goes down, and wreckage left floating where she went.
func _sinking_effects(id: int, s: ShipState, delta: float) -> void:
	if s.sink < 0.0:
		# A ghost galleon rising: the sea boils round her and pours off her decks.
		_wrecked[id] = _wrecked.get(id, 0.0) + delta
		if _wrecked[id] > 0.08:
			_wrecked[id] = 0.0
			var pose := ShipPhysics.pose_of(s, render_time)
			var along := randf_range(-ShipShape.HALF_LENGTH, ShipShape.HALF_LENGTH)
			var side := 1.0 if randf() < 0.5 else -1.0
			var at := pose * Vector3(side * 3.2, ShipShape.DECK_Y, along)
			effects.impact(0, Vector3(at.x, 0.1, at.z))
			effects.bubbles(Vector3(s.x + randf_range(-4, 4), 0.0, s.z + randf_range(-10, 10)))
		return
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


## A crew's mission from a snapshot: {kind, company, title, deadline, captain, handled, total,
## targets: [{island, x, z, done}]}, or {} with none.
static func _decode_mission(a: Array) -> Dictionary:
	if a.size() < 8:
		return {}
	var targets: Array[Dictionary] = []
	for i in int(a[7]):
		var k := 8 + i * 4
		targets.append({"island": int(a[k]), "x": float(a[k + 1]), "z": float(a[k + 2]), "done": int(a[k + 3]) == 1})
	var out := {
		"kind": int(a[0]), "company": int(a[1]), "title": str(a[2]), "deadline": float(a[3]),
		"captain": str(a[4]), "handled": int(a[5]), "total": int(a[6]), "targets": targets,
	}
	# A story chapter also says how many of the dead it raised still stand.
	var extra := 8 + int(a[7]) * 4
	if a.size() > extra:
		out.standing = int(a[extra])
	return out


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
	if s.crew > 0:
		return ServerSim.CREW_NAMES[s.crew - 1]
	return ["Skeleton ship", "Spanish galleon", "The Cuervo Negro", "A ghost galleon", "La Golondrina", "The prison hulk", "The Ash Admiral's flagship"][clampi(s.flag, 0, 6)]


## What's painted on an enemy (or ally) ship's transom, by its flag.
static func ship_name_for(flag: int) -> String:
	return ["The Rotten Grin", "San Cristobal", "Cuervo Negro", "Nuestra Senora", "La Golondrina", "Penitencia", "Cuervo Negro"][clampi(flag, 0, 6)]

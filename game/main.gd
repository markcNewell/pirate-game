extends Node
## Entry point. Reads the command line (everything after `--`) and either runs a dedicated
## server, a test bot, or the title menu.
##
##   --server                 dedicated server (also the default when run with --headless)
##   --port N                 port to serve or join (default 24565)
##   --join ADDRESS           join straight away, skipping the menu
##   --host                   host & play straight away
##   --name NAME              player name
##   --bot ROLE               headless test bot: wheel, sails, anchor or swimmer
##   --quit-after SECONDS     exit after this long, printing a summary
##   --screenshot PATH        save a screenshot and quit (with --shot-delay, --shot-view, and
##                            --shot-from X,Y,Z: where the island views look from,
##                            --shot-yaw Y: which way the first-person views face)
##   --demo                   host only: start under full sail with the anchor up
##   --crew N                 ask for crew N (1-4); 0 or absent for any
##   --time T                 pin the time of day for this client (0 midnight, 0.5 noon, 0.75 sunset)
##   --storm X,Z              pin the storm's centre there, for screenshots
##   --dolphins               dolphins visit straight away, for screenshots
##   --whale                  a whale surfaces ahead straight away, for screenshots
##   --model-sheet NAME       render a contact sheet of a Blender model (see tools/model_sheet.sh)
##   --no-save                server: keep pirate profiles in memory only (tests)
##   --profiles DIR           server: where pirate profiles are kept (default user://profiles)
##   --xp N                   server: every new pirate starts with N XP
##   --chapter ID             server: the first crew starts on story chapter ID (e.g. p1), at
##                            step --chapter-step N (default 0)

var _menu: Menu
var _backdrop: MenuBackdrop
var _args := {}


func _ready() -> void:
	PlayerInput.register_actions()
	Settings.load_saved()
	_args = _parse(OS.get_cmdline_user_args())
	Net.options = _args
	if _args.has("time"):
		Daylight.override = float(_args.time)
	Dolphins.eager = _args.has("dolphins")
	Whale.eager = _args.has("whale")
	if _args.has("storm"):
		var xz: PackedStringArray = str(_args.storm).split(",")
		Storm.pin = Vector2(float(xz[0]), float(xz[1]))
	# Start next frame: the scene root refuses new children while it is still being built.
	_start.call_deferred()


func _start() -> void:
	var port := int(_args.get("port", GameConfig.DEFAULT_PORT))

	var headless := DisplayServer.get_name() == "headless"
	if _args.has("server") or (headless and not _args.has("bot") and not _args.has("host")):
		var err := Net.serve(port)
		if err != OK:
			printerr("Could not serve on port %d: %s" % [port, error_string(err)])
			get_tree().quit(1)
			return
		print("[server] listening on port %d" % port)
		_maybe_quit_later()
		return

	if _args.has("bot"):
		var role: String = _args.bot
		Net.session_failed.connect(func(reason: String) -> void:
			printerr("[bot %s] %s" % [role, reason])
			get_tree().quit(2))
		# Two bots of one role in different crews need different names (names are unique).
		var bot_crew := int(_args.get("crew", 0))
		var bot_name := "Bot %s" % role + (" %d" % bot_crew if bot_crew > 0 else "")
		Net.join(_args.get("join", "127.0.0.1"), port, bot_name, role, bot_crew)
		_maybe_quit_later()
		return

	if _args.has("model-sheet"):
		add_child(ModelSheet.new(_args))
		return

	_menu = Menu.new()
	add_child(_menu)
	_show_backdrop()
	Net.session_started.connect(func(_g: Game) -> void:
		_menu.visible = false
		if _backdrop:
			_backdrop.queue_free()
			_backdrop = null)
	Net.session_failed.connect(func(reason: String) -> void:
		_menu.show_status(reason)
		_show_backdrop())
	Net.session_ended.connect(func(reason: String) -> void:
		_menu.show_status(reason)
		_show_backdrop())
	var player_name: String = _args.get("name", Settings.name)
	var crew := int(_args.get("crew", Settings.crew))
	if _args.has("host"):
		Net.host(port, player_name, crew)
		if _args.has("demo"):
			var ship := Net.game.sim.crew_ship()
			ship.anchored = false
			ship.sail_height = [1.0, 1.0]
			ship.speed = 6.0
	elif _args.has("join"):
		Net.join(_args.join, port, player_name, "", crew)
	if _args.has("screenshot"):
		_screenshot.call_deferred(_args.screenshot, float(_args.get("shot-delay", 6.0)), _args.get("shot-view", "deck"))
	_maybe_quit_later()


func _show_backdrop() -> void:
	if _backdrop == null:
		_backdrop = MenuBackdrop.new()
		add_child(_backdrop)


func _parse(raw: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < raw.size():
		var key := raw[i].trim_prefix("--")
		if i + 1 < raw.size() and not raw[i + 1].begins_with("--"):
			out[key] = raw[i + 1]
			i += 2
		else:
			out[key] = true
			i += 1
	return out


func _maybe_quit_later() -> void:
	if not _args.has("quit-after"):
		return
	await get_tree().create_timer(float(_args["quit-after"])).timeout
	_print_summary()
	get_tree().quit()


func _print_summary() -> void:
	var game := Net.game
	if game == null:
		print("RESULT no-session")
		return
	if game.is_server():
		var sim := game.sim
		var ship := sim.crew_ship()
		var line := "RESULT server moved=%.1f x=%.1f anchored=%s sails=%.2f/%.2f water=%.2f players=%d" % [
			Vector2(ship.x, ship.z).length(), ship.x, ship.anchored, ship.sail_height[0], ship.sail_height[1],
			ship.water, sim.players.size(),
		]
		for key in sim.stats:
			line += " %s=%s" % [key, sim.stats[key]]
		print(line)
	if game.local_player:
		var lp := game.local_player
		print("RESULT client id=%d active=%s mode=%d station=%d ship_seen=(%.1f, %.1f) snapshots_ok=%s" % [
			game.local_id, lp.active, lp.mode, lp.station, game.view_ship.x, game.view_ship.z,
			game.render_time > 0.0,
		])


## Capture the screen for checking the look without a monitor (see tools/screenshot.sh).
func _screenshot(path: String, delay: float, view: String) -> void:
	await get_tree().create_timer(delay * 0.5).timeout
	var game := Net.game
	if game and _args.has("shot-yaw"):
		# Turn the first-person view: 0 faces north, PI/2 west, -PI/2 east.
		game.local_player.yaw = float(_args["shot-yaw"])
	if game and view == "wheel":
		# Walk there instantly: the wheel is out of reach from the spawn point.
		game.sim._teleport(game.local_id, LocalPlayer.Mode.ON_SHIP, ShipShape.stations()[0].stand, 0.0)
		game.send_request("station", 0)
	elif game and view == "cannon":
		var st: Dictionary = ShipShape.stations()[5]
		game.sim._teleport(game.local_id, LocalPlayer.Mode.ON_SHIP, st.stand, -PI / 2.0)
		game.send_request("station", 5)
	elif game and view == "patch":
		# Below deck at the first hole (start with --test-holes 1), holding E on it.
		var h: Array = game.view_ship.holes[0]
		var side := signf(float(h[1]))
		var at := Vector3(float(h[1]) - side * 1.2, ShipShape.LOWER_Y, float(h[3]))
		game.sim._teleport(game.local_id, LocalPlayer.Mode.ON_SHIP, at, -side * PI / 2.0)
		game.local_player.pitch = -0.35
		# Start holding E a second before the picture, so it catches the patch half done.
		get_tree().create_timer(maxf(0.0, delay * 0.5 - 1.0)).timeout.connect(func() -> void: Input.action_press("interact"))
	elif game and view == "swing":
		# Start a cutlass swing just before the picture is taken.
		get_tree().create_timer(maxf(0.0, delay * 0.5 - 0.12)).timeout.connect(game.local_player.weapon_view.attack)
	elif game and view == "mouselook":
		# Feed real mouse movement through the whole input pipeline (GUI first, as from a
		# mouse) and report whether the view turned.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await get_tree().process_frame
		var before := game.local_player.yaw
		for i in 10:
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(40, 0)
			motion.position = get_viewport().get_visible_rect().size * 0.5
			Input.parse_input_event(motion)
			await get_tree().physics_frame
		await get_tree().physics_frame
		print("MOUSELOOK captured=%s yaw_before=%.3f yaw_after=%.3f turned=%s" % [
			Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, before, game.local_player.yaw,
			absf(game.local_player.yaw - before) > 0.1])
	elif game and view == "fp":
		# Freeze your own arm in one of its animations: --shot-anim NAME --shot-at SECONDS
		# (--shot-pistol to hold the pistol).
		var wv := game.local_player.weapon_view
		if _args.has("shot-pistol"):
			game.local_player.weapon = Weapons.Kind.PISTOL
		get_tree().create_timer(maxf(0.0, delay * 0.5 - 0.3)).timeout.connect(func() -> void:
			var player: AnimationPlayer = wv._player
			player.play(str(_args.get("shot-anim", "fp_idle")))
			player.seek(float(_args.get("shot-at", 0.0)), true)
			player.pause())
	elif game and view == "board":
		# At the map table with the mission board open.
		game.sim._teleport(game.local_id, LocalPlayer.Mode.ON_SHIP, ShipShape.MAP_TABLE + Vector3(0.9, 0, 0.6), 0.6)
		game.local_player.pitch = -0.4
		get_tree().create_timer(maxf(0.0, delay * 0.5 - 1.0)).timeout.connect(func() -> void: game.send_request("board", 0))
	elif game and view in ["bounty", "cargo", "trader"]:
		# A mission under way (on the island given by --voyage-island, default Parrot Rock), seen
		# where it happens: the captain and his crew, the crates on the pier, or the trader.
		var island := int(_args.get("voyage-island", 1))
		var company: int = {"bounty": Missions.Company.SOULS, "cargo": Missions.Company.MERCHANT, "trader": Missions.Company.MERCHANT}[view]
		var offer := Missions.make_offer(company, 2, Islands.mission_islands(), RandomNumberGenerator.new(), island)
		game.sim._start_mission(game.local_id if game.sim.crews.has(game.local_id) else ServerSim.CREW, offer)
		var spec: Dictionary = Islands.LAYOUT[island]
		var look_at := Vector3(spec.x, 0, spec.z)
		var stand := Vector3.ZERO
		match view:
			"bounty":
				var m: Dictionary = game.sim.crews[ServerSim.CREW].mission
				look_at = game.sim.skeletons[m.captain].pos
				# Hold their swings, or the shot is of you falling over.
				for s: Skeleton in game.sim.skeletons.values():
					s.cooldown = 1e6
				var away := (Vector3(spec.x, 0, spec.z) - look_at).normalized()
				stand = look_at + Vector3(away.z, 0, -away.x) * 7.0
			"cargo":
				look_at = Outpost.cargo_spot(1)
				stand = Outpost.agent_pos() + Vector3(-5.5, 0, 3.5)
			"trader":
				look_at = Islands.trader_spot(island)
				var out := (look_at - Vector3(spec.x, look_at.y, spec.z)).normalized()
				stand = look_at + out * 5.0 + Vector3(out.z, 0, -out.x) * 2.0
		var ground_island := Islands.island_at(stand.x, stand.z)
		stand.y = Islands.ground_at(ground_island, stand.x, stand.z) if ground_island >= 0 else stand.y
		if view == "cargo":
			stand.y = Outpost.PIER_Y
		var to := look_at - stand
		game.sim._teleport(game.local_id, LocalPlayer.Mode.WORLD, stand, atan2(-to.x, -to.z))
		game.local_player.pitch = -0.12
	elif game and view == "shop":
		# Big Martha's counter open, with gold to spend.
		var at := Outpost.martha_pos()
		var stand := at + Vector3(2.2, 0, 0.8)
		stand.y = Islands.ground_at(Islands.outpost_index(), stand.x, stand.z)
		var d := at - stand
		game.sim._teleport(game.local_id, LocalPlayer.Mode.WORLD, stand, atan2(-d.x, -d.z))
		game.sim.players[game.local_id].profile.gold = 1800
		game.sim.players[game.local_id].profile.owned.append("outfit4")
		game.sim._send_profile(game.local_id)
		get_tree().create_timer(maxf(0.0, delay * 0.5 - 1.0)).timeout.connect(func() -> void: game.send_request("talk", Story.PEOPLE_IDS.find("martha")))
	elif game and view in ["moll", "fire", "thieves"]:
		# The story: talking to Moll at her lighthouse (the panel open), the green fire on Gull
		# Isle with its journal (--chapter p1), or Bess's Spanish thieves by their boat (--chapter p2).
		var look_at := Vector3.ZERO
		var stand := Vector3.ZERO
		match view:
			"moll":
				look_at = Story.person_pos("moll")
				var spec := Outpost.spec()
				var out := (look_at - Vector3(spec.x, look_at.y, spec.z)).normalized()
				stand = look_at + out * 2.6 + Vector3(out.z, 0, -out.x) * 0.6
				get_tree().create_timer(maxf(0.0, delay * 0.5 - 1.0)).timeout.connect(func() -> void: game.send_request("talk", 0))
			"fire", "thieves":
				var kind := StoryObject.Kind.FIRE if view == "fire" else StoryObject.Kind.BOAT
				for o: StoryObject in game.sim.story.objects.values():
					if o.kind == kind:
						look_at = o.pos
				var isl := Islands.island_at(look_at.x, look_at.z)
				var spec: Dictionary = Islands.LAYOUT[maxi(isl, 0)]
				var inward := (Vector3(spec.x, look_at.y, spec.z) - look_at).normalized()
				stand = look_at + inward * (5.5 if view == "fire" else 9.0) + Vector3(inward.z, 0, -inward.x) * 2.0
				if view == "thieves":
					# Bess falls at once; her skull is theirs unless we stop them. Just before the
					# shot, stand beside the first thief to get to it.
					var m: Dictionary = game.sim.crews[ServerSim.CREW].mission
					game.sim._hurt_skeleton(m.captain, 999, "the sea")
					for s: Skeleton in game.sim.skeletons.values():
						s.cooldown = 1e6
					get_tree().create_timer(maxf(0.0, delay * 0.5 - 1.0)).timeout.connect(func() -> void:
						for s: Skeleton in game.sim.skeletons.values():
							s.cooldown = 1e6  # the island's own camp has woken by now too
						for s: Skeleton in game.sim.skeletons.values():
							if s.thief and s.alive():
								var side := Vector3(cos(s.yaw), 0, -sin(s.yaw))
								var at := s.pos + side * 3.5 - Vector3(-sin(s.yaw), 0, -cos(s.yaw)) * 1.5
								at.y = Islands.ground_at(maxi(0, Islands.island_at(at.x, at.z)), at.x, at.z)
								var d := s.pos - at
								game.sim._teleport(game.local_id, LocalPlayer.Mode.WORLD, at, atan2(-d.x, -d.z))
								return)
		var ground_island := Islands.island_at(stand.x, stand.z)
		stand.y = Islands.ground_at(ground_island, stand.x, stand.z) if ground_island >= 0 else stand.y
		var to := look_at - stand
		game.sim._teleport(game.local_id, LocalPlayer.Mode.WORLD, stand, atan2(-to.x, -to.z))
		game.local_player.pitch = -0.2
	elif game and view in ["graves", "store", "camp", "sergeant", "diggers", "bells", "fort", "polvorin", "wreck", "boat"]:
		# Act I, started with --chapter (a2 graves, a3 store, a6 camp; a6 --chapter-step 1 the
		# sergeant; a1 the diggers): stand back from the thing and look at it, everything holding
		# its swing.
		var look_at := Vector3.ZERO
		var back := 7.0
		var kinds := {
			"graves": StoryObject.Kind.GRAVE, "store": StoryObject.Kind.STORE, "camp": StoryObject.Kind.BONFIRE,
			"bells": StoryObject.Kind.BELL, "fort": StoryObject.Kind.GATE, "wreck": StoryObject.Kind.WRECK,
			"boat": StoryObject.Kind.BOAT,
		}
		if kinds.has(view):
			for o: StoryObject in game.sim.story.objects.values():
				if o.kind == kinds[view]:
					look_at = o.pos
			back = {"graves": 6.0, "store": 7.0, "camp": 13.0, "bells": 6.0, "fort": 30.0, "wreck": 14.0, "boat": 8.0}[view]
			if view == "bells":
				look_at.y -= 1.5
		for sk: Skeleton in game.sim.skeletons.values():
			sk.cooldown = 1e6
			sk.next_bomb = 1e9
			if (view == "sergeant" and sk.sergeant) or (view == "polvorin" and sk.bomber) or (view == "diggers" and sk.digger and look_at == Vector3.ZERO):
				look_at = sk.pos
				back = 4.5 if view != "polvorin" else 7.0
		if view == "diggers":
			# Wait until a digger is at its X, then stand by it.
			get_tree().create_timer(maxf(0.0, delay * 0.5 - 1.0)).timeout.connect(func() -> void:
				for sk: Skeleton in game.sim.skeletons.values():
					if sk.digger and sk.alive():
						var at := sk.pos + Vector3(3.0, 0, 2.0)
						at.y = Islands.ground_at(0, at.x, at.z)
						var d := sk.pos - at
						game.sim._teleport(game.local_id, LocalPlayer.Mode.WORLD, at, atan2(-d.x, -d.z))
						return)
		var isl := maxi(0, Islands.island_at(look_at.x, look_at.z))
		var spec: Dictionary = Islands.LAYOUT[isl]
		var inward := (Vector3(spec.x, look_at.y, spec.z) - look_at).normalized()
		if inward.length() < 0.5:
			inward = Vector3(1, 0, 0)
		var stand := look_at + inward.rotated(Vector3.UP, 0.6) * back
		if view == "sergeant":
			# From the camp's gate side (+x), clear of the tents.
			stand = look_at + Vector3(4.2, 0, -0.8)
		elif view == "fort":
			stand = look_at + Vector3(-back, 0, 6.0)
		elif view == "polvorin":
			stand = look_at + Vector3(-6.5, 0, 2.0)
		elif view in ["wreck", "boat"]:
			stand = look_at + Vector3(back, 0, back * 0.4)
		stand.y = Islands.ground_at(maxi(0, Islands.island_at(stand.x, stand.z)), stand.x, stand.z)
		if view in ["wreck", "boat"]:
			stand.y = -0.6
		var to := look_at - stand
		game.sim._teleport(game.local_id, LocalPlayer.Mode.WORLD, stand, atan2(-to.x, -to.z))
		game.local_player.pitch = {"fort": 0.12, "wreck": -0.05, "boat": -0.05}.get(view, -0.18)
	elif game and view in ["gallery", "cannons", "battery", "ocaso"]:
		# Act III: on the lighthouse gallery by the green lamp (c1); the cannons at the old camp
		# (c2); behind Merrow's battery with the galleons in the bay (c6); Doctor Ocaso on the
		# pier (c6, --chapter-step 3).
		for sk: Skeleton in game.sim.skeletons.values():
			sk.cooldown = 1e6
		var m: Dictionary = game.sim.crews[ServerSim.CREW].mission
		var stand := Vector3.ZERO
		var look_at := Vector3.ZERO
		match view:
			"gallery":
				stand = Outpost.gallery_spot()
				look_at = Outpost.lighthouse_lamp() - Vector3(0, 0.6, 0)
				var out := (stand - look_at) * Vector3(1, 0, 1)
				stand += out.normalized().cross(Vector3.UP) * 1.2
			"cannons":
				look_at = game.sim.items[m.items[0]].pos
				var isl: Dictionary = Islands.LAYOUT[maxi(0, Islands.island_at(look_at.x, look_at.z))]
				stand = look_at + (Vector3(isl.x, 0, isl.z) - look_at * Vector3(1, 0, 1)).normalized().rotated(Vector3.UP, 0.8) * 7.0
			"battery":
				var guns := Outpost.battery_centre()
				var out := Vector3(cos(Outpost.BATTERY_ANGLE), 0, sin(Outpost.BATTERY_ANGLE))
				stand = guns - out * 6.0 + out.cross(Vector3.UP) * 3.0
				look_at = guns + out * 40.0 + Vector3(0, 1.5, 0)
			"ocaso":
				for o: StoryObject in game.sim.story.objects.values():
					if o.kind == StoryObject.Kind.OCASO:
						look_at = o.pos + Vector3(0, 1.0, 0)
				stand = look_at + Vector3(-3.5, -1.0, 1.4)
		if view != "gallery":
			var ground_island := Islands.island_at(stand.x, stand.z)
			if ground_island >= 0:
				stand.y = Islands.ground_at(ground_island, stand.x, stand.z)
			if view == "ocaso":
				stand.y = Outpost.PIER_Y + 0.4
		var to := look_at - stand
		game.sim._teleport(game.local_id, LocalPlayer.Mode.WORLD, stand, atan2(-to.x, -to.z))
		game.local_player.pitch = {"gallery": -0.5, "cannons": -0.25, "battery": 0.0, "ocaso": -0.05}[view]
	elif game and view == "linnet":
		# The Other Lantern (--chapter t10, best with --time 0.9): Linnet on Gull Isle, a few
		# steps off, her lantern gathering to flare.
		var m: Dictionary = game.sim.crews[ServerSim.CREW].mission
		m.stage = 2  # she stays put for the picture
		m.next_shot = 1e9
		var linnet: Skeleton = game.sim.skeletons[m.captain]
		var isl: Dictionary = Islands.LAYOUT[2]
		var inward := (Vector3(isl.x, 0, isl.z) - linnet.pos * Vector3(1, 0, 1)).normalized()
		var stand := linnet.pos + inward.rotated(Vector3.UP, 0.5) * 5.5
		stand.y = Islands.ground_at(2, stand.x, stand.z)
		var to := linnet.pos - stand
		game.sim._teleport(game.local_id, LocalPlayer.Mode.WORLD, stand, atan2(-to.x, -to.z))
		game.local_player.pitch = -0.08
		get_tree().create_timer(maxf(0.0, delay - 0.8)).timeout.connect(func() -> void:
			if game._skeleton_views.has(linnet.id):
				game._skeleton_views[linnet.id].glint(1.2))
	elif game and view == "viuda":
		# The siege at --chapter c6 --chapter-step 2: La Viuda on the Cuervo Negro's quarterdeck,
		# seen from a boat's length off her quarter.
		for sk: Skeleton in game.sim.skeletons.values():
			sk.cooldown = 1e6
		var m: Dictionary = game.sim.crews[ServerSim.CREW].mission
		m.next_shot = 1e9
		var cam := Camera3D.new()
		cam.far = 3000.0
		cam.fov = 45.0
		game.add_child(cam)
		cam.make_current()
		var follow := func() -> void:
			if game.ship_views.has(m.ship):
				var ship: Transform3D = game.ship_views[m.ship].global_transform
				cam.look_at_from_position(ship * Vector3(7.0, ShipShape.QUARTER_Y + 3.0, 15.0), ship * Vector3(0, ShipShape.QUARTER_Y + 1.1, 8.5))
		get_tree().process_frame.connect(follow)
		get_tree().create_timer(maxf(0.0, delay - 1.2)).timeout.connect(func() -> void:
			for id in game._skeleton_views:
				if game.view_skeletons.has(id) and game.view_skeletons[id].sniper:
					game._skeleton_views[id].glint(2.0))
	elif game and view == "crab":
		# Coconut Thieves (--chapter t1): the crab with Captain Coco, seen from a few steps off.
		for sk: Skeleton in game.sim.skeletons.values():
			if sk.crab:
				# Out of its fright range, or it would be off up the beach before the picture.
				var at := sk.pos + Vector3(8.0, 0, 5.0)
				at.y = Islands.ground_at(2, at.x, at.z)
				var d := sk.pos - at
				game.sim._teleport(game.local_id, LocalPlayer.Mode.WORLD, at, atan2(-d.x, -d.z))
				game.local_player.pitch = -0.22
	elif game and view == "galleon":
		# From our deck, the Spanish galleon (--chapter a4) brought in close off the beam.
		var m: Dictionary = game.sim.crews[ServerSim.CREW].mission
		var g: ShipState = game.sim.ships[m.ship]
		var own := game.sim.crew_ship()
		g.x = own.x + 55.0
		g.z = own.z - 20.0
		g.yaw = own.yaw + 0.3
		game.sim._passive[m.ship] = true
		game.sim._teleport(game.local_id, LocalPlayer.Mode.ON_SHIP, Vector3(1.2, ShipShape.DECK_Y, -1.0), -PI / 2.0 + 0.3)
		game.local_player.pitch = 0.05
	elif game and view == "help":
		game.hud.toggle_help()
	elif game and view == "ghost":
		game.sim._hurt_player(game.local_id, 1000, "a falling yard")
	elif game and view == "map":
		game.sim._teleport(game.local_id, LocalPlayer.Mode.ON_SHIP, ShipShape.MAP_TABLE + Vector3(0.9, 0, 0.6), 0.6)
		game.send_request("voyage", 0)
		Input.action_press("map")
	elif game and view == "fight":
		# Ashore on Parrot Rock, where the camp wakes and comes for us.
		var spec: Dictionary = Islands.LAYOUT[1]
		var at := Vector3(spec.x - 12.0, 0, spec.z + 6.0)
		at.y = Islands.ground_at(1, at.x, at.z)
		game.sim._teleport(game.local_id, LocalPlayer.Mode.WORLD, at, -1.0)
	elif game and view == "swim":
		# In the sea off the port side, looking back at the ship.
		var ship := game.view_ship
		game.sim._teleport(game.local_id, LocalPlayer.Mode.WORLD, Vector3(ship.x - 14.0, 0.0, ship.z + 4.0), -PI / 2.0)
	elif game and view == "below":
		game.sim._teleport(game.local_id, LocalPlayer.Mode.ON_SHIP, Vector3(-0.8, ShipShape.LOWER_Y, 2.5), 0.25)
	elif game and view == "enemy":
		var cam := Camera3D.new()
		cam.far = 3000.0
		cam.fov = 50.0
		game.add_child(cam)
		cam.make_current()
		var watch := func() -> void:
			var enemy := game.nearest_enemy()
			var me := game.ship_view.global_transform.origin + Vector3(0, 9, 0)
			if enemy:
				# Close to the skeleton ship, on the side toward our own, looking at it.
				var at := Vector3(enemy.x, 5.0, enemy.z)
				var toward := (me - at).normalized()
				var side := toward.cross(Vector3.UP)
				cam.look_at_from_position(at + toward * 34.0 + side * 18.0 + Vector3(0, 6, 0), at)
		get_tree().process_frame.connect(watch)
	elif game and view != "deck":
		var cam := Camera3D.new()
		cam.far = 3000.0
		cam.fov = 60.0
		game.add_child(cam)
		cam.make_current()
		var offsets := {
			"outside": [Vector3(26, 10, 20), Vector3(0, 6, 0)],
			"bow": [Vector3(-8, 8, -40), Vector3(0, 5, 0)],
			"stern": [Vector3(3, 5.5, 24), Vector3(0, 3.6, 12)],
			"flag": [Vector3(7, ShipShape.DECK_Y + ShipShape.MAST_HEIGHT[1] - 3.0, ShipShape.MAST_Z[1] + 5.0),
				Vector3(1.2, ShipShape.DECK_Y + ShipShape.MAST_HEIGHT[1], ShipShape.MAST_Z[1])],
			"high": [Vector3(30, 45, 50), Vector3(0, 0, -20)],
			# From the front of the quarterdeck, looking forward over the waist where the crew work.
			"crew": [Vector3(-2.3, ShipShape.QUARTER_Y + 1.6, 4.8), Vector3(0.6, ShipShape.DECK_Y + 0.9, -3.0)],
		}
		if view.begins_with("island"):
			# "island" frames the first island; "island2" the third, and so on.
			var isl: Dictionary = Islands.LAYOUT[int(view.substr(6)) if view.length() > 6 else 0]
			var centre := Vector3(isl.x, 4.0, isl.z)
			var away: float = isl.radius / 60.0
			var from := Vector3(60, 22, 75)
			if _args.has("shot-from"):
				var xyz: PackedStringArray = str(_args["shot-from"]).split(",")
				from = Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))
			cam.look_at_from_position(centre + from * maxf(away, 0.55), centre)
		elif view == "tavern":
			cam.look_at_from_position(Outpost.tavern_point(Vector3(17, 6, -10)), Outpost.tavern_point(Vector3(0, 3.8, 0)))
		elif view == "lighthouse":
			var lamp := Outpost.lighthouse_lamp()
			var isl := Outpost.spec()
			var out := Vector3(lamp.x - isl.x, 0, lamp.z - isl.z).normalized()
			var side := out.cross(Vector3.UP)
			cam.look_at_from_position(lamp + out * 60.0 + side * 35.0 - Vector3(0, 8.0, 0), lamp - Vector3(0, 5.0, 0))
		elif view == "outpost":
			var at := Outpost.merchant_pos() + Vector3(0, 1.5, 0)
			var out := (Outpost.sell_spot() - Outpost.merchant_pos()).normalized()
			cam.look_at_from_position(at + out * 16.0 + Vector3(-8, 5, 6), at - out * 2.0)
		else:
			if view == "crew":
				# Out of the picture: our own first-person arm would float in mid air.
				game.sim._teleport(game.local_id, LocalPlayer.Mode.ON_SHIP, ShipShape.WHEEL + Vector3(2.0, 0, 2.5), 0.0)
			var spec: Array = offsets.get(view, offsets.outside)
			if view == "ship":
				# A camera placed by hand in the ship's frame: --shot-from X,Y,Z --shot-look X,Y,Z.
				var from: PackedStringArray = str(_args.get("shot-from", "6,6,6")).split(",")
				var to: PackedStringArray = str(_args.get("shot-look", "0,3,0")).split(",")
				spec = [Vector3(float(from[0]), float(from[1]), float(from[2])), Vector3(float(to[0]), float(to[1]), float(to[2]))]
				game.sim._teleport(game.local_id, LocalPlayer.Mode.ON_SHIP, ShipShape.MAP_TABLE + Vector3(0.9, 0, 0.6), 0.0)
			var follow := func() -> void:
				var ship := game.ship_view.global_transform
				cam.look_at_from_position(ship * spec[0], ship * spec[1])
			get_tree().process_frame.connect(follow)
	await get_tree().create_timer(delay * 0.5).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("screenshot saved to %s" % path)
	get_tree().quit()

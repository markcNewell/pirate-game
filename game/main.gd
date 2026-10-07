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
		Net.join(_args.get("join", "127.0.0.1"), port, "Bot %s" % role, role, int(_args.get("crew", 0)))
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
				var at := Vector3(enemy.x, 4.0, enemy.z)
				cam.look_at_from_position(me + (at - me).normalized() * 30.0 + Vector3(0, 3, 0), at)
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
			var spec: Array = offsets.get(view, offsets.outside)
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

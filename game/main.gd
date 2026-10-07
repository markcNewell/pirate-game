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
##   --screenshot PATH        save a screenshot and quit (with --shot-delay, --shot-view)
##   --demo                   host only: start under full sail with the anchor up
##   --crew N                 ask for crew N (1-4); 0 or absent for any
##   --time T                 pin the time of day for this client (0 midnight, 0.5 noon, 0.75 sunset)
##   --storm X,Z              pin the storm's centre there, for screenshots

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
	if game and view == "wheel":
		# Walk there instantly: the wheel is out of reach from the spawn point.
		game.sim._teleport(game.local_id, LocalPlayer.Mode.ON_SHIP, ShipShape.stations()[0].stand, 0.0)
		game.send_request("station", 0)
	elif game and view == "cannon":
		var st: Dictionary = ShipShape.stations()[5]
		game.sim._teleport(game.local_id, LocalPlayer.Mode.ON_SHIP, st.stand, -PI / 2.0)
		game.send_request("station", 5)
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
			"high": [Vector3(30, 45, 50), Vector3(0, 0, -20)],
		}
		if view == "island":
			var isl: Dictionary = Islands.LAYOUT[0]
			var centre := Vector3(isl.x, 4.0, isl.z)
			cam.look_at_from_position(centre + Vector3(60, 22, 75), centre)
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

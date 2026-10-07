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

var _menu: Menu
var _args := {}


func _ready() -> void:
	PlayerInput.register_actions()
	Settings.load_saved()
	_args = _parse(OS.get_cmdline_user_args())
	# Start next frame: the scene root refuses new children while it is still being built.
	_start.call_deferred()


func _start() -> void:
	var port := int(_args.get("port", GameConfig.DEFAULT_PORT))

	if _args.has("server") or (DisplayServer.get_name() == "headless" and not _args.has("bot")):
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
		Net.join(_args.get("join", "127.0.0.1"), port, "Bot %s" % role, role)
		_maybe_quit_later()
		return

	_menu = Menu.new()
	add_child(_menu)
	Net.session_started.connect(func(_g: Game) -> void: _menu.visible = false)
	Net.session_failed.connect(func(reason: String) -> void: _menu.show_status(reason))
	Net.session_ended.connect(func(reason: String) -> void: _menu.show_status(reason))
	var player_name: String = _args.get("name", Settings.name)
	if _args.has("host"):
		Net.host(port, player_name)
		if _args.has("demo"):
			Net.game.ship.anchored = false
			Net.game.ship.sail_height = [1.0, 1.0]
			Net.game.ship.speed = 6.0
	elif _args.has("join"):
		Net.join(_args.join, port, player_name)
	if _args.has("screenshot"):
		_screenshot.call_deferred(_args.screenshot, float(_args.get("shot-delay", 6.0)), _args.get("shot-view", "deck"))
	_maybe_quit_later()


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
		var moved := Vector2(game.ship.x, game.ship.z).length()
		print("RESULT server moved=%.1f max_speed=%.2f anchored=%s stations_taken=%d climbs=%d corrections=%d players=%d" % [
			moved, game.stats.max_speed, game.ship.anchored, game.stats.stations_taken,
			game.stats.climbs, game.stats.corrections, game.players.size(),
		])
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
		game.send_request("station", 0)
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

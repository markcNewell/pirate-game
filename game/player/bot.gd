class_name Bot
extends Node
## A scripted crew member for headless tests. It walks to its job, takes the station and works
## it, printing what happens so the smoke test can check. Roles:
##   wheel   - steer a little to starboard and hold it
##   sails   - let the main sails all the way out
##   anchor  - winch the anchor up
##   swimmer - jump overboard through the ladder gap, then climb back up the ladder

const ARRIVE := 0.5

var game: Game
var role := ""
var _player: LocalPlayer
var _route: Array[Vector3] = []
var _phase := "start"
var _timer := 0.0
var _working := false
var _status_timer := 0.0


func setup(g: Game, r: String) -> void:
	game = g
	role = r


func _ready() -> void:
	_player = game.local_player


func _physics_process(delta: float) -> void:
	var input := _player.input
	input.wish = Vector2.ZERO
	input.interact = false
	input.jump = false
	if not _player.active:
		return
	_timer += delta
	_status_timer += delta
	if _status_timer > 2.0:
		_status_timer = 0.0
		_say("phase=%s mode=%d at=%s vel=%s floor=%s swim=%s next=%s" % [
			_phase, _player.mode, _player.frame_position().snappedf(0.01), _player.body.velocity.snappedf(0.01),
			_player.body.is_on_floor(), _player.swimming, _route[0] if not _route.is_empty() else "-",
		])
	if _phase == "start":
		_route = _route_for(role)
		_say("spawned, heading for %s" % role)
		_phase = "walk"
	elif _phase == "walk":
		if _walk_route(input):
			_phase = "act"
			_timer = 0.0
	else:
		# Every later phase belongs to the role's own routine.
		_act(input)


## Walk along the route in the ship frame. True once at the end.
func _walk_route(input: PlayerInput) -> bool:
	if _route.is_empty():
		return true
	var here := _player.frame_position()
	var to := _route[0] - here
	to.y = 0.0
	if to.length() < ARRIVE:
		_route.pop_front()
		return _route.is_empty()
	# Face the waypoint and walk forward: forward is -Z, so heading = atan2(-x, -z).
	_player.yaw = atan2(-to.x, -to.z)
	_player.pitch = 0.0
	input.wish = Vector2(0, 1)
	return false


func _act(input: PlayerInput) -> void:
	match role:
		"wheel", "sails", "anchor":
			if _player.station < 0:
				# Look at the station post and press E every half second until granted.
				var st: Dictionary = ShipShape.stations()[_station_for(role)]
				var to: Vector3 = st.at - (_player.frame_position() + Vector3.UP * LocalPlayer.EYE_HEIGHT)
				_player.yaw = atan2(-to.x, -to.z)
				_player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
				if fmod(_timer, 0.5) < get_physics_process_delta_time():
					input.interact = true
				return
			if not _working:
				_say("took station %d" % _player.station)
				_working = true
				_timer = 0.0
			_work(input)
		"swimmer":
			_swim(input)


func _work(input: PlayerInput) -> void:
	match role:
		"wheel":
			input.wish = Vector2(1, 0) if _timer < 0.6 else Vector2.ZERO
		"sails":
			input.wish = Vector2(0, 1)
		"anchor":
			input.wish = Vector2(0, 1)


func _swim(input: PlayerInput) -> void:
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		if _phase == "climbed":
			return
		# Walk out through the gap in the rail on our side (yaw -90 degrees faces +x).
		_player.yaw = -PI / 2.0 if _player.frame_position().x >= 0.0 else PI / 2.0
		input.wish = Vector2(0, 1)
		return
	if _phase != "swimming" and _phase != "climbing":
		_say("overboard")
		_phase = "swimming"
		_timer = 0.0
	if _timer > 1.0 and _player.swimming and _phase == "swimming":
		_say("swimming")
		_phase = "climbing"
	# Swim to the nearer ladder and grab it once in reach.
	var p := _player.body.global_position
	var best := Vector3.ZERO
	var best_dist := INF
	for side: int in [-1, 1]:
		var bottom: Vector3 = game.ship_view.global_transform * ShipShape.ladder_bottom(side)
		var d := Vector2(bottom.x - p.x, bottom.z - p.z).length()
		if d < best_dist:
			best = bottom
			best_dist = d
	_player.yaw = atan2(-(best.x - p.x), -(best.z - p.z))
	input.wish = Vector2(0, 1) if best_dist > 1.5 else Vector2.ZERO
	if _phase == "climbing" and _player.nearest_ladder() != 0 and fmod(_timer, 0.5) < get_physics_process_delta_time():
		input.interact = true


func _process(_delta: float) -> void:
	if role == "swimmer" and _phase == "climbing" and _player.mode == LocalPlayer.Mode.ON_SHIP:
		_say("climbed back aboard")
		_phase = "climbed"


func _route_for(r: String) -> Array[Vector3]:
	# Keep to our own side of the deck so we never walk into the masts or the capstan.
	var here := _player.frame_position()
	var sx := 1.0 if here.x >= 0.0 else -1.0
	var d := ShipShape.DECK_Y
	var stations := ShipShape.stations()
	match r:
		"wheel":
			return [
				Vector3(sx * 2.5, d, here.z), Vector3(sx * 2.5, d, 2.35), Vector3(0, d, 2.35),
				# Round the wheel's post to stand behind it.
				Vector3(0, ShipShape.QUARTER_Y, 7.0), Vector3(1.3, ShipShape.QUARTER_Y, 8.0),
				Vector3(1.3, ShipShape.QUARTER_Y, 10.0), stations[0].stand,
			]
		"sails":
			return [Vector3(2.4, d, here.z), Vector3(2.4, d, 1.0), stations[2].stand]
		"anchor":
			return [Vector3(sx * 1.6, d, here.z), Vector3(sx * 1.6, d, -1.8), stations[3].stand]
		"swimmer":
			return [Vector3(sx * 2.0, d, here.z), Vector3(sx * 2.0, d, ShipShape.LADDER_Z)]
	return []


func _station_for(r: String) -> int:
	return {"wheel": 0, "sails": 2, "anchor": 3}[r]


func _say(text: String) -> void:
	print("[bot %s] %s" % [role, text])

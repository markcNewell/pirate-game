class_name Bot
extends Node
## A scripted crew member for headless tests. It finds its way about the decks (BotNav),
## does its job and prints what happens so the smoke tests can check. Roles:
##   wheel   - steer a little to starboard and hold it
##   sails   - let the main sails all the way out
##   anchor  - winch the anchor up
##   swimmer - jump overboard through the ladder gap, then climb back up the ladder
##   gunner  - man a cannon on the side facing the skeleton ship and shoot at it
##   repair  - go below, patch holes and bail water out with a bucket

const ARRIVE := 0.45
const STATIONS := {"wheel": 0, "sails": 2, "anchor": 3}

var game: Game
var role := ""
var _player: LocalPlayer
var _route: Array[Vector3] = []
var _phase := "start"
var _timer := 0.0
var _working := false
var _status_timer := 0.0
var _gun_station := -1
var _wrong_side := 0.0


func setup(g: Game, r: String) -> void:
	game = g
	role = r


func _ready() -> void:
	_player = game.local_player


func _physics_process(delta: float) -> void:
	var input := _player.input
	input.wish = Vector2.ZERO
	input.interact = false
	input.interact_held = false
	input.fire = false
	input.jump = false
	if not _player.active:
		return
	_timer += delta
	_status_timer += delta
	if _status_timer > 3.0:
		_status_timer = 0.0
		_say("phase=%s mode=%d station=%d at=%s next=%s" % [
			_phase, _player.mode, _player.station, _player.frame_position().snappedf(0.01),
			_route[0] if not _route.is_empty() else "-",
		])
	if _phase == "start":
		_say("spawned, heading for %s" % role)
		_phase = "act"
	match role:
		"wheel", "sails", "anchor":
			_crew_station(input, STATIONS[role])
		"swimmer":
			_swim(input)
		"gunner":
			_gunner(input)
		"repair":
			_repair(input)


func _process(_delta: float) -> void:
	if role == "swimmer" and _phase == "climbing" and _player.mode == LocalPlayer.Mode.ON_SHIP:
		_say("climbed back aboard")
		_phase = "climbed"


# --- moving about ---

## Head for `target` in the ship frame, planning a route around obstacles. True on arrival.
func _go(input: PlayerInput, target: Vector3) -> bool:
	if _route.is_empty() or _route.back().distance_to(target) > 0.05:
		_route = BotNav.find_path(_player.frame_position(), target)
		if _route.is_empty():
			_route = [target]
	var here := _player.frame_position()
	while not _route.is_empty():
		var to := _route[0] - here
		to.y = 0.0
		if to.length() >= ARRIVE:
			# Face the waypoint and walk forward: forward is -Z, so heading = atan2(-x, -z).
			_player.yaw = atan2(-to.x, -to.z)
			input.wish = Vector2(0, 1)
			return false
		_route.pop_front()
	return true


func _look_at(point: Vector3) -> void:
	var to: Vector3 = point - (_player.frame_position() + Vector3.UP * LocalPlayer.EYE_HEIGHT)
	_player.yaw = atan2(-to.x, -to.z)
	_player.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _every(seconds: float) -> bool:
	return fmod(_timer, seconds) < get_physics_process_delta_time()


## Walk to a station, press E at it until the server hands it over. True while working it.
func _man(input: PlayerInput, station: int) -> bool:
	if _player.station == station:
		if not _working:
			_say("took station %d" % station)
			_working = true
			_timer = 0.0
		return true
	_working = false
	var st: Dictionary = ShipShape.stations()[station]
	if not _go(input, st.stand):
		return false
	_look_at(st.at)
	if _every(0.5):
		input.interact = true
	return false


# --- roles ---

func _crew_station(input: PlayerInput, station: int) -> void:
	if not _man(input, station):
		return
	match role:
		"wheel":
			input.wish = Vector2(1, 0) if _timer < 0.6 else Vector2.ZERO
		"sails", "anchor":
			input.wish = Vector2(0, 1)


func _swim(input: PlayerInput) -> void:
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		if _phase == "climbed":
			return
		var sx := 1.0 if _player.frame_position().x >= 0.0 else -1.0
		if _phase == "out" or _go(input, Vector3(sx * 2.6, ShipShape.DECK_Y, ShipShape.LADDER_Z)):
			# Walk out through the gap in the rail (yaw -90 degrees faces +x).
			_phase = "out"
			_player.yaw = -PI / 2.0 * sx
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
	if _phase == "climbing" and _player.nearest_ladder() != 0 and _every(0.5):
		input.interact = true


## Pick a free cannon on the side facing the enemy, walk to it, aim with lead and fire.
func _gunner(input: PlayerInput) -> void:
	var enemy := game.nearest_enemy()
	var side := 1
	if enemy:
		var pose := game.ship_view.global_transform
		var local := pose.affine_inverse() * Vector3(enemy.x, 0.0, enemy.z)
		side = 1 if local.x >= 0.0 else -1
	if _gun_station < 0 or (_player.station == _gun_station and ShipShape.stations()[_gun_station].side != side):
		_wrong_side += get_physics_process_delta_time()
		if _gun_station < 0 or _wrong_side > 6.0:
			if _player.station >= 0:
				input.interact = true  # let go of the old gun
			_gun_station = _free_cannon(side)
			_wrong_side = 0.0
			return
	else:
		_wrong_side = 0.0
	if _gun_station < 0 or not _man(input, _gun_station):
		return
	if enemy == null:
		return
	var gun: int = ShipShape.stations()[_gun_station].gun
	var pose := ShipPhysics.pose_of(game.view_ship, game.render_time)
	var muzzle := pose * ShipShape.muzzle(gun, 0.0, 0.1)
	var sol := Gunnery.solve(muzzle, ShipPhysics.velocity_of(game.view_ship), Vector3(enemy.x, 0.8, enemy.z), ShipPhysics.velocity_of(enemy))
	if not sol.ok:
		return
	var angles := Gunnery.to_gun_angles(pose, gun, sol.dir)
	if not angles.ok:
		return
	# Turn our view so the cannon follows: invert LocalPlayer.cannon_aim.
	var st_side: int = ShipShape.stations()[_gun_station].side
	_player.yaw = -PI / 2.0 * st_side + angles.yaw * st_side
	_player.pitch = angles.pitch - LocalPlayer.SIGHT_PITCH
	if _player.cannon_reload() == 0.0 and _every(0.3):
		input.fire = true


func _free_cannon(side: int) -> int:
	var taken := {}
	for id in game.view_players:
		if id != game.local_id:
			taken[game.view_players[id].station] = true
	for st in ShipShape.stations():
		if st.kind == ShipShape.Kind.CANNON and st.side == side and not taken.has(st.id):
			return st.id
	return -1


## Below decks: patch the nearest hole; otherwise bail while there is water; otherwise wait.
func _repair(input: PlayerInput) -> void:
	if _player.mode != LocalPlayer.Mode.ON_SHIP:
		return
	var here := _player.frame_position()
	var below := ShipShape.is_below_deck(here)
	var ship := game.view_ship
	if _player.bucket:
		if below:
			# Up the ladder with the full bucket.
			if _go(input, ShipShape.HATCH_BOTTOM):
				_look_at(ShipShape.hatch_bottom_target())
				if _every(0.5):
					input.interact = true
		elif _every(0.4):
			input.interact = true  # throw it overboard
		return
	if not below:
		if _go(input, ShipShape.HATCH_TOP):
			_look_at(ShipShape.hatch_top_target())
			if _every(0.5):
				input.interact = true
		return
	if not ship.holes.is_empty():
		var h: Array = ship.holes[0]
		var at := Vector3(h[1], h[2], h[3])
		var stand := Vector3(signf(at.x) * (absf(at.x) - 0.75), ShipShape.LOWER_Y, at.z)
		if _go(input, stand):
			_look_at(at)
			input.interact_held = true
		return
	if ship.water > 0.12:
		if _every(0.5):
			input.interact = true  # fill the bucket where we stand
		return
	_go(input, ShipShape.HATCH_BOTTOM + Vector3(0, 0, 1.5))


func _say(text: String) -> void:
	print("[bot %s] %s" % [role, text])

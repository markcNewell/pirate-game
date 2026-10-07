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
##   treasure - take a voyage, swim ashore, dig up the chest and stow it aboard
##   seller  - carry the chest on deck to the outpost merchant, sell it, then restock
##   fighter - swim ashore and fight the island's skeletons with cutlass and pistol
##   boarder - swim to the skeleton ship alongside, climb its ladder and fight its crew

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
var _waypoints: Array[Vector3] = []
var _stuck_check := Vector3.ZERO
var _stuck_timer := 0.0
var _sidestep := 0.0


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
	input.weapon_key = -1
	if not _player.active:
		return
	_timer += delta
	_status_timer += delta
	if _status_timer > 3.0:
		_status_timer = 0.0
		_say("phase=%s mode=%d station=%d carry=%d at=%s next=%s" % [
			_phase, _player.mode, _player.station, _player.carry, _player.frame_position().snappedf(0.01),
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
		"treasure":
			_treasure(input)
		"seller":
			_seller(input)
		"fighter":
			_fighter(input)
		"boarder":
			_boarder(input)


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


## In the world, walk or swim straight for a point, side-stepping if something blocks us.
## True once within `near` metres (horizontally).
func _head_to(input: PlayerInput, target: Vector3, near := 1.0) -> bool:
	var p := _player.body.global_position
	var flat := Vector2(target.x - p.x, target.z - p.z)
	if flat.length() < near:
		return true
	_player.yaw = atan2(-flat.x, -flat.y)
	_player.pitch = 0.0
	input.wish = Vector2(0, 1)
	_stuck_timer += get_physics_process_delta_time()
	if _sidestep > 0.0:
		_sidestep -= get_physics_process_delta_time()
		input.wish = Vector2(1.0, 0.4)
	elif _stuck_timer > 1.0:
		if p.distance_to(_stuck_check) < 0.3:
			_sidestep = 1.2
		_stuck_check = p
		_stuck_timer = 0.0
	return false


## Walk out through a rail gap (the nearer one, or the side given). Call while on deck.
func _go_overboard(input: PlayerInput, side := 0) -> void:
	var sx := 1.0 if _player.frame_position().x >= 0.0 else -1.0
	if side != 0:
		sx = float(side)
	if _phase.ends_with("_out") or _go(input, Vector3(sx * 2.6, ShipShape.DECK_Y, ShipShape.LADDER_Z)):
		if not _phase.ends_with("_out"):
			_phase += "_out"
		_player.yaw = -PI / 2.0 * sx
		input.wish = Vector2(0, 1)


func _nearest_ladder_bottom() -> Vector3:
	var p := _player.body.global_position
	var best := Vector3.ZERO
	var best_d := INF
	for side: int in [-1, 1]:
		var b: Vector3 = game.ship_view.global_transform * ShipShape.ladder_bottom(side)
		var d := p.distance_to(b)
		if d < best_d:
			best = b
			best_d = d
	return best


func _treasure(input: PlayerInput) -> void:
	match _phase.trim_suffix("_out"):
		"act":
			# To the map table for a voyage.
			if not game.voyage.is_empty():
				_say("got a map to %s" % Islands.LAYOUT[game.voyage.island].name)
				_phase = "leave"
				return
			if _go(input, ShipShape.MAP_TABLE + Vector3(0.95, 0, 0.7)):
				_look_at(ShipShape.map_table_target())
				if _every(0.5):
					input.interact = true
		"leave":
			if _player.mode == LocalPlayer.Mode.WORLD:
				_say("overboard, heading for the X")
				_phase = "to_x"
				return
			_go_overboard(input)
		"to_x":
			var x := Vector3(game.voyage.x, 0, game.voyage.z)
			if _head_to(input, x, 1.0):
				_phase = "dig"
				_timer = 0.0
		"dig":
			input.interact_held = true
			for id in game.view_items:
				var item: Loot = game.view_items[id]
				if item.kind == Loot.Kind.CHEST and item.state == Loot.State.GROUND \
						and item.pos.distance_to(_player.body.global_position) < 4.0:
					_say("dug up the chest")
					_phase = "pick"
					_waypoints = [item.pos]
		"pick":
			if _player.carry >= 0:
				_say("carrying the chest")
				_phase = "return"
				return
			var at: Vector3 = _waypoints[0]
			if _head_to(input, at, 1.2):
				var to: Vector3 = at + Vector3.UP * 0.35 - (_player.body.global_position + Vector3.UP * LocalPlayer.EYE_HEIGHT)
				_player.yaw = atan2(-to.x, -to.z)
				_player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
				if _every(0.5):
					input.interact = true
		"return":
			if _player.mode == LocalPlayer.Mode.ON_SHIP:
				_say("back aboard with the chest")
				_phase = "stow"
				return
			if _head_to(input, _nearest_ladder_bottom(), 1.5) or _player.nearest_ladder() != 0:
				if _every(0.5):
					input.interact = true
		"stow":
			if _player.carry < 0:
				_say("stowed the chest")
				_phase = "done"
				return
			if _go(input, Vector3(-1.0, ShipShape.DECK_Y, 0.3)):
				if _every(0.5):
					input.interact = true


func _seller(input: PlayerInput) -> void:
	match _phase.trim_suffix("_out"):
		"act":
			if _player.carry >= 0:
				_say("picked up the chest")
				_phase = "leave"
				return
			for id in game.view_items:
				var item: Loot = game.view_items[id]
				if item.kind == Loot.Kind.CHEST and item.state == Loot.State.ON_SHIP:
					if _go(input, item.pos + Vector3(0.9, 0, 0.6)):
						_look_at(item.pos + Vector3.UP * 0.35)
						if _every(0.5):
							input.interact = true
					return
		"leave":
			if _player.mode == LocalPlayer.Mode.WORLD:
				_say("overboard with the chest, heading for the merchant")
				_phase = "to_merchant"
				return
			_go_overboard(input)
		"to_merchant":
			if _player.carry < 0:
				_say("sold the chest, gold %d" % game.purse)
				var c := Outpost._centre()
				var r: float = Outpost.spec().radius
				_waypoints = [
					c + Vector3(cos(0.45) * (r + 0.5), 0, sin(0.45) * (r + 0.5)),
					c + Vector3(cos(0.15) * (r - 1.0), 0, sin(0.15) * (r - 1.0)),
					c + Vector3(r - 5.0, 0, 0), Outpost.barrels()[0],
				]
				_phase = "restock"
				return
			if _head_to(input, Outpost.sell_spot(), 1.6):
				_player.yaw = atan2(-(Outpost.merchant_pos().x - _player.body.global_position.x), -(Outpost.merchant_pos().z - _player.body.global_position.z))
				if _every(0.5):
					input.interact = true
		"restock":
			if _waypoints.size() > 1:
				if _head_to(input, _waypoints[0], 1.0):
					_waypoints.pop_front()
				return
			if _head_to(input, _waypoints[0], 1.6) and _every(0.5):
				input.interact = true
			if game.view_ship.cannonballs == ShipState.MAX_CANNONBALLS:
				_say("restocked the ship")
				_phase = "done"


## The nearest standing skeleton in a frame (-1 = world), or null.
func _nearest_skeleton(frame: int, from: Vector3) -> Skeleton:
	var best: Skeleton = null
	var best_d := INF
	for id in game.view_skeletons:
		var sk: Skeleton = game.view_skeletons[id]
		if sk.frame != frame or not sk.alive():
			continue
		var d := sk.pos.distance_to(from)
		if d < best_d:
			best = sk
			best_d = d
	return best


## Face a skeleton's chest and attack: the pistol from range, the cutlass up close.
func _fight(input: PlayerInput, sk: Skeleton, eye: Vector3) -> void:
	var to := sk.pos + Vector3.UP * 1.0 - eye
	_player.yaw = atan2(-to.x, -to.z)
	_player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	var dist := Vector2(to.x, to.z).length()
	var want := Weapons.Kind.CUTLASS if dist < 4.0 else Weapons.Kind.PISTOL
	if _player.weapon != want:
		input.weapon_key = want
		return
	if dist < 2.0 or want == Weapons.Kind.PISTOL:
		input.fire = true
	if dist >= 1.6:
		input.wish = Vector2(0, 1)


func _fighter(input: PlayerInput) -> void:
	if _player.dead:
		return
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		_go_overboard(input)
		return
	var p := _player.body.global_position
	var sk := _nearest_skeleton(-1, p)
	if sk and sk.pos.distance_to(p) < 25.0:
		_fight(input, sk, p + Vector3.UP * LocalPlayer.EYE_HEIGHT)
		return
	# Head for the middle of the nearest island to wake its camp.
	var best := Vector3.ZERO
	var best_d := INF
	for spec in Islands.LAYOUT:
		if spec.outpost:
			continue
		var c := Vector3(spec.x, 0, spec.z)
		if c.distance_to(p) < best_d:
			best = c
			best_d = c.distance_to(p)
	_head_to(input, best, 3.0)


func _boarder(input: PlayerInput) -> void:
	if _player.dead:
		return
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		if _player.ship_id == ServerSim.CREW:
			# Over the side that faces the skeleton ship.
			var side := 1
			for id in game.view_ships:
				if id != ServerSim.CREW:
					var s: ShipState = game.view_ships[id]
					var local := game.frame_transform(ServerSim.CREW).affine_inverse() * Vector3(s.x, 0, s.z)
					side = 1 if local.x >= 0.0 else -1
			_go_overboard(input, side)
			return
		if _phase != "aboard":
			_say("boarded the skeleton ship")
			_phase = "aboard"
		var here := _player.frame_position()
		var sk := _nearest_skeleton(_player.ship_id, here)
		if sk == null:
			return
		if here.distance_to(sk.pos) > 2.2:
			_go(input, sk.pos)
		_fight(input, sk, here + Vector3.UP * LocalPlayer.EYE_HEIGHT)
		return
	# In the water: make for the skeleton ship's nearer ladder and climb.
	var p := _player.body.global_position
	for id in game.ship_views:
		if id == ServerSim.CREW:
			continue
		var best := Vector3.ZERO
		var best_d := INF
		for side: int in [-1, 1]:
			var b: Vector3 = game.ship_views[id].global_transform * ShipShape.ladder_bottom(side)
			if b.distance_to(p) < best_d:
				best = b
				best_d = b.distance_to(p)
		var at_theirs: bool = _player.nearest_ladder() != 0 and _player._ladder_ship == id
		if (_head_to(input, best, 1.5) or at_theirs) and _every(0.5):
			input.interact = true
		return


func _say(text: String) -> void:
	print("[bot %s] %s" % [role, text])

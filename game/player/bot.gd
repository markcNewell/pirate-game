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
##   seller  - carry the chest (or skull) on deck to its buyer at the outpost, sell it, restock
##   bounty  - take a bounty, swim ashore, beat the captain, carry his skull back aboard
##   cargo   - take a cargo run at the outpost, fetch a crate from the pier and stow it aboard
##   courier - carry the crate on deck ashore to the trader and hand it over
##   fighter - swim ashore and fight the island's skeletons with cutlass and pistol
##   boarder - swim to the skeleton ship alongside, climb its ladder and fight its crew
##   duelist - jump in and fight the nearest pirate of another crew
##   thief   - steal the chest from another crew's deck and stow it on our own ship
##   lights  - story chapter P1 on Gull Isle: read the journal, fill a bucket in the sea, douse
##             the green fire and fell the dead that climb out
##   moll    - swim ashore at Port Merrow and talk to Moll the keeper
##   salter  - Salt the Earth with a salt crate on deck: carry it ashore and salt a grave
##   kegs    - Captain Coco's Warning: go ashore to the powder store and shoot a keg (also the
##             fort's powder by its gate)
##   bells   - The Drowned Bells: go ashore and shoot the island's bell down
##   diver   - The Admiral's Story: swim to the San Telmo's wreck and dive on it
##   keeper  - Ashes on the Wind: fill a bucket, climb Moll's lighthouse, douse the green fire in
##             the lamp, climb down, fetch the jar of lamp oil and carry it up to the lamp
##   battery - The Siege of Port Merrow: go ashore and stand by Merrow's battery while it fires
##   viuda   - The siege, at La Viuda: from our deck, shoot her down off the flagship
##   sneak   - The Prison Hulk: swim to the hulk, climb aboard, fell the jailer, open the cage
##   lanterns - Lanterns of the Deep: go ashore on a sea stack and shoot its lantern to pieces
##   duel    - The battle's end: board the crippled Cuervo Negro and fight the Raven Admiral,
##             from behind where his parry can't reach

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
var _selling := Loot.Kind.CHEST


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
	# Once in the water, forget that we were walking out, so next time aboard we plan again.
	if _player.mode == LocalPlayer.Mode.WORLD and _phase.ends_with("_out"):
		_phase = _phase.trim_suffix("_out")
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
		"bounty":
			_bounty(input)
		"cargo":
			_cargo(input)
		"courier":
			_courier(input)
		"fighter":
			_fighter(input)
		"boarder":
			_boarder(input)
		"duelist":
			_duelist(input)
		"thief":
			_thief(input)
		"lights":
			_lights(input)
		"moll":
			_moll(input)
		"salter":
			_salter(input)
		"kegs":
			_kegs(input)
		"bells":
			_bells(input)
		"diver":
			_diver(input)
		"keeper":
			_keeper(input)
		"battery":
			_battery(input)
		"viuda":
			_viuda(input)
		"sneak":
			_sneak(input)
		"lanterns":
			_lanterns(input)
		"duel":
			_duel(input)


func _process(_delta: float) -> void:
	if role == "swimmer" and _phase == "climbing" and _player.mode == LocalPlayer.Mode.ON_SHIP:
		_say("climbed back aboard")
		_phase = "climbed"


# --- moving about ---

## Head for `target` in the ship frame, planning a route around obstacles. True on arrival.
func _go(input: PlayerInput, target: Vector3) -> bool:
	var off := target - _player.frame_position()
	off.y = 0.0
	if _route.is_empty() and off.length() < ARRIVE * 1.5:
		# Already there: stay put. Planning afresh from a spot beside an obstacle can start by
		# walking away, so the bot would pace back and forth instead of using the station.
		return true
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
	if _player.dead:
		return
	var now := _phase.trim_suffix("_out")
	if now in ["to_x", "dig", "pick"]:
		if _player.mode == LocalPlayer.Mode.ON_SHIP:
			# Felled and back aboard: over the side and back to the X.
			_go_overboard(input)
			return
		# The island's dead come for whoever digs on it: see them off first.
		var here := _player.body.global_position
		var sk := _nearest_skeleton(-1, here)
		if sk and sk.pos.distance_to(here) < 5.0:
			_fight(input, sk, here + Vector3.UP * LocalPlayer.EYE_HEIGHT)
			return
	match now:
		"act":
			# To the map table for a voyage.
			if not game.voyage.is_empty():
				_say("got a map to %s" % Islands.LAYOUT[game.voyage.island].name)
				_phase = "leave"
				return
			_take_mission(input, Missions.Company.GOLD)
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


## Walk to the map table and take the company's offer (bots skip the board's screen).
func _take_mission(input: PlayerInput, company: int) -> void:
	if _go(input, ShipShape.MAP_TABLE + Vector3(0.95, 0, 0.7)):
		_look_at(ShipShape.map_table_target())
		if _every(0.5):
			game.send_request("voyage", company)


## Pick up a carried item lying at `at` (world), walking up to it first. True once holding it.
func _fetch(input: PlayerInput, at: Vector3) -> bool:
	if _player.carry >= 0:
		return true
	if _head_to(input, at, 1.2):
		var to: Vector3 = at + Vector3.UP * 0.35 - (_player.body.global_position + Vector3.UP * LocalPlayer.EYE_HEIGHT)
		_player.yaw = atan2(-to.x, -to.z)
		_player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
		if _every(0.5):
			var item := _player.nearest_item()
			if item:
				game.send_request("pickup", item.id)
	return false


## Climb back aboard by the nearest ladder and put what we carry down on deck.
func _bring_aboard(input: PlayerInput, what: String) -> void:
	if _player.mode == LocalPlayer.Mode.WORLD:
		if _head_to(input, _nearest_ladder_bottom(), 1.5) or _player.nearest_ladder() != 0:
			if _every(0.5):
				input.interact = true
		return
	if _player.carry < 0:
		if _phase != "done":
			_say("stowed the %s" % what)
		_phase = "done"
		return
	if _go(input, Vector3(-1.0, ShipShape.DECK_Y, 0.3)) and _every(0.5):
		input.interact = true


func _bounty(input: PlayerInput) -> void:
	if _player.dead:
		return
	match _phase.trim_suffix("_out"):
		"act":
			if not game.mission.is_empty():
				_say("took the bounty on %s" % game.mission.captain)
				_phase = "hunt"
				return
			_take_mission(input, Missions.Company.SOULS)
		"hunt":
			if _player.mode == LocalPlayer.Mode.ON_SHIP:
				_go_overboard(input)
				return
			for id in game.view_items:
				var item: Loot = game.view_items[id]
				if item.kind == Loot.Kind.SKULL and item.state == Loot.State.GROUND:
					_say("the captain is down")
					_waypoints = [item.pos]
					_phase = "skull"
					return
			var p := _player.body.global_position
			var sk := _nearest_skeleton(-1, p)
			if sk and sk.pos.distance_to(p) < 25.0:
				_fight(input, sk, p + Vector3.UP * LocalPlayer.EYE_HEIGHT)
				return
			var t: Dictionary = game.mission.targets[0]
			_head_to(input, Vector3(t.x, 0, t.z), 4.0)
		"skull":
			if _fetch(input, _waypoints[0]):
				_say("carrying the skull")
				_phase = "return"
		"return", "done":
			_bring_aboard(input, "skull")


func _cargo(input: PlayerInput) -> void:
	match _phase.trim_suffix("_out"):
		"act":
			if not game.mission.is_empty():
				_say("took the cargo run: %s" % game.mission.title)
				_phase = "leave"
				return
			_take_mission(input, Missions.Company.MERCHANT)
		"leave":
			if _player.mode == LocalPlayer.Mode.WORLD:
				_phase = "fetch"
				return
			_go_overboard(input)
		"fetch":
			# Up the beach to the pier's root, then along the pier to the crates.
			if _waypoints.is_empty():
				var c := Outpost._centre()
				var r: float = Outpost.spec().radius
				_waypoints = [c + Vector3(cos(0.15) * (r - 1.0), 0, sin(0.15) * (r - 1.0)), c + Vector3(r - 5.0, 0, 0)]
			if _waypoints.size() > 0 and _head_to(input, _waypoints[0], 1.0):
				_waypoints.pop_front()
			if _waypoints.is_empty():
				_phase = "pick"
		"pick":
			if _fetch(input, Outpost.cargo_spot(0)):
				_say("carrying a crate")
				_phase = "return"
		"return", "done":
			_bring_aboard(input, "crate")


func _courier(input: PlayerInput) -> void:
	match _phase.trim_suffix("_out"):
		"act":
			if _player.carry >= 0:
				_say("picked up the crate")
				_phase = "leave"
				return
			for id in game.view_items:
				var item: Loot = game.view_items[id]
				if item.kind == Loot.Kind.CRATE and item.state == Loot.State.ON_SHIP:
					if _go(input, item.pos + Vector3(0.9, 0, 0.6)):
						_look_at(item.pos + Vector3.UP * 0.35)
						if _every(0.5):
							input.interact = true
					return
		"leave":
			if _player.mode == LocalPlayer.Mode.WORLD:
				_say("overboard with the crate, heading for the trader")
				_phase = "deliver"
				return
			_go_overboard(input)
		"deliver":
			if _player.carry < 0:
				_say("delivered the crate, gold %d" % game.purse)
				_phase = "done"
				return
			var t: Dictionary = game.mission.targets[0] if not game.mission.is_empty() else {}
			if t.is_empty():
				return
			var spot := Islands.trader_spot(t.island)
			if _head_to(input, spot, 1.6) and _every(0.5):
				game.send_request("deliver", 0)


func _seller(input: PlayerInput) -> void:
	match _phase.trim_suffix("_out"):
		"act":
			if _player.carry >= 0:
				_say("picked up the chest")
				_phase = "leave"
				return
			for id in game.view_items:
				var item: Loot = game.view_items[id]
				if item.kind in [Loot.Kind.CHEST, Loot.Kind.SKULL] and item.state == Loot.State.ON_SHIP:
					_selling = item.kind
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
				_say("sold the %s, gold %d" % ["skull" if _selling == Loot.Kind.SKULL else "chest", game.purse])
				var c := Outpost._centre()
				var r: float = Outpost.spec().radius
				_waypoints = [
					c + Vector3(cos(0.45) * (r + 0.5), 0, sin(0.45) * (r + 0.5)),
					c + Vector3(cos(0.15) * (r - 1.0), 0, sin(0.15) * (r - 1.0)),
					c + Vector3(r - 5.0, 0, 0), Outpost.barrels()[0],
				]
				_phase = "restock"
				return
			var spot := Outpost.mystic_spot() if _selling == Loot.Kind.SKULL else Outpost.sell_spot()
			var buyer := Outpost.mystic_pos() if _selling == Loot.Kind.SKULL else Outpost.merchant_pos()
			if _head_to(input, spot, 1.6):
				_player.yaw = atan2(-(buyer.x - _player.body.global_position.x), -(buyer.z - _player.body.global_position.z))
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
		if _player.ship_id == game.own_ship:
			# Over the side that faces the skeleton ship.
			var side := 1
			for id in game.view_ships:
				if id != game.own_ship:
					var s: ShipState = game.view_ships[id]
					var local := game.frame_transform(game.own_ship).affine_inverse() * Vector3(s.x, 0, s.z)
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
		if id == game.own_ship:
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


## The side (+1 starboard, -1 port) of our current ship that faces a world point.
func _side_facing(world: Vector3) -> int:
	var local := game.frame_transform(_player.ship_id).affine_inverse() * world
	return 1 if local.x >= 0.0 else -1


## The nearest living pirate of another crew, in the world: {id, pos} or {}.
func _nearest_rival() -> Dictionary:
	var me := _player.world_position()
	var best := {}
	var best_d := INF
	for id in game.view_players:
		var p: Dictionary = game.view_players[id]
		if id == game.local_id or p.crew == game.own_crew or p.dead:
			continue
		var w: Vector3 = p.pos
		if p.mode == LocalPlayer.Mode.ON_SHIP:
			w = game.frame_transform(p.ship) * p.pos
		if w.distance_to(me) < best_d:
			best = {"id": id, "pos": w}
			best_d = w.distance_to(me)
	return best


func _duelist(input: PlayerInput) -> void:
	if _player.dead:
		return
	var rival := _nearest_rival()
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		_go_overboard(input, _side_facing(rival.pos) if not rival.is_empty() else 1)
		return
	if rival.is_empty():
		return
	var foe := Skeleton.new()
	foe.pos = rival.pos
	_fight(input, foe, _player.body.global_position + Vector3.UP * LocalPlayer.EYE_HEIGHT)


func _thief(input: PlayerInput) -> void:
	if _player.dead:
		return
	match _player.mode:
		LocalPlayer.Mode.ON_SHIP:
			if _player.ship_id == game.own_ship:
				if _player.carry >= 0:
					if _phase != "done" and _go(input, Vector3(-1.0, ShipShape.DECK_Y, 0.3)) and _every(0.5):
						input.interact = true
					return
				if _phase == "stowing":
					_say("stowed the stolen chest")
					_phase = "done"
				if _phase == "done":
					return
				# Over the side facing the other crew's ship.
				for id in game.view_ships:
					if id != game.own_ship and game.view_ships[id].crew > 0:
						var s: ShipState = game.view_ships[id]
						_go_overboard(input, _side_facing(Vector3(s.x, 0, s.z)))
				return
			# Aboard the other crew's ship.
			if _player.carry >= 0:
				_say("got the chest, back to our ship")
				var o: ShipState = game.view_ship
				_go_overboard(input, _side_facing(Vector3(o.x, 0, o.z)))
				return
			for id in game.view_items:
				var item: Loot = game.view_items[id]
				if item.state == Loot.State.ON_SHIP and item.ship == _player.ship_id:
					if _go(input, item.pos + Vector3(0.9, 0, 0.6)):
						_look_at(item.pos + Vector3.UP * 0.35)
						if _every(0.5):
							input.interact = true
					return
		LocalPlayer.Mode.WORLD:
			# Swim to a ladder: theirs if empty-handed, ours if carrying.
			var target_ship := -1
			for id in game.view_ships:
				var s: ShipState = game.view_ships[id]
				if _player.carry >= 0 and id == game.own_ship:
					target_ship = id
				elif _player.carry < 0 and id != game.own_ship and s.crew > 0:
					target_ship = id
			if target_ship < 0 or not game.ship_views.has(target_ship):
				return
			if _player.carry >= 0:
				_phase = "stowing"
			var best := Vector3.ZERO
			var best_d := INF
			var p := _player.body.global_position
			for side: int in [-1, 1]:
				var b: Vector3 = game.ship_views[target_ship].global_transform * ShipShape.ladder_bottom(side)
				if b.distance_to(p) < best_d:
					best = b
					best_d = b.distance_to(p)
			var at_it: bool = _player.nearest_ladder() != 0 and _player._ladder_ship == target_ship
			if (_head_to(input, best, 1.5) or at_it) and _every(0.5):
				input.interact = true


func _say(text: String) -> void:
	print("[bot %s] %s" % [role, text])


## The first story thing of a kind lying about (StoryObject.Kind), or null.
func _story_object(kind: int, lit_only := false) -> StoryObject:
	for id in game.view_objects:
		var o: StoryObject = game.view_objects[id]
		if o.kind == kind and (not lit_only or o.state >= 1):
			return o
	return null


func _lights(input: PlayerInput) -> void:
	if _player.dead:
		return
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		_go_overboard(input)
		return
	var p := _player.body.global_position
	var book := _story_object(StoryObject.Kind.BOOK)
	if book:
		if _head_to(input, book.pos, 1.4) and _every(0.5):
			input.interact = true
		return
	if _phase == "act":
		_say("read the journal")
		_phase = "fire"
	var fire := _story_object(StoryObject.Kind.FIRE, true)
	if fire == null:
		fire = _story_object(StoryObject.Kind.BONFIRE, true)
	if fire:
		if not _player.bucket:
			# Already in the sea (overboard, or walked out): fill it here.
			if _player.swimming or Waves.height(p.x, p.z, game.render_time) > p.y + StoryRun.SCOOP_DEPTH:
				if _every(0.5):
					game.send_request("scoop", 0)
				return
			# Out from the fire toward the sea until our feet are wet.
			var isl := Islands.island_at(fire.pos.x, fire.pos.z)
			var spec: Dictionary = Islands.LAYOUT[maxi(isl, 0)]
			var out := Vector3(fire.pos.x - spec.x, 0, fire.pos.z - spec.z).normalized()
			if _player.current_target().get("kind", "") == "scoop":
				if _every(0.5):
					input.interact = true
				return
			_head_to(input, Vector3(spec.x, 0, spec.z) + out * (float(spec.radius) + 4.0), 0.5)
			return
		if _phase == "fire":
			_say("filled the bucket")
			_phase = "douse"
		if _head_to(input, fire.pos, 1.6) and _every(0.5):
			input.interact = true
		return
	if _phase == "douse":
		_say("doused the green fire")
		_phase = "dead"
	if game.mission.is_empty() or int(game.mission.handled) >= 2:
		if _phase != "done":
			_say("the green fire is out and its dead are down")
		_phase = "done"
		return
	var sk := _nearest_skeleton(-1, p)
	if sk and sk.pos.distance_to(p) < 30.0:
		_fight(input, sk, p + Vector3.UP * LocalPlayer.EYE_HEIGHT)
		return
	# Knocked down and sent back aboard: back to the grave (or bonfire), where the dead are.
	var grave := _story_object(StoryObject.Kind.FIRE)
	if grave == null:
		grave = _story_object(StoryObject.Kind.BONFIRE)
	if grave:
		_head_to(input, grave.pos, 3.0)


func _moll(input: PlayerInput) -> void:
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		_go_overboard(input)
		return
	if game.mission.is_empty():
		if _phase != "done":
			_say("chapter over: %d chapters done" % game.chapters.size())
		_phase = "done"
		return
	var at := Story.person_pos("moll")
	if _head_to(input, at, 1.8):
		var to := at - _player.body.global_position
		_player.yaw = atan2(-to.x, -to.z)
		if _every(0.5):
			input.interact = true


func _salter(input: PlayerInput) -> void:
	if _player.dead:
		return
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		if _player.carry < 0:
			for id in game.view_items:
				var item: Loot = game.view_items[id]
				if item.kind == Loot.Kind.CRATE and item.state == Loot.State.ON_SHIP:
					if _go(input, item.pos + Vector3(0.9, 0, 0.6)):
						_look_at(item.pos + Vector3.UP * 0.35)
						if _every(0.5):
							input.interact = true
					return
			return
		if _phase == "act":
			_say("picked up a salt crate")
			_phase = "ashore"
		_go_overboard(input)
		return
	var grave := _story_object(StoryObject.Kind.GRAVE, true)
	if grave == null or _player.carry < 0:
		if _phase != "done":
			_say("salted a grave")
		_phase = "done"
		return
	if _head_to(input, grave.pos, 1.6) and _every(0.5):
		input.interact = true


func _kegs(input: PlayerInput) -> void:
	if _player.dead:
		return
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		_go_overboard(input)
		return
	var keg := _story_object(StoryObject.Kind.KEG, true)
	if keg == null:
		if _phase != "done":
			_say("the powder store is gone")
		_phase = "done"
		return
	var p := _player.body.global_position
	if not _head_to(input, keg.pos, 7.0):
		return
	if _player.weapon != Weapons.Kind.PISTOL:
		input.weapon_key = Weapons.Kind.PISTOL
		return
	var to := keg.pos + Vector3.UP * 0.4 - (p + Vector3.UP * LocalPlayer.EYE_HEIGHT)
	_player.yaw = atan2(-to.x, -to.z)
	_player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	if _every(1.0):
		if _phase == "act":
			_say("shooting at a powder keg")
			_phase = "shoot"
		input.fire = true


func _bells(input: PlayerInput) -> void:
	if _player.dead:
		return
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		_go_overboard(input)
		return
	var p := _player.body.global_position
	var best: StoryObject = null
	for id in game.view_objects:
		var o: StoryObject = game.view_objects[id]
		if o.kind == StoryObject.Kind.BELL and o.state == 1 and (best == null or p.distance_to(o.pos) < p.distance_to(best.pos)):
			best = o
	if best == null:
		if _phase != "done":
			_say("no bells left ringing")
		_phase = "done"
		return
	if not _head_to(input, best.pos, 6.0):
		return
	if _player.weapon != Weapons.Kind.PISTOL:
		input.weapon_key = Weapons.Kind.PISTOL
		return
	var to := best.pos - (p + Vector3.UP * LocalPlayer.EYE_HEIGHT)
	_player.yaw = atan2(-to.x, -to.z)
	_player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	if _every(1.0):
		if _phase == "act":
			_say("shooting at a bell")
			_phase = "shoot"
		input.fire = true


func _diver(input: PlayerInput) -> void:
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		_go_overboard(input)
		return
	var wreck := _story_object(StoryObject.Kind.WRECK)
	if wreck == null:
		if _phase != "done":
			_say("found the logbook")
		_phase = "done"
		return
	if _head_to(input, wreck.pos, 2.0):
		input.interact_held = true


## Press E when it would do `kind` (see LocalPlayer.current_target).
func _press(input: PlayerInput, kind: String) -> void:
	if _player.current_target().get("kind", "") == kind and _every(0.5):
		input.interact = true


func _keeper(input: PlayerInput) -> void:
	if _player.dead:
		return
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		_go_overboard(input)
		return
	if game.mission.is_empty():
		if _phase != "done":
			_say("the lamp burns true")
		_phase = "done"
		return
	var p := _player.body.global_position
	var up_top := p.distance_to(Outpost.gallery_spot()) < 3.0
	var door := Outpost.lighthouse_door()
	var lamp := _story_object(StoryObject.Kind.LAMP, true)
	if lamp:
		if not _player.bucket:
			if up_top:
				_press(input, "climb_light")
				return
			if _player.swimming or Waves.height(p.x, p.z, game.render_time) > p.y + StoryRun.SCOOP_DEPTH:
				if _every(0.5):
					game.send_request("scoop", 0)
				return
			# Down the beach below the lighthouse until our feet are wet.
			var spec := Outpost.spec()
			var out := Vector3(door.x - spec.x, 0, door.z - spec.z).normalized()
			_head_to(input, Vector3(spec.x, 0, spec.z) + out * (float(spec.radius) + 4.0), 0.5)
			return
		if _phase == "act":
			_say("filled the bucket")
			_phase = "climb"
		if up_top:
			if _phase == "climb":
				_say("up on the gallery")
				_phase = "douse"
			_press(input, "douse")
			return
		if _head_to(input, door, 1.2):
			_press(input, "climb_light")
		return
	if _phase in ["act", "climb", "douse"]:
		_say("doused the green fire in the lamp")
		_phase = "oil"
	if _player.carry < 0:
		if up_top:
			_press(input, "climb_light")
			return
		for id in game.view_items:
			var it: Loot = game.view_items[id]
			if it.kind == Loot.Kind.OIL and it.state == Loot.State.GROUND:
				if _head_to(input, it.pos, 0.8):
					_press(input, "pickup")
				return
		return
	if _phase == "oil":
		_say("carrying the lamp oil")
		_phase = "carry"
	if up_top:
		_press(input, "give")
		return
	if _head_to(input, door, 1.2):
		_press(input, "climb_light")


func _battery(input: PlayerInput) -> void:
	if _player.dead:
		return
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		_go_overboard(input)
		return
	var out := Vector3(cos(Outpost.BATTERY_ANGLE), 0, sin(Outpost.BATTERY_ANGLE))
	if _head_to(input, Outpost.battery_centre() - out * 3.0, 1.5) and _phase == "act":
		_say("manning the battery")
		_phase = "manned"


func _viuda(input: PlayerInput) -> void:
	if _player.dead or _player.mode != LocalPlayer.Mode.ON_SHIP:
		return
	var viuda: Skeleton = null
	for id in game.view_skeletons:
		var sk: Skeleton = game.view_skeletons[id]
		if sk.sniper and sk.alive():
			viuda = sk
	if viuda == null or not game.view_ships.has(viuda.frame) or not game.view_ships.has(game.own_ship):
		if _phase == "shoot":
			_say("La Viuda is down")
			_phase = "done"
		return
	if _player.weapon != Weapons.Kind.PISTOL:
		input.weapon_key = Weapons.Kind.PISTOL
		return
	# Her chest, in our own deck's frame.
	var her := ShipPhysics.pose_of(game.view_ships[viuda.frame], game.render_time) * (viuda.pos + Vector3.UP * 1.2)
	var ours := ShipPhysics.pose_of(game.view_ships[game.own_ship], game.render_time)
	_look_at(ours.affine_inverse() * her)
	if _every(1.0):
		if _phase == "act":
			_say("shooting at La Viuda")
			_phase = "shoot"
		input.fire = true


## The id of the first ship flying `flag` (ShipState.flag), or -1.
func _ship_flying(flag: int) -> int:
	for id in game.view_ships:
		if id != game.own_ship and game.view_ships[id].flag == flag and game.view_ships[id].kind == ShipState.Kind.SKELETON:
			return id
	return -1


## Off our deck toward ship `target`, through the water to her nearer ladder, and up it.
func _board(input: PlayerInput, target: int) -> void:
	if _player.mode == LocalPlayer.Mode.ON_SHIP and _player.ship_id == game.own_ship:
		var s: ShipState = game.view_ships[target]
		_go_overboard(input, _side_facing(Vector3(s.x, 0, s.z)))
		return
	if not game.ship_views.has(target):
		return
	var p := _player.body.global_position
	var best := Vector3.ZERO
	var best_d := INF
	# The hulk: always her stern rope, out of her guards' sight.
	var sides := [ShipShape.STERN_ROPE] if game.view_ships[target].flag == 5 else [-1, 1]
	for side: int in sides:
		var b: Vector3 = game.ship_views[target].global_transform * ShipShape.ladder_bottom(side)
		if b.distance_to(p) < best_d:
			best = b
			best_d = b.distance_to(p)
	var at_theirs: bool = _player.nearest_ladder() != 0 and _player._ladder_ship == target
	if (_head_to(input, best, 1.5) or at_theirs) and _every(0.5):
		input.interact = true


func _sneak(input: PlayerInput) -> void:
	if _player.dead:
		return
	if game.mission.is_empty():
		if _phase != "done":
			_say("Isabel is home")
		_phase = "done"
		return
	var hulk := _ship_flying(5)
	if hulk < 0:
		return
	if _player.mode != LocalPlayer.Mode.ON_SHIP or _player.ship_id != hulk:
		if _player.mode == LocalPlayer.Mode.ON_SHIP and _player.ship_id == game.own_ship and _phase in ["free", "home"]:
			return  # Isabel aboard: home we go (the test only needs her out)
		_board(input, hulk)
		return
	if _phase == "act":
		_say("aboard the hulk")
		_phase = "aboard"
	var here := _player.frame_position()
	var jailer: Skeleton = null
	for id in game.view_skeletons:
		var sk: Skeleton = game.view_skeletons[id]
		if sk.jailer and sk.alive() and sk.frame == hulk:
			jailer = sk
	if jailer:
		if here.distance_to(jailer.pos) > 2.0:
			_go(input, jailer.pos)
		_fight(input, jailer, here + Vector3.UP * LocalPlayer.EYE_HEIGHT)
		return
	if _phase == "aboard":
		_say("the jailer is down")
		_phase = "cage"
	for id in game.view_objects:
		var o: StoryObject = game.view_objects[id]
		if o.kind == StoryObject.Kind.CAGE and o.ship == hulk:
			if o.state == 0:
				if _phase == "cage":
					_say("Isabel is out of her cage")
					_phase = "free"
				return
			if _go(input, o.pos + Vector3(-1.4, 0, 0)):
				_look_at(o.pos + Vector3(0, 1.0, 0))
				_press(input, "use")


func _lanterns(input: PlayerInput) -> void:
	if _player.dead:
		return
	var p := _player.body.global_position
	var best: StoryObject = null
	for id in game.view_objects:
		var o: StoryObject = game.view_objects[id]
		if o.kind == StoryObject.Kind.GLANTERN and o.state > 0 and (best == null or p.distance_to(o.pos) < p.distance_to(best.pos)):
			best = o
	if best == null:
		if _phase != "done":
			_say("no lanterns left burning")
		_phase = "done"
		return
	if _player.mode == LocalPlayer.Mode.ON_SHIP:
		_go_overboard(input, _side_facing(best.pos))
		return
	if not _head_to(input, best.pos, 5.0):
		return
	if _player.weapon != Weapons.Kind.PISTOL:
		input.weapon_key = Weapons.Kind.PISTOL
		return
	var to := best.pos + Vector3(0, 3.7, 0) - (p + Vector3.UP * LocalPlayer.EYE_HEIGHT)
	_player.yaw = atan2(-to.x, -to.z)
	_player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	if _every(1.0):
		if _phase == "act":
			_say("shooting at a lantern of the deep")
			_phase = "shoot"
		input.fire = true


func _duel(input: PlayerInput) -> void:
	if _player.dead:
		return
	var flagship := _ship_flying(2)
	if flagship < 0:
		if _phase != "done":
			_say("the Cuervo Negro is gone")
		_phase = "done"
		return
	if _player.mode != LocalPlayer.Mode.ON_SHIP or _player.ship_id != flagship:
		_board(input, flagship)
		return
	if _phase == "act":
		_say("aboard the Cuervo Negro")
		_phase = "aboard"
	var here := _player.frame_position()
	var admiral: Skeleton = null
	for id in game.view_skeletons:
		var sk: Skeleton = game.view_skeletons[id]
		if sk.admiral and sk.alive() and sk.frame == flagship:
			admiral = sk
	if admiral == null:
		if _phase != "won":
			_say("the Raven Admiral has fallen")
		_phase = "won"
		return
	# Round to his back, where his parry can't reach, then cut.
	var facing := Vector3(-sin(admiral.yaw), 0, -cos(admiral.yaw))
	var behind := admiral.pos - facing * 1.5
	if here.distance_to(behind) > 0.8 and here.distance_to(admiral.pos) > 1.2:
		_go(input, behind)
	_fight(input, admiral, here + Vector3.UP * LocalPlayer.EYE_HEIGHT)

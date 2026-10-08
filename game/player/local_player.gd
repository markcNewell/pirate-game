class_name LocalPlayer
extends Node3D
## The player at this keyboard (or a test bot).
##
## On board, the body walks on the still deck proxy and the camera is that position carried
## onto the moving ship, so the deck never slides away underfoot. Overboard, the body lives in
## the world: it swims on the waves or walks on islands. Walking is decided here and reported
## to the server, which checks it and can snap the player back (see ServerSim.player_state).

enum Mode { ON_SHIP, WORLD }

const EYE_HEIGHT := 1.6
## Swimmers see from this much higher than their eyes really are, so passing crests do not
## fill the view. Only the camera moves; the body and every reach check stay where they are.
const SWIM_VIEW_LIFT := 0.5
const STATION_REACH := 2.4
const LADDER_REACH := 3.5
const HOLE_REACH := 2.4
const HATCH_REACH := 2.4
const PATCH_SEND_EVERY := 0.2
const ITEM_REACH := 2.6
const CARRY_SPEED := 0.7
## The cannon sights sit a little above the barrel, so aim a touch higher than the eye looks.
const SIGHT_PITCH := 0.04

const STATION_HELP := {
	ShipShape.Kind.WHEEL: "A / D  turn the wheel      E  let go",
	ShipShape.Kind.SAILS: "W / S  let out / take in sail      A / D  swing the sails      E  let go",
	ShipShape.Kind.ANCHOR: "W (hold)  winch the anchor up      S  drop the anchor      E  let go",
	ShipShape.Kind.CANNON: "Mouse  aim      Left click  fire      E  let go",
}

var game: Game
var input := PlayerInput.new()
var mode := Mode.ON_SHIP
## Waits for the server to place us (the first teleport) before moving.
var active := false
## Heading and look angle, in the ship frame on board and the world frame overboard.
var yaw := 0.0
var pitch := 0.0
## Station the server says we are working, or -1.
var station := -1
## True while the mission board is open: the number keys pick offers, not weapons.
var board_open := false
## True while carrying a bucket of water (the server says).
var bucket := false
## The item in our arms (a chest), or -1.
var carry := -1
## Which ship's frame we stand in while ON_SHIP (our own is game.own_ship).
var ship_id := 1
var hp := 100
var dead := false
var weapon := Weapons.Kind.CUTLASS
var weapon_view: WeaponView
var _attack_ready := 0.0
var teleport_seq := 0
var swimming := false
var sensitivity := 0.0025

var body: CharacterBody3D
var head: Node3D
var camera: Camera3D

var _prev := Vector3.ZERO
var _curr := Vector3.ZERO
var _send_timer := 0.0
var _patch_timer := 0.0
## How long E has been held on a dig spot; the HUD's ring shows it (the server keeps the truth).
var _dig_clock := 0.0
## Distance walked since the last footstep, and time since the last spade or stroke sound.
var _stride := 0.0
var _sound_wait := 0.0
var _stations := ShipShape.stations()


func _ready() -> void:
	body = CharacterBody3D.new()
	body.top_level = true
	body.floor_max_angle = deg_to_rad(46.0)
	body.floor_snap_length = 0.4
	body.collision_layer = 0
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	add_child(body)
	_set_mode(Mode.ON_SHIP)

	head = Node3D.new()
	head.top_level = true
	add_child(head)
	camera = Camera3D.new()
	camera.position.y = EYE_HEIGHT
	camera.fov = 75.0
	camera.near = 0.05
	camera.far = 3000.0
	head.add_child(camera)
	camera.make_current()
	weapon_view = WeaponView.new()
	camera.add_child(weapon_view)


## Mouse look is read here, before any on-screen element sees the event, so nothing drawn on
## the HUD can ever swallow it.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input.add_mouse(event.relative, sensitivity)


func _physics_process(delta: float) -> void:
	if not active or game == null:
		return
	input.poll()
	if board_open:
		# The board takes the keys: no weapon swaps or using things behind it.
		input.weapon_key = -1
		input.interact = false
		input.interact_held = false
		input.fire = false
	_prev = _curr
	if dead:
		# A ghost: no moving or acting until the server brings us back.
		body.velocity = Vector3.ZERO
		_curr = frame_position()
		return
	yaw = wrapf(yaw - input.look.x, -PI, PI)
	pitch = clampf(pitch - input.look.y, -1.45, 1.45)
	_attack_ready -= delta
	if input.weapon_key >= 0 and input.weapon_key != weapon:
		weapon = input.weapon_key
		game.send_request("weapon", weapon)

	if station >= 0:
		body.global_position = DeckProxy.to_proxy(_stations[station].stand)
		body.velocity = Vector3.ZERO
		if input.interact:
			game.send_request("leave", station)
		elif input.fire and _stations[station].kind == ShipShape.Kind.CANNON:
			var aim := cannon_aim()
			game.send_request("fire", station, [aim.x, aim.y])
	else:
		if mode == Mode.ON_SHIP:
			_move_on_ship(delta)
		else:
			_move_in_world(delta)
		_interact(delta)
		if input.fire and carry < 0 and _attack_ready <= 0.0:
			_attack_ready = Weapons.CUTLASS_COOLDOWN if weapon == Weapons.Kind.CUTLASS else Weapons.PISTOL_RELOAD
			weapon_view.attack()
			Audio.play("swing" if weapon == Weapons.Kind.CUTLASS else "pistol", -3.0 if weapon == Weapons.Kind.CUTLASS else 0.0)
			game.send_request("attack", weapon, [yaw, pitch])

	_curr = frame_position()
	var lift := SWIM_VIEW_LIFT if swimming and mode == Mode.WORLD else 0.0
	camera.position.y = move_toward(camera.position.y, EYE_HEIGHT + lift, delta * 1.5)
	_send_timer += delta
	if _send_timer >= 1.0 / GameConfig.PLAYER_SEND_RATE:
		_send_timer = 0.0
		game.send_player_state(state_array())
		if station >= 0:
			game.send_station_input(input.wish, cannon_aim())


func _move_on_ship(delta: float) -> void:
	swimming = false
	var local := DeckProxy.from_proxy(body.global_position)
	# Wading through a flooded lower deck is slow going.
	var depth := frame_ship().water - (local.y - ShipShape.LOWER_Y)
	var scale := 0.55 if ShipShape.is_below_deck(local) and depth > 0.6 else 1.0
	if carry >= 0:
		scale *= CARRY_SPEED
	var jump := input.jump and carry < 0
	body.velocity = PlayerMotor.walk(body.velocity, input.wish, yaw, input.run, body.is_on_floor(), jump, delta, scale)
	body.move_and_slide()
	_footsteps(delta, "step_wood")
	local = DeckProxy.from_proxy(body.global_position)
	if not ShipShape.is_on_board(local):
		_go_overboard(local)


func _move_in_world(delta: float) -> void:
	var p := body.global_position
	var surface := Waves.height(p.x, p.z, game.render_time)
	swimming = PlayerMotor.is_swimming(p.y, surface)
	var scale := CARRY_SPEED if carry >= 0 else 1.0
	if swimming:
		body.velocity = PlayerMotor.swim(body.velocity, input.wish, yaw, p.y, surface, delta, scale * 0.85)
	else:
		var jump := input.jump and carry < 0
		body.velocity = PlayerMotor.walk(body.velocity, input.wish, yaw, input.run, body.is_on_floor(), jump, delta, scale)
	body.move_and_slide()
	_footsteps(delta, "splash" if swimming else "step_sand")


## A footstep sound every stride while walking on something (a stroke while swimming).
func _footsteps(delta: float, sound: String) -> void:
	var flat := Vector2(body.velocity.x, body.velocity.z).length()
	if not swimming and not body.is_on_floor():
		return
	_stride += flat * delta
	var stride := 2.2 if swimming else 1.5
	if _stride < stride:
		return
	_stride = 0.0
	if swimming:
		Audio.play(sound, -22.0, 1.6, 0.15)
	else:
		Audio.play(sound, -12.0 if sound == "step_wood" else -14.0, 1.0, 0.12)


## Leave the ship frame: carry position, heading and momentum (including the ship's) into the world.
func _go_overboard(local: Vector3) -> void:
	var ship_tf := game.frame_transform(ship_id)
	var ship := frame_ship()
	var vel := ship_tf.basis * body.velocity
	var drift := ShipPhysics.forward(ship.yaw) * ship.speed
	yaw = wrapf(yaw + ship.yaw, -PI, PI)
	_set_mode(Mode.WORLD)
	body.global_position = ship_tf * local
	body.velocity = vel + Vector3(drift.x, 0.0, drift.y)
	_prev = body.global_position


func _interact(delta: float) -> void:
	var target := current_target()
	var digging: bool = not target.is_empty() and target.kind == "dig" and input.interact_held
	_dig_clock = _dig_clock + delta if digging else 0.0
	_sound_wait -= delta
	if digging and _sound_wait <= 0.0:
		_sound_wait = 0.5
		Audio.play("dig", -4.0)
	if target.is_empty():
		return
	if target.kind in ["patch", "dig", "dive"]:
		# Held actions: keep telling the server while E is down.
		_patch_timer -= delta
		if input.interact_held and _patch_timer <= 0.0:
			_patch_timer = PATCH_SEND_EVERY
			game.send_request(target.kind, target.id)
		return
	if not input.interact:
		return
	match target.kind:
		"station":
			game.send_request("station", target.id)
		"ladder":
			game.send_request("climb", target.id, [_ladder_ship])
		"hatch":
			game.send_request("hatch", target.id)
		"scoop":
			game.send_request("scoop", 0)
			Audio.play("splash", -14.0, 1.5)
		"throw":
			game.send_request("throw", 0)
			Audio.play("splash", -8.0, 1.2)
		"sell", "drop", "board", "deliver", "eat":
			game.send_request(target.kind, 0)
		"talk", "read", "search", "use", "rescue":
			game.send_request(target.kind, target.id)
		"give":
			game.send_request("give", 0)
			Audio.play("coins", -6.0, 1.2)
		"salt":
			game.send_request("salt", target.id)
			Audio.play("splash", -10.0, 1.6)
		"douse":
			game.send_request("douse", target.id)
			Audio.play("splash", -6.0, 0.8)
		"pickup", "open", "restock":
			game.send_request(target.kind, target.id)


## What E would do right now: {kind, id, label}, or empty.
func current_target() -> Dictionary:
	if not active or station >= 0:
		return {}
	if carry >= 0:
		var held: Loot = game.view_items.get(carry)
		var what := held.label() if held else "chest"
		if mode == Mode.WORLD and held:
			var here := body.global_position
			if held.kind == Loot.Kind.CHEST and here.distance_to(Outpost.sell_spot()) < 3.5:
				return {"kind": "sell", "id": 0, "label": "E  sell the %s to Silas Penny (%d gold)" % [what, held.value]}
			if held.kind == Loot.Kind.SKULL and here.distance_to(Outpost.mystic_spot()) < 3.5:
				return {"kind": "sell", "id": 0, "label": "E  give the skull to Mother Wren (%d gold)" % held.value}
			var give := _give_target(held, here)
			if not give.is_empty():
				return give
			if held.kind == Loot.Kind.CRATE and held.variant == Missions.SALT:
				for id in game.view_objects:
					var o: StoryObject = game.view_objects[id]
					if o.kind == StoryObject.Kind.GRAVE and o.state == 1 and here.distance_to(o.pos) < StoryRun.SALT_REACH:
						return {"kind": "salt", "id": o.id, "label": "E  pour the salt on the grave"}
			if held.kind == Loot.Kind.CRATE:
				for crew in game.traders:
					var t: Dictionary = game.traders[crew]
					if here.distance_to(Islands.trader_spot(t.island)) < 3.5:
						return {"kind": "deliver", "id": 0, "label": "E  hand the %s to the trader" % what}
		if mode == Mode.WORLD and nearest_ladder() != 0:
			return {"kind": "ladder", "id": nearest_ladder(), "label": "E  climb the ladder"}
		return {"kind": "drop", "id": 0, "label": "E  put down the %s" % what}
	var item := nearest_item()
	if item:
		var verb := "open the" if item.kind == Loot.Kind.BARREL else "pick up the"
		return {"kind": "open" if item.kind == Loot.Kind.BARREL else "pickup", "id": item.id, "label": "E  %s %s" % [verb, item.label()]}
	if mode == Mode.WORLD:
		var side := nearest_ladder()
		if side != 0:
			var whose := "climb the ladder"
			if _ladder_ship != game.own_ship and game.view_ships.has(_ladder_ship):
				whose = "board %s!" % Game.ship_name(game.view_ships[_ladder_ship])
			return {"kind": "ladder", "id": side, "label": "E  %s" % whose}
		var barrel := nearest_outpost_barrel()
		if barrel >= 0:
			return {"kind": "restock", "id": barrel, "label": "E  load supplies onto the ship"}
		var tale := _story_target(body.global_position)
		if not tale.is_empty():
			return tale
		if not game.voyage.is_empty() and not swimming and Islands.island_at(body.global_position.x, body.global_position.z) >= 0:
			return {"kind": "dig", "id": 0, "label": "Hold E  dig"}
		return {}
	if ship_id != game.own_ship:
		return {}  # aboard someone else's ship: nothing of theirs to use
	# Of everything in reach, use the thing we are looking at most directly.
	var local := frame_position()
	var eye := local + Vector3.UP * EYE_HEIGHT
	var best := {}
	var best_dot := -2.0
	var candidates: Array[Dictionary] = []
	var st := nearest_station()
	if st >= 0:
		candidates.append({"kind": "station", "id": st, "label": "E  %s" % _stations[st].label, "at": _stations[st].at})
	var hole := nearest_hole()
	if not hole.is_empty():
		candidates.append({
			"kind": "patch", "id": int(hole[0]), "at": Vector3(hole[1], hole[2], hole[3]),
			"label": "Hold E  patch the hole (%d%%)" % int(float(hole[4]) * 100.0),
		})
	if local.y > ShipShape.DECK_Y - 0.5 and _looking_at(eye, ShipShape.hatch_top_target(), HATCH_REACH, 0.3):
		candidates.append({"kind": "hatch", "id": 0, "label": "E  climb down the hatch", "at": ShipShape.hatch_top_target()})
	if ShipShape.is_below_deck(local) and eye.distance_to(ShipShape.hatch_bottom_target()) < HATCH_REACH:
		candidates.append({"kind": "hatch", "id": 1, "label": "E  climb up", "at": ShipShape.hatch_bottom_target()})
	if ShipShape.is_below_deck(local) and hp < 100 and game.view_ship.bananas > 0 \
			and _looking_at(eye, ShipShape.BANANA_BARREL + Vector3.UP * 0.9, 2.6, 0.3):
		candidates.append({
			"kind": "eat", "id": 0, "at": ShipShape.BANANA_BARREL + Vector3.UP * 0.9,
			"label": "E  eat a banana (%d left)" % game.view_ship.bananas,
		})
	if _looking_at(eye, ShipShape.map_table_target(), 2.6, 0.3):
		var map_label := "E  the mission board" if game.mission.is_empty() else "E  your mission     Hold M  the map"
		candidates.append({"kind": "board", "id": 0, "label": map_label, "at": ShipShape.map_table_target()})
	for c in candidates:
		var dot := look_direction().dot((c.at - eye).normalized())
		if dot > best_dot:
			best = c
			best_dot = dot
	if not best.is_empty():
		return best
	if _story_step_is(Story.Step.RESCUE):
		for id in game.view_objects:
			var o: StoryObject = game.view_objects[id]
			var ship := game.view_ship
			if o.kind == StoryObject.Kind.BOAT and Vector2(ship.x - o.pos.x, ship.z - o.pos.z).length() < StoryRun.RESCUE_REACH + 8.0:
				return {"kind": "rescue", "id": o.id, "label": "E  throw her a line"}
	if bucket and local.y > ShipShape.DECK_Y - 0.5:
		return {"kind": "throw", "id": 0, "label": "E  throw the water overboard"}
	var water := game.view_ship.water
	if not bucket and water > 0.1 and ShipShape.is_below_deck(local) and local.y < ShipShape.LOWER_Y + water + 0.2:
		return {"kind": "scoop", "id": 0, "label": "E  fill your bucket"}
	return {}


## Carrying what the story step wants (Captain Coco, planks, a tea crate, Señor Hueso) near
## whoever or wherever wants it: hand it over.
func _give_target(held: Loot, here: Vector3) -> Dictionary:
	var m: Dictionary = game.mission
	if m.is_empty() or m.kind != Missions.Kind.STORY:
		return {}
	var ch := Story.chapter(m.captain)
	if ch.is_empty() or int(m.handled) >= ch.steps.size():
		return {}
	var step: Dictionary = ch.steps[m.handled]
	if int(step.kind) not in [Story.Step.CHASE, Story.Step.GATHER]:
		return {}
	var to := str(step.to)
	if here.distance_to(StoryRun.give_spot(to)) > StoryRun.GIVE_REACH:
		return {}
	if to.begins_with("beach:"):
		return {"kind": "give", "id": 0, "label": "E  set the %s down here" % held.label()}
	return {"kind": "give", "id": 0, "label": "E  give the %s to %s" % [held.label(), Story.person_name(to)]}


## The story's things within reach ashore: a journal to read, a green fire to douse (or a word
## that you need water first), the sea to fill a bucket from while a fire burns, someone of
## Port Merrow to talk to, Isabel's boat, the San Telmo to dive on, a crate to search, a door.
func _story_target(here: Vector3) -> Dictionary:
	var any_fire := false
	for id in game.view_objects:
		var o: StoryObject = game.view_objects[id]
		var d := here.distance_to(o.pos)
		var flat := Vector2(here.x - o.pos.x, here.z - o.pos.z).length()
		match o.kind:
			StoryObject.Kind.BOAT:
				if flat < StoryRun.RESCUE_REACH and _story_step_is(Story.Step.RESCUE):
					return {"kind": "rescue", "id": o.id, "label": "E  help her aboard"}
			StoryObject.Kind.WRECK:
				if flat < StoryRun.DIVE_REACH and swimming:
					return {"kind": "dive", "id": o.id, "label": "Hold E  dive to the wreck"}
			StoryObject.Kind.SEARCH:
				if d < StoryRun.USE_REACH and o.state == 1:
					return {"kind": "search", "id": o.id, "label": "E  search the crate"}
			StoryObject.Kind.CELL, StoryObject.Kind.VAULT:
				if d < StoryRun.USE_REACH and o.state == 1:
					var what := "open the cell door" if o.kind == StoryObject.Kind.CELL else "open the vault"
					return {"kind": "use", "id": o.id, "label": "E  %s" % what}
			StoryObject.Kind.BOOK:
				if d < StoryRun.READ_REACH:
					return {"kind": "read", "id": o.id, "label": "E  read the journal"}
			StoryObject.Kind.BOTTLE:
				if Vector2(here.x - o.pos.x, here.z - o.pos.z).length() < StoryRun.READ_REACH:
					return {"kind": "read", "id": o.id, "label": "E  take the letter from the bottle"}
			StoryObject.Kind.FIRE, StoryObject.Kind.BONFIRE:
				if o.state <= 0:
					continue
				any_fire = true
				var reach := StoryRun.DOUSE_REACH + (2.0 if o.kind == StoryObject.Kind.BONFIRE else 0.0)
				if d < reach:
					if bucket:
						return {"kind": "douse", "id": o.id, "label": "E  throw the water on the green fire"}
					return {"kind": "hint", "id": 0, "label": "A green fire. Fill your bucket in the sea to douse it"}
	if any_fire and not bucket and Waves.height(here.x, here.z, game.render_time) > here.y + StoryRun.SCOOP_DEPTH:
		return {"kind": "scoop", "id": 0, "label": "E  fill your bucket from the sea"}
	if Islands.island_at(here.x, here.z) == Islands.outpost_index():
		for i in Story.PEOPLE_IDS.size():
			var who := Story.PEOPLE_IDS[i]
			if here.distance_to(Story.person_pos(who)) < Story.TALK_REACH:
				return {"kind": "talk", "id": i, "label": "E  talk to %s" % Story.person_name(who)}
	return {}


## Is the crew's chapter on a step of this kind?
func _story_step_is(kind: int) -> bool:
	var m: Dictionary = game.mission
	if m.is_empty() or m.kind != Missions.Kind.STORY:
		return false
	var ch := Story.chapter(m.captain)
	return not ch.is_empty() and int(m.handled) < ch.steps.size() and int(ch.steps[m.handled].kind) == kind


func _looking_at(eye: Vector3, point: Vector3, reach: float, min_dot: float) -> bool:
	var to := point - eye
	var dist := to.length()
	return dist < reach and look_direction().dot(to / maxf(dist, 1e-3)) > min_dot


## Where we are looking, in our current frame.
func look_direction() -> Vector3:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD


## The station in reach that we are looking at, or -1.
func nearest_station() -> int:
	var eye := DeckProxy.from_proxy(body.global_position) + Vector3.UP * EYE_HEIGHT
	var look := look_direction()
	var best := -1
	var best_dist := STATION_REACH
	for st in _stations:
		var to: Vector3 = st.at - eye
		var dist := to.length()
		if dist < best_dist and look.dot(to / dist) > 0.5:
			best = st.id
			best_dist = dist
	return best


## How far along a held action is (0-1) while E is held on it, or -1 when nothing is held.
func hold_progress() -> float:
	if not input.interact_held:
		return -1.0
	var target := current_target()
	if target.is_empty():
		return -1.0
	if target.kind == "dig":
		return clampf(_dig_clock / ServerSim.DIG_TIME, 0.0, 1.0)
	if target.kind == "patch":
		var hole := nearest_hole()
		return float(hole[4]) if not hole.is_empty() else -1.0
	return -1.0


## The hole in reach that we are looking at ([id, x, y, z, progress]), or empty.
func nearest_hole() -> Array:
	var local := frame_position()
	if not ShipShape.is_below_deck(local):
		return []
	var eye := local + Vector3.UP * EYE_HEIGHT
	var best: Array = []
	var best_dist := HOLE_REACH
	for h: Array in game.view_ship.holes:
		var at := Vector3(h[1], h[2], h[3])
		var dist := eye.distance_to(at)
		if dist < best_dist and _looking_at(eye, at, HOLE_REACH, 0.4):
			best = h
			best_dist = dist
	return best


## The loose chest or barrel we are looking at within reach, in our frame, or null.
func nearest_item() -> Loot:
	var eye := frame_position() + Vector3.UP * EYE_HEIGHT
	var best: Loot = null
	var best_dot := 0.55
	for id in game.view_items:
		var item: Loot = game.view_items[id]
		var reachable := false
		match item.state:
			Loot.State.GROUND, Loot.State.FLOATING:
				reachable = mode == Mode.WORLD
			Loot.State.ON_SHIP:
				reachable = mode == Mode.ON_SHIP and item.ship == ship_id
		if not reachable:
			continue
		var centre := item.pos + Vector3.UP * 0.35
		var to := centre - eye
		if to.length() > ITEM_REACH + 0.6:
			continue
		var dot := look_direction().dot(to.normalized())
		if dot > best_dot:
			best = item
			best_dot = dot
	return best


## The outpost's supply barrel within reach, or -1.
func nearest_outpost_barrel() -> int:
	var spots := Outpost.barrels()
	for i in spots.size():
		if body.global_position.distance_to(spots[i]) < ITEM_REACH:
			return i
	return -1


var _ladder_ship := 1


## The ladder (-1 port, 1 starboard) of any ship within reach of a swimmer, or 0.
## Which ship it belongs to is left in _ladder_ship.
func nearest_ladder() -> int:
	var p := body.global_position
	for id in game.ship_views:
		var s: ShipState = game.view_ships.get(id)
		if s == null or s.is_sinking():
			continue
		for side: int in [-1, 1]:
			var bottom: Vector3 = game.ship_views[id].global_transform * ShipShape.ladder_bottom(side)
			if Vector2(p.x - bottom.x, p.z - bottom.z).length() < LADDER_REACH and absf(p.y - bottom.y) < 3.0:
				_ladder_ship = id
				return side
	return 0


## The ship whose frame we stand in.
func frame_ship() -> ShipState:
	return game.view_ships.get(ship_id, game.view_ship)


## The aim of the cannon we are manning, from where we look: (yaw toward the bow, pitch).
func cannon_aim() -> Vector2:
	if station < 0 or _stations[station].kind != ShipShape.Kind.CANNON:
		return Vector2.ZERO
	var side: int = _stations[station].side
	var outboard := -PI / 2.0 * side
	var swing := angle_difference(outboard, yaw) * side
	return Vector2(
		clampf(swing, -ShipShape.CANNON_YAW_LIMIT, ShipShape.CANNON_YAW_LIMIT),
		clampf(pitch + SIGHT_PITCH, ShipShape.CANNON_PITCH_MIN, ShipShape.CANNON_PITCH_MAX),
	)


## Seconds until our cannon can fire again (0 when loaded), or -1 if not at a cannon.
func cannon_reload() -> float:
	if station < 0 or _stations[station].kind != ShipShape.Kind.CANNON:
		return -1.0
	return game.view_ship.gun_reload[_stations[station].gun]


## What the HUD should offer right now.
func prompt() -> String:
	if not active:
		return ""
	if station >= 0:
		return STATION_HELP[_stations[station].kind]
	var target := current_target()
	return target.get("label", "")


## The server placed us: on spawn, at a station, up a ladder, on respawn or as a correction.
func apply_teleport(data: Array) -> void:
	teleport_seq = data[0]
	if data.size() > 6 and int(data[6]) >= 0:
		ship_id = int(data[6])
	_set_mode(data[1])
	var p := Vector3(data[2], data[3], data[4])
	yaw = data[5]
	body.global_position = DeckProxy.to_proxy(p) if mode == Mode.ON_SHIP else p
	body.velocity = Vector3.ZERO
	_curr = p
	_prev = p
	active = true


## Our position in our current frame (ship frame on board, world overboard).
func frame_position() -> Vector3:
	return DeckProxy.from_proxy(body.global_position) if mode == Mode.ON_SHIP else body.global_position


func state_array() -> Array:
	var p := frame_position()
	return [teleport_seq, mode, p.x, p.y, p.z, yaw, pitch]


## Place the camera for this frame. Called after the ship has been drawn.
func update_view() -> void:
	if not active:
		return
	var p := _prev.lerp(_curr, Engine.get_physics_interpolation_fraction())
	var look := Transform3D(Basis(Vector3.UP, yaw), p)
	head.global_transform = game.frame_transform(ship_id) * look if mode == Mode.ON_SHIP else look
	camera.rotation.x = pitch
	var tool := "bucket" if bucket else ""
	if tool == "" and input.interact_held:
		var target := current_target()
		if not target.is_empty() and target.kind in ["dig", "patch"]:
			tool = "shovel" if target.kind == "dig" else "hammer"
	weapon_view.set_tool(tool)
	weapon_view.moving = Vector2(body.velocity.x, body.velocity.z).length() > 1.0
	# Both hands are busy swimming, so the weapon is put away in the water.
	weapon_view.show_weapon(weapon, not dead and station < 0 and carry < 0 and not swimming)


func world_position() -> Vector3:
	return head.global_position


func _set_mode(m: Mode) -> void:
	mode = m
	body.collision_mask = DeckProxy.LAYER if m == Mode.ON_SHIP else 1
	if m == Mode.WORLD:
		station = -1

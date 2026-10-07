class_name LocalPlayer
extends Node3D
## The player at this keyboard (or a test bot).
##
## On board, the body walks on the still deck proxy and the camera is that position carried
## onto the moving ship, so the deck never slides away underfoot. Overboard, the body lives in
## the world: it swims on the waves or walks on islands. Walking is decided here and reported
## to the server, which checks it and can snap the player back (see Game.server_player_state).

enum Mode { ON_SHIP, WORLD }

const EYE_HEIGHT := 1.6
const STATION_REACH := 2.4
const LADDER_REACH := 3.5
const OVERBOARD_DROP := 1.2

const STATION_HELP := {
	ShipShape.Kind.WHEEL: "A / D  turn the wheel      E  let go",
	ShipShape.Kind.SAILS: "W / S  let out / take in sail      A / D  swing the sails      E  let go",
	ShipShape.Kind.ANCHOR: "W (hold)  winch the anchor up      S  drop the anchor      E  let go",
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
var teleport_seq := 0
var swimming := false
var sensitivity := 0.0025

var body: CharacterBody3D
var head: Node3D
var camera: Camera3D

var _prev := Vector3.ZERO
var _curr := Vector3.ZERO
var _send_timer := 0.0
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input.add_mouse(event.relative, sensitivity)


func _physics_process(delta: float) -> void:
	if not active or game == null:
		return
	input.poll()
	yaw = wrapf(yaw - input.look.x, -PI, PI)
	pitch = clampf(pitch - input.look.y, -1.45, 1.45)
	_prev = _curr

	if station >= 0:
		body.global_position = DeckProxy.to_proxy(_stations[station].stand)
		body.velocity = Vector3.ZERO
		if input.interact:
			game.send_request("leave", station)
	else:
		if mode == Mode.ON_SHIP:
			_move_on_ship(delta)
		else:
			_move_in_world(delta)
		if input.interact:
			_interact()

	_curr = frame_position()
	_send_timer += delta
	if _send_timer >= 1.0 / GameConfig.PLAYER_SEND_RATE:
		_send_timer = 0.0
		game.send_player_state(state_array())
		if station >= 0:
			game.send_station_input(input.wish)


func _move_on_ship(delta: float) -> void:
	body.velocity = PlayerMotor.walk(body.velocity, input.wish, yaw, input.run, body.is_on_floor(), input.jump, delta)
	body.move_and_slide()
	var local := DeckProxy.from_proxy(body.global_position)
	if local.y < ShipShape.DECK_Y - OVERBOARD_DROP or absf(local.z) > ShipShape.HALF_LENGTH + 4.0:
		_go_overboard(local)


func _move_in_world(delta: float) -> void:
	var p := body.global_position
	var surface := Waves.height(p.x, p.z, game.render_time)
	swimming = PlayerMotor.is_swimming(p.y, surface)
	if swimming:
		body.velocity = PlayerMotor.swim(body.velocity, input.wish, yaw, p.y, surface, delta)
	else:
		body.velocity = PlayerMotor.walk(body.velocity, input.wish, yaw, input.run, body.is_on_floor(), input.jump, delta)
	body.move_and_slide()


## Leave the ship frame: carry position, heading and momentum (including the ship's) into the world.
func _go_overboard(local: Vector3) -> void:
	var ship_tf := game.ship_view.global_transform
	var vel := ship_tf.basis * body.velocity
	var drift := ShipPhysics.forward(game.view_ship.yaw) * game.view_ship.speed
	yaw = wrapf(yaw + game.view_ship.yaw, -PI, PI)
	_set_mode(Mode.WORLD)
	body.global_position = ship_tf * local
	body.velocity = vel + Vector3(drift.x, 0.0, drift.y)
	_prev = body.global_position


func _interact() -> void:
	if mode == Mode.ON_SHIP:
		var id := nearest_station()
		if id >= 0:
			game.send_request("station", id)
	else:
		var side := nearest_ladder()
		if side != 0:
			game.send_request("climb", side)


## The station in reach that we are looking at, or -1.
func nearest_station() -> int:
	var eye := DeckProxy.from_proxy(body.global_position) + Vector3.UP * EYE_HEIGHT
	var look := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD
	var best := -1
	var best_dist := STATION_REACH
	for st in _stations:
		var to: Vector3 = st.at - eye
		var dist := to.length()
		if dist < best_dist and look.dot(to / dist) > 0.5:
			best = st.id
			best_dist = dist
	return best


## The ladder (-1 port, 1 starboard) within reach of a swimmer, or 0.
func nearest_ladder() -> int:
	if game.ship_view == null:
		return 0
	var p := body.global_position
	for side: int in [-1, 1]:
		var bottom: Vector3 = game.ship_view.global_transform * ShipShape.ladder_bottom(side)
		if Vector2(p.x - bottom.x, p.z - bottom.z).length() < LADDER_REACH and absf(p.y - bottom.y) < 3.0:
			return side
	return 0


## What the HUD should offer right now.
func prompt() -> String:
	if not active:
		return ""
	if station >= 0:
		return STATION_HELP[_stations[station].kind]
	if mode == Mode.ON_SHIP:
		var id := nearest_station()
		return "E  %s" % _stations[id].label if id >= 0 else ""
	return "E  climb the ladder" if nearest_ladder() != 0 else ""


## The server placed us: on spawn, at a station, up a ladder, on respawn or as a correction.
func apply_teleport(data: Array) -> void:
	teleport_seq = data[0]
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
	head.global_transform = game.ship_view.global_transform * look if mode == Mode.ON_SHIP else look
	camera.rotation.x = pitch


func world_position() -> Vector3:
	return head.global_position


func _set_mode(m: Mode) -> void:
	mode = m
	body.collision_mask = DeckProxy.LAYER if m == Mode.ON_SHIP else 1
	if m == Mode.WORLD:
		station = -1

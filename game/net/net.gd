extends Node
## Network transport (autoload as /root/Net, so it exists at the same path on every machine,
## which Godot RPCs need). Starts and stops the ENet peer, carries every message, and hands
## each one to the running Game. Game logic never touches the peer directly.

signal session_started(game: Game)
signal session_failed(reason: String)
signal session_ended(reason: String)

var game: Game = null
## Command-line options handed to each new session (AI timing and the like).
var options := {}
var _player_name := ""
var _bot_role := ""
var _signals_connected := false


## Dedicated server: no player of its own, no graphics needed.
func serve(port: int) -> Error:
	var err := _create_server(port)
	if err == OK:
		_start_game(Game.Role.SERVER, 1)
	return err


## Development shortcut: run the server and play on it from this window.
func host(port: int, player_name: String) -> Error:
	var err := _create_server(port)
	if err == OK:
		_start_game(Game.Role.HOST, 1)
		game.server_add_player(1, player_name)
	return err


func join(address: String, port: int, player_name: String, bot_role := "") -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_player_name = player_name
	_bot_role = bot_role
	_connect_signals()
	return OK


func leave(reason := "") -> void:
	_teardown()
	session_ended.emit(reason)


func _teardown() -> void:
	if game:
		game.queue_free()
		game = null
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func _create_server(port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, GameConfig.MAX_PLAYERS + 2)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_connect_signals()
	return OK


func _connect_signals() -> void:
	if _signals_connected:
		return
	_signals_connected = true
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _start_game(role: Game.Role, my_id: int, bot := "") -> void:
	game = Game.new().setup(role, my_id, bot, options)
	game.name = "Game"
	get_tree().root.add_child(game)
	session_started.emit(game)


func _on_connected() -> void:
	_hello.rpc_id(1, _player_name, GameConfig.VERSION)


func _on_connection_failed() -> void:
	_teardown()
	session_failed.emit("Could not reach the server. Check the address and that it is running.")


func _on_server_disconnected() -> void:
	leave("The server closed the connection.")


func _on_peer_disconnected(id: int) -> void:
	if game and game.is_server():
		game.server_remove_player(id)


# --- messages to clients (server side) ---

func send_snapshot(data: Array) -> void:
	_snapshot.rpc(data)


func send_teleport(id: int, data: Array) -> void:
	if id == multiplayer.get_unique_id():
		game.client_on_teleport(data)
	else:
		_teleport.rpc_id(id, data)


func send_roster(roster: Dictionary) -> void:
	_roster.rpc(roster)
	if game.has_view():
		game.client_on_roster(roster)


## A one-off happening for every client (a shot, an impact).
func send_event(kind: String, data: Array) -> void:
	_event.rpc(kind, data)
	if game.has_view():
		game.client_on_event(kind, data)


## id 0 means everyone.
func send_message(id: int, text: String) -> void:
	if id == 0:
		_message.rpc(text)
		if game.has_view():
			game.client_on_message(text)
	elif id == multiplayer.get_unique_id():
		game.client_on_message(text)
	else:
		_message.rpc_id(id, text)


# --- messages to the server (client side) ---

func send_player_state(data: Array) -> void:
	_player_state.rpc_id(1, data)


func send_station_input(axes: Vector2, aim: Vector2) -> void:
	_station_input.rpc_id(1, axes, aim)


func send_request(action: String, arg: int, data: Array = []) -> void:
	_request.rpc_id(1, action, arg, data)


# --- RPC endpoints ---

@rpc("any_peer", "call_remote", "reliable")
func _hello(player_name: String, version: String) -> void:
	if game == null or not game.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var reason := game.server_can_join(version)
	if reason != "":
		_refused.rpc_id(id, reason)
		# Give the refusal a moment to arrive before hanging up.
		get_tree().create_timer(0.5).timeout.connect(
			func() -> void:
				if multiplayer.multiplayer_peer:
					multiplayer.multiplayer_peer.disconnect_peer(id)
		)
		return
	_welcome.rpc_id(id, id)
	game.server_add_player(id, player_name)


@rpc("authority", "call_remote", "reliable")
func _welcome(my_id: int) -> void:
	_start_game(Game.Role.CLIENT, my_id, _bot_role)


@rpc("authority", "call_remote", "reliable")
func _refused(reason: String) -> void:
	_teardown()
	session_failed.emit(reason)


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(data: Array) -> void:
	if game:
		game.client_on_snapshot(data)


@rpc("authority", "call_remote", "reliable")
func _teleport(data: Array) -> void:
	if game:
		game.client_on_teleport(data)


@rpc("authority", "call_remote", "reliable")
func _roster(roster: Dictionary) -> void:
	if game:
		game.client_on_roster(roster)


@rpc("authority", "call_remote", "reliable")
func _event(kind: String, data: Array) -> void:
	if game:
		game.client_on_event(kind, data)


@rpc("authority", "call_remote", "reliable")
func _message(text: String) -> void:
	if game:
		game.client_on_message(text)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _player_state(data: Array) -> void:
	if game and game.is_server():
		game.server_player_state(multiplayer.get_remote_sender_id(), data)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _station_input(axes: Vector2, aim: Vector2) -> void:
	if game and game.is_server():
		game.server_station_input(multiplayer.get_remote_sender_id(), axes, aim)


@rpc("any_peer", "call_remote", "reliable")
func _request(action: String, arg: int, data: Array) -> void:
	if game and game.is_server():
		game.server_request(multiplayer.get_remote_sender_id(), action, arg, data)

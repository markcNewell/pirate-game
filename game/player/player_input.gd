class_name PlayerInput
extends RefCounted
## One tick of what a player is asking for. A human fills it from the keyboard and mouse;
## a bot (tests) sets the fields directly.

var wish := Vector2.ZERO
var run := false
var jump := false
var interact := false
## E held down (for patching), and the left mouse button pressed this tick (cannons).
var interact_held := false
var fire := false
## 0 or 1 when a weapon key was pressed this tick (1 cutlass, 2 pistol), else -1.
var weapon_key := -1
## Radians to turn this tick: x = yaw left/right, y = pitch up/down.
var look := Vector2.ZERO
var is_bot := false

var _mouse := Vector2.ZERO


## Call from _unhandled_input with mouse motion while the mouse is captured.
func add_mouse(relative: Vector2, sensitivity: float) -> void:
	_mouse += relative * sensitivity


## Fill this tick's fields. Bots skip this; their driver writes the fields itself.
func poll() -> void:
	if is_bot:
		return
	var playing := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	wish = Input.get_vector("move_left", "move_right", "move_back", "move_forward") if playing else Vector2.ZERO
	run = playing and Input.is_action_pressed("run")
	jump = playing and Input.is_action_just_pressed("jump")
	interact = playing and Input.is_action_just_pressed("interact")
	interact_held = playing and Input.is_action_pressed("interact")
	fire = playing and Input.is_action_just_pressed("fire")
	weapon_key = -1
	if playing and Input.is_action_just_pressed("weapon_1"):
		weapon_key = Weapons.Kind.CUTLASS
	elif playing and Input.is_action_just_pressed("weapon_2"):
		weapon_key = Weapons.Kind.PISTOL
	look = _mouse
	_mouse = Vector2.ZERO


## Register the key bindings once at start-up, so the project file stays small.
static func register_actions() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "run": [KEY_SHIFT], "interact": [KEY_E],
		"crew": [KEY_TAB], "menu": [KEY_ESCAPE], "map": [KEY_M],
		"weapon_1": [KEY_1], "weapon_2": [KEY_2],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", click)

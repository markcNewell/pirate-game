class_name Hud
extends CanvasLayer
## What you see on top of the world: crosshair, prompts, a compass, wind and speed, messages,
## the crew list (Tab) and the pause menu (Esc).

const INK := Color("1b1a24")
const PAPER := Color("fff8ea")
const GOLD := Color("e0b04a")

static var _panel_styles := {}

static var _display: Font


static var _theme: Theme


## Wooden buttons with gold edges and parchment fields, for the menus.
static func ui_theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	var wood := Color("8a4a26")
	var gold := Color("e0b04a")
	var make := func(bg: Color, border: Color, width: int) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_border_width_all(width)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(10)
		return sb
	_theme.set_stylebox("normal", "Button", make.call(wood, gold, 3))
	_theme.set_stylebox("hover", "Button", make.call(wood.lightened(0.12), Color("ffd86a"), 3))
	_theme.set_stylebox("pressed", "Button", make.call(wood.darkened(0.2), gold, 3))
	_theme.set_stylebox("focus", "Button", make.call(Color(0, 0, 0, 0), Color("ffd86a"), 2))
	_theme.set_color("font_color", "Button", PAPER)
	_theme.set_color("font_hover_color", "Button", Color("fff2c0"))
	_theme.set_font_size("font_size", "Button", 20)
	for cls in ["OptionButton"]:
		_theme.set_stylebox("normal", cls, make.call(Color("f2e2b8"), wood, 2))
		_theme.set_stylebox("hover", cls, make.call(Color("f7ebc8"), wood, 2))
		_theme.set_stylebox("pressed", cls, make.call(Color("e8d6a6"), wood, 2))
		_theme.set_color("font_color", cls, INK)
		_theme.set_color("font_hover_color", cls, INK)
	_theme.set_stylebox("normal", "LineEdit", make.call(Color("f2e2b8"), wood, 2))
	_theme.set_stylebox("focus", "LineEdit", make.call(Color("f7ebc8"), gold, 2))
	_theme.set_color("font_color", "LineEdit", INK)
	_theme.set_color("font_placeholder_color", "LineEdit", Color(INK, 0.45))
	_theme.set_color("caret_color", "LineEdit", INK)
	return _theme


## The pirate display face (Pirata One, SIL Open Font Licence) for titles and big messages.
static func display_font() -> Font:
	if _display == null:
		_display = load("res://art/fonts/PirataOne-Regular.ttf")
	return _display

var game: Game

var _prompt: Label
var _toast: Label
var _toast_left := 0.0
var _compass: Control
var _gauges: Control
var _damage: Control
var _health: Control
var _hurt: ColorRect
var _ghost: Label
var _veil: ColorRect
var _ring: HoldRing
var _help: PanelContainer
var _help_hint: Label
var _map: Control
var _board: PanelContainer
var _board_box: VBoxContainer
var _card: Control
var _purse: Label
var _gunner: Label
var _enemy: Label
var _crew: PanelContainer
var _crew_list: Label
var _menu: PanelContainer
var _respawn: Button


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.85)
	dot.size = Vector2(6, 6)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(3, 3)
	# A captured mouse sits at the centre of the screen, right on the dot: if the dot took
	# mouse events, it would swallow every movement and the view would never turn.
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot)

	_prompt = _label(26)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -150
	_prompt.offset_bottom = -110
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_prompt)

	_toast = _label(34)
	_toast.add_theme_font_override("font", display_font())
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 70
	# Wrapped under the compass, clear of the mission card on the left.
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_toast)

	_compass = Compass.new()
	_compass.hud = self
	_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_compass.custom_minimum_size = Vector2(640, 46)
	_compass.offset_left = -320
	_compass.offset_right = 320
	_compass.offset_top = 14
	_compass.offset_bottom = 60
	root.add_child(_compass)

	_gauges = Gauges.new()
	_gauges.hud = self
	_gauges.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_gauges.offset_top = -150
	_gauges.offset_right = 300
	_gauges.offset_bottom = -20
	_gauges.offset_left = 20
	root.add_child(_gauges)

	_damage = Damage.new()
	_damage.hud = self
	_damage.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_damage.offset_left = -280
	_damage.offset_top = -120
	_damage.offset_right = -20
	_damage.offset_bottom = -20
	root.add_child(_damage)

	_gunner = _label(24)
	_gunner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_gunner.offset_top = 40
	_gunner.offset_bottom = 80
	_gunner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_gunner)

	_enemy = _label(20)
	_enemy.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_enemy.offset_top = 104
	_enemy.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_enemy.add_theme_color_override("font_color", Color("b8f5ae"))
	root.add_child(_enemy)

	_health = Health.new()
	_health.hud = self
	_health.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_health.offset_left = -160
	_health.offset_right = 160
	_health.offset_top = -64
	_health.offset_bottom = -24
	root.add_child(_health)

	_ring = HoldRing.new()
	_ring.hud = self
	_ring.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_ring)

	_hurt = ColorRect.new()
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.color = Color(0.8, 0.05, 0.05, 0.0)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hurt)

	# While fallen, the world is seen drained and cold through this veil.
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil_material := ShaderMaterial.new()
	veil_material.shader = load("res://art/shaders/ghost_veil.gdshader")
	_veil.material = veil_material
	_veil.visible = false
	root.add_child(_veil)

	_ghost = _label(48)
	_ghost.add_theme_font_override("font", display_font())
	_ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ghost.visible = false
	var shroud := StyleBoxFlat.new()
	shroud.bg_color = Color(0.1, 0.12, 0.18, 0.15)
	_ghost.add_theme_stylebox_override("normal", shroud)
	root.add_child(_ghost)

	_help = _controls_card()
	root.add_child(_help)
	_help_hint = _label(16)
	_help_hint.text = "H  controls"
	_help_hint.modulate.a = 0.75
	_help_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_help_hint.offset_left = -300
	_help_hint.offset_right = -20
	_help_hint.offset_top = 76
	_help_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_help_hint)

	_purse = _label(22)
	_purse.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_purse.offset_left = -300
	_purse.offset_right = -20
	_purse.offset_top = 16
	_purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_purse)

	_card = MissionCard.new()
	_card.hud = self
	_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_card.offset_left = 20
	_card.offset_top = 16
	_card.offset_right = 310
	_card.offset_bottom = 260
	root.add_child(_card)

	_board = _parchment_card()
	_board_box = VBoxContainer.new()
	_board_box.add_theme_constant_override("separation", 10)
	_board.add_child(_board_box)
	_board.visible = false
	root.add_child(_board)

	_map = TreasureMap.new()
	_map.hud = self
	_map.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_map.offset_left = -260
	_map.offset_right = 260
	_map.offset_top = -230
	_map.offset_bottom = 230
	_map.visible = false
	root.add_child(_map)

	_crew = _panel()
	_crew.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crew.visible = false
	_crew_list = _label(24)
	_crew_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_crew.add_child(_crew_list)
	root.add_child(_crew)

	_build_menu(root)
	_let_mouse_through(root)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Everything on the HUD lets the mouse pass, except what you click in the pause menu.
func _let_mouse_through(node: Node) -> void:
	for child in node.get_children():
		if child == _menu:
			continue
		if child is Control and not (child is BaseButton or child is Range or child is LineEdit):
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_let_mouse_through(child)


func _build_menu(root: Control) -> void:
	_menu = _panel()
	_menu.theme = ui_theme()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_menu.add_child(box)
	var title := _label(44)
	title.add_theme_font_override("font", display_font())
	title.text = "Paused"
	box.add_child(title)

	var resume := Button.new()
	resume.text = "Back to the game"
	resume.pressed.connect(_close_menu)
	box.add_child(resume)

	_respawn = Button.new()
	_respawn.text = "Respawn on the ship"
	_respawn.pressed.connect(func() -> void:
		game.send_request("respawn", 0)
		_close_menu())
	box.add_child(_respawn)

	var sens_label := _label(18)
	sens_label.text = "Mouse sensitivity"
	box.add_child(sens_label)
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.006
	sens.step = 0.0001
	sens.value = Settings.sensitivity
	sens.custom_minimum_size = Vector2(280, 24)
	sens.value_changed.connect(func(v: float) -> void:
		Settings.sensitivity = v
		game.local_player.sensitivity = v
		Settings.save())
	box.add_child(sens)

	var leave := Button.new()
	leave.text = "Leave the game"
	leave.pressed.connect(func() -> void: Net.leave())
	box.add_child(leave)
	root.add_child(_menu)


func _unhandled_input(event: InputEvent) -> void:
	if _board.visible and event is InputEventKey and event.pressed and not event.echo:
		_board_key(event as InputEventKey)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu"):
		if _menu.visible:
			_close_menu()
		else:
			_menu.visible = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("crew"):
		_crew.visible = true
	elif event.is_action_released("crew"):
		_crew.visible = false
	elif event is InputEventMouseButton and event.pressed and not _menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _close_menu() -> void:
	_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if game == null or game.local_player == null:
		return
	_prompt.text = game.local_player.prompt()
	_toast_left -= delta
	_toast.modulate.a = clampf(_toast_left, 0.0, 1.0)
	var far := game.distance_to_ship() > GameConfig.RESPAWN_DISTANCE
	_respawn.text = "Respawn on the ship (you are far away)" if far else "Respawn on the ship"
	if _crew.visible:
		var lines := ["Crews"]
		var ids := game.roster.keys()
		ids.sort_custom(func(a: int, b: int) -> bool:
			return game.view_players.get(a, {}).get("crew", 9) < game.view_players.get(b, {}).get("crew", 9))
		var last_crew := -1
		for id in ids:
			var p: Dictionary = game.view_players.get(id, {})
			var c: int = p.get("crew", 0)
			if c != last_crew and c > 0:
				last_crew = c
				lines.append("%s%s - %d gold" % [ServerSim.CREW_NAMES[c - 1], " (yours)" if c == game.own_crew else "", game.purses.get(c, 0)])
			var job := ""
			if p.get("station", -1) >= 0:
				job = "  -  " + ShipShape.stations()[p.station].label.trim_prefix("take ").trim_prefix("work ")
			elif p.get("mode", 0) == LocalPlayer.Mode.WORLD:
				job = "  -  overboard"
			lines.append("    %s%s%s" % [game.roster[id], " (you)" if id == game.local_id else "", job])
		_crew_list.text = "\n".join(lines)
	_compass.queue_redraw()
	_gauges.queue_redraw()
	_damage.queue_redraw()
	_health.queue_redraw()
	_ring.queue_redraw()
	_hurt.color.a = maxf(0.0, _hurt.color.a - delta * 1.2)
	_ghost.visible = game.local_player.dead
	_veil.visible = _ghost.visible
	if _ghost.visible:
		_ghost.text = "You have fallen.\nThe sea will send you back aboard shortly."
	var ship := game.view_ship
	_purse.text = "%d gold\n%d cannonballs  %d planks" % [game.purse, ship.cannonballs, ship.planks]
	if Input.is_action_just_pressed("help") and not _menu.visible:
		toggle_help()
	_map.visible = Input.is_action_pressed("map") and not game.mission.is_empty() and not _menu.visible
	_prompt.visible = not _map.visible and not _board.visible and not game.local_player.dead
	if _board.visible and game.local_player.frame_position().distance_to(ShipShape.map_table_target()) > 3.5:
		close_board()
	_card.queue_redraw()
	if _map.visible:
		_map.queue_redraw()
	var reload := game.local_player.cannon_reload()
	_gunner.text = "" if reload < 0.0 else ("Loaded - left click to fire" if reload <= 0.0 else "Reloading %.1f s" % reload)
	var enemy := game.nearest_enemy()
	_enemy.text = ""
	if enemy:
		var d := Vector2(enemy.x - game.view_ship.x, enemy.z - game.view_ship.z)
		_enemy.text = "%s: %d m %s" % [Game.ship_name(enemy), int(d.length()), ServerSim.compass_name(atan2(d.x, -d.y))]


# --- the mission board (E at the map table) ---

## Show the board: the three offers (game.offers), or the running mission with a way to give
## it up. Keys: 1-3 take an offer, 4 gives up, E or Esc close.
func show_board() -> void:
	for child in _board_box.get_children():
		child.queue_free()
	var title := _card_label("Mission board", 40, Color("5a3e22"))
	title.add_theme_font_override("font", display_font())
	_board_box.add_child(title)
	var m: Dictionary = game.mission
	if not m.is_empty():
		_board_box.add_child(_card_label("Your mission for the %s:" % Missions.COMPANY_NAMES[m.company], 20, Color("2a1a10")))
		_board_box.add_child(_card_label(m.title, 30, Missions.COMPANY_COLOURS[m.company].darkened(0.45)))
		_board_box.add_child(_card_label("4  give up this mission        E  close", 18, Color("8a2a1a")))
	else:
		for i in game.offers.size():
			var offer: Dictionary = game.offers[i]
			var c: int = offer.company
			var head := _card_label("%d   %s  (level %d)" % [i + 1, Missions.COMPANY_NAMES[c], offer.level], 22, Missions.COMPANY_COLOURS[c].darkened(0.5))
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_board_box.add_child(head)
			var line := _card_label("      %s: %s.  %d-%d gold" % [offer.title, offer.text, offer.gold.x, offer.gold.y], 18, Color("2a1a10"))
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size = Vector2(640, 0)
			_board_box.add_child(line)
		_board_box.add_child(_card_label("1 / 2 / 3  take a mission        E  close", 18, Color("8a2a1a")))
	_board.visible = true
	_board.reset_size()
	game.local_player.board_open = true


func close_board() -> void:
	_board.visible = false
	game.local_player.board_open = false


func board_visible() -> bool:
	return _board.visible


func _board_key(event: InputEventKey) -> void:
	var key := event.physical_keycode
	if key in [KEY_1, KEY_2, KEY_3] and game.mission.is_empty():
		var i := key - KEY_1
		if i < game.offers.size():
			game.send_request("voyage", game.offers[i].company)
			Audio.play("click")
			close_board()
	elif key == KEY_4 and not game.mission.is_empty():
		game.send_request("abandon", 0)
		Audio.play("click")
		close_board()
	elif key in [KEY_E, KEY_ESCAPE]:
		close_board()


func _card_label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


## A sheet of parchment in the middle of the screen (the controls card, the mission board).
func _parchment_card() -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f2e2b8")
	sb.border_color = Color("5a3e22")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	return card


func flash_damage() -> void:
	_hurt.color.a = 0.35


func toast(text: String) -> void:
	_toast.text = text
	_toast_left = 4.0


## Compass heading of the camera: 0 = north (-Z), 90 = east (+X).
func heading() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var f := -cam.global_basis.z
	return fposmod(rad_to_deg(atan2(f.x, -f.z)), 360.0)


func toggle_help() -> void:
	_help.visible = not _help.visible
	_help_hint.visible = not _help.visible


## The controls on a sheet of parchment, shown and hidden with H.
func _controls_card() -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f2e2b8")
	sb.border_color = Color("5a3e22")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	card.add_child(box)
	var title := Label.new()
	title.text = "How to sail"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", display_font())
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("5a3e22"))
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for row: Array in [
		["W A S D, mouse", "walk and look; Shift runs, Space jumps"],
		["E", "use what you look at: wheel, sails, anchor, cannon, ladder, hatch, chest"],
		["E again", "let go of a station"],
		["At the wheel", "A / D steer"],
		["At the sails", "W / S raise and lower, A / D swing them to the wind"],
		["At the anchor", "hold W to winch it up, S to drop it"],
		["At a cannon", "mouse aims, left click fires"],
		["Hold E", "patch a hole (needs planks), dig at the X"],
		["Bucket", "E in the water below decks, then E on deck to throw it out"],
		["1 / 2, left click", "cutlass or pistol, attack"],
		["E at the map table", "the mission board: treasure, bounties, cargo"],
		["M (hold)", "read your mission's map"],
		["Tab / Esc", "crew list / menu"],
		["Storms", "big seas and lightning that holes the hull: patch, bail, or sail out"],
	]:
		for i in 2:
			var cell := Label.new()
			cell.text = row[i]
			cell.add_theme_color_override("font_color", Color("2a1a10") if i == 1 else Color("8a2a1a"))
			cell.add_theme_font_size_override("font_size", 18)
			grid.add_child(cell)
	card.visible = false
	return card


func _label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", PAPER)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 8)
	return l


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK, 0.85)
	style.border_color = Toon.color("stripe")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", style)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	return p


## A strip showing 90 degrees either side of where you look.
## A HUD panel: dark see-through wood with a thin gold edge and rounded corners.
static func panel(ci: CanvasItem, rect: Rect2, radius := 12) -> void:
	if not _panel_styles.has(radius):
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Color("24160e"), 0.62)
		sb.border_color = Color(GOLD, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(radius)
		sb.shadow_color = Color(0, 0, 0, 0.25)
		sb.shadow_size = 4
		sb.anti_aliasing = true
		_panel_styles[radius] = sb
	(_panel_styles[radius] as StyleBoxFlat).draw(ci.get_canvas_item(), rect)


## A rounded bar filled to `frac` in `fill` over a dark track.
static func bar(ci: CanvasItem, rect: Rect2, frac: float, fill: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(INK, 0.6)
	track.set_corner_radius_all(int(rect.size.y))
	track.border_color = Color(GOLD, 0.6)
	track.set_border_width_all(1)
	track.draw(ci.get_canvas_item(), rect.grow(3))
	if frac <= 0.0:
		return
	var full := StyleBoxFlat.new()
	full.bg_color = fill
	full.set_corner_radius_all(int(rect.size.y * 0.5))
	full.draw(ci.get_canvas_item(), Rect2(rect.position, Vector2(maxf(rect.size.y, rect.size.x * frac), rect.size.y)))


class Compass:
	extends Control

	var hud: Hud

	func _draw() -> void:
		var w := size.x
		var mid := w * 0.5
		var h := hud.heading()
		Hud.panel(self, Rect2(Vector2.ZERO, size), int(size.y * 0.5))
		var font := Hud.display_font()
		for deg in range(0, 360, 15):
			var off := wrapf(deg - h, -180.0, 180.0)
			if absf(off) > 90.0:
				continue
			var x := mid + off / 90.0 * mid
			# Fade out toward the rounded ends of the strip.
			var fade := clampf((mid - absf(x - mid) - 18.0) / 40.0, 0.0, 1.0)
			if fade <= 0.0:
				continue
			var names := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
			if names.has(deg):
				var text: String = names[deg]
				var col := Toon.color("stripe") if deg == 0 else PAPER
				col.a *= fade
				var size_px := 26 if text.length() == 1 else 21
				var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
				draw_string(font, Vector2(x - width * 0.5, 32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
			else:
				draw_line(Vector2(x, 26), Vector2(x, 36), Color(PAPER, 0.6 * fade), 2.0)
		# A gold pointer at the top marks where you are facing.
		draw_colored_polygon(PackedVector2Array([Vector2(mid - 8, 0), Vector2(mid + 8, 0), Vector2(mid, 10)]), GOLD)


## Wind arrow (relative to where you look), ship speed in knots and the anchor.
class Gauges:
	extends Control

	var hud: Hud

	func _draw() -> void:
		var game := hud.game
		Hud.panel(self, Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		var centre := Vector2(64, size.y * 0.5)
		draw_circle(centre, 46, Color(PAPER, 0.12))
		draw_arc(centre, 46, 0.0, TAU, 40, Color(GOLD, 0.7), 2.0, true)
		var wind := game.view_wind
		var wind_heading := rad_to_deg(atan2(wind.x, -wind.y))
		var rel := deg_to_rad(wind_heading - hud.heading())
		var dir := Vector2(sin(rel), -cos(rel))
		var tip := centre + dir * 38
		var tail := centre - dir * 30
		draw_line(tail, tip, PAPER, 5.0)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip + dir * 6, tip - dir * 12 + side * 11, tip - dir * 12 - side * 11]), PAPER)
		draw_string(font, Vector2(16, size.y - 8), "wind", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(PAPER, 0.8))
		var knots := game.view_ship.speed * 1.944
		draw_string(Hud.display_font(), Vector2(130, 48), "%.0f knots" % knots, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, PAPER)
		var anchor := "anchor down" if game.view_ship.anchored else "anchor up"
		if game.view_ship.anchored and game.view_ship.anchor_progress > 0.0:
			anchor = "winching %d%%" % int(game.view_ship.anchor_progress * 100.0)
		draw_string(font, Vector2(130, 82), anchor, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPER)
		draw_string(font, Vector2(130, 108), "sails %d%% / %d%%" % [
			int(game.view_ship.sail_height[0] * 100.0), int(game.view_ship.sail_height[1] * 100.0)
		], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPER)


## The lower deck: water level against the sinking point, open holes, and your bucket.
class Damage:
	extends Control

	var hud: Hud

	func _draw() -> void:
		var ship := hud.game.view_ship
		var leaks := ship.leaks()
		if ship.water < 0.01 and leaks == 0 and not hud.game.local_player.bucket:
			return
		Hud.panel(self, Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		var frac := clampf(ship.water / ShipPhysics.SINK_LEVEL, 0.0, 1.0)
		var fill := Color("4fb6f5") if frac < 0.6 else Color("ff5a4a")
		Hud.bar(self, Rect2(Vector2(16, 40), Vector2(size.x - 32, 14)), frac, fill)
		draw_string(font, Vector2(16, 28), "water below: %d cm" % int(ship.water * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPER)
		var leak_text := "no leaks" if leaks == 0 else ("1 leak!" if leaks == 1 else "%d leaks!" % leaks)
		draw_string(font, Vector2(16, 80), leak_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd23a") if leaks > 0 else PAPER)
		if hud.game.local_player.bucket:
			draw_string(font, Vector2(130, 80), "bucket full", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("4fb6f5"))



## The running mission, top left: the company, the title and the steps, done ones dimmed and
## struck through; a cargo run's time left.
class MissionCard:
	extends Control

	var hud: Hud

	func _draw() -> void:
		var m: Dictionary = hud.game.mission
		if m.is_empty():
			return
		var lines := MissionCard.steps(m, hud.game.render_time)
		var font := get_theme_default_font()
		var width := size.x - 32
		# Long steps wrap onto further lines; the panel grows to fit.
		var heights: Array[float] = []
		var height := 70.0
		for line: Array in lines:
			var h := font.get_multiline_string_size(str(line[0]).trim_prefix("!"), HORIZONTAL_ALIGNMENT_LEFT, width, 18).y
			heights.append(h)
			height += h + 4.0
		Hud.panel(self, Rect2(Vector2.ZERO, Vector2(size.x, height + 6.0)))
		var colour: Color = Missions.COMPANY_COLOURS[m.company]
		draw_string(font, Vector2(16, 26), Missions.COMPANY_NAMES[m.company].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, colour)
		# A long title is set smaller rather than cut off.
		var title_size := 28
		while title_size > 18 and Hud.display_font().get_string_size(m.title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > width:
			title_size -= 1
		draw_string(Hud.display_font(), Vector2(16, 56), m.title, HORIZONTAL_ALIGNMENT_LEFT, width, title_size, PAPER)
		var top := 66.0
		for i in lines.size():
			var done: bool = lines[i][1]
			var text: String = lines[i][0]
			var col := Color(PAPER, 0.45) if done else PAPER
			if text.begins_with("!"):
				text = text.substr(1)
				col = Color("ffb04a")
			var y := top + font.get_ascent(18)
			draw_multiline_string(font, Vector2(16, y), text, HORIZONTAL_ALIGNMENT_LEFT, width, 18, -1, col)
			if done:
				var w := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, width)
				draw_line(Vector2(14, y - 6), Vector2(18 + w, y - 6), Color(PAPER, 0.6), 2.0)
			top += heights[i] + 4.0

	## The steps as [text, done] (text starting "!" is a warning).
	static func steps(m: Dictionary, now: float) -> Array:
		var out := []
		match int(m.kind):
			Missions.Kind.TREASURE:
				for t: Dictionary in m.targets:
					out.append(["Dig at the X on %s" % Islands.LAYOUT[t.island].name, t.done])
				out.append(["Sell to the Gold Hoarder (%d of %d)" % [m.handled, m.total], m.handled >= m.total])
			Missions.Kind.BOUNTY:
				var t: Dictionary = m.targets[0]
				out.append(["Beat %s on %s" % [m.captain, Islands.LAYOUT[t.island].name], t.done])
				out.append(["Bring his skull to the Order of Souls", m.handled >= m.total])
			Missions.Kind.CARGO:
				var t: Dictionary = m.targets[0]
				out.append(["Collect the cargo on Port Merrow's pier", false])
				out.append(["Deliver to the trader on %s (%d of %d)" % [Islands.LAYOUT[t.island].name, m.handled, m.total], false])
				var left: float = m.deadline - now
				if left > 0.0:
					out.append(["%d:%02d left" % [int(left) / 60, int(left) % 60], false])
				else:
					out.append(["!Late: crates pay half now", false])
		return out


## The mission's map (hold M): the next island to visit on parchment, its name, its mark (the
## X, the captain's skull, or the trader's crate) and where the island lies from the ship.
class TreasureMap:
	extends Control

	const PARCHMENT := Color("f2e2b8")
	const INKY := Color("5a3e22")

	var hud: Hud

	func _draw() -> void:
		var m: Dictionary = hud.game.mission
		if m.is_empty():
			return
		var v: Dictionary = m.targets[0]
		for t: Dictionary in m.targets:
			if not t.done:
				v = t
				break
		var spec: Dictionary = Islands.LAYOUT[v.island]
		var font := get_theme_default_font()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(spec.seed) * 31 + 7
		_parchment(rng)
		var centre := size * 0.5 + Vector2(0, 14)
		var scale: float = (minf(size.x, size.y) * 0.34) / (spec.radius + 6.0)
		_sea_marks(rng, centre, spec.radius * scale * 1.25)
		var beach := PackedVector2Array()
		var grass := PackedVector2Array()
		var grass_r: Array[float] = []
		for i in 64:
			var a := TAU * i / 64.0
			var wob := 1.0 + 0.04 * sin(5.0 * a)
			var dir := Vector2(cos(a), sin(a))
			beach.append(centre + dir * spec.radius * wob * scale)
			# Walk in from the shore to where the grass starts.
			var r: float = spec.radius
			while r > 0.0 and not IslandMesh.is_grass(spec, cos(a) * r * wob, sin(a) * r * wob):
				r -= 0.5
			grass.append(centre + dir * r * wob * scale)
			grass_r.append(r * wob * scale)
		draw_colored_polygon(beach, Color("e8cf98"))
		draw_colored_polygon(grass, Color("9cbf6e"))
		beach.append(beach[0])
		draw_polyline(beach, INKY, 3.0, true)
		# A few palms drawn the way a map-maker would.
		for i in 6:
			var k := rng.randi_range(0, 63)
			var p := centre + Vector2(cos(TAU * k / 64.0), sin(TAU * k / 64.0)) * grass_r[k] * rng.randf_range(0.25, 0.8)
			_palm(p)
		var x := centre + Vector2(v.x - spec.x, v.z - spec.z) * scale
		match int(m.kind):
			Missions.Kind.TREASURE:
				_trail(beach, x, rng)
				for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
					draw_line(x - d * 13.0, x + d * 13.0, Color("c8302a"), 7.0, true)
			Missions.Kind.BOUNTY:
				_skull(x)
			Missions.Kind.CARGO:
				_crate(x)
		draw_string(Hud.display_font(), Vector2(0, 50), spec.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 42, INKY)
		if m.targets.size() > 1:
			var k: int = m.targets.find(v)
			draw_string(font, Vector2(0, 74), "island %d of %d" % [k + 1, m.targets.size()], HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, INKY)
		_compass_rose(Vector2(size.x - 52, 62))
		var ship := hud.game.view_ship
		var to := Vector2(spec.x - ship.x, spec.z - ship.z)
		var hint := "%d m to the %s" % [int(to.length()), ServerSim.compass_name(atan2(to.x, -to.y))]
		draw_string(font, Vector2(0, size.y - 24), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, INKY)

	## The sheet: torn, scorched edges round a slightly yellowed middle.
	func _parchment(rng: RandomNumberGenerator) -> void:
		var edge := PackedVector2Array()
		var pad := 6.0
		var corners: Array[Vector2] = [Vector2(pad, pad), Vector2(size.x - pad, pad), Vector2(size.x - pad, size.y - pad), Vector2(pad, size.y - pad)]
		for c in 4:
			var a: Vector2 = corners[c]
			var b: Vector2 = corners[(c + 1) % 4]
			var steps := int(a.distance_to(b) / 18.0)
			var inward := (b - a).normalized().orthogonal()
			for i in steps:
				var p := a.lerp(b, float(i) / steps)
				edge.append(p - inward * rng.randf_range(-1.0, 5.0))
		draw_colored_polygon(edge, PARCHMENT)
		var ring := edge.duplicate()
		ring.append(edge[0])
		draw_polyline(ring, Color("9a6a3a", 0.55), 10.0, true)
		draw_polyline(ring, Color("5a3e22", 0.9), 2.5, true)

	## Little wavy strokes on the sea around the island.
	func _sea_marks(rng: RandomNumberGenerator, centre: Vector2, keep_out: float) -> void:
		for i in 22:
			var p := Vector2(rng.randf_range(40, size.x - 40), rng.randf_range(80, size.y - 50))
			if p.distance_to(centre) < keep_out:
				continue
			for k in 2:
				draw_arc(p + Vector2(k * 12.0, 0), 6.0, PI * 1.1, PI * 1.9, 6, Color(INKY, 0.45), 2.0, true)

	func _palm(p: Vector2) -> void:
		var top := p + Vector2(3, -16)
		draw_line(p, top, INKY, 2.5, true)
		for a: float in [-2.6, -1.9, -1.2, -0.5]:
			var leaf := Vector2(cos(a), sin(a) * 0.6 + 0.25) * 10.0
			draw_line(top, top + leaf, Color("3f6e2e"), 3.0, true)

	## A dotted path from the nearest stretch of beach to the X.
	func _trail(beach: PackedVector2Array, x: Vector2, rng: RandomNumberGenerator) -> void:
		var start := beach[0]
		for p in beach:
			if p.distance_to(x) < start.distance_to(x):
				start = p
		var bend := (x - start).orthogonal().normalized() * rng.randf_range(-20.0, 20.0)
		var mid := (start + x) * 0.5 + bend
		var dots := 14
		for i in range(1, dots):
			var t := float(i) / dots
			var p := start.lerp(mid, t).lerp(mid.lerp(x, t), t)
			draw_circle(p, 2.2, Color(INKY, 0.8))

	## A skull and crossbones in ink, where a bounty's captain waits.
	func _skull(at: Vector2) -> void:
		for a: float in [0.7, -0.7]:
			var d := Vector2(cos(a), sin(a)) * 18.0
			draw_line(at - d, at + d, INKY, 5.0, true)
		draw_circle(at + Vector2(0, -6), 12.0, PARCHMENT)
		draw_arc(at + Vector2(0, -6), 12.0, 0.0, TAU, 20, INKY, 3.0, true)
		draw_rect(Rect2(at + Vector2(-6, 2), Vector2(12, 7)), INKY)
		for sx: float in [-5.0, 5.0]:
			draw_circle(at + Vector2(sx, -7), 3.2, Color("c8302a"))

	## A crate marked with the Merchant Alliance's anchor, where the trader waits.
	func _crate(at: Vector2) -> void:
		var r := Rect2(at - Vector2(13, 13), Vector2(26, 26))
		draw_rect(r, Color("c08a50"))
		draw_rect(r, INKY, false, 3.0)
		draw_line(r.position, r.end, INKY, 2.0, true)
		draw_line(r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), INKY, 2.0, true)

	func _compass_rose(at: Vector2) -> void:
		for k in 4:
			var a := k * PI / 2.0 - PI / 2.0
			var tip := at + Vector2(cos(a), sin(a)) * 24.0
			var side := Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0)) * 6.0
			draw_colored_polygon(PackedVector2Array([at + side, tip, at - side]), Color("c8302a") if k == 0 else INKY)
		draw_circle(at, 4.0, PARCHMENT)
		draw_string(Hud.display_font(), at + Vector2(-7, -28), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("c8302a"))


## Health bar and the weapon in hand (1 cutlass, 2 pistol).
## A gold ring round the crosshair that fills while E is held on a hole or a dig spot.
class HoldRing:
	extends Control

	var hud: Hud

	func _draw() -> void:
		var progress := hud.game.local_player.hold_progress()
		if progress < 0.0:
			return
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 40, Color(INK, 0.45), 7.0, true)
		draw_arc(Vector2.ZERO, 26.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 40, GOLD, 5.0, true)


class Health:
	extends Control

	var hud: Hud

	func _draw() -> void:
		var lp := hud.game.local_player
		var font := get_theme_default_font()
		Hud.panel(self, Rect2(Vector2(-14, -6), size + Vector2(28, 10)))
		var bar := Rect2(Vector2(0, 22), Vector2(size.x, 14))
		Hud.bar(self, bar, lp.hp / 100.0, Color("e04a3a") if lp.hp < 35 else Color("63c25a"))
		var names := ["1 cutlass", "2 pistol"]
		for i in 2:
			var col := Toon.color("stripe") if lp.weapon == i else Color(PAPER, 0.6)
			draw_string(font, Vector2(i * size.x * 0.5, 14), names[i], HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.5, 18, col)

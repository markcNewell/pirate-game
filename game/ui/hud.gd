class_name Hud
extends CanvasLayer
## What you see on top of the world: crosshair, prompts, a compass, wind and speed, messages,
## the crew list (Tab) and the pause menu (Esc).

const INK := Color("1b1a24")
const PAPER := Color("fff8ea")
const GOLD := Color("e0b04a")
const WORLD_GREEN := Color("9cff8a")

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
## Linnet's lantern in your eyes: the screen goes white and slowly clears.
var _blind: ColorRect
var _world_line: Label
var _world_event: Array = []
var _ring: HoldRing
var _help: PanelContainer
var _help_hint: Label
var _map: Control
var _board: PanelContainer
var _board_box: VBoxContainer
## Someone talking (bottom of the screen) and a journal page (middle): see show_talk.
var _talk: PanelContainer
var _talk_name: Label
var _talk_text: Label
var _talk_hint: Label
var _talk_lines: Array = []
var _talk_at := 0
var _journal: PanelContainer
var _journal_title: Label
var _journal_text: Label
## Big Martha's counter (see show_shop); rebuilt when your gold or wardrobe changes.
var _shop: PanelContainer
var _shop_box: VBoxContainer
var _shop_seen := ""
var _card: Control
var _purse: Label
var _level: Control
var _level_banner: Label
var _level_banner_left := 0.0
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

	_blind = ColorRect.new()
	_blind.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blind.color = Color(0.92, 1.0, 0.9, 0.0)
	_blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_blind)

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
	_help_hint.offset_top = 128
	_help_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_help_hint)

	_purse = _label(22)
	_purse.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_purse.offset_left = -300
	_purse.offset_right = -20
	_purse.offset_top = 16
	_purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_purse)

	_level = LevelBadge.new()
	_level.hud = self
	_level.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_level.offset_left = -300
	_level.offset_right = -20
	_level.offset_top = 80
	_level.offset_bottom = 124
	root.add_child(_level)

	# The world event under way, if any: one line at the top right, under the purse.
	_world_line = _label(18)
	_world_line.add_theme_color_override("font_color", WORLD_GREEN)
	_world_line.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_world_line.offset_left = -520
	_world_line.offset_right = -24
	_world_line.offset_top = 150
	_world_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_world_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_world_line.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(_world_line)

	_level_banner = _label(44)
	_level_banner.add_theme_font_override("font", display_font())
	_level_banner.add_theme_color_override("font_color", Color("ffd86a"))
	_level_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_level_banner.offset_left = -400
	_level_banner.offset_right = 400
	_level_banner.offset_top = 170
	_level_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_level_banner.modulate.a = 0.0
	root.add_child(_level_banner)

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

	_talk = _parchment_card()
	_talk.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_talk.offset_top = -250
	_talk.offset_bottom = -40
	_talk.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var talk_box := VBoxContainer.new()
	talk_box.add_theme_constant_override("separation", 6)
	_talk.add_child(talk_box)
	_talk_name = _card_label("", 30, Color("5a3e22"))
	_talk_name.add_theme_font_override("font", display_font())
	_talk_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	talk_box.add_child(_talk_name)
	_talk_text = _card_label("", 20, Color("2a1a10"))
	_talk_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_talk_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talk_text.custom_minimum_size = Vector2(680, 0)
	talk_box.add_child(_talk_text)
	_talk_hint = _card_label("", 16, Color("8a2a1a"))
	_talk_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	talk_box.add_child(_talk_hint)
	_talk.visible = false
	root.add_child(_talk)

	_journal = _parchment_card()
	var journal_box := VBoxContainer.new()
	journal_box.add_theme_constant_override("separation", 10)
	_journal.add_child(journal_box)
	_journal_title = _card_label("", 34, Color("5a3e22"))
	_journal_title.add_theme_font_override("font", display_font())
	journal_box.add_child(_journal_title)
	_journal_text = _card_label("", 19, Color("2a1a10"))
	_journal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_journal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_journal_text.custom_minimum_size = Vector2(640, 0)
	journal_box.add_child(_journal_text)
	journal_box.add_child(_card_label("E  close", 16, Color("8a2a1a")))
	_journal.visible = false
	root.add_child(_journal)

	_shop = _parchment_card()
	_shop_box = VBoxContainer.new()
	_shop_box.add_theme_constant_override("separation", 4)
	_shop.add_child(_shop_box)
	_shop.visible = false
	root.add_child(_shop)

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
	if _shop.visible and event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode in [KEY_E, KEY_ESCAPE]:
			close_shop()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_J \
			and not _talk.visible and not _board.visible and not _shop.visible and not _menu.visible:
		# J: your deeds, as a page of the journal (J again, or E, puts it away).
		if _journal.visible:
			_close_reading()
		else:
			show_journal("Deeds", Deeds.page(game.deeds))
		get_viewport().set_input_as_handled()
		return
	if (_talk.visible or _journal.visible) and event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key in [KEY_E, KEY_SPACE, KEY_ENTER]:
			if _journal.visible:
				_close_reading()
			else:
				_next_line()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_ESCAPE:
			_close_reading()
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
				lines.append("%s%s" % [ServerSim.CREW_NAMES[c - 1], " (yours)" if c == game.own_crew else ""])
			var job := ""
			if p.get("station", -1) >= 0:
				job = "  -  " + ShipShape.stations()[p.station].label.trim_prefix("take ").trim_prefix("work ")
			elif p.get("mode", 0) == LocalPlayer.Mode.WORLD:
				job = "  -  overboard"
			var tag: Array = game.tags.get(id, [1, ""])
			lines.append("    %s  (level %d)%s%s" % [game.roster[id], tag[0], " (you)" if id == game.local_id else "", job])
		_crew_list.text = "\n".join(lines)
	_compass.queue_redraw()
	_gauges.queue_redraw()
	_damage.queue_redraw()
	_health.queue_redraw()
	_ring.queue_redraw()
	_hurt.color.a = maxf(0.0, _hurt.color.a - delta * 1.2)
	_blind.color.a = maxf(0.0, _blind.color.a - delta * 0.4)
	_ghost.visible = game.local_player.dead
	_veil.visible = _ghost.visible
	if _ghost.visible:
		_ghost.text = "You have fallen.\nThe sea will send you back aboard shortly."
	var ship := game.view_ship
	_purse.text = "%d gold\n%d cannonballs  %d planks" % [game.purse, ship.cannonballs, ship.planks]
	_level.queue_redraw()
	_level_banner_left = maxf(0.0, _level_banner_left - delta)
	if not _world_event.is_empty() and Engine.get_process_frames() % 30 == 0:
		_update_world_line()
	_level_banner.modulate.a = clampf(_level_banner_left, 0.0, 1.0)
	if Input.is_action_just_pressed("help") and not _menu.visible:
		toggle_help()
	_map.visible = Input.is_action_pressed("map") and not game.mission.is_empty() and not _menu.visible
	_prompt.visible = not _map.visible and not _board.visible and not reading() and not game.local_player.dead
	if _board.visible and game.local_player.frame_position().distance_to(ShipShape.map_table_target()) > 3.5:
		close_board()
	_card.queue_redraw()
	if _shop.visible:
		if "%d|%d|%d|%d|%d|%d|%s" % [game.purse, game.my_outfit, game.my_dye, game.my_blade, game.my_gun, game.my_armour, game.owned] != _shop_seen:
			_fill_shop()
		if game.local_player.frame_position().distance_to(Outpost.martha_pos()) > Shop.REACH + 3.0 and game.local_player.mode == LocalPlayer.Mode.WORLD:
			close_shop()
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
		if m.company < 0:
			_board_box.add_child(_card_label("Your chapter of the story:", 20, Color("2a1a10")))
			_board_box.add_child(_card_label(m.title, 30, Story.COLOUR.darkened(0.55)))
		else:
			_board_box.add_child(_card_label("Your mission for the %s:" % Missions.COMPANY_NAMES[m.company], 20, Color("2a1a10")))
			_board_box.add_child(_card_label(m.title, 30, Missions.COMPANY_COLOURS[m.company].darkened(0.45)))
		_board_box.add_child(_card_label("4  give up this mission        E  close", 18, Color("8a2a1a")))
	else:
		var takeable := _takeable_offers()
		for i in takeable.size():
			var offer: Dictionary = takeable[i]
			var c: int = offer.company
			var head := _card_label("%d   %s  (level %d)" % [i + 1, Missions.COMPANY_NAMES[c], offer.level], 22, Missions.COMPANY_COLOURS[c].darkened(0.5))
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_board_box.add_child(head)
			var line := _card_label("      %s: %s.  %d-%d gold" % [offer.title, offer.text, offer.gold.x, offer.gold.y], 18, Color("2a1a10"))
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size = Vector2(640, 0)
			_board_box.add_child(line)
		for offer: Dictionary in game.offers:
			if offer.company >= 0:
				continue
			var head := _card_label("The Ash Fleet, %s:  %s" % [Story.ACT_NAMES[offer.level], offer.title], 22, Story.COLOUR.darkened(0.6))
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_board_box.add_child(head)
			var line := _card_label("      %s." % offer.text, 18, Color("2a1a10"))
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_board_box.add_child(line)
		_board_box.add_child(_card_label("1 / 2 / 3  take a mission        E  close", 18, Color("8a2a1a")))
	_board.visible = true
	_board.reset_size()
	game.local_player.board_open = true


## Someone talks: `lines` are [speaker, text] pairs, shown one at a time (E for the next).
func show_talk(lines: Array) -> void:
	if lines.size() < 2:
		return
	close_board()
	_journal.visible = false
	_talk_lines = lines
	_talk_at = 0
	_show_line()
	game.local_player.board_open = true


func _show_line() -> void:
	_talk_name.text = str(_talk_lines[_talk_at])
	_talk_text.text = str(_talk_lines[_talk_at + 1])
	_talk_hint.text = "E  next" if _talk_at + 2 < _talk_lines.size() else "E  close"
	_talk.visible = true
	_talk.reset_size()


func _next_line() -> void:
	_talk_at += 2
	if _talk_at + 1 < _talk_lines.size():
		_show_line()
		Audio.play("click", -8.0)
	else:
		_close_reading()


## A journal page, read where it was found.
func show_journal(title: String, text: String) -> void:
	close_board()
	_talk.visible = false
	_journal_title.text = title
	_journal_text.text = text
	_journal.visible = true
	_journal.reset_size()
	game.local_player.board_open = true
	Audio.play("click", -4.0)


func _close_reading() -> void:
	_talk.visible = false
	_journal.visible = false
	if not _board.visible:
		game.local_player.board_open = false


func reading() -> bool:
	return _talk.visible or _journal.visible or _shop.visible


## Big Martha's counter: every outfit and dye, what each costs, and Buy or Wear; the mouse is
## freed to click while it is open.
func show_shop() -> void:
	close_board()
	_talk.visible = false
	_journal.visible = false
	_fill_shop()
	_shop.visible = true
	_shop.reset_size()
	game.local_player.board_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_shop() -> void:
	_shop.visible = false
	game.local_player.board_open = false
	if not _menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _fill_shop() -> void:
	_shop_seen = "%d|%d|%d|%d|%d|%d|%s" % [game.purse, game.my_outfit, game.my_dye, game.my_blade, game.my_gun, game.my_armour, game.owned]
	for child in _shop_box.get_children():
		child.queue_free()
	var title := _card_label("Big Martha's back room", 34, Color("5a3e22"))
	title.add_theme_font_override("font", display_font())
	_shop_box.add_child(title)
	_shop_box.add_child(_card_label("Looks and arms: nothing here makes you stronger.   You have %d gold." % game.purse, 17, Color("2a1a10")))
	# Outfits and dyes side by side, so the counter fits on the screen.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	_shop_box.add_child(columns)
	for kind: int in [Shop.Kind.OUTFIT, Shop.Kind.DYE, Shop.Kind.BLADE]:
		var column := VBoxContainer.new()
		columns.add_child(column)
		column.add_child(_card_label(["Outfits", "Shirt dyes", "Arms (fair swaps, not upgrades)"][kind], 22, Color("8a2a1a")))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 2)
		column.add_child(grid)
		for i in Shop.ITEMS.size():
			var item: Array = Shop.ITEMS[i]
			# The arms column holds both hands: blades, then guns.
			if item[0] != kind and not (kind == Shop.Kind.BLADE and item[0] in [Shop.Kind.GUN, Shop.Kind.ARMOUR]):
				continue
			var name := _card_label(item[2], 17, Color("2a1a10"))
			name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			name.custom_minimum_size = Vector2([240, 110, 170][kind], 0)
			if kind == Shop.Kind.DYE:
				name.add_theme_color_override("font_color", Shop.DYES[item[1]].darkened(0.35))
			grid.add_child(name)
			var own := Shop.has({"owned": game.owned}, i)
			var arms: bool = item[0] in [Shop.Kind.BLADE, Shop.Kind.GUN, Shop.Kind.ARMOUR]
			var current: int = [game.my_outfit, game.my_dye, game.my_blade, game.my_gun, game.my_armour][item[0]]
			var wearing: bool = current == item[1]
			var gift: bool = item[3] <= 0
			var now := ("carried" if arms else "wearing") if wearing else ("owned" if own else ("a gift" if gift else "%d gold" % item[3]))
			grid.add_child(_card_label(now, 16, Color("5a3e22")))
			var button := Button.new()
			button.text = ("Carry" if arms else "Wear") if own else ("-" if gift else "Buy")
			button.disabled = wearing or (not own and (gift or game.purse < item[3]))
			button.custom_minimum_size = Vector2(80, 0)
			button.pressed.connect(func() -> void:
				game.send_request("buy", i)
				Audio.play("coins", -4.0))
			grid.add_child(button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_shop_box.add_child(row)
	for pair: Array in [["Your own outfit", -1], ["Your own shirt", -2]]:
		var b := Button.new()
		b.text = pair[0]
		b.pressed.connect(func() -> void: game.send_request("wear", pair[1]))
		row.add_child(b)
	var close := Button.new()
	close.text = "Close (E)"
	close.pressed.connect(close_shop)
	row.add_child(close)


func close_board() -> void:
	_board.visible = false
	game.local_player.board_open = false


func board_visible() -> bool:
	return _board.visible


func _board_key(event: InputEventKey) -> void:
	var key := event.physical_keycode
	if key in [KEY_1, KEY_2, KEY_3] and game.mission.is_empty():
		var i := key - KEY_1
		var takeable := _takeable_offers()
		if i < takeable.size():
			game.send_request("voyage", takeable[i].company)
			Audio.play("click")
			close_board()
	elif key == KEY_4 and not game.mission.is_empty():
		game.send_request("abandon", 0)
		Audio.play("click")
		close_board()
	elif key in [KEY_E, KEY_ESCAPE]:
		close_board()


## The board's company offers (the story's line is not taken from the board).
func _takeable_offers() -> Array:
	return game.offers.filter(func(o: Dictionary) -> bool: return o.company >= 0)


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


## A world event began ([name, what, x, z]) or ended ([]).
func set_world_event(data: Array) -> void:
	_world_event = data
	_update_world_line()


## The world event's line, with how far it is and which way from our ship.
func _update_world_line() -> void:
	if _world_event.is_empty():
		_world_line.text = ""
		return
	var ship := game.view_ship
	var to := Vector2(float(_world_event[2]) - ship.x, float(_world_event[3]) - ship.z)
	var where := "%d m to the %s" % [int(to.length()), ServerSim.compass_name(atan2(to.x, -to.y))] if to.length() > 60.0 else "here"
	_world_line.text = "World event: %s (%s)\n%s" % [_world_event[0], where, _world_event[1]]


func blind() -> void:
	_blind.color.a = 1.0


## A new pirate level: a banner across the top for a few seconds.
func level_up(lvl: int, level_title: String) -> void:
	_level_banner.text = "Pirate level %d\n%s" % [lvl, level_title]
	_level_banner_left = 5.0
	Audio.play("coins", 0.0)


func toast(text: String) -> void:
	_toast.text = text
	_toast_left = 4.0


## Compass heading of the camera: 0 = north (-Z), 90 = east (+X).
## Which way the world event lies from where you stand, in compass degrees; NAN when there is
## none or you are already there.
func world_event_bearing() -> float:
	var cam := get_viewport().get_camera_3d()
	if _world_event.is_empty() or cam == null:
		return NAN
	var to := Vector2(float(_world_event[2]) - cam.global_position.x, float(_world_event[3]) - cam.global_position.z)
	if to.length() < 60.0:
		return NAN
	return fposmod(rad_to_deg(atan2(to.x, -to.y)), 360.0)


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
		["1 / 2, left click", "blade or gun (Martha sells others), attack"],
		["E at the map table", "the mission board: treasure, bounties, cargo"],
		["M (hold)", "read your mission's map"],
		["J", "your deeds: long goals, each earning a title"],
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
		# A green diamond marks the way to a world event, pinned to the strip's end when behind you.
		var event := hud.world_event_bearing()
		if not is_nan(event):
			var ex := mid + clampf(wrapf(event - h, -180.0, 180.0), -80.0, 80.0) / 90.0 * mid
			draw_colored_polygon(PackedVector2Array([Vector2(ex, 6), Vector2(ex + 7, 13), Vector2(ex, 20), Vector2(ex - 7, 13)]), WORLD_GREEN)
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



## Top right under the gold: your pirate level and title, and how far to the next level.
class LevelBadge:
	extends Control

	var hud: Hud

	func _draw() -> void:
		var g := hud.game
		var lvl := Progress.level(g.xp)
		var font := get_theme_default_font()
		var text := "Level %d  %s" % [lvl, g.title if g.title != "" else Progress.title_for(lvl)]
		draw_string(font, Vector2(0, 20), text, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 18, Color("ffd86a"))
		var bar := Rect2(Vector2(size.x - 180, 30), Vector2(180, 7))
		Hud.bar(self, bar, Progress.level_fraction(g.xp), Color("ffd86a"))


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
		var colour: Color = Story.COLOUR if m.company < 0 else Missions.COMPANY_COLOURS[m.company]
		var head: String = Missions.COMPANY_NAMES[m.company] if m.company >= 0 else "The Ash Fleet: " + MissionCard.act_name(m)
		draw_string(font, Vector2(16, 26), head.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, colour)
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
	static func act_name(m: Dictionary) -> String:
		var ch := Story.chapter(m.captain)
		return Story.ACT_NAMES[ch.act] if not ch.is_empty() else ""

	static func steps(m: Dictionary, now: float) -> Array:
		var out := []
		match int(m.kind):
			Missions.Kind.STORY:
				# Steps done so far, then the one under way; what comes after stays a surprise.
				var ch := Story.chapter(m.captain)
				if ch.is_empty():
					return out
				for i in mini(int(m.handled), ch.steps.size()):
					out.append([Story.step_text(ch.steps[i], 0, 0, true), true])
				if int(m.handled) < ch.steps.size():
					out.append([Story.step_text(ch.steps[m.handled], m.total, m.get("standing", 0)), false])
				if m.deadline > 0.0 and int(m.handled) < ch.steps.size():
					# The clock: until dawn for the vigil, before the storm for the lanterns.
					var left: float = m.deadline - now
					var kind := int(ch.steps[m.handled].kind)
					var until := {Story.Step.VIGIL: ["until dawn", "!Dawn is breaking"], Story.Step.LANTERNS: ["before the storm closes", "!The storm is closing"]}.get(kind, ["left", "!Time is up"]) as Array
					out.append(["%d:%02d %s" % [int(left) / 60, int(left) % 60, until[0]] if left > 0.0 else until[1], false])
			Missions.Kind.TREASURE:
				for t: Dictionary in m.targets:
					if str(m.captain) == "wreck":
						out.append(["Fish a chest of wreck gold out at the Reef's edge", t.done])
					else:
						out.append(["Dig at the X on %s" % Islands.LAYOUT[t.island].name, t.done])
				out.append(["Sell to Silas Penny (%d of %d)" % [m.handled, m.total], m.handled >= m.total])
			Missions.Kind.BOUNTY:
				var t: Dictionary = m.targets[0]
				if str(m.captain) == Missions.GHOST_CAPTAIN:
					out.append(["Sink the ghost galleon and fish up her captain's skull", t.done])
				else:
					out.append(["Beat %s on %s" % [m.captain, Islands.LAYOUT[t.island].name], t.done])
				out.append(["Bring the skull to Mother Wren", m.handled >= m.total])
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
		if m.targets.is_empty():
			_parchment(RandomNumberGenerator.new())
			draw_string(Hud.display_font(), Vector2(0, size.y * 0.5), "No map for this.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 42, INKY)
			draw_string(get_theme_default_font(), Vector2(0, size.y * 0.5 + 34), "Look to the horizon.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, INKY)
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
			Missions.Kind.STORY:
				var ch := Story.chapter(m.captain)
				if not ch.is_empty() and int(m.handled) < ch.steps.size():
					match int(ch.steps[m.handled].kind):
						Story.Step.BOUNTY:
							_skull(x)
						Story.Step.DOUSE:
							for t: Dictionary in m.targets:
								_flame(centre + Vector2(t.x - spec.x, t.z - spec.z) * scale, t.done)
						Story.Step.READ:
							_trail(beach, x, rng)
							_book(x)
						Story.Step.DIG_RACE:
							for t: Dictionary in m.targets:
								if not t.done:
									var p := centre + Vector2(t.x - spec.x, t.z - spec.z) * scale
									for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
										draw_line(p - d * 11.0, p + d * 11.0, Color("c8302a"), 6.0, true)
						Story.Step.SALT:
							for t: Dictionary in m.targets:
								var p := centre + Vector2(t.x - spec.x, t.z - spec.z) * scale
								draw_rect(Rect2(p - Vector2(5, 10), Vector2(10, 20)), Color("f4f1ea") if t.done else Color("3a2a1a"))
								draw_rect(Rect2(p - Vector2(5, 10), Vector2(10, 20)), INKY, false, 2.0)
						Story.Step.KEGS:
							draw_string(Hud.display_font(), x - Vector2(14, -16), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color("c8302a"))
						Story.Step.BOSS, Story.Step.VIGIL:
							_skull(x)
						Story.Step.BELLS:
							for t: Dictionary in m.targets:
								if t.island == v.island:
									_flame(centre + Vector2(t.x - spec.x, t.z - spec.z) * scale, t.done)
						Story.Step.BREACH, Story.Step.USE, Story.Step.SIEGE_SEA, Story.Step.SIEGE_BEACH, Story.Step.SNIPER, Story.Step.DOCTOR, \
								Story.Step.HULK, Story.Step.GAMBIT, Story.Step.RISEN, Story.Step.CRIPPLE, Story.Step.ADMIRAL, Story.Step.GHOST, \
								Story.Step.ASHEN, Story.Step.OCASO, Story.Step.ASH_FLAGSHIP, Story.Step.COLOSSUS, Story.Step.ASH_DUEL, Story.Step.HEART:
							_skull(x)
						Story.Step.BEACONS:
							_flame(x, false)
						Story.Step.LANTERNS:
							_flame(x, false)
						Story.Step.CHASE, Story.Step.GATHER:
							for t: Dictionary in m.targets:
								if Islands.island_at(t.x, t.z, 30.0) == v.island or t.island == v.island:
									_crate(centre + Vector2(t.x - spec.x, t.z - spec.z) * scale)
						_:
							_flame(x, false)
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

	## A crate marked with the Merrow Traders' anchor, where the trader waits.
	func _crate(at: Vector2) -> void:
		var r := Rect2(at - Vector2(13, 13), Vector2(26, 26))
		draw_rect(r, Color("c08a50"))
		draw_rect(r, INKY, false, 3.0)
		draw_line(r.position, r.end, INKY, 2.0, true)
		draw_line(r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), INKY, 2.0, true)

	## A green flame (grey once doused) where a grave fire burns.
	func _flame(at: Vector2, out: bool) -> void:
		var col := Color("5a6a5a") if out else Color("3fa060")
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			var r := 11.0 * (1.0 - 0.55 * maxf(0.0, -sin(a)))
			pts.append(at + Vector2(cos(a) * r * 0.8, sin(a) * r + (-8.0 if sin(a) < 0.0 else 0.0) * absf(sin(a))))
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, INKY, 2.0, true)

	## An open book where a journal lies.
	func _book(at: Vector2) -> void:
		for side: float in [-1.0, 1.0]:
			var page := PackedVector2Array([at, at + Vector2(side * 14, -4), at + Vector2(side * 14, 10), at + Vector2(0, 13)])
			draw_colored_polygon(page, Color("fff6dc"))
			page.append(page[0])
			draw_polyline(page, INKY, 2.0, true)

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
		var names := ["1 " + str(Weapons.blade(hud.game.my_blade).name).to_lower(), "2 " + str(Weapons.gun(hud.game.my_gun).name).to_lower().replace("flintlock ", "")]
		for i in 2:
			var col := Toon.color("stripe") if lp.weapon == i else Color(PAPER, 0.6)
			draw_string(font, Vector2(i * size.x * 0.5, 14), names[i], HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.5, 18, col)

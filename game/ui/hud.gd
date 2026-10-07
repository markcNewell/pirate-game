class_name Hud
extends CanvasLayer
## What you see on top of the world: crosshair, prompts, a compass, wind and speed, messages,
## the crew list (Tab) and the pause menu (Esc).

const INK := Color("1b1a24")
const PAPER := Color("fff8ea")

var game: Game

var _prompt: Label
var _toast: Label
var _toast_left := 0.0
var _compass: Control
var _gauges: Control
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
	root.add_child(dot)

	_prompt = _label(26)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -150
	_prompt.offset_bottom = -110
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_prompt)

	_toast = _label(24)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 70
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
	_gauges.offset_right = 260
	_gauges.offset_bottom = -20
	_gauges.offset_left = 20
	root.add_child(_gauges)

	_crew = _panel()
	_crew.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crew.visible = false
	_crew_list = _label(24)
	_crew_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_crew.add_child(_crew_list)
	root.add_child(_crew)

	_build_menu(root)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_menu(root: Control) -> void:
	_menu = _panel()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_menu.add_child(box)
	var title := _label(32)
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
		var lines := ["Crew"]
		for id in game.roster:
			var p: Dictionary = game.view_players.get(id, {})
			var job := ""
			if p.get("station", -1) >= 0:
				job = "  -  " + ShipShape.stations()[p.station].label.trim_prefix("take ").trim_prefix("work ")
			elif p.get("mode", 0) == LocalPlayer.Mode.WORLD:
				job = "  -  overboard"
			lines.append("%s%s%s" % [game.roster[id], " (you)" if id == game.local_id else "", job])
		_crew_list.text = "\n".join(lines)
	_compass.queue_redraw()
	_gauges.queue_redraw()


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
class Compass:
	extends Control

	var hud: Hud

	func _draw() -> void:
		var w := size.x
		var mid := w * 0.5
		var h := hud.heading()
		draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.45))
		var font := get_theme_default_font()
		for deg in range(0, 360, 15):
			var off := wrapf(deg - h, -180.0, 180.0)
			if absf(off) > 90.0:
				continue
			var x := mid + off / 90.0 * mid
			var names := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
			if names.has(deg):
				var text: String = names[deg]
				var col := Toon.color("stripe") if deg == 0 else PAPER
				draw_string(font, Vector2(x - 12, 30), text, HORIZONTAL_ALIGNMENT_CENTER, 24, 20, col)
			else:
				draw_line(Vector2(x, 30), Vector2(x, 40), Color(PAPER, 0.7), 2.0)
		draw_line(Vector2(mid, 36), Vector2(mid, 46), Toon.color("stripe"), 3.0)


## Wind arrow (relative to where you look), ship speed in knots and the anchor.
class Gauges:
	extends Control

	var hud: Hud

	func _draw() -> void:
		var game := hud.game
		draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.45))
		var font := get_theme_default_font()
		var centre := Vector2(64, size.y * 0.5)
		draw_circle(centre, 46, Color(PAPER, 0.15))
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
		draw_string(font, Vector2(130, 46), "%.0f kn" % knots, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, PAPER)
		var anchor := "anchor down" if game.view_ship.anchored else "anchor up"
		if game.view_ship.anchored and game.view_ship.anchor_progress > 0.0:
			anchor = "winching %d%%" % int(game.view_ship.anchor_progress * 100.0)
		draw_string(font, Vector2(130, 82), anchor, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPER)
		draw_string(font, Vector2(130, 108), "sails %d%% / %d%%" % [
			int(game.view_ship.sail_height[0] * 100.0), int(game.view_ship.sail_height[1] * 100.0)
		], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPER)

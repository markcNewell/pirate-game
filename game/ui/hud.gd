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
var _damage: Control
var _map: Control
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

	_purse = _label(22)
	_purse.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_purse.offset_left = -300
	_purse.offset_right = -20
	_purse.offset_top = 16
	_purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_purse)

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
	_damage.queue_redraw()
	var ship := game.view_ship
	_purse.text = "%d gold\n%d cannonballs  %d planks" % [game.purse, ship.cannonballs, ship.planks]
	_map.visible = Input.is_action_pressed("map") and not game.voyage.is_empty() and not _menu.visible
	if _map.visible:
		_map.queue_redraw()
	var reload := game.local_player.cannon_reload()
	_gunner.text = "" if reload < 0.0 else ("Loaded - left click to fire" if reload <= 0.0 else "Reloading %.1f s" % reload)
	var enemy := game.nearest_enemy()
	_enemy.text = ""
	if enemy:
		var d := Vector2(enemy.x - game.view_ship.x, enemy.z - game.view_ship.z)
		_enemy.text = "Skeleton ship: %d m %s" % [int(d.length()), ServerSim.compass_name(atan2(d.x, -d.y))]


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
				var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
				draw_string(font, Vector2(x - width * 0.5, 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
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


## The lower deck: water level against the sinking point, open holes, and your bucket.
class Damage:
	extends Control

	var hud: Hud

	func _draw() -> void:
		var ship := hud.game.view_ship
		var leaks := ship.leaks()
		if ship.water < 0.01 and leaks == 0 and not hud.game.local_player.bucket:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.45))
		var font := get_theme_default_font()
		var frac := clampf(ship.water / ShipPhysics.SINK_LEVEL, 0.0, 1.0)
		var bar := Rect2(Vector2(16, 40), Vector2(size.x - 32, 16))
		draw_rect(bar, Color(PAPER, 0.2))
		var fill := Color("4fb6f5") if frac < 0.6 else Color("ff5a4a")
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), fill)
		draw_string(font, Vector2(16, 28), "water below: %d cm" % int(ship.water * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPER)
		var leak_text := "no leaks" if leaks == 0 else ("1 leak!" if leaks == 1 else "%d leaks!" % leaks)
		draw_string(font, Vector2(16, 80), leak_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd23a") if leaks > 0 else PAPER)
		if hud.game.local_player.bucket:
			draw_string(font, Vector2(130, 80), "bucket full", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("4fb6f5"))



## The treasure map (hold M): the voyage island's outline on parchment, its name, the X,
## and where the island lies from the ship.
class TreasureMap:
	extends Control

	const PARCHMENT := Color("f2e2b8")
	const INKY := Color("5a3e22")

	var hud: Hud

	func _draw() -> void:
		var v: Dictionary = hud.game.voyage
		if v.is_empty():
			return
		var spec: Dictionary = Islands.LAYOUT[v.island]
		var font := get_theme_default_font()
		draw_rect(Rect2(Vector2.ZERO, size), PARCHMENT)
		draw_rect(Rect2(Vector2.ZERO, size), INKY, false, 4.0)
		var centre := size * 0.5 + Vector2(0, 14)
		var scale: float = (minf(size.x, size.y) * 0.36) / (spec.radius + 6.0)
		var beach := PackedVector2Array()
		var grass := PackedVector2Array()
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
		draw_colored_polygon(beach, Color("e8cf98"))
		draw_colored_polygon(grass, Color("9cbf6e"))
		beach.append(beach[0])
		draw_polyline(beach, INKY, 3.0)
		var x := centre + Vector2(v.x - spec.x, v.z - spec.z) * scale
		for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
			draw_line(x - d * 12.0, x + d * 12.0, Color("c8302a"), 6.0)
		draw_string(font, Vector2(0, 40), spec.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, INKY)
		var ship := hud.game.view_ship
		var to := Vector2(spec.x - ship.x, spec.z - ship.z)
		var hint := "%d m to the %s" % [int(to.length()), ServerSim.compass_name(atan2(to.x, -to.y))]
		draw_string(font, Vector2(0, size.y - 22), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, INKY)
		draw_string(font, Vector2(size.x - 40, 40), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("c8302a"))

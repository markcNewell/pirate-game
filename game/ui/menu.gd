class_name Menu
extends CanvasLayer
## The title screen: your name, the server to join, and Join / Host & play / Quit.
## A CanvasLayer so its controls can fill the window (a Control under a plain Node cannot).

var _name: LineEdit
var _address: LineEdit
var _port: SpinBox
var _crew: OptionButton
var _status: Label
## Play-test options (PlayTest): shown by the "Play-test" toggle, used by Host & play.
var _test: CheckButton
var _test_box: VBoxContainer
var _test_chapter: OptionButton
var _test_gold: SpinBox
var _test_event: OptionButton
## The command line's options, so a play-test game's never outlive it.
var _base_options := {}


func _ready() -> void:
	# The menu card sits on the left; the live sea scene (MenuBackdrop) shows round it.
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	centre.offset_right = 620
	add_child(centre)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Hud.PAPER
	style.border_color = Hud.INK
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", style)
	card.theme = Hud.ui_theme()
	centre.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var title := Label.new()
	title.text = "Sea of Slop"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Hud.display_font())
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Hud.PAPER)
	title.add_theme_color_override("font_outline_color", Hud.INK)
	title.add_theme_constant_override("outline_size", 16)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Crew a galleon with your friends. Hunt treasure, sink skeletons, rob rivals."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Hud.INK)
	box.add_child(sub)

	_name = _field(box, "Your name", Settings.name)
	_name.placeholder_text = "Pirate"
	# The server and its port on one row, and the crew on the next, so the card fits a short
	# screen even with the play-test options open.
	var server := HBoxContainer.new()
	server.add_theme_constant_override("separation", 8)
	box.add_child(server)
	_address = LineEdit.new()
	_address.text = Settings.address
	_address.placeholder_text = "Server address"
	_address.tooltip_text = "Server address"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server.add_child(_inline_label("Server"))
	server.add_child(_address)
	server.add_child(_inline_label("Port"))
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = Settings.port
	server.add_child(_port)

	var crew_row := HBoxContainer.new()
	crew_row.add_theme_constant_override("separation", 8)
	box.add_child(crew_row)
	crew_row.add_child(_inline_label("Crew"))
	_crew = OptionButton.new()
	_crew.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crew.add_item("Any crew (friends sail together)", 0)
	for i in ServerSim.CREW_NAMES.size():
		_crew.add_item("Crew %d: %s" % [i + 1, ServerSim.CREW_NAMES[i]], i + 1)
	_crew.select(Settings.crew)
	crew_row.add_child(_crew)

	# Sound: overall volume and the music, applied as you drag and saved with the rest.
	var sound := HBoxContainer.new()
	sound.add_theme_constant_override("separation", 8)
	box.add_child(sound)
	_slider(sound, "Volume", Settings.volume, func(v: float) -> void: Settings.volume = v)
	_slider(sound, "Music", Settings.music, func(v: float) -> void: Settings.music = v)

	_play_test(box)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_button(buttons, "Join", _on_join)
	_button(buttons, "Host & play", _on_host)
	_button(buttons, "Quit", func() -> void: get_tree().quit())

	# The music's licence asks for credit where people see it (CREDITS.md has every track).
	var credit := Label.new()
	credit.text = "Music by Kevin MacLeod (incompetech.com), CC BY 4.0"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 13)
	credit.add_theme_color_override("font_color", Color(Hud.INK, 0.65))
	box.add_child(credit)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color("7a1f1a"))
	box.add_child(_status)


func show_status(text: String) -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_status.text = text


func _remember() -> void:
	Settings.name = _name.text.strip_edges()
	Settings.address = _address.text.strip_edges()
	Settings.port = int(_port.value)
	Settings.crew = _crew.get_selected_id()
	Settings.save()


func _on_join() -> void:
	_remember()
	_status.text = "Connecting to %s:%d..." % [Settings.address, Settings.port]
	var err := Net.join(Settings.address, Settings.port, Settings.name, "", Settings.crew)
	if err != OK:
		_status.text = "Could not start a connection (%s)." % error_string(err)


func _on_host() -> void:
	_remember()
	Net.options = _base_options.duplicate()
	var crew := Settings.crew
	if _test.button_pressed:
		var chapter := "" if _test_chapter.selected <= 0 else str(Story.CHAPTERS[_test_chapter.selected - 1].id)
		Net.options.merge(PlayTest.options_for(chapter, int(_test_gold.value), PlayTest.EVENTS[maxi(0, _test_event.selected)]), true)
		if chapter != "":
			crew = ServerSim.CREW  # the chapter is started for crew 1
	var err := Net.host(Settings.port, Settings.name, crew)
	if err == ERR_UNAUTHORIZED:
		return  # the session_ended message says why
	if err != OK:
		_status.text = "Could not host on port %d (%s). Is another game already using it?" % [Settings.port, error_string(err)]


## "Play-test" and its options: start at any chapter (everything before it done), with gold, or
## with a world event under way. Such games don't save your pirate.
func _play_test(box: VBoxContainer) -> void:
	_base_options = Net.options.duplicate()
	_test = CheckButton.new()
	_test.text = "Play-test (doesn't save your pirate)"
	_test.add_theme_color_override("font_color", Hud.INK)
	box.add_child(_test)
	_test_box = VBoxContainer.new()
	_test_box.visible = false
	box.add_child(_test_box)
	_test.toggled.connect(func(on: bool) -> void: _test_box.visible = on)
	_test_chapter = OptionButton.new()
	_test_chapter.add_item("Start at chapter: none, play from the start")
	for i in Story.CHAPTERS.size():
		_test_chapter.add_item(PlayTest.label(i))
	_test_box.add_child(_test_chapter)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_test_box.add_child(row)
	var gold_label := Label.new()
	gold_label.text = "Gold"
	gold_label.add_theme_color_override("font_color", Hud.INK)
	row.add_child(gold_label)
	_test_gold = SpinBox.new()
	_test_gold.max_value = 20000
	_test_gold.step = 500
	_test_gold.custom_minimum_size = Vector2(110, 0)
	row.add_child(_test_gold)
	_test_event = OptionButton.new()
	_test_event.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e: String in PlayTest.EVENTS:
		_test_event.add_item("No world event" if e == "" else "Event: %s" % WorldEvents.NAMES[PlayTest.event_kind(e)])
	row.add_child(_test_event)


## Show the play-test options (for screenshots: --show-play-test).
func open_play_test() -> void:
	_test.button_pressed = true


func _inline_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Hud.INK)
	return l


func _field(box: VBoxContainer, label: String, value: String) -> LineEdit:
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", Hud.INK)
	box.add_child(l)
	var edit := LineEdit.new()
	edit.text = value
	box.add_child(edit)
	return edit


func _button(row: HBoxContainer, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(func() -> void: Audio.play("click", -6.0))
	b.pressed.connect(action)
	row.add_child(b)


func _slider(row: HBoxContainer, label: String, value: float, store: Callable) -> void:
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", Hud.INK)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(v: float) -> void:
		store.call(v)
		Audio.apply_volumes())
	row.add_child(s)


func _sky_gradient() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec3 top = vec3(0.184, 0.561, 0.941);
	vec3 horizon = vec3(0.769, 0.914, 1.0);
	vec3 sea = vec3(0.137, 0.537, 0.890);
	COLOR = vec4(UV.y < 0.72 ? mix(top, horizon, pow(UV.y / 0.72, 1.5)) : sea, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	return m

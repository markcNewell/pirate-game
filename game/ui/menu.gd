class_name Menu
extends CanvasLayer
## The title screen: your name, the server to join, and Join / Host & play / Quit.
## A CanvasLayer so its controls can fill the window (a Control under a plain Node cannot).

var _name: LineEdit
var _address: LineEdit
var _port: SpinBox
var _crew: OptionButton
var _status: Label


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
	title.text = "Pirate Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Hud.display_font())
	title.add_theme_font_size_override("font_size", 84)
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
	_address = _field(box, "Server address", Settings.address)
	var port_label := Label.new()
	port_label.text = "Port"
	port_label.add_theme_color_override("font_color", Hud.INK)
	box.add_child(port_label)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = Settings.port
	box.add_child(_port)

	var crew_label := Label.new()
	crew_label.text = "Crew"
	crew_label.add_theme_color_override("font_color", Hud.INK)
	box.add_child(crew_label)
	_crew = OptionButton.new()
	_crew.add_item("Any crew (friends sail together)", 0)
	for i in ServerSim.CREW_NAMES.size():
		_crew.add_item("Crew %d: %s" % [i + 1, ServerSim.CREW_NAMES[i]], i + 1)
	_crew.select(Settings.crew)
	box.add_child(_crew)

	# Sound: overall volume and the music, applied as you drag and saved with the rest.
	var sound := HBoxContainer.new()
	sound.add_theme_constant_override("separation", 8)
	box.add_child(sound)
	_slider(sound, "Volume", Settings.volume, func(v: float) -> void: Settings.volume = v)
	_slider(sound, "Music", Settings.music, func(v: float) -> void: Settings.music = v)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_button(buttons, "Join", _on_join)
	_button(buttons, "Host & play", _on_host)
	_button(buttons, "Quit", func() -> void: get_tree().quit())

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
	var err := Net.host(Settings.port, Settings.name, Settings.crew)
	if err != OK:
		_status.text = "Could not host on port %d (%s). Is another game already using it?" % [Settings.port, error_string(err)]


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

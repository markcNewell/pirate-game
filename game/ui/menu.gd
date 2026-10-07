class_name Menu
extends CanvasLayer
## The title screen: your name, the server to join, and Join / Host & play / Quit.
## A CanvasLayer so its controls can fill the window (a Control under a plain Node cannot).

var _name: LineEdit
var _address: LineEdit
var _port: SpinBox
var _status: Label


func _ready() -> void:
	var sky := ColorRect.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.material = _sky_gradient()
	add_child(sky)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Hud.PAPER
	style.border_color = Hud.INK
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", style)
	centre.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var title := Label.new()
	title.text = "PIRATE GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Hud.PAPER)
	title.add_theme_color_override("font_outline_color", Hud.INK)
	title.add_theme_constant_override("outline_size", 16)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "milestone 1: sail together"
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
	Settings.save()


func _on_join() -> void:
	_remember()
	_status.text = "Connecting to %s:%d..." % [Settings.address, Settings.port]
	var err := Net.join(Settings.address, Settings.port, Settings.name)
	if err != OK:
		_status.text = "Could not start a connection (%s)." % error_string(err)


func _on_host() -> void:
	_remember()
	var err := Net.host(Settings.port, Settings.name)
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
	b.pressed.connect(action)
	row.add_child(b)


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

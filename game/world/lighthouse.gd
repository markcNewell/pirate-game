class_name Lighthouse
extends Node3D
## The lighthouse's lamp at night: a glowing lamp room and two beams sweeping round over the
## sea. Lit through the same "lamps" group as every lantern. While the Spanish green fire burns
## in it (Act III, Ashes on the Wind) it burns green by day and night, and its glow gives way to
## the story's flame.

const GREEN_BEAM := Color(0.45, 1.0, 0.55, 0.26)
const WARM_BEAM := Color(1.0, 0.88, 0.55, 0.22)

const TURN_SPEED := 0.5
const BEAM_LENGTH := 110.0

var _beams: Node3D
var _glow: MeshInstance3D
var _light: OmniLight3D
var _shine: ShaderMaterial
var _level := 0.0
var _poisoned := false


func _ready() -> void:
	_beams = Node3D.new()
	add_child(_beams)
	var cone := MeshBuilder.new()
	cone.cylinder(Vector3.ZERO, Vector3(0, 0, -BEAM_LENGTH), 0.5, 9.0, 12, Color.WHITE)
	var beam_mesh := cone.build()
	var shine := ShaderMaterial.new()
	shine.shader = load("res://art/shaders/light_beam.gdshader")
	shine.set_shader_parameter("length", BEAM_LENGTH)
	_shine = shine
	for side: float in [0.0, PI]:
		var beam := MeshInstance3D.new()
		beam.mesh = beam_mesh
		beam.material_override = shine
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.rotation = Vector3(-0.06, side, 0)
		_beams.add_child(beam)
	var s := SphereMesh.new()
	s.radius = 0.95
	s.height = 1.7
	_glow = MeshInstance3D.new()
	_glow.mesh = s
	_glow.material_override = Toon.glow_material(Color("fff1a8"))
	add_child(_glow)
	_light = OmniLight3D.new()
	_light.light_color = Color("ffe2a0")
	_light.omni_range = 16.0
	_light.light_cull_mask = 0xFFFFF & ~Lantern.UNLIT_LAYER
	add_child(_light)
	add_to_group(Lantern.GROUP)
	set_level(0.0)


func set_level(level: float) -> void:
	_level = level
	var lit := 1.0 if _poisoned else level
	_beams.visible = lit > 0.3
	_glow.visible = lit > 0.3 and not _poisoned
	_light.visible = lit > 0.02
	_light.light_energy = 1.5 * lit


## The green fire lit (or put out) in the lamp.
func set_poisoned(on: bool) -> void:
	if on == _poisoned:
		return
	_poisoned = on
	_shine.set_shader_parameter("color", GREEN_BEAM if on else WARM_BEAM)
	_light.light_color = Color("7dff8a") if on else Color("ffe2a0")
	set_level(_level)


func _process(delta: float) -> void:
	if _beams.visible:
		_beams.rotation.y += delta * TURN_SPEED

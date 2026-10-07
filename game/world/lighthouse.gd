class_name Lighthouse
extends Node3D
## The lighthouse's lamp at night: a glowing lamp room and two beams sweeping round over the
## sea. Lit through the same "lamps" group as every lantern.

const TURN_SPEED := 0.5
const BEAM_LENGTH := 110.0

var _beams: Node3D
var _glow: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	_beams = Node3D.new()
	add_child(_beams)
	var cone := MeshBuilder.new()
	cone.cylinder(Vector3.ZERO, Vector3(0, 0, -BEAM_LENGTH), 0.5, 9.0, 12, Color.WHITE)
	var beam_mesh := cone.build()
	var shine := ShaderMaterial.new()
	shine.shader = load("res://art/shaders/light_beam.gdshader")
	shine.set_shader_parameter("length", BEAM_LENGTH)
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
	_beams.visible = level > 0.3
	_glow.visible = level > 0.3
	_light.visible = level > 0.02
	_light.light_energy = 1.5 * level


func _process(delta: float) -> void:
	if _beams.visible:
		_beams.rotation.y += delta * TURN_SPEED

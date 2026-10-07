class_name Lantern
extends Node3D
## A light that comes on at dusk: a ship's lantern, a pier lamp or a camp fire. World turns
## every lantern up or down together through the "lamps" group as the day goes by.

const GROUP := "lamps"
## Render layer for things lanterns should not light (sails: a lamp below one draws a bright
## disc on the canvas). Cameras and the sun still see it.
const UNLIT_LAYER := 1 << 1

var _light: OmniLight3D
var _energy: float
var _flame: MeshInstance3D
var _flicker := 0.0


## `fire` adds a flickering toon flame that only shows while the lantern is lit.
func _init(color: Color, energy: float, reach: float, fire := false) -> void:
	_energy = energy
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 0.0
	_light.omni_range = reach
	_light.omni_attenuation = 1.2
	_light.light_cull_mask = 0xFFFFF & ~UNLIT_LAYER
	_light.visible = false
	add_child(_light)
	if fire:
		var b := MeshBuilder.new()
		b.cylinder(Vector3(0, 0.0, 0), Vector3(0, 0.75, 0), 0.32, 0.0, 6, Color("ff9a2e"))
		b.cylinder(Vector3(0.05, 0.0, 0.04), Vector3(0.03, 0.5, 0.02), 0.2, 0.0, 5, Color("ffe06a"))
		_flame = MeshInstance3D.new()
		_flame.mesh = b.build()
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.vertex_color_use_as_albedo = true
		glow.vertex_color_is_srgb = true
		_flame.material_override = glow
		_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flame.visible = false
		add_child(_flame)
		_light.position.y = 0.9
	add_to_group(GROUP)


## Window panes that glow warm once the lamps are lit: a mesh of flat panes whose colour runs
## from `day` to a lamplit yellow with the lamp level.
static func lit_panes(mesh: Mesh, day: Color) -> MeshInstance3D:
	var panes := LitPanes.new()
	panes.mesh = mesh
	panes.day = day
	panes.add_to_group(GROUP)
	panes.set_level(0.0)
	return panes


class LitPanes:
	extends MeshInstance3D

	var day := Color.BLACK
	var _material := StandardMaterial3D.new()

	func _init() -> void:
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material_override = _material
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func set_level(level: float) -> void:
		_material.albedo_color = day.lerp(Color("ffcf6a"), clampf(level * 1.4, 0.0, 1.0))


## 0 by day, 1 at night.
func set_level(level: float) -> void:
	_light.visible = level > 0.02
	_light.light_energy = _energy * level
	if _flame:
		_flame.visible = level > 0.3
	set_process(_flame != null and _flame.visible)


func _process(delta: float) -> void:
	if _flame == null or not _flame.visible:
		return
	_flicker += delta
	var f := 1.0 + 0.12 * sin(_flicker * 11.0) * sin(_flicker * 7.3 + 1.0)
	_flame.scale = Vector3(1.0, f, 1.0)
	_flame.rotation.y = _flicker * 0.7
	_light.light_energy = _energy * f

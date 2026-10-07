class_name Toon
extends RefCounted
## Shared toon materials. Every code-built model uses one of these, so the whole world gets
## the same light steps and the same ink outline.

const PALETTE := {
	"hull": Color("a0522d"),
	"hull_dark": Color("7d3c20"),
	"bottom": Color("6e2a22"),
	"stripe": Color("ffd23a"),
	"deck": Color("e0a868"),
	"rail": Color("8a4524"),
	"mast": Color("b07a42"),
	"rope": Color("caa36a"),
	"trim": Color("2a1e1a"),
	"sail": Color("fff8ea"),
	"flag": Color("1d1d26"),
	"bone": Color("f4efe2"),
	"lantern": Color("ffe08a"),
	"sand": Color("f4d595"),
	"wet_sand": Color("e9c486"),
	"grass": Color("4fbf41"),
	"grass_dark": Color("3fa535"),
	"rock": Color("9aa4b5"),
	"trunk": Color("b07a42"),
	"leaf": Color("3cc24e"),
	"cloud": Color("ffffff"),
	"gold": Color("ffd23a"),
}

static var _object: ShaderMaterial
static var _sky_object: ShaderMaterial
static var _glow: StandardMaterial3D


static func color(name: String) -> Color:
	return PALETTE[name]


## The toon material with an ink outline pass, for anything built by MeshBuilder.
static func object_material() -> ShaderMaterial:
	if _object == null:
		_object = ShaderMaterial.new()
		_object.shader = load("res://art/shaders/toon.gdshader")
		_object.next_pass = _outline()
	return _object


## For clouds and other horizon things that fog must not wash out.
static func sky_object_material() -> ShaderMaterial:
	if _sky_object == null:
		_sky_object = ShaderMaterial.new()
		# No outline: at cloud distance it would be fogged into a pale halo.
		_sky_object.shader = load("res://art/shaders/toon_sky_object.gdshader")
	return _sky_object


## Unlit, for lanterns.
static func glow_material() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.albedo_color = color("lantern")
	return _glow


static func instance(mesh: Mesh, material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material if material else object_material()
	return mi


static func _outline() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://art/shaders/outline.gdshader")
	return m

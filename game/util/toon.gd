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
	"iron": Color("2e2e36"),
}

## The skeleton ships: a weathered black-green hull, ghostly green trim and tattered grey sails.
const SKELETON := {
	"hull": Color("3d4741"),
	"hull_dark": Color("262d2a"),
	"bottom": Color("1f2622"),
	"stripe": Color("78c36d"),
	"deck": Color("6e6a5c"),
	"rail": Color("333b33"),
	"mast": Color("5c5546"),
	"rope": Color("8a8470"),
	"trim": Color("121614"),
	"sail": Color("9a9c90"),
	"lantern": Color("9cff8a"),
	"gold": Color("78c36d"),
}

## Each crew's colours: sails and the stripe along the hull, so ships can be told apart.
const CREWS := [
	{},
	{"sail": Color("e05a4a"), "stripe": Color("fff2d0"), "flag": Color("7a1414")},
	{"sail": Color("5a8fe0"), "stripe": Color("ffd23a"), "flag": Color("17305a")},
	{"sail": Color("6ac46a"), "stripe": Color("fff2d0"), "flag": Color("1d4a22")},
]

static var _object: ShaderMaterial


static func crew_palette(crew: int) -> Dictionary:
	return CREWS[clampi(crew - 1, 0, CREWS.size() - 1)]
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
static func glow_material(tint: Color = PALETTE["lantern"]) -> StandardMaterial3D:
	if _glow == null or _glow.albedo_color != tint:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = tint
		if tint != PALETTE["lantern"]:
			return m
		_glow = m
	return _glow


## Unlit see-through colour (sea water inside a hull, effects).
static func clear_material(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = tint
	return m


static func instance(mesh: Mesh, material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material if material else object_material()
	return mi


static func _outline() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://art/shaders/outline.gdshader")
	return m

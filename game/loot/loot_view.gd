class_name LootView
extends Node3D
## How a chest or a supply barrel looks. Chests come in three finishes by value:
## plain wood, wood bound in silver, and a red captain's chest bound in gold.

const GLINT_EVERY := 2.6
const GLINT_LENGTH := 0.45

static var _star: ArrayMesh
static var _star_material: StandardMaterial3D

var _glint: MeshInstance3D
var _clock := randf() * GLINT_EVERY


## The chest for its value's tier, or the supply barrel (art/blender/props.py).
static func mesh_for(kind: int, tier: int) -> ArrayMesh:
	if kind == Loot.Kind.BARREL:
		return Models.mesh("supply_barrel")
	return Models.part("chests", "chest_%d" % tier)


func setup(kind: int, value: int) -> LootView:
	add_child(Toon.instance(mesh_for(kind, Loot.chest_tier(value))))
	if kind != Loot.Kind.BARREL:
		# Treasure catches the light now and then, so it stands out on a beach or a deck.
		_glint = MeshInstance3D.new()
		_glint.mesh = _star_mesh()
		_glint.material_override = _star_material
		_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glint.position = Vector3(0.25, 0.95, -0.15)
		_glint.visible = false
		add_child(_glint)
	return self


## Off while carried, so it does not twinkle in your face.
func set_glint(on: bool) -> void:
	if _glint == null or on == is_processing():
		return
	set_process(on)
	_glint.visible = false


func _process(delta: float) -> void:
	if _glint == null:
		return
	_clock += delta
	var k := fmod(_clock, GLINT_EVERY) / GLINT_LENGTH
	_glint.visible = k < 1.0
	if _glint.visible:
		_glint.scale = Vector3.ONE * sin(k * PI) * 0.5
		_glint.rotation.z = k * 1.2


## A four-pointed star in the XY plane, drawn facing the camera.
static func _star_mesh() -> ArrayMesh:
	if _star == null:
		var b := MeshBuilder.new()
		var c := Color("fffbe0")
		for i in 4:
			var a := TAU * i / 4.0
			var tip := Vector3(cos(a), sin(a), 0.0)
			var side := Vector3(-sin(a), cos(a), 0.0) * 0.16
			b.tri(Vector3.ZERO, tip, side, c, Vector3.BACK)
			b.tri(Vector3.ZERO, -side, tip, c, Vector3.BACK)
		_star = b.build()
		_star_material = StandardMaterial3D.new()
		_star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_star_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_star_material.billboard_keep_scale = true
		_star_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_star_material.vertex_color_use_as_albedo = true
		_star_material.vertex_color_is_srgb = true
		_star_material.no_depth_test = false
	return _star

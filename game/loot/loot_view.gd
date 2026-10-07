class_name LootView
extends Node3D
## How a chest or a supply barrel looks. Chests come in three finishes by value:
## plain wood, wood bound in silver, and a red captain's chest bound in gold.

const GLINT_EVERY := 2.6
const GLINT_LENGTH := 0.45

static var _meshes := {}
static var _star: ArrayMesh
static var _star_material: StandardMaterial3D

var _glint: MeshInstance3D
var _clock := randf() * GLINT_EVERY


static func mesh_for(kind: int, tier: int) -> ArrayMesh:
	var key := "%d/%d" % [kind, tier]
	if not _meshes.has(key):
		_meshes[key] = _barrel() if kind == Loot.Kind.BARREL else _chest(tier)
	return _meshes[key]


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


static func _chest(tier: int) -> ArrayMesh:
	var b := MeshBuilder.new()
	var wood: Color = [Color("8a5a32"), Color("7a4a2a"), Color("8f2f24")][tier]
	var metal: Color = [Color("3a2c22"), Color("c9d2dc"), Color("ffd23a")][tier]
	b.box(Vector3(0, 0.22, 0), Vector3(0.42, 0.22, 0.28), wood)
	b.box(Vector3(0, 0.52, 0), Vector3(0.43, 0.09, 0.29), wood.lightened(0.08))
	for x: float in [-0.3, 0.3]:
		b.box(Vector3(x, 0.32, 0), Vector3(0.04, 0.31, 0.3), metal)
	b.box(Vector3(0, 0.44, -0.3), Vector3(0.07, 0.08, 0.025), metal)
	if tier == 2:
		b.box(Vector3(0, 0.62, 0), Vector3(0.44, 0.02, 0.3), metal)
	return b.build()


static func _barrel() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.cylinder(Vector3(0, 0, 0), Vector3(0, 0.45, 0), 0.34, 0.4, 10, Color("9a6838"))
	b.cylinder(Vector3(0, 0.45, 0), Vector3(0, 0.9, 0), 0.4, 0.34, 10, Color("9a6838"))
	for h: float in [0.15, 0.7]:
		b.cylinder(Vector3(0, h, 0), Vector3(0, h + 0.07, 0), 0.4, 0.4, 10, Color("2a1e1a"))
	b.cylinder(Vector3(0, 0.9, 0), Vector3(0, 0.95, 0), 0.3, 0.3, 10, Color("c99a5b"))
	return b.build()

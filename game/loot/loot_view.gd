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


## The chest for its value's tier, the supply barrel, a captain's skull or a crate of the
## given goods (art/blender/props.py).
static func mesh_for(kind: int, tier: int, variant := 0) -> ArrayMesh:
	match kind:
		Loot.Kind.BARREL:
			return Models.mesh("supply_barrel")
		Loot.Kind.SKULL:
			return Models.part("loot", "skull")
		Loot.Kind.CRATE:
			return Models.part("loot", "crate_%s" % Missions.GOODS[variant % Missions.GOODS.size()])
	return Models.part("chests", "chest_%d" % tier)


func setup(kind: int, value: int, variant := 0) -> LootView:
	add_child(Toon.instance(mesh_for(kind, Loot.chest_tier(value), variant)))
	if kind == Loot.Kind.SKULL:
		# A skeleton captain's skull glows green from its sockets.
		var glow := OmniLight3D.new()
		glow.light_color = Color("9cff8a")
		glow.light_energy = 1.4
		glow.omni_range = 2.5
		glow.position = Vector3(0, 0.2, -0.3)
		add_child(glow)
		for side: float in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = 0.022
			ball.height = 0.044
			eye.mesh = ball
			eye.material_override = Toon.glow_material(Color("9cff8a"))
			eye.position = Vector3(side * 0.05, 0.15, -0.105)
			eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(eye)
	if kind == Loot.Kind.CHEST or kind == Loot.Kind.SKULL:
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

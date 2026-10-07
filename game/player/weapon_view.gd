class_name WeaponView
extends Node3D
## The cutlass or pistol held in front of the first-person camera, with a quick swing for
## the blade and a kick and a flash for the pistol.

## A cutlass, grip at the origin, blade forward along -Z (art/blender/props.py).
static func cutlass_mesh() -> ArrayMesh:
	return Models.mesh("cutlass")


## A flintlock pistol, the butt in the fist at the origin, barrel forward along -Z.
static func pistol_mesh() -> ArrayMesh:
	return Models.mesh("flintlock")


var weapon := Weapons.Kind.CUTLASS
## What you are working with instead of a weapon: "", "shovel", "hammer" or "bucket".
var tool := ""
var _tools := {}
var _tool_clock := 0.0
var _cutlass: MeshInstance3D
var _pistol: MeshInstance3D
var _flash: MeshInstance3D
var _hand: MeshInstance3D
var _swoosh: MeshInstance3D
var _swoosh_material: StandardMaterial3D
var _shirt: Color = Avatar.SHIRTS[0]
var _skin: Color = Avatar.SKINS[0]
var _swing := 0.0
var _kick := 0.0


## The toon look with a finer ink line: held this close, the world's line would be a rope.
static func view_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://art/shaders/toon.gdshader")
	var ink := ShaderMaterial.new()
	ink.shader = load("res://art/shaders/outline.gdshader")
	ink.set_shader_parameter("min_width", 0.0035)
	m.next_pass = ink
	return m


func _ready() -> void:
	position = Vector3(0.3, -0.33, -0.52)
	var look := view_material()
	_cutlass = Toon.instance(cutlass_mesh(), look)
	add_child(_cutlass)
	_pistol = Toon.instance(pistol_mesh(), look)
	add_child(_pistol)
	_flash = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.07
	s.height = 0.14
	_flash.mesh = s
	_flash.material_override = Toon.glow_material(Color("ffe08a"))
	_flash.position = Vector3(0, 0.055, -0.37)
	_flash.visible = false
	add_child(_flash)
	# Your own hand round the grip, and a sleeve in your shirt's colour running off screen.
	_hand = Toon.instance(hand_mesh(_shirt, _skin), look)
	add_child(_hand)
	# Tools, held in the same fist: each turned so its handle runs along the grip.
	for name: String in ["shovel", "hammer", "bucket"]:
		var held := Toon.instance(Models.part("tools", name), look)
		match name:
			"shovel":
				held.rotation.x = PI / 2.0
				held.position = Vector3(0, 0, 0.1)
			"hammer":
				held.rotation.x = -PI / 2.0
			"bucket":
				held.rotation.y = PI / 2.0
		held.visible = false
		held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(held)
		_tools[name] = held
	# A white crescent swept across the view with each cutlass swing. It hangs off the camera,
	# not the blade, so it stays put while the arm moves.
	_swoosh_material = Toon.clear_material(Color(1, 1, 1, 0.0))
	_swoosh = MeshInstance3D.new()
	_swoosh.mesh = swoosh_mesh()
	_swoosh.material_override = _swoosh_material
	_swoosh.position = Vector3(-0.05, -0.05, -0.95)
	_swoosh.visible = false
	get_parent().add_child.call_deferred(_swoosh)
	for m: MeshInstance3D in [_cutlass, _pistol, _flash, _hand, _swoosh]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A crescent from upper right to lower left, thick in the middle and pointed at both ends.
static func swoosh_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var steps := 16
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var a0 := lerpf(0.5, 2.9, t0)
		var a1 := lerpf(0.5, 2.9, t1)
		var w0 := 0.07 * sin(t0 * PI)
		var w1 := 0.07 * sin(t1 * PI)
		var r := 0.42
		var p0 := Vector3(cos(a0), sin(a0), 0.0)
		var p1 := Vector3(cos(a1), sin(a1), 0.0)
		verts.append_array([p0 * (r - w0), p1 * (r - w1), p1 * (r + w1)])
		verts.append_array([p0 * (r - w0), p1 * (r + w1), p0 * (r + w0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func set_sleeve(shirt: Color, skin: Color) -> void:
	if shirt == _shirt and skin == _skin:
		return
	_shirt = shirt
	_skin = skin
	if _hand:
		_hand.mesh = hand_mesh(shirt, skin)


## Your fist round the grip and your sleeve running back off the bottom of the screen
## (art/blender/characters.py, fp_arm), in your shirt colour and skin tone.
static func hand_mesh(shirt: Color, skin: Color) -> ArrayMesh:
	return Models.mesh("fp_arm", {
		Models.SHIRT: shirt, Models.SHIRT_DARK: shirt.darkened(0.28),
		Models.SKIN: skin, Models.SKIN_DARK: skin.darkened(0.12),
	})


func show_weapon(kind: int, visible_now: bool) -> void:
	weapon = kind
	visible = visible_now
	_cutlass.visible = kind == Weapons.Kind.CUTLASS and tool == ""
	_pistol.visible = kind == Weapons.Kind.PISTOL and tool == ""
	for name: String in _tools:
		_tools[name].visible = name == tool


## Hold a tool instead of the weapon while digging, patching or carrying water ("" for none).
func set_tool(name: String) -> void:
	if name != tool:
		tool = name
		_tool_clock = 0.0


func attack() -> void:
	if weapon == Weapons.Kind.CUTLASS:
		_swing = 1.0
	else:
		_kick = 1.0


func _process(delta: float) -> void:
	if tool != "":
		_tool_clock += delta
		_work_motion()
		return
	_swing = maxf(0.0, _swing - delta * 3.5)
	_kick = maxf(0.0, _kick - delta * 6.0)
	var arc := sin(_swing * PI)
	rotation = Vector3(-arc * 1.2 + _kick * 0.4, arc * 0.9, -arc * 0.6)
	_flash.visible = _kick > 0.6
	# The swoosh shows through the middle of the swing and fades as it ends.
	_swoosh.visible = _swing > 0.05 and _swing < 0.85
	_swoosh_material.albedo_color.a = 0.55 * sin(clampf((0.85 - _swing) / 0.8, 0.0, 1.0) * PI)


## The working motions: a shovel driven down and heaved up, a hammer tapping, a bucket
## swaying low at your side.
func _work_motion() -> void:
	var t := _tool_clock
	match tool:
		"shovel":
			var dig := maxf(0.0, sin(t * TAU / 0.8))
			rotation = Vector3(-0.9 - 0.45 * dig, 0.25, 0.1)
			position = Vector3(0.18, -0.38 - 0.12 * dig, -0.55)
		"hammer":
			var tap := absf(sin(t * TAU / 0.6))
			rotation = Vector3(0.35 - 0.7 * tap, 0.2, -0.2)
			position = Vector3(0.28, -0.3, -0.5)
		"bucket":
			rotation = Vector3(0.0, 0.0, 0.05 * sin(t * 2.0))
			position = Vector3(0.3, -0.25, -0.5)
	_flash.visible = false
	_swoosh.visible = false

class_name WeaponView
extends Node3D
## Your own arm in first person (a rigged arm from art/blender/characters.py, fp_rig) holding
## the cutlass up in guard or the pistol low: it sways while you stand, bobs as you walk, cuts
## left and right in turn from the guard with the blade (a white swoosh following), kicks with a flash for the pistol and brings
## a weapon up when you change to it. While you dig, patch or carry water it holds the spade,
## hammer or bucket instead, working them.
##
## This node sits on the camera; the arm is built in the camera's frame and the fist closes
## round a grip at GRIP, where every held thing goes (its grip at its origin, running forward).

const GRIP := Vector3(0.3, -0.33, -0.52)
const BASES := ["fp_idle", "fp_walk", "fp_idle_blade", "fp_walk_blade"]
const SWOOSH_TIME := 0.36

## A cutlass, grip at the origin, blade forward along -Z (art/blender/props.py).
static func cutlass_mesh() -> ArrayMesh:
	return Models.mesh("cutlass")


## A flintlock pistol, the butt in the fist at the origin, barrel forward along -Z.
static func pistol_mesh() -> ArrayMesh:
	return Models.mesh("flintlock")


var weapon := Weapons.Kind.CUTLASS
## What you are working with instead of a weapon: "", "shovel", "hammer" or "bucket".
var tool := ""
## Set by the player each frame: walking (or running) on something.
var moving := false
var _tools := {}
var _tool_clock := 0.0
var _rig: Node3D
var _player: AnimationPlayer
var _grip := Node3D.new()
var _cutlass: MeshInstance3D
var _pistol: MeshInstance3D
var _flash: MeshInstance3D
var _swoosh: MeshInstance3D
var _swoosh_material: StandardMaterial3D
var _shirt: Color = Avatar.SHIRTS[0]
var _skin: Color = Avatar.SKINS[0]
var _swoosh_left := 0.0
var _flash_left := 0.0
var _backhand := false
var _shown_weapon := -1


## The toon look with a finer ink line: held this close, the world's line would be a rope.
static func view_material(skinned := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://art/shaders/toon.gdshader")
	var ink := ShaderMaterial.new()
	ink.shader = load("res://art/shaders/outline.gdshader")
	ink.set_shader_parameter("min_width", 0.0035)
	ink.set_shader_parameter("normal_source", 2 if skinned else 0)
	m.next_pass = ink
	return m


func _ready() -> void:
	var look := view_material()
	_cutlass = Toon.instance(cutlass_mesh(), look)
	_grip.add_child(_cutlass)
	_pistol = Toon.instance(pistol_mesh(), look)
	_grip.add_child(_pistol)
	_flash = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.07
	s.height = 0.14
	_flash.mesh = s
	_flash.material_override = Toon.glow_material(Color("ffe08a"))
	_flash.position = Vector3(0, 0.055, -0.37)
	_flash.visible = false
	_pistol.add_child(_flash)
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
		_grip.add_child(held)
		_tools[name] = held
	_build_arm()
	# A white crescent swept across the view with each cutlass cut. It hangs off the camera,
	# not the blade, so it stays put while the arm moves.
	_swoosh_material = Toon.clear_material(Color(1, 1, 1, 0.0))
	_swoosh = MeshInstance3D.new()
	_swoosh.mesh = swoosh_mesh()
	_swoosh.material_override = _swoosh_material
	_swoosh.position = Vector3(-0.05, -0.05, -0.95)
	_swoosh.visible = false
	get_parent().add_child.call_deferred(_swoosh)
	for m: MeshInstance3D in [_cutlass, _pistol, _flash, _swoosh]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for held: MeshInstance3D in _tools.values():
		held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The arm in your shirt and skin, with the grip (and all it holds) on its fist.
func _build_arm() -> void:
	if _rig:
		_grip.get_parent().remove_child(_grip)
		_rig.queue_free()
	_rig = Models.instance("fp_rig", {
		Models.SHIRT: _shirt, Models.SHIRT_DARK: _shirt.darkened(0.28),
		Models.SKIN: _skin, Models.SKIN_DARK: _skin.darkened(0.12),
	})
	add_child(_rig)
	var arm_look := view_material(true)
	for mi: MeshInstance3D in _rig.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = arm_look
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var skeleton: Skeleton3D = _rig.find_children("*", "Skeleton3D", true, false)[0]
	var hand := BoneAttachment3D.new()
	hand.bone_name = "fp_hand"
	skeleton.add_child(hand)
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone("fp_hand"))
	_grip.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, GRIP)
	hand.add_child(_grip)
	_player = _rig.find_children("*", "AnimationPlayer", true, false)[0]
	for name: String in BASES:
		_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	_player.animation_finished.connect(func(_name: StringName) -> void: _player.play(_base(), 0.15))
	_player.play("fp_idle")


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
	if _rig:
		_build_arm()


func show_weapon(kind: int, visible_now: bool) -> void:
	weapon = kind
	visible = visible_now
	_cutlass.visible = kind == Weapons.Kind.CUTLASS and tool == ""
	_pistol.visible = kind == Weapons.Kind.PISTOL and tool == ""
	for name: String in _tools:
		_tools[name].visible = name == tool
	# Bring a weapon up when you change to it.
	if visible_now and tool == "" and kind != _shown_weapon:
		if _shown_weapon != -1 and _player:
			_player.play("fp_equip_blade" if kind == Weapons.Kind.CUTLASS else "fp_equip", 0.05)
		_shown_weapon = kind


## Hold a tool instead of the weapon while digging, patching or carrying water ("" for none).
func set_tool(name: String) -> void:
	if name != tool:
		tool = name
		_tool_clock = 0.0
		if name == "":
			transform = Transform3D.IDENTITY


func attack() -> void:
	if weapon == Weapons.Kind.CUTLASS:
		# Forehand and backhand in turn, the swoosh drawn the matching way.
		_player.play("fp_slash2" if _backhand else "fp_slash", 0.04)
		_swoosh.scale = Vector3(-1, 1, 1) if _backhand else Vector3.ONE
		_backhand = not _backhand
		_swoosh_left = SWOOSH_TIME
	else:
		_player.play("fp_shoot", 0.03)
		_flash_left = 0.07


## The resting animation: walking or standing, with the cutlass held up in guard when it is
## the weapon in hand.
func _base() -> String:
	var name := "fp_walk" if moving else "fp_idle"
	return name + "_blade" if weapon == Weapons.Kind.CUTLASS and tool == "" else name


func _process(delta: float) -> void:
	if _player and _player.current_animation in BASES and _player.current_animation != _base():
		_player.play(_base(), 0.25)
	if tool != "":
		_tool_clock += delta
		_work_motion()
		return
	_flash_left = maxf(0.0, _flash_left - delta)
	_flash.visible = _flash_left > 0.0
	# The swoosh shows through the middle of the cut and fades as it ends.
	_swoosh_left = maxf(0.0, _swoosh_left - delta)
	var k := 1.0 - _swoosh_left / SWOOSH_TIME
	_swoosh.visible = _swoosh_left > 0.0 and k > 0.15
	_swoosh_material.albedo_color.a = 0.55 * sin(clampf((k - 0.15) / 0.85, 0.0, 1.0) * PI)


## The working motions, turning the arm about the fist: a spade driven down and heaved up, a
## hammer tapping, a bucket swaying low at your side.
func _work_motion() -> void:
	var t := _tool_clock
	var rot := Vector3.ZERO
	var at := GRIP
	match tool:
		"shovel":
			var dig := maxf(0.0, sin(t * TAU / 0.8))
			rot = Vector3(-0.9 - 0.45 * dig, 0.25, 0.1)
			at = Vector3(0.18, -0.38 - 0.12 * dig, -0.55)
		"hammer":
			var tap := absf(sin(t * TAU / 0.6))
			rot = Vector3(0.35 - 0.7 * tap, 0.2, -0.2)
			at = Vector3(0.28, -0.3, -0.5)
		"bucket":
			rot = Vector3(0.0, 0.0, 0.05 * sin(t * 2.0))
			at = Vector3(0.3, -0.25, -0.5)
	transform = Transform3D(Basis.from_euler(rot), at) * Transform3D(Basis.IDENTITY, -GRIP)
	_flash.visible = false
	_swoosh.visible = false

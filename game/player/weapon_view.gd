class_name WeaponView
extends Node3D
## The cutlass or pistol held in front of the first-person camera, with a quick swing for
## the blade and a kick and a flash for the pistol.

static func cutlass_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.box(Vector3(0, 0, 0.05), Vector3(0.025, 0.025, 0.08), Color("5a3a22"))
	b.box(Vector3(0, 0, -0.04), Vector3(0.09, 0.02, 0.02), Toon.color("gold"))
	b.box(Vector3(0, 0.0, -0.4), Vector3(0.008, 0.035, 0.34), Color("d8dde2"))
	b.box(Vector3(0, 0.02, -0.72), Vector3(0.008, 0.02, 0.05), Color("d8dde2"))
	return b.build()


static func pistol_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.cylinder(Vector3(0, 0, 0.0), Vector3(0, 0, -0.32), 0.028, 0.024, 8, Color("3a3a42"))
	b.box(Vector3(0, -0.05, 0.06), Vector3(0.025, 0.07, 0.07), Color("6b4a2c"), Basis(Vector3.RIGHT, 0.5))
	b.box(Vector3(0, 0.02, 0.02), Vector3(0.012, 0.02, 0.03), Toon.color("gold"))
	return b.build()


var weapon := Weapons.Kind.CUTLASS
var _cutlass: MeshInstance3D
var _pistol: MeshInstance3D
var _flash: MeshInstance3D
var _hand: MeshInstance3D
var _shirt: Color = Avatar.SHIRTS[0]
var _swing := 0.0
var _kick := 0.0


func _ready() -> void:
	position = Vector3(0.32, -0.32, -0.45)
	_cutlass = Toon.instance(cutlass_mesh())
	add_child(_cutlass)
	_pistol = Toon.instance(pistol_mesh())
	add_child(_pistol)
	_flash = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.07
	s.height = 0.14
	_flash.mesh = s
	_flash.material_override = Toon.glow_material(Color("ffe08a"))
	_flash.position = Vector3(0, 0, -0.38)
	_flash.visible = false
	add_child(_flash)
	# Your own hand round the grip, and a sleeve in your shirt's colour running off screen.
	_hand = Toon.instance(hand_mesh(_shirt))
	add_child(_hand)
	for m: MeshInstance3D in [_cutlass, _pistol, _flash, _hand]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_sleeve(shirt: Color) -> void:
	if shirt == _shirt:
		return
	_shirt = shirt
	if _hand:
		_hand.mesh = hand_mesh(shirt)


## A fist round the grip (thumb on top) and a sleeve running back off the bottom of the screen.
static func hand_mesh(shirt: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.ellipsoid(Vector3(0.0, -0.005, 0.055), 0.055, Vector3(1.05, 1.0, 1.4), 6, 8, Color("f2c49b"))
	b.ellipsoid(Vector3(-0.035, 0.01, 0.02), 0.025, Vector3(1.0, 0.8, 1.2), 4, 6, Color("f2c49b"))
	b.cylinder(Vector3(0.0, -0.02, 0.11), Vector3(0.1, -0.26, 0.62), 0.065, 0.085, 8, shirt)
	return b.build()


func show_weapon(kind: int, visible_now: bool) -> void:
	weapon = kind
	visible = visible_now
	_cutlass.visible = kind == Weapons.Kind.CUTLASS
	_pistol.visible = kind == Weapons.Kind.PISTOL


func attack() -> void:
	if weapon == Weapons.Kind.CUTLASS:
		_swing = 1.0
	else:
		_kick = 1.0


func _process(delta: float) -> void:
	_swing = maxf(0.0, _swing - delta * 3.5)
	_kick = maxf(0.0, _kick - delta * 6.0)
	var arc := sin(_swing * PI)
	rotation = Vector3(-arc * 1.2 + _kick * 0.4, arc * 0.9, -arc * 0.6)
	_flash.visible = _kick > 0.6

class_name Avatar
extends Node3D
## Another player as you see them: a toon pirate with a name tag, drawn where the snapshots say.
## Legs and arms hang from hip and shoulder joints so they swing as the pirate walks; the right
## hand holds the cutlass or pistol and swings it when they attack.

const SHIRTS: Array[Color] = [Color("d63c3c"), Color("3c6fd6"), Color("3cae5a"), Color("9a4fd0")]
const HIP := Vector3(0.14, 0.86, 0.0)
const SHOULDER := Vector3(0.36, 1.42, 0.0)
const NECK := Vector3(0.0, 1.55, 0.0)
## Walk-cycle radians per metre: about one step every 0.9 m.
const STEP_RATE := 3.4

var _model: Node3D
var _label: Label3D
var _bucket: MeshInstance3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _head: Node3D
var _cutlass: MeshInstance3D
var _pistol: MeshInstance3D
var _last := Vector3.ZERO
var _phase := 0.0
var _stride := 0.0
var _swing := 0.0


func _init(player_name: String, index: int) -> void:
	var shirt := SHIRTS[index % SHIRTS.size()]
	_model = Node3D.new()
	add_child(_model)
	_model.add_child(Toon.instance(body_mesh(shirt)))
	# The head nods on a neck joint to show where the player is looking.
	_head = Node3D.new()
	_head.position = NECK
	var face := Toon.instance(head_mesh(shirt, index))
	face.position = -NECK
	_head.add_child(face)
	_model.add_child(_head)
	for side: int in [-1, 1]:
		_legs.append(_joint(Vector3(side * HIP.x, HIP.y, HIP.z), leg_mesh()))
		_arms.append(_joint(Vector3(side * SHOULDER.x, SHOULDER.y, SHOULDER.z), arm_mesh(shirt, side)))
	# The weapons sit in the right hand, pointing forward and a little down.
	_cutlass = _in_hand(WeaponView.cutlass_mesh(), -0.35)
	_pistol = _in_hand(WeaponView.pistol_mesh(), -0.2)
	_label = Label3D.new()
	_label.text = player_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 10
	# The same size on screen near or far, so a crewmate beside you is not hidden behind it.
	_label.fixed_size = true
	_label.pixel_size = 0.001
	_label.position.y = 2.3
	_label.no_depth_test = false
	add_child(_label)
	var b := MeshBuilder.new()
	b.cylinder(Vector3(0, 0, 0), Vector3(0, 0.32, 0), 0.15, 0.2, 10, Color("8a5a32"))
	b.cylinder(Vector3(0, 0.27, 0), Vector3(0, 0.29, 0), 0.19, 0.19, 10, Color("4fb6f5"))
	_bucket = Toon.instance(b.build())
	_bucket.position = Vector3(-0.09, -0.8, -0.1)
	_bucket.visible = false
	_arms[0].add_child(_bucket)
	set_weapon(Weapons.Kind.CUTLASS)


func _joint(at: Vector3, mesh: ArrayMesh) -> Node3D:
	var joint := Node3D.new()
	joint.position = at
	joint.add_child(Toon.instance(mesh))
	_model.add_child(joint)
	return joint


func _in_hand(mesh: ArrayMesh, tilt: float) -> MeshInstance3D:
	var held := Toon.instance(mesh)
	held.position = Vector3(0.09, -0.56, -0.08)
	held.rotation.x = tilt
	_arms[1].add_child(held)
	return held


func set_bucket(full: bool) -> void:
	_bucket.visible = full


## Crewmates' names are white; other crews' are red.
func set_hostile(hostile: bool) -> void:
	_label.modulate = Color("ff8a7a") if hostile else Color.WHITE


func set_weapon(kind: int) -> void:
	_cutlass.visible = kind == Weapons.Kind.CUTLASS
	_pistol.visible = kind == Weapons.Kind.PISTOL


## Swings the sword arm up and forward (or raises the pistol) for a moment.
func attack() -> void:
	_swing = 1.0


## Tilt the head up or down with the player's view, a little less than they really look.
func set_pitch(pitch: float) -> void:
	_head.rotation.x = clampf(pitch * 0.6, -0.5, 0.6)


## `pose` is where the feet are and which way the pirate faces, in world space.
func place(pose: Transform3D, delta: float) -> void:
	var moved := (pose.origin - _last).length() / maxf(delta, 1e-3)
	_last = pose.origin
	var walking := moved > 0.5 and moved < 20.0
	_stride = move_toward(_stride, 1.0 if walking else 0.0, delta * 5.0)
	if walking:
		_phase += delta * moved * STEP_RATE
	var leg := sin(_phase) * 0.6 * _stride
	_legs[0].rotation.x = leg
	_legs[1].rotation.x = -leg
	_arms[0].rotation.x = -leg * 0.7
	_swing = maxf(0.0, _swing - delta * 3.0)
	_arms[1].rotation.x = leg * 0.7 + sin(_swing * PI) * 1.9
	_model.position.y = absf(sin(_phase)) * 0.06 * _stride
	global_transform = pose


## The outpost merchant: a stout figure in a green coat and apron with a wide hat.
static func merchant_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	var skin := Color("e8b48a")
	var coat := Color("2f7a4f")
	var dark := Color("2a2430")
	for side: int in [-1, 1]:
		b.box(Vector3(side * 0.16, 0.08, -0.04), Vector3(0.11, 0.08, 0.15), dark)
		b.cylinder(Vector3(side * 0.15, 0.1, 0), Vector3(side * 0.15, 0.8, 0), 0.13, 0.15, 8, Color("5b4636"))
		b.cylinder(Vector3(side * 0.42, 1.38, 0), Vector3(side * 0.5, 0.95, -0.12), 0.11, 0.09, 8, coat)
		b.ellipsoid(Vector3(side * 0.5, 0.9, -0.15), 0.1, Vector3.ONE, 5, 8, skin)
		b.ellipsoid(Vector3(side * 0.08, 1.7, -0.2), 0.035, Vector3(1, 1.3, 0.6), 4, 6, dark)
	b.cylinder(Vector3(0, 0.78, 0), Vector3(0, 1.45, 0), 0.4, 0.36, 12, coat)
	b.box(Vector3(0, 1.0, -0.36), Vector3(0.26, 0.3, 0.03), Color("f4efe2"))
	b.ellipsoid(Vector3(0, 1.68, 0), 0.23, Vector3(1.0, 1.05, 1.0), 8, 12, skin)
	b.ellipsoid(Vector3(0, 1.58, -0.18), 0.12, Vector3(1.2, 0.6, 0.6), 5, 8, Color("8a8a8a"))
	b.cylinder(Vector3(0, 1.84, 0), Vector3(0, 1.88, 0), 0.5, 0.5, 14, Color("6b4a2c"))
	b.cylinder(Vector3(0, 1.86, 0), Vector3(0, 2.1, 0), 0.24, 0.22, 12, Color("6b4a2c"))
	return b.build()


## The torso and belt. The head, legs and arms are separate (head_mesh, leg_mesh, arm_mesh).
static func body_mesh(shirt: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	for side: int in [-1, 1]:
		# Rounded shoulders hide the joint as the arm swings.
		b.ellipsoid(Vector3(side * 0.33, 1.42, 0), 0.12, Vector3.ONE, 5, 8, shirt)
	b.cylinder(Vector3(0, 0.82, 0), Vector3(0, 1.48, 0), 0.3, 0.35, 12, shirt)
	b.cylinder(Vector3(0, 0.84, 0), Vector3(0, 0.96, 0), 0.315, 0.315, 12, Color("4a2c1c"))
	b.box(Vector3(0, 0.9, -0.31), Vector3(0.07, 0.06, 0.02), Toon.color("gold"))
	# Hips, so the tops of the legs don't show a gap mid-stride.
	b.ellipsoid(Vector3(0, 0.84, 0), 0.3, Vector3(1.0, 0.45, 0.85), 5, 10, Color("3b3550"))
	return b.build()


## The head, in the same coordinates as the body, with one of four looks: tricorn and beard,
## bandana and eyepatch, captain's hat and moustache, or headscarf.
static func head_mesh(shirt: Color, look := 0) -> ArrayMesh:
	var b := MeshBuilder.new()
	var skin := Color("f2c49b")
	var dark := Color("2a2430")
	for side: int in [-1, 1]:
		b.ellipsoid(Vector3(side * 0.08, 1.72, -0.19), 0.035, Vector3(1, 1.3, 0.6), 4, 6, dark)
	b.cylinder(Vector3(0, 1.45, 0), Vector3(0, 1.58, 0), 0.09, 0.09, 8, skin)
	b.ellipsoid(Vector3(0, 1.68, 0), 0.22, Vector3(1.0, 1.1, 1.0), 8, 12, skin)
	b.ellipsoid(Vector3(0, 1.65, -0.22), 0.05, Vector3(1, 1, 1.2), 4, 6, skin)
	match look % 4:
		0:
			# A three-sided brim makes a tricorn, one corner pointing forward; a bushy beard.
			b.cylinder(Vector3(0, 1.82, 0), Vector3(0, 1.87, 0), 0.42, 0.4, 3, dark)
			b.cylinder(Vector3(0, 1.85, 0), Vector3(0, 2.02, 0), 0.21, 0.18, 10, dark)
			b.ellipsoid(Vector3(0, 1.55, -0.12), 0.17, Vector3(1.1, 1.0, 0.8), 5, 8, Color("6b3f22"))
		1:
			# A red bandana with a knot, and an eyepatch.
			b.ellipsoid(Vector3(0, 1.78, 0), 0.235, Vector3(1.0, 0.75, 1.0), 6, 10, Color("c8302a"))
			b.ellipsoid(Vector3(0.05, 1.8, 0.24), 0.07, Vector3(1.2, 1, 1), 4, 6, Color("c8302a"))
			b.ellipsoid(Vector3(0.08, 1.72, -0.2), 0.06, Vector3(1, 1.1, 0.4), 4, 6, dark)
			b.box(Vector3(0, 1.75, -0.02), Vector3(0.23, 0.012, 0.22), dark, Basis(Vector3.BACK, 0.35))
		2:
			# A big captain's bicorne with a gold band, and a curly moustache.
			b.ellipsoid(Vector3(0, 1.93, 0), 0.5, Vector3(1.0, 0.32, 0.45), 6, 12, dark)
			b.box(Vector3(0, 1.88, -0.16), Vector3(0.35, 0.03, 0.02), Toon.color("gold"))
			for side: int in [-1, 1]:
				b.ellipsoid(Vector3(side * 0.07, 1.6, -0.21), 0.06, Vector3(1.4, 0.5, 0.6), 4, 6, Color("3a2416"))
		_:
			# A knotted headscarf in the shirt's colour.
			b.ellipsoid(Vector3(0, 1.79, 0.01), 0.235, Vector3(1.0, 0.8, 1.02), 6, 10, shirt.darkened(0.25))
	return b.build()


## A trouser leg and boot hanging from the hip joint at the origin.
static func leg_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.cylinder(Vector3(0, 0.02, 0), Vector3(0.0, -0.76, 0), 0.13, 0.11, 8, Color("3b3550"))
	b.box(Vector3(0, -0.78, -0.04), Vector3(0.1, 0.08, 0.15), Color("2a2430"))
	return b.build()


## A sleeve and hand hanging from the shoulder joint at the origin.
static func arm_mesh(shirt: Color, side: int) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.cylinder(Vector3.ZERO, Vector3(side * 0.08, -0.5, -0.05), 0.1, 0.08, 8, shirt)
	b.ellipsoid(Vector3(side * 0.09, -0.56, -0.06), 0.09, Vector3.ONE, 5, 8, Color("f2c49b"))
	return b.build()

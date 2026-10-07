class_name SkeletonView
extends Node3D
## A skeleton as players see it: ivory bones, a battered hat and a cutlass. It bobs as it
## walks, swings its sword arm when it attacks, flashes red when hit and topples when it falls.

static var _body: ArrayMesh
static var _arm: ArrayMesh
static var _leg: ArrayMesh

var _model: Node3D
var _arm_pivot: Node3D
var _legs: Array[Node3D] = []
var _material: ShaderMaterial
var _swing := 0.0
var _flash := 0.0
var _fall := 0.0
var _bob := 0.0


func _ready() -> void:
	if _body == null:
		_body = _build_body()
		_arm = _build_arm()
		_leg = _build_leg()
	_material = ShaderMaterial.new()
	_material.shader = load("res://art/shaders/toon.gdshader")
	_material.next_pass = Toon.object_material().next_pass
	_model = Node3D.new()
	add_child(_model)
	_model.add_child(Toon.instance(_body, _material))
	# A green glow in each eye socket.
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.024
		ball.height = 0.048
		ball.radial_segments = 6
		ball.rings = 3
		eye.mesh = ball
		eye.material_override = Toon.glow_material(Color("9cff8a"))
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.position = Vector3(side * 0.065, 1.8, -0.165)
		_model.add_child(eye)
	_arm_pivot = Node3D.new()
	_arm_pivot.position = Vector3(0.3, 1.4, 0)
	_model.add_child(_arm_pivot)
	_arm_pivot.add_child(Toon.instance(_arm, _material))
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.12, 0.95, 0)
		hip.add_child(Toon.instance(_leg, _material))
		_model.add_child(hip)
		_legs.append(hip)


func swing() -> void:
	_swing = 1.0


func hurt() -> void:
	_flash = 1.0


## `pose` is where the feet are, in the world. `walking` and `fallen` come from the snapshot.
func place(pose: Transform3D, walking: bool, fallen: bool, delta: float) -> void:
	global_transform = pose
	if walking:
		_bob += delta * 9.0
	_model.position.y = absf(sin(_bob)) * 0.07 if walking else 0.0
	var stride := sin(_bob) * 0.6 if walking else 0.0
	_legs[0].rotation.x = stride
	_legs[1].rotation.x = -stride
	_swing = maxf(0.0, _swing - delta * 2.5)
	_arm_pivot.rotation.x = -sin(_swing * PI) * 1.9
	_flash = maxf(0.0, _flash - delta * 4.0)
	_material.set_shader_parameter("tint", Color(1.0, 1.0 - _flash * 0.6, 1.0 - _flash * 0.6))
	if fallen:
		_fall = minf(1.0, _fall + delta * 2.5)
	_model.rotation.x = -_fall * PI / 2.0
	_model.position.y -= _fall * 0.3


static func _build_body() -> ArrayMesh:
	var b := MeshBuilder.new()
	var bone := Color("efe8d2")
	var dark := Color("1a1714")
	# Pelvis, spine and ribs (the legs hang from hip joints; see _build_leg).
	b.ellipsoid(Vector3(0, 0.95, 0), 0.17, Vector3(1.2, 0.5, 0.8), 5, 8, bone)
	b.cylinder(Vector3(0, 0.95, 0.04), Vector3(0, 1.55, 0.04), 0.045, 0.045, 6, bone)
	for k in 4:
		var y := 1.18 + k * 0.1
		var w := 0.22 - absf(k - 1.5) * 0.02
		b.ellipsoid(Vector3(0, y, -0.02), w, Vector3(1.0, 0.18, 0.75), 4, 10, bone)
	b.ellipsoid(Vector3(0, 1.55, 0), 0.2, Vector3(1.3, 0.25, 0.7), 4, 8, bone)
	# Left arm hanging; the sword arm is separate.
	b.cylinder(Vector3(-0.3, 1.5, 0), Vector3(-0.34, 1.15, -0.04), 0.04, 0.04, 6, bone)
	b.cylinder(Vector3(-0.34, 1.13, -0.04), Vector3(-0.35, 0.85, -0.1), 0.035, 0.035, 6, bone)
	# Skull with dark eye sockets and a battered hat.
	b.cylinder(Vector3(0, 1.55, 0.02), Vector3(0, 1.65, 0.02), 0.04, 0.04, 6, bone)
	b.ellipsoid(Vector3(0, 1.78, 0), 0.17, Vector3(1.0, 1.05, 1.05), 6, 10, bone)
	b.box(Vector3(0, 1.66, -0.1), Vector3(0.09, 0.04, 0.06), bone)
	for side: int in [-1, 1]:
		b.ellipsoid(Vector3(side * 0.065, 1.8, -0.15), 0.045, Vector3(1, 1.2, 0.5), 4, 6, dark)
	b.cylinder(Vector3(0, 1.9, 0), Vector3(0, 1.93, 0), 0.32, 0.3, 3, Color("2b2622"))
	b.cylinder(Vector3(0, 1.92, 0), Vector3(0, 2.05, 0), 0.16, 0.13, 8, Color("2b2622"))
	return b.build()


## A bony leg hanging from the hip joint at the origin.
static func _build_leg() -> ArrayMesh:
	var b := MeshBuilder.new()
	var bone := Color("efe8d2")
	b.cylinder(Vector3(0, -0.03, 0), Vector3(0.0, -0.45, 0), 0.055, 0.05, 6, bone)
	b.ellipsoid(Vector3(0, -0.46, 0), 0.07, Vector3.ONE, 4, 6, bone)
	b.cylinder(Vector3(0, -0.47, 0), Vector3(0.0, -0.9, 0), 0.05, 0.05, 6, bone)
	b.box(Vector3(0.0, -0.91, -0.07), Vector3(0.06, 0.04, 0.12), bone)
	return b.build()


## The sword arm, hanging from the shoulder at the origin, with a rusty cutlass.
static func _build_arm() -> ArrayMesh:
	var b := MeshBuilder.new()
	var bone := Color("efe8d2")
	b.cylinder(Vector3(0, 0, 0), Vector3(0.04, -0.35, -0.04), 0.04, 0.04, 6, bone)
	b.cylinder(Vector3(0.04, -0.37, -0.04), Vector3(0.05, -0.62, -0.14), 0.035, 0.035, 6, bone)
	var hand := Vector3(0.05, -0.65, -0.16)
	b.box(hand, Vector3(0.04, 0.05, 0.04), bone)
	b.box(hand + Vector3(0, 0, -0.08), Vector3(0.06, 0.02, 0.02), Color("8a6a2a"))
	b.box(hand + Vector3(0, 0, -0.45), Vector3(0.012, 0.045, 0.36), Color("9a948a"))
	return b.build()

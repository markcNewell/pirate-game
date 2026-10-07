class_name Avatar
extends Node3D
## Another player as you see them: a toon pirate with a name tag, drawn where the snapshots say.

const SHIRTS: Array[Color] = [Color("d63c3c"), Color("3c6fd6"), Color("3cae5a"), Color("9a4fd0")]

var _model: MeshInstance3D
var _label: Label3D
var _last := Vector3.ZERO
var _bob := 0.0


func _init(player_name: String, index: int) -> void:
	_model = Toon.instance(pirate_mesh(SHIRTS[index % SHIRTS.size()]))
	add_child(_model)
	_label = Label3D.new()
	_label.text = player_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.005
	_label.position.y = 2.3
	_label.no_depth_test = false
	add_child(_label)


## `pose` is where the feet are and which way the pirate faces, in world space.
func place(pose: Transform3D, delta: float) -> void:
	var moved := (pose.origin - _last).length() / maxf(delta, 1e-3)
	_last = pose.origin
	if moved > 0.5 and moved < 20.0:
		_bob += delta * moved * 2.2
	_model.position.y = absf(sin(_bob)) * 0.08
	global_transform = pose


## A pirate built from code: boots, trousers, shirt, belt, arms, head and a tricorn hat.
static func pirate_mesh(shirt: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	var skin := Color("f2c49b")
	var dark := Color("2a2430")
	var trousers := Color("3b3550")
	for side: int in [-1, 1]:
		b.box(Vector3(side * 0.14, 0.08, -0.04), Vector3(0.1, 0.08, 0.15), dark)
		b.cylinder(Vector3(side * 0.14, 0.1, 0), Vector3(side * 0.13, 0.86, 0), 0.11, 0.13, 8, trousers)
		b.cylinder(Vector3(side * 0.36, 1.42, 0), Vector3(side * 0.44, 0.92, -0.05), 0.1, 0.08, 8, shirt)
		b.ellipsoid(Vector3(side * 0.45, 0.86, -0.06), 0.09, Vector3.ONE, 5, 8, skin)
		b.ellipsoid(Vector3(side * 0.08, 1.72, -0.19), 0.035, Vector3(1, 1.3, 0.6), 4, 6, dark)
	b.cylinder(Vector3(0, 0.82, 0), Vector3(0, 1.48, 0), 0.3, 0.35, 12, shirt)
	b.cylinder(Vector3(0, 0.84, 0), Vector3(0, 0.96, 0), 0.315, 0.315, 12, Color("4a2c1c"))
	b.box(Vector3(0, 0.9, -0.31), Vector3(0.07, 0.06, 0.02), Toon.color("gold"))
	b.ellipsoid(Vector3(0, 1.68, 0), 0.22, Vector3(1.0, 1.1, 1.0), 8, 12, skin)
	b.ellipsoid(Vector3(0, 1.65, -0.22), 0.05, Vector3(1, 1, 1.2), 4, 6, skin)
	# A three-sided brim makes a tricorn, with one corner pointing forward.
	b.cylinder(Vector3(0, 1.82, 0), Vector3(0, 1.87, 0), 0.42, 0.4, 3, dark)
	b.cylinder(Vector3(0, 1.85, 0), Vector3(0, 2.02, 0), 0.21, 0.18, 10, dark)
	return b.build()

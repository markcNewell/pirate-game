class_name Avatar
extends Node3D
## Another player as you see them: a toon pirate with a name tag, drawn where the snapshots say.

const SHIRTS: Array[Color] = [Color("d63c3c"), Color("3c6fd6"), Color("3cae5a"), Color("9a4fd0")]

var _model: MeshInstance3D
var _label: Label3D
var _bucket: MeshInstance3D
var _last := Vector3.ZERO
var _bob := 0.0


func _init(player_name: String, index: int) -> void:
	_model = Toon.instance(pirate_mesh(SHIRTS[index % SHIRTS.size()], index))
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
	var b := MeshBuilder.new()
	b.cylinder(Vector3(0, 0, 0), Vector3(0, 0.32, 0), 0.15, 0.2, 10, Color("8a5a32"))
	b.cylinder(Vector3(0, 0.27, 0), Vector3(0, 0.29, 0), 0.19, 0.19, 10, Color("4fb6f5"))
	_bucket = Toon.instance(b.build())
	_bucket.position = Vector3(0.45, 0.62, -0.1)
	_bucket.visible = false
	_model.add_child(_bucket)


func set_bucket(full: bool) -> void:
	_bucket.visible = full


## Crewmates' names are white; other crews' are red.
func set_hostile(hostile: bool) -> void:
	_label.modulate = Color("ff8a7a") if hostile else Color.WHITE


## `pose` is where the feet are and which way the pirate faces, in world space.
func place(pose: Transform3D, delta: float) -> void:
	var moved := (pose.origin - _last).length() / maxf(delta, 1e-3)
	_last = pose.origin
	if moved > 0.5 and moved < 20.0:
		_bob += delta * moved * 2.2
	_model.position.y = absf(sin(_bob)) * 0.08
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


## A pirate built from code: boots, trousers, shirt, belt, arms and head, plus one of four
## looks: tricorn and beard, bandana and eyepatch, captain's hat and moustache, or headscarf.
static func pirate_mesh(shirt: Color, look := 0) -> ArrayMesh:
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

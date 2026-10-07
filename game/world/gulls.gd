class_name Gulls
extends Node3D
## Seagulls wheeling over the islands: little white birds with flapping grey-tipped wings,
## each circling at its own height, speed and radius.

const PER_ISLAND := 4

var _birds: Array[Dictionary] = []


static var _body: ArrayMesh
static var _wing: ArrayMesh


## One gull (art/blender/wildlife.py): a node with two wing pivots to flap (see flap()).
static func make_bird() -> Dictionary:
	if _body == null:
		_body = Models.part("gull", "gull_body")
		_wing = Models.part("gull", "gull_wing")
	var bird := Node3D.new()
	bird.add_child(Toon.instance(_body))
	var wings: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.scale.x = side
		pivot.position = Vector3(side * 0.08, 0.06, -0.04)
		pivot.add_child(Toon.instance(_wing))
		bird.add_child(pivot)
		wings.append(pivot)
	bird.scale = Vector3.ONE * 1.15
	return {"node": bird, "wings": wings}


static func flap(wings: Array[Node3D], t: float, rate: float, phase: float) -> void:
	var f := sin(t * rate + phase) * 0.6
	for w: Node3D in wings:
		w.rotation.z = f * signf(w.scale.x)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for spec in Islands.LAYOUT:
		for i in PER_ISLAND:
			var made := make_bird()
			add_child(made.node)
			_birds.append({
				"node": made.node, "wings": made.wings, "centre": Vector3(spec.x, 0, spec.z),
				"radius": spec.radius * rng.randf_range(0.6, 1.4) + 10.0,
				"height": rng.randf_range(14.0, 30.0), "speed": rng.randf_range(0.15, 0.3) * (1 if i % 2 == 0 else -1),
				"phase": rng.randf() * TAU, "flap": rng.randf_range(5.0, 8.0),
			})


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for b in _birds:
		var a: float = b.phase + t * b.speed
		var r: float = b.radius
		var pos: Vector3 = b.centre + Vector3(cos(a) * r, b.height + sin(t * 0.7 + b.phase) * 1.5, sin(a) * r)
		# Fly along the circle: the tangent, banking into the turn.
		var tangent := Vector3(-sin(a), 0, cos(a)) * signf(b.speed)
		var node: Node3D = b.node
		node.global_transform = Transform3D(Basis.looking_at(tangent) * Basis(Vector3.BACK, -0.35 * signf(b.speed)), pos)
		flap(b.wings, t, b.flap, b.phase)

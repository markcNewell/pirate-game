class_name Gulls
extends Node3D
## Seagulls wheeling over the islands: little white birds with flapping grey-tipped wings,
## each circling at its own height, speed and radius.

const PER_ISLAND := 4

var _birds: Array[Dictionary] = []


func _ready() -> void:
	var body := MeshBuilder.new()
	body.ellipsoid(Vector3.ZERO, 0.22, Vector3(0.7, 0.6, 1.6), 5, 8, Color("ffffff"))
	body.ellipsoid(Vector3(0, 0.08, -0.33), 0.12, Vector3.ONE, 4, 6, Color("ffffff"))
	body.box(Vector3(0, 0.06, -0.48), Vector3(0.03, 0.025, 0.07), Color("ffb030"))
	var wing := MeshBuilder.new()
	wing.box(Vector3(0.45, 0, 0), Vector3(0.45, 0.02, 0.16), Color("f4f4f4"))
	wing.box(Vector3(0.82, 0, 0.02), Vector3(0.1, 0.021, 0.12), Color("4a4a52"))
	var body_mesh := body.build()
	var wing_mesh := wing.build()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for spec in Islands.LAYOUT:
		for i in PER_ISLAND:
			var bird := Node3D.new()
			bird.add_child(Toon.instance(body_mesh))
			var wings: Array[Node3D] = []
			for side: float in [-1.0, 1.0]:
				var pivot := Node3D.new()
				var w := Toon.instance(wing_mesh)
				pivot.scale.x = side
				pivot.add_child(w)
				bird.add_child(pivot)
				wings.append(pivot)
			bird.scale = Vector3.ONE * 1.4
			add_child(bird)
			_birds.append({
				"node": bird, "wings": wings, "centre": Vector3(spec.x, 0, spec.z),
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
		var flap := sin(t * b.flap + b.phase) * 0.6
		for w: Node3D in b.wings:
			w.rotation.z = flap * signf(w.scale.x)

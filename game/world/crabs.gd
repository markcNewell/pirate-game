class_name Crabs
extends Node3D
## Little red crabs on every beach, scuttling sideways back and forth along the sand with
## their legs going. Only scenery; each player sees their own.

const PER_ISLAND := 5

var _crabs: Array[Dictionary] = []


func _ready() -> void:
	var mesh := crab_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for spec in Islands.LAYOUT:
		if spec.get("outpost", false):
			continue
		for i in PER_ISLAND:
			var crab := Toon.instance(mesh)
			crab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(crab)
			_crabs.append({
				"node": crab, "spec": spec, "angle": rng.randf() * TAU,
				# Walk a short stretch of beach, along the shore, at its own pace.
				"span": rng.randf_range(0.04, 0.1), "speed": rng.randf_range(0.5, 1.1),
				"phase": rng.randf() * TAU, "in": rng.randf_range(2.5, 4.5),
			})


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for c in _crabs:
		var spec: Dictionary = c.spec
		var swing := sin(t * c.speed + c.phase)
		var a: float = c.angle + swing * c.span
		var r: float = spec.radius - c.in
		var x := cos(a) * r
		var z := sin(a) * r
		var node: MeshInstance3D = c.node
		# Crabs walk sideways: face out to sea, so moving round the shore is a sidestep.
		var out := Vector3(cos(a), 0.0, sin(a))
		var jiggle := absf(sin(t * 18.0 + c.phase)) * 0.03 * absf(cos(t * c.speed + c.phase))
		node.global_transform = Transform3D(
			Basis.looking_at(out),
			Vector3(spec.x + x, IslandMesh.ground(spec, x, z) + jiggle, spec.z + z))


## A toon crab facing -z: a round shell, two claws up front and three legs a side.
static func crab_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	var red := Color("e0482e")
	var dark := Color("2a2430")
	b.ellipsoid(Vector3(0, 0.1, 0), 0.16, Vector3(1.3, 0.55, 1.0), 5, 10, red)
	for side: float in [-1.0, 1.0]:
		b.ellipsoid(Vector3(side * 0.07, 0.2, -0.12), 0.025, Vector3.ONE, 3, 5, dark)
		b.cylinder(Vector3(side * 0.12, 0.1, -0.1), Vector3(side * 0.2, 0.14, -0.22), 0.025, 0.025, 4, red)
		b.ellipsoid(Vector3(side * 0.21, 0.16, -0.26), 0.06, Vector3(0.8, 0.7, 1.2), 4, 6, red)
		for k in 3:
			var z := -0.06 + k * 0.07
			b.cylinder(Vector3(side * 0.17, 0.08, z), Vector3(side * 0.3, 0.0, z + 0.02), 0.015, 0.012, 4, red)
	return b.build()

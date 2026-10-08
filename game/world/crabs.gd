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
		if spec.get("outpost", false) or spec.get("story_only", false):
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


## A toon crab facing -z (art/blender/wildlife.py).
static func crab_mesh() -> ArrayMesh:
	return Models.mesh("crab")

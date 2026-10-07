class_name WindLines
extends Node3D
## Cartoon wind: thin white streaks that appear near the camera, drift downwind with a little
## curl at the tail, and fade out. They show which way the wind blows without a glance at the
## HUD. Only scenery; each player sees their own.

const COUNT := 7
const LIFE := 2.6
const SPEED := 9.0
const LENGTH := 6.0

var _lines: Array[Dictionary] = []
var _material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(1, 1, 1, 0.0)
	var mesh := ribbon_mesh()
	for i in COUNT:
		var line := MeshInstance3D.new()
		line.mesh = mesh
		line.material_override = _material.duplicate()
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
		# Stagger the first appearances so they do not all pop in together.
		_lines.append({"node": line, "age": -_rng.randf() * LIFE * 1.5, "from": Vector3.ZERO})


## Call every frame with the camera position and the wind direction (unit, on the sea).
## `gloom` (0-1) fades the lines out at night and in storms, where they would glow oddly.
func follow(camera_pos: Vector3, wind: Vector2, gloom: float, delta: float) -> void:
	var dir := Vector3(wind.x, 0.0, wind.y)
	for item in _lines:
		item.age += delta
		var line: MeshInstance3D = item.node
		if item.age < 0.0:
			line.visible = false
			continue
		if item.age > LIFE:
			item.age = 0.0
			# Somewhere in front of the camera, a little above eye level, upwind of where it shows.
			var cam := get_viewport().get_camera_3d()
			var ahead := Vector3.FORWARD
			if cam:
				ahead = -cam.global_basis.z
			ahead.y = 0.0
			ahead = ahead.normalized() if ahead.length_squared() > 0.01 else Vector3.FORWARD
			var side := ahead.cross(Vector3.UP)
			var at := camera_pos + ahead * _rng.randf_range(8.0, 26.0) + side * _rng.randf_range(-16.0, 16.0)
			at.y = maxf(camera_pos.y + _rng.randf_range(-0.5, 4.0), 1.0)
			item.from = at - dir * SPEED * LIFE * 0.5
		var k: float = item.age / LIFE
		line.visible = true
		var at: Vector3 = item.from + dir * SPEED * item.age
		line.global_transform = Transform3D(Basis.looking_at(-dir) * Basis.from_scale(Vector3(1.0, 1.0, 0.3 + 0.7 * sin(k * PI))), at)
		var m := line.material_override as StandardMaterial3D
		m.albedo_color.a = 0.8 * sin(k * PI) * (1.0 - gloom)


## A thin line along +z, bowing gently, that ends in a small curl.
static func ribbon_mesh() -> ArrayMesh:
	var points: Array[Vector3] = []
	var steps := 14
	for i in steps + 1:
		var t := float(i) / steps
		points.append(Vector3(0.0, sin(t * PI) * 0.35, t * LENGTH))
	# The curl: a small loop at the tail end.
	var tail := points.back() as Vector3
	for i in range(1, 10):
		var a := i / 9.0 * TAU * 0.85
		points.append(tail + Vector3(0.0, (1.0 - cos(a)) * 0.45, sin(a) * 0.45))
	var verts := PackedVector3Array()
	var width := 0.11
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var w0 := width * (0.3 + 0.7 * sin(PI * i / (points.size() - 1)))
		var w1 := width * (0.3 + 0.7 * sin(PI * (i + 1) / (points.size() - 1)))
		# Two strips crossed along the line, so it shows from any side.
		for across: Vector3 in [Vector3.RIGHT, Vector3.UP]:
			verts.append_array([a - across * w0, b - across * w1, b + across * w1])
			verts.append_array([a - across * w0, b + across * w1, a + across * w0])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

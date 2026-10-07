class_name Ocean
extends MeshInstance3D
## The sea surface: a round grid that is dense near the camera and coarse far out, following
## the camera so the sea never ends. The shader moves and colours it (ocean.gdshader).

const RADIUS := 1500.0
const MAX_SHIPS := 4
const SECTORS := 160

var _material: ShaderMaterial


func _ready() -> void:
	mesh = _radial_grid()
	extra_cull_margin = 4.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = load("res://game/ocean/ocean.gdshader")
	var params := Waves.shader_params()
	_material.set_shader_parameter("wave_a", params["wave_a"])
	_material.set_shader_parameter("wave_b", params["wave_b"])
	var islands := PackedVector4Array()
	for island in Islands.LAYOUT:
		islands.append(Vector4(island.x, island.z, island.radius, 0.0))
	_material.set_shader_parameter("islands", islands)
	_material.set_shader_parameter("island_count", islands.size())
	material_override = _material


## Call every frame with the camera position, the shared sea clock and the ships (id -> ShipState).
func follow(camera_pos: Vector3, sea_time: float, ships: Dictionary) -> void:
	global_position = Vector3(camera_pos.x, 0.0, camera_pos.z)
	_material.set_shader_parameter("sea_time", sea_time)
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	for id in ships:
		var s: ShipState = ships[id]
		if a.size() >= MAX_SHIPS:
			break
		a.append(Vector4(s.x, s.z, s.yaw, 0.0))
		b.append(Vector4(s.sink, s.water, 0.0, 0.0))
	var count := a.size()
	while a.size() < MAX_SHIPS:
		a.append(Vector4.ZERO)
		b.append(Vector4.ZERO)
	_material.set_shader_parameter("ships", a)
	_material.set_shader_parameter("ships_b", b)
	_material.set_shader_parameter("ship_count", count)


## Rings 1 m apart near the middle, spreading out by 3.5 % per ring toward the horizon.
func _radial_grid() -> ArrayMesh:
	var radii: Array[float] = [0.0]
	var r := 1.0
	while r < RADIUS:
		radii.append(r)
		r += maxf(1.0, r * 0.035)
	radii.append(RADIUS)

	var verts := PackedVector3Array()
	for radius in radii:
		for s in SECTORS:
			var a := TAU * s / SECTORS
			verts.append(Vector3(cos(a) * radius, 0.0, sin(a) * radius))
	var indices := PackedInt32Array()
	for ring in radii.size() - 1:
		for s in SECTORS:
			var a := ring * SECTORS + s
			var b := ring * SECTORS + (s + 1) % SECTORS
			var c := (ring + 1) * SECTORS + (s + 1) % SECTORS
			var d := (ring + 1) * SECTORS + s
			# Wound so the front face looks up (Godot fronts are clockwise).
			indices.append_array([a, c, b, a, d, c])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

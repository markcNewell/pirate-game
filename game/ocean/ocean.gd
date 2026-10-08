class_name Ocean
extends MeshInstance3D
## The sea surface: a round grid that is dense near the camera and coarse far out, following
## the camera so the sea never ends. The shader moves and colours it (ocean.gdshader).

const RADIUS := 1500.0
const MAX_SHIPS := 8
const SECTORS := 160
## The open sea's colour far out by day (the shader's far_color).
const MID_COLOR := Color(0.137, 0.537, 0.890)

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


## The time of day's tint, how much the sun glints, and the colour far out to the horizon.
## Where the storm is and whether it is on, so the drawn waves grow with it like Waves does.
func set_storm(centre: Vector2, on: bool) -> void:
	_material.set_shader_parameter("storm_centre", centre)
	_material.set_shader_parameter("storm_radius", Storm.RADIUS)
	_material.set_shader_parameter("storm_gain", Storm.WAVE_GAIN)
	_material.set_shader_parameter("storm_on", 1.0 if on else 0.0)
	_material.set_shader_parameter("reef_centre", Reef.CENTRE)
	_material.set_shader_parameter("reef_radius", Reef.STORM_RADIUS)


## The glitter path toward a low light: its direction, colour and strength (0 for none).
func set_light_path(dir: Vector3, color: Color, strength: float) -> void:
	_material.set_shader_parameter("path_dir", dir)
	_material.set_shader_parameter("path_color", color)
	_material.set_shader_parameter("path_strength", strength)


func set_daylight(tint: Color, glints: float, far: Color) -> void:
	_material.set_shader_parameter("daylight", tint)
	_material.set_shader_parameter("sun_glints", glints)
	_material.set_shader_parameter("far_color", far)


## Call every frame with the camera position, the shared sea clock and the ships (id -> ShipState).
## Only the nearest MAX_SHIPS get their hulls cut out of the sea and their wakes drawn.
func follow(camera_pos: Vector3, sea_time: float, ships: Dictionary) -> void:
	global_position = Vector3(camera_pos.x, 0.0, camera_pos.z)
	_material.set_shader_parameter("sea_time", sea_time)
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	var near: Array = ships.values()
	if near.size() > MAX_SHIPS:
		var at := Vector2(camera_pos.x, camera_pos.z)
		near.sort_custom(func(p: ShipState, q: ShipState) -> bool:
			return at.distance_squared_to(Vector2(p.x, p.z)) < at.distance_squared_to(Vector2(q.x, q.z)))
		near.resize(MAX_SHIPS)
	for s: ShipState in near:
		a.append(Vector4(s.x, s.z, s.yaw, 0.0))
		b.append(Vector4(s.sink, s.water, s.speed, 0.0))
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

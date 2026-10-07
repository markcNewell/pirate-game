class_name World
extends Node3D
## Everything around the ship that only players need to see or touch: sky, sun, fog, the sea,
## clouds, and the islands with their collision. The dedicated server never builds this.

const HORIZON := Color("c4e9ff")
const SKY_TOP := Color("2f8ff0")

var ocean: Ocean
var _clouds: Node3D


func _ready() -> void:
	_environment()
	_sun()
	ocean = Ocean.new()
	add_child(ocean)
	for spec in Islands.LAYOUT:
		_island(spec)
	_clouds = Node3D.new()
	add_child(_clouds)
	_make_clouds()


func follow(camera_pos: Vector3, sea_time: float, ship: ShipState) -> void:
	ocean.follow(camera_pos, sea_time, ship)
	# Clouds ride along with the camera so they always sit on the horizon, drifting slowly.
	_clouds.global_position = Vector3(camera_pos.x, 0.0, camera_pos.z)
	_clouds.rotation.y = sea_time * 0.002


func _environment() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://art/shaders/sky.gdshader")
	sky_material.set_shader_parameter("top_color", SKY_TOP)
	sky_material.set_shader_parameter("horizon_color", HORIZON)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9cc8f0")
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HORIZON
	env.fog_density = 1.0
	env.fog_depth_begin = 160.0
	env.fog_depth_end = 950.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.0

	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)


func _sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_color = Color("fff6e5")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


func _island(spec: Dictionary) -> void:
	var built := IslandMesh.build(spec)
	var root := Node3D.new()
	root.position = Vector3(spec.x, 0.0, spec.z)
	root.add_child(Toon.instance(built.ground))
	root.add_child(Toon.instance(built.decor))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(built.faces)
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	root.add_child(body)
	add_child(root)


func _make_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 14:
		var b := MeshBuilder.new()
		var puffs := rng.randi_range(4, 7)
		for p in puffs:
			var offset := Vector3(rng.randf_range(-2.2, 2.2), rng.randf_range(-0.3, 0.7), rng.randf_range(-0.8, 0.8))
			if p == 0:
				offset = Vector3.ZERO
			b.ellipsoid(offset, rng.randf_range(1.0, 1.7), Vector3(1.0, 0.75, 1.0), 8, 12, Toon.color("cloud"))
		var cloud := Toon.instance(b.build(), Toon.sky_object_material())
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / 14.0 + rng.randf_range(-0.2, 0.2)
		var dist := rng.randf_range(650.0, 900.0)
		cloud.position = Vector3(cos(a) * dist, rng.randf_range(110.0, 190.0), sin(a) * dist)
		cloud.scale = Vector3.ONE * rng.randf_range(22.0, 34.0)
		cloud.rotation.y = rng.randf() * TAU
		_clouds.add_child(cloud)

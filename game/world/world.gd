class_name World
extends Node3D
## Everything around the ship that only players need to see or touch: sky, sun, fog, the sea,
## clouds, and the islands with their collision. The dedicated server never builds this.

const HORIZON := Color("c4e9ff")
const SKY_TOP := Color("2f8ff0")

var ocean: Ocean
## The title screen turns the storm off so its sky stays clear.
var storm_enabled := true
var _clouds: Node3D
var _env: Environment
var _sky: ShaderMaterial
var _light: DirectionalLight3D
var _cloud_material: ShaderMaterial
var _daylight_wait := 0.0
var _lamps := -1.0
var _storm: StormView
var _dolphins: Dolphins
var _wind_lines: WindLines
var _whale: Whale
var _merchant: Node3D
var _merchant_rest := 0.0
var _gloom := 0.0
var _camera := Vector2.ZERO
var _inside := 0.0
var _ambient := 0.38
var _light_energy := 0.9


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
	add_child(Gulls.new())
	add_child(Crabs.new())
	_storm = StormView.new()
	add_child(_storm)
	_dolphins = Dolphins.new()
	add_child(_dolphins)
	_wind_lines = WindLines.new()
	add_child(_wind_lines)
	_whale = Whale.new()
	add_child(_whale)


## `time_of_day` pins the light (0-1, see Daylight); below 0 it follows the server clock.
func follow(camera_pos: Vector3, sea_time: float, ships: Dictionary, time_of_day := -1.0) -> void:
	ocean.follow(camera_pos, sea_time, ships)
	_sky.set_shader_parameter("time", sea_time)
	_camera = Vector2(camera_pos.x, camera_pos.z)
	_dolphins.follow(camera_pos, sea_time, ships, get_process_delta_time())
	_wind_lines.follow(camera_pos, Game.wind_dir(sea_time), _gloom, get_process_delta_time())
	_whale.follow(camera_pos, sea_time, get_process_delta_time())
	_animate_merchant(camera_pos, sea_time)
	_inside = Storm.amount(_camera, sea_time) if storm_enabled else 0.0
	_storm.visible = storm_enabled
	# The light changes slowly, so a few updates a second is plenty.
	_daylight_wait -= get_process_delta_time()
	if _daylight_wait <= 0.0:
		_daylight_wait = 0.25
		_apply_daylight(time_of_day if time_of_day >= 0.0 else Daylight.time_of_day(sea_time))
	# Lightning lights up the whole scene for a moment, more the nearer it strikes.
	var flash := _storm.follow(camera_pos, sea_time, _inside) if storm_enabled else 0.0
	_env.ambient_light_energy = _ambient + flash * 1.4
	_light.light_energy = _light_energy * (1.0 + flash * 0.8)
	# Clouds ride along with the camera so they always sit on the horizon, drifting slowly.
	_clouds.global_position = Vector3(camera_pos.x, 0.0, camera_pos.z)
	_clouds.rotation.y = sea_time * 0.002


func _apply_daylight(t: float) -> void:
	var look := Daylight.look(t)
	var s := _inside
	if s > 0.0:
		# Inside the storm everything goes grey and dim, and the fog closes in.
		for key: String in ["top", "horizon", "ambient", "fog", "light", "cloud"]:
			look[key] = _stormy(look[key], s)
		look.sea = (look.sea as Color).lerp(Color(0.36, 0.46, 0.46) * (look.sea as Color).v, s)
		look.energy *= 1.0 - 0.65 * s
		look.glow *= 1.0 - s
	_sky.set_shader_parameter("overcast", s)
	_gloom = maxf(s, look.stars)
	_env.fog_depth_begin = lerpf(160.0, 20.0, s)
	_env.fog_depth_end = lerpf(950.0, 260.0, s)
	_sky.set_shader_parameter("top_color", look.top)
	_sky.set_shader_parameter("horizon_color", look.horizon)
	_sky.set_shader_parameter("glow_color", look.light.lerp(Color("ff5e3a"), 0.35))
	_sky.set_shader_parameter("sun_dir", look.sun)
	_sky.set_shader_parameter("moon_dir", look.moon)
	_sky.set_shader_parameter("glow", look.glow)
	_sky.set_shader_parameter("stars", look.stars)
	_env.ambient_light_color = look.ambient
	_ambient = look.ambient_energy
	_env.fog_light_color = look.fog
	var dir: Vector3 = look.light_dir
	_light.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	_light.light_color = look.light
	_light_energy = look.energy
	var sea: Color = look.sea
	# Far out, the sea takes on some of the horizon's colour: orange at sunset, blue at night.
	var far := Ocean.MID_COLOR * sea
	ocean.set_daylight(sea, clampf(look.energy * 1.2 - 0.1, 0.0, 1.0), far.lerp(look.horizon, 0.3 * look.glow))
	_cloud_material.set_shader_parameter("tint", look.cloud)
	var lamps := snappedf(look.lamps, 0.05)
	if lamps != _lamps:
		_lamps = lamps
		get_tree().call_group(Lantern.GROUP, "set_level", lamps)


## The merchant breathes, and turns to watch you when you come close.
func _animate_merchant(camera_pos: Vector3, t: float) -> void:
	if _merchant == null:
		return
	_merchant.scale = Vector3(1.0, 1.0 + 0.02 * sin(t * 2.2), 1.0)
	var to := camera_pos - _merchant.global_position
	var want := _merchant_rest
	if Vector2(to.x, to.z).length() < 12.0:
		# The model faces -z, so its heading toward a point is atan2(-x, -z).
		want = atan2(-to.x, -to.z)
	_merchant.rotation.y = lerp_angle(_merchant.rotation.y, want, clampf(get_process_delta_time() * 3.0, 0.0, 1.0))


static func _stormy(c: Color, s: float) -> Color:
	var grey := c.get_luminance() * 0.62
	return c.lerp(Color(grey * 0.95, grey, grey * 1.08), s)


func _environment() -> void:
	_sky = ShaderMaterial.new()
	_sky.shader = load("res://art/shaders/sky.gdshader")
	_sky.set_shader_parameter("top_color", SKY_TOP)
	_sky.set_shader_parameter("horizon_color", HORIZON)
	var sky := Sky.new()
	sky.sky_material = _sky
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9cc8f0")
	env.ambient_light_energy = 0.38
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

	_env = env
	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)


func _sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_color = Color("fff6e5")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	# Generous bias: toon shading turns any shadow acne into hard blotches.
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 2.5
	add_child(sun)
	_light = sun


func _island(spec: Dictionary) -> void:
	var built := IslandMesh.build(spec)
	var root := Node3D.new()
	root.position = Vector3(spec.x, 0.0, spec.z)
	root.add_child(Toon.instance(built.ground))
	root.add_child(Toon.instance(built.decor))
	var faces: PackedVector3Array = built.faces
	if spec.outpost:
		var port := Outpost.build()
		root.add_child(Toon.instance(port.mesh))
		var merchant := Toon.instance(port.merchant)
		merchant.position = Outpost.merchant_pos() - root.position
		# Face out to sea: the model faces -z, so turn it toward the hut's outward direction.
		merchant.rotation.y = -PI / 2.0 - Outpost.HUT_ANGLE
		root.add_child(merchant)
		_merchant = merchant
		_merchant_rest = merchant.rotation.y
		faces.append_array(port.faces)
		root.add_child(_chimney_smoke(Outpost.tavern_chimney() - root.position))
		var lighthouse := Lighthouse.new()
		lighthouse.position = Outpost.lighthouse_lamp() - root.position
		root.add_child(lighthouse)
		for lamp in Outpost.lamps():
			var light := Lantern.new(Color("ffd08a"), 1.6, 9.0)
			light.position = lamp - root.position
			root.add_child(light)
	if built.fire != null:
		var fire := Lantern.new(Color("ff9a4a"), 2.2, 14.0, true)
		fire.position = built.fire
		root.add_child(fire)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	root.add_child(body)
	add_child(root)


## A lazy column of smoke from the tavern chimney.
static func _chimney_smoke(at: Vector3) -> CPUParticles3D:
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 4
	var p := CPUParticles3D.new()
	p.mesh = puff
	p.material_override = Toon.clear_material(Color(0.93, 0.92, 0.9, 0.7))
	p.position = at
	p.amount = 14
	p.lifetime = 5.0
	p.direction = Vector3(0.3, 1.0, 0.1)
	p.spread = 12.0
	p.gravity = Vector3(0.25, 0.15, 0.0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.8
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 2.2))
	p.scale_amount_curve = grow
	return p


func _make_clouds() -> void:
	# Its own copy of the material, so the clouds can blush at sunset without tinting anything else.
	_cloud_material = Toon.sky_object_material().duplicate()
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
		var cloud := Toon.instance(b.build(), _cloud_material)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / 14.0 + rng.randf_range(-0.2, 0.2)
		var dist := rng.randf_range(650.0, 900.0)
		cloud.position = Vector3(cos(a) * dist, rng.randf_range(110.0, 190.0), sin(a) * dist)
		cloud.scale = Vector3.ONE * rng.randf_range(22.0, 34.0)
		cloud.rotation.y = rng.randf() * TAU
		_clouds.add_child(cloud)

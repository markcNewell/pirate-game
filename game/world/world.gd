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
var _lighthouse: Lighthouse
var _lamp_glass: Lantern.LitPanes
var _storm: StormView
var _dolphins: Dolphins
var _wind_lines: WindLines
var _whale: Whale
var _merchant: Node3D
var _npcs: Array[Npc] = []
var _isabel: Npc
var _merchant_rest := 0.0
var _gloom := 0.0
var _strike_flash := 0.0
var _last_flash := -1
var _gull_wait := 6.0
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
	ocean.set_storm(Storm.centre(sea_time), Storm.enabled)
	_sky.set_shader_parameter("time", sea_time)
	_camera = Vector2(camera_pos.x, camera_pos.z)
	_dolphins.follow(camera_pos, sea_time, ships, get_process_delta_time())
	_sounds(camera_pos, sea_time, get_process_delta_time())
	_wind_lines.follow(camera_pos, Game.wind_dir(sea_time), _gloom, get_process_delta_time())
	_whale.follow(camera_pos, sea_time, get_process_delta_time())
	_animate_merchant(camera_pos, sea_time)
	for npc in _npcs:
		npc.watch(camera_pos, get_process_delta_time())
	_inside = Storm.amount(_camera, sea_time) if storm_enabled else 0.0
	_storm.visible = storm_enabled and Storm.enabled
	# The light changes slowly, so a few updates a second is plenty.
	_daylight_wait -= get_process_delta_time()
	if _daylight_wait <= 0.0:
		_daylight_wait = 0.25
		_apply_daylight(time_of_day if time_of_day >= 0.0 else Daylight.time_of_day(sea_time))
	# Lightning lights up the whole scene for a moment, more the nearer it strikes.
	var flash := _storm.follow(camera_pos, sea_time, _inside) if _storm.visible else 0.0
	flash = maxf(flash, _strike_flash)
	_strike_flash = maxf(0.0, _strike_flash - get_process_delta_time() * 4.0)
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
	_storm.daylight = clampf((look.energy - 0.6) / 0.25, 0.0, 1.0)
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
	# A path of glitter on the water toward the sun when it is low, or toward the moon.
	var sun: Vector3 = look.sun
	var moon: Vector3 = look.moon
	if sun.y > -0.02 and sun.y < 0.35:
		ocean.set_light_path(sun, Color("ffd08a"), (1.0 - smoothstep(0.15, 0.35, sun.y)) * (1.0 - s))
	elif moon.y > 0.05:
		ocean.set_light_path(moon, Color("e6ecff"), 0.75 * look.stars * (1.0 - s))
	else:
		ocean.set_light_path(sun, Color.WHITE, 0.0)
	var lamps := snappedf(look.lamps, 0.05)
	if lamps != _lamps:
		_lamps = lamps
		get_tree().call_group(Lantern.GROUP, "set_level", lamps)


## Lightning hits a ship's mast at `top`: a bolt down onto it, a bright flash and a crack.
func strike(top: Vector3) -> void:
	_storm.strike(top)
	Audio.play_at("thunder", top, 6.0)
	_strike_flash = clampf(1.0 - Vector2(top.x - _camera.x, top.z - _camera.y).length() / 300.0, 0.3, 1.0)


## The ambience follows where you are: the sea always, wind louder up high and in the storm,
## rain inside it, thunder after each flash (later the further off it is), gulls near islands.
func _sounds(camera_pos: Vector3, sea_time: float, delta: float) -> void:
	var low := 1.0 - clampf(camera_pos.y / 12.0, 0.0, 1.0)
	Audio.set_ambience("sea", lerpf(-16.0, -7.0, low))
	Audio.set_ambience("wind", -24.0 + 4.0 * clampf(camera_pos.y / 15.0, 0.0, 1.0) + 16.0 * _inside)
	Audio.set_ambience("rain", lerpf(-40.0, -6.0, _inside) if _inside > 0.1 else -80.0)
	var f := Storm.flash(sea_time)
	if f.on and f.seed != _last_flash and _storm.visible:
		_last_flash = f.seed
		var off: Vector2 = f.offset
		var bolt: Vector2 = Storm.centre(sea_time) + off
		var far := Vector2(camera_pos.x, camera_pos.z).distance_to(bolt)
		if far < 1200.0:
			var rumble := "thunder" if far < 250.0 else "thunder_far"
			var loud := 4.0 - far / 60.0
			get_tree().create_timer(far / 343.0).timeout.connect(func() -> void: Audio.play(rumble, loud))
	_gull_wait -= delta
	if _gull_wait <= 0.0:
		_gull_wait = randf_range(5.0, 14.0)
		var island := Islands.island_at(camera_pos.x, camera_pos.z, 120.0)
		if island >= 0 and _gloom < 0.5:
			var spec: Dictionary = Islands.LAYOUT[island]
			var a := randf() * TAU
			Audio.play_at("gull", Vector3(spec.x + cos(a) * spec.radius, 20.0, spec.z + sin(a) * spec.radius), -6.0, 1.0, 0.15)


## The merchant (breathing in his idle animation) turns to watch you when you come close.
func _animate_merchant(camera_pos: Vector3, _t: float) -> void:
	if _merchant == null:
		return
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
	_scenery(root, built.props)
	var faces: PackedVector3Array = built.faces
	if spec.outpost:
		var port := Outpost.build()
		for prop: Array in port.props:
			var piece := Toon.instance(Models.part(prop[0], prop[1]))
			piece.transform = prop[2]
			root.add_child(piece)
		var merchant := Models.instance("merchant")
		var player: AnimationPlayer = merchant.find_children("*", "AnimationPlayer", true, false)[0]
		player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		player.play("idle")
		merchant.position = Outpost.merchant_pos() - root.position
		# Face out to sea: the model faces -z, so turn it toward the hut's outward direction.
		merchant.rotation.y = -PI / 2.0 - Outpost.HUT_ANGLE
		root.add_child(merchant)
		_merchant = merchant
		_merchant_rest = merchant.rotation.y
		# The other companies' people: the Lantern Order's mystic on the beach, the Traders' agent on
		# the pier beside the cargo, Moll the keeper at the foot of her lighthouse, and Jonah Salt
		# visiting from his island. All look out to sea.
		for who: String in ["mystic", "agent", "keeper", "castaway", "martha"]:
			var at: Vector3 = {
				"mystic": Outpost.mystic_pos(), "agent": Outpost.agent_pos(), "keeper": Outpost.keeper_pos(),
				"castaway": Outpost.jonah_pos(), "martha": Outpost.martha_pos(),
			}[who]
			var out := Vector3(at.x - spec.x, 0, at.z - spec.z).normalized()
			if who == "agent":
				out = Vector3(0, 0, 1)
			var npc := Npc.new(who, atan2(-out.x, -out.z))
			npc.position = at - root.position
			root.add_child(npc)
			_npcs.append(npc)
		# Isabel waits by the tavern door once you have brought her ashore (see set_isabel).
		_isabel = Npc.new("isabel", PI / 2.0)
		_isabel.position = Outpost.isabel_pos() - root.position
		_isabel.visible = false
		root.add_child(_isabel)
		_npcs.append(_isabel)
		faces.append_array(port.faces)
		root.add_child(_chimney_smoke(Outpost.tavern_chimney() - root.position))
		var panes := Lantern.lit_panes(Models.part("tavern", "tavern_panes"), Color("3a4250"))
		panes.transform = Outpost.tavern_windows()
		root.add_child(panes)
		var glass := Lantern.lit_panes(Models.part("lighthouse", "lighthouse_glass"), Color("fff3b0"))
		glass.transform = Outpost.lighthouse_glass()
		root.add_child(glass)
		_lamp_glass = glass
		# The tavern's music drifts out of its door.
		var tavern := Node3D.new()
		tavern.position = Outpost.tavern_point(Vector3(3.5, 1.5, 0)) - root.position
		root.add_child(tavern)
		Audio.loop_at(tavern, "shanty", -8.0, 45.0)
		var lighthouse := Lighthouse.new()
		lighthouse.position = Outpost.lighthouse_lamp() - root.position
		root.add_child(lighthouse)
		_lighthouse = lighthouse
		for lamp in Outpost.lamps():
			var light := Lantern.new(Color("ffd08a"), 1.6, 9.0)
			light.position = lamp - root.position
			root.add_child(light)
	if spec.get("fort", false):
		var fort := Toon.instance(Models.mesh("fort"))
		fort.position = Vector3(0, Fort.PLATEAU_Y, 0)
		root.add_child(fort)
	if not spec.outpost:
		var flies := Fireflies.new(spec.radius)
		flies.position = Vector3(0, IslandMesh.ground(spec, 0.0, 0.0) + 1.6, 0)
		root.add_child(flies)
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


## The island's palms, rocks, bushes and the rest: one batch (MultiMesh) per model, so a
## hundred tufts of grass cost one draw.
static func _scenery(root: Node3D, props: Array) -> void:
	var groups := {}
	for prop: Array in props:
		if not groups.has(prop[0]):
			groups[prop[0]] = []
		groups[prop[0]].append(prop[1])
	var names := groups.keys()
	names.sort()
	for name: String in names:
		var list: Array = groups[name]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = Models.part(IslandMesh.PROP_FILES[name], name)
		multi.instance_count = list.size()
		for i in list.size():
			multi.set_instance_transform(i, list[i])
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multi
		batch.material_override = Models.material()
		if name.get_slice("_", 0) in ["tuft", "flowers", "starfish", "shell", "pebbles"]:
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(batch)


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
		# A cumulus from art/blender/sky.py (four shapes), scaled up to sky size.
		var cloud := Toon.instance(Models.part("clouds", "cloud_%d" % (i % 4)), _cloud_material)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / 14.0 + rng.randf_range(-0.2, 0.2)
		var dist := rng.randf_range(650.0, 900.0)
		cloud.position = Vector3(cos(a) * dist, rng.randf_range(110.0, 190.0), sin(a) * dist)
		cloud.scale = Vector3.ONE * rng.randf_range(19.0, 29.0)
		cloud.rotation.y = rng.randf() * TAU
		_clouds.add_child(cloud)


## Moll's lamp burning with the Spanish green fire (a LAMP story object alight), or not.
func set_lamp_poisoned(on: bool) -> void:
	if _lighthouse:
		_lighthouse.set_poisoned(on)
	if _lamp_glass:
		_lamp_glass.set_tint(Color("7dff8a") if on else Color.TRANSPARENT)


## Isabel shows at the tavern only for those who have brought her ashore (story chapter b1).
func set_isabel(ashore: bool) -> void:
	if _isabel:
		_isabel.visible = ashore

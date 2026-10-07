class_name StormView
extends Node3D
## What a player sees of the storm: a dark cloud bank over a curtain of rain, visible from
## miles off, rain falling round the camera inside it, and lightning bolts.

const CLOUD_Y := 72.0

var _rain_curtain: MeshInstance3D
var _curtain_material: ShaderMaterial
var _rain: CPUParticles3D
var _bolt: MeshInstance3D
var _bolt_seed := -1


func _ready() -> void:
	var clouds := Toon.instance(_cloud_bank(), _cloud_material())
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clouds)

	var tube := CylinderMesh.new()
	tube.top_radius = Storm.RADIUS * 0.8
	tube.bottom_radius = Storm.RADIUS * 0.85
	tube.height = CLOUD_Y
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 48
	tube.rings = 1
	_curtain_material = ShaderMaterial.new()
	_curtain_material.shader = load("res://art/shaders/rain_curtain.gdshader")
	_curtain_material.set_shader_parameter("height", CLOUD_Y)
	_rain_curtain = MeshInstance3D.new()
	_rain_curtain.mesh = tube
	_rain_curtain.material_override = _curtain_material
	_rain_curtain.position.y = CLOUD_Y * 0.5
	_rain_curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain_curtain)

	_rain = _make_rain()
	add_child(_rain)

	_bolt = MeshInstance3D.new()
	_bolt.material_override = Toon.glow_material(Color("eef4ff"))
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.visible = false
	add_child(_bolt)


## `inside` is how deep in the storm the camera is (Storm.amount); returns how bright any
## lightning is right now as seen from the camera (0 when none).
func follow(camera_pos: Vector3, sea_time: float, inside: float) -> float:
	var c := Storm.centre(sea_time)
	position = Vector3(c.x, 0.0, c.y)
	# From inside, the curtain would be a wall right round you; the falling rain takes over.
	_curtain_material.set_shader_parameter("strength", 1.0 - inside * 0.85)
	_rain.global_position = camera_pos + Vector3(0, 14.0, 0)
	_rain.emitting = inside > 0.25
	var f := Storm.flash(sea_time)
	_bolt.visible = f.on
	if not f.on:
		return 0.0
	if f.seed != _bolt_seed:
		_bolt_seed = f.seed
		_bolt.mesh = _bolt_mesh(f.seed)
		var off: Vector2 = f.offset
		_bolt.position = Vector3(off.x, 0.0, off.y)
	var dist := Vector2(camera_pos.x, camera_pos.z).distance_to(c + f.offset)
	return clampf(1.0 - dist / (Storm.RADIUS * 4.0), 0.0, 1.0)


static func _cloud_bank() -> ArrayMesh:
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 26:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * Storm.RADIUS * 0.85
		var at := Vector3(cos(a) * r, CLOUD_Y + rng.randf_range(0.0, 14.0), sin(a) * r)
		var size := rng.randf_range(26.0, 40.0)
		b.ellipsoid(at, size, Vector3(1.0, 0.55, 1.0), 6, 10, Color("8e96a3").darkened(rng.randf() * 0.25))
	return b.build()


static func _cloud_material() -> ShaderMaterial:
	var m: ShaderMaterial = Toon.sky_object_material().duplicate()
	m.set_shader_parameter("tint", Color(0.62, 0.64, 0.7))
	return m


func _make_rain() -> CPUParticles3D:
	var drop := QuadMesh.new()
	drop.size = Vector2(0.03, 0.7)
	var rain := CPUParticles3D.new()
	rain.mesh = drop
	var wet := Toon.clear_material(Color(0.8, 0.86, 0.95, 0.55))
	wet.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	wet.billboard_keep_scale = true
	rain.material_override = wet
	rain.amount = 900
	rain.lifetime = 1.1
	rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(22.0, 1.0, 22.0)
	rain.direction = Vector3(0.15, -1.0, 0.0)
	rain.spread = 3.0
	rain.gravity = Vector3(0, -9.8, 0)
	rain.initial_velocity_min = 22.0
	rain.initial_velocity_max = 26.0
	rain.emitting = false
	return rain


## A jagged bolt from the cloud base down to the sea, with one fork.
static func _bolt_mesh(seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var b := MeshBuilder.new()
	var white := Color("eef4ff")
	var p := Vector3(0, CLOUD_Y, 0)
	var fork_at := rng.randi_range(3, 6)
	var steps := 11
	for i in steps:
		var next := p + Vector3(rng.randf_range(-5, 5), -CLOUD_Y / steps, rng.randf_range(-5, 5))
		b.cylinder(p, next, 0.35, 0.35, 4, white)
		if i == fork_at:
			var q := p
			for k in 4:
				var qn := q + Vector3(rng.randf_range(2, 6), -CLOUD_Y / steps * 0.8, rng.randf_range(-4, 4))
				b.cylinder(q, qn, 0.2, 0.2, 4, white)
				q = qn
		p = next
	return b.build()

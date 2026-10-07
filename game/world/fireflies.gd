class_name Fireflies
extends CPUParticles3D
## Little glowing specks drifting over an island's grass after dark. They join the lamps group
## so World turns them on and off with the lanterns.


func _init(radius: float) -> void:
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	dot.radial_segments = 6
	dot.rings = 3
	mesh = dot
	material_override = Toon.glow_material(Color("e8ff8a"))
	amount = int(clampf(radius * 1.5, 20.0, 80.0))
	lifetime = 6.0
	preprocess = 6.0
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = Vector3(radius * 0.55, 1.2, radius * 0.55)
	direction = Vector3.UP
	spread = 180.0
	gravity = Vector3.ZERO
	initial_velocity_min = 0.1
	initial_velocity_max = 0.4
	# Each one swells in and fades out over its little life.
	var pulse := Curve.new()
	pulse.add_point(Vector2(0.0, 0.0))
	pulse.add_point(Vector2(0.5, 1.0))
	pulse.add_point(Vector2(1.0, 0.0))
	scale_amount_curve = pulse
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitting = false
	add_to_group(Lantern.GROUP)


func set_level(level: float) -> void:
	emitting = level > 0.6
	visible = level > 0.3

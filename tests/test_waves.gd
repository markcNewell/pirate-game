extends "res://tests/support/case.gd"


func test_height_stays_within_total_amplitude() -> void:
	var limit := Waves.max_height()
	for i in 400:
		var h := Waves.height(i * 3.7 - 600.0, i * -2.3 + 200.0, i * 0.37)
		check(absf(h) <= limit + 1e-5, "height %f beyond %f" % [h, limit])


func test_sea_moves_over_time() -> void:
	var changed := false
	for i in 20:
		if absf(Waves.height(i * 5.0, 3.0, 0.0) - Waves.height(i * 5.0, 3.0, 1.5)) > 0.05:
			changed = true
	check(changed, "the sea should move between t=0 and t=1.5")


func test_normal_matches_finite_difference() -> void:
	var e := 0.01
	for p in [Vector3(0, 0, 0), Vector3(13.2, 0, -40.1), Vector3(-250, 0, 77)]:
		var t := 12.3
		var dx := (Waves.height(p.x + e, p.z, t) - Waves.height(p.x - e, p.z, t)) / (2.0 * e)
		var dz := (Waves.height(p.x, p.z + e, t) - Waves.height(p.x, p.z - e, t)) / (2.0 * e)
		var expected := Vector3(-dx, 1.0, -dz).normalized()
		var n := Waves.normal(p.x, p.z, t)
		check(n.distance_to(expected) < 1e-3, "normal %s vs %s" % [n, expected])


func test_shader_params_carry_every_component() -> void:
	var params := Waves.shader_params()
	var a: PackedVector4Array = params["wave_a"]
	var b: PackedVector4Array = params["wave_b"]
	check_eq(a.size(), Waves.COUNT)
	check_eq(b.size(), Waves.COUNT)
	# Rebuild the height from the shader numbers exactly as ocean.gdshader does.
	var x := 31.0
	var z := -7.5
	var t := 4.2
	var h := 0.0
	for i in Waves.COUNT:
		h += a[i].w * sin(a[i].z * (a[i].x * x + a[i].y * z) - b[i].x * t + b[i].y)
	check_near(h, Waves.height(x, z, t), 1e-5)


func test_wave_speeds_follow_deep_water_dispersion() -> void:
	var params := Waves.shader_params()
	var a: PackedVector4Array = params["wave_a"]
	var b: PackedVector4Array = params["wave_b"]
	for i in Waves.COUNT:
		check_near(b[i].x, sqrt(Waves.GRAVITY * a[i].z), 1e-4)

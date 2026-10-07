extends "res://tests/support/case.gd"


func test_storm_roams_and_returns() -> void:
	var a := Storm.centre(0.0)
	check(a.distance_to(Storm.centre(Storm.LOOP_TIME)) < 0.01, "back where it started after a loop")
	check(a.distance_to(Storm.centre(Storm.LOOP_TIME * 0.5)) > 100.0, "somewhere else half way round")


func test_amount_is_full_inside_and_none_far_away() -> void:
	var c := Storm.centre(100.0)
	check_near(Storm.amount(c, 100.0), 1.0, 1e-6, "full at the centre")
	check_near(Storm.amount(c + Vector2(Storm.RADIUS * 2.0, 0), 100.0), 0.0, 1e-6, "none well outside")
	var mid := Storm.amount(c + Vector2(Storm.RADIUS, 0), 100.0)
	check(mid > 0.0 and mid < 1.0, "fading at the edge")


func test_lightning_is_brief_and_the_same_for_everyone() -> void:
	var on := 0
	for i in 6000:
		var t := i * 0.05
		if Storm.flash(t).on:
			on += 1
		check_eq(Storm.flash(t).on, Storm.flash(t).on, "deterministic")
	# 300 s at 3 s slots, about two in three striking, each 0.18 s long: roughly 12 s lit.
	check(on > 100 and on < 400, "lightning lit %d of 6000 samples" % on)


func test_waves_grow_toward_the_heart() -> void:
	Storm.pin = Vector2(100, 100)
	check_near(Storm.wave_factor(100, 100, 5.0), 1.0 + Storm.WAVE_GAIN, 1e-6, "full gain at the heart")
	check_near(Storm.wave_factor(100 + Storm.RADIUS * 2.0, 100, 5.0), 1.0, 1e-6, "calm well outside")
	var calm := Waves.height(100 + Storm.RADIUS * 3.0, 100, 2.0)
	Storm.enabled = false
	var flat := Waves.height(100, 100, 7.0)
	Storm.enabled = true
	check_near(Waves.height(100, 100, 7.0), flat * (1.0 + Storm.WAVE_GAIN), 1e-5, "waves scaled at the heart")
	check(is_finite(calm), "heights stay finite")
	Storm.pin = Vector2.INF


func test_calm_switch_turns_the_storm_off() -> void:
	Storm.pin = Vector2(0, 0)
	Storm.enabled = false
	check_eq(Storm.amount(Vector2.ZERO, 1.0), 0.0, "no storm when calm")
	check_eq(Storm.wind(Vector2(10, 0), 1.0, Vector2(0, -1)), Vector2(0, -1), "plain wind when calm")
	Storm.enabled = true
	Storm.pin = Vector2.INF


func test_gusts_stay_between_half_and_one_and_a_half() -> void:
	for i in 2000:
		var g := Storm.gust(i * 0.37)
		check(g >= 0.5 - 1e-6 and g <= 1.5 + 1e-6, "gust %.3f in range" % g)


func test_wind_swirls_round_the_heart() -> void:
	Storm.pin = Vector2(0, 0)
	# A crosswind, so only the swirl can turn it north on one side and south on the other.
	var base := Vector2(1, 0)
	var east := Storm.wind(Vector2(20, 0), 3.0, base)
	var west := Storm.wind(Vector2(-20, 0), 3.0, base)
	check(east.normalized().dot(Vector2(0, -1)) > 0.85, "east of the heart it blows north (-z)")
	check(west.normalized().dot(Vector2(0, 1)) > 0.85, "west of the heart it blows south (+z)")
	var far := Storm.wind(Vector2(Storm.RADIUS * 3.0, 0), 3.0, base)
	check(far.is_equal_approx(base), "open sea wind far away")
	Storm.pin = Vector2.INF


func test_pin_holds_the_storm() -> void:
	Storm.pin = Vector2(5, 6)
	check(Storm.centre(1234.0).is_equal_approx(Vector2(5, 6)), "pinned")
	Storm.pin = Vector2.INF

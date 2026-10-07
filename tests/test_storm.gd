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


func test_pin_holds_the_storm() -> void:
	Storm.pin = Vector2(5, 6)
	check(Storm.centre(1234.0).is_equal_approx(Vector2(5, 6)), "pinned")
	Storm.pin = Vector2.INF

extends "res://tests/support/case.gd"


func test_noon_sun_is_high_and_midnight_sun_is_down() -> void:
	check(Daylight.sun_direction(0.5).y > 0.8, "noon sun high")
	check(Daylight.sun_direction(0.0).y < -0.5, "midnight sun below the horizon")
	check(Daylight.sun_direction(0.3).x > 0.0, "morning sun in the east")
	check(Daylight.sun_direction(0.7).x < 0.0, "evening sun in the west")


func test_moon_is_up_when_the_sun_is_down() -> void:
	check(Daylight.moon_direction(0.0).y > 0.5, "moon high at midnight")
	check(Daylight.look(0.0).light_dir.is_equal_approx(Daylight.moon_direction(0.0)), "moonlight at night")
	check(Daylight.look(0.5).light_dir.is_equal_approx(Daylight.sun_direction(0.5)), "sunlight by day")


func test_day_and_night_looks() -> void:
	var noon := Daylight.look(0.5)
	var night := Daylight.look(0.0)
	check(noon.lamps < 0.01 and noon.stars < 0.01, "no lamps or stars at noon")
	check(night.lamps > 0.99 and night.stars > 0.99, "lamps and stars at midnight")
	check(night.energy < noon.energy, "night is dimmer")


func test_light_never_jumps() -> void:
	# Light energy must be near zero where the light swaps from the sun to the moon,
	# and every value must change smoothly through the day.
	var prev := Daylight.look(0.0)
	for i in range(1, 2001):
		var t := i / 2000.0
		var now := Daylight.look(t)
		check(absf(now.energy - prev.energy) < 0.02, "energy smooth at %.4f" % t)
		check(absf(now.lamps - prev.lamps) < 0.03, "lamps smooth at %.4f" % t)
		if not now.light_dir.is_equal_approx(prev.light_dir) and now.light_dir.dot(prev.light_dir) < 0.9:
			check(now.energy < 0.06, "sun-to-moon swap happens in the dark at %.4f" % t)
		prev = now


func test_clock_runs_from_mid_morning() -> void:
	Daylight.override = -1.0
	check(is_equal_approx(Daylight.time_of_day(0.0), Daylight.START), "starts at START")
	check(is_equal_approx(Daylight.time_of_day(Daylight.DAY_LENGTH), Daylight.START), "a day later, same time")
	Daylight.override = 0.75
	check(is_equal_approx(Daylight.time_of_day(123.0), 0.75), "override pins the time")
	Daylight.override = -1.0

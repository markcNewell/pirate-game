extends "res://tests/support/case.gd"


const DT := 1.0 / 60.0


func _sail(state: ShipState, controls: ShipControls, wind: Vector2, seconds: float) -> void:
	for i in int(seconds / DT):
		ShipPhysics.step(state, controls, wind, DT, [])


func _ready_to_sail() -> ShipState:
	var s := ShipState.new()
	s.anchored = false
	s.sail_height = [1.0, 1.0]
	return s


func test_forward_points_down_minus_z_and_turns_left_with_yaw() -> void:
	check(ShipPhysics.forward(0.0).distance_to(Vector2(0, -1)) < 1e-6, "yaw 0 faces -z")
	check(ShipPhysics.forward(PI / 2).distance_to(Vector2(-1, 0)) < 1e-6, "+yaw turns toward -x")


func test_full_sails_downwind_reach_top_speed() -> void:
	var s := _ready_to_sail()
	_sail(s, ShipControls.new(), ShipPhysics.forward(0.0), 90.0)
	check_near(s.speed, ShipPhysics.MAX_SPEED, 0.2)
	check(s.z < -300.0, "the ship should have sailed toward -z, z=%f" % s.z)


func test_upwind_is_slow_but_not_stopped() -> void:
	var down := _ready_to_sail()
	var up := _ready_to_sail()
	_sail(down, ShipControls.new(), ShipPhysics.forward(0.0), 90.0)
	_sail(up, ShipControls.new(), -ShipPhysics.forward(0.0), 90.0)
	check(up.speed > 0.5, "upwind should still creep, got %f" % up.speed)
	check(up.speed < down.speed * 0.6, "upwind %f should be well below downwind %f" % [up.speed, down.speed])


func test_swinging_sails_into_a_side_wind_helps() -> void:
	var side_wind := Vector2(1, 0)  # blowing toward starboard when facing -z
	var straight := _ready_to_sail()
	var trimmed := _ready_to_sail()
	trimmed.sail_angle = [1.0, 1.0]
	check(
		ShipPhysics.sail_efficiency(trimmed.yaw, 1.0, side_wind)
			> ShipPhysics.sail_efficiency(straight.yaw, 0.0, side_wind) + 0.2,
		"turning the sails toward the wind should catch more of it",
	)


func test_anchor_stops_a_moving_ship() -> void:
	var s := _ready_to_sail()
	var wind := ShipPhysics.forward(0.0)
	_sail(s, ShipControls.new(), wind, 60.0)
	var drop := ShipControls.new()
	drop.anchor_drop = true
	ShipPhysics.step(s, drop, wind, DT, [])
	check(s.anchored, "anchor should be down")
	_sail(s, ShipControls.new(), wind, 6.0)
	check_near(s.speed, 0.0, 0.01, "stopped within 6 s")


func test_winching_the_anchor_takes_about_four_seconds() -> void:
	var s := ShipState.new()
	var winch := ShipControls.new()
	winch.anchor_winch = true
	_sail(s, winch, Vector2(0, -1), 3.5)
	check(s.anchored, "still down after 3.5 s")
	_sail(s, winch, Vector2(0, -1), 0.7)
	check(not s.anchored, "up after 4.2 s")


func test_wheel_right_turns_the_bow_toward_starboard() -> void:
	var s := _ready_to_sail()
	_sail(s, ShipControls.new(), ShipPhysics.forward(0.0), 30.0)
	var right := ShipControls.new()
	right.wheel = 1.0
	_sail(s, right, ShipPhysics.forward(0.0), 4.0)
	check(s.rudder > 0.9, "rudder should be hard over")
	check(ShipPhysics.forward(s.yaw).x > 0.1, "bow should swing to +x, forward=%s" % ShipPhysics.forward(s.yaw))


func test_the_wheel_stays_where_it_is_left() -> void:
	var s := ShipState.new()
	var right := ShipControls.new()
	right.wheel = 1.0
	_sail(s, right, Vector2(0, -1), 0.5)
	var held := s.rudder
	_sail(s, ShipControls.new(), Vector2(0, -1), 2.0)
	check_near(s.rudder, held, 1e-6)


func test_a_ship_at_rest_does_not_turn() -> void:
	var s := ShipState.new()
	var right := ShipControls.new()
	right.wheel = 1.0
	_sail(s, right, Vector2(0, -1), 5.0)
	check_near(s.yaw, 0.0, 1e-6)


func test_running_aground_stops_the_ship() -> void:
	var s := _ready_to_sail()
	s.speed = ShipPhysics.MAX_SPEED
	var island := {"x": 0.0, "z": -60.0, "radius": 20.0}
	for i in 900:
		ShipPhysics.step(s, ShipControls.new(), ShipPhysics.forward(0.0), DT, [island])
	var bow := Vector2(s.x, s.z) + ShipPhysics.forward(s.yaw) * ShipPhysics.BOW_PROBE
	check(bow.distance_to(Vector2(0, -60)) >= 19.9, "bow should stay out of the island")
	check(s.speed < 0.5, "speed should drop to nothing, got %f" % s.speed)


func test_pose_rides_the_sea() -> void:
	# A calm sea: the storm starts out on this stretch and would make the waves taller.
	Storm.enabled = false
	for i in 30:
		var t := i * 1.3
		var x := i * 17.0
		var pose := ShipPhysics.pose(x, -40.0, 0.4, t)
		check(absf(pose.origin.y) <= Waves.max_height(), "heave inside the waves")
		check(pose.basis.is_equal_approx(pose.basis.orthonormalized()), "rotation stays rigid")
		var f := ShipPhysics.forward(0.4)
		var bow := Waves.height(x + f.x * 11.0, -40.0 + f.y * 11.0, t)
		var stern := Waves.height(x - f.x * 11.0, -40.0 - f.y * 11.0, t)
		var bow_up := (pose.basis * Vector3(0, 0, -1)).y
		if absf(bow - stern) > 0.05:
			check(signf(bow_up) == signf(bow - stern), "bow tips up when the sea is higher there")
	Storm.enabled = true


func test_state_survives_the_network_round_trip() -> void:
	var s := _ready_to_sail()
	s.x = 12.5
	s.z = -99.0
	s.yaw = 1.2
	s.speed = 3.3
	s.rudder = -0.4
	s.sail_angle = [0.5, -0.25]
	s.anchor_progress = 0.3
	var back := ShipState.from_array(s.to_array())
	check_eq(back.to_array(), s.to_array())


func test_state_blend_takes_the_short_way_round() -> void:
	var a := ShipState.new()
	var b := ShipState.new()
	a.yaw = PI - 0.1
	b.yaw = -PI + 0.1
	var mid := ShipState.blend(a, b, 0.5)
	check_near(absf(mid.yaw), PI, 1e-4, "halfway between 179 and -179 degrees is 180")

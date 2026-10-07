extends "res://tests/support/case.gd"

const DT := 1.0 / 60.0


## Fly a ball until it comes back down to `floor_y`; return where it landed.
func _fly(p0: Vector3, v0: Vector3, floor_y: float) -> Vector3:
	var t := 0.0
	var p := p0
	while t < 20.0:
		t += DT * 0.25
		var next := Ballistics.position(p0, v0, t)
		if next.y < floor_y and Ballistics.velocity(v0, t).y < 0.0:
			return next
		p = next
	return p


func test_flight_follows_gravity() -> void:
	var p := Ballistics.position(Vector3.ZERO, Vector3(10, 20, 0), 2.0)
	check(p.distance_to(Vector3(20, 40 - 0.5 * 9.81 * 4.0, 0)) < 1e-4, "position %s" % p)


func test_elevation_lands_on_target() -> void:
	for d: float in [40.0, 150.0, 300.0]:
		var theta := Ballistics.elevation(d, 0.0)
		var v0 := Vector3(cos(theta), sin(theta), 0) * Ballistics.MUZZLE_SPEED
		var land := _fly(Vector3.ZERO, v0, 0.0)
		check_near(land.x, d, 1.0, "range %f" % d)


func test_out_of_range_has_no_solution() -> void:
	check(is_nan(Ballistics.elevation(Ballistics.max_range() + 50.0, 0.0)), "beyond max range")


func test_solution_leads_a_moving_target() -> void:
	var muzzle := Vector3(0, 4, 0)
	var shooter := Vector3(0, 0, -5)
	var target := Vector3(180, 0.8, -40)
	var target_vel := Vector3(-3, 0, 6)
	var sol := Gunnery.solve(muzzle, shooter, target, target_vel)
	check(sol.ok, "should find a solution")
	var v0: Vector3 = sol.dir * Ballistics.MUZZLE_SPEED + shooter
	var t: float = sol.time
	var ball := Ballistics.position(muzzle, v0, t)
	var where := target + target_vel * t
	check(ball.distance_to(where) < 1.5, "ball %s vs target %s" % [ball, where])


func test_gun_angles_round_trip() -> void:
	var pose := ShipPhysics.pose(10, -20, 0.6, 3.0)
	for gun in ShipShape.cannon_count():
		var dir := pose.basis * ShipShape.barrel_direction(gun, 0.3, 0.2)
		var a := Gunnery.to_gun_angles(pose, gun, dir)
		check(a.ok, "gun %d" % gun)
		check_near(a.yaw, 0.3, 1e-3)
		check_near(a.pitch, 0.2, 1e-3)


func test_guns_cannot_fire_across_the_deck() -> void:
	var pose := ShipPhysics.pose(0, 0, 0.0, 0.0)
	var port_dir := pose.basis * ShipShape.barrel_direction(0, 0.0, 0.1)
	check(not Gunnery.to_gun_angles(pose, 1, port_dir).ok, "a starboard gun cannot aim to port")


func test_hull_hits_below_the_deck_make_reachable_holes() -> void:
	var hit := Vector3(ShipShape.half_width(-1.0, 0.2) - 0.05, 0.2, -1.0)
	check(ShipShape.inside_hull(hit), "point just inside the hull")
	check(ShipShape.makes_hole(hit), "below the deck")
	var hole := ShipShape.hole_point(hit)
	check(ShipShape.is_below_deck(hole), "hole is on the lower deck")
	check(hole.y >= ShipShape.LOWER_Y + 0.3 and hole.y <= ShipShape.LOWER_Y + 1.6, "reachable height")
	check(not ShipShape.makes_hole(Vector3(3.6, 3.6, 0)), "bulwark hits only splinter")


func test_holes_flood_and_sink_the_ship() -> void:
	var s := ShipState.new()
	s.holes = [[1, 2, 0, 0, 0.0], [2, -2, 0, 1, 0.0], [3, 2, 0, -3, 0.0]]
	var seconds := ShipPhysics.SINK_LEVEL / (3 * ShipPhysics.LEAK_RATE)
	for i in int((seconds + 1.0) / DT):
		ShipPhysics.step(s, ShipControls.new(), Vector2(0, -1), DT, [])
	check(s.is_sinking(), "three holes sink her in about %d s" % int(seconds))
	for i in int((ShipPhysics.SINK_TIME + 0.5) / DT):
		ShipPhysics.step(s, ShipControls.new(), Vector2(0, -1), DT, [])
	check_near(s.sink, 1.0, 1e-6, "fully sunk after SINK_TIME")


func test_bailing_keeps_up_with_one_hole() -> void:
	var s := ShipState.new()
	s.holes = [[1, 2, 0, 0, 0.0]]
	var c := ShipControls.new()
	for i in 600:
		c.bail = 0.02 * DT
		ShipPhysics.step(s, c, Vector2(0, -1), DT, [])
	check_near(s.water, 0.0, 1e-6, "a 2 cm/s bail beats one 1.2 cm/s leak")


func test_water_slows_the_ship() -> void:
	var dry := ShipState.new()
	var wet := ShipState.new()
	for s: ShipState in [dry, wet]:
		s.anchored = false
		s.sail_height = [1.0, 1.0]
	wet.water = ShipPhysics.SINK_LEVEL * 0.9
	for i in 3600:
		ShipPhysics.step(dry, ShipControls.new(), Vector2(0, -1), DT, [])
		ShipPhysics.step(wet, ShipControls.new(), Vector2(0, -1), DT, [])
	check(wet.speed < dry.speed * 0.85, "wet %f vs dry %f" % [wet.speed, dry.speed])


func test_sinking_ship_slides_under() -> void:
	var afloat := ShipPhysics.pose(0, 0, 0, 1.0)
	var going := ShipPhysics.pose(0, 0, 0, 1.0, 0.0, 1.0)
	check(going.origin.y < afloat.origin.y - 15.0, "a sunk ship is deep under")


func test_state_round_trip_keeps_holes_and_guns() -> void:
	var s := ShipState.new()
	s.kind = ShipState.Kind.SKELETON
	s.water = 0.7
	s.sink = 0.2
	s.holes = [[4, 2.5, 0.1, -1.0, 0.5], [9, -2.4, -0.2, 3.0, 0.0]]
	s.gun_yaw = [0.1, -0.2, 0.3, 0.0]
	s.gun_pitch = [0.05, 0.1, 0.0, 0.2]
	s.gun_reload = [1.0, 0.0, 2.5, 0.0]
	check_eq(ShipState.from_array(s.to_array()).to_array(), s.to_array())


func test_captain_closes_in_then_turns_broadside() -> void:
	var me := ShipState.new()
	me.anchored = false
	me.x = 0.0
	me.z = 400.0
	var target := ShipState.new()
	var cap := Captain.new(1)
	var wind := Vector2(0, -1)
	var t := 0.0
	var closest := 1e9
	for i in int(240.0 / DT):
		var c := ShipControls.new()
		cap.think(me, target, wind, t, DT, [], c)
		ShipPhysics.step(me, c, wind, DT, [])
		t += DT
		closest = minf(closest, Vector2(me.x, me.z).length())
	var dist := Vector2(me.x, me.z).length()
	check(dist < Captain.APPROACH_RANGE, "it should close the range, now %f" % dist)
	check(closest > 25.0, "without ramming, closest %f" % closest)
	var to := Captain.bearing(Vector2(me.x, me.z), Vector2.ZERO)
	check(absf(absf(angle_difference(me.yaw, to)) - PI / 2.0) < 0.9, "roughly broadside on")


func test_captain_guns_land_near_a_still_target() -> void:
	var me := ShipState.new()
	me.anchored = false
	me.x = 120.0
	me.z = 0.0
	me.yaw = 0.0  # facing -z, so the target at the origin is off the port side
	var target := ShipState.new()
	var cap := Captain.new(2)
	var shots := cap.think(me, target, Vector2(0, -1), 0.0, DT, [], ShipControls.new())
	check(not shots.is_empty(), "port guns should have a shot")
	for shot: Dictionary in shots:
		check(ShipShape.cannon_side(shot.gun) == -1, "only port guns bear")
		var pose := ShipPhysics.pose_of(me, 0.0)
		var muzzle := pose * ShipShape.muzzle(shot.gun, shot.yaw, shot.pitch)
		var dir := pose.basis * ShipShape.barrel_direction(shot.gun, shot.yaw, shot.pitch)
		var land := _fly(muzzle, dir * Ballistics.MUZZLE_SPEED, 0.5)
		check(Vector2(land.x, land.z).length() < 12.0, "landed at %s" % land)

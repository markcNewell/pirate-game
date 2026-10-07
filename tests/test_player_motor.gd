extends "res://tests/support/case.gd"

const DT := 1.0 / 60.0


func _settle(wish: Vector2, yaw: float, run: bool) -> Vector3:
	var v := Vector3.ZERO
	for i in 60:
		v = PlayerMotor.walk(v, wish, yaw, run, true, false, DT)
	return v


func test_forward_walks_toward_minus_z_at_yaw_zero() -> void:
	var v := _settle(Vector2(0, 1), 0.0, false)
	check(v.z < -4.0 and absf(v.x) < 0.01, "velocity %s" % v)


func test_strafe_right_walks_toward_plus_x() -> void:
	var v := _settle(Vector2(1, 0), 0.0, false)
	check(v.x > 4.0 and absf(v.z) < 0.01, "velocity %s" % v)


func test_yaw_turns_the_walking_direction() -> void:
	var v := _settle(Vector2(0, 1), PI / 2.0, false)
	check(v.x < -4.0, "a quarter turn left walks toward -x, got %s" % v)


func test_running_is_faster_than_walking() -> void:
	var walk := _settle(Vector2(0, 1), 0.0, false).length()
	var run := _settle(Vector2(0, 1), 0.0, true).length()
	check_near(walk, PlayerMotor.WALK, 0.01)
	check_near(run, PlayerMotor.RUN, 0.01)


func test_diagonals_are_not_faster() -> void:
	var v := _settle(Vector2(1, 1), 0.0, false)
	check_near(v.length(), PlayerMotor.WALK, 0.01)


func test_jump_only_from_the_floor() -> void:
	var up := PlayerMotor.walk(Vector3.ZERO, Vector2.ZERO, 0.0, false, true, true, DT)
	check_near(up.y, PlayerMotor.JUMP, 1e-4)
	var air := PlayerMotor.walk(Vector3.ZERO, Vector2.ZERO, 0.0, false, false, true, DT)
	check(air.y < 0.0, "no jumping in mid-air")


func test_jump_clears_the_rail_block() -> void:
	var apex := PlayerMotor.JUMP * PlayerMotor.JUMP / (2.0 * PlayerMotor.GRAVITY)
	check(apex > ShipShape.RAIL_BLOCK + 0.05, "jump height %f must clear the rail" % apex)


func test_swimming_floats_up_to_the_surface() -> void:
	var feet := -3.0
	var v := Vector3.ZERO
	for i in 240:
		v = PlayerMotor.swim(v, Vector2.ZERO, 0.0, feet, 0.0, DT)
		feet += v.y * DT
	check_near(feet, -PlayerMotor.FLOAT_DEPTH, 0.05)


func test_deep_water_means_swimming() -> void:
	check(PlayerMotor.is_swimming(-2.0, 0.0), "feet 2 m under")
	check(not PlayerMotor.is_swimming(-0.3, 0.0), "wading at 0.3 m")

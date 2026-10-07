extends "res://tests/support/case.gd"


func test_hull_narrows_to_a_bow_and_a_keel() -> void:
	check(ShipShape.half_width(-12.5, ShipShape.DECK_Y) < 1.0, "pointed bow")
	check_near(ShipShape.half_width(0.0, ShipShape.DECK_Y), ShipShape.BEAM / 2.0, 0.01, "full beam mid-ship")
	check(ShipShape.half_width(12.5, ShipShape.DECK_Y) > 2.5, "square transom")
	check(
		ShipShape.half_width(0.0, ShipShape.KEEL_Y) < ShipShape.half_width(0.0, 0.0),
		"narrower at the keel than at the waterline",
	)


func test_every_station_spawn_and_ladder_top_is_on_board() -> void:
	for st in ShipShape.stations():
		check(ShipShape.is_on_board(st.stand), "%s stand spot" % st.label)
		check_near(st.stand.y, ShipShape.floor_y(st.stand.z, st.stand.x), 0.01, "%s stands on the floor" % st.label)
	for p in ShipShape.SPAWNS:
		check(ShipShape.is_on_board(p), "spawn %s" % p)
	for side in [-1, 1]:
		check(ShipShape.is_on_board(ShipShape.ladder_top(side)), "ladder top %d" % side)
		check(not ShipShape.is_on_board(ShipShape.ladder_bottom(side)), "ladder bottom is in the water")


func test_station_ids_match_their_index() -> void:
	var list := ShipShape.stations()
	for i in list.size():
		check_eq(list[i].id, i)


func test_stairs_climb_from_main_deck_to_quarterdeck() -> void:
	check_near(ShipShape.floor_y(ShipShape.STAIR_BOTTOM_Z, 0.0), ShipShape.DECK_Y, 0.01)
	check_near(ShipShape.floor_y(ShipShape.QUARTER_Z - 0.01, 0.0), ShipShape.QUARTER_Y, 0.01)
	check_near(ShipShape.floor_y(4.0, 3.0), ShipShape.DECK_Y, 0.01, "beside the stairs is main deck")


func test_ladder_gap_cuts_the_rail() -> void:
	check(ShipShape.rail_top(ShipShape.LADDER_Z) < ShipShape.DECK_Y + 0.3, "gap at the ladder")
	check(ShipShape.rail_top(-6.0) > ShipShape.DECK_Y + 0.9, "full rail elsewhere")


func test_deck_collision_is_whole_triangles() -> void:
	var faces := ShipShape.deck_faces()
	check(faces.size() > 300, "deck should have plenty of faces, got %d" % faces.size())
	check_eq(faces.size() % 3, 0)

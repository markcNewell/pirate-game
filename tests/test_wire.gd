extends "res://tests/support/case.gd"
## Lean snapshots (docs/specs/2026-10-08-m24-lean-snapshots.md): packed small, and each player
## sent what is near them.


func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true})
	sim.add_player(1, "Anne", 1, "a")
	return sim


func test_values_come_back_as_they_went() -> void:
	var buf := StreamPeerBuffer.new()
	var values := [0, 1, 127, 128, -1, -2, -200, 40000, -70000, 3000000000, 0.0, 1.5, -2.25, 123456.789, "Bounty: a ghost galleon", "", true, false, null]
	Wire.put_values(buf, values)
	buf.seek(0)
	var back := Wire.get_values(buf)
	check_eq(back.size(), values.size(), "as many as went")
	for i in values.size():
		if typeof(values[i]) == TYPE_FLOAT:
			check(absf(float(back[i]) - float(values[i])) < 0.001, "%s came back as %s" % [values[i], back[i]])
			check_eq(typeof(back[i]), TYPE_FLOAT, "%s is still a float" % values[i])
		else:
			check_eq(back[i], values[i], "%s came back" % [values[i]])
			check_eq(typeof(back[i]), typeof(values[i]), "%s kept its type" % [values[i]])


func test_the_clock_keeps_its_precision() -> void:
	var snap := [123456.789012, [], [], [], [], [], []]
	check_eq(Wire.decode_snapshot(Wire.encode_snapshot(snap))[0], 123456.789012, "hours into a game, to the microsecond")


func test_a_busy_snapshot_comes_back_whole() -> void:
	var sim := _sim()
	sim.story.start(ServerSim.CREW, Story.index_of("b6"), 1)
	sim._new_item(Loot.Kind.CHEST, Loot.State.GROUND, sim.players[1].pos + Vector3(3, 0, 0), 300)
	var snap := sim.snapshot()
	var back := Wire.decode_snapshot(Wire.encode_snapshot(snap))
	check_eq(back.size(), snap.size(), "every section")
	check_eq(back[1].size(), snap[1].size(), "every ship")
	var ship := ShipState.from_array(back[1][0][1])
	var orig := ShipState.from_array(snap[1][0][1])
	check(absf(ship.x - orig.x) < 0.001 and ship.crew == orig.crew and ship.holes.size() == orig.holes.size(), "a ship as it was")
	check_eq(back[5].size(), snap[5].size(), "every skeleton")
	check_eq(Skeleton.from_array(back[5][0]).id, Skeleton.from_array(snap[5][0]).id)
	check_eq(back[6].size(), snap[6].size(), "every story object")
	check_eq(Game._decode_mission(back[4][0].slice(1)).title, Game._decode_mission(snap[4][0].slice(1)).title, "the mission's title")
	check(Wire.encode_snapshot(snap).size() * 3 < var_to_bytes(snap).size(), "and a third of the size or less")


func test_far_things_are_left_out() -> void:
	var sim := _sim()
	var r: Dictionary = sim.players[1]
	var me := sim._world_pos(r)
	var near := sim._new_skeleton(-1, me + Vector3(30, 0, 0))
	var far := sim._new_skeleton(-1, me + Vector3(ServerSim.INTEREST + 100.0, 0, 0))
	sim._new_item(Loot.Kind.CHEST, Loot.State.GROUND, me + Vector3(ServerSim.INTEREST + 100.0, 0, 0), 100)
	var mine := sim.snapshot_for(sim.snapshot(), 1)
	var ids := []
	for e: Array in mine[5]:
		ids.append(int(e[0]))
	check(ids.has(near.id), "the skeleton nearby is sent")
	check(not ids.has(far.id), "the one 600 m off isn't")
	check_eq(mine[3].size(), 0, "nor the chest out there")
	check_eq(mine[1].size(), sim.ships.size(), "every ship is, wherever she is")


func test_slow_parts_only_when_they_change() -> void:
	var sim := _sim()
	sim.story.start(ServerSim.CREW, Story.index_of("a1"), 0)
	var first := sim.snapshot_for(sim.snapshot(), 1)
	check(first[4] != null and first[6] != null, "the first time: missions and story objects")
	var second := sim.snapshot_for(sim.snapshot(), 1)
	check(second[4] == null and second[6] == null, "unchanged: left out")
	var o: StoryObject = sim.story.objects.values()[0]
	o.state = 0
	var third := sim.snapshot_for(sim.snapshot(), 1)
	check(third[6] != null, "a change goes out at once")
	for n in ServerSim.REFRESH:
		third = sim.snapshot_for(sim.snapshot(), 1)
		if third[4] != null:
			break
	check(third[4] != null, "and everything again now and then, in case a packet went astray")


func test_the_client_keeps_what_was_left_out() -> void:
	var game := Game.new()
	var snap := [1.0, [], [], [], [[1, Missions.Kind.TREASURE, 0, "Hoard", -1.0, "", 0, 1, 0]], [], [[7, StoryObject.Kind.FIRE, 0.0, 0.0, 0.0, 0.0, 1, -1]]]
	game.local_id = 5
	game.client_on_snapshot(snap)
	check(game.view_objects.has(7), "the fire arrives")
	game.client_on_snapshot([2.0, [], [], [], null, [], null])
	check(game.view_objects.has(7), "and stays when a snapshot leaves the objects out")
	game.free()

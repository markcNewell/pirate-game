extends "res://tests/support/case.gd"
## Shipyards and the first playtest's fixes (docs/specs/2026-10-12-m26-shipyards.md).

const DT := 1.0 / 60.0


func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true})
	sim.add_player(1, "Anne", 1, "a")
	return sim


# --- buckets ---

func test_one_bailer_keeps_ahead_of_two_holes() -> void:
	var per_second := ServerSim.BUCKET / ServerSim.BAIL_TRIP
	check(per_second > 2.0 * ShipPhysics.LEAK_RATE,
		"a bucket every %.0f s takes %.3f m/s against two holes' %.3f" % [ServerSim.BAIL_TRIP, per_second, 2.0 * ShipPhysics.LEAK_RATE])


func test_a_bucket_thrown_takes_out_its_water() -> void:
	var sim := _sim()
	var ship: ShipState = sim.ships[1]
	ship.water = 1.0
	var r: Dictionary = sim.players[1]
	r.pos = ShipShape.HATCH_BOTTOM
	sim.request(1, "scoop", 0, [])
	check(r.bucket, "filled below")
	r.pos = ShipShape.SPAWNS[0]
	sim.request(1, "throw", 0, [])
	sim.tick(DT)
	check_near(ship.water, 1.0 - ServerSim.BUCKET, 0.01, "one bucket's worth gone")

extends "res://tests/support/case.gd"
## Shipyards and the first playtest's fixes (docs/specs/2026-10-12-m26-shipyards.md).

const DT := 1.0 / 60.0


func _sim() -> ServerSim:
	var sim := ServerSim.new({"no-ai": true, "calm": true})
	sim.add_player(1, "Anne", 1, "a")
	return sim


# --- buckets ---

func test_one_bailer_keeps_ahead_of_two_holes() -> void:
	for hull: Hull in [Hull.galleon(), Hull.sloop()]:
		var trip := maxf(Hull.BAIL_TRIP if hull.has_hold else 0.0, hull.bail_every)
		var per_second := hull.bucket / trip
		check(per_second > 1.5 * hull.leak_rate,
			"%s: a bucket every %.1f s takes %.3f m/s against a hole's %.3f" % [hull.name, trip, per_second, hull.leak_rate])


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
	check_near(ship.water, 1.0 - Hull.galleon().bucket, 0.01, "one bucket's worth gone")

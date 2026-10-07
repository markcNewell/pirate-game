class_name ShipControls
extends RefCounted
## What the crew is doing to the ship this tick, gathered by the server from the stations.

## Wheel input, -1 (turn to port) .. 1 (turn to starboard). The wheel stays where it is left.
var wheel := 0.0
## Per mast: -1 lower .. 1 raise. Positive lets the sail down (more sail).
var sail_raise: Array[float] = [0.0, 0.0]
## Per mast: -1 swing to port .. 1 swing to starboard.
var sail_turn: Array[float] = [0.0, 0.0]
## One-off: let the anchor go.
var anchor_drop := false
## Held: winch the anchor up.
var anchor_winch := false

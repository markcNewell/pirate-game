class_name ShipView
extends Node3D
## The ship as players see it: the model riding the waves, sails, wheel, capstan and flag
## following the ship's state, and a solid hull swimmers bump into.

const FURLED := 0.06

var _rigs: Array[Node3D] = []
var _sails: Array[Array] = []
var _wheel: Node3D
var _capstan: Node3D
var _flag: Node3D
var _last_anchor_progress := 0.0


func _ready() -> void:
	add_child(Toon.instance(ShipMesh.hull()))
	for m in ShipShape.MAST_Z.size():
		_build_rig(m)

	_wheel = Toon.instance(ShipMesh.wheel())
	_wheel.position = ShipShape.WHEEL + Vector3(0, 1.05, 0.25)
	add_child(_wheel)

	_capstan = Toon.instance(ShipMesh.capstan())
	_capstan.position = ShipShape.CAPSTAN
	add_child(_capstan)

	_flag = Node3D.new()
	_flag.position = Vector3(0, ShipShape.DECK_Y + ShipShape.MAST_HEIGHT[1] + 0.3, ShipShape.MAST_Z[1])
	var cloth := Toon.instance(ShipMesh.flag())
	cloth.position = Vector3(0, -0.9, 0)
	_flag.add_child(cloth)
	add_child(_flag)

	var lamp := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.36, 0.3)
	lamp.mesh = box
	lamp.material_override = Toon.glow_material()
	lamp.position = Vector3(0, ShipShape.QUARTER_Y + ShipShape.RAIL_HEIGHT + 1.32, ShipShape.STERN_Z + 0.2)
	add_child(lamp)

	_add_hull_blocker()


func _build_rig(mast: int) -> void:
	var rig := Node3D.new()
	rig.position = Vector3(0, ShipShape.DECK_Y, ShipShape.MAST_Z[mast])
	add_child(rig)
	_rigs.append(rig)
	var sails: Array[MeshInstance3D] = []
	for spec in ShipMesh.sails_for(mast):
		var top: float = spec[0]
		var yard := Toon.instance(ShipMesh.yard(spec[2]))
		yard.position = Vector3(0, top, -ShipShape.MAST_RADIUS - 0.2)
		rig.add_child(yard)
		var sail := Toon.instance(ShipMesh.sail(spec[2], spec[1]))
		sail.position = Vector3(0, top - 0.1, -ShipShape.MAST_RADIUS - 0.3)
		rig.add_child(sail)
		sails.append(sail)
	_sails.append(sails)


## Swimmers collide with this box; it rides along with the ship. On the world layer.
func _add_hull_blocker() -> void:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ShipShape.BEAM - 0.4, ShipShape.DECK_Y - ShipShape.KEEL_Y + 1.0, 2.0 * ShipShape.HALF_LENGTH - 2.0)
	shape.shape = box
	shape.position = Vector3(0, (ShipShape.DECK_Y + ShipShape.KEEL_Y + 1.0) * 0.5, 0.5)
	body.add_child(shape)
	add_child(body)


## Draw the ship for this frame. `pose` comes from ShipPhysics.pose at the render time.
func apply(state: ShipState, pose: Transform3D, wind_dir: Vector2, delta: float) -> void:
	global_transform = pose
	for m in _rigs.size():
		_rigs[m].rotation.y = -state.sail_angle[m] * ShipPhysics.MAX_SAIL_ANGLE
		for sail: MeshInstance3D in _sails[m]:
			sail.scale.y = lerpf(FURLED, 1.0, state.sail_height[m])
	_wheel.rotation.z = -state.rudder * 2.6
	if state.anchored and state.anchor_progress > _last_anchor_progress:
		_capstan.rotation.y += delta * 2.5
	_last_anchor_progress = state.anchor_progress

	# Fly the flag downwind, in the ship's own frame.
	var local := pose.basis.inverse() * Vector3(wind_dir.x, 0.0, wind_dir.y)
	var target := atan2(-local.z, local.x)
	_flag.rotation.y = lerp_angle(_flag.rotation.y, target, clampf(delta * 3.0, 0.0, 1.0))


## Ship frame -> world, for things standing on board.
func to_world(local: Transform3D) -> Transform3D:
	return global_transform * local

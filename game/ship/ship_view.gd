class_name ShipView
extends Node3D
## A ship as players see it: the model riding the waves, sails, wheel, capstan, flag and
## cannons following the ship's state, holes and flood water on the lower deck, and a solid
## hull swimmers bump into. `kind` picks the crew's colours or the skeleton ship's.

const FURLED := 0.06
const RECOIL := 0.5

var kind := ShipState.Kind.CREW
## Crew number (1-4) for the sail colours; 0 for skeleton ships.
var crew := 1

var _rigs: Array[Node3D] = []
var _sails: Array[Array] = []
var _wheel: Node3D
var _capstan: Node3D
var _flag: Node3D
var _barrels: Array[Node3D] = []
var _recoil: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _aim_override := {}
var _flood: MeshInstance3D
var _holes := {}  # hole id -> Node3D
var _hole_mesh: ArrayMesh
var _patch_mesh: ArrayMesh
var _last_anchor_progress := 0.0


func _ready() -> void:
	ShipMesh.use_palette(Toon.SKELETON if kind == ShipState.Kind.SKELETON else Toon.crew_palette(crew))
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

	var barrel_mesh := ShipMesh.barrel()
	for gun in ShipShape.cannon_count():
		var barrel := Toon.instance(barrel_mesh)
		add_child(barrel)
		_barrels.append(barrel)
		_place_barrel(gun, 0.0, 0.0)

	var glow := Toon.glow_material(ShipMesh._c("lantern"))
	_lamp(Vector3(0, ShipShape.QUARTER_Y + ShipShape.RAIL_HEIGHT + 1.32, ShipShape.STERN_Z + 0.2), glow)
	for z: float in [-7.0, -1.0, 3.5]:
		_lamp(Vector3(0, ShipShape.DECK_Y - 0.55, z), glow)
	if kind == ShipState.Kind.CREW:
		for z: float in [-6.5, -1.0]:
			var light := OmniLight3D.new()
			light.position = Vector3(0, ShipShape.DECK_Y - 0.8, z)
			light.light_color = Color("ffe2b0")
			light.light_energy = 0.55
			light.omni_range = 6.0
			add_child(light)

	_flood = MeshInstance3D.new()
	_flood.mesh = ShipMesh.flood_mesh()
	_flood.material_override = Toon.clear_material(Color(0.137, 0.537, 0.890, 0.82))
	_flood.visible = false
	add_child(_flood)

	var hb := MeshBuilder.new()
	hb.cylinder(Vector3(-0.04, 0, 0), Vector3(0.04, 0, 0), 0.34, 0.3, 7, Color("161210"))
	_hole_mesh = hb.build()
	var pb := MeshBuilder.new()
	pb.box(Vector3(0, 0.12, 0), Vector3(0.05, 0.1, 0.42), ShipMesh._c("deck"))
	pb.box(Vector3(0, -0.12, 0), Vector3(0.05, 0.1, 0.42), ShipMesh._c("deck").darkened(0.1))
	_patch_mesh = pb.build()
	ShipMesh.use_palette({})

	_add_hull_blocker()


func _lamp(pos: Vector3, glow: Material) -> void:
	var lamp := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.28, 0.34, 0.28)
	lamp.mesh = box
	lamp.material_override = glow
	lamp.position = pos
	add_child(lamp)


func _build_rig(mast: int) -> void:
	var rig := Node3D.new()
	rig.position = Vector3(0, ShipShape.DECK_Y, ShipShape.MAST_Z[mast])
	add_child(rig)
	_rigs.append(rig)
	var sails: Array[MeshInstance3D] = []
	var specs := ShipMesh.sails_for(mast)
	for k in specs.size():
		var spec: Array = specs[k]
		var top: float = spec[0]
		var yard := Toon.instance(ShipMesh.yard(spec[2]))
		yard.position = Vector3(0, top, -ShipShape.MAST_RADIUS - 0.2)
		rig.add_child(yard)
		var sail := Toon.instance(ShipMesh.sail(spec[2], spec[1]))
		sail.position = Vector3(0, top - 0.1, -ShipShape.MAST_RADIUS - 0.3)
		rig.add_child(sail)
		sails.append(sail)
		if mast == 1 and k == 0:
			# The crew's emblem on the main course, furling with the sail.
			var badge := Toon.instance(ShipMesh.emblem())
			badge.position = Vector3(0, -spec[1] * 0.5, 0)
			sail.add_child(badge)
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


## Draw the ship for this frame. `pose` comes from ShipPhysics.pose_of at the render time.
func apply(state: ShipState, pose: Transform3D, wind_dir: Vector2, delta: float) -> void:
	global_transform = pose
	visible = state.sink < 1.0
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

	for gun in _barrels.size():
		_recoil[gun] = maxf(0.0, _recoil[gun] - delta * 0.8)
		var aim: Vector2 = _aim_override.get(gun, Vector2(state.gun_yaw[gun], state.gun_pitch[gun]))
		_place_barrel(gun, aim.x, aim.y)
	_aim_override.clear()

	_flood.visible = state.water > 0.02
	_flood.position.y = ShipShape.LOWER_Y + state.water
	_update_holes(state.holes)


## Point one of our own cannons where the local gunner is looking (this frame only).
func aim_gun(gun: int, aim: Vector2) -> void:
	_aim_override[gun] = aim
	_place_barrel(gun, aim.x, aim.y)


func recoil(gun: int) -> void:
	if gun >= 0 and gun < _recoil.size():
		_recoil[gun] = RECOIL


func _place_barrel(gun: int, yaw: float, pitch: float) -> void:
	var dir := ShipShape.barrel_direction(gun, yaw, pitch)
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK
	var basis := Basis.looking_at(dir, up)
	_barrels[gun].transform = Transform3D(basis, ShipShape.cannon_pivot_of(gun) - dir * _recoil[gun])


func _update_holes(holes: Array) -> void:
	var seen := {}
	for h: Array in holes:
		var id := int(h[0])
		seen[id] = true
		var node: Node3D = _holes.get(id)
		if node == null:
			node = _make_hole(Vector3(h[1], h[2], h[3]))
			_holes[id] = node
		var patch: Node3D = node.get_node("Patch")
		patch.visible = float(h[4]) > 0.02
		patch.scale = Vector3(1.0, clampf(float(h[4]), 0.05, 1.0), 1.0)
	for id in _holes.keys():
		if not seen.has(id):
			_holes[id].queue_free()
			_holes.erase(id)


## A splintered hole on the inside wall, its twin on the outside of the hull, a jet of water
## coming in, and a plank patch that grows as someone fixes it.
func _make_hole(at: Vector3) -> Node3D:
	var side := signf(at.x)
	var node := Node3D.new()
	node.position = at
	add_child(node)
	node.add_child(Toon.instance(_hole_mesh))
	var outside := Toon.instance(_hole_mesh)
	outside.position = Vector3(side * (ShipShape.half_width(at.z, at.y) - absf(at.x) + 0.02), 0, 0)
	node.add_child(outside)
	var patch := Toon.instance(_patch_mesh)
	patch.name = "Patch"
	patch.position = Vector3(-side * 0.06, 0, 0)
	node.add_child(patch)

	var spray := CPUParticles3D.new()
	spray.amount = 40
	spray.lifetime = 0.7
	spray.direction = Vector3(-side, 0.1, 0)
	spray.spread = 18.0
	spray.initial_velocity_min = 2.5
	spray.initial_velocity_max = 4.0
	spray.gravity = Vector3(0, -9.8, 0)
	spray.scale_amount_min = 0.12
	spray.scale_amount_max = 0.2
	var drop := SphereMesh.new()
	drop.radius = 0.5
	drop.height = 1.0
	drop.radial_segments = 6
	drop.rings = 3
	spray.mesh = drop
	spray.material_override = Toon.clear_material(Color(0.55, 0.8, 1.0, 0.9))
	spray.local_coords = true
	node.add_child(spray)
	return node

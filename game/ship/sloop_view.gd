class_name SloopView
extends ShipView
## The sloop as players see it (docs/specs/2026-10-12-m26-shipyards.md): her model in the
## crew's colours, the one sail swinging and furling on its yard, the wheel and the anchor
## winch, holes by the rail and a hull swimmers bump into. No guns, no hold, no flood water.

const WHEEL_SCALE := 0.75
const WINCH_SCALE := 0.6


func _init() -> void:
	hull_type = Hull.Type.SLOOP


func _ready() -> void:
	var palette: Dictionary = Shipwright.palette(crew, looks)
	ShipMesh.use_palette(palette)
	_paint = Models.palette_recolor(palette)
	add_child(Toon.instance(Models.mesh("sloop_hull", _paint)))

	var rig := Node3D.new()
	rig.position = Vector3(0, SloopHull.DECK_Y, SloopHull.MAST_Z)
	add_child(rig)
	_rigs.append(rig)
	var top := 7.4  # sloopshape.SAIL_TOP: the yard's height above the deck
	var yard := Toon.instance(Models.part("sloop_parts", "yard", _paint))
	yard.position = Vector3(0, top, -SloopHull.MAST_RADIUS - 0.15)
	rig.add_child(yard)
	var bundle := Toon.instance(Models.part("sloop_parts", "furl", _paint))
	bundle.position = yard.position
	bundle.layers = Lantern.UNLIT_LAYER
	rig.add_child(bundle)
	var sail := Toon.instance(Models.part("sloop_parts", "sail", _paint))
	sail.position = Vector3(0, top - 0.1, -SloopHull.MAST_RADIUS - 0.25)
	sail.layers = Lantern.UNLIT_LAYER
	rig.add_child(sail)
	_sails.append([sail])
	_furls.append([bundle])

	_wheel = Toon.instance(_part("wheel"))
	_wheel.scale = Vector3.ONE * WHEEL_SCALE
	_wheel.position = SloopHull.WHEEL + Vector3(0, 0.95, 0.14)
	add_child(_wheel)
	_capstan = Toon.instance(_part("capstan"))
	_capstan.scale = Vector3.ONE * WINCH_SCALE
	_capstan.position = SloopHull.CAPSTAN + Vector3(0, 0.16, 0)
	add_child(_capstan)
	_winch = Audio.loop_at(_capstan, "winch", -80.0, 25.0)

	_flag = Node3D.new()
	_flag.position = Vector3(0, SloopHull.DECK_Y + SloopHull.MAST_HEIGHT + 0.2, SloopHull.MAST_Z)
	var cloth := Toon.instance(_part("flag"), Toon.cloth_material())
	cloth.scale = Vector3.ONE * 0.6
	cloth.position = Vector3(0, -0.55, 0)
	_flag.add_child(cloth)
	add_child(_flag)

	# A lantern on the stern rail.
	var lamp := Vector3(0, SloopHull.DECK_Y + SloopHull.RAIL_HEIGHT + 0.3, SloopHull.STERN_Z - 0.1)
	_lamp(lamp, Toon.glow_material(ShipMesh._c("lantern")))
	var lantern := Lantern.new(ShipMesh._c("lantern").lerp(Color.WHITE, 0.2), 0.8, 7.0)
	lantern.position = lamp
	add_child(lantern)

	for side: float in [-1.0, 1.0]:
		var spray := _make_spray(side)
		spray.position = Vector3(side * (Hull.sloop().half_width(-4.3, 0.0) + 0.1), 0.2, -4.3)
		add_child(spray)
		_spray.append(spray)

	_hole_mesh = _part("hole")
	_patch_mesh = _part("patch")
	ShipMesh.use_palette({})
	_add_hull_blocker()


func _add_hull_blocker() -> void:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SloopHull.BEAM - 0.4, SloopHull.DECK_Y - SloopHull.KEEL_Y + 0.6, 2.0 * SloopHull.HALF_LENGTH - 1.2)
	shape.shape = box
	shape.position = Vector3(0, (SloopHull.DECK_Y + SloopHull.KEEL_Y + 0.6) * 0.5, 0.3)
	body.add_child(shape)
	add_child(body)


func apply(state: ShipState, pose: Transform3D, wind_dir: Vector2, delta: float) -> void:
	global_transform = pose
	_gust_clock += delta
	visible = state.sink < 1.0
	_rigs[0].rotation.y = -state.sail_angle[0] * ShipPhysics.MAX_SAIL_ANGLE
	var h: float = state.sail_height[0]
	var sail: MeshInstance3D = _sails[0][0]
	sail.scale.y = lerpf(FURLED, 1.0, h)
	sail.visible = h > 0.06
	sail.scale.z = 1.0 + 0.07 * sin(_gust_clock * 1.3)
	var bundle: MeshInstance3D = _furls[0][0]
	var roll := clampf(1.0 - h / 0.4, 0.0, 1.0)
	bundle.visible = roll > 0.02
	bundle.scale = Vector3(1.0, maxf(roll, 0.05), maxf(roll, 0.05))
	_wheel.rotation.z = -state.rudder * 2.6
	_ship_sounds(state, delta)
	if state.anchored and state.anchor_progress > _last_anchor_progress:
		_capstan.rotation.y += delta * 2.5
	_last_anchor_progress = state.anchor_progress
	var local := pose.basis.inverse() * Vector3(wind_dir.x, 0.0, wind_dir.y)
	_flag.rotation.y = lerp_angle(_flag.rotation.y, atan2(-local.z, local.x), clampf(delta * 3.0, 0.0, 1.0))
	var game := get_parent() as Game
	var storm := Storm.amount(Vector2(state.x, state.z), game.render_time) if game else 0.0
	for spray in _spray:
		spray.emitting = (state.speed > 3.0 or storm > 0.3) and state.sink <= 0.0
		spray.initial_velocity_min = 1.5 + state.speed * 0.3 + storm * 3.0
		spray.initial_velocity_max = 2.5 + state.speed * 0.5 + storm * 4.0
	_update_holes(state.holes)


func aim_gun(_gun: int, _aim: Vector2) -> void:
	pass


func recoil(_gun: int) -> void:
	pass

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
## ShipState.flag: 0 the pirate dead's wreck, 1 a Spanish galleon (black sails, the raven), 2 the
## Cuervo Negro, 3 a ghost galleon, 4 Isabel's La Golondrina, 5 the prison hulk (no yards or sails).
var flag := 0
## A crew's ship: her fitted looks and trophies from the shipwright, [sails, hull, flag,
## figurehead, trophies].
var looks: Array = []

var _rigs: Array[Node3D] = []
var _sails: Array[Array] = []
var _furls: Array[Array] = []
var _wheel: Node3D
var _capstan: Node3D
var _flag: Node3D
var _barrels: Array[Node3D] = []
var _recoil: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _aim_override := {}
var _flood: MeshInstance3D
var _spray: Array[CPUParticles3D] = []
var _gust_clock := 0.0
var _mist: Array[MeshInstance3D] = []
var _gull_pivot: Node3D
var _gulls: Array[Dictionary] = []
var _holes := {}  # hole id -> Node3D
var _hole_mesh: ArrayMesh
var _patch_mesh: ArrayMesh
var _last_anchor_progress := 0.0
var _winch: AudioStreamPlayer3D
var _last_sails := -1.0
var _last_patch := {}
var _last_stores := -1
var _flap_wait := 0.0
var _hammer_wait := 0.0


## The ship's colours: Toon.PALETTE with the crew's (or the skeleton ship's) over it.
var _paint := {}


## Prepare the hull and parts in every crew's colours and the skeleton ship's (Models caches
## them), so no ship's first appearance costs a frame.
static func warm_up() -> void:
	if Models.headless:
		return
	for crew_number in range(1, 5):
		var paint := Models.palette_recolor(Toon.crew_palette(crew_number))
		Models.mesh("ship_hull", paint)
		Models.part("ship_parts", "sail_0_0", paint)
	var wreck := Models.palette_recolor(Toon.SKELETON)
	Models.mesh("ship_wreck", wreck)
	Models.part("ship_parts", "sail_torn_0_0", wreck)
	var spanish := Models.palette_recolor(Toon.SPANISH)
	Models.mesh("ship_hull", spanish)
	Models.part("ship_parts", "sail_0_0", spanish)


## A Spanish galleon: sound hull and sails (not a wreck), but crewed by the dead.
func _spanish() -> bool:
	return kind == ShipState.Kind.SKELETON and flag in [1, 2, 5, 6]


func _part(name: String) -> ArrayMesh:
	return Models.part("ship_parts", name, _paint)


func _ready() -> void:
	var palette: Dictionary = Toon.SKELETON if kind == ShipState.Kind.SKELETON else Shipwright.palette(crew, looks)
	if _spanish():
		palette = {2: Toon.FLAGSHIP, 6: Toon.ASHSHIP}.get(flag, Toon.SPANISH)
	elif kind == ShipState.Kind.SKELETON and flag == 3:
		palette = Toon.GHOST
	elif kind == ShipState.Kind.SKELETON and flag == 4:
		palette = Toon.MERROW
	ShipMesh.use_palette(palette)
	_paint = Models.palette_recolor(palette)
	var wreck := kind == ShipState.Kind.SKELETON and flag in [0, 3]
	add_child(Toon.instance(Models.mesh("ship_wreck" if wreck else "ship_hull", _paint)))
	if flag != 5 or kind != ShipState.Kind.SKELETON:
		for m in ShipShape.MAST_Z.size():
			_build_rig(m)
	else:
		# The prison hulk: a rope hanging down her stern into the sea (ShipShape.STERN_ROPE).
		var rope := MeshBuilder.new()
		var top := ShipShape.ladder_top(ShipShape.STERN_ROPE) + Vector3(0, 0.9, 1.5)
		var bottom := ShipShape.ladder_bottom(ShipShape.STERN_ROPE) + Vector3(0, -0.5, 0)
		rope.cylinder(top, bottom, 0.045, 0.045, 6, Color("8a7a5a"))
		for k in 6:
			var y := lerpf(bottom.y + 0.6, top.y - 0.4, k / 5.0)
			var at := bottom.lerp(top, (y - bottom.y) / (top.y - bottom.y))
			rope.cylinder(at - Vector3(0.09, 0, 0), at + Vector3(0.09, 0, 0), 0.06, 0.06, 6, Color("6a5a3a"))
		add_child(Toon.instance(rope.build()))

	# The stern windows: dark by day, glowing from the cabin lamps at night.
	var panes := MeshBuilder.new()
	for x: float in [-1.8, -0.6, 0.6, 1.8]:
		panes.box(Vector3(x, ShipShape.DECK_Y + 0.9, ShipShape.HALF_LENGTH + 0.13), Vector3(0.28, 0.28, 0.01), Color.WHITE)
	add_child(Lantern.lit_panes(panes.build(), ShipMesh._c("trim")))

	# The ship's name in gold letters across the transom.
	var name_plate := Label3D.new()
	name_plate.text = ServerSim.CREW_NAMES[crew - 1] if crew > 0 else Game.ship_name_for(flag)
	name_plate.font = Hud.display_font()
	name_plate.font_size = 64
	name_plate.pixel_size = 0.0056
	name_plate.modulate = ShipMesh._c("gold")
	name_plate.outline_size = 6
	name_plate.outline_modulate = Color("2a1a10")
	name_plate.shaded = true
	name_plate.double_sided = false
	name_plate.position = ShipMesh.name_board() + Vector3(0, 0, 0.04)
	add_child(name_plate)

	# The figurehead, or the Admiral's raven if someone aboard has earned it; and the crew's
	# other trophies (Shipwright.Trophy).
	var trophies := int(looks[Shipwright.LOOKS]) if looks.size() > Shipwright.LOOKS else 0
	add_child(Toon.instance(_part(Shipwright.figurehead_part(looks, trophies))))
	if trophies & Shipwright.Trophy.HALBERD:
		add_child(Toon.instance(_part("trophy_halberd")))
	if trophies & Shipwright.Trophy.LANTERN:
		add_child(Toon.instance(_part("trophy_lantern")))
		var green := Vector3(-(ShipShape.half_width(11.6, ShipShape.QUARTER_Y) - 0.2) - 0.55, ShipShape.QUARTER_Y + ShipShape.RAIL_HEIGHT + 0.45 - 0.55, 11.6)
		_lamp(green, Toon.glow_material(Color("9cff8a")))
		var linnet := Lantern.new(Color("9cff8a"), 0.7, 6.0)
		linnet.position = green
		add_child(linnet)

	_wheel = Toon.instance(_part("wheel"))
	_wheel.position = ShipShape.WHEEL + Vector3(0, 1.05, 0.25)
	add_child(_wheel)

	_capstan = Toon.instance(_part("capstan"))
	_winch = Audio.loop_at(_capstan, "winch", -80.0, 35.0)
	_capstan.position = ShipShape.CAPSTAN
	add_child(_capstan)

	_flag = Node3D.new()
	_flag.position = Vector3(0, ShipShape.DECK_Y + ShipShape.MAST_HEIGHT[1] + 0.3, ShipShape.MAST_Z[1])
	var cloth := Toon.instance(_part("flag"), Toon.cloth_material())
	cloth.position = Vector3(0, -0.9, 0)
	_flag.add_child(cloth)
	add_child(_flag)

	var barrel_mesh := _part("cannon")
	for gun in ShipShape.cannon_count():
		var barrel := Toon.instance(barrel_mesh)
		add_child(barrel)
		_barrels.append(barrel)
		_place_barrel(gun, 0.0, 0.0)

	var glow := Toon.glow_material(ShipMesh._c("lantern"))
	var stern_lamp := Vector3(0, ShipShape.QUARTER_Y + ShipShape.RAIL_HEIGHT + 1.32, ShipShape.STERN_Z + 0.2)
	_lamp(stern_lamp, glow)
	# At night the stern lantern lights the quarterdeck and a lamp on the main mast the deck.
	var mast_lamp := Vector3(0.45, ShipShape.DECK_Y + 2.4, ShipShape.MAST_Z[1] - 0.45)
	_lamp(mast_lamp, glow)
	# Short reach for the mast lamp, so it lights the deck and not the sails above it.
	for lamp: Array in [[stern_lamp, 9.0], [mast_lamp, 5.5]]:
		var lantern := Lantern.new(ShipMesh._c("lantern").lerp(Color.WHITE, 0.2), 0.9, lamp[1])
		lantern.position = lamp[0]
		add_child(lantern)
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

	if kind == ShipState.Kind.SKELETON:
		_make_mist()
	else:
		# A couple of gulls keep the crew company, wheeling round the mainmast.
		_gull_pivot = Node3D.new()
		_gull_pivot.position = Vector3(0, ShipShape.DECK_Y + ShipShape.MAST_HEIGHT[1] - 2.0, ShipShape.MAST_Z[1])
		add_child(_gull_pivot)
		for i in 2:
			var bird: Dictionary = Gulls.make_bird()
			var node: Node3D = bird.node
			node.position = Vector3(5.5 + i * 2.0, i * 1.2, 0)
			node.rotation.y = PI
			_gull_pivot.add_child(node)
			_gulls.append(bird)

	# Spray thrown off both sides of the bow when the ship is moving fast.
	for side: float in [-1.0, 1.0]:
		var spray := _make_spray(side)
		spray.position = Vector3(side * (ShipShape.half_width(-10.5, 0.0) + 0.15), 0.25, -10.5)
		add_child(spray)
		_spray.append(spray)

	_flood = MeshInstance3D.new()
	_flood.mesh = ShipMesh.flood_mesh()
	_flood.material_override = Toon.clear_material(Color(0.137, 0.537, 0.890, 0.82))
	_flood.visible = false
	add_child(_flood)

	_hole_mesh = _part("hole")
	_patch_mesh = _part("patch")
	ShipMesh.use_palette({})

	_add_hull_blocker()


## The glowing glass inside one of the ship's lantern housings (modelled in the hull).
func _lamp(pos: Vector3, glow: Material) -> void:
	var lamp := MeshInstance3D.new()
	var glass := CylinderMesh.new()
	glass.top_radius = 0.11
	glass.bottom_radius = 0.13
	glass.height = 0.34
	glass.radial_segments = 8
	glass.rings = 1
	lamp.mesh = glass
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.material_override = glow
	lamp.position = pos
	add_child(lamp)


func _build_rig(mast: int) -> void:
	var rig := Node3D.new()
	rig.position = Vector3(0, ShipShape.DECK_Y, ShipShape.MAST_Z[mast])
	add_child(rig)
	_rigs.append(rig)
	var sails: Array[MeshInstance3D] = []
	var furls: Array[MeshInstance3D] = []
	var specs := ShipMesh.sails_for(mast)
	for k in specs.size():
		var spec: Array = specs[k]
		var top: float = spec[0]
		var yard := Toon.instance(_part("yard_%d_%d" % [mast, k]))
		yard.position = Vector3(0, top, -ShipShape.MAST_RADIUS - 0.2)
		rig.add_child(yard)
		var torn := "torn_" if kind == ShipState.Kind.SKELETON and flag in [0, 3] else ""
		# The canvas rolled up on top of the yard, shown as the sail is taken in.
		var bundle := Toon.instance(_part("furl_%d_%d" % [mast, k]))
		bundle.position = yard.position
		bundle.layers = Lantern.UNLIT_LAYER
		rig.add_child(bundle)
		furls.append(bundle)
		var sail := Toon.instance(_part("sail_%s%d_%d" % [torn, mast, k]))
		sail.position = Vector3(0, top - 0.1, -ShipShape.MAST_RADIUS - 0.3)
		sail.layers = Lantern.UNLIT_LAYER
		rig.add_child(sail)
		sails.append(sail)
		if mast == 1 and k == 0:
			# The crew's emblem on the main course, furling with the sail.
			var badge := Toon.instance(_part("raven_emblem" if _spanish() else "emblem"))
			badge.position = Vector3(0, -spec[1] * 0.5, 0)
			badge.layers = Lantern.UNLIT_LAYER
			sail.add_child(badge)
	_sails.append(sails)
	_furls.append(furls)


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
	_gust_clock += delta
	visible = state.sink < 1.0
	for m in _rigs.size():
		_rigs[m].rotation.y = -state.sail_angle[m] * ShipPhysics.MAX_SAIL_ANGLE
		var h: float = state.sail_height[m]
		for i in _sails[m].size():
			var sail: MeshInstance3D = _sails[m][i]
			sail.scale.y = lerpf(FURLED, 1.0, h)
			# Furled, the sail is a bundle on the yard; it unrolls into canvas as it comes down.
			sail.visible = h > 0.06
			var bundle: MeshInstance3D = _furls[m][i]
			var roll := clampf(1.0 - h / 0.4, 0.0, 1.0)
			bundle.visible = roll > 0.02
			bundle.scale = Vector3(1.0, maxf(roll, 0.05), maxf(roll, 0.05))
			# The canvas breathes a little as gusts fill and spill it.
			sail.scale.z = 1.0 + 0.07 * sin(_gust_clock * 1.3 + m * 1.7 + i * 0.9)
	_wheel.rotation.z = -state.rudder * 2.6
	_ship_sounds(state, delta)
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
	if _gull_pivot:
		_gull_pivot.rotation.y = _gust_clock * 0.45
		for i in _gulls.size():
			Gulls.flap(_gulls[i].wings, _gust_clock, 6.0 + i, i * 1.7)
	for i in _mist.size():
		# The ghostly mist swells and shrinks, each puff in its own time.
		var swell := 1.0 + 0.18 * sin(_gust_clock * 0.9 + i * 1.3)
		_mist[i].scale = Vector3(swell, 0.3 + 0.05 * sin(_gust_clock * 1.4 + i), swell)
	# In the storm's big seas the bow throws spray even at a crawl.
	var game := get_parent() as Game
	var storm := Storm.amount(Vector2(state.x, state.z), game.render_time) if game else 0.0
	for spray in _spray:
		spray.emitting = (state.speed > 3.0 or storm > 0.3) and state.sink <= 0.0
		spray.initial_velocity_min = 2.0 + state.speed * 0.35 + storm * 4.0
		spray.initial_velocity_max = 3.0 + state.speed * 0.6 + storm * 6.0
	_update_holes(state.holes)


## Skeleton ships trail a pale green mist along their waterline.
func _make_mist() -> void:
	var puff := SphereMesh.new()
	puff.radius = 2.1
	puff.height = 4.2
	puff.radial_segments = 12
	puff.rings = 6
	var haze := Toon.clear_material(Color(0.6, 1.0, 0.62, 0.26))
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	for z in range(-11, 13, 3):
		for side: float in [-1.0, 1.0]:
			var m := MeshInstance3D.new()
			m.mesh = puff
			m.material_override = haze
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.position = Vector3(side * (ShipShape.half_width(float(z), 0.0) + 0.6), 0.35, float(z))
			add_child(m)
			_mist.append(m)


func _make_spray(side: float) -> CPUParticles3D:
	var drop := SphereMesh.new()
	drop.radius = 0.22
	drop.height = 0.44
	drop.radial_segments = 6
	drop.rings = 3
	var p := CPUParticles3D.new()
	p.mesh = drop
	p.material_override = Toon.clear_material(Color(1, 1, 1, 0.85))
	p.amount = 64
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.2, 0.1, 1.2)
	p.direction = Vector3(side, 1.1, 0.5)
	p.spread = 26.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = shrink
	p.emitting = false
	return p


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


## Sounds of the crew at work, heard by anyone nearby: the capstan ratchet while the anchor
## comes up, canvas flapping as sails are worked, hammering at a hole being patched, and a
## thump as supplies come aboard.
func _ship_sounds(state: ShipState, delta: float) -> void:
	var winching := state.anchored and state.anchor_progress > _last_anchor_progress
	_winch.volume_db = -4.0 if winching else -80.0
	var sails := state.sail_height[0] + state.sail_height[1] + absf(state.sail_angle[0]) + absf(state.sail_angle[1])
	_flap_wait -= delta
	if _last_sails >= 0.0 and absf(sails - _last_sails) > 1e-3 and _flap_wait <= 0.0:
		_flap_wait = 0.7
		Audio.play_at("sail_flap", global_transform * Vector3(0, ShipShape.DECK_Y + 8.0, ShipShape.MAST_Z[1]), -6.0)
	_last_sails = sails
	_hammer_wait -= delta
	var patched := {}
	for hole: Array in state.holes:
		patched[int(hole[0])] = float(hole[4])
		if float(hole[4]) > _last_patch.get(int(hole[0]), 1.0) and _hammer_wait <= 0.0:
			_hammer_wait = 0.32
			Audio.play_at("hammer", global_transform * Vector3(hole[1], hole[2], hole[3]), -2.0)
	_last_patch = patched
	var stores := state.cannonballs + state.planks + state.bananas
	if _last_stores >= 0 and stores > _last_stores:
		Audio.play_at("thud", global_transform * Vector3(0, ShipShape.DECK_Y, 0), 0.0)
	_last_stores = stores


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

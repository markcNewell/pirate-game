class_name Avatar
extends Node3D
## Another player as you see them: a rigged toon pirate (made in Blender, art/blender/
## characters.py) in one of eight looks, wearing their shirt colour and skin tone, with a name
## tag. What the snapshots say picks the animation: standing, walking or running (played at the
## speed they really move), swimming, jumping, at the wheel, the ropes, the capstan or a gun,
## digging, hammering a patch or bailing; carrying a chest or a bucket on top of that; a cutlass
## cut or a pistol shot, and a flinch when hit. Their head nods with where they look.

const SHIRTS: Array[Color] = [Color("d63c3c"), Color("3c6fd6"), Color("3cae5a"), Color("9a4fd0")]
const SKINS: Array[Color] = [Color("f2c49b"), Color("c98e62"), Color("8d5a3b"), Color("e8b48a")]
## How many looks the pirate model has (look0, look1...: art/blender/characters.py).
const LOOKS := 8
## The speeds the walk and run cycles are drawn for (PlayerMotor.WALK and RUN).
const WALK_SPEED := 4.5
const RUN_SPEED := 7.0
## Bones the upper-body actions (carrying, bucket, attacks) take over from the legs' cycle.
const UPPER := ["spine", "chest", "neck", "head", "upper_arm_r", "forearm_r", "hand_r",
	"upper_arm_l", "forearm_l", "hand_l"]
const LOOPS := ["idle", "walk", "run", "swim", "wheel", "haul", "push", "cannon", "dig", "hammer",
	"bail", "carry", "bucket", "jump"]
const BASES := ["idle", "walk", "run", "swim", "wheel", "haul", "push", "cannon", "jump", "dig",
	"hammer", "bail"]
## Where the fist closes round a grip in the rest pose, from the wrist along the hanging hand
## (art/blender/characters.py, hand()); the arms rest in an A this many degrees off vertical.
const GRIP := Vector3(-0.0396, -0.121, 0.0)
const ARM_A := 37.7

## What a player is busy with besides moving (the server's "act" in each snapshot).
enum Act { NONE, DIG, HAMMER, BAIL }

var _model: Node3D
var _skeleton: Skeleton3D
var _tree: AnimationTree
var _look: HeadLook
var _label: Label3D
var _cutlass: Node3D
var _pistol: Node3D
var _bucket: Node3D
var _weapon := Weapons.Kind.CUTLASS
var _last := Vector3.ZERO
var _have_last := false
var _speed := 0.0
var _climb := 0.0
var _base := "idle"
var _station_kind := -1
var _swimming := false
var _carrying := false
var _act := Act.NONE


## Which look, shirt and skin tone this player has (their place in the roster).
var index := 0


func _init(player_name: String, look_index: int) -> void:
	index = look_index
	var shirt := SHIRTS[look_index % SHIRTS.size()]
	var skin := skin_for(look_index)
	_model = Models.instance("pirate", {
		Models.SHIRT: shirt, Models.SHIRT_DARK: shirt.darkened(0.28),
		Models.SKIN: skin, Models.SKIN_DARK: skin.darkened(0.12).lerp(Color("c0503a"), 0.12),
	}, ["body", "look%d" % (look_index % LOOKS)])
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_build_tree()
	_look = HeadLook.new()
	_skeleton.add_child(_look)
	_cutlass = _in_hand("hand_r", Toon.instance(WeaponView.cutlass_mesh()), 1.0)
	_pistol = _in_hand("hand_r", Toon.instance(WeaponView.pistol_mesh()), 1.0)
	# The bucket hangs from its handle in the fist; the grip runs forward, the handle across it.
	var bucket := Toon.instance(Models.part("tools", "bucket"))
	bucket.rotation.y = PI / 2.0
	_bucket = _in_hand("hand_l", bucket, -1.0)
	_bucket.visible = false
	_label = Label3D.new()
	_label.text = player_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 10
	# The same size on screen near or far, so a crewmate beside you is not hidden behind it.
	_label.fixed_size = true
	_label.pixel_size = 0.001
	_label.position.y = 2.3
	_label.no_depth_test = false
	add_child(_label)
	set_weapon(Weapons.Kind.CUTLASS)


## The animation graph: one base pose (moving, at a station, swimming...), then the upper body
## taken over for carrying or a bucket, then one-off attacks and flinches on top.
func _build_tree() -> void:
	var player: AnimationPlayer = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for name: String in LOOPS:
		var a := player.get_animation(name)
		if a and a.loop_mode == Animation.LOOP_NONE:
			a.loop_mode = Animation.LOOP_LINEAR
	var graph := AnimationNodeBlendTree.new()
	var base := AnimationNodeTransition.new()
	base.xfade_time = 0.22
	for name: String in BASES:
		base.add_input(name)
	graph.add_node("base", base)
	for name: String in BASES:
		var clip := AnimationNodeAnimation.new()
		clip.animation = name
		graph.add_node("clip_" + name, clip)
		if name in ["walk", "run", "swim"]:
			# Played at the speed the player really moves.
			graph.add_node("rate_" + name, AnimationNodeTimeScale.new())
			graph.connect_node("rate_" + name, 0, "clip_" + name)
			graph.connect_node("base", BASES.find(name), "rate_" + name)
		else:
			graph.connect_node("base", BASES.find(name), "clip_" + name)
	var last := "base"
	for name: String in ["carry", "bucket"]:
		var hold := AnimationNodeBlend2.new()
		_upper_only(hold)
		graph.add_node(name, hold)
		var clip := AnimationNodeAnimation.new()
		clip.animation = name
		graph.add_node("clip_" + name, clip)
		graph.connect_node(name, 0, last)
		graph.connect_node(name, 1, "clip_" + name)
		last = name
	var weapon := AnimationNodeTransition.new()
	weapon.add_input("slash")
	weapon.add_input("shoot")
	graph.add_node("weapon", weapon)
	for i in 2:
		var clip := AnimationNodeAnimation.new()
		clip.animation = ["slash", "shoot"][i]
		graph.add_node("clip_" + clip.animation, clip)
		graph.connect_node("weapon", i, "clip_" + clip.animation)
	for name: String in ["attack", "hurt"]:
		var shot := AnimationNodeOneShot.new()
		shot.fadein_time = 0.06
		shot.fadeout_time = 0.15
		_upper_only(shot)
		graph.add_node(name, shot)
		graph.connect_node(name, 0, last)
		last = name
	graph.connect_node("attack", 1, "weapon")
	var flinch := AnimationNodeAnimation.new()
	flinch.animation = "hurt"
	graph.add_node("clip_hurt", flinch)
	graph.connect_node("hurt", 1, "clip_hurt")
	graph.connect_node("output", 0, last)
	_tree = AnimationTree.new()
	_tree.tree_root = graph
	_model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.root_node = _tree.get_path_to(_model)
	_tree.active = true


func _upper_only(node: AnimationNode) -> void:
	node.filter_enabled = true
	var path := String(_model.get_path_to(_skeleton))
	for bone: String in UPPER:
		node.set_filter_path(NodePath("%s:%s" % [path, bone]), true)


## Something held in a fist (the grip runs forward through it), following the hand's bone.
## `side` is 1 for the right hand, -1 for the left.
func _in_hand(bone: String, held: Node3D, side: float) -> Node3D:
	var attach := BoneAttachment3D.new()
	attach.bone_name = bone
	_skeleton.add_child(attach)
	var rest := _skeleton.get_bone_global_rest(_skeleton.find_bone(bone))
	var turn := Basis(Vector3.BACK, deg_to_rad(ARM_A) * side)
	var grip := Transform3D(turn, rest.origin + turn * Vector3(GRIP.x * side, GRIP.y, GRIP.z))
	var holder := Node3D.new()
	holder.transform = rest.affine_inverse() * grip
	attach.add_child(holder)
	holder.add_child(held)
	return holder


func set_bucket(full: bool) -> void:
	_bucket.visible = full
	_tree.set("parameters/bucket/blend_amount", 1.0 if full and not _carrying else 0.0)


## Crewmates' names are white; other crews' are red.
func set_hostile(hostile: bool) -> void:
	_label.modulate = Color("ff8a7a") if hostile else Color.WHITE


func set_weapon(kind: int) -> void:
	_weapon = kind
	_cutlass.visible = kind == Weapons.Kind.CUTLASS and not _busy_hands()
	_pistol.visible = kind == Weapons.Kind.PISTOL and not _busy_hands()


## A cutlass cut or a pistol shot.
func attack() -> void:
	_tree.set("parameters/weapon/transition_request", "shoot" if _weapon == Weapons.Kind.PISTOL else "slash")
	_tree.set("parameters/attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func hurt() -> void:
	_tree.set("parameters/hurt/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Skin tones cycle on a different beat from shirts and looks, so the four players of a crew
## all differ and the next four mix them up again.
static func skin_for(index: int) -> Color:
	return SKINS[(index + index / 4) % SKINS.size()]


## Tilt the head (and a little of the neck) up or down with the player's view.
func set_pitch(pitch: float) -> void:
	_look.pitch = clampf(pitch * 0.7, -0.6, 0.7)


## What the player is doing besides moving: at which kind of station (-1 none), swimming,
## carrying a chest, and digging, hammering or bailing (Act).
func set_state(station_kind: int, swimming: bool, carrying: bool, act: int) -> void:
	_station_kind = station_kind
	_swimming = swimming
	_carrying = carrying
	_act = act
	_tree.set("parameters/carry/blend_amount", 1.0 if carrying else 0.0)
	set_weapon(_weapon)


func _busy_hands() -> bool:
	return _carrying or _station_kind >= 0 or _act != Act.NONE or _swimming


## `pose` is where the feet are and which way the pirate faces, in the world; `local` is the
## same point in the frame they stand in (their ship's, or the world's), so a ship's own speed
## does not make its crew walk.
func place(pose: Transform3D, delta: float, local := Vector3.INF) -> void:
	global_transform = pose
	var here := pose.origin if local == Vector3.INF else local
	if _have_last and delta > 0.0:
		var step := here - _last
		var flat := Vector2(step.x, step.z).length() / delta
		# Ignore teleports (respawns, ladders, hatches).
		if flat < 20.0:
			_speed = lerpf(_speed, flat, minf(1.0, delta * 10.0))
			_climb = lerpf(_climb, step.y / delta, minf(1.0, delta * 10.0))
	_last = here
	_have_last = true
	_pick_base()


func _pick_base() -> void:
	var base := "idle"
	match _station_kind:
		ShipShape.Kind.WHEEL:
			base = "wheel"
		ShipShape.Kind.SAILS:
			base = "haul"
		ShipShape.Kind.ANCHOR:
			base = "push"
		ShipShape.Kind.CANNON:
			base = "cannon"
		_:
			if _swimming:
				base = "swim"
			elif absf(_climb) > 2.5:
				base = "jump"
			elif _act == Act.DIG:
				base = "dig"
			elif _act == Act.HAMMER:
				base = "hammer"
			elif _act == Act.BAIL:
				base = "bail"
			elif _speed > 5.6:
				base = "run"
			elif _speed > 0.6:
				base = "walk"
	if base != _base:
		_base = base
		_tree.set("parameters/base/transition_request", base)
	_tree.set("parameters/rate_walk/scale", clampf(_speed / WALK_SPEED, 0.5, 1.6))
	_tree.set("parameters/rate_run/scale", clampf(_speed / RUN_SPEED, 0.7, 1.4))
	_tree.set("parameters/rate_swim/scale", clampf(0.6 + _speed / PlayerMotor.SWIM, 0.6, 1.6))


## Bends the neck and head after the animation, to look up or down.
class HeadLook extends SkeletonModifier3D:
	var pitch := 0.0

	func _process_modification() -> void:
		var sk := get_skeleton()
		for pair: Array in [["neck", 0.35], ["head", 0.65]]:
			var bone := sk.find_bone(pair[0])
			var parent := sk.get_bone_parent(bone)
			var axis := (sk.get_bone_global_pose(parent).basis.inverse() * Vector3.RIGHT).normalized()
			var q := Quaternion(axis, pitch * float(pair[1]))
			sk.set_bone_pose_rotation(bone, q * sk.get_bone_pose_rotation(bone))

class_name SkeletonView
extends Node3D
## A skeleton as players see it (art/blender/characters.py): yellowed bones in one of three
## outfits of rags, green light in its eye sockets and a rusty cutlass. It shares the
## pirates' rig and animations: it walks, stands, cuts at you, flinches and flashes red when
## hit, and topples when it falls.

## Its rusty cutlass: the blade and brass of the pirates' one, gone brown and green.
const RUST := {Color("d8dde2"): Color("9c8a74"), Color("9aa2ac"): Color("6e5e4c"), Color("e0b04a"): Color("7d8a5a")}

## Which outfit (0-2: breeches and tricorn, bandana and shirt rags, helmet and loincloth).
var look := 0
## A bounty's captain: his own coat, hat and lantern, and a head taller.
var captain := false
## One of the Spanish dead: steel helmet and breastplate; a digger carries a spade instead of a
## sword; the sergeant (Calavera) wears gilt, a tower shield and a halberd, and stands taller.
var spanish := false
var digger := false
var sergeant := false
var _digging := false
var _model: Node3D
var _player: AnimationPlayer
var _material: ShaderMaterial
var _moving := false
var _flash := 0.0
var _fall := 0.0


func _ready() -> void:
	var outfit := "look%d" % (look % 3)
	if captain:
		outfit = "look3"
	elif sergeant:
		outfit = "look5"
	elif spanish:
		outfit = "look4"
	_model = Models.instance("skeleton", {}, ["skeleton", outfit])
	add_child(_model)
	if captain:
		_model.scale = Vector3.ONE * 1.12
	elif sergeant:
		_model.scale = Vector3.ONE * 1.25
	# Its own copy of the toon material, so its red flash is its own.
	_material = Models.material(true).duplicate()
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _material
	_player = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for name: String in ["idle_blade", "walk_blade"]:
		var a := _player.get_animation(name)
		if a.loop_mode == Animation.LOOP_NONE:
			a.loop_mode = Animation.LOOP_LINEAR
	_player.animation_finished.connect(func(_name: StringName) -> void: _player.play("walk_blade" if _moving else "idle_blade", 0.2))
	_player.play("idle_blade")
	# A skeleton never stands quite in step with the next one.
	_player.seek(randf() * _player.current_animation_length)
	var skeleton: Skeleton3D = _model.find_children("*", "Skeleton3D", true, false)[0]
	var head := BoneAttachment3D.new()
	head.bone_name = "head"
	skeleton.add_child(head)
	var head_rest := skeleton.get_bone_global_rest(skeleton.find_bone("head"))
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.02
		ball.height = 0.04
		ball.radial_segments = 8
		ball.rings = 4
		eye.mesh = ball
		eye.material_override = Toon.glow_material(Color("9cff8a"))
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.transform = head_rest.affine_inverse() * Transform3D(Basis.IDENTITY, Vector3(side * 0.045, 1.675, -0.112))
		head.add_child(eye)
	var hand := BoneAttachment3D.new()
	hand.bone_name = "hand_r"
	skeleton.add_child(hand)
	var hand_rest := skeleton.get_bone_global_rest(skeleton.find_bone("hand_r"))
	var turn := Basis(Vector3.BACK, deg_to_rad(Avatar.ARM_A))
	var grip := Transform3D(turn, hand_rest.origin + turn * Avatar.GRIP)
	if sergeant:
		return  # his halberd is part of his outfit
	if digger:
		# A spade, gripped like the pirates' (its shaft through the fist).
		var spade := Toon.instance(Models.part("tools", "shovel"))
		spade.transform = hand_rest.affine_inverse() * Transform3D(turn * Basis(Vector3.RIGHT, -PI / 2.0), grip.origin)
		hand.add_child(spade)
		return
	var sword := Toon.instance(Models.mesh("cutlass", RUST))
	sword.transform = hand_rest.affine_inverse() * grip
	hand.add_child(sword)


## A digger at work, or not (from the snapshot).
func set_digging(on: bool) -> void:
	if on == _digging:
		return
	_digging = on
	if on:
		var a := _player.get_animation("dig")
		if a and a.loop_mode == Animation.LOOP_NONE:
			a.loop_mode = Animation.LOOP_LINEAR
		_player.play("dig", 0.2)
	else:
		_player.play("walk_blade" if _moving else "idle_blade", 0.2)


## A blow rings off the sergeant's shield (`knocked`: a shot knocked it aside).
func shield_hit(knocked: bool) -> void:
	_flash = 0.4 if knocked else 0.15
	if knocked and _player.current_animation != "slash":
		_player.play("hurt", 0.05)


func swing() -> void:
	_player.play("slash", 0.08)


func hurt() -> void:
	_flash = 1.0
	if _player.current_animation != "slash":
		_player.play("hurt", 0.05)


## `pose` is where the feet are, in the world. `walking` and `fallen` come from the snapshot.
func place(pose: Transform3D, walking: bool, fallen: bool, delta: float) -> void:
	global_transform = pose
	if walking != _moving and not fallen:
		_moving = walking
		if _player.current_animation in ["idle_blade", "walk_blade"] and not _digging:
			_player.play("walk_blade" if walking else "idle_blade", 0.25)
	_flash = maxf(0.0, _flash - delta * 4.0)
	_material.set_shader_parameter("tint", Color(1.0, 1.0 - _flash * 0.6, 1.0 - _flash * 0.6))
	if fallen:
		_fall = minf(1.0, _fall + delta * 2.5)
		_player.pause()
	_model.rotation.x = -_fall * PI / 2.0
	_model.position.y = -_fall * 0.3

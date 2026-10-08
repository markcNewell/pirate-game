class_name Colossus
extends Node3D
## The Bone Colossus as players see it (story Act V): the skeleton model at StoryAct5.SCALE times
## life size, knee-deep in the Maw, with green fire in its eyes and four glowing joints
## (shoulders and knees) that go dark as cannon breaks them. Fallen, it lies on its back across
## the Anvil. Its root is its feet, StoryAct5.ROOT_Y below the sea.

## Joint bones in the order of StoryAct5.JOINTS: right shoulder, left shoulder, right knee, left knee
## (+x first, as the server counts them).
const JOINT_BONES := ["upper_arm", "upper_arm", "shin", "shin"]

var _model: Node3D
var _player: AnimationPlayer
var _joints: Array[MeshInstance3D] = []
var _flash := [0.0, 0.0, 0.0, 0.0]
var _fallen := false


func _ready() -> void:
	_model = Models.instance("skeleton", {}, ["skeleton"])
	_model.scale = Vector3.ONE * StoryAct5.SCALE
	add_child(_model)
	var material := Models.material(true).duplicate()
	material.set_shader_parameter("tint", Color(0.85, 0.9, 0.8))
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = material
	_player = _model.find_children("*", "AnimationPlayer", true, false)[0]
	var idle := _player.get_animation("idle_blade")
	idle.loop_mode = Animation.LOOP_LINEAR
	_player.animation_finished.connect(func(_name: StringName) -> void: _player.play("idle_blade", 0.4))
	_player.play("idle_blade")
	_player.speed_scale = 0.35  # a giant moves slowly
	var skeleton: Skeleton3D = _model.find_children("*", "Skeleton3D", true, false)[0]
	# Its eyes.
	var head := BoneAttachment3D.new()
	head.bone_name = "head"
	skeleton.add_child(head)
	var head_rest := skeleton.get_bone_global_rest(skeleton.find_bone("head"))
	for side: float in [-1.0, 1.0]:
		var eye := _glow(0.035, Color("9cff8a"))
		eye.transform = head_rest.affine_inverse() * Transform3D(Basis.IDENTITY, Vector3(side * 0.045, 1.675, -0.112))
		head.add_child(eye)
	# The four joints: pick the side by where each bone rests (+x first, as the server counts).
	for i in 4:
		var want_plus := i % 2 == 0
		for suffix: String in ["_r", "_l"]:
			var bone: String = JOINT_BONES[i] + suffix
			var rest := skeleton.get_bone_global_rest(skeleton.find_bone(bone))
			if (rest.origin.x > 0.0) != want_plus:
				continue
			var at := BoneAttachment3D.new()
			at.bone_name = bone
			skeleton.add_child(at)
			var glow := _glow(0.11 if i < 2 else 0.09, Color("7dff8a"))
			at.add_child(glow)
			var light := OmniLight3D.new()
			light.light_color = Color("7dff8a")
			light.light_energy = 3.0
			light.omni_range = 1.4  # in model units: 25 m at full size
			glow.add_child(light)
			_joints.append(glow)
			break


func _glow(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = Toon.glow_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The server's state: bits 0-3 the broken joints, StoryAct5.KNEEL once it has fallen.
func set_state(state: int, first: bool) -> void:
	for i in mini(4, _joints.size()):
		_joints[i].visible = state & (1 << i) == 0
	if state & StoryAct5.KNEEL and not _fallen:
		_fallen = true
		_player.pause()
		if first:
			_model.rotation.x = -PI / 2.0
			_model.position.y = 0.0


func slam() -> void:
	if not _fallen and _player.has_animation("slash"):
		_player.play("slash", 0.2)


func joint_hit(i: int) -> void:
	if i < _flash.size():
		_flash[i] = 1.0


func _process(delta: float) -> void:
	for i in mini(4, _joints.size()):
		if _flash[i] > 0.0:
			_flash[i] = maxf(0.0, _flash[i] - delta * 3.0)
			_joints[i].scale = Vector3.ONE * (1.0 + _flash[i])
	if _fallen and _model.rotation.x > -PI / 2.0:
		# Toppling over backwards onto the rock.
		_model.rotation.x = maxf(-PI / 2.0, _model.rotation.x - delta * 0.8)
		_model.position.y = lerpf(_model.position.y, 0.0, delta)

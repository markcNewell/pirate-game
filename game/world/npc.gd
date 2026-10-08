class_name Npc
extends Node3D
## One of Port Merrow's people standing about (art/blender/characters.py, npcs): the Lantern
## Order's mystic, the Merrow Traders' agent, a castaway trader or Moll the lighthouse keeper. They breathe and shift
## on their feet, and turn to watch you when you come near.

const WHO := {
	"mystic": {"shirt": Color("2a5a48"), "skin": Color("cfd6cc"), "lantern": Color("9cff8a")},
	"agent": {"shirt": Color("f4efe2"), "skin": Color("e8b48a")},
	"castaway": {"shirt": Color("5a7a9a"), "skin": Color("b07a4a")},
	"keeper": {"shirt": Color("e8e0d0"), "skin": Color("e0a888")},
	"isabel": {"shirt": Color("efe8da"), "skin": Color("d8a07a")},
	"gideon": {"shirt": Color("c8302a"), "skin": Color("e8b48a")},
	"martha": {"shirt": Color("7a9a6a"), "skin": Color("e8b48a")},
	"hobb": {"shirt": Color("c8b48a"), "skin": Color("d89a70")},
	"ocaso": {"shirt": Color("e8e4d8"), "skin": Color("d8c8b0")},
	"cuervo": {"shirt": Color("efe8da"), "skin": Color("dcae86")},
}
const WATCH_RANGE := 12.0

var _rest_yaw := 0.0
var _model: Node3D


## `who` is a key of WHO; `facing` the direction (yaw) they look when nobody is near.
func _init(who: String, facing: float) -> void:
	var look: Dictionary = WHO[who]
	_model = Models.instance("npcs", {
		Models.SHIRT: look.shirt, Models.SHIRT_DARK: look.shirt.darkened(0.28),
		Models.SKIN: look.skin, Models.SKIN_DARK: look.skin.darkened(0.12),
	}, ["body", who])
	add_child(_model)
	_rest_yaw = facing
	rotation.y = facing
	var player: AnimationPlayer = _model.find_children("*", "AnimationPlayer", true, false)[0]
	player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	player.play("idle")
	player.seek(randf() * player.current_animation_length)
	if look.has("lantern"):
		# The lantern in the left hand gives off a little light.
		var skeleton: Skeleton3D = _model.find_children("*", "Skeleton3D", true, false)[0]
		var hand := BoneAttachment3D.new()
		hand.bone_name = "hand_l"
		skeleton.add_child(hand)
		var glow := OmniLight3D.new()
		glow.light_color = look.lantern
		glow.light_energy = 1.2
		glow.omni_range = 4.0
		glow.position = Vector3(0, -0.3, 0)
		hand.add_child(glow)


## Turn toward the camera when it comes close, back to facing the sea when it leaves.
func watch(camera_pos: Vector3, delta: float) -> void:
	var to := camera_pos - global_position
	var want := _rest_yaw
	if Vector2(to.x, to.z).length() < WATCH_RANGE:
		want = atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(delta * 3.0, 0.0, 1.0))

class_name StoryObjectView
extends Node3D
## How a story thing looks (art/blender/props.py, story): a fresh grave burning with green fire
## (a flickering flame and a green light on the ground, then smoke once doused), a journal
## lying open with a glint to catch the eye, or the Spanish dead's rowing boat.

## The flame's orange made green: the Heart's fire.
const GREEN := {Color("ff8a2a"): Color("2fbf5a"), Color("ffd040"): Color("8cff7a"), Color("fff4c0"): Color("e8ffd8")}

var kind := StoryObject.Kind.FIRE
var _flame: MeshInstance3D
var _light: OmniLight3D
var _glint: MeshInstance3D
var _smoke := 0.0
var _clock := randf() * 10.0


func _init(what: int, lit := true) -> void:
	kind = what
	match kind:
		StoryObject.Kind.FIRE:
			add_child(Toon.instance(Models.part("story", "grave")))
			_flame = MeshInstance3D.new()
			_flame.mesh = Models.part("fx", "flame", GREEN)
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.vertex_color_use_as_albedo = true
			glow.vertex_color_is_srgb = true
			_flame.material_override = glow
			_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_flame.position = Vector3(0, 0.22, 0.05)
			_flame.scale = Vector3.ONE * 1.3
			add_child(_flame)
			_light = OmniLight3D.new()
			_light.light_color = Color("7dff8a")
			_light.light_energy = 2.2
			_light.omni_range = 7.0
			_light.position = Vector3(0, 1.0, 0)
			add_child(_light)
			if not lit:
				douse()
		StoryObject.Kind.BOOK:
			add_child(Toon.instance(Models.part("story", "journal")))
			_glint = MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.08
			s.height = 0.16
			_glint.mesh = s
			_glint.material_override = Toon.glow_material(Color("fff6c8"))
			_glint.position = Vector3(0, 0.3, 0)
			_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_glint)
		StoryObject.Kind.BOAT:
			add_child(Toon.instance(Models.part("story", "rowboat")))


## The fire hisses out: no flame or light, a wisp of smoke for a while.
func douse() -> void:
	if _flame == null or not _flame.visible:
		return
	_flame.visible = false
	_light.visible = false
	_smoke = 6.0


func _process(delta: float) -> void:
	_clock += delta
	if _flame and _flame.visible:
		# A guttering flicker, in size and light.
		var f := 1.0 + 0.12 * sin(_clock * 13.0) + 0.08 * sin(_clock * 7.3 + 1.0)
		_flame.scale = Vector3(1.3, 1.3 * f, 1.3)
		_flame.rotation.y += delta * 0.6
		_light.light_energy = 2.0 + 0.5 * sin(_clock * 11.0)
	if _glint:
		# A slow twinkle over the journal so it can be found on the sand.
		var t := 0.5 + 0.5 * sin(_clock * 3.0)
		_glint.scale = Vector3.ONE * (0.3 + 0.7 * t)
		_glint.visible = t > 0.25
	if _smoke > 0.0:
		_smoke -= delta
		if Engine.get_process_frames() % 12 == 0:
			var game := get_parent() as Game
			if game and game.effects:
				game.effects.smoke(global_position + Vector3(0, 0.4, 0))

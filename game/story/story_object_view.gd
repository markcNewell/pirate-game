class_name StoryObjectView
extends Node3D
## How a story thing looks (art/blender/props.py, story): a fresh grave burning with green fire
## (a flickering flame and a green light on the ground, then smoke once doused), a journal
## lying open with a glint to catch the eye, the Spanish dead's rowing boat, an open grave
## (filled white once salted), a powder keg (sparking once struck), the powder store, the dig
## camp and its great green bonfire (smaller with each bucket), or a bottle bobbing in the sea.

## The flame's orange made green: the Heart's fire.
const GREEN := {Color("ff8a2a"): Color("2fbf5a"), Color("ffd040"): Color("8cff7a"), Color("fff4c0"): Color("e8ffd8")}

var kind := StoryObject.Kind.FIRE
var _state := -99
var _flame: MeshInstance3D
var _flame_size := 1.3
var _light: OmniLight3D
var _glint: MeshInstance3D
var _body: MeshInstance3D
var _spark: MeshInstance3D
var _smoke := 0.0
var _topple := 0.0
var _clock := randf() * 10.0


func _init(what: int, state := 1) -> void:
	kind = what
	match kind:
		StoryObject.Kind.FIRE:
			add_child(Toon.instance(Models.part("story", "grave")))
			_add_flame(Vector3(0, 0.22, 0.05), 1.3, 7.0)
		StoryObject.Kind.BOOK:
			add_child(Toon.instance(Models.part("story", "journal")))
			_add_glint(Vector3(0, 0.3, 0))
		StoryObject.Kind.BOAT:
			add_child(Toon.instance(Models.part("story", "rowboat")))
		StoryObject.Kind.GRAVE:
			_body = Toon.instance(Models.part("story", "grave_open"))
			add_child(_body)
		StoryObject.Kind.KEG:
			add_child(Toon.instance(Models.part("story", "keg")))
			_spark = MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.06
			s.height = 0.12
			_spark.mesh = s
			_spark.material_override = Toon.glow_material(Color("ffd040"))
			_spark.position = Vector3(0.1, 0.9, 0.06)
			_spark.visible = false
			add_child(_spark)
		StoryObject.Kind.STORE:
			add_child(Toon.instance(Models.part("story", "powder_store")))
		StoryObject.Kind.CAMP:
			add_child(Toon.instance(Models.part("story", "dig_camp")))
		StoryObject.Kind.BONFIRE:
			add_child(Toon.instance(Models.part("story", "bonfire")))
			_add_flame(Vector3(0, 0.3, 0), 3.2, 16.0)
		StoryObject.Kind.BOTTLE:
			_body = Toon.instance(Models.part("story", "bottle"))
			add_child(_body)
			_add_glint(Vector3(0, 0.25, 0))
		StoryObject.Kind.ISABEL:
			var isabel := Npc.new("isabel", 0.0)
			add_child(isabel)
		StoryObject.Kind.WRECK:
			# The San Telmo, settled on the bottom with her bow and a mast above the water.
			var wreck := Toon.instance(Models.mesh("ship_wreck", Models.palette_recolor(Toon.SKELETON)))
			wreck.rotation = Vector3(0.35, 0.0, 0.25)
			wreck.position = Vector3(0, -5.5, 0)
			add_child(wreck)
			_add_glint(Vector3(0, 0.4, 0))
		StoryObject.Kind.BELL:
			_body = Toon.instance(Models.part("fort_parts", "bell_gallows"))
			_body.position.y = -StoryRun.BELL_HEIGHT
			add_child(_body)
		StoryObject.Kind.SEARCH:
			_body = Toon.instance(Models.part("loot", "crate_salt"))
			add_child(_body)
		StoryObject.Kind.GATE:
			_body = Toon.instance(Models.part("fort_parts", "gate"))
			add_child(_body)
			_blocker(Vector3(0.6, Fort.WALL_H - 0.6, 2.0 * Fort.GATE_HALF), Vector3(0, (Fort.WALL_H - 0.6) * 0.5, 0))
		StoryObject.Kind.GUN:
			_body = Toon.instance(Models.part("ship_parts", "cannon"))
			_body.position.y = 0.1
			add_child(_body)
		StoryObject.Kind.CELL:
			_body = Toon.instance(Models.part("fort_parts", "cell_door"))
			add_child(_body)
		StoryObject.Kind.VAULT:
			_body = Toon.instance(Models.part("fort_parts", "vault_door"))
			add_child(_body)
		StoryObject.Kind.BOMB:
			add_child(Toon.instance(Models.part("fort_parts", "bomb")))
			_spark = MeshInstance3D.new()
			var s2 := SphereMesh.new()
			s2.radius = 0.06
			s2.height = 0.12
			_spark.mesh = s2
			_spark.material_override = Toon.glow_material(Color("ffd040"))
			_spark.position = Vector3(0.02, 0.54, 0.06)
			add_child(_spark)
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi != _flame and mi != _glint and mi != _spark:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	set_state(state)


func _add_flame(at: Vector3, size: float, reach: float) -> void:
	_flame = MeshInstance3D.new()
	_flame.mesh = Models.part("fx", "flame", GREEN)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	glow.vertex_color_is_srgb = true
	_flame.material_override = glow
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.position = at
	_flame_size = size
	_flame.scale = Vector3.ONE * size
	add_child(_flame)
	_light = OmniLight3D.new()
	_light.light_color = Color("7dff8a")
	_light.light_energy = 2.2
	_light.omni_range = reach
	_light.position = at + Vector3(0, 0.8, 0)
	add_child(_light)


## A solid box players bump into (the shut gate), removed when it is blown.
func _blocker(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
	body.name = "blocker"
	add_child(body)


## Where the server says it is this frame (on a deck, for Isabel aboard).
func place(at: Transform3D) -> void:
	if kind == StoryObject.Kind.BOTTLE:
		at.origin.y = global_position.y if is_inside_tree() else at.origin.y
	global_transform = at


func _add_glint(at: Vector3) -> void:
	_glint = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.16
	_glint.mesh = s
	_glint.material_override = Toon.glow_material(Color("fff6c8"))
	_glint.position = at
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glint)


## The thing's state from the server (StoryObject.state): a fire out, a grave salted, a keg's
## fuse lit, a bonfire smaller by a bucket.
func set_state(state: int) -> void:
	if state == _state:
		return
	var was := _state
	_state = state
	match kind:
		StoryObject.Kind.FIRE:
			if state == 0:
				_put_out(was != -99)
		StoryObject.Kind.BONFIRE:
			if state <= 0:
				_put_out(was != -99)
			elif _flame:
				_flame_size = 3.2 * (0.4 + 0.6 * state / 3.0)
				if was != -99:
					_smoke = 2.0
		StoryObject.Kind.GRAVE:
			if state == 0:
				remove_child(_body)
				_body.queue_free()
				_body = Toon.instance(Models.part("story", "grave_salted"))
				add_child(_body)
		StoryObject.Kind.KEG:
			_spark.visible = state == 2
		StoryObject.Kind.BELL:
			if state == 0 and was != -99:
				_topple = 0.001
			elif state == 0:
				_body.rotation.z = 1.4
		StoryObject.Kind.GATE:
			if state == 0:
				remove_child(_body)
				_body.queue_free()
				_body = Toon.instance(Models.part("fort_parts", "gate_broken"))
				add_child(_body)
				var blocker := get_node_or_null("blocker")
				if blocker:
					blocker.queue_free()
		StoryObject.Kind.GUN:
			if state == 0:
				_body.rotation.x = 0.5
				if was != -99:
					_smoke = 8.0
		StoryObject.Kind.CELL, StoryObject.Kind.VAULT:
			if state == 0:
				_body.rotation.y = -1.9
		StoryObject.Kind.SEARCH:
			if state == 0:
				_body.rotation.z = 0.12


## No more flame or light; a wisp of smoke for a while if it has just happened.
func _put_out(now: bool) -> void:
	if _flame == null:
		return
	_flame.visible = false
	_light.visible = false
	if now:
		_smoke = 6.0


func douse() -> void:
	set_state(0)


func _process(delta: float) -> void:
	_clock += delta
	if _flame and _flame.visible:
		# A guttering flicker, in size and light.
		var f := 1.0 + 0.12 * sin(_clock * 13.0) + 0.08 * sin(_clock * 7.3 + 1.0)
		_flame.scale = Vector3(_flame_size, _flame_size * f, _flame_size)
		_flame.rotation.y += delta * 0.6
		_light.light_energy = 2.0 + 0.5 * sin(_clock * 11.0)
	if _glint:
		# A slow twinkle over the journal (or bottle) so it can be found.
		var t := 0.5 + 0.5 * sin(_clock * 3.0)
		_glint.scale = Vector3.ONE * (0.3 + 0.7 * t)
		_glint.visible = t > 0.25
	if _topple > 0.0 and _topple < 1.0:
		# A shot-down bell's gallows keels over.
		_topple = minf(1.0, _topple + delta * 2.0)
		_body.rotation.z = 1.4 * _topple * _topple
	if _spark and _spark.visible:
		_spark.scale = Vector3.ONE * (0.6 + 0.6 * absf(sin(_clock * 31.0)))
	if kind == StoryObject.Kind.BOTTLE:
		# Riding the waves, rolling a little.
		var p := global_position
		var game := get_parent() as Game
		var t := game.render_time if game else _clock
		global_position = Vector3(p.x, Waves.height(p.x, p.z, t) - 0.03, p.z)
		_body.rotation = Vector3(0.25 * sin(_clock * 1.3), _clock * 0.2, 0.2 * sin(_clock * 0.9))
	if _smoke > 0.0:
		_smoke -= delta
		if Engine.get_process_frames() % 12 == 0:
			var game := get_parent() as Game
			if game and game.effects:
				game.effects.smoke(global_position + Vector3(0, 0.4, 0))

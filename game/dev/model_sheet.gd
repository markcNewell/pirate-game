class_name ModelSheet
extends Node3D
## A contact sheet for checking a Blender model in the game's own light and ink: the model
## from several sides, or an animation's poses in a row, on a sand-coloured disc.
## Run through tools/model_sheet.sh; main.gd starts it for --model-sheet NAME.
##
##   --sheet-anim NAME     show this animation's poses (front row and side row) instead of turning
##   --sheet-frames N      how many poses (default 6)
##   --sheet-anims A,B,..  one pose from each of these animations (at --sheet-at, default 0.3)
##   --sheet-views N       how many sides when turning (default 5: front, quarters, side, back)
##   --sheet-focus LO,HI   frame only heights LO..HI (metres), e.g. 1.4,2.1 for a head
##   --sheet-recolor 1     paint the shirt red and the skin a light tone (player models)
##   --sheet-only A,B      show only the meshes with these names (e.g. body,look0)
##   --sheet-palette N     ship slot colours: 0 plain, 1-4 a crew's, 5 the skeleton ship's
##   --sheet-cam X,Y,Z --sheet-look X,Y,Z [--sheet-fov DEG]   one close-up, camera placed by hand
##   --sheet-tilt DEG      how far the camera looks down (default 12)
##   --sheet-noink, --sheet-noshadow, --sheet-normals N   for checking the outline and light

var _args: Dictionary


func _init(args: Dictionary) -> void:
	_args = args


func _ready() -> void:
	var model: String = _args["model-sheet"]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b9d9f2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9cc8f0")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_color = Color("fff6e5")
	sun.light_energy = 0.9
	sun.shadow_enabled = not _args.has("sheet-noshadow")
	# The game's own shadow settings (World._sun), so acne shows here if it would there.
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 2.5
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	var recolor := {}
	if _args.has("sheet-recolor"):
		recolor = {
			Models.SHIRT: Color("d63c3c"), Models.SHIRT_DARK: Color("d63c3c").darkened(0.3),
			Models.SKIN: Color("f2c49b"), Models.SKIN_DARK: Color("f2c49b").darkened(0.25),
		}
	if _args.has("sheet-palette"):
		# Ship models: 0 the plain palette, 1-4 a crew's colours, 5 the skeleton ship's.
		var n := int(_args["sheet-palette"])
		var pal: Dictionary = Toon.SKELETON if n == 5 else (Toon.crew_palette(n) if n > 0 else {})
		recolor.merge(Models.palette_recolor(pal), true)
	var anim: String = _args.get("sheet-anim", "")
	var poses: Array = []
	var anims: PackedStringArray = []
	if _args.has("sheet-anims"):
		# One pose from each of several animations, a third of the way in, from the front quarter.
		anims = str(_args["sheet-anims"]).split(",")
		for i in anims.size():
			poses.append([0.6, float(_args.get("sheet-at", 0.3))])
	elif anim != "":
		var n := int(_args.get("sheet-frames", 6))
		for row: float in [0.35, PI / 2.0]:
			for i in n:
				poses.append([row, float(i) / n])
	else:
		var n := int(_args.get("sheet-views", 5))
		for i in n:
			poses.append([PI * i / maxf(1.0, n - 1.0) * (1.0 if n > 1 else 0.0), 0.0])

	if _args.has("sheet-cam"):
		_studio(model, recolor)
		return
	var probe := _make(model, recolor)
	var box := _bounds(probe)
	probe.free()
	var focus := Vector2(box.position.y, box.end.y)
	if _args.has("sheet-focus"):
		var f: PackedStringArray = str(_args["sheet-focus"]).split(",")
		focus = Vector2(float(f[0]), float(f[1]))
	var width := maxf(box.size.x, box.size.z) * 1.15 + 0.1
	if _args.has("sheet-focus"):
		# A close-up: columns as wide as the focus band is tall (neighbours may overlap).
		width = (focus.y - focus.x) * 1.1
	var cols := int(_args.get("sheet-frames", 6)) if anim != "" and anims.is_empty() else poses.size()
	var rows := 2 if anim != "" and anims.is_empty() else 1
	for i in poses.size():
		var col := i % cols
		var row := i / cols
		var holder := Node3D.new()
		holder.position = Vector3((col - (cols - 1) * 0.5) * width, -row * (focus.y - focus.x) * 1.15, 0)
		add_child(holder)
		var inst := _make(model, recolor)
		# Models face -Z; the camera looks from +Z, so turn them round to face it first.
		inst.rotation.y = PI + poses[i][0]
		holder.add_child(inst)
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = width * 0.42
		cyl.bottom_radius = width * 0.42
		cyl.height = 0.04
		disc.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("e6c88c")
		disc.material_override = m
		disc.position.y = box.position.y - 0.02
		holder.add_child(disc)
		if anim != "" or not anims.is_empty():
			var player: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
			player.play(anims[i] if not anims.is_empty() else anim)
			player.seek(player.current_animation_length * poses[i][1], true)
			player.pause()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var vp := get_viewport().get_visible_rect().size
	var span_x := width * cols
	var span_y := (focus.y - focus.x) * 1.15 * rows
	cam.size = maxf(span_y, span_x * vp.y / vp.x) * 1.04
	var centre_y := (focus.x + focus.y) * 0.5 - (rows - 1) * (focus.y - focus.x) * 1.15 * 0.5
	var tilt := deg_to_rad(float(_args.get("sheet-tilt", 12.0)))
	var target := Vector3(0, centre_y, 0)
	# As near as a perspective camera showing this much would be, so the ink outline (which
	# thickens with distance) is drawn as thick as in the game.
	var reach := maxf(cam.size / 1.15, box.size.length() * 0.5 + 0.5)
	cam.position = target + Vector3(0, sin(tilt), cos(tilt)) * reach
	cam.near = 0.02
	cam.far = reach * 3.0
	add_child(cam)
	cam.look_at(target)
	cam.make_current()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var path: String = _args.get("screenshot", "user://sheet.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("sheet saved to %s" % path)
	get_tree().quit()


## One copy of the model and a perspective camera placed by hand, for close-ups:
## --sheet-cam X,Y,Z --sheet-look X,Y,Z [--sheet-fov DEG], in the model's own coordinates.
func _studio(model: String, recolor: Dictionary) -> void:
	var inst := _make(model, recolor)
	add_child(inst)
	var cam := Camera3D.new()
	cam.fov = float(_args.get("sheet-fov", 50.0))
	cam.near = 0.05
	cam.far = 500.0
	add_child(cam)
	cam.look_at_from_position(_vec(_args["sheet-cam"]), _vec(_args.get("sheet-look", "0,0,0")))
	cam.make_current()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var path: String = _args.get("screenshot", "user://sheet.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("sheet saved to %s" % path)
	get_tree().quit()


static func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _make(model: String, recolor: Dictionary) -> Node3D:
	var inst := Models.instance(model, recolor)
	if _args.has("sheet-noink"):
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			var m: ShaderMaterial = mi.material_override.duplicate()
			m.next_pass = null
			mi.material_override = m
	if _args.has("sheet-normals"):
		Models.outline_material(true).set_shader_parameter("normal_source", int(_args["sheet-normals"]))
	if _args.has("sheet-only"):
		var keep: PackedStringArray = str(_args["sheet-only"]).split(",")
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			if not keep.has(String(mi.name)):
				mi.free()
	return inst


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var b := mi.get_aabb()
		b = _node_transform(mi, root) * b
		box = b if first else box.merge(b)
		first = false
	return box


func _node_transform(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

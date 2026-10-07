class_name Models
extends RefCounted
## Models made in Blender (art/blender/*.py, exported to art/models/*.glb), ready for the toon
## look: every mesh gets the toon material and the ink outline, and its colours can be swapped
## for a player's own (shirt and skin markers).
##
## The outline needs a smoothed normal per vertex, so hard corners get a closed line. Static
## models carry it in CUSTOM0, like MeshBuilder meshes. Animated (skinned) models push their
## outline along the real normals instead, which bend with the bones; they are modelled smooth
## so that is closed too. (Tangents would bend as well, but the GL renderer mangles them on
## skinned meshes.) Vertex alpha holds baked crease shadow (see toon.gdshader).

## Marker colours painted in Blender (art/blender/kit.py) and what they stand for.
const SHIRT := Color("ff00ff")
const SHIRT_DARK := Color("b000b0")
const SKIN := Color("00ffff")
const SKIN_DARK := Color("00b0b0")

## Ship parts are painted in one marker colour per palette slot (kit.slot in Blender), swapped
## here for the ship's palette: Toon.PALETTE with a crew's or the skeleton ship's overrides.
const SLOTS := ["hull", "hull_dark", "bottom", "stripe", "deck", "rail", "mast", "rope", "trim",
	"sail", "flag", "bone", "lantern", "gold", "iron"]

static var _scenes := {}
static var _parts := {}
## Static meshes with more triangles than this get levels of detail.
const LOD_MIN_TRIANGLES := 4000
static var _meshes := {}
static var _materials := {}
## Per source surface ("id/surface"): its arrays with outline normals in place, made once and
## shared by every recolouring (only the colours differ).
static var _base := {}
## A headless process (the server, test bots) never draws: models load as they are, without
## the outline normals, recolouring or levels of detail that only matter on screen.
static var headless := DisplayServer.get_name() == "headless"


## The recolour map from slot markers to a palette's colours (missing slots: Toon.PALETTE).
static func palette_recolor(palette: Dictionary) -> Dictionary:
	var out := {}
	for i in SLOTS.size():
		var marker := Color8(0xf0, 16 + 8 * i, 0xf1)
		var name: String = SLOTS[i]
		out[marker] = palette.get(name, Toon.PALETTE[name] if Toon.PALETTE.has(name) else Color.MAGENTA)
	return out


## A fresh copy of a model, toon-ready. `recolor` maps marker colours to real ones. With `keep`,
## only the meshes of those names are kept (one look of several), and only they are prepared.
static func instance(model: String, recolor := {}, keep: Array = []) -> Node3D:
	var root: Node3D = _scene(model).instantiate()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not keep.is_empty() and not keep.has(String(mi.name)):
			mi.free()
			continue
		mi.mesh = _prepared(mi.mesh, recolor)
		mi.material_override = material(mi.skin != null)
	return root


## The first mesh of a model, toon-ready (for static props built into bigger meshes).
static func mesh(model: String, recolor := {}) -> ArrayMesh:
	var root: Node = _scene(model).instantiate()
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var m := _prepared(mi.mesh, recolor)
	root.free()
	return m


## One named mesh from a model holding several parts (a ship's sails, wheel...), toon-ready.
static func part(model: String, name: String, recolor := {}) -> ArrayMesh:
	var key := "%s/%s" % [model, name]
	if not _parts.has(key):
		var root: Node = _scene(model).instantiate()
		var found: MeshInstance3D = root.find_child(name, true, false)
		_parts[key] = found.mesh if found else null
		root.free()
	var source: Mesh = _parts[key]
	assert(source != null, "%s has no part %s" % [model, name])
	return _prepared(source, recolor)


## Toon lighting plus the ink outline (for a skinned mesh, or a static one).
static func material(skinned := false) -> ShaderMaterial:
	if not _materials.has(skinned):
		var m := ShaderMaterial.new()
		m.shader = load("res://art/shaders/toon.gdshader")
		m.next_pass = outline_material(skinned)
		_materials[skinned] = m
	return _materials[skinned]


static func outline_material(skinned := false) -> ShaderMaterial:
	var key := "ink%s" % skinned
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://art/shaders/outline.gdshader")
		m.set_shader_parameter("normal_source", 2 if skinned else 0)
		_materials[key] = m
	return _materials[key]


static func _scene(model: String) -> PackedScene:
	if not _scenes.has(model):
		_scenes[model] = load("res://art/models/%s.glb" % model)
	return _scenes[model]


static func _prepared(source: Mesh, recolor: Dictionary) -> ArrayMesh:
	if headless:
		return source as ArrayMesh
	var key := "%d/%s" % [source.get_instance_id(), str(recolor)]
	if not _meshes.has(key):
		_meshes[key] = prepare(source, recolor)
	return _meshes[key]


## A copy of `source` with outline normals in CUSTOM0 and marker colours swapped.
static func prepare(source: Mesh, recolor := {}) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in source.get_surface_count():
		var base: Dictionary = _base_surface(source, s)
		var arrays: Array = base.arrays.duplicate()
		if not recolor.is_empty():
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR].duplicate()
			var lookup := {}
			for marker: Color in recolor:
				lookup[_key(marker)] = recolor[marker]
			for i in colors.size():
				var c := colors[i]
				var to: Variant = lookup.get(_key(c))
				if to != null:
					colors[i] = Color(to.r, to.g, to.b, c.a)
			arrays[Mesh.ARRAY_COLOR] = colors
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], base.lods, base.flags)
	return out


## One source surface made toon-ready once: colours filled in, outline normals in CUSTOM0
## (with each part's ink weight), the ink UVs dropped, levels of detail for big static ones.
static func _base_surface(source: Mesh, surface: int) -> Dictionary:
	var key := "%d/%d" % [source.get_instance_id(), surface]
	if _base.has(key):
		return _base[key]
	var arrays := source.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	if colors.is_empty():
		colors.resize(verts.size())
		colors.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = colors
	var ink: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	arrays[Mesh.ARRAY_CUSTOM0] = _outline_normals(verts, normals, ink)
	arrays[Mesh.ARRAY_TEX_UV] = null
	var flags := Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	if bones != null and weights != null and weights.size() == verts.size() * 8:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var lods := {}
	if bones == null:
		lods = _lods_for(arrays, flags)
	_base[key] = {"arrays": arrays, "flags": flags, "lods": lods}
	return _base[key]


## Simplified versions of a big static surface for drawing far off (Godot's own simplifier).
static func _lods_for(arrays: Array, flags: int) -> Dictionary:
	var lods := {}
	var indices = arrays[Mesh.ARRAY_INDEX]
	var triangles: int = (indices.size() if indices != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	if indices != null and triangles > LOD_MIN_TRIANGLES:
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, null, "", flags)
		im.generate_lods(25.0, 60.0, [])
		for i in im.get_surface_lod_count(0):
			lods[im.get_surface_lod_size(0, i)] = im.get_surface_lod_indices(0, i)
	return lods


## A colour's 8-bit RGB as one number, for exact lookups (vertex colours arrive as bytes).
static func _key(c: Color) -> int:
	return (roundi(c.r * 255.0) << 16) | (roundi(c.g * 255.0) << 8) | roundi(c.b * 255.0)


## One smoothed normal per position, so hard-edged corners get a closed outline, its length
## the outline's weight there (the U of the model's UV, from kit.noink in Blender).
static func _outline_normals(verts: PackedVector3Array, normals: PackedVector3Array, ink: PackedVector2Array) -> PackedFloat32Array:
	var sums := {}
	for i in verts.size():
		var key := verts[i].snappedf(0.0005)
		sums[key] = sums.get(key, Vector3.ZERO) + normals[i]
	var out := PackedFloat32Array()
	out.resize(verts.size() * 3)
	for i in verts.size():
		var n: Vector3 = sums[verts[i].snappedf(0.0005)]
		n = n.normalized() if n.length_squared() > 1e-8 else normals[i]
		if not ink.is_empty():
			n *= clampf(ink[i].x, 0.0, 1.0)
		out[i * 3] = n.x
		out[i * 3 + 1] = n.y
		out[i * 3 + 2] = n.z
	return out

class_name LootView
extends Node3D
## How a chest or a supply barrel looks. Chests come in three finishes by value:
## plain wood, wood bound in silver, and a red captain's chest bound in gold.

static var _meshes := {}


static func mesh_for(kind: int, tier: int) -> ArrayMesh:
	var key := "%d/%d" % [kind, tier]
	if not _meshes.has(key):
		_meshes[key] = _barrel() if kind == Loot.Kind.BARREL else _chest(tier)
	return _meshes[key]


func setup(kind: int, value: int) -> LootView:
	add_child(Toon.instance(mesh_for(kind, Loot.chest_tier(value))))
	return self


static func _chest(tier: int) -> ArrayMesh:
	var b := MeshBuilder.new()
	var wood: Color = [Color("8a5a32"), Color("7a4a2a"), Color("8f2f24")][tier]
	var metal: Color = [Color("3a2c22"), Color("c9d2dc"), Color("ffd23a")][tier]
	b.box(Vector3(0, 0.22, 0), Vector3(0.42, 0.22, 0.28), wood)
	b.box(Vector3(0, 0.52, 0), Vector3(0.43, 0.09, 0.29), wood.lightened(0.08))
	for x: float in [-0.3, 0.3]:
		b.box(Vector3(x, 0.32, 0), Vector3(0.04, 0.31, 0.3), metal)
	b.box(Vector3(0, 0.44, -0.3), Vector3(0.07, 0.08, 0.025), metal)
	if tier == 2:
		b.box(Vector3(0, 0.62, 0), Vector3(0.44, 0.02, 0.3), metal)
	return b.build()


static func _barrel() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.cylinder(Vector3(0, 0, 0), Vector3(0, 0.45, 0), 0.34, 0.4, 10, Color("9a6838"))
	b.cylinder(Vector3(0, 0.45, 0), Vector3(0, 0.9, 0), 0.4, 0.34, 10, Color("9a6838"))
	for h: float in [0.15, 0.7]:
		b.cylinder(Vector3(0, h, 0), Vector3(0, h + 0.07, 0), 0.4, 0.4, 10, Color("2a1e1a"))
	b.cylinder(Vector3(0, 0.9, 0), Vector3(0, 0.95, 0), 0.3, 0.3, 10, Color("c99a5b"))
	return b.build()

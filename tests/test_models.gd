extends "res://tests/support/case.gd"


## Every Blender export loads, and comes out toon-ready: coloured vertices and outline normals.
func test_every_model_loads() -> void:
	var names: Array[String] = []
	for file in DirAccess.get_files_at("res://art/models"):
		if file.ends_with(".glb"):
			names.append(file.get_basename())
	check(names.size() > 0, "there are models in art/models")
	for name in names:
		var root := Models.instance(name)
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() > 0, "%s has a mesh" % name)
		for mi: MeshInstance3D in meshes:
			var arrays := mi.mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_COLOR] != null, "%s/%s has vertex colours" % [name, mi.name])
			check(arrays[Mesh.ARRAY_CUSTOM0] != null, "%s/%s has outline normals" % [name, mi.name])
			check(mi.material_override is ShaderMaterial, "%s/%s has the toon material" % [name, mi.name])
		root.free()


## The pirate has every animation and bone the avatar code asks for.
func test_pirate_has_what_avatars_use() -> void:
	var root := Models.instance("pirate")
	var player: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	for name: String in Avatar.BASES + Avatar.LOOPS + ["slash", "shoot", "hurt"]:
		check(player.has_animation(name), "pirate has the %s animation" % name)
	var skeleton: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	for bone: String in Avatar.UPPER + ["root", "hips", "thigh_r", "shin_l", "foot_r"]:
		check(skeleton.find_bone(bone) >= 0, "pirate has the %s bone" % bone)
	for look in 4:
		check(root.find_child("look%d" % look, true, false) != null, "pirate has look %d" % look)
	root.free()


## An avatar builds, keeps only its own look, and takes every state without errors.
func test_avatar_builds_and_takes_states() -> void:
	var avatar := Avatar.new("Test", 5)
	var looks := avatar.find_children("look*", "MeshInstance3D", true, false)
	check(looks.size() == 1 and looks[0].name == "look1", "player 5 wears look 1 only")
	avatar.set_state(ShipShape.Kind.WHEEL, false, false, Avatar.Act.NONE)
	avatar.set_state(-1, true, false, Avatar.Act.NONE)
	avatar.set_state(-1, false, true, Avatar.Act.DIG)
	avatar.set_weapon(Weapons.Kind.PISTOL)
	avatar.attack()
	avatar.hurt()
	avatar.set_bucket(true)
	avatar.set_pitch(0.4)
	avatar.free()


## The Blender scripts build the ship on a copy of ShipShape's numbers (art/blender/
## shipshape.py); if one changes without the other the model drifts off the decks you walk on.
func test_blender_ship_layout_matches_the_game() -> void:
	var text := FileAccess.get_file_as_string("res://art/blender/shipshape.py")
	check(text != "", "shipshape.py is readable")
	var game := {
		"HALF_LENGTH": ShipShape.HALF_LENGTH, "BEAM": ShipShape.BEAM, "KEEL_Y": ShipShape.KEEL_Y,
		"DECK_Y": ShipShape.DECK_Y, "BOW_DECK_Z": ShipShape.BOW_DECK_Z, "STERN_Z": ShipShape.STERN_Z,
		"RAIL_HEIGHT": ShipShape.RAIL_HEIGHT, "RAIL_THICKNESS": ShipShape.RAIL_THICKNESS,
		"QUARTER_Z": ShipShape.QUARTER_Z, "QUARTER_Y": ShipShape.QUARTER_Y,
		"STAIR_BOTTOM_Z": ShipShape.STAIR_BOTTOM_Z, "STAIR_HALF_WIDTH": ShipShape.STAIR_HALF_WIDTH,
		"LOWER_Y": ShipShape.LOWER_Y, "LOWER_Z0": ShipShape.LOWER_Z0, "LOWER_Z1": ShipShape.LOWER_Z1,
		"WALL_INSET": ShipShape.WALL_INSET, "HATCH_Z0": ShipShape.HATCH_Z0,
		"HATCH_Z1": ShipShape.HATCH_Z1, "HATCH_X": ShipShape.HATCH_X, "COAMING": ShipShape.COAMING,
		"MAST_RADIUS": ShipShape.MAST_RADIUS, "LADDER_Z": ShipShape.LADDER_Z,
		"LADDER_GAP": ShipShape.LADDER_GAP, "CANNON_PIVOT_INSET": ShipShape.CANNON_PIVOT_INSET,
		"CANNON_HEIGHT": ShipShape.CANNON_HEIGHT, "BARREL_LENGTH": ShipShape.BARREL_LENGTH
	}
	var re := RegEx.create_from_string("(?m)^([A-Z_0-9]+) = (-?[0-9.]+)$")
	var found := {}
	for m in re.search_all(text):
		found[m.get_string(1)] = float(m.get_string(2))
	for name: String in game:
		var ours: float = game[name]
		check(found.has(name) and absf(found[name] - ours) < 1e-6, "%s: game %s, Blender %s" % [name, ours, found.get(name, "missing")])
	check(text.contains("0.92 * max(0.0, -t) ** 2 - 0.25 * max(0.0, t) ** 4"), "half_width's formula is the game's")

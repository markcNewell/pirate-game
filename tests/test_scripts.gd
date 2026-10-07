extends "res://tests/support/case.gd"


## Every script in game/ compiles, including ones nothing else loads in the tests (main.gd,
## dev tools): a parse error there would only show when the game is started.
func test_every_script_compiles() -> void:
	var found := 0
	for path in _scripts("res://game"):
		var script: Script = load(path)
		check(script != null and script.can_instantiate(), "%s loads" % path)
		found += 1
	check(found > 30, "found the game's scripts (%d)" % found)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	return out

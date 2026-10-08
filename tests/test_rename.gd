extends "res://tests/support/case.gd"
## Sea of Slop was Pirate Game: saves from before the rename come across once.


func test_the_old_save_comes_across_once() -> void:
	var here := OS.get_user_data_dir()
	var old_name := "Sea of Slop rename test %d" % Time.get_ticks_usec()
	var old := here.get_base_dir().path_join(old_name)
	DirAccess.make_dir_recursive_absolute(old.path_join("profiles"))
	var f := FileAccess.open(old.path_join("profiles").path_join("anne.json"), FileAccess.WRITE)
	f.store_string('{"name": "Anne"}')
	f.close()
	var had_settings := FileAccess.file_exists(Settings.PATH)
	if had_settings:
		check(not Settings.bring_old_save_across(old_name), "nothing copied over a save that is already here")
	else:
		check(Settings.bring_old_save_across(old_name), "copied when there is no save yet")
		check(FileAccess.file_exists("user://profiles/anne.json"), "the pirates came across")
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profiles/anne.json"))
	DirAccess.remove_absolute(old.path_join("profiles").path_join("anne.json"))
	DirAccess.remove_absolute(old.path_join("profiles"))
	DirAccess.remove_absolute(old)
	check_eq(ProjectSettings.get_setting("application/config/name"), "Sea of Slop", "the game's new name")

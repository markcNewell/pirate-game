extends "res://tests/support/case.gd"
## The score (docs/specs/2026-10-08-m23-music.md): which music fits what is around you.


func test_calm_seas_by_day_and_by_night() -> void:
	check_eq(Music.pick({}), Music.Mood.DAY, "nothing about: sailing by day")
	check_eq(Music.pick({"night": true}), Music.Mood.NIGHT, "and by night")
	check_eq(Music.pick({"storm": 0.8}), Music.Mood.STORM, "in a storm")
	check_eq(Music.pick({"storm": 0.2}), Music.Mood.DAY, "not at its edge")
	check_eq(Music.pick({"port": true}), Music.Mood.NONE, "at Port Merrow the tavern plays instead")


func test_danger_comes_first_boss_highest() -> void:
	check_eq(Music.pick({"dead": true, "night": true}), Music.Mood.DEAD, "the dead close by")
	check_eq(Music.pick({"battle": true, "dead": true}), Music.Mood.BATTLE, "a skeleton ship beats a few skeletons")
	check_eq(Music.pick({"boss": true, "battle": true, "storm": 1.0}), Music.Mood.BOSS, "a boss beats everything")
	check_eq(Music.pick({"battle": true, "port": true}), Music.Mood.BATTLE, "even in port")


func test_danger_lingers_a_little() -> void:
	var since := {Music.Mood.BATTLE: 100.0}
	check_eq(Music.pick({"now": 105.0, "since": since}), Music.Mood.BATTLE, "five seconds after: still the battle")
	check_eq(Music.pick({"now": 100.0 + Music.LINGER[Music.Mood.BATTLE] + 0.5, "since": since}), Music.Mood.DAY, "then calm again")


func test_tracks_take_turns() -> void:
	var first := Music.next_track(Music.Mood.DAY, "")
	var second := Music.next_track(Music.Mood.DAY, first)
	check(first != second, "two tracks for sailing by day, in turn")
	check_eq(Music.next_track(Music.Mood.DAY, second), first, "and round again")
	check_eq(Music.next_track(Music.Mood.NONE, ""), "", "no music for no mood")


func test_every_track_is_there_and_credited() -> void:
	var names: Array = [Music.TAVERN, Music.STING]
	for mood: int in Music.TRACKS:
		names.append_array(Music.TRACKS[mood])
	for name: String in names:
		check(ResourceLoader.exists("res://art/music/%s.ogg" % name), "%s is in art/music" % name)
		check(Music.TITLES.has(name), "%s has its title for the credits" % name)
	var credits := FileAccess.get_file_as_string("res://CREDITS.md")
	for name: String in Music.TITLES:
		check(credits.contains("\"%s\"" % Music.TITLES[name]), "CREDITS.md credits %s" % Music.TITLES[name])

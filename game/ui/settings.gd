class_name Settings
extends RefCounted
## The few things the game remembers between runs, in user://settings.cfg.

const PATH := "user://settings.cfg"

static var name := ""
static var address := "127.0.0.1"
static var port := GameConfig.DEFAULT_PORT
static var sensitivity := 0.0025
## The crew asked for when joining: 0 any, else 1-4.
static var crew := 0
## Overall and music volume, 0-1.
static var volume := 0.8
static var music := 0.6
## A random code made on first launch and sent when joining, so servers keep your pirate's
## name (and level and gold) for you alone.
static var token := ""


static func load_saved() -> void:
	bring_old_save_across()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	name = cfg.get_value("player", "name", name)
	address = cfg.get_value("server", "address", address)
	port = cfg.get_value("server", "port", port)
	sensitivity = cfg.get_value("controls", "sensitivity", sensitivity)
	crew = cfg.get_value("player", "crew", crew)
	volume = cfg.get_value("sound", "volume", volume)
	music = cfg.get_value("sound", "music", music)
	token = cfg.get_value("player", "token", token)


## Until 0.4 the game was called "Pirate Game", and Godot keeps each game's saves in a folder
## named after it: your settings, your token (so servers know your pirate) and a host's saved
## pirates. Copy them across once, the first time Sea of Slop finds nothing of its own.
static func bring_old_save_across(old_name := "Pirate Game") -> bool:
	var here := OS.get_user_data_dir()
	var old := here.get_base_dir().path_join(old_name)
	if FileAccess.file_exists(PATH) or not DirAccess.dir_exists_absolute(old):
		return false
	_copy_tree(old, here)
	print("[settings] brought settings and pirates across from %s" % old)
	return true


static func _copy_tree(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for file in DirAccess.get_files_at(from):
		if not FileAccess.file_exists(to.path_join(file)):
			DirAccess.copy_absolute(from.path_join(file), to.path_join(file))
	for dir in DirAccess.get_directories_at(from):
		_copy_tree(from.path_join(dir), to.path_join(dir))


## The token, made (and saved) the first time it is needed.
static func get_token() -> String:
	if token == "":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in 16:
			token += "%02x" % rng.randi_range(0, 255)
		save()
	return token


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", name)
	cfg.set_value("server", "address", address)
	cfg.set_value("server", "port", port)
	cfg.set_value("controls", "sensitivity", sensitivity)
	cfg.set_value("player", "crew", crew)
	cfg.set_value("sound", "volume", volume)
	cfg.set_value("sound", "music", music)
	cfg.set_value("player", "token", token)
	cfg.save(PATH)

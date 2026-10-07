class_name Settings
extends RefCounted
## The few things the game remembers between runs, in user://settings.cfg.

const PATH := "user://settings.cfg"

static var name := ""
static var address := "127.0.0.1"
static var port := GameConfig.DEFAULT_PORT
static var sensitivity := 0.0025


static func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	name = cfg.get_value("player", "name", name)
	address = cfg.get_value("server", "address", address)
	port = cfg.get_value("server", "port", port)
	sensitivity = cfg.get_value("controls", "sensitivity", sensitivity)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", name)
	cfg.set_value("server", "address", address)
	cfg.set_value("server", "port", port)
	cfg.set_value("controls", "sensitivity", sensitivity)
	cfg.save(PATH)

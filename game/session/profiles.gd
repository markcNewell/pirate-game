class_name Profiles
extends RefCounted
## What the server remembers about each pirate name between sessions: XP, gold, standing with
## the companies, titles and chapters done. One JSON file per name in `dir`; with no dir they
## live only in memory (tests). A token sent on joining keeps a name to whoever made it.

## Saves wait this long after a change, so a busy fight writes once (s).
const SAVE_DELAY := 5.0

var dir := ""
## XP and standing every new profile starts with (test hooks).
var start_xp := 0
var start_rep := 0
## Test hooks (--gold, --blade, --gun): what a new pirate starts with.
var start_gold := 0
var start_blade := 0
var start_gun := 0
var _profiles := {}  # key -> profile Dictionary
var _dirty := {}  # key -> true
var _save_at := -1.0


func _init(save_dir := "", first_xp := 0) -> void:
	dir = save_dir
	start_xp = first_xp
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)


## The file-safe key for a name: lower case, letters and digits, the rest as "_".
static func key_for(player_name: String) -> String:
	var out := ""
	for ch in player_name.strip_edges().to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	return out if out != "" else "_"


static func blank(player_name: String, token: String, xp := 0) -> Dictionary:
	return {
		"name": player_name, "token": token, "xp": xp, "gold": 0, "rep": [0, 0, 0],
		"titles": [], "title": "", "chapters": [], "deeds": {}, "owned": [], "look": -1, "dye": -1,
		"blade": 0, "gun": 0, "armour": 0, "ship": [0, 0, 0],
	}


## "" if `player_name` may join with `token`, else why not.
func check(player_name: String, token: String) -> String:
	var p := _load(key_for(player_name))
	if p.is_empty() or str(p.token) == "" or str(p.token) == token:
		return ""
	return "That name belongs to another pirate on this server. Pick another name."


## The profile for a name, made on first use (and claimed by `token` if it had none).
func get_or_make(player_name: String, token: String) -> Dictionary:
	var key := key_for(player_name)
	var p := _load(key)
	if p.is_empty():
		p = blank(player_name, token, start_xp)
		p.rep = [start_rep, start_rep, start_rep]
		p.gold = start_gold
		p.blade = start_blade
		p.gun = start_gun
		_profiles[key] = p
		changed(player_name)
	elif str(p.token) == "" and token != "":
		p.token = token
		changed(player_name)
	return p


func has(player_name: String) -> bool:
	return not _load(key_for(player_name)).is_empty()


## Mark a profile for saving soon.
func changed(player_name: String) -> void:
	_dirty[key_for(player_name)] = true


## Write changed profiles once SAVE_DELAY has passed since the first change (`now` in s).
func tick(now: float) -> void:
	if _dirty.is_empty():
		_save_at = -1.0
		return
	if _save_at < 0.0:
		_save_at = now + SAVE_DELAY
	elif now >= _save_at:
		flush()


## Write every changed profile now.
func flush() -> void:
	_save_at = -1.0
	if dir == "":
		_dirty.clear()
		return
	for key: String in _dirty:
		if not _profiles.has(key):
			continue
		var f := FileAccess.open(dir.path_join(key + ".json"), FileAccess.WRITE)
		if f == null:
			push_warning("[profiles] cannot write %s" % key)
			continue
		f.store_string(JSON.stringify(_profiles[key], "\t"))
	_dirty.clear()


func _load(key: String) -> Dictionary:
	if _profiles.has(key):
		return _profiles[key]
	if dir == "":
		return {}
	var path := dir.path_join(key + ".json")
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[profiles] %s is not a profile; starting it afresh" % path)
		return {}
	# Fill in anything an older file lacks, and make numbers whole again (JSON reads floats).
	var p := blank(str(data.get("name", key)), str(data.get("token", "")))
	p.merge(data, true)
	p.xp = int(p.xp)
	p.gold = int(p.gold)
	p.look = int(p.look)
	p.dye = int(p.dye)
	var ship: Array = []
	for i in 3:
		ship.append(int(p.ship[i]) if i < p.ship.size() else 0)
	p.ship = ship
	var rep: Array = []
	for i in 3:
		rep.append(int(p.rep[i]) if i < p.rep.size() else 0)
	p.rep = rep
	_profiles[key] = p
	return p

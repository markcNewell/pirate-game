class_name ServerSim
extends RefCounted
## The authoritative world, run only on the server (dedicated or host): the ships and their
## damage, the skeleton captains, cannonballs in flight, the crew list and what each player
## is doing. Game feeds it ticks and player messages; it answers through Net.

## The first crew's ship id. Crew ships take their crew's number (1-4) as their id;
## skeleton ships are numbered from 10.
const CREW := 1
const MAX_CREWS := 4
const CREW_SIZE := 4
const CREW_NAMES := ["The Salty Maiden", "The Crimson Wren", "The Blue Petrel", "The Green Gull"]
const CREW_SPAWNS := [Vector2(0, 0), Vector2(180, 120), Vector2(-180, 120), Vector2(0, 260)]
## Test hook: crews start within boarding distance of each other.
const CREW_SPAWNS_CLOSE := [Vector2(0, 0), Vector2(45, 0), Vector2(-45, 0), Vector2(0, 45)]
const EMPTY_CREW_TIMEOUT := 60.0
const STATION_INPUT_TIMEOUT := 0.5
const MAX_PLAYER_SPEED := 15.0
const LADDER_TOLERANCE := 6.0
const HATCH_REACH := 2.6
const PATCH_REACH := 2.6
const PATCH_TIME := 2.0
const MAX_HOLES := 12
const PLAYER_RELOAD := 3.0
const CREW_RESPAWN_DELAY := 10.0
const AI_FIRST_DELAY := 60.0
const AI_RESPAWN_DELAY := 90.0
const AI_SPAWN_DISTANCE := 450.0
## Ships closer than this (between any of bow, middle and stern) are pushed apart.
const SHIP_CONTACT := 6.5
const ITEM_REACH := 3.0
const DIG_REACH := 3.0
const DIG_TIME := 2.0
const SELL_REACH := 4.0
const RESTOCK_SHIP_RANGE := 80.0
const OPEN_SHIP_RANGE := 60.0
const BARREL_BALLS := 15
const BARREL_PLANKS := 8
const MAP_TABLE_REACH := 3.0
const HEALTH := 100
const GHOST_TIME := 8.0
const BANANA_HEAL := 50
const EAT_REACH := 2.2
const CAMP_SIZE := 3
const CAMP_WAKE := 80.0
const CAMP_RESPAWN := 180.0
const SHIP_SKELETONS := 3
const ATTACK_SLACK := 0.1
## Attack targets at or above this id are the story's powder kegs (id - KEG_TARGET).
const KEG_TARGET := 10000000
const BELL_TARGET := 20000000
const LANTERN_TARGET := 30000000

var time := 0.0
var ships := {}  # ship id -> ShipState
var captains := {}  # ship id -> Captain (skeleton ships only)
var players := {}  # peer id -> record (see add_player)
var roster := {}  # peer id -> name
## Crews by number (1-4): {"mission" ({} or see _start_mission), "offers" (the board's last
## offers), "respawn_at", "empty_since"}. Gold and standing belong to each pirate's profile.
var crews := {}
## Pirates remembered between sessions (Profiles), and what others see of each player online:
## peer id -> [pirate level, title].
var profiles: Profiles
var tags := {}
## The story's chapters as they run (StoryRun), and what they put in the world.
var story: StoryRun
## World events for every crew (WorldEvents).
var world: WorldEvents
## The crew whose cannonball last struck each ship (for the XP when it sinks).
var _last_hit_by := {}
## When each pirate last earned XP for knocking down each other pirate: "a:b" -> time.
var _pvp_xp := {}
var station_owner := {}  # ship id * 100 + station id -> peer id
var station_input := {}  # peer id -> {axes, aim, time}
var projectiles: Array[Dictionary] = []
var stats := {
	"max_speed": 0.0, "stations_taken": 0, "climbs": 0, "corrections": 0, "shots": 0,
	"hits": 0, "holes": 0, "patched": 0, "bailed": 0, "ai_spawned": 0, "ai_sunk": 0, "crew_sunk": 0,
	"voyages": 0, "dug": 0, "sold": 0, "restocked": 0, "loot_spawned": 0, "stowed": 0,
	"kills": 0, "falls": 0, "eaten": 0, "boarded": 0, "skeleton_swings": 0, "pvp_falls": 0, "stolen": 0,
	"lightning": 0, "missions": 0, "delivered": 0, "skulls": 0, "xp": 0, "levels": 0,
	"chapters_started": 0, "chapters": 0, "doused": 0, "thefts": 0, "salted": 0, "explosions": 0,
	"galleons": 0, "blocked": 0, "given": 0, "broken": 0, "bells": 0, "gates": 0, "guns_silenced": 0,
	"dives": 0, "fort_shots": 0, "bought": 0, "refits": 0, "sieges": 0, "battery_shots": 0, "climbed": 0, "blinded": 0, "lanterns": 0,
	"alarms": 0, "lanterns_smashed": 0, "lunges": 0, "parried": 0, "reef_tears": 0,
	"blinks": 0, "braziers": 0, "beacons": 0, "slams": 0, "throws": 0, "joint_hits": 0, "crumbled": 0,
	"world_events": 0, "world_won": 0, "deeds": 0, "voice": 0, "ships_bought": 0,
}
var items := {}  # item id -> Loot
## Test hooks: the island missions go to (-1 for random), the mission kind the board always
## gives (-1 for the player's choice), and the level every crew starts at with each company.
var options_island := -1
var options_mission := -1
var options_level := 1
var _next_item := 1
var skeletons := {}  # skeleton id -> Skeleton
var camps := {}  # island index -> {"alive": int, "wake": time it may next wake}
var _next_skeleton := 1
var _passive := {}  # skeleton ships that only sit there (tests)
## Restock requests for the fort's barrels count from here (Port Merrow's are 0-2).
const FORT_BARRELS := 10
## What each crew's ship was last said to look like: crew -> [crew, sails, hull, flag, trophies].
var _ship_looks := {}
## Snapshots (snapshot_for): what each player was last sent of the slow-changing parts.
var _sent := {}
const INTEREST := 500.0
const REFRESH := 15
## Voice (docs/specs/2026-10-09-m25-voice.md): heard up to 40 m, so sent a little further, and
## no more packets a second from one player than this (a talker sends about 17).
const EARSHOT := 45.0
const VOICE_PER_SECOND := 25
## Each player's voice allowance: peer id -> [packets left, server time last topped up].
var _voice_allowance := {}
var _next_looks := 0.0
## Whether each pirate was last told the fort is their port: peer id -> bool.
var _fort_open := {}

var ai_enabled := true
var next_ai_time := AI_FIRST_DELAY
var _next_ship_id := 10
var _spawns: Array = CREW_SPAWNS
## Shipyards (docs/specs/2026-10-12-m26-shipyards.md): crews start on Merrow's pier with their
## ship moored there, and a sunk ship stays gone until the crew buys another. Off (`harbour`
## false), ships start at sea, as the tests expect. `first_hull`: a test hook (--sloop).
var harbour := false
## Test hook (--wreck-at YARD): a crew's ship starts on the bottom and its pirates in the water
## a short swim from that shipyard.
var options_wreck := -1
var first_hull := Hull.Type.GALLEON
var _next_projectile := 1
var _evacuated := {}
var _pending_bail := {}
var _rng := RandomNumberGenerator.new()
## The last lightning flash slot already judged for a strike.
var _last_flash := -1


func _init(options: Dictionary = {}) -> void:
	_rng.seed = 12345
	ai_enabled = not options.get("no-ai", false)
	Storm.enabled = not options.has("calm")
	next_ai_time = float(options.get("ai-delay", AI_FIRST_DELAY))
	if options.has("crews-close"):
		_spawns = CREW_SPAWNS_CLOSE
	# A real game starts at Port Merrow (main.gd asks for it); tests start at sea as before.
	harbour = options.has("harbour")
	options_wreck = int(options.get("wreck-at", -1))
	first_hull = Hull.Type.SLOOP if options.has("sloop") else Hull.Type.GALLEON
	# Test hooks: start near an island or the outpost, with a chest aboard.
	if options.has("voyage-island"):
		options_island = int(options["voyage-island"])
	if options.has("mission"):
		options_mission = ["treasure", "bounty", "cargo"].find(str(options["mission"]))
	options_level = clampi(int(options.get("rep", 1)), 1, Missions.MAX_LEVEL)
	profiles = Profiles.new(str(options.get("profiles", "")), int(options.get("xp", 0)))
	profiles.start_rep = (options_level - 1) * Missions.LEVEL_POINTS
	profiles.start_gold = int(options.get("gold", 0))
	profiles.start_blade = int(options.get("blade", 0))
	profiles.start_gun = int(options.get("gun", 0))
	profiles.start_armour = int(options.get("armour", 0))
	if options.has("done"):
		profiles.start_chapters = Array(str(options.done).split(","))
	story = StoryRun.new(self)
	world = WorldEvents.new(self)
	world.enabled = ai_enabled
	_ensure_crew(CREW)
	# Test hook: where the crew's ship starts (before any chapter, which may place things by it).
	if options.has("start-near"):
		var where := str(options["start-near"])
		if where in ["hulk", "reef", "maw"]:
			# Act IV and V: alongside the prison hulk in the fog, at the edge of the Black Reef, or
			# within cannon shot of the Maw (just outside the Reef's heart).
			var offsets := {"hulk": StoryRun.HULK_FOG + Vector2(-32.0, 10.0), "reef": Reef.CENTRE + Vector2(-210.0, 0.0), "maw": Reef.CENTRE + Vector2(-110.0, 0.0)}
			var at: Vector2 = offsets[where]
			crew_ship().x = at.x
			crew_ship().z = at.y
			crew_ship().yaw = -PI / 2.0
		else:
			var spot := Outpost.anchorage() if where == "outpost" else _anchorage(int(where))
			crew_ship().x = spot.x
			crew_ship().z = spot.z
			crew_ship().yaw = Captain.bearing(Vector2(spot.x, spot.z), _island_xz(where))
	# Test hook: the crew is already on a story chapter (from step --chapter-step, 0 = first).
	if options.has("chapter") and Story.index_of(str(options.chapter)) >= 0:
		story.start(CREW, Story.index_of(str(options.chapter)), int(options.get("chapter-step", 0)))
		# Test hook: the chapter's crates (Quill's salt) start on the crew's deck.
		if options.has("chapter-aboard"):
			var k := 0
			for id: int in crews[CREW].mission.items:
				if items.has(id) and items[id].kind == Loot.Kind.CRATE:
					items[id].state = Loot.State.ON_SHIP
					items[id].ship = CREW
					items[id].pos = Vector3(-1.2 + 1.0 * k, ShipShape.DECK_Y, -2.2)
					k += 1
		if options.has("jump"):
			_jump_to_chapter()
	if options.has("event"):
		# Test hook: a world event at once (green_fire, patrol, convoy, raid, fort, maw).
		var which := PlayTest.event_kind(str(options.event))
		if which != WorldEvents.Kind.NONE:
			world.start(which, Vector3(crew_ship().x, 0, crew_ship().z))
	if options.has("test-boarding"):
		_spawn_passive_skeleton_ship()
	if options.has("test-chest"):
		_new_item(Loot.Kind.CHEST, Loot.State.ON_SHIP, Vector3(-1.2, ShipShape.DECK_Y, -2.2), 250).ship = CREW
	if options.has("test-skull"):
		_new_item(Loot.Kind.SKULL, Loot.State.ON_SHIP, Vector3(-1.2, ShipShape.DECK_Y, -2.2), 300).ship = CREW
	if options.has("test-cargo"):
		# A cargo run to the mission island under way, its crate already on deck.
		var to := options_island if options_island >= 0 else Islands.mission_islands()[0]
		var offer := Missions.make_offer(Missions.Company.MERCHANT, options_level, Islands.mission_islands(), _rng, to)
		_start_mission(CREW, offer)
		for id in crews[CREW].mission.items:
			items[id].state = Loot.State.ON_SHIP
			items[id].ship = CREW
			items[id].pos = Vector3(-1.2, ShipShape.DECK_Y, -2.2)
	if options.has("test-steal"):
		# Crew 2 starts with a chest on its deck for crew 1 to steal (and stays put meanwhile).
		_ensure_crew(2)
		crews[2].pinned = true
		_new_item(Loot.Kind.CHEST, Loot.State.ON_SHIP, Vector3(-1.2, ShipShape.DECK_Y, -2.2), 300).ship = 2
	# Test hook: start with this many holes in the crew's ship.
	for i in int(options.get("test-holes", 0)):
		var h := ShipShape.hole_point(Vector3(1.0 if i % 2 == 0 else -1.0, 0.0, -6.0 + i * 1.5))
		crew_ship().holes.append([crew_ship().next_hole_id, h.x, h.y, h.z, 0.0])
		crew_ship().next_hole_id += 1


## A crew's ship (crew 1 by default).
func crew_ship(crew := CREW) -> ShipState:
	return ships.get(crew)


## The ship belonging to a player's crew.
func _own(r: Dictionary) -> ShipState:
	return ships.get(r.crew)


## Whether a crew has a ship afloat (a sunk one stays on the list, on the bottom, until the
## crew buys another at a shipyard).
func has_ship(crew: int) -> bool:
	return ships.has(crew) and not ships[crew].is_sinking()


## Whether the crew's ship is still at her berth by Merrow's pier.
func _moored_at_merrow(crew: int) -> bool:
	var s: ShipState = ships.get(crew)
	var b := Shipyards.merrow_berth(crew, Hull.of(s))
	return s != null and Vector2(s.x - b.x, s.z - b.z).length() < 20.0


## Puts a pirate on Merrow's pier by their crew's berth.
func _to_pier(id: int) -> void:
	var r: Dictionary = players[id]
	var n := 0
	for other in _crew_members(r.crew):
		if other != id and players[other].mode == LocalPlayer.Mode.WORLD and Outpost.on_pier(players[other].pos.x, players[other].pos.z):
			n += 1
	var spot := Shipyards.pier_spawn(r.crew, n)
	_teleport(id, LocalPlayer.Mode.WORLD, spot.pos, spot.yaw)


## E at a shipwright, buying a ship of `hull_type` (Hull.Type): the galleon for its price from
## the buyer's own gold, or the sloop free. One ship a crew: a crew with a galleon afloat can't
## buy one, and a sloop is broken up when her crew trades up. The new ship is moored at the
## yard with the buyer aboard (and anyone who was aboard the old one).
func _buy_ship(id: int, r: Dictionary, hull_type: int) -> void:
	if hull_type not in [Hull.Type.GALLEON, Hull.Type.SLOOP] or r.mode != LocalPlayer.Mode.WORLD:
		return
	var yard := Shipyards.at(r.pos)
	if yard < 0:
		return
	var wright := Shipyards.wright_name(yard)
	var hull := Hull.of_type(hull_type)
	var old: ShipState = ships.get(r.crew)
	var afloat := has_ship(r.crew)
	if afloat and (old.hull == Hull.Type.GALLEON or hull_type == Hull.Type.SLOOP):
		Net.send_message(id, "%s: \"You've a ship already. Sink her first, or trade a sloop up.\"" % wright)
		return
	var p: Dictionary = r.profile
	if int(p.gold) < hull.price:
		Net.send_message(id, "%s: \"A galleon's %d gold, and you've %d. The sloop's free.\"" % [wright, hull.price, int(p.gold)])
		return
	p.gold = int(p.gold) - hull.price
	var aboard: Array = []
	if afloat:
		for other in _crew_members(r.crew):
			if players[other].mode == LocalPlayer.Mode.ON_SHIP and players[other].ship == r.crew:
				aboard.append(other)
	var s := ShipState.new()
	s.crew = r.crew
	s.hull = hull_type
	var b := Shipyards.berth(yard, hull, r.crew)
	s.x = b.x
	s.z = b.z
	s.yaw = b.yaw
	for other in _crew_members(r.crew):
		_free_station_of(other)
	_put_crew_ship(r.crew, s)
	# Loot left aboard the old one comes across to the new deck.
	for item_id in items:
		var item: Loot = items[item_id]
		if item.state == Loot.State.ON_SHIP and item.ship == r.crew:
			item.pos = hull.cargo_spot + Vector3(0.6 * (item_id % 3), 0, 0)
	if not id in aboard:
		aboard.append(id)
	for other in aboard:
		_teleport(other, LocalPlayer.Mode.ON_SHIP, _free_spawn(other), 0.0)
	stats.ships_bought += 1
	var where: String = Shipyards.island(yard).name
	print("[server] %s bought a %s at %s for crew %d (%d gold)" % [r.name, hull.name, where, r.crew, hull.price])
	_tell_crew(r.crew, "%s bought us a %s at %s. All aboard!" % [r.name, hull.name, where])
	profiles.changed(r.name)
	_send_profile(id)


func _ensure_crew(crew: int) -> void:
	if crews.has(crew):
		return
	crews[crew] = {
		"mission": {}, "offers": [], "respawn_at": -1.0, "empty_since": -1.0, "pinned": false,
		"looks": [],
	}
	_launch_crew_ship(crew)


func _launch_crew_ship(crew: int) -> void:
	var s := ShipState.new()
	s.crew = crew
	s.hull = first_hull
	if harbour:
		var b := Shipyards.merrow_berth(crew, Hull.of(s))
		s.x = b.x
		s.z = b.z
		s.yaw = b.yaw
	else:
		var spot: Vector2 = _spawns[crew - 1]
		s.x = spot.x
		s.z = spot.y
	_put_crew_ship(crew, s)


## Makes `s` the crew's ship (a new one, or bought to replace a sunk one or a sloop): stocked
## for her size, with nobody at her stations.
func _put_crew_ship(crew: int, s: ShipState) -> void:
	if s.hull == Hull.Type.SLOOP:
		s.cannonballs = 0
		s.planks = 8
		s.bananas = 5
	ships[crew] = s
	_evacuated.erase(crew)
	for key in station_owner.keys():
		if key / 100 == crew:
			station_owner.erase(key)


func _crew_members(crew: int) -> Array:
	var out := []
	for id in players:
		if players[id].crew == crew:
			out.append(id)
	return out


func _tell_crew(crew: int, text: String) -> void:
	for id in _crew_members(crew):
		Net.send_message(id, text)


func crew_name(crew: int) -> String:
	return CREW_NAMES[crew - 1]


# =====================================================================================
# Ticking
# =====================================================================================

func tick(dt: float) -> void:
	time += dt
	profiles.tick(time)
	story.tick(dt)
	world.tick(dt)
	if time >= _next_looks:
		_next_looks = time + 1.0
		_send_ship_looks()
		_send_fort_ports()
	var wind := Game.wind_dir(time)
	_maybe_spawn_skeleton()
	_maybe_respawn_crews()
	_retire_empty_crews()

	for id in ships.keys():
		var s: ShipState = ships[id]
		var c := _crew_controls(id) if crews.has(id) else ShipControls.new()
		if captains.has(id) and not s.is_sinking() and not _passive.has(id):
			# Isabel's ship (flag 4) hunts the Admiral's ships, not yours.
			var foe := _nearest_enemy_ship(s) if s.flag == 4 else _nearest_crew_ship(s)
			var orders: Array = captains[id].think(s, foe, wind, time, dt, Islands.LAYOUT, c)
			for shot: Dictionary in orders:
				_fire(id, shot.gun, shot.yaw, shot.pitch, Captain.RELOAD * captains[id].reload_scale + _rng.randf())
		c.bail += _pending_bail.get(id, 0.0)
		_pending_bail.erase(id)
		# In the storm the wind swirls and gusts; its length is how hard it pushes.
		var gale := Storm.wind(Vector2(s.x, s.z), time, wind)
		ShipPhysics.step(s, c, gale.normalized(), dt, Islands.ship_blockers(), gale.length())
		if s.flag == 2 and s.sink > 0.0 and not story.act4.flagship_may_sink(id):
			# The Cuervo Negro only goes down when the story says so (the end of Act IV).
			s.sink = 0.0
			s.water = ShipPhysics.SINK_LEVEL - 0.3
	stats.max_speed = maxf(stats.max_speed, crew_ship().speed)

	_separate_ships()
	_lightning()
	_step_projectiles()
	_handle_sinking()
	_step_items(dt)
	_wake_camps()
	_step_skeletons(dt)
	_step_ghosts()


## Each new flash may strike the ship nearest the bolt among those deep in the storm: a hole
## below the mainmast and a hurt for anyone standing by it. Decided from the clock alone.
func _lightning() -> void:
	var f := Storm.flash(time)
	if not f.on or f.seed == _last_flash:
		return
	_last_flash = f.seed
	if not Storm.enabled or not Storm.strikes(f.seed):
		return
	var bolt: Vector2 = Storm.centre(time) + f.offset
	var target := -1
	var best := INF
	for id in ships:
		var s: ShipState = ships[id]
		var at := Vector2(s.x, s.z)
		if s.is_sinking() or Storm.amount(at, time) < Storm.STRIKE_DEPTH:
			continue
		if at.distance_to(bolt) < best:
			best = at.distance_to(bolt)
			target = id
	if target >= 0:
		_strike(target)


func _strike(ship_id: int) -> void:
	var s: ShipState = ships[ship_id]
	var hull := Hull.of(s)
	var tallest := hull.masts() - 1
	var mast := Vector3(0.0, hull.deck_y, hull.mast_z[tallest])
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	if s.holes.size() < MAX_HOLES:
		var h := hull.hole_point(Vector3(side, 0.0, mast.z + _rng.randf_range(-1.5, 1.5)))
		s.holes.append([s.next_hole_id, h.x, h.y, h.z, 0.0])
		s.next_hole_id += 1
	else:
		s.water = minf(hull.sink_level, s.water + 0.15)
	for id in players:
		var r: Dictionary = players[id]
		if r.mode == LocalPlayer.Mode.ON_SHIP and r.ship == ship_id and r.pos.distance_to(mast) < 4.0:
			_hurt_player(id, 25, "lightning")
	stats.lightning += 1
	var top := ShipPhysics.pose_of(s, time) * (mast + Vector3(0, hull.mast_height[tallest], 0))
	Net.send_event("lightning", [ship_id, top.x, top.y, top.z])
	if crews.has(ship_id):
		_tell_crew(ship_id, "Lightning strikes the mainmast! We're holed!")
	print("[server] lightning struck ship %d" % ship_id)


func _crew_controls(ship_id: int) -> ShipControls:
	var c := ShipControls.new()
	for key in station_owner:
		if key / 100 != ship_id:
			continue
		var id: int = key % 100
		var peer: int = station_owner[key]
		var input: Dictionary = station_input.get(peer, {})
		if input.is_empty() or time - input.time > STATION_INPUT_TIMEOUT:
			continue
		var axes: Vector2 = input.axes
		var st := Hull.of(ships.get(ship_id)).station(id)
		match st.get("kind", -1):
			ShipShape.Kind.WHEEL:
				c.wheel = axes.x
			ShipShape.Kind.SAILS:
				c.sail_raise[st.mast] = axes.y
				c.sail_turn[st.mast] = axes.x
			ShipShape.Kind.ANCHOR:
				c.anchor_winch = axes.y > 0.5
				c.anchor_drop = axes.y < -0.5
	return c


func snapshot() -> Array:
	var ship_list := []
	for id in ships:
		ship_list.append([id, ships[id].to_array()])
	var list := []
	for id in players:
		var r: Dictionary = players[id]
		list.append([
			id, r.mode, r.ship, r.pos.x, r.pos.y, r.pos.z, r.yaw, r.pitch, r.station, 1 if r.bucket else 0,
			r.carry, r.hp, 1 if r.dead_until >= 0.0 else 0, r.weapon, r.crew, _act(r),
		])
	var item_list := []
	for id in items:
		var item: Loot = items[id]
		if item.state != Loot.State.BURIED:
			item_list.append(item.to_array())
	var crew_list := []
	for c in crews:
		crew_list.append([c] + _mission_array(c))
	var bones := []
	for id in skeletons:
		bones.append(skeletons[id].to_array())
	var things := []
	for id in story.objects:
		things.append(story.objects[id].to_array())
	return [time, ship_list, list, item_list, crew_list, bones, things]


## One player's share of `snap` (docs/specs/2026-10-08-m24-lean-snapshots.md): skeletons and
## loot only within INTEREST of them (or on a ship within it, or carried), and the crews'
## missions and the story's objects only when they have changed since this player was last
## sent them, or every REFRESH snapshots in case one went astray.
func snapshot_for(snap: Array, id: int) -> Array:
	if not players.has(id):
		return snap
	var me := _world_pos(players[id])
	var near := func(x: float, z: float) -> bool:
		return Vector2(x - me.x, z - me.z).length() <= INTEREST
	var bones := []
	for entry: Array in snap[5]:
		var frame := int(entry[1])
		var s: ShipState = ships.get(frame)
		if (frame < 0 and near.call(entry[2], entry[4])) or (s and near.call(s.x, s.z)):
			bones.append(entry)
	var loot := []
	for entry: Array in snap[3]:
		var state := int(entry[2])
		var s: ShipState = ships.get(int(entry[9]))
		if state in [Loot.State.CARRIED, Loot.State.HELD] or (state == Loot.State.ON_SHIP and s and near.call(s.x, s.z)) \
				or (state not in [Loot.State.ON_SHIP] and near.call(entry[3], entry[5])):
			loot.append(entry)
	var sent: Dictionary = _sent.get(id, {})
	_sent[id] = sent
	var out := [snap[0], snap[1], snap[2], loot, null, bones, null]
	var refresh := int(sent.get("count", 0)) % REFRESH == 0
	sent.count = int(sent.get("count", 0)) + 1
	for section: int in [4, 6]:
		var h := hash(snap[section])
		if refresh or sent.get(section, 0) != h:
			sent[section] = h
			out[section] = snap[section]
	return out


## What a player is busy with, for the animation others see (Avatar.Act): digging or hammering
## while they hold the key, and a moment's heave when they throw a bucket over the side.
func _act(r: Dictionary) -> int:
	if r.last_dig >= 0.0 and time - r.last_dig < 0.4:
		return Avatar.Act.DIG
	if r.last_patch >= 0.0 and time - r.last_patch < 0.4:
		return Avatar.Act.HAMMER
	if r.last_bail >= 0.0 and time - r.last_bail < 0.9:
		return Avatar.Act.BAIL
	return Avatar.Act.NONE


func log_line() -> String:
	var s := crew_ship()
	var skel := ""
	for id in captains:
		var k: ShipState = ships[id]
		skel += " skeleton%d=(%.0f, %.0f, water %.2f, holes %d)" % [id, k.x, k.z, k.water, k.leaks()]
	return "t=%.0f players=%d ship=(%.1f, %.1f) speed=%.2f anchored=%s sails=%.2f/%.2f water=%.2f holes=%d stations=%s%s" % [
		time, players.size(), s.x, s.z, s.speed, s.anchored, s.sail_height[0], s.sail_height[1],
		s.water, s.leaks(), station_owner, skel,
	]


# =====================================================================================
# Skeleton ships and the crew's ship coming back
# =====================================================================================

## The nearest crew ship afloat (what a skeleton captain hunts), or null.
## For an ally: the nearest of the Admiral's ships (or the dead's), or null.
func _nearest_enemy_ship(from: ShipState) -> ShipState:
	var best: ShipState = null
	var best_d := INF
	for id in ships:
		var s: ShipState = ships[id]
		if s.kind != ShipState.Kind.SKELETON or s.flag == 4 or s.flag == 5 or s.is_sinking():
			continue
		var d := Vector2(s.x - from.x, s.z - from.z).length()
		if d < best_d:
			best = s
			best_d = d
	return best


func _nearest_crew_ship(from: ShipState) -> ShipState:
	var best: ShipState = null
	var best_d := INF
	for c in crews:
		var s: ShipState = ships.get(c)
		if s == null or s.is_sinking():
			continue
		var d := Vector2(s.x - from.x, s.z - from.z).length()
		if d < best_d:
			best = s
			best_d = d
	return best


func _maybe_spawn_skeleton() -> void:
	if not ai_enabled or time < next_ai_time or not captains.is_empty():
		return
	# Hunt a crew that has players aboard.
	var targets := []
	for c in crews:
		if not _crew_members(c).is_empty() and ships.has(c) and not ships[c].is_sinking():
			targets.append(c)
	if targets.is_empty():
		return
	var crew: ShipState = ships[targets[_rng.randi() % targets.size()]]
	var origin := Vector2(crew.x, crew.z)
	var spot := origin
	for attempt in 12:
		var angle := _rng.randf() * TAU
		spot = origin + Vector2(cos(angle), sin(angle)) * AI_SPAWN_DISTANCE
		var clear := true
		for island in Islands.LAYOUT:
			if spot.distance_to(Vector2(island.x, island.z)) < island.radius + 80.0:
				clear = false
		if clear:
			break
	var s := ShipState.new()
	s.kind = ShipState.Kind.SKELETON
	s.x = spot.x
	s.z = spot.y
	s.yaw = Captain.bearing(spot, origin)
	s.anchored = false
	s.sail_height = [1.0, 1.0]
	s.speed = 4.0
	var id := _next_ship_id
	_next_ship_id += 1
	ships[id] = s
	captains[id] = Captain.new(id)
	_crew_skeleton_ship(id)
	stats.ai_spawned += 1
	var from := spot - origin
	print("[server] skeleton ship %d spawned at (%.0f, %.0f)" % [id, spot.x, spot.y])
	Net.send_message(0, "A skeleton ship approaches from the %s!" % compass_name(atan2(from.x, -from.y)))
	Net.send_event("alarm", [])


func _maybe_respawn_crews() -> void:
	for c in crews:
		var crew: Dictionary = crews[c]
		if crew.respawn_at < 0.0 or time < crew.respawn_at:
			continue
		crew.respawn_at = -1.0
		_launch_crew_ship(c)
		print("[server] the crew's ship is back (crew %d)" % c)
		_tell_crew(c, "The ship is back. All hands on deck!")
		for id in _crew_members(c):
			players[id].station = -1
			players[id].bucket = false
			if players[id].dead_until < 0.0:
				_teleport(id, LocalPlayer.Mode.ON_SHIP, _free_spawn(id), 0.0)


## A crew with nobody left in it loses its ship after a while (crew 1 always stays).
func _retire_empty_crews() -> void:
	for c in crews.keys():
		if c == CREW:
			continue
		var crew: Dictionary = crews[c]
		if not _crew_members(c).is_empty() or crew.pinned:
			crew.empty_since = -1.0
			continue
		if crew.empty_since < 0.0:
			crew.empty_since = time
		elif time - crew.empty_since > EMPTY_CREW_TIMEOUT:
			if not crew.mission.is_empty() and crew.mission.kind == Missions.Kind.STORY:
				story.cleanup(crew.mission)
			if ships.has(c):
				_evacuate(c)
				ships.erase(c)
			crews.erase(c)
			print("[server] crew %d sailed away" % c)


func _handle_sinking() -> void:
	for id in ships.keys():
		var s: ShipState = ships[id]
		if not s.is_sinking():
			continue
		if not _evacuated.has(id):
			_evacuated[id] = true
			_evacuate(id)
			story.on_ship_sunk(id, Vector3(s.x, 0.0, s.z))
			world.on_ship_sunk(id, Vector3(s.x, 0.0, s.z))
			_board_ghost_sunk(id, Vector3(s.x, 0.0, s.z))
			if _last_hit_by.has(id) and crews.has(_last_hit_by[id]):
				var xp := Progress.XP_PLAYER_SHIP if crews.has(id) else (Progress.XP_GALLEON if s.flag == 1 else Progress.XP_SKELETON_SHIP)
				_award_crew(_last_hit_by[id], xp, "sinking a ship")
				if s.flag in [1, 2, 6]:
					_deed_crew(_last_hit_by[id], "galleons")
				elif s.flag == 3:
					_deed_crew(_last_hit_by[id], "ghosts")
			_last_hit_by.erase(id)
			if crews.has(id):
				stats.crew_sunk += 1
				_tell_crew(id, "We're sinking! Abandon ship!")
				Net.send_message(0, "%s is going down!" % crew_name(id))
			else:
				Net.send_message(0, "The skeleton ship is going down!")
		if s.sink >= 1.0:
			# A crew's ship stays on the bottom (still on the list, so her crew has a "ship" to
			# refer to) until they buy another at a shipyard.
			if not crews.has(id):
				_drop_wreck_loot(s)
				for sid in skeletons.keys():
					if skeletons[sid].frame == id:
						skeletons.erase(sid)
				ships.erase(id)
				captains.erase(id)
				_evacuated.erase(id)
				stats.ai_sunk += 1
				next_ai_time = time + AI_RESPAWN_DELAY
				print("[server] skeleton ship %d sunk" % id)


## Everyone aboard a sinking ship goes into the sea where they stood.
func _evacuate(ship_id: int) -> void:
	var pose := ShipPhysics.pose_of(ships[ship_id], time)
	# Anything stowed aboard floats up where it was.
	for iid in items:
		var item: Loot = items[iid]
		if item.state == Loot.State.ON_SHIP and item.ship == ship_id:
			_set_floating(item, pose * item.pos)
	for id in players:
		var r: Dictionary = players[id]
		if r.mode != LocalPlayer.Mode.ON_SHIP or r.ship != ship_id:
			continue
		_free_station_of(id)
		r.bucket = false
		var world: Vector3 = pose * r.pos
		world.y = maxf(world.y, Waves.height(world.x, world.z, time) + 0.5)
		_teleport(id, LocalPlayer.Mode.WORLD, world, r.yaw + ships[ship_id].yaw, -1)


func _separate_ships() -> void:
	var ids := ships.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: ShipState = ships[ids[i]]
			var b: ShipState = ships[ids[j]]
			if a.is_sinking() or b.is_sinking():
				continue
			var pa := Vector2(a.x, a.z)
			var pb := Vector2(b.x, b.z)
			if pa.distance_to(pb) > Hull.of(a).half_length + Hull.of(b).half_length + SHIP_CONTACT:
				continue
			var closest := INF
			for da: float in [-9.0, 0.0, 9.0]:
				for db: float in [-9.0, 0.0, 9.0]:
					var qa := pa + ShipPhysics.forward(a.yaw) * da
					var qb := pb + ShipPhysics.forward(b.yaw) * db
					closest = minf(closest, qa.distance_to(qb))
			if closest >= SHIP_CONTACT:
				continue
			var push := (pb - pa).normalized() * (SHIP_CONTACT - closest) * 0.5
			a.x -= push.x
			a.z -= push.y
			b.x += push.x
			b.z += push.y
			a.speed *= 0.5
			b.speed *= 0.5


# =====================================================================================
# Cannonballs
# =====================================================================================

func _fire(ship_id: int, gun: int, yaw: float, pitch: float, reload: float) -> void:
	var s: ShipState = ships[ship_id]
	yaw = clampf(yaw, -ShipShape.CANNON_YAW_LIMIT, ShipShape.CANNON_YAW_LIMIT)
	pitch = clampf(pitch, ShipShape.CANNON_PITCH_MIN, ShipShape.CANNON_PITCH_MAX)
	s.gun_yaw[gun] = yaw
	s.gun_pitch[gun] = pitch
	s.gun_reload[gun] = reload
	var pose := ShipPhysics.pose_of(s, time)
	var muzzle := pose * ShipShape.muzzle(gun, yaw, pitch)
	var dir := pose.basis * ShipShape.barrel_direction(gun, yaw, pitch)
	var v0 := dir * Ballistics.MUZZLE_SPEED + ShipPhysics.velocity_of(s)
	var id := _next_projectile
	_next_projectile += 1
	projectiles.append({"id": id, "t0": time, "p0": muzzle, "v0": v0, "ship": ship_id, "prev": muzzle})
	stats.shots += 1
	Net.send_event("shot", [id, time, muzzle.x, muzzle.y, muzzle.z, v0.x, v0.y, v0.z, ship_id, gun])


func _step_projectiles() -> void:
	var poses := {}
	for id in ships:
		poses[id] = ShipPhysics.pose_of(ships[id], time)
	var keep: Array[Dictionary] = []
	for p in projectiles:
		var age: float = time - p.t0
		var pos := Ballistics.position(p.p0, p.v0, age)
		if story.act5.projectile_hit(pos) or world.projectile_hit(pos):
			# The Bone Colossus's glowing joints (Act V, or the Maw stirring).
			Net.send_event("impact", [p.id, 2, pos.x, pos.y, pos.z, -1, time])
			continue
		if not _projectile_hits(p, pos, age, poses):
			if age < Ballistics.LIFETIME:
				p.prev = pos
				keep.append(p)
	projectiles = keep


## True if the ball hit something this tick (and reports it).
func _projectile_hits(p: Dictionary, pos: Vector3, age: float, poses: Dictionary) -> bool:
	for id in ships:
		var s: ShipState = ships[id]
		if s.sink > 0.5 or (id == p.ship and age < 0.4):
			continue
		var pose: Transform3D = poses[id]
		var inv := pose.affine_inverse()
		var local := inv * pos
		var hull := Hull.of(s)
		if local.length() > 25.0 or not hull.inside_hull(local):
			continue
		# Walk back along this tick's path to where the ball met the hull.
		var outside: Vector3 = inv * p.prev
		var inside := local
		for i in 10:
			var mid := (outside + inside) * 0.5
			if hull.inside_hull(mid):
				inside = mid
			else:
				outside = mid
		_hull_hit(p, id, inside, pose * inside)
		return true
	if pos.y < Waves.height(pos.x, pos.z, time):
		Net.send_event("impact", [p.id, 0, pos.x, pos.y, pos.z, -1, time])
		_splash(pos, _crew_of_ship(p.ship))
		return true
	for island in Islands.LAYOUT:
		var dx: float = pos.x - island.x
		var dz: float = pos.z - island.z
		if dx * dx + dz * dz < (island.radius + 14.0) ** 2 and pos.y < IslandMesh.ground(island, dx, dz) + 0.3:
			Net.send_event("impact", [p.id, 3, pos.x, pos.y, pos.z, -1, time])
			_splash(pos, _crew_of_ship(p.ship))
			return true
	return false


func _hull_hit(p: Dictionary, ship_id: int, local: Vector3, world: Vector3) -> void:
	var s: ShipState = ships[ship_id]
	var kind := 2
	# The Admiral's flagship cannot be holed but when a chapter is fighting her (Act IV); the
	# prison hulk never; Isabel's ship takes no shot from a pirate, nor does a pirate from her.
	var from_ship: ShipState = ships.get(int(p.ship))
	var friendly := from_ship != null and ((from_ship.flag == 4 and s.kind == ShipState.Kind.CREW) or (from_ship.kind == ShipState.Kind.CREW and s.flag == 4))
	if (s.flag == 2 and not story.act4.flagship_holeable(ship_id)) or s.flag == 5 or friendly:
		Net.send_event("impact", [p.id, kind, world.x, world.y, world.z, ship_id, time])
		return
	# Saltshot: a crew that brewed it holes the dead's ships twice.
	var hull := Hull.of(s)
	if s.kind == ShipState.Kind.SKELETON and hull.makes_hole(local) and _has_saltshot(_crew_of_ship(p.ship)) and s.holes.size() < MAX_HOLES:
		var extra := hull.hole_point(local + Vector3(0, 0, 0.9))
		s.holes.append([s.next_hole_id, extra.x, extra.y, extra.z, 0.0])
		s.next_hole_id += 1
		stats.holes += 1
	if hull.makes_hole(local):
		kind = 1
		stats.hits += 1
		if s.flag == 2:
			# Every hit below her waterline counts toward breaking her, holes patched or not.
			story.act4.on_hole(ship_id)
		if s.holes.size() < MAX_HOLES:
			var h := hull.hole_point(local)
			s.holes.append([s.next_hole_id, h.x, h.y, h.z, 0.0])
			s.next_hole_id += 1
			stats.holes += 1
			if crews.has(ship_id):
				_tell_crew(ship_id, "We're hit! Water on the lower deck!" if hull.has_hold else "We're hit! She's taking water!")
		else:
			s.water = minf(hull.sink_level, s.water + 0.15)
	Net.send_event("impact", [p.id, kind, world.x, world.y, world.z, ship_id, time])
	var shooter := _crew_of_ship(p.ship)
	if shooter > 0 and shooter != s.crew:
		_last_hit_by[ship_id] = shooter
	_splash(world, shooter)


# =====================================================================================
# Players
# =====================================================================================

## "" if a new player may join, otherwise the reason they may not.
func can_join(version: String, player_name := "", token := "") -> String:
	if version != GameConfig.VERSION:
		return "This server runs version %s; you have %s." % [GameConfig.VERSION, version]
	if players.size() >= GameConfig.MAX_PLAYERS:
		return "The server is full (%d players)." % GameConfig.MAX_PLAYERS
	var clean := player_name.strip_edges().substr(0, 20)
	for id in players:
		if Profiles.key_for(players[id].name) == Profiles.key_for(clean) and clean != "":
			return "A pirate called %s is already aboard. Pick another name." % clean
	return profiles.check(clean, token) if clean != "" else ""


## Which crew a joining player goes to: the one asked for if it has room, otherwise the
## lowest-numbered crew with room (so friends who pick "any" end up together).
func pick_crew(wanted: int) -> int:
	if wanted >= 1 and wanted <= MAX_CREWS and _crew_members(wanted).size() < CREW_SIZE:
		return wanted
	for c in range(1, MAX_CREWS + 1):
		if _crew_members(c).size() < CREW_SIZE:
			return c
	return -1


func add_player(id: int, player_name: String, wanted_crew := 0, token := "") -> void:
	var clean := player_name.strip_edges().substr(0, 20)
	if clean == "":
		clean = "Pirate %d" % (players.size() + 1)
	var crew := maxi(1, pick_crew(wanted_crew))
	_ensure_crew(crew)
	players[id] = {
		"name": clean, "crew": crew, "mode": LocalPlayer.Mode.ON_SHIP, "ship": crew, "pos": Vector3.ZERO,
		"yaw": 0.0, "pitch": 0.0, "station": -1, "seq": 0, "time": time, "bucket": false,
		"last_patch": -1.0, "carry": -1, "dig": 0.0, "last_dig": -1.0, "last_bail": -1.0,
		"hp": HEALTH, "dead_until": -1.0, "weapon": Weapons.Kind.CUTLASS, "next_attack": 0.0,
		"profile": profiles.get_or_make(clean, token),
	}
	roster[id] = clean
	if crews[crew].looks.is_empty():
		# A new ship wears the looks her first pirate aboard last fitted.
		crews[crew].looks = players[id].profile.ship.duplicate()
	print("[server] %s joined crew %d (peer %d)" % [clean, crew, id])
	Net.send_roster(roster)
	var ship: ShipState = ships[crew]
	if harbour and (ship.is_sinking() or _moored_at_merrow(crew)):
		# A new crew starts on the pier by its ship; so does anyone whose crew has none.
		_to_pier(id)
	elif ship.is_sinking():
		_teleport(id, LocalPlayer.Mode.WORLD, Vector3(ship.x + 12.0, 0.5, ship.z), 0.0)
	else:
		_teleport(id, LocalPlayer.Mode.ON_SHIP, _free_spawn(id), 0.0)
	if options_wreck >= 0 and options_wreck < Shipyards.count():
		ship.sink = 1.0
		_evacuated[crew] = true
		_teleport(id, LocalPlayer.Mode.WORLD, Shipyards.test_swim_spot(options_wreck), 0.0)
	Net.send_message(0, "%s joined %s" % [clean, crew_name(crew)])
	_send_profile(id)
	_update_tag(id)
	world.tell(id)  # a world event already under way
	for c in _ship_looks:
		Net.send_event_to(id, "ship_look", _ship_looks[c])


## Returns the name of the player who left, or "".
func remove_player(id: int) -> String:
	if not players.has(id):
		return ""
	_free_station_of(id)
	_drop_carried(id)
	var who: String = players[id].name
	print("[server] %s left (peer %d)" % [who, id])
	profiles.changed(who)
	profiles.flush()
	players.erase(id)
	roster.erase(id)
	tags.erase(id)
	station_input.erase(id)
	_fort_open.erase(id)
	_sent.erase(id)
	_voice_allowance.erase(id)
	return who


## Who hears `id` speak: everyone within EARSHOT of them, any crew, but not themselves.
func voice_listeners(id: int) -> Array:
	if not players.has(id):
		return []
	var mouth := _world_pos(players[id])
	var out := []
	for other: int in players:
		if other != id and _world_pos(players[other]).distance_to(mouth) <= EARSHOT:
			out.append(other)
	return out


## Whether to pass on a voice packet of `size` bytes from `id`: the right size, and within
## their VOICE_PER_SECOND (topped up as time passes, never above a second's worth).
func voice_ok(id: int, size: int) -> bool:
	if size <= VoicePacket.HEADER or size > VoicePacket.MAX_BYTES or not players.has(id):
		return false
	var a: Array = _voice_allowance.get(id, [float(VOICE_PER_SECOND), time])
	a[0] = minf(VOICE_PER_SECOND, a[0] + (time - a[1]) * VOICE_PER_SECOND)
	a[1] = time
	_voice_allowance[id] = a
	if a[0] < 1.0:
		return false
	a[0] -= 1.0
	return true


## A player reports where they are: [teleport seq, mode, x, y, z, yaw, pitch].
func player_state(id: int, data: Array) -> void:
	if not players.has(id) or data.size() != 7:
		return
	var r: Dictionary = players[id]
	if int(data[0]) != r.seq or r.dead_until >= 0.0:
		return  # from before our last teleport, or a ghost that may not move
	var mode := int(data[1])
	var pos := Vector3(data[2], data[3], data[4])
	var elapsed := maxf(time - r.time, 1.0 / GameConfig.PLAYER_SEND_RATE)
	var crew: ShipState = ships.get(r.ship, _own(r))

	var ok := true
	if mode == r.mode:
		ok = pos.distance_to(r.pos) <= MAX_PLAYER_SPEED * elapsed + 2.0
		if mode == LocalPlayer.Mode.ON_SHIP:
			ok = ok and Hull.of(crew).plausible_position(pos)
		else:
			ok = ok and _plausible_in_world(pos)
	elif r.mode == LocalPlayer.Mode.ON_SHIP and mode == LocalPlayer.Mode.WORLD:
		ok = crew != null and Vector2(pos.x, pos.z).distance_to(Vector2(crew.x, crew.z)) < 40.0
	else:
		ok = false  # only the server moves people back aboard

	if not ok:
		stats.corrections += 1
		_teleport(id, r.mode, r.pos, r.yaw)
		return
	if mode == LocalPlayer.Mode.WORLD:
		_free_station_of(id)
		if r.mode != LocalPlayer.Mode.WORLD:
			r.bucket = false  # it stays aboard; ashore you fill one from the sea
		r.ship = -1
	r.mode = mode
	r.pos = pos
	r.yaw = float(data[5])
	r.pitch = float(data[6])
	r.time = time


func set_station_input(id: int, axes: Vector2, aim: Vector2) -> void:
	if not players.has(id):
		return
	station_input[id] = {"axes": axes.limit_length(1.4), "aim": aim, "time": time}
	var r: Dictionary = players[id]
	var st := Hull.of(_own(r)).station(r.station) if r.station >= 0 else {}
	if st.get("kind", -1) == ShipShape.Kind.CANNON:
		var gun: int = st.gun
		_own(r).gun_yaw[gun] = clampf(aim.x, -ShipShape.CANNON_YAW_LIMIT, ShipShape.CANNON_YAW_LIMIT)
		_own(r).gun_pitch[gun] = clampf(aim.y, ShipShape.CANNON_PITCH_MIN, ShipShape.CANNON_PITCH_MAX)


func request(id: int, action: String, arg: int, data: Array) -> void:
	if not players.has(id):
		return
	var r: Dictionary = players[id]
	if r.dead_until >= 0.0:
		return
	if r.mode == LocalPlayer.Mode.ON_SHIP and r.ship != r.crew and action not in ["attack", "weapon", "drop", "respawn", "pickup", "use"]:
		return  # aboard someone else's ship: fight (or open a cage), but no working their gear
	match action:
		"station":
			_take_station(id, r, arg)
		"leave":
			if r.station == arg:
				_free_station_of(id)
		"climb":
			_climb(id, r, arg, int(data[0]) if data.size() == 1 else -1)
		"respawn":
			_free_station_of(id)
			r.bucket = false
			if has_ship(r.crew):
				_teleport(id, LocalPlayer.Mode.ON_SHIP, _free_spawn(id), 0.0)
			elif harbour:
				_to_pier(id)
		"ship":
			_buy_ship(id, r, arg)
		"hatch":
			_hatch(id, r, arg)
		"patch":
			_patch(r, arg)
		"scoop":
			_scoop(r)
		"throw":
			_throw(r)
		"fire":
			_player_fire(r, arg, data)
		"board":
			_show_board(id, r)
		"voyage":
			_take_offer(id, r, arg)
		"abandon":
			_abandon(id, r)
		"deliver":
			_deliver(r)
		"dig":
			_dig(r)
		"pickup":
			_pickup(id, r, arg)
		"drop":
			_drop_carried(id)
		"sell":
			_sell(r, id)
		"restock":
			_restock(r, arg)
		"open":
			_open_barrel(r, arg)
		"weapon":
			if arg == Weapons.Kind.CUTLASS or arg == Weapons.Kind.PISTOL:
				r.weapon = arg
		"attack":
			_attack(id, r, data)
		"eat":
			_eat(r)
		"talk":
			if arg >= 0 and arg < Story.PEOPLE_IDS.size():
				if Story.PEOPLE_IDS[arg] == "martha" and not story.fresh_offer(r.crew, "martha"):
					_open_shop(id, r)
				elif Story.PEOPLE_IDS[arg] == "hobb":
					_open_wright(id, r)
				else:
					story.talk(id, r, Story.PEOPLE_IDS[arg])
		"climb_light":
			_climb_lighthouse(id, r, arg)
		"light":
			story.act5.light_beacon(id, r, arg)
		"buy":
			_buy(id, r, arg)
		"wear":
			_wear(id, r, arg)
		"wright":
			_wright(id, r, arg)
		"armoury":
			_open_fort_arms(id, r)
		"read":
			story.read(r, arg)
		"douse":
			story.douse(r, arg)
		"salt":
			story.salt(r, arg)
		"give":
			story.give(id, r)
		"rescue":
			story.rescue(r)
		"dive":
			story.dive(id, r)
		"search":
			story.search(id, r, arg)
		"use":
			story.use(id, r, arg)


func _take_station(id: int, r: Dictionary, station: int) -> void:
	if not has_ship(r.crew) or r.mode != LocalPlayer.Mode.ON_SHIP:
		return
	var st := Hull.of(_own(r)).station(station)
	if st.is_empty() or r.station == station:
		return
	if r.carry >= 0:
		Net.send_message(id, "Put the chest down first")
		return
	var key: int = r.crew * 100 + station
	if station_owner.has(key) and station_owner[key] != id:
		Net.send_message(id, "%s is already on it" % roster.get(station_owner[key], "Someone"))
		return
	if r.pos.distance_to(st.stand) > 4.0:
		return
	_free_station_of(id)
	station_owner[key] = id
	r.station = station
	stats.stations_taken += 1
	print("[server] %s took station %d" % [r.name, station])
	var face := 0.0
	if st.kind == ShipShape.Kind.CANNON:
		face = -PI / 2.0 * st.side
	_teleport(id, LocalPlayer.Mode.ON_SHIP, st.stand, face)


## Up a ladder from the water: the ship asked for, or else whichever ladder is in reach.
func _climb(id: int, r: Dictionary, side: int, wanted := -1) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or (absi(side) != 1 and side != ShipShape.STERN_ROPE):
		return
	if r.carry >= 0 and items.has(r.carry) and items[r.carry].kind == Loot.Kind.HEART:
		return  # the Heart is too heavy, and too hot, to climb with
	var order: Array = ships.keys()
	if ships.has(wanted):
		order.erase(wanted)
		order.push_front(wanted)
	for ship_id in order:
		var s: ShipState = ships[ship_id]
		if s.is_sinking() or (side == ShipShape.STERN_ROPE and s.flag != 5):
			continue
		if side == ShipShape.STERN_ROPE and s.hull != Hull.Type.GALLEON:
			continue
		var bottom := ShipPhysics.pose_of(s, time) * Hull.of(s).ladder_bottom(side)
		if Vector2(r.pos.x - bottom.x, r.pos.z - bottom.z).length() > LADDER_TOLERANCE:
			continue
		stats.climbs += 1
		if ship_id != r.crew:
			stats.boarded += 1
			var whose := crew_name(ship_id) if crews.has(ship_id) else "skeleton ship %d" % ship_id
			print("[server] %s boarded %s" % [r.name, whose])
		else:
			print("[server] %s climbed aboard" % r.name)
		# Face inboard: starboard ladder looks toward -x, which is a quarter turn left.
		var facing := 0.0 if side == ShipShape.STERN_ROPE else PI / 2.0 * side
		_teleport(id, LocalPlayer.Mode.ON_SHIP, Hull.of(s).ladder_top(side), facing, ship_id)
		return


func _hatch(id: int, r: Dictionary, up: int) -> void:
	if r.mode != LocalPlayer.Mode.ON_SHIP or r.station >= 0 or not Hull.of(ships.get(r.ship)).has_hold:
		return
	if up == 0 and r.pos.distance_to(ShipShape.hatch_top_target()) < HATCH_REACH + 1.0:
		_teleport(id, LocalPlayer.Mode.ON_SHIP, ShipShape.HATCH_BOTTOM, PI)
	elif up == 1 and r.pos.distance_to(ShipShape.hatch_bottom_target()) < HATCH_REACH + 1.5:
		_teleport(id, LocalPlayer.Mode.ON_SHIP, ShipShape.HATCH_TOP, 0.0)


func _patch(r: Dictionary, hole_id: int) -> void:
	if r.mode != LocalPlayer.Mode.ON_SHIP:
		return
	var s := _own(r)
	for h: Array in s.holes:
		if int(h[0]) != hole_id:
			continue
		var at := Vector3(h[1], h[2], h[3])
		if r.pos.distance_to(at) > PATCH_REACH + 1.0:
			return
		# Credit the time since this player's last patch request, so the work rate is the
		# same however often the client asks.
		var gap: float = time - r.last_patch if r.last_patch >= 0.0 else 0.2
		r.last_patch = time
		h[4] = minf(float(h[4]) + clampf(gap, 0.0, 0.35) / PATCH_TIME, 1.0)
		if h[4] >= 1.0:
			if s.planks <= 0:
				h[4] = 0.95
				Net.send_message(players.find_key(r), "No planks left! Restock at Port Merrow.")
				return
			s.planks -= 1
			s.holes.erase(h)
			stats.patched += 1
			print("[server] %s patched hole %d" % [r.name, hole_id])
		return


func _scoop(r: Dictionary) -> void:
	if r.mode == LocalPlayer.Mode.WORLD:
		story.scoop(r)
		return
	var s := _own(r)
	if r.mode != LocalPlayer.Mode.ON_SHIP or r.bucket or s == null or r.ship != r.crew:
		return
	if Hull.of(s).can_scoop(r.pos, s.water):
		r.bucket = true


func _throw(r: Dictionary) -> void:
	var s := _own(r)
	if r.mode != LocalPlayer.Mode.ON_SHIP or not r.bucket or s == null or r.ship != r.crew:
		return
	var hull := Hull.of(s)
	# A sloop's water is right under the deck, so her bailer doesn't climb: a throw takes a moment.
	if not hull.can_throw(r.pos) or (r.last_bail >= 0.0 and time - r.last_bail < hull.bail_every):
		return
	r.bucket = false
	r.last_bail = time
	_pending_bail[r.crew] = _pending_bail.get(r.crew, 0.0) + hull.bucket
	stats.bailed += 1


func _player_fire(r: Dictionary, station: int, aim: Array) -> void:
	if r.station != station or station < 0 or aim.size() != 2:
		return
	var st := Hull.of(_own(r)).station(station)
	if st.get("kind", -1) != ShipShape.Kind.CANNON or _own(r).is_sinking():
		return
	if _own(r).gun_reload[st.gun] > 0.0:
		return
	if _own(r).cannonballs <= 0:
		Net.send_message(players.find_key(r), "Out of cannonballs! Restock at Port Merrow.")
		return
	_own(r).cannonballs -= 1
	_fire(r.crew, st.gun, float(aim[0]), float(aim[1]), PLAYER_RELOAD)


func _free_station_of(id: int) -> void:
	if not players.has(id):
		return
	var r: Dictionary = players[id]
	var key: int = r.crew * 100 + r.station
	if r.station >= 0 and station_owner.get(key) == id:
		station_owner.erase(key)
	r.station = -1
	station_input.erase(id)


func _free_spawn(for_id: int) -> Vector3:
	var spots := Hull.of(_own(players[for_id]) if players.has(for_id) else null).spawns
	for spot in spots:
		var taken := false
		for id in players:
			var r: Dictionary = players[id]
			var same_ship: bool = r.ship == players[for_id].crew if players.has(for_id) else true
			if id != for_id and same_ship and r.mode == LocalPlayer.Mode.ON_SHIP and r.pos.distance_to(spot) < 0.8:
				taken = true
		if not taken:
			return spot
	return spots[0]


## Put a player somewhere. `ship` is the ship whose frame `pos` is in (ON_SHIP), else -1.
## -2 for `ship` means the player's own crew ship.
func _teleport(id: int, mode: int, pos: Vector3, yaw: float, ship := -2) -> void:
	var r: Dictionary = players[id]
	if ship == -2:
		ship = r.crew
	r.seq += 1
	r.mode = mode
	r.ship = ship if mode == LocalPlayer.Mode.ON_SHIP else -1
	r.pos = pos
	r.yaw = yaw
	r.time = time
	# The frame ship's hull goes too, so the client walks on the right deck from the first step.
	var hull: int = ships[r.ship].hull if ships.has(r.ship) else Hull.Type.GALLEON
	Net.send_teleport(id, [r.seq, mode, pos.x, pos.y, pos.z, yaw, r.ship, hull])


static func compass_name(heading: float) -> String:
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	return names[int(round(fposmod(rad_to_deg(heading), 360.0) / 45.0)) % 8]


# =====================================================================================
# Treasure and supplies
# =====================================================================================

func _new_item(kind: int, state: int, pos: Vector3, value := 0) -> Loot:
	var item := Loot.new()
	item.id = _next_item
	_next_item += 1
	item.kind = kind
	item.state = state
	item.pos = pos
	item.value = value
	item.born = time
	items[item.id] = item
	return item


func _island_xz(where: String) -> Vector2:
	var index := Islands.outpost_index() if where == "outpost" else int(where)
	var spec: Dictionary = Islands.LAYOUT[index]
	return Vector2(spec.x, spec.z)


## A spot 40 m off an island's shore, on the side facing the start (for tests).
## Play-test (--jump): the crew's ship starts by the island its chapter sends it to, or at the
## Black Reef's edge for the chapters out there.
func _jump_to_chapter() -> void:
	var m: Dictionary = crews[CREW].mission
	if m.is_empty():
		return
	var islands: Array = m.get("islands", [])
	var at := Vector3.INF
	var look := Vector2(Reef.CENTRE)
	if not islands.is_empty() and int(islands[0]) != Islands.outpost_index():
		at = _anchorage(int(islands[0]))
		look = _island_xz(str(islands[0]))
	elif islands.is_empty() and int(Story.CHAPTERS[m.chapter].act) >= 4:
		at = Vector3(Reef.CENTRE.x - 210.0, 0.0, Reef.CENTRE.y)
	if at == Vector3.INF:
		return
	crew_ship().x = at.x
	crew_ship().z = at.z
	crew_ship().yaw = Captain.bearing(Vector2(at.x, at.z), look)
	print("[server] play-test: the ship starts at (%.0f, %.0f) for chapter %s" % [at.x, at.z, Story.CHAPTERS[m.chapter].id])


func _anchorage(index: int) -> Vector3:
	var spec: Dictionary = Islands.LAYOUT[index]
	var dir := -Vector2(spec.x, spec.z).normalized()
	var p: Vector2 = Vector2(spec.x, spec.z) + dir * (spec.radius + 40.0)
	return Vector3(p.x, 0.0, p.y)


func _set_floating(item: Loot, world: Vector3) -> void:
	if item.kind == Loot.Kind.CRATE and not item.soaked:
		# Cargo that goes in the sea is spoilt: it pays less from now on.
		item.soaked = true
		item.value = int(round(item.value * Missions.SOAKED_PAY))
	item.state = Loot.State.FLOATING
	item.carrier = -1
	item.pos = Vector3(world.x, Waves.height(world.x, world.z, time) - 0.15, world.z)
	item.born = time


func _step_items(dt: float) -> void:
	var gone := []
	for id in items:
		var item: Loot = items[id]
		match item.state:
			Loot.State.FLOATING:
				item.pos.y = Waves.height(item.pos.x, item.pos.z, time) - 0.15
				item.yaw += 0.05 * dt
				if time - item.born > Loot.FLOAT_LIFE:
					gone.append(id)
			Loot.State.CARRIED:
				if players.has(item.carrier):
					item.pos = players[item.carrier].pos
				else:
					gone.append(id)
	for id in gone:
		_mission_item_done(items[id], 0, false)
		items.erase(id)


## Where a player is in the world (converting from the ship frame when aboard).
func _world_pos(r: Dictionary) -> Vector3:
	if r.mode == LocalPlayer.Mode.ON_SHIP and ships.has(r.ship):
		return ShipPhysics.pose_of(ships[r.ship], time) * r.pos
	return r.pos


# =====================================================================================
# Missions (docs/specs/2026-10-07-m6-missions.md)
# =====================================================================================

## A crew's level with each company.
## The crew's level with each company: the best of its pirates online.
func _levels(crew: int) -> Array:
	var out := [options_level, options_level, options_level]
	for id in _crew_members(crew):
		for c in 3:
			out[c] = maxi(out[c], Missions.level(int(players[id].profile.rep[c])))
	return out


## E at the map table: the board's three offers (fresh ones while no mission is running).
func _show_board(id: int, r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.ON_SHIP or r.ship != r.crew:
		return
	if r.pos.distance_to(Hull.of(ships.get(r.ship)).map_table_target()) > MAP_TABLE_REACH + 1.0:
		return
	var crew: Dictionary = crews[r.crew]
	if crew.mission.is_empty():
		crew.offers = _make_offers(r.crew)
	var shown := []
	for offer: Dictionary in crew.offers:
		shown.append(Missions.offer_to_array(offer))
	var tale := story.board_entry(r.crew)
	if not tale.is_empty():
		shown.append(tale)
	Net.send_event_to(id, "board", shown)


func _make_offers(crew: int) -> Array[Dictionary]:
	# Test hook: every mission goes to options_island first.
	var offers := Missions.make_offers(_levels(crew), Islands.mission_islands(), _rng, options_island)
	# The further the crew is in the story, the more the war turns up on the board.
	var stage := Missions.war_stage(story.done_lists(crew))
	for offer: Dictionary in offers:
		Missions.add_twists(offer, stage, _rng)
	return offers


## Take one of the board's offers (by company), if no mission is running.
func _take_offer(_id: int, r: Dictionary, company: int) -> void:
	if r.mode != LocalPlayer.Mode.ON_SHIP or r.ship != r.crew or not crews[r.crew].mission.is_empty():
		return
	if r.pos.distance_to(Hull.of(ships.get(r.ship)).map_table_target()) > MAP_TABLE_REACH + 1.0:
		return
	var crew: Dictionary = crews[r.crew]
	if crew.offers.is_empty():
		crew.offers = _make_offers(r.crew)
	if options_mission >= 0:
		company = options_mission
	if company < 0 or company >= crew.offers.size():
		return
	_start_mission(r.crew, crew.offers[company])
	crew.offers = []


## Set a mission going for a crew: bury the chests, raise the bounty, load the cargo.
func _start_mission(crew: int, offer: Dictionary) -> void:
	var m := {
		"company": offer.company, "kind": offer.kind, "title": offer.title, "islands": offer.islands,
		"items": [], "total": 0, "handled": 0, "own": 0, "deadline": -1.0, "captain": -1, "name": "",
	}
	match int(offer.kind):
		Missions.Kind.TREASURE:
			if offer.get("wreck", false):
				# Wreck gold: the chests float at the Black Reef's edge, for fishing out.
				var islands: Array = []
				for n in int(offer.size):
					var gold := int(_rng.randi_range(Missions.CHEST_GOLD.x, Missions.CHEST_GOLD.y) * offer.pay)
					var at := StoryRun.REEF_EDGE + Vector3(_rng.randf_range(-35, 35), 0, _rng.randf_range(-35, 35))
					var chest := _new_item(Loot.Kind.CHEST, Loot.State.GROUND, at, gold)
					_set_floating(chest, at)
					chest.born = time + 1e6  # it stays afloat until you come for it
					m.items.append(chest.id)
					islands.append(7)
				m.islands = islands
				m.name = "wreck"
				m.total = m.items.size()
				_tell_crew(crew, "Wreck gold floats at the Black Reef's edge, far to the south-east.")
			else:
				for island: int in offer.islands:
					var spot := Islands.dig_spot(island, _rng)
					var gold := int(_rng.randi_range(Missions.CHEST_GOLD.x, Missions.CHEST_GOLD.y) * offer.pay)
					var chest := _new_item(Loot.Kind.CHEST, Loot.State.BURIED, Vector3(spot.x, Islands.ground_at(island, spot.x, spot.y), spot.y), gold)
					m.items.append(chest.id)
					if offer.get("cache", false):
						# A Spanish cache: two of the dead stand over the X.
						for side: float in [-1.0, 1.0]:
							var at := Vector3(spot.x + side * 1.5, 0, spot.y + 0.8)
							at.y = Islands.ground_at(island, at.x, at.z)
							_new_skeleton(-1, at).spanish = true
				m.total = m.items.size()
				_tell_crew(crew, "A treasure map! Hold M to read it.")
		Missions.Kind.BOUNTY when offer.get("ghost", false):
			# A ghost ship: she rises near the crew; her captain's skull floats up when she sinks.
			m.name = offer.captain
			m.total = 1
			m.skull_gold = int(_rng.randi_range(Missions.SKULL_GOLD.x, Missions.SKULL_GOLD.y) * offer.pay)
			var own: ShipState = ships.get(crew, crew_ship())
			m.ghost = story.act4.spawn_ghost(crew, own, 120.0)
			_tell_crew(crew, "Green light under the sea... a ghost galleon is rising! Sink her.")
		Missions.Kind.BOUNTY:
			var island: int = offer.islands[0]
			m.name = offer.captain
			m.total = 1
			m.skull_gold = int(_rng.randi_range(Missions.SKULL_GOLD.x, Missions.SKULL_GOLD.y) * offer.pay)
			var spec: Dictionary = Islands.LAYOUT[island]
			var spanish: bool = offer.get("officer", false) or offer.get("pressed", false)
			var camp: Dictionary = camps.get(island, {"alive": 0, "wake": 0.0})
			camps[island] = camp
			for n in int(offer.size) + 1:
				var spot := Islands.dig_spot(island, _rng)
				if n == 0:
					spot = Vector2(spec.x, spec.z) + (spot - Vector2(spec.x, spec.z)) * 0.4
				var sk := _new_skeleton(-1, Vector3(spot.x, Islands.ground_at(island, spot.x, spot.y), spot.y), island)
				if n == 0:
					sk.make_captain()
					m.captain = sk.id
				else:
					sk.spanish = spanish
				camp.alive += 1
			_tell_crew(crew, "%s waits on %s. Bring his skull to Mother Wren!" % [offer.captain, spec.name])
		Missions.Kind.CARGO:
			for n in int(offer.size):
				var gold := int(_rng.randi_range(Missions.CRATE_GOLD.x, Missions.CRATE_GOLD.y) * offer.pay)
				var crate := _new_item(Loot.Kind.CRATE, Loot.State.GROUND, Outpost.cargo_spot(n), gold)
				crate.variant = int(offer.goods)
				crate.yaw = 0.1 * n
				m.items.append(crate.id)
			m.total = m.items.size()
			m.deadline = time + Missions.cargo_time(m.total)
			_tell_crew(crew, "Cargo waits on Port Merrow's pier for %s." % Islands.LAYOUT[offer.islands[0]].name)
			if offer.get("raided", false):
				# The war on the route: a skeleton ship comes looking for the cargo.
				spawn_galleon(crew, 260.0, 0)
				_tell_crew(crew, "Lookouts report a skeleton ship on the route. Keep your guns ready.")
	crews[crew].mission = m
	if m.kind == Missions.Kind.TREASURE and offer.get("diggers", false):
		story.add_board_diggers(crew, m)
		_tell_crew(crew, "Spanish diggers are after the same hoard. Be quick!")
	stats.voyages += 1
	print("[server] crew %d took a %s mission: %s" % [crew, ["treasure", "bounty", "cargo"][m.kind], m.title])


## Give up the running mission (its chests, skulls and crates stay where they are).
func _abandon(id: int, r: Dictionary) -> void:
	if crews[r.crew].mission.is_empty():
		return
	story.cleanup(crews[r.crew].mission)
	crews[r.crew].mission = {}
	crews[r.crew].offers = []
	_tell_crew(r.crew, "%s gave up the mission." % r.name)
	Net.send_event_to(id, "board", [])


## The mission's state for clients: [kind, company, title, deadline, captain, handled, total,
## n targets, then island, x, z, done for each], or [] with none.
func _mission_array(crew: int) -> Array:
	var m: Dictionary = crews[crew].mission
	if m.is_empty():
		return []
	if m.kind == Missions.Kind.STORY:
		# The chapter's id in the name's place, its step as "handled", fires lit as "total", and
		# the dead standing after the targets.
		var marks := story.targets(m)
		var n := story.counts(m)
		return [m.kind, -1, m.title, m.deadline, m.name, m.step, n[0], marks.size() / 4] + marks + [n[1]]
	var targets := []
	match int(m.kind):
		Missions.Kind.TREASURE:
			for i in m.islands.size():
				var item: Loot = items.get(m.items[i])
				var x: float = item.pos.x if item else 0.0
				var z: float = item.pos.z if item else 0.0
				# Still to find: buried, or (wreck gold) still bobbing in the sea.
				var waiting: bool = item != null and item.state in [Loot.State.BURIED, Loot.State.FLOATING]
				targets.append_array([m.islands[i], x, z, 0 if waiting else 1])
		Missions.Kind.BOUNTY when str(m.name) == Missions.GHOST_CAPTAIN:
			# A ghost ship: the mark follows her; done once she is sunk.
			var g: ShipState = ships.get(int(m.get("ghost", -1)))
			var island: int = m.islands[0] if not m.islands.is_empty() else 0
			targets.append_array([island, g.x if g else 0.0, g.z if g else 0.0, 0 if g and not g.is_sinking() else 1])
		Missions.Kind.BOUNTY:
			var island: int = m.islands[0]
			var spec: Dictionary = Islands.LAYOUT[island]
			var cap: Skeleton = skeletons.get(m.captain)
			targets.append_array([island, spec.x, spec.z, 0 if cap and cap.alive() else 1])
		Missions.Kind.CARGO:
			var spot := Islands.trader_spot(m.islands[0])
			targets.append_array([m.islands[0], spot.x, spot.z, 0])
	return [m.kind, m.company, m.title, m.deadline, m.name, m.handled, m.total, targets.size() / 4] + targets


## An item has left play: sold or delivered (by a crew) or lost. Counts toward the mission it
## belongs to, which ends once all its items are handled.
func _mission_item_done(item: Loot, by_crew: int, handed_in: bool) -> void:
	for c in crews:
		var m: Dictionary = crews[c].mission
		if m.is_empty() or not m.items.has(item.id):
			continue
		if m.kind == Missions.Kind.STORY:
			story.on_item_done(c, item, by_crew, handed_in)
			continue
		m.handled += 1
		if handed_in and by_crew == c:
			m.own += 1
		if m.handled >= m.total:
			_finish_mission(c)


func _finish_mission(crew: int) -> void:
	var m: Dictionary = crews[crew].mission
	story.cleanup(m)
	crews[crew].mission = {}
	if m.own <= 0:
		_tell_crew(crew, "The mission is over, with nothing to show for it.")
		return
	_add_rep(crew, m.company, Missions.FINISH_POINTS)
	_award_crew(crew, Progress.XP_MISSION + Progress.XP_MISSION_ITEM * m.own, "the mission")
	stats.missions += 1
	print("[server] crew %d finished %s" % [crew, m.title])
	_tell_crew(crew, "Mission done for the %s!" % Missions.COMPANY_NAMES[m.company])


## Standing with a company for every pirate of the crew online.
func _add_rep(crew: int, company: int, points: int) -> void:
	for id in _crew_members(crew):
		var profile: Dictionary = players[id].profile
		var before := Missions.level(int(profile.rep[company]))
		profile.rep[company] = int(profile.rep[company]) + points
		var after := Missions.level(int(profile.rep[company]))
		profiles.changed(profile.name)
		_send_profile(id)
		if after > before:
			Net.send_message(id, "You are now level %d with the %s!" % [after, Missions.COMPANY_NAMES[company]])


## Gold for every pirate of the crew online: each gets the full amount.
func _pay_crew(crew: int, gold: int) -> void:
	for id in _crew_members(crew):
		var profile: Dictionary = players[id].profile
		profile.gold = int(profile.gold) + gold
		profiles.changed(profile.name)
		_send_profile(id)


## XP for one pirate, with a word when they reach a new level.
func _award(id: int, xp: int, why: String) -> void:
	if not players.has(id) or xp <= 0:
		return
	var r: Dictionary = players[id]
	var before := Progress.level(int(r.profile.xp))
	r.profile.xp = int(r.profile.xp) + xp
	stats.xp += xp
	var after := Progress.level(int(r.profile.xp))
	profiles.changed(r.name)
	if after > before:
		stats.levels += 1
		var title := Progress.title_for(after)
		if title != Progress.title_for(before):
			r.profile.title = title
		print("[server] %s reached pirate level %d" % [r.name, after])
		Net.send_event_to(id, "level", [after, Progress.title_for(after)])
		Net.send_message(0, "%s is now pirate level %d!" % [r.name, after])
		_update_tag(id)
	print("[server] %s earned %d XP for %s (xp %d)" % [r.name, xp, why, r.profile.xp])
	_send_profile(id)


func _award_crew(crew: int, xp: int, why: String) -> void:
	for id in _crew_members(crew):
		_award(id, xp, why)


## A pirate's own record, for their HUD: [xp, gold, title, rep x 3, chapters done, outfit, dye,
## what they own].
func _send_profile(id: int) -> void:
	var p: Dictionary = players[id].profile
	Net.send_event_to(id, "profile", [int(p.xp), int(p.gold), _title_of(p)] + p.rep + [p.chapters.duplicate(), int(p.look), int(p.dye), p.owned.duplicate(), int(p.get("blade", 0)), int(p.get("gun", 0)), p.get("deeds", {}).duplicate(), int(p.get("armour", 0))])


## Count one more towards a deed (Deeds) for a pirate; the title when it is done.
func _deed(id: int, deed: String, n := 1) -> void:
	if not players.has(id) or n <= 0:
		return
	var p: Dictionary = players[id].profile
	if not p.has("deeds") or typeof(p.deeds) != TYPE_DICTIONARY:
		p.deeds = {}
	var d := Deeds.find(deed)
	var before := int(p.deeds.get(deed, 0))
	p.deeds[deed] = before + n
	profiles.changed(players[id].name)
	if d.is_empty() or before >= int(d[2]) or before + n < int(d[2]):
		return
	if not p.titles.has(d[3]):
		p.titles.append(d[3])
		p.title = d[3]
	if not p.owned.has(d[4]):
		p.owned.append(d[4])
	stats.deeds += 1
	print("[server] %s finished a deed: %s" % [players[id].name, d[1]])
	Net.send_message(id, "Deed done: %s! You have earned the title %s, and a gift: %s." % [d[1], d[3], Deeds.gift_name(d[4])])
	_update_tag(id)
	_send_profile(id)


func _deed_crew(crew: int, deed: String) -> void:
	for id in _crew_members(crew):
		_deed(id, deed)


## Once the story is done the fort is a friendly port for the crew (docs/specs/2026-10-08-m21-
## fort-port.md): anyone aboard has finished it, and the dead aren't holding it just now.
func fort_port(crew: int) -> bool:
	if world.kind == WorldEvents.Kind.FORT:
		return false
	for pid in _crew_members(crew):
		if players[pid].profile.chapters.has("e6"):
			return true
	return false


## Is this pirate at a counter that sells arms: Martha's, or Isabel's at the fort?
func _at_arms_counter(r: Dictionary) -> bool:
	if r.pos.distance_to(Outpost.martha_pos()) <= Shop.REACH + 1.0:
		return true
	return fort_port(r.crew) and r.pos.distance_to(Fort.isabel_pos()) <= Shop.REACH + 1.0


## E by Isabel in the fort's courtyard: her rack of arms opens (blades, guns, armour).
func _open_fort_arms(id: int, r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or not fort_port(r.crew) or r.pos.distance_to(Fort.isabel_pos()) > Shop.REACH + 1.0:
		return
	Net.send_event_to(id, "shop", [1])


## Tell each pirate whether the fort is their crew's port, when that changes.
func _send_fort_ports() -> void:
	for pid in players:
		var open := fort_port(players[pid].crew)
		if _fort_open.get(pid, false) != open:
			_fort_open[pid] = open
			Net.send_event_to(pid, "fort_port", [open])


## E by Old Hobb on the pier: his counter opens.
func _open_wright(id: int, r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or r.pos.distance_to(Outpost.hobb_pos()) > Shipwright.REACH + 1.0:
		return
	Net.send_event_to(id, "wright", [])


## Buy look `i` from Hobb and fit it to the crew's ship, or just fit it if already owned.
func _wright(id: int, r: Dictionary, i: int) -> void:
	if i < 0 or i >= Shipwright.ITEMS.size() or r.mode != LocalPlayer.Mode.WORLD:
		return
	if r.pos.distance_to(Outpost.hobb_pos()) > Shipwright.REACH + 1.0:
		return
	var p: Dictionary = r.profile
	var item: Array = Shipwright.ITEMS[i]
	if not Shipwright.has(p, i):
		var price: int = item[3]
		if price <= 0:
			Net.send_message(id, "Hobb: \"That one's earned, not sold. Go and do the deed.\"")
			return
		if int(p.gold) < price:
			Net.send_message(id, "Hobb sucks his teeth: that's %d gold, and you have %d." % [price, int(p.gold)])
			return
		p.gold = int(p.gold) - price
		p.owned.append(Shipwright.key(i))
		stats.bought += 1
		print("[server] %s bought %s %s for %d gold" % [r.name, item[2], ["sails", "hull paint", "flag", "figurehead"][item[0]], price])
		Net.send_message(id, "Bought: %s %s." % [item[2], ["sails", "hull paint", "flag", "figurehead"][item[0]]])
	var looks: Array = crews[r.crew].looks
	while looks.size() < Shipwright.LOOKS:
		looks.append(0)
	while p.ship.size() < Shipwright.LOOKS:
		p.ship.append(0)
	looks[item[0]] = item[1]
	p.ship[item[0]] = item[1]
	stats.refits += 1
	print("[server] %s fitted %s %s to %s" % [r.name, item[2], ["sails", "hull paint", "flag", "figurehead"][item[0]], crew_name(r.crew)])
	_tell_crew(r.crew, "%s has Hobb fit %s %s to the ship." % [r.name, item[2], ["sails", "hull paint", "flag", "figurehead"][item[0]]])
	profiles.changed(r.name)
	_send_profile(id)
	_send_ship_looks()


## Tell everyone how each crew's ship looks (fitted looks and trophies), when that changes.
func _send_ship_looks() -> void:
	for c in crews:
		var looks: Array = crews[c].looks
		var lists: Array = []
		for pid in _crew_members(c):
			lists.append(players[pid].profile.chapters)
		var data := [c]
		for k in Shipwright.LOOKS:
			data.append(int(looks[k]) if looks.size() > k else 0)
		data.append(Shipwright.trophies(lists))
		if _ship_looks.get(c, []) != data:
			_ship_looks[c] = data
			Net.send_event("ship_look", data)


## E at Big Martha's counter: her shop opens.
func _open_shop(id: int, r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or r.pos.distance_to(Outpost.martha_pos()) > Shop.REACH + 1.0:
		return
	Net.send_event_to(id, "shop", [])


## Buy item `i` from Martha, or arms from Isabel at the fort (and wear it), or just wear it if
## already owned.
func _buy(id: int, r: Dictionary, i: int) -> void:
	if i < 0 or i >= Shop.ITEMS.size() or r.mode != LocalPlayer.Mode.WORLD:
		return
	if not _at_arms_counter(r):
		return
	var at_martha: bool = r.pos.distance_to(Outpost.martha_pos()) <= Shop.REACH + 1.0
	if not at_martha and Shop.ITEMS[i][0] not in [Shop.Kind.BLADE, Shop.Kind.GUN, Shop.Kind.ARMOUR]:
		return  # Isabel sells arms, not coats
	var seller := "Martha" if at_martha else "Isabel"
	var p: Dictionary = r.profile
	var key := Shop.key(i)
	if not Shop.has(p, i):
		var price: int = Shop.ITEMS[i][3]
		if price <= 0:
			Net.send_message(id, "%s: \"That one's not mine to sell. Someone has to give it you.\"" % seller)
			return
		if int(p.gold) < price:
			Net.send_message(id, "%s shakes her head: that's %d gold, and you have %d." % [seller, price, int(p.gold)])
			return
		p.gold = int(p.gold) - price
		p.owned.append(key)
		stats.bought += 1
		print("[server] %s bought %s for %d gold from %s" % [r.name, Shop.ITEMS[i][2], price, seller])
		Net.send_message(id, "Bought: %s." % Shop.ITEMS[i][2])
	_wear(id, r, i)


## Wear an owned outfit or dye (`i`), or go back to your own outfit (-1) or shirt (-2).
func _wear(id: int, r: Dictionary, i: int) -> void:
	var p: Dictionary = r.profile
	if i == -1:
		p.look = -1
	elif i == -2:
		p.dye = -1
	elif i >= 0 and i < Shop.ITEMS.size() and Shop.has(p, i):
		match Shop.ITEMS[i][0]:
			Shop.Kind.OUTFIT:
				p.look = Shop.ITEMS[i][1]
			Shop.Kind.DYE:
				p.dye = Shop.ITEMS[i][1]
			Shop.Kind.BLADE:
				p.blade = Shop.ITEMS[i][1]
				print("[server] %s carries the %s" % [r.name, Shop.ITEMS[i][2]])
			Shop.Kind.GUN:
				p.gun = Shop.ITEMS[i][1]
				print("[server] %s carries the %s" % [r.name, Shop.ITEMS[i][2]])
			Shop.Kind.ARMOUR:
				p.armour = Shop.ITEMS[i][1]
				print("[server] %s wears %s" % [r.name, Weapons.ARMOURS[p.armour].name])
	else:
		return
	profiles.changed(r.name)
	_send_profile(id)
	_update_tag(id)


## The title a pirate wears: their latest earned, or the one for their level.
func _title_of(profile: Dictionary) -> String:
	var t := str(profile.title)
	return t if t != "" else Progress.title_for(Progress.level(int(profile.xp)))


## What everyone sees over a pirate's head changed (or they joined): tell everyone.
func _update_tag(id: int) -> void:
	var p: Dictionary = players[id].profile
	tags[id] = [Progress.level(int(p.xp)), _title_of(p), int(p.look), int(p.dye), int(p.get("blade", 0)), int(p.get("gun", 0)), int(p.get("armour", 0))]
	var flat := []
	for pid in tags:
		flat.append_array([pid] + tags[pid])
	Net.send_event("tags", flat)


func _dig(r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or r.carry >= 0:
		return
	var island := Islands.island_at(r.pos.x, r.pos.z)
	if island < 0 or r.pos.y < Waves.height(r.pos.x, r.pos.z, time):
		return
	var gap: float = time - r.last_dig if r.last_dig >= 0.0 else 0.2
	r.last_dig = time
	if gap > 0.6:
		r.dig = 0.0
	r.dig += clampf(gap, 0.0, 0.35) / DIG_TIME
	if r.dig < 1.0:
		return
	r.dig = 0.0
	for id in items:
		var item: Loot = items[id]
		if item.state == Loot.State.BURIED and Vector2(item.pos.x - r.pos.x, item.pos.z - r.pos.z).length() < DIG_REACH:
			item.state = Loot.State.GROUND
			item.pos.y = Islands.ground_at(island, item.pos.x, item.pos.z) + 0.05
			stats.dug += 1
			story.act4.on_dug(item)
			print("[server] %s dug up a %s" % [r.name, item.label()])
			Net.send_message(0, "%s dug up a %s!" % [r.name, item.label()])
			return
	Net.send_message(players.find_key(r), "Nothing here.")


func _pickup(id: int, r: Dictionary, item_id: int) -> void:
	if r.carry >= 0 or r.station >= 0 or not items.has(item_id):
		return
	var item: Loot = items[item_id]
	if not item.carried():
		return
	var close := false
	match item.state:
		Loot.State.GROUND, Loot.State.FLOATING:
			close = r.mode == LocalPlayer.Mode.WORLD and r.pos.distance_to(item.pos) < ITEM_REACH + 1.0
		Loot.State.ON_SHIP:
			close = r.mode == LocalPlayer.Mode.ON_SHIP and r.ship == item.ship and r.pos.distance_to(item.pos) < ITEM_REACH + 1.0
	if not close:
		return
	var stolen: bool = item.state == Loot.State.ON_SHIP and item.ship != r.crew
	item.state = Loot.State.CARRIED
	item.carrier = id
	r.carry = item_id
	print("[server] %s %s a %s" % [r.name, "stole" if stolen else "picked up", item.label()])
	if stolen:
		stats.stolen += 1
		Net.send_message(0, "%s stole a %s from %s!" % [r.name, item.label(), crew_name(item.ship)])


func _drop_carried(id: int) -> void:
	if not players.has(id):
		return
	var r: Dictionary = players[id]
	if r.carry < 0 or not items.has(r.carry):
		r.carry = -1
		return
	var item: Loot = items[r.carry]
	r.carry = -1
	item.carrier = -1
	var ahead := Basis(Vector3.UP, r.yaw) * Vector3(0, 0, -0.8)
	if r.mode == LocalPlayer.Mode.ON_SHIP and ships.has(r.ship) and not ships[r.ship].is_sinking():
		item.state = Loot.State.ON_SHIP
		item.ship = r.ship
		var p: Vector3 = r.pos + ahead
		item.pos = Vector3(p.x, r.pos.y, p.z)
		item.yaw = r.yaw
		stats.stowed += 1
		print("[server] %s stowed a %s aboard ship %d" % [r.name, item.label(), r.ship])
		return
	var world: Vector3 = _world_pos(r) + ahead
	var island := Islands.island_at(world.x, world.z)
	var ground := Islands.ground_at(island, world.x, world.z) if island >= 0 else -99.0
	if item.fragile:
		stats.broken += 1
		story.on_fragile_broken(item)
		return
	if ground > Waves.height(world.x, world.z, time):
		item.state = Loot.State.GROUND
		item.pos = Vector3(world.x, ground + 0.05, world.z)
		item.yaw = r.yaw
	else:
		_set_floating(item, world)


## Sell what you carry to the company that buys it: chests to Silas Penny (the Gilded Hand)
## at his stall, skulls to Mother Wren (the Lantern Order).
func _sell(r: Dictionary, id := 0) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or r.carry < 0 or not items.has(r.carry):
		return
	var item: Loot = items[r.carry]
	var at := Outpost.sell_spot() if item.kind == Loot.Kind.CHEST else Outpost.mystic_spot()
	if item.kind not in [Loot.Kind.CHEST, Loot.Kind.SKULL] or r.pos.distance_to(at) > SELL_REACH + 1.0:
		return
	if story.is_keepsake(item.id):
		Net.send_message(id, "That's not for selling: someone at Port Merrow is waiting for it.")
		return
	_pay_crew(r.crew, item.value)
	stats.sold += 1
	_deed(id, "chests" if item.kind == Loot.Kind.CHEST else "skulls")
	items.erase(item.id)
	r.carry = -1
	if item.kind == Loot.Kind.CHEST:
		_add_rep(r.crew, Missions.Company.GOLD, Missions.CHEST_POINTS)
	if _belongs_to_mission(item.id, r.crew):
		_add_rep(r.crew, Missions.Company.GOLD if item.kind == Loot.Kind.CHEST else Missions.Company.SOULS, Missions.ITEM_POINTS)
	_mission_item_done(item, r.crew, true)
	print("[server] %s sold a %s for %d gold (gold %d)" % [r.name, item.label(), item.value, r.profile.gold])
	Net.send_message(0, "Sold a %s for %d gold!" % [item.label(), item.value])


## Hand a crate over to the trader on a cargo run's island (any crew's run: cargo pays
## whoever brings it).
func _deliver(r: Dictionary) -> void:
	if r.mode != LocalPlayer.Mode.WORLD or r.carry < 0 or not items.has(r.carry):
		return
	var item: Loot = items[r.carry]
	if item.kind != Loot.Kind.CRATE:
		return
	for c in crews:
		var m: Dictionary = crews[c].mission
		if m.is_empty() or m.kind != Missions.Kind.CARGO or not m.items.has(item.id):
			continue
		if r.pos.distance_to(Islands.trader_spot(m.islands[0])) > SELL_REACH + 1.0:
			return
		var gold := Missions.crate_pay(item.value, time, m.deadline)
		_pay_crew(r.crew, gold)
		stats.delivered += 1
		_deed(players.find_key(r), "crates")
		items.erase(item.id)
		r.carry = -1
		_add_rep(r.crew, Missions.Company.MERCHANT, Missions.ITEM_POINTS)
		var late := " (late, half pay)" if time > m.deadline else ""
		print("[server] %s delivered a %s for %d gold%s" % [r.name, item.label(), gold, late])
		Net.send_message(0, "Delivered a %s for %d gold%s!" % [item.label(), gold, late])
		_mission_item_done(item, r.crew, true)
		return


func _belongs_to_mission(item_id: int, crew: int) -> bool:
	var m: Dictionary = crews[crew].mission
	return not m.is_empty() and m.items.has(item_id)


func _restock(r: Dictionary, barrel: int) -> void:
	# Port Merrow's barrels are 0-2; the fort's, once it is the crew's port, FORT_BARRELS on.
	var spots := Outpost.barrels()
	if barrel >= FORT_BARRELS and fort_port(r.crew):
		spots = Fort.barrels()
		barrel -= FORT_BARRELS
	if r.mode != LocalPlayer.Mode.WORLD or barrel < 0 or barrel >= spots.size():
		return
	if r.pos.distance_to(spots[barrel]) > ITEM_REACH + 1.0:
		return
	var ship := _own(r)
	if Vector2(ship.x - r.pos.x, ship.z - r.pos.z).length() > RESTOCK_SHIP_RANGE:
		Net.send_message(players.find_key(r), "Bring the ship closer to load supplies.")
		return
	ship.cannonballs = ShipState.MAX_CANNONBALLS
	ship.planks = ShipState.MAX_PLANKS
	ship.bananas = ShipState.MAX_BANANAS
	stats.restocked += 1
	Net.send_message(0, "Supplies loaded: %d cannonballs, %d planks." % [ship.cannonballs, ship.planks])


func _open_barrel(r: Dictionary, item_id: int) -> void:
	if not items.has(item_id) or r.mode != LocalPlayer.Mode.WORLD:
		return
	var item: Loot = items[item_id]
	if item.kind != Loot.Kind.BARREL or r.pos.distance_to(item.pos) > ITEM_REACH + 1.0:
		return
	var ship := _own(r)
	if Vector2(ship.x - r.pos.x, ship.z - r.pos.z).length() > OPEN_SHIP_RANGE:
		Net.send_message(players.find_key(r), "Too far from the ship to stow these supplies.")
		return
	ship.cannonballs = mini(ShipState.MAX_CANNONBALLS, ship.cannonballs + BARREL_BALLS)
	ship.planks = mini(ShipState.MAX_PLANKS, ship.planks + BARREL_PLANKS)
	ship.bananas = mini(ShipState.MAX_BANANAS, ship.bananas + 5)
	items.erase(item_id)
	stats.restocked += 1
	Net.send_message(0, "Supplies stowed: %d cannonballs, %d planks." % [ship.cannonballs, ship.planks])


## A sunk skeleton ship leaves a captain's chest and two supply barrels floating behind.
func _drop_wreck_loot(s: ShipState) -> void:
	var at := Vector3(s.x, 0.0, s.z)
	_set_floating(_new_item(Loot.Kind.CHEST, Loot.State.FLOATING, at, _rng.randi_range(480, 720)), at)
	for dx: float in [-6.0, 6.0]:
		var p := at + Vector3(dx, 0.0, _rng.randf_range(-5.0, 5.0))
		_set_floating(_new_item(Loot.Kind.BARREL, Loot.State.FLOATING, p), p)
	stats.loot_spawned += 3


# =====================================================================================
# Fighting on foot
# =====================================================================================

func _new_skeleton(frame: int, pos: Vector3, home := -1) -> Skeleton:
	var sk := Skeleton.new()
	sk.id = _next_skeleton
	_next_skeleton += 1
	sk.frame = frame
	sk.pos = pos
	sk.home = home
	sk.yaw = _rng.randf() * TAU
	skeletons[sk.id] = sk
	return sk


func _crew_skeleton_ship(ship_id: int) -> void:
	var spots: Array[Vector3] = [
		Vector3(-1.5, ShipShape.DECK_Y, -4.6), Vector3(1.8, ShipShape.DECK_Y, -0.2), Vector3(0, ShipShape.QUARTER_Y, 8.0),
	]
	for i in SHIP_SKELETONS:
		_new_skeleton(ship_id, spots[i % spots.size()])


## A story ship: a Spanish galleon under the Admiral's raven (`flag` 1: tougher, quicker to
## reload) or a plain skeleton ship (0), appearing `distance` from the crew's ship, or at `at`.
## Returns its id.
func spawn_galleon(crew: int, distance: float, flag := 1, at := Vector3.INF) -> int:
	var own: ShipState = ships.get(crew)
	var origin := Vector2(own.x, own.z) if own else Vector2.ZERO
	var spot := origin
	for attempt in 16:
		var angle := _rng.randf() * TAU
		spot = origin + Vector2(cos(angle), sin(angle)) * distance
		var clear := true
		for island in Islands.LAYOUT:
			if spot.distance_to(Vector2(island.x, island.z)) < island.radius + 60.0:
				clear = false
		if clear:
			break
	if at != Vector3.INF:
		spot = Vector2(at.x, at.z)
	var s := ShipState.new()
	s.kind = ShipState.Kind.SKELETON
	s.flag = flag
	s.x = spot.x
	s.z = spot.y
	s.yaw = Captain.bearing(spot, origin)
	s.anchored = false
	s.sail_height = [1.0, 1.0]
	s.speed = 4.0
	var id := _next_ship_id
	_next_ship_id += 1
	ships[id] = s
	var cap := Captain.new(id)
	if flag == 1:
		cap.bail_scale = 2.0
		cap.reload_scale = 0.7
	captains[id] = cap
	var spots: Array[Vector3] = [
		Vector3(-1.5, ShipShape.DECK_Y, -4.6), Vector3(1.8, ShipShape.DECK_Y, -0.2), Vector3(0, ShipShape.QUARTER_Y, 8.0),
		Vector3(1.5, ShipShape.DECK_Y, -4.0), Vector3(-1.8, ShipShape.DECK_Y, 0.5),
	]
	for i in (StoryRun.GALLEON_CREW if flag in [1, 6] else SHIP_SKELETONS):
		var dead := _new_skeleton(id, spots[i % spots.size()])
		dead.spanish = flag in [1, 6]
		dead.ashen = flag == 6
	stats.galleons += 1
	print("[server] a Spanish galleon %d sails at (%.0f, %.0f)" % [id, spot.x, spot.y])
	Net.send_event("alarm", [])
	return id


## A board bounty's ghost galleon went down: her captain's skull floats up, the mission's prize.
func _board_ghost_sunk(ship_id: int, at: Vector3) -> void:
	for c in crews:
		var m: Dictionary = crews[c].mission
		if m.is_empty() or m.kind != Missions.Kind.BOUNTY or int(m.get("ghost", -1)) != ship_id:
			continue
		var skull := _new_item(Loot.Kind.SKULL, Loot.State.GROUND, at, int(m.skull_gold))
		_set_floating(skull, at)
		skull.born = time + 1e6
		m.items.append(skull.id)
		m.ghost = -1
		stats.skulls += 1
		print("[server] crew %d sank the ghost galleon; her captain's skull floats up" % c)
		_tell_crew(c, "The ghost galleon goes down. Her captain's skull bobs up, glowing: fish it out!")


## Does any pirate of this crew online have saltshot (story chapter c3)?
func _has_saltshot(crew: int) -> bool:
	for id in _crew_members(crew):
		if players[id].profile.chapters.has("c3"):
			return true
	return false


## E at Moll's lighthouse door goes up to the gallery round the lamp (arg 0); E at the top
## comes back down (arg 1). A bucket of water comes with you.
func _climb_lighthouse(id: int, r: Dictionary, down: int) -> void:
	if r.mode != LocalPlayer.Mode.WORLD:
		return
	var door := Outpost.lighthouse_door()
	var top := Outpost.gallery_spot()
	if down == 0 and r.pos.distance_to(door) < 3.0:
		stats.climbed += 1
		print("[server] %s climbed the lighthouse" % r.name)
		_teleport(id, LocalPlayer.Mode.WORLD, top, r.yaw)
	elif down == 1 and r.pos.distance_to(top) < 3.5:
		_teleport(id, LocalPlayer.Mode.WORLD, door, r.yaw)


## A cannonball from a fort gun at `from` (world), aimed at `aim` with a little scatter.
func fire_from(from: Vector3, aim: Vector3, error: float) -> void:
	var flat := Vector2(aim.x - from.x, aim.z - from.z)
	var elev := Ballistics.elevation(flat.length(), aim.y - from.y)
	if is_nan(elev):
		return
	var yaw := atan2(flat.y, flat.x) + _rng.randf_range(-error, error)
	elev += _rng.randf_range(-error, error) * 0.5
	var v0 := Vector3(cos(yaw) * cos(elev), sin(elev), sin(yaw) * cos(elev)) * Ballistics.MUZZLE_SPEED
	var id := _next_projectile
	_next_projectile += 1
	projectiles.append({"id": id, "t0": time, "p0": from, "v0": v0, "ship": -1, "prev": from})
	stats.shots += 1
	stats.fort_shots += 1
	Net.send_event("shot", [id, time, from.x, from.y, from.z, v0.x, v0.y, v0.z, -1, -1])


## Test hook: a skeleton ship lying still beside the crew's ship, with its skeletons aboard.
func _spawn_passive_skeleton_ship() -> void:
	var crew := crew_ship()
	var s := ShipState.new()
	s.kind = ShipState.Kind.SKELETON
	s.x = crew.x + 40.0
	s.z = crew.z
	s.anchored = true
	var id := _next_ship_id
	_next_ship_id += 1
	ships[id] = s
	captains[id] = Captain.new(id)
	_passive[id] = true
	_crew_skeleton_ship(id)
	ai_enabled = false


## Wake an island's camp when a pirate comes near it and it has no skeletons standing.
func _wake_camps() -> void:
	for i in Islands.LAYOUT.size():
		var spec: Dictionary = Islands.LAYOUT[i]
		if spec.outpost or spec.get("fort", false) or spec.get("story_only", false):
			continue
		var camp: Dictionary = camps.get(i, {"alive": 0, "wake": 0.0})
		camps[i] = camp
		if camp.alive > 0 or time < camp.wake or story.busy_island(i):
			continue
		var near := false
		for id in players:
			var w := _world_pos(players[id])
			if Vector2(w.x - spec.x, w.z - spec.z).length() < spec.radius + CAMP_WAKE:
				near = true
		if not near:
			continue
		for n in CAMP_SIZE:
			var spot := Islands.dig_spot(i, _rng)
			_new_skeleton(-1, Vector3(spot.x, Islands.ground_at(i, spot.x, spot.y), spot.y), i)
		camp.alive = CAMP_SIZE
		print("[server] the skeletons of %s awake" % spec.name)


func _step_skeletons(dt: float) -> void:
	for sid in skeletons.keys():
		var sk: Skeleton = skeletons[sid]
		if not sk.alive():
			if time - sk.fell > Skeleton.CORPSE_TIME:
				skeletons.erase(sid)
			continue
		if sk.frame >= 0 and not ships.has(sk.frame):
			skeletons.erase(sid)
			continue
		if sk.crab or sk.gideon:
			story.step_crab(sk, dt, _floor_for(sk))
			continue
		if sk.linnet:
			story.step_linnet(sk)
			continue
		if sk.guard and story.act4.step_guard(sk, dt):
			continue
		if sk.admiral and story.act4.step_admiral(sk, dt):
			continue
		if sk.thief and story.step_thief(sk, dt, _floor_for(sk)):
			continue
		var target := _skeleton_target(sk)
		var goal: Variant = null if target < 0 else _pos_in_frame(players[target], sk.frame)
		if sk.step(goal, dt, _floor_for(sk)):
			stats.skeleton_swings += 1
			Net.send_event("swing", [sk.id])
			_hurt_player(target, sk.damage, "a skeleton captain" if sk.captain else "a skeleton", -1, Weapons.Hit.BLADE)


## The nearest living player the skeleton can get at, or -1.
func _skeleton_target(sk: Skeleton) -> int:
	var best := -1
	var best_d := Skeleton.CHASE_RANGE
	for id in players:
		var r: Dictionary = players[id]
		if r.dead_until >= 0.0:
			continue
		if sk.frame >= 0 and (r.mode != LocalPlayer.Mode.ON_SHIP or r.ship != sk.frame):
			continue
		if sk.frame < 0 and r.mode != LocalPlayer.Mode.WORLD:
			continue
		var d: float = r.pos.distance_to(sk.pos)
		if d < best_d:
			best = id
			best_d = d
	return best


func _pos_in_frame(r: Dictionary, frame: int) -> Vector3:
	if frame < 0:
		return _world_pos(r)
	return r.pos


## Where a skeleton may stand: dry land on islands, the decks on ships.
func _floor_for(sk: Skeleton) -> Callable:
	if sk.frame >= 0:
		var hull := Hull.of(ships.get(sk.frame))
		return func(x: float, z: float) -> float:
			var p := Vector3(x, hull.deck_y, z)
			if not hull.is_on_board(p) or absf(x) > hull.half_width(z, hull.deck_y) - 0.5:
				return NAN
			return hull.floor_y(z, x)
	# A camp's skeletons keep to their island; the story's raised dead to the one they stand on.
	var island := sk.home if sk.home >= 0 else Islands.island_at(sk.pos.x, sk.pos.z, 4.0)
	if island < 0 and Outpost.on_pier(sk.pos.x, sk.pos.z):
		island = Islands.outpost_index()
	if island < 0:
		return func(_x: float, _z: float) -> float: return NAN
	if island == Islands.outpost_index():
		# Port Merrow: its pier's deck is ground too (the siege's dead come up on it).
		return func(x: float, z: float) -> float:
			if Outpost.on_pier(x, z):
				return Outpost.PIER_Y
			var g := Islands.ground_at(island, x, z)
			return g if g > Waves.height(x, z, time) + Skeleton.SHORE else NAN
	if Islands.LAYOUT[island].get("fort", false):
		# The fort's walls and buildings: no walking through them (the gate once blown).
		var spec: Dictionary = Islands.LAYOUT[island]
		var gate_open := story.fort_gate_open()
		return func(x: float, z: float) -> float:
			if Fort.blocked(x - spec.x, z - spec.z, gate_open):
				return NAN
			var g := Islands.ground_at(island, x, z)
			return g if g > Waves.height(x, z, time) + Skeleton.SHORE else NAN
	return func(x: float, z: float) -> float:
		var g := Islands.ground_at(island, x, z)
		return g if g > Waves.height(x, z, time) + Skeleton.SHORE else NAN


func _hurt_player(id: int, damage: int, by: String, attacker := -1, hit := Weapons.Hit.NONE) -> void:
	if not players.has(id):
		return
	var r: Dictionary = players[id]
	if r.dead_until >= 0.0:
		return
	damage = Weapons.armoured(damage, int(r.profile.get("armour", 0)), hit)
	r.hp = maxi(0, r.hp - damage)
	Net.send_event("hurt_player", [id, damage])
	if r.hp > 0:
		return
	stats.falls += 1
	if attacker >= 0:
		stats.pvp_falls += 1
		# XP for knocking down another pirate, but not again for the same one too soon.
		var key := "%d:%s" % [attacker, r.name]
		if time - float(_pvp_xp.get(key, -1e9)) >= Progress.PLAYER_XP_COOLDOWN:
			_pvp_xp[key] = time
			_award(attacker, Progress.XP_PLAYER, "knocking down %s" % r.name)
	r.dead_until = time + GHOST_TIME
	_free_station_of(id)
	_drop_carried(id)
	r.bucket = false
	print("[server] %s was felled by %s" % [r.name, by])
	Net.send_message(0, "%s has fallen to %s!" % [r.name, by])


func _step_ghosts() -> void:
	for id in players:
		var r: Dictionary = players[id]
		if r.dead_until < 0.0 or time < r.dead_until:
			continue
		if not has_ship(r.crew) and not harbour:
			continue  # at sea with no ship (tests): wait for one
		r.dead_until = -1.0
		r.hp = HEALTH
		if has_ship(r.crew):
			_teleport(id, LocalPlayer.Mode.ON_SHIP, _free_spawn(id), 0.0)
			Net.send_message(id, "Back from the brink. Welcome aboard.")
		else:
			# No ship to come back to: the crew's home port.
			_to_pier(id)
			Net.send_message(id, "Back from the brink, on Port Merrow's pier. A shipwright will sell you a ship.")


## A swing or a shot: the client says where it looked; the server decides what it hit.
func _attack(id: int, r: Dictionary, look: Array) -> void:
	if look.size() != 2 or r.station >= 0 or r.carry >= 0 or time < r.next_attack - ATTACK_SLACK:
		return
	var weapon: int = r.weapon
	# The blade and gun this pirate carries (the armoury): fair choices, each with its own feel.
	var blade := Weapons.blade(int(r.profile.get("blade", 0)))
	var gun := Weapons.gun(int(r.profile.get("gun", 0)))
	r.next_attack = time + Weapons.every(weapon, int(r.profile.get("blade", 0)), int(r.profile.get("gun", 0)))
	var basis := Basis(Vector3.UP, float(look[0])) * Basis(Vector3.RIGHT, float(look[1]))
	var dir := basis * Vector3.FORWARD
	var eye := _world_pos(r) + Vector3.UP * Weapons.EYE_HEIGHT
	if r.mode == LocalPlayer.Mode.ON_SHIP and ships.has(r.ship):
		var pose := ShipPhysics.pose_of(ships[r.ship], time)
		dir = pose.basis * dir
		eye = pose * (r.pos + Vector3.UP * Weapons.EYE_HEIGHT)
	# Targets: standing skeletons (positive ids) and living players of other crews (negative).
	var ids: Array = []
	var feet: Array = []
	for sid in skeletons:
		var sk: Skeleton = skeletons[sid]
		if sk.alive():
			ids.append(sid)
			feet.append(_skeleton_world(sk))
	for pid in players:
		var other: Dictionary = players[pid]
		if pid != id and other.crew != r.crew and other.dead_until < 0.0:
			ids.append(-pid)
			feet.append(_world_pos(other))
	# The story's powder kegs (struck kegs go off after a moment) and drowned bells (aimed at
	# where they hang).
	for k: Array in story.kegs():
		ids.append(KEG_TARGET + int(k[0]))
		feet.append(k[1] + Vector3(0, -0.5, 0))
	for b: Array in story.bells():
		ids.append(BELL_TARGET + int(b[0]))
		feet.append(b[1] + Vector3(0, -1.0, 0))
	# The lanterns of the deep (Act IV), aimed at their heads high on their posts.
	for g: Array in story.act4.lanterns():
		ids.append(LANTERN_TARGET + int(g[0]))
		feet.append(g[1] + Vector3(0, 2.6, 0))
	Net.send_event("attack", [id, weapon])
	var damage: int = blade.damage if weapon == Weapons.Kind.CUTLASS else gun.damage
	var struck: Array[int] = []
	if weapon == Weapons.Kind.CUTLASS:
		struck = Weapons.cutlass_hits(eye, dir, feet, float(blade.reach), float(blade.half_arc))
	else:
		# A ball, or a blunderbuss's spray of shot: every pellet that finds someone counts.
		for d in Weapons.pellet_dirs(dir, int(gun.pellets), float(gun.spread)):
			var i := Weapons.pistol_hit(eye, d, feet, float(gun.range))
			if i >= 0:
				struck.append(i)
	for i in struck:
		var target: int = ids[i]
		if target >= LANTERN_TARGET:
			story.act4.strike_lantern(target - LANTERN_TARGET)
		elif target >= BELL_TARGET:
			story.strike_bell(target - BELL_TARGET)
		elif target >= KEG_TARGET:
			story.strike_keg(target - KEG_TARGET)
		elif target > 0:
			var sk: Skeleton = skeletons[target]
			var from := eye if sk.frame < 0 else ShipPhysics.pose_of(ships[sk.frame], time).affine_inverse() * eye
			if sk.doctor and sk.shield_up:
				# Ocaso, while any of his braziers burns: the blow passes through green fire.
				stats.blocked += 1
				Net.send_event("shield", [target, 1])
				continue
			if sk.admiral and weapon == Weapons.Kind.CUTLASS and StoryAct4.parries(sk, from):
				# Steel rings on steel: strike him from the side or behind.
				stats.parried += 1
				Net.send_event("parry", [target])
				continue
			if sk.linnet and sk.shield_up:
				# Her lantern: a blade passes through its light; a shot knocks it from her hand.
				if weapon == Weapons.Kind.PISTOL:
					sk.shield_up = false
					stats.lanterns += 1
					print("[server] %s shot the lantern from Linnet's hand" % r.name)
					Net.send_event("lantern_shot", [target])
				continue
			if sk.sergeant and sk.blocks(from):
				# The tower shield: a blade rings off it; a shot knocks it aside for a moment.
				stats.blocked += 1
				if weapon == Weapons.Kind.PISTOL:
					sk.shield_up = false
					sk.shield_down_until = time + Skeleton.SHIELD_DOWN
					Net.send_event("shield", [target, 0])
				else:
					Net.send_event("shield", [target, 1])
				continue
			_hurt_skeleton(target, damage, r.name, id)
		else:
			_hurt_player(-target, damage, "%s of %s" % [r.name, crew_name(r.crew)], id, Weapons.Hit.BLADE if weapon == Weapons.Kind.CUTLASS else Weapons.Hit.SHOT)


func _skeleton_world(sk: Skeleton) -> Vector3:
	if sk.frame >= 0 and ships.has(sk.frame):
		return ShipPhysics.pose_of(ships[sk.frame], time) * sk.pos
	return sk.pos


## `attacker`: the player who struck (for the XP), or -1.
func _hurt_skeleton(sid: int, damage: int, by: String, attacker := -1) -> void:
	var sk: Skeleton = skeletons[sid]
	if not sk.alive():
		return
	if sk.guard:
		story.act4.raise_alarm(sk.story_crew, by)
	if sk.admiral and damage > 0:
		print("[server] the Raven Admiral is wounded by %s (%d left)" % [by, sk.hp - damage])
	sk.hp -= damage
	Net.send_event("hurt_skeleton", [sid, damage])
	if sk.hp > 0:
		return
	sk.fell = time
	stats.kills += 1
	_deed(attacker, "skeletons")
	print("[server] %s felled skeleton %d" % [by, sid])
	var xp := Progress.XP_SPANISH if sk.spanish else Progress.XP_SKELETON
	if sk.captain:
		xp = Progress.XP_CAPTAIN
	if sk.sergeant:
		xp = Progress.XP_BOSS
	if sk.crab:
		xp = 0
	if sk.gideon:
		xp = Progress.XP_CAPTAIN
	if sk.bomber or sk.sniper:
		xp = Progress.XP_BOSS
	_award(attacker, xp, "felling a skeleton")
	story.on_skeleton_fell(sk)
	if sk.ashen or sk.ash or sk.doctor:
		var at := _skeleton_world(sk)
		Net.send_event("ash_burst", [at.x, at.y, at.z])
	if sk.captain:
		_drop_skull(sk)
	if sk.home >= 0 and camps.has(sk.home):
		camps[sk.home].alive -= 1
		if camps[sk.home].alive <= 0:
			camps[sk.home].wake = time + CAMP_RESPAWN
			Net.send_message(0, "The skeletons of %s are beaten!" % Islands.LAYOUT[sk.home].name)


## A bounty's captain has fallen: his skull lies where he fell, for whoever picks it up.
func _drop_skull(sk: Skeleton) -> void:
	if story.on_captain_fell(sk):
		return
	for c in crews:
		var m: Dictionary = crews[c].mission
		if m.is_empty() or m.kind != Missions.Kind.BOUNTY or m.captain != sk.id:
			continue
		var skull := _new_item(Loot.Kind.SKULL, Loot.State.GROUND, _skeleton_world(sk) + Vector3(0, 0.05, 0), m.skull_gold)
		m.items.append(skull.id)
		stats.skulls += 1
		print("[server] %s has fallen; his skull is worth %d" % [m.name, skull.value])
		Net.send_message(0, "%s has fallen! His skull glows on the sand." % m.name)
		return


func _crew_of_ship(ship_id: int) -> int:
	return ships[ship_id].crew if ships.has(ship_id) else 0


## A cannonball hurts anyone near where it lands, except the crew that fired it.
func _splash(world: Vector3, shooter_crew := 0) -> void:
	story.splash(world)
	for id in players:
		var r: Dictionary = players[id]
		if r.crew == shooter_crew:
			continue
		var dmg := Weapons.splash_damage(_world_pos(r).distance_to(world))
		if dmg > 0:
			_hurt_player(id, dmg, "a cannonball", -1, Weapons.Hit.SHOT)
	for sid in skeletons.keys():
		var sk: Skeleton = skeletons[sid]
		if sk.alive():
			var dmg := Weapons.splash_damage(_skeleton_world(sk).distance_to(world))
			if dmg > 0:
				_hurt_skeleton(sid, dmg, "a cannonball")


func _eat(r: Dictionary) -> void:
	var ship := _own(r)
	if r.mode != LocalPlayer.Mode.ON_SHIP or r.ship != r.crew or ship.bananas <= 0 or r.hp >= HEALTH:
		return
	if r.pos.distance_to(Hull.of(ships.get(r.ship)).bananas_at) > EAT_REACH + 1.0:
		return
	ship.bananas -= 1
	r.hp = mini(HEALTH, r.hp + BANANA_HEAL)
	stats.eaten += 1
	Net.send_message(players.find_key(r), "Mmm, banana. (%d left)" % ship.bananas)



## Stricter checks on where a player says they are in the world: not inside an island.
func _plausible_in_world(p: Vector3) -> bool:
	var island := Islands.island_at(p.x, p.z)
	if island >= 0 and p.y < Islands.ground_at(island, p.x, p.z) - 0.6:
		return false
	return p.y > -6.0 and p.y < 60.0

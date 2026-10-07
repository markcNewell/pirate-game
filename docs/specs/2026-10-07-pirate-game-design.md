# Pirate game: design

Status: agreed 07-10-2026 (brainstorm). Mark said "build it" after section 1, so sections 2-5
hold Claude's recommended defaults. Change anything here and the code follows.

## In one paragraph

A first-person co-op pirate game in the spirit of Sea of Thieves, in a toon style with ink
outlines (style B on the [style board](https://claude.ai/artifact/N5LAHyfEAzEDRiVkiXccTW)).
Friends crew one ship together on a shared sea hosted by a dedicated server. It is built in
Godot 4 with GDScript, and it ships as a Windows download plus a Linux server. It is built in
five playable milestones. This document designs the whole game lightly and milestone 1 in full.

## Glossary

| Word | Meaning here |
|---|---|
| Client | The game on a player's PC. It draws the world and sends what the player presses. |
| Dedicated server | The same game started with `--server` and no graphics. It owns the truth. |
| Host & play | A development shortcut: one PC runs the server and plays at the same time. |
| Station | A ship control a player takes over: the wheel, a mast's sail ropes, the anchor capstan. |
| Ship frame | Coordinates fixed to the deck. Players on board move in this frame, so the rocking ship carries them. |
| Deck proxy | A still, invisible copy of the ship's collision that on-board players walk on. |
| Snapshot | A packet the server sends ~30 times a second with ship and player state. |
| Toon shading | Lighting in 3 flat steps instead of a smooth gradient, plus dark outlines. |

## Milestones

Each milestone is playable and gets its own spec, plan and build.

1. **Sail together**: sea, one ship, 2-4 friends on a server, walk the moving deck, sails, wheel,
   anchor, swim, islands as landmarks. *(this document)*
2. **Ship combat**: cannons, holes below the waterline, bailing, patching, sinking, AI ships, lower deck.
3. **Treasure hunting**: maps, digging, carrying chests, an outpost to cash in, gold.
4. **Fighting on foot**: sword, pistol, skeletons on treasure islands, health and respawn.
5. **Crew vs crew**: several player ships on one server, PvP, server-checked movement.

## Decisions so far

| Topic | Decision | Why |
|---|---|---|
| Players | Co-op with friends, crew of up to 4 on one ship | The Sea of Thieves core |
| Platform | PC download (Windows client, Linux server) | Best performance; friends install once |
| Who builds | Claude writes code and scenes; Mark play-tests and steers | Favours text-based Godot files |
| Engine | Godot 4.7 (pinned 4.7.2), GDScript | Plain-text scenes, Python-like, built-in multiplayer, free |
| Hosting | Dedicated server, headless build in Docker on a small VPS | Robust; ready for crew vs crew |
| Camera | First-person | Best for working the ship together; least animation work |
| Art style | Toon with ink outlines, banded cartoon sea, foam rings | Mark's pick; models stay simple |
| Art source | Built from code first; free CC0 packs and Blender (+ Blender MCP) later | "Start simple" |

## 1. How the game is put together (agreed)

- One Godot project. The same build runs as a client, or with `--server` as a headless server.
- The server is the referee for everything that matters: the ship, the wind, the stations,
  who is on board. Clients send inputs.
- Players on board live in the **ship frame**: they walk on a still deck proxy, and what you
  see is the proxy position carried onto the moving, rocking ship. Nobody slides off.
- The sea is one shared formula driven by the server clock: the server floats the ship with it,
  the graphics card draws the sea with it, and no water data is sent.

Milestone 1 simplification: **your own walking is decided on your PC** and sent to the server,
which checks it (speed limit, still inside the world) and snaps you back if it is impossible.
That feels instant and is fine among friends. Milestone 5 (PvP) moves walking onto the server
with prediction and replay.

## 2. Look and art pipeline (default)

- **Toon material**: one Godot shader with 3-step lighting, a soft rim and a colour per object.
  An outline pass draws each object again, slightly inflated and inside out, in dark ink.
  Code-built meshes store smoothed normals for the outline so boxes do not crack at corners.
- **Sea**: one big grid that follows the camera. The shader moves its vertices with the wave
  formula and colours it in three blue bands, with white caps on high crests, foam rings around
  islands and a foam ring around the hull. Distance fog fades it into the sky.
- **Sky**: gradient sky with a hard toon sun and a few outlined cloud blobs.
- **Models, milestone 1**: ship, islands, palms, rocks and pirates are built from code
  (like the style board), so nothing needs a modelling tool yet. Later milestones swap in
  Blender models (glTF/.blend import) and CC0 packs (Kenney, Quaternius) where they fit.

## 3. Milestone 1 "Sail together" in detail (default)

**Joining.** Main menu: name, server address, *Join*, *Host & play*, *Quit*. The server checks
the game version on join. Up to 4 players. Everyone spawns on the main deck.

**The ship.** A galleon about 26 m long and 7.5 m wide, main deck 3 m above the water,
a raised quarterdeck at the stern with stairs, two masts with two square sails each,
a ladder on each side, a black flag.

| Station | Where | Controls |
|---|---|---|
| Wheel | Quarterdeck | A / D turn the rudder (it stays where you leave it) |
| Sail ropes | Foot of each mast | W / S raise or lower that mast's sails; A / D swing them across the wind |
| Anchor capstan | Front of the main deck | E drops it; hold E to winch it up (about 4 s) |

Press E to take a station, and E again to leave it. One player per station.

**Sailing.** A wind blows from a direction that slowly swings round (a full turn in about
20 minutes). Push from the sails = how high they are × how well they face the wind
(always at least a quarter, so you can creep upwind). Top speed is about 8 m/s (15 knots).
The rudder turns the ship faster the quicker it moves. The anchor stops the ship over a few
seconds. Hitting an island stops the ship dead (no damage until milestone 2).

**Moving about.** WASD, mouse look, Shift to run, Space to jump. Fall or jump overboard and you
swim on the waves. Climb back up a side ladder with E, or swim to an island and walk on it.
Swim too far from your ship (500 m) and you can respawn on deck from the menu.

**Screen.** Crosshair, "E: take the wheel"-style prompts, a compass strip, a wind arrow and
the ship's speed. Tab shows the crew list. Esc opens a menu with mouse sensitivity,
*Respawn on ship* and *Leave game*.

**The world.** Open toon sea with three islands (one large, two small) to sail around.
No gameplay on them yet.

**Not in milestone 1:** voice or text chat (use Discord), damage, cannons, lower deck,
treasure, animations beyond a simple walking bob, sound beyond a few ambient loops (if time).

**Done when:**

1. Two to four clients join a headless server, locally or on a VPS.
2. Players walk around the deck while the ship sails and rocks, without sliding or jitter.
3. One steers, one works the sails, one handles the anchor, and everyone sees the same ship
   and each other.
4. Falling overboard, swimming, climbing a ladder and walking on an island all work.
5. The server runs for 30 minutes without trouble, and players can leave and rejoin.
6. Automated tests pass, including a headless test where bot players join and sail.
7. A Windows build and a Linux server build export from the command line.

## 4. Testing and tooling (default)

- **Unit tests** for the maths that must be right: waves, ship pose, sail push, steering,
  anchor, ship-frame conversion, input checks. A small built-in test runner, run headless with
  `godot --headless -s tests/run_tests.gd`.
- **Bot smoke test**: a headless server plus two bot clients in separate processes. The bots
  join, walk, take the wheel and raise the sails; the test passes when the server sees the ship
  move and both bots stay in sync.
- **Screenshots**: a container with a virtual display renders the game so Claude can check the
  look without a monitor.
- **Builds**: export presets for Windows (client) and Linux (server). GitHub Actions runs the
  tests on every push and exports both builds on a `v*` tag as a GitHub release.
- **Server hosting**: Dockerfile and a short guide for a small VPS (for example Hetzner).
  Renting one is Mark's call.

## 5. Technical detail

### Folders

```
project.godot
game/main.gd, main.tscn      entry point: menu, starts client and/or server
game/ocean/                  waves.gd (shared formula), ocean.gdshader, ocean.gd (follows camera)
game/ship/                   ship_shape.gd (dimensions), ship_mesh.gd (code-built model),
                             ship_physics.gd (pure sailing maths), ship.gd (node), deck_proxy.gd,
                             stations.gd
game/player/                 player_motor.gd (pure movement rules), player.gd (local), avatar.gd (others)
game/net/                    net.gd (autoload: peer, RPCs, snapshots), protocol.gd, clock.gd
game/world/                  world.gd (sea, sky, islands, wind), island_mesh.gd, sky
game/ui/                     menu, HUD
art/shaders/                 toon.gdshader, outline.gdshader
tests/                       run_tests.gd, test_*.gd, bot smoke test
server/                      Dockerfile, run script, VPS guide
docs/specs, docs/plans
```

### Networking

- ENet over UDP, default port 24565. Godot high-level multiplayer with `@rpc`.
- Join: client sends `hello(name, version)`; server replies `welcome(id, server_time, world)`
  or `refused(reason)`.
- Server → all, ~30 Hz, unreliable ordered: snapshot of the ship (x, z, heading, speed, rudder,
  sail heights and angles, anchor state), the wind, and each player (mode, position in its
  frame, look angles, station).
- Client → server, ~30 Hz, unreliable ordered: own player state. At a station: control axes.
- Reliable RPCs for events: take/leave station, anchor drop, climb ladder, respawn.
- Clocks: the client estimates server time from snapshots (smoothed offset). The sea shader,
  wave sampling and interpolation all use that estimate, so everyone sees the same waves.
- Remote players and the ship are drawn ~100 ms in the past, interpolated between snapshots.
  The ship's rocking (heave, pitch, roll) is not sent: every machine works it out from the
  wave formula, the ship position and the shared clock.

### Ship frame and the deck proxy

- Each ship has a static collision copy (deck, rails, quarterdeck, stairs, masts) on its own
  physics layer, parked far below the world. Boarded players are `CharacterBody3D`s that walk
  on it with gravity pointing down the ship's own axis.
- Drawn position = ship's world transform × (proxy offset⁻¹ × body position). The camera is a
  child of that, so it rocks with the ship.
- Leaving the proxy (walking off the side, falling below the deck) converts the player to
  world coordinates and swimming. Climbing a ladder converts back to the ship frame.

### Sea formula

Height = sum of four sine waves of different lengths, directions and speeds (amplitude about
0.6 m in total for milestone 1). The GDScript and shader versions are kept identical, and a
test checks the constants match.

### Ship pose

Each frame, sample the sea at bow, stern, port, starboard and centre. Heave is the weighted
average, pitch and roll come from the differences, and they are smoothed with a spring so the
ship feels heavy. Every machine computes this itself from synced inputs.

# Pirate Game

A first-person co-op pirate game in a toon style, in the spirit of Sea of Thieves. Friends crew
one ship together on a shared sea hosted by a dedicated server. Built with Godot 4.7 (GDScript).

**Status: all five milestones built.** Up to four crews of four players, each with its own galleon:
sailing, swimming, cannons, skeleton ships, holes, patching, bailing and sinking; treasure maps,
digging and selling at Port Merrow; health, cutlass and pistol, skeleton camps and boarding; and
crew vs crew: fight other crews, sink their ships and steal their chests. The sea has a
24-minute day with sunsets, starry nights and lanterns, a storm that roams the map with big
waves, gusts and lightning that can hole your ship, and sound throughout. Specs:
[design](docs/specs/2026-10-07-pirate-game-design.md), [2](docs/specs/2026-10-07-m2-ship-combat.md),
[3](docs/specs/2026-10-07-m3-treasure.md), [4](docs/specs/2026-10-07-m4-fighting.md),
[5](docs/specs/2026-10-07-m5-crew-vs-crew.md), [art pass](docs/specs/2026-10-07-art-pass-1.md), [storm](docs/specs/2026-10-07-storm.md).

![The title screen](docs/screenshots/title.png)

| | |
|---|---|
| ![Under sail](docs/screenshots/ship-under-sail.png) | ![At the wheel](docs/screenshots/at-the-wheel.png) |
| ![Crew on deck, island ahead](docs/screenshots/crew-and-island.png) | ![An island](docs/screenshots/island.png) |
| ![A skeleton ship firing](docs/screenshots/skeleton-ship.png) | ![Holes on the lower deck](docs/screenshots/lower-deck.png) |
| ![Port Merrow](docs/screenshots/outpost.png) | ![A treasure map](docs/screenshots/treasure-map.png) |
| ![Skeletons on Parrot Rock](docs/screenshots/skeletons.png) | ![Two crews' ships](docs/screenshots/two-crews.png) |
| ![Sunset](docs/screenshots/sunset.png) | ![Night, lanterns lit](docs/screenshots/night.png) |
| ![A storm on the horizon, with a rainbow](docs/screenshots/storm.png) | ![Inside the storm](docs/screenshots/in-the-storm.png) |
| ![Port Merrow's lighthouse at night](docs/screenshots/lighthouse-night.png) | ![The rock arch on Gull Isle](docs/screenshots/gull-isle-arch.png) |
| ![The tavern at Port Merrow](docs/screenshots/tavern.png) | |

## Play

**From a release** (Windows): download `PirateGame-windows-*.zip` from the repo's Releases, unzip,
run `PirateGame.exe`.

**From source**: install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/),
open this folder as a project and press Play (F5).

On the title screen:

- **Host & play** runs a server inside your game and puts you on deck. Good for trying it alone,
  or for friends on the same network to join you.
- **Join** connects to a server address (default port 24565).
- **Crew** picks which of the four crews to sail with. "Any crew" fills crew 1 first, so friends
  who all pick it end up on the same ship.

| Key | On foot | At the wheel | At the sail ropes | At the anchor |
|---|---|---|---|---|
| W / S | walk | | let sail out / take it in | hold W: winch up; S: drop |
| A / D | strafe | turn the wheel | swing the sails | |
| Mouse | look | look | look | look |
| E | use a station or ladder | let go | let go | let go |
| Shift / Space | run / jump | | | |
| Tab / Esc | crew list / menu | | | |

| Below decks and at the guns | |
|---|---|
| Cannon | E to man it, mouse to aim, left click to fire (3 s reload) |
| Hatch | E at the hatch in front of the main mast climbs down; E at the ladder foot climbs up |
| Patch a hole | look at it and hold E for 2 s |
| Bail | E in the water below fills your bucket; E on deck throws it overboard |
| Treasure | E at the map table (beside the wheel) for a voyage; hold M to read the map |
| Dig | on an island, hold E for 2 s; at the X a chest comes up |
| Chests | E picks up and puts down; carry one to the merchant at Port Merrow and press E to sell |
| Supplies | E at a supply barrel (Port Merrow's pier, or floating after a fight) refills the ship |
| Fight | 1 cutlass, 2 pistol, left click to attack; skeletons guard every treasure island |
| Board | swim to a skeleton ship and E at its ladder |
| Heal | E at the banana barrel on the lower deck |
| Other crews | their names show red; you can fight them, board their ship and steal its chests |

The ship starts at anchor with its sails furled. Winch the anchor up, let the sails out, and
watch the wind arrow at the bottom left: sails pull hardest with the wind behind them, and you
can swing them (A / D at the ropes) to catch a side wind.

## Run a server for friends

The same game runs as a dedicated server with no graphics:

```
PirateGame.exe --headless -- --server --port 24565        # Windows
./pirate-game-server.x86_64 --headless -- --server        # Linux (from a release)
```

Open UDP port 24565 and give friends your address. For an always-on server on a small cloud
machine, see [server/README.md](server/README.md).

## Develop

| What | Command |
|---|---|
| Unit tests | `godot --headless --path . -s tests/run_tests.gd` |
| Bot smoke test (server + 4 bots) | `tests/smoke/smoke_test.sh` |
| Combat smoke test (fight + sinking) | `tests/smoke/combat_test.sh` |
| Treasure smoke test (dig + sell) | `tests/smoke/treasure_test.sh` |
| Fighting smoke test (island + boarding) | `tests/smoke/fighting_test.sh` |
| Crew-vs-crew smoke test (duel, broadsides, theft) | `tests/smoke/crew_test.sh` |
| Storm smoke test (lightning strikes a ship) | `tests/smoke/storm_test.sh` |
| Every smoke test at once | `tools/smoke_all.sh` |
| Rebuild the sounds | `python3 tools/make_sounds.py` |
| Import and unit tests in one go | `tools/check.sh` |
| Screenshot without a monitor | `tools/screenshot.sh /tmp/shot.png outside --demo` |
| Export Windows + server builds | `tools/export.sh` |
| Release | push a tag like `v0.1.0`; CI builds both and publishes a GitHub release |

Run `godot --headless --path . --import` once after cloning so Godot registers the script classes.

Useful command-line options (after `--`): `--host`, `--join ADDRESS`, `--port N`, `--name NAME`,
`--demo` (host under full sail), `--bot wheel|sails|anchor|swimmer|gunner|repair`,
`--quit-after SECONDS`, `--no-ai`, `--ai-delay SECONDS`, `--test-holes N`, `--start-near N|outpost`,
`--voyage-island N`, `--test-chest`, `--test-boarding`, `--crew N`, `--crews-close`, `--test-steal`,
`--time T` (pin the time of day: 0 midnight, 0.5 noon, 0.79 sunset), `--storm X,Z` (pin the storm)
and `--calm` (server: no storm).
Bots also take `treasure`, `seller`, `fighter`, `boarder`, `duelist` and `thief`.

### How it fits together

- `game/game.gd`: one session. The server half owns the ship and the crew list and sends
  snapshots 30 times a second; the client half draws everything 0.1 s in the past, blending
  snapshots, and runs your player.
- `game/net/net.gd`: the network transport (ENet over UDP) and every message.
- `game/ocean/waves.gd`: the one sea formula, shared by the server's ship physics and the sea shader.
- `game/ship/`: layout (`ship_shape.gd`), sailing maths (`ship_physics.gd`), the code-built model
  (`ship_mesh.gd`), and the still deck copy players walk on (`deck_proxy.gd`).
- `game/player/`: movement rules, your player, other players, test bots.
- `game/world/`: islands, the outpost, the time of day (`daylight.gd`) and the storm
  (`storm.gd` says where it is, `storm_view.gd` draws it). Both run off the shared server clock,
  so every player sees the same sunset and the same storm.
- `art/shaders/`: toon lighting, ink outlines, sky, rain.
- `art/sounds/`: every sound, synthesised by `tools/make_sounds.py` (numpy; nothing recorded or
  downloaded; the title tune is the traditional "Drunken Sailor"). `game/audio/audio.gd` (the
  `Audio` autoload) plays them: one-shots in the world, ambience loops that follow the scene,
  and music. Volume and music sliders are on the title screen.

Everything you see is built from code for now; Blender models arrive in later milestones.

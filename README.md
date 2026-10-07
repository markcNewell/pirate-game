# Pirate Game

A first-person co-op pirate game in a toon style, in the spirit of Sea of Thieves. Friends crew
one ship together on a shared sea hosted by a dedicated server. Built with Godot 4.7 (GDScript).

**Status: milestone 1, "Sail together".** One galleon, up to 4 players, sails, wheel, anchor,
swimming, ladders and three islands to sail around. Combat, treasure and skeletons come in later
milestones; see the [design spec](docs/specs/2026-10-07-pirate-game-design.md).

| | |
|---|---|
| ![Under sail](docs/screenshots/ship-under-sail.png) | ![At the wheel](docs/screenshots/at-the-wheel.png) |
| ![Crew on deck, island ahead](docs/screenshots/crew-and-island.png) | ![An island](docs/screenshots/island.png) |

## Play

**From a release** (Windows): download `PirateGame-windows-*.zip` from the repo's Releases, unzip,
run `PirateGame.exe`.

**From source**: install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/),
open this folder as a project and press Play (F5).

On the title screen:

- **Host & play** runs a server inside your game and puts you on deck. Good for trying it alone,
  or for friends on the same network to join you.
- **Join** connects to a server address (default port 24565).

| Key | On foot | At the wheel | At the sail ropes | At the anchor |
|---|---|---|---|---|
| W / S | walk | | let sail out / take it in | hold W: winch up; S: drop |
| A / D | strafe | turn the wheel | swing the sails | |
| Mouse | look | look | look | look |
| E | use a station or ladder | let go | let go | let go |
| Shift / Space | run / jump | | | |
| Tab / Esc | crew list / menu | | | |

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
| Screenshot without a monitor | `tools/screenshot.sh /tmp/shot.png outside --demo` |
| Export Windows + server builds | `tools/export.sh` |
| Release | push a tag like `v0.1.0`; CI builds both and publishes a GitHub release |

Run `godot --headless --path . --import` once after cloning so Godot registers the script classes.

Useful command-line options (after `--`): `--host`, `--join ADDRESS`, `--port N`, `--name NAME`,
`--demo` (host under full sail), `--bot wheel|sails|anchor|swimmer`, `--quit-after SECONDS`.

### How it fits together

- `game/game.gd`: one session. The server half owns the ship and the crew list and sends
  snapshots 30 times a second; the client half draws everything 0.1 s in the past, blending
  snapshots, and runs your player.
- `game/net/net.gd`: the network transport (ENet over UDP) and every message.
- `game/ocean/waves.gd`: the one sea formula, shared by the server's ship physics and the sea shader.
- `game/ship/`: layout (`ship_shape.gd`), sailing maths (`ship_physics.gd`), the code-built model
  (`ship_mesh.gd`), and the still deck copy players walk on (`deck_proxy.gd`).
- `game/player/`: movement rules, your player, other players, test bots.
- `art/shaders/`: toon lighting, ink outlines, sky.

Everything you see is built from code for now; Blender models arrive in later milestones.

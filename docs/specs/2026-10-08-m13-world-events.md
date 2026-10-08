# Milestone 13: World events

Status: built 08-10-2026, after the whole story (M7-M12), with `tests/smoke/world_test.sh`. The story doc
(docs/specs/2026-10-08-story.md, "World events") lists seven; this milestone builds five. Every
choice below is Claude's default; change anything and the code follows.

## In one paragraph

Now and then something happens on the shared sea that every crew can join, whatever chapter they
are on: green fires on an island at night, a Spanish galleon on patrol, a gold convoy running for
the fort, the dead raiding Port Merrow, a ghost galleon rising in the storm. The whole server is
told, the map marks it, and whoever takes part gets the reward. The story explains each one as
you go, but they all run from the start (the raid waits until someone has played Act III).

## Glossary

| Word | Meaning here |
|---|---|
| World event | Something on the shared sea any crew can join. One at a time. |
| Taking part | Being within 150 m of the event's place when it is won (or, for a ship, having hit it). |

## The events as built

| Event | What happens | Won when | Reward (everyone taking part) |
|---|---|---|---|
| **Green Fire** | At night, three green fires light on one of the treasure islands. While any burns and a pirate is near, two dead climb out every 20 s (no more than eight). | All three doused (a bucket each). | A chest on the beach; 200 XP. |
| **Raven Patrol** | A Spanish galleon sails a loop round the Isles. She leaves crews alone unless one comes within 150 m. | She is sunk (her captain's chest floats up as usual). | 250 XP (as for any galleon) |
| **Gold Convoy** | A Spanish treasure galleon with three chests on deck runs from Cutlass Cay for the fort, two skeleton ships beside her. | Her chests are taken (or she sinks, and they float). | The chests; 150 XP for each brought aboard. |
| **Raid on Merrow** | Two boats' worth of the dead land on Port Merrow's beach: two waves of six. Only once someone on the server has finished Act III. | Both waves felled. | 300 XP and 150 gold. |
| **Ghost Galleon** | When a crew sails deep into the roaming storm, a ghost galleon rises beside them and hunts them. | She is sunk. | A captain's skull floats up (worth 300-500 to Wren). |

Not built yet: **Fuerte del Cuervo** re-garrisoning, and **The Maw Stirs** (after the story).

## Rules

- **When**: the first event 5 minutes after a server starts with someone on it, then one 8
  minutes after the last ended. Green Fire only starts at night (another is picked by day); the
  raid only once someone online has finished chapter 18. The Ghost Galleon is not on the clock:
  it comes when a crew is deep in the storm (more than half way to its heart), not on a story
  chapter (those bring their own ghosts), and no other event is running; at most once every 10
  minutes.
- **How long**: an event that nobody wins ends by itself after 10 minutes (the fires burn out,
  the patrol and convoy sail off over the horizon, the raiders crumble at dawn).
- **Telling everyone**: a message to every player when it starts and ends, and a green line in
  the top corner of the screen while it runs, saying how far away it is and which way; a green
  diamond on the compass points to it (added in M17).
- **Story chapters come first**: no event starts on an island a crew's chapter is using.
- `--no-ai` turns the clock off (tests); `--event NAME` starts one at once (green_fire, patrol,
  convoy or raid), placed by the crew's ship.

## Done when

1. Unit tests: each event starts, runs and is won; the clock, night-only fires and the raid's
   gate; nobody wins and it ends; the rewards reach everyone taking part and only them.
2. A smoke test: a bot douses a world green fire; the patrol turns on a crew and a bot mans a
   cannon against her.
3. All earlier tests and smoke tests pass.

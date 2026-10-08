# Milestone 18: The fort and the Maw

Status: built 08-10-2026, with two more scenarios in `tests/smoke/world_test.sh`. The last two of the story doc's seven world events (docs/specs/2026-10-08-story.md,
"World events"; M13 built the other five). Every number below is Claude's default; change anything
and the code follows.

## In one paragraph

Two world events for crews who have got far enough. **Fuerte del Cuervo**: once someone on the
server has stormed the fort in Act II, the dead now and then take it back: its two tower guns are
run out again, two waves of the Spanish dead hold the courtyard, and the vault behind them is full.
**The Maw Stirs**: once someone has finished the story, the Black Reef wakes for a night: two
ghost galleons rise at its edge and a lesser Bone Colossus stands up in the Maw. Fell it and a big
chest comes up out of the whirlpool, and everyone who fought gets a rare shirt dye, Maw-green.

## Glossary

| Word | Meaning here |
|---|---|
| Lesser colossus | The Act V giant again, but weaker: four hits break a joint, not eight. It stays in the Maw (no Anvil). |
| Taking part | As in M13: within 150 m of the event's place when it is won (300 m for the Maw, where the fight is at range). |

## The events

| Event | When it can come | What happens | Won when | Reward (everyone taking part) |
|---|---|---|---|---|
| **Fuerte del Cuervo** | Someone online has finished Act II's finale (chapter b6); no crew's chapter is using the fort. | The two tower guns fire at any crew ship in range (as in b6: two hits from a cannonball or a keg silence one). Six Spanish dead in the courtyard; when they fall, six more. | Both waves felled. | The vault opens: four chests at its door; 300 XP. |
| **The Maw Stirs** | Night, and someone online has finished the story (chapter e6). | Two ghost galleons rise at the Reef's edge and hunt the nearest crew. A lesser colossus stands in the Maw and throws wreckage (or slams, close in) at the nearest ship, as in Act V. | All four of its joints broken by cannon fire. | A big chest (900-1300 gold) floats up at the Maw's edge; 400 XP; the Maw-green dye (a gift, never sold). |

## Rules

- Both join the M13 clock (one event at a time, 8 minutes apart, 10 minutes each) and its
  messages, top-corner line and compass mark.
- Nobody wins: the fort's garrison holds and its guns fall silent; at dawn (or after 10 minutes)
  the giant sinks back into the Maw and the ghosts go with it.
- The fort's gate stays shut to the dead: the garrison holds the courtyard, and pirates come in
  through the gap where Act II's gate was blown.
- The Black Reef still tears ships without the pilot's chart (chapter d2), so only crews who have
  played Act IV can reach the Maw; everyone who has finished the story has.
- `--event fort` and `--event maw` start them at once (tests).

## New things to see

Nothing new to model: the tower guns, the Spanish dead, the ghost galleons and the Colossus are
all from the story. The Maw-green dye is a new colour at Martha's, marked "a gift" until given.

## Done when

1. Unit tests: each event's gate (b6 / e6 and night); the fort's guns firing and being silenced,
   its two waves and the vault; the giant's joints breaking at four hits, its fall, the chest and
   the dye reaching only those taking part; nobody wins and each ends.
2. The world smoke test also: a bot fights the fort's garrison; a bot's crew breaks a joint of the
   lesser colossus.
3. All earlier tests and smoke tests pass.

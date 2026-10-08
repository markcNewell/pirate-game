# Milestone 12: The Heart of Ash (Act V and the epilogue)

Status: written 08-10-2026, the last build step of the story (docs/specs/2026-10-08-story.md).
Every choice below is Claude's default; change anything and the code follows. Where the story doc
asked for more than one night's work, this says what is built instead.

## In one paragraph

Act V, from pirate level 18: the end. The crews dive to the sunken *Cuervo Negro* and learn that
Ocaso never served Spain: the Heart talks to him, and it wants every drowned soul to walk. They
storm Isla Ceniza through its ashen dead and beat the Doctor among his braziers; rally every hand
in the Isles; break the risen fleet and the Ash Admiral's burning flagship at the Maw; and then,
with every crew on the server called, bring down the Bone Colossus, beat the Ash Admiral for good
on the rock where it falls, and carry the burning Heart to the edge of the Maw and throw it in.
Every skeleton on the sea crumbles. The epilogue is a party at the Drowned Rat.

## Glossary

| Word | Meaning here |
|---|---|
| The Maw | A whirlpool in the middle of the Black Reef, where the Heart came from. |
| The Anvil | A flat black rock beside the Maw, where the Colossus falls. |
| Ashen dead | Spanish dead burned black, flames in their ribs; they burst into green fire when they fall. |
| Brazier | A fire basket of green flame on Isla Ceniza. While any of Ocaso's three burn, he cannot be hurt. A bucket of water puts one out. |
| Beacon | A great woodpile on an island's height. E lights it, calling every crew. |
| The Ash Admiral | The Raven Admiral raised by the Heart, burned black and crowned with green fire. Faster than before. |
| The Bone Colossus | A giant of the drowned fleet's bones, waist-deep in the Maw. Four glowing joints (shoulders and knees). |
| The Heart of Ash | A stone burning with green fire. Carrying it hurts, and you can't fight while you do. |

## New places

| Place | Where | Look |
|---|---|---|
| Ocaso's workshop | Isla Ceniza's hill | A stone hut dug into the hill, a chimney of green smoke, green glass windows, bottles and a long table. |
| The Maw | The middle of the Black Reef | A slow whirlpool, dark in the middle, rings of foam turning round it. |
| The Anvil | Beside the Maw | A small flat-topped black rock, a slope down to its shore. |

## The chapters as built

| # | Chapter | Giver | What you do | XP / gold |
|---|---|---|---|---|
| 25 | What the Admiral Knew | Wren | Dive on the wreck of the *Cuervo Negro* in the Reef (hold E over her). The Admiral's journal: Ocaso hears the Heart, and the Heart wants every drowned soul to walk. | 900 / 250 |
| 26 | Isla Ceniza | Isabel | Land on Isla Ceniza: the ashen dead come at you on the beach (two waves of four). Up the hill to the workshop: Doctor Ocaso jumps between three braziers in bursts of green fire, raising two dead where he lands. Douse the braziers (bucket from the sea) and he can be hurt. | 1,100 / 350 |
| 27 | Every Hand | Quill | Three jobs: carry three crates of saltshot from the pier to the ships at Merrow's battery; light the beacons on Cutlass Cay, Parrot Rock and Gull Isle; carry Wren's lantern to the edge of the Black Reef. | 1,000 / 300 |
| 28 | The Ash Admiral | Isabel | At the Maw: four risen galleons, then the Ash Admiral's burning flagship, which can be sunk now. | 1,300 / 400 |
| 29 | The Bone Colossus | Wren | Call to arms. 1: at sea, break the Colossus's four glowing joints with cannon (eight hits each; it slams ships that come close and throws wreckage at those that don't). 2: it falls across the Anvil: land, and beat the Ash Admiral among its bones. 3: carry the Heart to the edge of the Maw while the dead rise round the carrier, and throw it in. Every skeleton on the sea crumbles. Title **Heartbreaker**; gift: **the Admiral's raven cloak** (a pirate outfit). | 2,000 / 800 |
| 30 | Quiet Waters | Martha | The party at the Drowned Rat: talk to Isabel, Silas, Quill and Wren. | 500 / 200 |

Simplifications against the story doc: the Colossus fights from the Maw and falls on a rock
rather than being climbed; the Heart is carried on the Anvil, a short way, rather than across the
Reef; Isabel's freed sailors are in the lines, not on a ship; the green-fire ship lantern and the
post-story world (the fort as a second port, the Maw Stirs event) are left for later.

## Rules

- **Act gate**: Act V needs pirate level 18 (the best in the crew).
- **Ashen dead**: Spanish dead, 80 health, burst into green flame when felled (no harm).
- **Doctor Ocaso**: 300 health. Every 6 s he vanishes in green fire and appears by another
  burning brazier (or by a doused one when all are out), raising two dead there (no more than six
  standing). While any brazier burns, nothing hurts him. Each brazier takes one bucket.
- **Beacons**: E at an unlit beacon lights it (no bucket needed; you carry a torch).
- **Saltshot crates and Wren's lantern**: carried in both hands, handed over with E at the
  battery and at the Reef's edge (a spot on the West Stack's beach).
- **The Ash Admiral's flagship** (28): sinks like any galleon, with 1.5 times the hull.
- **The Colossus**: stands in the Maw, turning to face the nearest crew ship. Joints: a
  cannonball landing within 5 m of a glowing joint counts a hit; eight break it. Every 7 s it
  attacks the nearest crew ship within 120 m: within 35 m a fist slam (a hole, and a hurt for
  anyone on deck near the side); further out it throws wreckage (a cannonball). With all four
  joints broken it falls across the Anvil.
- **The Ash Admiral** (29): as the Raven Admiral, but 500 health and a lunge every 3.5 s. When he
  falls, the Heart drops where he stood.
- **The Heart**: carrying it costs 4 health a second; you cannot fight or climb while you do.
  Every 5 s while it is carried two dead rise near the carrier (no more than eight standing).
  E at the Maw's edge throws it in. Every skeleton on the server falls at once; everyone within
  300 m of the Reef shares 500 XP and 300 gold.

## New things to see

The workshop; braziers (lit and doused); beacons (unlit and burning); the Maw; the Anvil; the ashen
dead (charred bones, green fire in the ribs); Doctor Ocaso as a boss (his vial flaring when he
jumps); the Ash Admiral (charred, green fire crown); the Ash Admiral's flagship (charred hull,
green-fire stripes); the Bone Colossus (the skeleton model, twenty times life size, with four
glowing joints); the Heart of Ash; the raven cloak outfit.

## Done when

1. Unit tests for every step: the dive, the ashen dead and Ocaso's braziers and jumps, the three
   jobs and beacons, the fleet and flagship, the Colossus's joints, slams and fall, the Ash
   Admiral, the Heart's carry, the crumbling and the shared reward, and the epilogue's talks.
2. A smoke test: a bot douses a brazier; a bot lights a beacon; a bot's crew breaks a Colossus
   joint with cannon.
3. All earlier tests and smoke tests pass.

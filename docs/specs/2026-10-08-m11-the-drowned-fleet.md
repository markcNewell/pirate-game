# Milestone 11: The Drowned Fleet (Act IV)

Status: built 09-10-2026 (the fifth build step of the story, docs/specs/2026-10-08-story.md):
the places, the six chapters, their art, three bots and `tests/smoke/act4_test.sh`.
Every choice below is Claude's default; change anything and the code follows. Where the story doc
asked for more than one night's work, this says what is built instead.

## In one paragraph

Act IV, from pirate level 14: the crews take the fight to the Admiral. They slip aboard a prison
hulk in the fog off Isla Ceniza and free Isabel; follow a dead pilot's riddle across the
skull-shaped Isla Calavera to the only safe channel into the Black Reef; sink a ghost galleon that
rises in the storm; smash Ocaso's three green lanterns on the Reef's sea stacks; play the bait
and lead the *Cuervo Negro* into Isabel's ambush; and finally, with every crew called, fight the
drowned fleet in the Reef's storm, cripple the flagship, board her and beat the Raven Admiral on
his own quarterdeck.

## Glossary

| Word | Meaning here |
|---|---|
| The Black Reef | A ring of rocks and wrecks far to the south-east, under a storm that never leaves. Its heart tears the hull of any ship that doesn't know the channel. |
| The pilot's chart | Shows the safe channel. Once anyone in your crew has it (chapter 20), the Reef's rocks leave your ship alone. |
| Prison hulk | An old Spanish galleon with bare masts (no yards or sails), anchored in the fog, used as a jail. A rope hangs down her stern. |
| Lantern guard | A Spanish dead sentry with a lantern. If one sees you, he rings the alarm and two skeleton ships come. |
| Ghost galleon | A drowned galleon that rises out of the sea in a storm, streaming water, and hunts whoever is near. Sunk, it goes back down. |
| Lantern of the Deep | A great green lantern on a sea stack, lighting the drowned fleet's way up. Smash it (cutlass or pistol). |
| La Golondrina | Isabel's ship: a captured Spanish sloop in Merrow's colours. She fights on your side. |
| The Raven Admiral | Alonso de Cuervo himself, a duellist: he parries blades from the front and lunges. |

## New places

| Place | Where | Look |
|---|---|---|
| Isla Calavera | South-west of Gull Isle | A rock island shaped like a skull: a great domed brow, two dark eye caves, a nose hole, and a row of tooth-stones along the beach. |
| Isla Ceniza | Far south, beyond the fort | Grey ash beaches, dead grey trees and a smoking hill; fog lies thick off its western shore (the Doctor's workshop is Act V). |
| The Black Reef | Far south-east | A permanent storm over a ring of black rocks and old wreck masts; three tall sea stacks on its rim. |

## The chapters as built

| # | Chapter | Giver | What you do | XP / gold |
|---|---|---|---|---|
| 19 | The Prison Hulk | Moll | Board the hulk in the fog off Isla Ceniza. Three lantern guards walk her deck: if one sees you (close, in front of him) the alarm bell rings and two skeleton ships come. Fell the jailer at the stern; open Isabel's cell; bring her home to Merrow. | 800 / 250 |
| 20 | The Pilot's Chart | Isabel | Isabel sings the pilot's riddle. On Isla Calavera read the carving in the left eye cave, then the one on the third tooth-stone; dig the pilot's grave where it points. The pilot and two of his drowned crew climb out. Bring the chart to Isabel. | 800 / 200 |
| 21 | Ghost Lights | Wren | Find the storm. Inside it a ghost galleon rises beside you. Sink it. | 800 / 250 |
| 22 | Lanterns of the Deep | Wren | Three great green lanterns on the Reef's sea stacks, three Spanish dead guarding each. Land and smash all three within 12 minutes. | 900 / 300 |
| 23 | The Merchant's Gambit | Quill | Sail close to the Reef as the "treasure ship". The *Cuervo Negro* comes out after you: lead her to Isabel's ambush off the fort without being sunk. *La Golondrina* joins the fight; hole the flagship ten times and she runs for the Reef. | 1,000 / 350 |
| 24 | The Battle of the Black Reef | Isabel | Call to arms, in the Reef's storm. Three ghost galleons rise: sink them. Hole the *Cuervo Negro* until she lies dead in the water. Board her: the Raven Admiral and four marines on the quarterdeck. Beat him; he goes over the side as she sinks, and a rowing boat slips away into the smoke. Title **Raven-Breaker**. | 1,500 / 500 |

Simplifications against the story doc: the riddle is three steps on one island rather than a
whole-island riddle map; the hulk has no below-decks (Isabel's cage is on her deck) and keeps
bare masts rather than stumps; *La Golondrina*
is a plain AI ship that fights enemies near her, not a ship anyone sails; the Admiral's raven
figurehead is the title only for now.

## Rules

- **Act gate**: Act IV needs pirate level 14 (the best in the crew).
- **Fog**: within 120 m of the hulk the view closes to about 60 m, grey-green.
- **Lantern guards**: they walk a loop of the hulk's forward deck, round Isabel's cage. Each
  sees a pirate on the deck within 9 m and within 50 degrees of where he faces. The alarm rings
  once per attempt (also when a guard is struck); two skeleton ships come from 250 m off.
- **The stern rope**: E at the foot of the rope hanging from the hulk's stern climbs up onto her
  quarterdeck, out of the guards' sight; the side ladders come up among them.
- **The jailer**: a Spanish officer (160 health) on the hulk's quarterdeck; felling him opens the
  step to the cage. E at the cage door frees Isabel onto your ship (as in Act II); then ferry her
  home.
- **Isla Calavera's riddle**: two carvings to read (E), then a grave to dig (hold E with the
  spade, as for treasure). Digging it raises the pilot (a captain) and two dead. The chart is a
  small case carried in your hands; E at Isabel hands it over.
- **The Reef's rocks**: a ship within 100 m of the Reef's centre takes a hole every 8 s, unless
  someone in her crew has finished chapter 20. Enemy ships know the way.
- **Ghost galleon**: rises over 8 s, water pouring off, beside the first crew ship of the
  chapter's crew found more than half way into the storm; it fights like a skeleton galleon,
  with 1.5 times the hull. Saltshot works on it.
- **Lanterns of the Deep**: 3 hits with any weapon each. The 12 minutes start when the chapter
  does; if time runs out the lanterns relight and the step starts again.
- **The gambit**: the flagship appears 200 m from your ship when you come within 400 m of the
  Reef, and hunts you (her guns reload slowly while she chases). Reach the ambush point (within
  60 m) with her still following: *La Golondrina* comes out and fights her. Ten holes on the
  flagship (from anyone) and she flees into the Reef.
- **The battle**: three ghost galleons rise round the Reef's heart, one after another; then the
  flagship, which cannot sink until she has taken 14 holes, when she stops dead. Her deck has the
  Admiral (400 health) and four marines. Everyone within 300 m of the Reef when the Admiral falls
  gets 400 XP and 200 gold, whichever crew they sail with.
- **The Raven Admiral**: a blade struck from within 60 degrees of his front is parried (a ring
  of steel and nothing more); from the side or behind it lands; pistol shots always land. Every
  5 s he lunges at the nearest pirate within 6 m: half a second of warning (he draws back), then a
  3.5 m dash that hurts 40 if it reaches.

## New things to see

Isla Calavera's skull rock and tooth-stones; carvings in the rock; the pilot's grave; Isla
Ceniza (grey sand, dead trees, a smoking hill); the Reef's rocks and wreck masts; the sea stacks
with their great green lanterns; the prison hulk (masts cut to stumps); the lantern guards; the
ghost galleon (green-black hull, rags of sails, the sea boiling as she rises); *La Golondrina*
(white and blue); the Raven Admiral (black feathered cloak, plumed helmet, rapier); the chart case.

## Done when

1. Unit tests for every step: the guards and the alarm, the jailer and the cell, the riddle and
   the grave, the Reef's rocks with and without the chart, the ghost galleon rising and sinking,
   the lanterns and their clock, the gambit's chase and ambush, the battle's three phases, the
   Admiral's parry and lunge, and the shared reward.
2. A smoke test: a bot sneaks up and fells the jailer; a bot smashes a lantern; a bot fights the
   Admiral from behind.
3. All earlier tests and smoke tests pass.

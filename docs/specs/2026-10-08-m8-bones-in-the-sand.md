# Milestone 8: Bones in the Sand (Act I)

Status: written and built 08-10-2026, the second build step of the story
(docs/specs/2026-10-08-story.md). Every choice below is Claude's default; change anything and the
code follows.

## In one paragraph

Act I of the Ash Fleet: six chapters in which the crews find out who is raising the dead. Race
Spanish diggers for three hoards on Cutlass Cay; salt the graves of Gull Isle's old pirate
graveyard while the dead keep climbing out; follow Jonah's riddle to a Spanish powder store and
blow it up; sink the first raven-sailed Spanish galleon and fish out the Admiral's letter; lay
three captains to rest in one night; and storm the Sergeant's dig camp on Cutlass Cay's hill,
where a green bonfire raises the dead until it is out and Sargento Calavera hides behind a
tower shield.

## Glossary

| Word | Meaning here |
|---|---|
| Digger | A Spanish skeleton with a spade. It digs at an X and carries the chest to its boat. |
| Graveyard | A row of open graves on Gull Isle. Dead climb from any grave that is not salted. |
| Salting | Hold E at an open grave while carrying a crate of salt: the crate is used up, the grave sealed. |
| Riddle | Directions in a note ("where the two rocks kiss..."): no X on the map, you find the place. |
| Powder keg | A Spanish keg of gunpowder. Shoot it or strike it and it blows up after a moment, hurting everyone near and setting off kegs beside it. |
| Spanish galleon | A skeleton ship with black sails and the Admiral's gold raven: tougher, more guns. |
| Bonfire | A camp's great green fire: it raises a few dead every so often until doused (three buckets). |
| Shield | Calavera's tower shield turns any blow from in front. Strike from the side or behind, or shoot him: a pistol shot staggers him and lowers it for a few seconds. |

## The chapters as built

| # | Chapter | Giver | Steps | XP / gold |
|---|---|---|---|---|
| 1 | Dig Faster | Silas | Three chests buried on Cutlass Cay with a Spanish digger heading for each; dig them first or catch the diggers; sell what you save to Silas (done once all three are dealt with and at least one sold). | 400 / chests |
| 2 | Salt the Earth | Quill | Three salt crates wait on the pier; Gull Isle's graveyard has three open graves; a dead climbs out of an open grave every 15 s (at most 4 up); salt every grave, then fell the dead still standing. | 400 / 150 |
| 3 | Captain Coco's Warning | Jonah (visiting Port Merrow) | Read Jonah's directions; find the powder store on Cutlass Cay (no mark on the map, only the island); blow it up; read the orders in the wreckage. | 450 / 100 |
| 4 | The Raven Sails | Silas | A Spanish galleon sails out to meet you; sink it; swim to the bottle bobbing in its wreckage and read the Admiral's letter. | 500 / 200 |
| 5 | Wren's Vigil | Wren | At dusk only: three captains on three islands; bring all three skulls to Wren before dawn, or the vigil fails and starts again next dusk. | 500 / skulls |
| 6 | The Sergeant's Camp | Wren | The dig camp on Cutlass Cay's hill: douse the bonfire (three buckets) while dead rise; then fell Sargento Calavera; read his orders. Title **Gravewarden**. | 1,000 / 300 |

## Rules

- **Diggers** walk to their X, dig for 12 s, then carry the chest to their boat (as thieves do).
  Fell a digger and it drops what it holds. A chest that reaches the boat is lost.
- **Graveyard**: dead rise only from open graves, only while a crew member is within 60 m.
- **Powder kegs**: 40 damage within 4 m when they go off, to players and skeletons alike (half at
  the edge), 1.5 s after being hit; a keg sets off any keg within 3 m.
- **Spanish galleon**: tougher than a skeleton ship (it bails twice as fast and reloads 30%
  quicker), five Spanish dead aboard. It appears 300 m from the crew's ship. Sinking one is
  worth 250 XP to the crew.
- **Night**: dusk is when the sun sets (time of day 0.78) and dawn when it rises (0.24).
- **The bonfire** raises two dead every 20 s while lit (at most 6 up). Each bucket shrinks it; the
  third puts it out.
- **Calavera**: 300 health, 35 damage a swing, 2 s between swings. Blows within 70 degrees of his
  front do nothing while his shield is up; a pistol hit from any side drops it for 3 s.
- **Act I board flavour**: once a crew has finished the prologue, a treasure offer now and then
  (one in three) has Spanish diggers landing for the same chests; the board says so.
- **Tales** (side stories, each opening after a story chapter): *Captain Coco* (Jonah, after P1):
  T1 Coconut Thieves, catch the smug crab that runs off with Jonah's coconut (it flees anyone
  within 9 m; strike it and it lets go); T2 A Raft for Jonah, a bundle of planks from the beach of
  each of three islands. *Quill's Ledger* (Quill, after chapter 2): T3 The Missing Tea, fish three
  floating tea crates out of the sea; T4 Señor Hueso, carry the rattling crate with a polite
  skeleton cook in it to Gull Isle's beach; T5 The Governor's Ball, two porcelain-packed crates
  from Hueso's kitchen to Quill in six minutes; put one down anywhere but your deck and it breaks
  (and the clock starts again). Title **Purveyor of Fine Goods**.

## New things to see

Jonah at Port Merrow; a Spanish digger (spade, the dig animation); salt crates (white sacks);
Gull Isle's graveyard (six graves, three of them open, a broken fence); the powder store (tarp,
kegs with a red band); kegs exploding (flash, smoke, splinters); the Spanish galleon (black
sails, gold raven, red hull band); a bottle bobbing in the sea; the dig camp (palisade, tents,
the bonfire); Sargento Calavera (big, tower shield with the raven, halberd, plumed morion).

## Done when

1. Unit tests: each chapter's steps (diggers digging and stealing, salting and rising, keg chain
   reactions and damage, the galleon sinking into a bottle, the vigil's dawn, bonfire waves and
   the shield).
2. Smoke tests: a bot salts a grave; a bot shoots a powder keg; a bot fells a digger; a bot
   douses the bonfire.
3. All earlier tests and smoke tests pass.

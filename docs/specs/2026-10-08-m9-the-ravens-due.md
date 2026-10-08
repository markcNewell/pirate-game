# Milestone 9: The Raven's Due (Act II)

Status: written 08-10-2026, the third build step of the story (docs/specs/2026-10-08-story.md).
Every choice below is Claude's default; change anything and the code follows. Where the story doc
asked for something bigger than one night's work, this says what was built instead.

## In one paragraph

Act II of the Ash Fleet, from pirate level 5: the crews learn who is behind it. They pull a
Spanish deserter, Lieutenant Isabel Montero, out of a drifting boat and bring her to Port Merrow
under fire; dive to her old ship's wreck for its logbook; raid a Spanish gold convoy; shoot down
the bells that call the dead; unmask the spy selling Quill's salt to the Spanish; and storm
Fuerte del Cuervo, the Admiral's fort, past its guns and its bomb-throwing gunner El Polvorín, to
free the prisoners in its cells and empty its vault.

## Glossary

| Word | Meaning here |
|---|---|
| Isabel | Teniente Isabel Montero, a Spanish marine officer who deserts. She rides on your deck in chapter 7. |
| Passenger | Someone standing on your deck who must reach Port Merrow alive; if your ship sinks, they are lost. |
| Diving | Over a wreck in the sea, hold E to dive and search; a breath bar runs down, let go to come up. |
| Convoy | A Spanish treasure galleon (it runs away) with two escorts (they fight). |
| Bell | A green bronze bell hung high on a rock or tree: every so often it rings and the dead rise round it. Shoot it down. |
| Clue | Someone to ask, or a crate to search: the whodunit's steps. |
| Gideon | Fat Gideon, the smuggler: a living pirate who runs when caught and gives up when beaten. |
| The fort | Fuerte del Cuervo, a new rocky island with stone walls, two gun towers, a gate, cells and a vault. |
| Shore gun | A cannon on a fort tower: it fires at any crew's ship within range. Blow it up with a keg or knock it out with cannon fire. |
| El Polvorín | The fort's gunner: a big raised Spanish gunner who throws lit bombs (short fuse, big bang). |

## The chapters as built

| # | Chapter | Giver | What you do | XP / gold |
|---|---|---|---|---|
| 7 | A Deserter at Dawn | Moll | A rowing boat drifts off Cutlass Cay with a skeleton ship closing on it; get alongside, E to take Isabel aboard, bring her within 60 m of Port Merrow. Sink with her aboard and she is lost (the step starts again). | 500 / 200 |
| 8 | The Admiral's Story | Isabel | She tells the story (a long talk); then dive at the San Telmo's wreck off Gull Isle's arch for the captain's logbook (hold E over the wreck for 4 s; breath for 20 s). | 500 / 150 |
| 9 | Starve the Fire | Silas | A convoy: a treasure galleon with three chests on deck that sails away from you, and two escorts. Board the galleon (or sink it and fish the chests from the sea) and sell what you take to Silas. | 600 / chests |
| 10 | The Drowned Bells | Wren | Three bells on Parrot Rock, Gull Isle and Cutlass Cay; each rings every 20 s while near and raises two dead. Shoot all three down. | 550 / 150 |
| 11 | Spies in Merrow | Quill | Ask Jonah, Moll and Silas what they saw; search three crates on the pier (one hides a raven coin); catch Gideon at his cove on Gull Isle (he runs; his Spanish dead fight). | 550 / 200 |
| 12 | Fuerte del Cuervo | Isabel | Sail to the fort under its two guns; blow the gate with a keg; fight through the courtyard; beat El Polvorín on the walls; free the prisoners (E at the cell door); open the vault (four chests). Title **Fort-Breaker**. | 1,000 / chests |

Simplifications against the story doc: the "skeleton rowing boats" chasing Isabel are an
ordinary skeleton ship; diving is a held E over the wreck, not free swimming under water;
Martha (not yet modelled) is replaced by Jonah, Moll and Silas as witnesses; the fort is not yet
a repeating world event; the musketeers are Spanish dead with swords.

## Rules

- **Passenger**: Isabel stands on the main deck; she does not fight or take damage, but if the
  ship sinks she is lost. Reaching Port Merrow means the ship's centre within 60 m of the
  island's shore.
- **Diving**: E held while swimming within 4 m of the wreck mark; 4 s of holding finds the book;
  breath runs out in 20 s, after which you surface and must let go to breathe again.
- **Convoy**: the treasure galleon sails at three quarters of a skeleton ship's speed, away from
  the nearest crew; the escorts fight. Its chests sit on its deck (take them like any loot);
  if it sinks they float.
- **Bells** ring every 20 s while a crew member is within 60 m, raising two Spanish dead (at most
  six up); a pistol hit brings a bell down.
- **Gideon** has 80 health and runs from anyone within 10 m; beaten, he gives up and talks.
- **Shore guns** fire every 7 s at the nearest crew ship within 260 m; a keg at the tower's foot
  or two cannonball hits silence one.
- **El Polvorín**: 350 health; every 5 s he lobs a bomb at the nearest pirate within 25 m: it
  lands near them and goes off 2 s later (as a powder keg: 40 damage within 4 m).
- **Cells**: E at the cell door frees the prisoners (they run for the boats; Isabel's crew later).
- **Act gate**: Act II needs pirate level 5 (the best in the crew).

## New things to see

Isabel Montero (red coat, sash, dark braid, a straight sword); a drifting rowing boat; the half-
sunk San Telmo off Gull Isle with bubbles over it; the treasure galleon (Spanish, gilded stern);
green bronze bells on gallows; Fat Gideon; pier crates to search; Fuerte del Cuervo: a rock
island with stone walls, a gate, two round towers with guns, a courtyard, a cell block with a
barred door, a vault; El Polvorín (barrel chest, bandolier of bombs); bombs (round, fizzing).

## Done when

1. Unit tests for each chapter's steps: passenger lost and delivered, diving and breath, the
   convoy fleeing and its chests, bells ringing and falling, clues and Gideon, the fort's guns,
   gate, gunner, cells and vault.
2. A smoke test: a bot shoots a bell; a bot dives at the wreck; a bot blows the fort's gate.
3. All earlier tests and smoke tests pass.

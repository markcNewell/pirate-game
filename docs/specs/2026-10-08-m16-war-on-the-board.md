# Milestone 16: The war on the board

Status: built 08-10-2026. The story doc's "The board missions as the story moves on"
(docs/specs/2026-10-08-story.md): the three companies' repeatable missions change with how far
the crew has got, so the war is felt between chapters. Every number below is Claude's default;
change anything and the code follows.

## In one paragraph

The more of the story a crew has seen, the more the war turns up on the mission board. After Act
I, Spanish dead stand guard over some hoards and Spanish officers lead some bounties; after Act
II, famous pirate captains raised as Spanish officers (the pressed dead) walk the islands; after
Act III, skeleton ships raid cargo runs; after Act III's siege, some hoards are wreck gold
floating at the Black Reef's edge and some bounties are ghost galleons you must sink to fish up
their captain's skull. Each twist says so on the board.

## How far the war has got (for a crew)

The furthest any pirate aboard has got: **0** prologue, **1** the prologue done (Spanish diggers,
as built in M8), **2** Act I done, **3** Act II done, **4** Act III done.

## The twists

| From | Company | Twist | Chance | What changes |
|---|---|---|---|---|
| 1 | Gilded Hand | Spanish diggers (as built) | 1 in 3 | Diggers race you for the chests. |
| 2 | Gilded Hand | A Spanish cache | 1 in 3 | Two Spanish dead stand guard at each X. |
| 4 | Gilded Hand | Wreck gold | 1 in 4 | The chests float at the Black Reef's edge instead of being buried. |
| 2 | Lantern Order | A Spanish officer | 2 in 5 | The captain's crew are Spanish dead. |
| 3 | Lantern Order | The pressed dead | 1 in 3 | A famous pirate captain, raised to lead Spanish dead. |
| 4 | Lantern Order | A ghost ship | 1 in 4 | No island: a ghost galleon rises near you; sink her and fish her captain's skull from the sea. |
| 1 | Merrow Traders | Salt | always | Salt joins rum, silk and spice among the goods. |
| 3 | Merrow Traders | Raided | 1 in 3 | A skeleton ship comes for you while you carry the cargo. |

Where two twists fit, the later one is tried first. Pay is as for the plain mission.

## Done when

1. Unit tests: the war's stage from done chapters; each twist's offer and what it puts in the
   world; a ghost bounty's skull floating up and being sold; nothing before its stage.
2. All earlier tests and smoke tests pass.

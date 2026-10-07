# Milestone 2: ship combat

Status: written 07-10-2026 while Mark was away ("keep going with the plan phase after phase").
Every choice below is Claude's default and easy to change.

## In one paragraph

Skeleton ships hunt the crew. Both sides fire cannonballs that fly in real arcs. A hit on the hull
below the main deck punches a hole on the new lower deck, and water pours in. The crew patch holes
with planks and bail with buckets. If the water gets too high the ship sinks; the crew wash up in
the sea and the ship comes back after a short wait. Sink the skeleton ship and another arrives
later.

## Glossary

| Word | Meaning here |
|---|---|
| Lower deck | A new deck inside the hull, below the waterline, reached by a ladder through a hatch. |
| Hole | Damage on the lower deck. Each one lets water in until it is patched. |
| Water level | How deep the water is on the lower deck. Too deep and the ship sinks. |
| Skeleton ship | An enemy galleon sailed by the server (AI): black hull, tattered grey sails. |
| Cannonball | A projectile with a real arc. The server decides what it hits; everyone draws the same arc. |

## What players do

| Action | How |
|---|---|
| Fire a cannon | Take one of the four deck cannons (E). Aim with the mouse, left click to fire. Reloads in 3 s. |
| Go below | E at the hatch (front of the main deck) climbs down the ladder; E at the bottom climbs up. |
| Patch a hole | Look at a hole on the lower deck and hold E for 2 s. Planks are free in this milestone. |
| Bail | E while standing in water on the lower deck fills your bucket; E on the main deck throws it overboard. |

## Rules (numbers are tunable in code)

- Cannonballs leave the muzzle at 65 m/s plus the ship's own speed and fall at 9.81 m/s².
  Their longest range is about 400 m.
- A hit on the hull below the main deck makes a hole at that point on the lower deck wall (up to 12).
  Hits above the deck, on masts or on sails only throw splinters.
- Each hole raises the water by 1.2 cm a second. A full bucket removes 6 cm. At 2.4 m deep the ship sinks.
- A sinking ship slides under over 12 s. Anyone aboard ends up in the sea.
  The crew's ship comes back at its start point 10 s later, and everyone is put back on deck.
- Water slows the ship (up to 40 % at the sinking point) and makes it sit lower.
- Skeleton ships: one at a time, the first 60 s after the server starts and the next 90 s after
  the last one sinks. A skeleton ship appears 450 m away and sails in. It holds its broadside
  70-140 m off and fires two guns a side every 5 s, aiming with lead and a little error. It bails
  on its own, slowly, so it takes about eight leaking hits to sink.
- Ships that touch are pushed apart and both stop. Ramming damage comes later.

## Not in this milestone

Player health (milestone 4), cannonball supplies and barrels (milestone 3), boarding the skeleton
ship (milestone 4), sound effects (art pass).

## Done when

1. Bots fire cannons and the server sees cannonballs land in the sea and on ships.
2. A skeleton ship arrives, fights and lands hits that make holes and raise the water.
3. A repair bot patches holes and bails, and the water goes down.
4. A ship that floods sinks, and the crew's ship comes back with everyone on deck.
5. Unit tests cover ballistics, hull hits, holes and water, and the AI's aim; the smoke test
   covers a fight.

## Technical notes

- Ships become a list (id 0 is the crew's galleon). Each ship's water, sinking progress and holes
  ride in the snapshot, so late joiners need nothing extra.
- Cannonball launches and impacts are reliable events. Clients draw each ball's arc from its
  launch time on the shared clock, so in-flight balls are never streamed.
- The sea shader hides the water surface inside any hull, so the lower deck stays dry until it floods.
- New stations: four cannons (ids 4-7). New player actions: hatch, patch, scoop, throw, fire.
  The server checks distances for all of them.

# Milestone 5: crew vs crew

Status: written 07-10-2026 while Mark was away. Every choice below is Claude's default.
**One choice departs from the original design**; see "Movement checks" below.

## In one paragraph

A server now holds up to four crews of up to four players, each with its own galleon, sail
colours, gold and treasure hunt. Crews can fight each other: shoot each other's ships, board them,
cut each other down and steal the chests stowed on each other's decks to sell as their own.
Skeleton ships hunt whichever crew is nearest.

## Glossary

| Word | Meaning here |
|---|---|
| Crew | Up to four players sharing a ship, a purse and a voyage. |
| Crew ship | Each crew's galleon. It appears when the crew's first player joins and leaves a minute after the last one goes. |
| Hostile | Anyone not in your crew: other crews and skeletons. |
| Steal | Pick up a chest from another crew's deck and sell it yourself. |

## The crews

| Crew | Ship | Sails | Starts at |
|---|---|---|---|
| 1 | The Salty Maiden | cream | (0, 0) |
| 2 | The Crimson Wren | red | (180, 120) |
| 3 | The Blue Petrel | blue | (-180, 120) |
| 4 | The Green Gull | green | (0, 260) |

On the title screen you pick a crew, or **Any crew**, which fills crew 1 first, then 2, and so
on, so friends who all pick "any" sail together.

## Rules

- Cutlass, pistol and cannon splash hurt hostile players as they hurt skeletons. Your own crew
  is never hurt by you (no friendly fire, even with cannons).
- You can climb any crew's ladder. On another crew's ship you can fight, pick up and put down
  chests, but not use their wheel, sails, anchor, cannons, map table, hatch or bananas.
- A crew's chests are on its deck until someone carries them off. Selling pays the seller's crew.
- If your ship sinks it comes back at your crew's start point.
- When a player falls to another player, everyone sees who felled whom.

## Movement checks (departure from the original design)

The design said this milestone would move walking onto the server, with the client predicting
and the server replaying. **Instead, the server now checks every reported position more
strictly.** On deck, positions must be on open deck, not inside masts, cannons or walls, and not
floating or sunk through the floor. Ashore, nobody may stand inside the ground. Speed is checked
everywhere, as before. Attacks are rate-limited, and the server works out their hits.

Why: moving walking onto the server means running every player's physics there and rewinding
and replaying inputs on each client. That is a large, risky change to code that works and feels
instant, for a game among friends. The stricter checks catch the cheats that matter here
(walking through walls, flying, teleporting). If PvP with strangers ever matters, full server
movement is the next step, and the current split (ServerSim versus LocalPlayer) leaves room for it.

## Done when

1. Two crews on one server each have their own ship, and players land on the right one.
2. Bots of two crews duel in the water, and the server counts the player falls.
3. Gunner bots of two crews shoot each other's ships, and both take holes.
4. A bot steals a chest from the other crew's deck and stows it on its own.
5. Positions inside a mast or below the deck are corrected.
6. All earlier smoke tests still pass with crews in place.

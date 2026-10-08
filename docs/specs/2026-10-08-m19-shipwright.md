# Milestone 19: The shipwright

Status: built 08-10-2026, with `tests/smoke/shipwright_test.sh` (bots `wright` and `watcher`).
The story doc's shipwright ("Gold buys, at Port Merrow": sail colours, flags, hull paint,
figureheads, lanterns; looks only) and the ship trophies its chapters promise (the
Sergeant's halberd, the Admiral's raven figurehead). Every name, colour and price below is
Claude's default; change anything and the code follows.

## In one paragraph

Old Hobb the shipwright works at the landward end of Port Merrow's pier. He sells looks for your
ship, never speed or strength: sail colours, hull paint and flag colours, bought with your own
gold and yours for good. Any pirate aboard can have Hobb fit what they own to their crew's ship,
and everyone on the sea sees it. Three things can't be bought, only earned in the story, and they
go up on the ship of any crew with someone aboard who earned them: the Sergeant's halberd, the
Admiral's raven figurehead and Linnet's green lantern.

## Glossary

| Word | Meaning here |
|---|---|
| Ship look | The ship's sails, hull paint and flag. Every ship starts in its crew's colours. |
| Fit | Hobb puts a look you own on your crew's ship. It stays until someone fits another. |
| Trophy | A story reward shown on the ship while anyone aboard has earned it. |

## What Hobb sells

| Kind | Looks (price in gold) |
|---|---|
| Sails | Bone white 500, Crimson 500, Sky 500, Saffron 600, Sea-green 600, Royal purple 800, Black 900 |
| Hull paint | Tar black 800, Navy 800, Oxblood 800, Sea-green 900, Ivory and gold 1,500 |
| Flag | Crimson 300, Navy 300, Bottle green 300, Purple 300, Bone 300 |

"The crew's own" (the colours a crew's ship starts with) is always there, free, for each kind.

## Trophies

| Trophy | Earned by | Where on the ship |
|---|---|---|
| The Sergeant's halberd | Act I's finale (a6, title Gravewarden) | Lashed upright beside the wheel |
| The raven figurehead | Act IV's finale (d6, title Raven-Breaker) | In place of the bow's figurehead |
| Linnet's green lantern | The Other Lantern's end (t11, title Lantern-Bearer) | Hung at the stern, glowing green at night |

## Rules

- **Buying**: at Hobb's counter (E near him), like Martha's: three columns, one per kind. Bought
  once with your own gold, yours for good, saved with your pirate.
- **Fitting**: "Fit" puts the look on your crew's ship now, for everyone to see. Fitting is free
  and needs nobody's leave (the crew can argue about it). Your last fitted look of each kind is
  saved, and a crew's ship takes the saved looks of the first pirate aboard when it is new.
- **Sinking**: a ship that sinks and comes back keeps its looks.
- **Trophies**: shown while at least one pirate in the crew has earned them; nobody can take
  them off.
- **Nothing changes how a ship handles.**

## New things to see

Old Hobb (a broad shipwright in a leather apron and a knitted cap, a mallet at his belt), his
counter. The halberd, the raven figurehead and the green stern lantern on the crew's ship.

## Done when

1. Unit tests: buying, owning and saving; fitting changes the crew's ship for everyone and is
   kept through a sinking; a new ship takes the first pirate's saved looks; trophies from earned
   chapters, and only while their earner is aboard the crew; nothing about handling changes.
2. A smoke test: a bot buys black sails from Hobb and fits them; another bot on the same server
   sees them.
3. All earlier tests and smoke tests pass; screenshots of Hobb and a refitted ship with trophies.

# Milestone 14: The armoury

Status: written 08-10-2026. It answers the story doc's open decision 1 with its default: weapons
are **fair choices**, never upgrades (docs/specs/2026-10-08-story.md, "Decisions for Mark"). Every
number below is Claude's default; change anything and the code follows.

## In one paragraph

Big Martha keeps a rack of arms behind the bar. Besides the cutlass and pistol everyone starts
with, a pirate can buy a rapier or a boarding axe for the blade hand, and a blunderbuss or a long
musket for the gun hand. None is stronger: each blade does about the same damage over time as the
cutlass, and each gun trades range for punch. They only change how a fight feels. You carry one
blade and one gun, chosen at Martha's counter, and everyone sees what you carry.

## The weapons

| Hand | Weapon | Damage | Every | Reach / range | Feel |
|---|---|---|---|---|---|
| Blade | Cutlass (start) | 25 | 0.6 s | 2.4 m, 70° arc | the all-rounder |
| Blade | Rapier | 15 | 0.36 s | 2.9 m, 35° arc | quick and long, but you must aim it |
| Blade | Boarding axe | 45 | 1.05 s | 2.0 m, 100° arc | slow, short, catches everyone in front |
| Gun | Flintlock pistol (start) | 40 | 2.5 s | 60 m, one ball | the all-rounder |
| Gun | Blunderbuss | 6 × 12 | 3.0 s | 18 m, a spray of shot | brutal close, useless far |
| Gun | Long musket | 75 | 4.5 s | 110 m, one ball | slow, for picking off at range |

Damage over time is the same within each hand (blades about 42 a second; the pistol and musket
about 16, the blunderbuss more only if every pellet lands, which happens only up close).

## Rules

- **Buying**: at Martha's counter, a third column, "Arms". Rapier 600, boarding axe 600,
  blunderbuss 800, long musket 900 gold. Bought once, yours for good.
- **Carrying**: one blade and one gun; "Carry" picks which (the starting ones are always yours).
  It is saved with your pirate.
- **Everyone sees it**: the weapon in your hand is the one you carry, for you and for others.
- **The story's rules hold**: anything "a pistol shot" does (dropping the Sergeant's shield,
  knocking Linnet's lantern away, the Admiral's parry not stopping it) any gun does; anything a
  blade does, any blade does.

## New things to see

A rapier (basket hilt, long thin blade), a boarding axe (short haft, broad bearded head), a
blunderbuss (flared brass muzzle), a long musket (long barrel, a sling).

## Done when

1. Unit tests: every weapon's numbers and its fairness (damage over time within a hand); buying,
   carrying and saving; the server using the carried weapon (reach, arc, pellets, range).
2. A smoke test: a bot buys a rapier and fights skeletons with it; a bot with a blunderbuss.
3. All earlier tests and smoke tests pass.

# Art pass 2: Blender models and animation

Status: first pass over every model done 07-10-2026 (see "Progress" at the end); iterating.
Mark asked: "continually iterate to improve every single model that the game currently has.
Don't settle for good enough." Every choice below is Claude's default.

## In one paragraph

Every model in the game is rebuilt in Blender, from Python scripts kept in the repo, and
people get proper skeletons and animation. Blender runs headless (no window) and exports glTF
files that Godot loads. The look stays the same family: flat toon light steps and ink
outlines. Nothing about how the game plays changes: the server never loads a model, and every
walkable or shootable shape still comes from the same numbers in code.

## Glossary

| Word | Meaning here |
|---|---|
| Asset script | A Python file in `art/blender/` that builds one model (or a family) in Blender. |
| Export | The `.glb` file an asset script writes to `art/models/`. Committed, so nobody needs Blender to build the game. |
| Rig | A model's skeleton of bones; animations move the bones, the mesh follows. |
| Contact sheet | One picture of a model from several sides (and poses), rendered by the game itself with its real light and outline. |
| Outline normal | A smoothed direction stored on each vertex, used only to push the ink outline out. |

## How it works

- `tools/build_models.sh [name ...]` runs Blender on each asset script (all by default). The
  shared kit (`art/blender/kit.py`) holds the palette (the same colours as `Toon.PALETTE`),
  shape helpers, colour painting and the export.
- Colours live on the vertices, as now, so one toon material still serves every model. Blender
  also bakes soft shadow into crevices (ambient occlusion) into those colours.
- `Models` (`game/util/models.gd`) loads an export, adds the outline normals, gives every mesh
  the toon material and caches it. Static models carry smoothed outline normals in CUSTOM0 (as
  MeshBuilder meshes do); animated ones push their outline along their real normals, which
  bend with the bones (they are modelled smooth so that stays closed). Each part can ask for a
  finer line or none (`kit.noink`: eyes, buttons, rigging), carried in the first UV channel.
- Ship parts are painted in palette slots (`kit.slot`), which `Models.palette_recolor` swaps for
  a crew's colours or the skeleton ship's; players' shirts and skin use marker colours the same
  way. Darker planks and stains ride in the vertex alpha with the crease shadow, so slots stay
  swappable.
- `tools/model_sheet.sh OUT NAME [options]` renders a contact sheet: the model turning, an
  animation's poses in a row, one pose from each of several animations, or a close-up from a
  camera placed by hand, in a ship palette or a player's colours. That is how each model is
  checked and improved. `tools/readme_shots.sh` retakes every README screenshot.

## Rules

1. Gameplay shapes do not move. The hull follows `ShipShape.half_width`, decks sit at the same
   heights, stations stay where they are, island ground stays the `IslandMesh.ground` formula.
2. Every model is made by a script: rerunning it rebuilds the same model (byte-for-byte equality
   is not promised: Blender orders a few triangles differently run to run).
3. No downloaded models or textures; everything is built here.
4. Big scenery is drawn in batches: island scenery is one MultiMesh per model per island.
5. Animation states come from what snapshots already say (speed, station, swimming,
   carrying, weapon, attacks), plus what a player is busy with (new "act": digging, patching,
   bailing).
6. Keep the frame rate: one material per model; the galleon is the heaviest model at about
   120k triangles.

## Every model, in order of how much you see it

| # | Model | Now | Plan |
|---|---|---|---|
| 1 | Pirate (other players), four looks | capsules and spheres, swinging limbs | rigged character, outfits and hats per look, full animation set |
| 2 | Your own hands and weapons | box fist, flat blade | modelled hands, cutlass, pistol, bucket, hammer, shovel, animated |
| 3 | Skeleton | sticks and spheres | rigged, sharing the pirate's animations |
| 4 | Galleon (hull, decks, hold, rails, stairs, fittings) | planked boxes | planked hull with wales, gunports, stern gallery, figurehead, rudder, bowsprit |
| 5 | Masts, yards, sails, rigging, flag, crow's nest | tubes and flat panels | tapered masts, billowing sails with seams, deadeyes, ratlines |
| 6 | Cannons, wheel, capstan, map table, barrels, crates, rope coils, lamps, ladder, hatch | primitives | detailed props |
| 7 | Skeleton ship | the galleon in other colours | weathered, broken rails, torn sails |
| 8 | Treasure chests (tiers), supply barrels, banana barrel | boxes | detailed, per-tier trim |
| 9 | Palm trees, bushes, flowers, rocks, sea stacks, arch, wreck, skeleton camp | primitives | sculpted shapes, variants |
| 10 | Port Merrow: tavern, lighthouse, hut, pier, merchant | boxes | detailed buildings, merchant rigged |
| 11 | Wildlife: gulls, crabs, dolphins, whale | primitives | modelled and animated |
| 12 | Effects: cannonball, splinters, wreckage, clouds, storm clouds | primitives | modelled |

Island ground, the sea and the sky stay code-built (they are formulas the game plays on), but
get their own look pass once the models are done.

## Done when

1. Every row above is a Blender model, checked on a contact sheet and in game screenshots.
2. `tools/check.sh` and `tools/smoke_all.sh` pass; a unit test loads every export.
3. README screenshots retaken.

## Progress

| # | Model | Done (first pass) |
|---|---|---|
| 1 | Pirate | One rig (18 bones), body plus four looks (tricorn and beard with waistcoat; bandana, eyepatch, earring and sash; captain's bicorne, curly moustache and coat; headscarf, sideburns, ponytail and braces), 17 animations in an AnimationTree, weapons and bucket in hand, head nods with the view. |
| 2 | Your hands | A modelled arm and fist with a finer ink line; cutlass, flintlock; shovel, hammer and bucket shown while digging, patching or carrying water. |
| 3 | Skeleton | Bone by bone on the pirates' rig, all their animations, glowing eyes, rusty cutlass, torn breeches and hat. |
| 4-6 | Galleon | Planked hull with seams and wales, gunports, channels and deadeyes, shrouds with ratlines, tapered masts with tops and crow's nest, bowsprit, mermaid figurehead, anchors, stern gallery, quarter galleries, cabin windows, taffrail, rudder, quarterdeck front with doors and balustrade, stairs, carriages, shot racks, pin rails, binnacle, map table, deck clutter, hold with ribs, beams, knees, hammocks and stores; sails with panels, reef band and bolt ropes that roll up on their yards; wheel, capstan, cannon, flag, emblem, hole, patch. |
| 7 | Skeleton ship | Its own wrecked hull (smashed bulwarks, stove-in holes, barnacles, weed, snapped foremast, bones) and torn sails. |
| 8 | Loot | Three chest finishes, the supply barrel, the banana barrel. |
| 9 | Islands | Palms (three heights), rocks (also building the arch and stacks), bushes, flowers, grass tufts, beach shells, starfish, pebbles and driftwood, the skeleton camp, the beached wreck. |
| 10 | Port Merrow | Tavern (stones, timber frame, tiles, sign), lighthouse (glazed lamp room lit at night), the merchant's stall, the pier, the flag, a rigged merchant. |
| 11 | Wildlife | Gulls, crabs, dolphins, the whale (now swims head first). |
| 12 | Effects and sky | Cannonballs, splinters, wreckage, the camp-fire flame, cumulus clouds and the storm's cloud bank. |

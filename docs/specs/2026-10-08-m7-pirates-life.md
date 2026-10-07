# Milestone 7: a pirate's life

Status: written 08-10-2026, the first build step of the story (docs/specs/2026-10-08-story.md).
Every choice below is Claude's default, including the five open decisions in the story doc;
change anything and the code follows.

## In one paragraph

Pirates become people who last. The server remembers each pirate by name between sessions:
their **pirate level** (from XP, earned by fighting, sinking ships and finishing missions),
their **gold** (now their own: every crew member gets the full price of anything the crew
sells) and their **standing** with the three companies, renamed the **Gilded Hand**, the
**Lantern Order** and the **Merrow Traders**. And the story starts: talk to Moll the
lighthouse keeper at Port Merrow and play the **Prologue**, two chapters where you find a dead
Spanish sailor's journal, douse a green fire that raises the dead, and race Spanish skeletons
for Black-Eyed Bess's skull.

## Glossary

| Word | Meaning here |
|---|---|
| Profile | What the server remembers about a pirate name: XP, gold, standing, titles, chapters done. |
| Token | A random code your game keeps and sends when you join, so nobody else uses your name on that server by accident. |
| Pirate level | 1 to 30, from XP. Shows next to your name. Never makes you stronger. |
| Title | A name earned by level or story ("Bosun", "Gravewarden"). You show one under your name. |
| Standing | Points with a company (the old crew reputation, now per pirate). |
| Chapter | One story mission, made of steps (talk, read, douse, bounty). |
| Green fire | A grave fire from the Heart. Douse it with a bucket of seawater; the dead it was raising climb out. |
| Spanish dead | Skeletons in helmets and breastplates. Some grab loot and run for their boat. |

## What players see and do

| Thing | How |
|---|---|
| Your level and gold | Top right: gold, level and a thin XP bar. Your level and title show over your head to others. |
| Level up | A banner: "Pirate level 5: Powder Monkey". |
| XP | Felling skeletons, knocking down other pirates, sinking ships, finishing missions and chapters (table in the story doc). |
| Gold | Every crew member aboard when the crew sells or delivers something gets the full price. Kept between sessions. |
| The board | Offers are sized by the best standing among the crew online. A fourth line names the next story chapter and who gives it. |
| Story chapters | Walk up to the giver at Port Merrow and press E. They talk (E for the next line); the chapter starts if the crew has no mission running. Its steps show on the mission card and the map. |
| Talking | A panel at the bottom: the speaker's name and a line. E or Space for the next, Esc to skip. |
| Journals | Press E on a book lying on the ground: a parchment page opens. |
| Green fires | Wade into the shallows and press E to fill your bucket, carry it to the fire and press E: it hisses out and the dead climb up around it. |
| Thieves | When a captain falls, Spanish skeletons run for his skull and carry it to their rowing boat. Fell the carrier and the skull drops. If they reach the boat, the skull is gone and the chapter goes back a step. |

## Rules

- **Profiles** live on the server, one JSON file per name in `user://profiles/` (or
  `--profiles DIR`; `--no-save` keeps them in memory for tests). They save when something
  changes (at most every 5 s), when a pirate leaves and when the server stops.
- **Joining** sends the name and the token from your settings (made on first launch). A name the
  server knows with a different token is refused: "That name belongs to another pirate on this
  server." Bots use a fixed token per name.
- **XP and levels** as the story doc: level n to n+1 takes 300 + 100 x n XP, to level 30. Kill XP
  goes to whoever landed the blow; ship, mission and chapter XP to every crew member online.
  Knocking down the same pirate pays XP once per 5 minutes.
- **Titles by level**: 1 Deckhand, 3 Swabbie, 5 Powder Monkey, 8 Able Seaman, 11 Bosun,
  14 Quartermaster, 18 First Mate, 22 Captain, 26 Commodore, 30 Legend of the Isles. Story
  titles add to these. You wear your latest one.
- **Standing** is per pirate and kept between sessions; reaching a company level is announced to
  you. Every crew member online earns the standing for the crew's sales and missions.
- **Chapters**: a crew may start one if anyone online in it has finished the chapter before it
  (or it is the first). Finished chapters can be played again. Everyone online in the crew when
  it ends gets it ticked off, plus its XP and gold. One mission at a time, story or board.
  Giving up a chapter works as for missions.
- **Acts** need a pirate level (Act II 5, III 10, IV 14, V 18), checked against the best level in
  the crew. The prologue and Act I need none.

## The Prologue (as built)

**P1 Strange Lights** (Moll, at the lighthouse): talk; read the journal on Gull Isle's beach;
douse the green fire on the grave nearby (3 Spanish dead climb out); fell them; tell Moll.
300 XP, 150 gold.

**P2 Black-Eyed Bess** (Mother Wren): talk; on Parrot Rock fell Bess (a captain) and her two
Spanish dead, who try to steal her skull for their boat; bring the skull to Wren. 400 XP and
the skull's price.

## New things to see

Moll Tinder (keeper's coat, spyglass) by the lighthouse; the Spanish dead (morion helmet,
breastplate); a Spanish rowing boat drawn up on the beach; green fires on graves (a mound, a
cross of driftwood and a green flame that lights the ground); a journal lying open on the sand;
the talk panel and journal page; level, title and XP bar on the HUD.

## Testing aids

`--chapter ID` starts the crew on that story chapter (talk step done) for bots and screenshots;
`--xp N` starts every new profile with N XP; `--no-save`; `--profiles DIR`.

## Done when

1. Unit tests: levels and titles, profiles (create, token check, save and load), gold to every
   crew member, XP for kills, ships and missions, both prologue chapters step by step, thieves
   reaching their boat.
2. Smoke test `story_test.sh`: a bot plays P1 from Moll to Moll; a bot finishes P2's bounty with
   the thieves trying for the skull; a server restarted with the same profile directory
   remembers a bot's gold and level.
3. All earlier tests and smoke tests pass (with the renamed companies).

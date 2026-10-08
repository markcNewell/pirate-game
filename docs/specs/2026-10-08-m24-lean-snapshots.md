# Milestone 24: Lean snapshots

Status: built 08-10-2026. Before playing over the internet: the server's 30-a-second updates had
grown past what fits in one network packet (1,392 bytes), up to 8 KB in the siege. Over a real
connection that means more lost updates and jerky movement, and about 2 Mbit/s to each player.

## What changed

1. **Packed small** (`Wire`): every number went over as Godot's general-purpose encoding, 8-12
   bytes each. Now a small whole number (0-127, the commonest) is one byte, other whole numbers
   two to five, positions and angles four (the server's clock keeps double precision).
2. **Only what is near you**: each player's update carries the skeletons and loot within 500 m of
   them (or on a ship within 500 m, or being carried). Ships and players always.
3. **The slow parts only when they change**: the crews' missions and the story's objects are sent
   when they change, and again every half second in case a packet went astray; otherwise the
   client keeps the last ones.

## Sizes (bytes per update)

| Scene | Before | After |
|---|---|---|
| One crew of four, quiet | 904 | 173 |
| Eight players in four crews | 2,336 | 406 |
| Act IV's battle at the Black Reef | 2,164 | 458 |
| The siege of Port Merrow (26 of the dead, 5 ships) | 5,520 | 1,175 |

The worst scenes now fit one packet, and a quiet one is a fifth of what it was.

## Not done

- Testing with real lag and packet loss (it needs the operating system's network shaping, which
  needs admin rights on the test machine). Movement already uses a 0.1 s buffer and server
  corrections; play with friends will show whether that is enough.

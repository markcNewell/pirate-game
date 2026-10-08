"""Fuerte del Cuervo, the Admiral's fort (story Act II): the walls, towers, cells, vault and gun
platform as one model, plus its gate (shut and blown) and its doors, which the game shows and
swings. The layout mirrors game/world/fort.gd (keep the two in step).

    blender -b --factory-startup --python art/blender/fort.py [-- fort fort_parts]

Frame (Godot axes): the fort's centre on the plateau at the origin (the game lifts it to
Fort.PLATEAU_Y); the gate faces -X.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

# Mirrors game/world/fort.gd.
FACING = math.pi
WALL_R = 13.0
WALL_H = 5.0
WALL_T = 1.4
GATE_HALF = 2.2
TOWER_SPREAD = 0.9
TOWER_R = 2.6
TOWER_H = 8.0
CELLS = (math.pi + 0.65, 8.0, 5.0, 3.5)
VAULT = (math.pi - 0.65, 8.0, 4.0, 3.0)
BUILDING_H = 4.0
PLATFORM = (3.0, 1.2, 3.0)

STONE = ["a8a296", "9c968a", "b4aea0", "8e887c"]
STONE_DARK = "6e6a62"
WOOD = "6a4a2c"
IRON = "2e2e36"
GOLD = "e0b04a"
RED = "8a1a18"


def at(a, r, y=0.0):
    """Godot point at angle `a` from the gate's direction, `r` from the centre, height y."""
    t = FACING + a
    return (math.cos(t) * r, y, math.sin(t) * r)


def yaw_of(a):
    """The Godot yaw that turns a part's +X to point outward at angle `a`."""
    return -(FACING + a)


def wall():
    """The curtain wall: stone courses round the ring, battered at the foot, merlons on top,
    a gap for the gate."""
    rng = random.Random(3)
    parts = []
    segments = 48
    for k in range(segments):
        a0 = 2 * math.pi * k / segments - math.pi
        a1 = 2 * math.pi * (k + 1) / segments - math.pi
        mid = (a0 + a1) * 0.5
        if abs(mid) * WALL_R < GATE_HALF + 0.3:
            continue
        length = WALL_R * (a1 - a0) + 0.05
        for course in range(5):
            y = course * WALL_H / 5
            h = WALL_H / 5 - 0.03
            grow = 0.18 * (1 - course / 4)
            block = kit.box("course", (0, 0, 0), (WALL_T + grow, h, length), rng.choice(STONE), bevel=0.04)
            kit.place(block, at(mid, WALL_R, y + h / 2), (0, yaw_of(mid), 0))
            parts.append(block)
        if k % 2 == 0:
            merlon = kit.box("merlon", (0, 0, 0), (WALL_T * 0.55, 0.7, length * 0.8), rng.choice(STONE), bevel=0.04)
            kit.place(merlon, at(mid, WALL_R + WALL_T * 0.2, WALL_H + 0.35), (0, yaw_of(mid), 0))
            parts.append(merlon)
    # The walk behind the parapet.
    walk = kit.lathe("walk", [(WALL_R - WALL_T * 0.5 - 1.0, WALL_H - 0.6), (WALL_R - WALL_T * 0.5, WALL_H - 0.6)], 64, STONE_DARK, caps=False)
    parts.append(walk)
    # The gateway: two pillars and a lintel with the Admiral's raven.
    for side in (-1, 1):
        a = side * (GATE_HALF + 0.35) / WALL_R
        pillar = kit.box("pillar", (0, 0, 0), (WALL_T + 0.5, WALL_H + 0.8, 0.9), STONE_DARK, bevel=0.06)
        kit.place(pillar, at(a, WALL_R, (WALL_H + 0.8) / 2), (0, yaw_of(a), 0))
        parts.append(pillar)
    lintel = kit.box("lintel", (0, 0, 0), (WALL_T + 0.5, 0.9, 2 * GATE_HALF + 1.6), STONE_DARK, bevel=0.06)
    kit.place(lintel, at(0, WALL_R, WALL_H + 0.35), (0, yaw_of(0), 0))
    parts.append(lintel)
    crest = kit.noink(kit.prism("crest", [(-0.6, 0.0), (-0.2, 0.3), (0.2, 0.25), (0.6, 0.45), (0.5, 0.1), (0.7, 0.0), (0.1, -0.1), (-0.3, -0.2)], 0.05, GOLD, plane="zy"), 0.3)
    kit.place(crest, at(0, WALL_R + WALL_T * 0.5 + 0.28, WALL_H + 0.3), (0, yaw_of(0), 0))
    parts.append(crest)
    return parts


def tower(side):
    """A round gun tower, battered at the foot, crenellated, its gun platform on top."""
    rng = random.Random(10 + side)
    a = TOWER_SPREAD * side
    cx, _, cz = at(a, WALL_R)
    parts = []
    body = kit.lathe("tower", [(TOWER_R + 0.35, 0.0), (TOWER_R, 1.6), (TOWER_R, TOWER_H), (TOWER_R + 0.25, TOWER_H + 0.05), (TOWER_R + 0.25, TOWER_H + 0.35), (0.0, TOWER_H + 0.35)], 20, rng.choice(STONE), centre=(cx, 0, cz))
    kit.paint_where(body, STONE_DARK, lambda x, y, z: y < 0.9)
    parts.append(body)
    for k in range(10):
        t = 2 * math.pi * k / 10
        m = kit.box("merlon", (0, 0, 0), (0.5, 0.7, 0.7), rng.choice(STONE), bevel=0.04)
        kit.place(m, (cx + math.cos(t) * TOWER_R, TOWER_H + 0.7, cz + math.sin(t) * TOWER_R), (0, -t, 0))
        parts.append(m)
    for k in range(3):
        y = 2.2 + 1.8 * k
        t = FACING + a
        slit = kit.noink(kit.box("slit", (0, 0, 0), (0.05, 0.6, 0.14), "1a1714"), 0.0)
        kit.place(slit, (cx + math.cos(t) * (TOWER_R + 0.01), y, cz + math.sin(t) * (TOWER_R + 0.01)), (0, -t, 0))
        parts.append(slit)
    if side == 1:
        parts.append(kit.tube("flagpole", [(cx, TOWER_H + 0.3, cz), (cx, TOWER_H + 4.5, cz)], 0.06, 6, "3a2e26"))
        flag = kit.prism("flag", [(0.0, 0.0), (0.0, 1.0), (1.6, 0.9), (1.5, 0.5), (1.6, 0.1)], 0.02, RED, centre=(cx + 0.03, TOWER_H + 3.4, cz), plane="xy")
        parts.append(flag)
        parts.append(kit.noink(kit.prism("flagraven", [(0.3, 0.35), (0.6, 0.6), (0.9, 0.55), (1.1, 0.75), (1.05, 0.42), (1.25, 0.32), (0.8, 0.28)], 0.03, GOLD, centre=(cx + 0.03, TOWER_H + 3.4, cz), plane="xy"), 0.2))
    return parts


def building(row, name, door_dark):
    """A low stone block house inside the walls, flat-roofed, its door toward the courtyard."""
    a, r, sx, sz = row
    rng = random.Random(len(name))
    parts = []
    house = kit.box(name, (0, 0, 0), (sz, BUILDING_H, sx), rng.choice(STONE), bevel=0.06)
    kit.place(house, at(a, r, BUILDING_H / 2), (0, yaw_of(a), 0))
    parts.append(house)
    roof = kit.box(name + "_roof", (0, 0, 0), (sz + 0.4, 0.3, sx + 0.4), STONE_DARK, bevel=0.04)
    kit.place(roof, at(a, r, BUILDING_H + 0.15), (0, yaw_of(a), 0))
    parts.append(roof)
    # The doorway's dark recess on the courtyard side (the door itself is the game's).
    recess = kit.noink(kit.box(name + "_doorway", (0, 0, 0), (0.06, 2.3, 1.5), door_dark), 0.3)
    kit.place(recess, at(a, r - sz / 2 - 0.02, 1.15), (0, yaw_of(a), 0))
    parts.append(recess)
    return parts


def platform():
    """The gunner's raised platform in the middle of the courtyard, with steps up to it."""
    px, py, pz = PLATFORM
    parts = [kit.box("platform", (0, py / 2, 0), (px, py, pz), STONE_DARK, bevel=0.06)]
    for k in range(3):
        parts.append(kit.box("step", (px / 2 + 0.25 + 0.3 * k, py * (1 - (k + 1) / 4) / 2, 0), (0.3, py * (1 - (k + 1) / 4), 1.2), STONE[k % 4], bevel=0.03))
    # A brazier and a stack of bombs ready to hand.
    parts.append(kit.lathe("brazier", [(0.0, py), (0.25, py), (0.35, py + 0.5), (0.3, py + 0.55), (0.0, py + 0.4)], 10, IRON, centre=(-0.9, 0, -0.9)))
    for k in range(4):
        parts.append(kit.ellipsoid("bomb", (0.8 + 0.25 * (k % 2), py + 0.15 + 0.22 * (k // 2), 0.8), (0.14, 0.14, 0.14), "1e1e24", rings=6, sectors=8))
    return parts


def courtyard():
    """Flagstones over the courtyard inside the wall."""
    rng = random.Random(7)
    parts = [kit.noink(kit.lathe("flags", [(0.0, 0.02), (WALL_R - WALL_T * 0.5, 0.02)], 40, "8e887c", caps=False), 0.0)]
    for k in range(40):
        t = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(1.5, WALL_R - 2.0)
        parts.append(kit.noink(kit.box("flagstone", (math.cos(t) * r, 0.03, math.sin(t) * r), (0.9, 0.02, 0.7), rng.choice(STONE), rot=(0, rng.uniform(0, 3), 0)), 0.0))
    return parts


def fort():
    parts = courtyard() + wall() + tower(-1) + tower(1) + building(CELLS, "cells", "141210") + building(VAULT, "vault", "141210") + platform()
    return kit.join("fort", parts)


def gate(broken=False):
    """The fort's gate (its centre at the origin, the gate's face toward -X): two leaves of heavy
    planks bound with iron, or what is left after a powder keg."""
    rng = random.Random(4)
    parts = []
    width = 2 * GATE_HALF
    height = WALL_H - 0.6
    for k in range(9):
        z = -width / 2 + width * (k + 0.5) / 9
        h = height if not broken else rng.uniform(0.3, 1.6)
        lean = 0.0 if not broken else rng.uniform(-0.5, 0.5)
        plank = kit.box("plank", (0, 0, 0), (0.18, h, width / 9 - 0.02), ("6a4a2c", "5a3e24", "7a5a38")[k % 3], bevel=0.02)
        kit.place(plank, (0, h / 2, z), (0, 0, lean))
        parts.append(plank)
    if not broken:
        for y in (0.7, 2.2, 3.7):
            parts.append(kit.box("band", (-0.1, y, 0), (0.05, 0.18, width), IRON))
        for side in (-1, 1):
            parts.append(kit.lathe("ring", [(0.12, -0.02), (0.12, 0.02)], 10, IRON, caps=False, centre=(-0.15, 1.6, side * 0.4), axis="x"))
    else:
        for k in range(6):
            p = kit.box("debris", (0, 0, 0), (0.15, 0.08, rng.uniform(0.4, 1.0)), "5a3e24", bevel=0.01)
            kit.place(p, (rng.uniform(-1.5, 0.5), 0.04, rng.uniform(-1.6, 1.6)), (0, rng.uniform(0, 3), 0))
            parts.append(p)
    return kit.join("gate_broken" if broken else "gate", parts)


def door(name, color, bars):
    """A door 1.4 x 2.2 (hinged at its -Z edge, which the game swings it about; face toward -X):
    iron bars for the cells, studded iron for the vault."""
    if bars:
        parts = [kit.box(name + "_frame", (0, 1.1, 0.7), (0.1, 2.2, 1.4), IRON, bevel=0.02)]
        kit.paint_where(parts[0], "1a1714", lambda x, y, z: 0.2 < y < 2.0 and 0.15 < z < 1.25)
        for k in range(5):
            parts.append(kit.tube("bar", [(-0.07, 0.2, 0.25 + 0.22 * k), (-0.07, 2.0, 0.25 + 0.22 * k)], 0.03, 5, "4a4a52"))
    else:
        parts = [kit.box(name + "_slab", (0, 1.1, 0.7), (0.1, 2.2, 1.4), color, bevel=0.02)]
        for y in range(4):
            for z in range(3):
                parts.append(kit.noink(kit.ellipsoid("stud", (-0.06, 0.35 + 0.5 * y, 0.3 + 0.4 * z), (0.03, 0.04, 0.04), "6a6e76", rings=3, sectors=6), 0.3))
        parts.append(kit.lathe("handle", [(0.1, -0.02), (0.1, 0.02)], 10, GOLD, caps=False, centre=(-0.1, 1.1, 1.1), axis="x"))
    return kit.join(name, parts)


def bell_gallows():
    """A drowned bell on a gallows (the bell's mouth at y = 3.2): two driftwood posts, a cross
    beam, and a green bronze bell crusted with weed."""
    parts = []
    for side in (-1, 1):
        parts.append(kit.tube("post", [(side * 1.0, -0.2, 0), (side * 0.95, 4.3, 0.02)], [0.09, 0.07], 6, "8a7a62", twist=0.3))
    parts.append(kit.tube("beam", [(-1.15, 4.2, 0), (1.15, 4.25, 0)], 0.08, 6, "7a6a54"))
    parts.append(kit.tube("rope", [(0, 4.2, 0), (0, 3.95, 0)], 0.025, 4, "c8b080"))
    bell = kit.lathe("bell", [(0.0, 3.95), (0.15, 3.93), (0.22, 3.75), (0.26, 3.45), (0.36, 3.22), (0.3, 3.2), (0.0, 3.3)], 16, "4a8a6a")
    kit.paint_where(bell, "2e6a4a", lambda x, y, z: y < 3.35)
    parts.append(bell)
    parts.append(kit.noink(kit.ellipsoid("clapper", (0, 3.25, 0), (0.06, 0.08, 0.06), "2e2e36", rings=4, sectors=6), 0.3))
    for k in range(4):
        t = 2 * math.pi * k / 4
        parts.append(kit.noink(kit.tube("weed", [(math.cos(t) * 0.3, 3.3, math.sin(t) * 0.3), (math.cos(t) * 0.32, 3.0, math.sin(t) * 0.32)], 0.02, 4, "3a6a3a"), 0.2))
    return kit.join("bell_gallows", parts)


def bomb():
    """El Polvorín's bomb: a black iron ball with a fizzing fuse."""
    ball = kit.ellipsoid("ball", (0, 0.16, 0), (0.16, 0.16, 0.16), "1e1e24", rings=8, sectors=12)
    neck = kit.lathe("neck", [(0.05, 0.3), (0.05, 0.36)], 8, "3a3a42", caps=False)
    fuse = kit.tube("fuse", [(0, 0.36, 0), (0.04, 0.45, 0.02), (0.02, 0.52, 0.06)], 0.012, 4, "c8b080")
    return kit.join("bomb", [ball, neck, fuse])


def main(names):
    builders = {
        "fort": lambda: [fort()],
        "fort_parts": lambda: [gate(), gate(True), door("cell_door", IRON, True), door("vault_door", "4a4a52", False), bell_gallows(), bomb()],
    }
    for name in names or builders:
        kit.reset()
        kit.export(name, builders[name]())


if __name__ == "__main__":
    main(kit.args())

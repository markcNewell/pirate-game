"""Port Merrow: the tavern, the lighthouse, the merchant's stall, the pier and its flag. Each is
built in its own frame; game/world/outpost.gd places them (and keeps the collision boxes).

    blender -b --factory-startup --python art/blender/outpost.py [-- tavern lighthouse ...]

Frames (Godot axes): the tavern and the stall face +X (their fronts toward the sea), origin on
the ground at their middle; the lighthouse stands on its foot with its door toward -Z; the
pier runs from its root at the origin out along +X, its deck at y = 0 (the game lifts it to
the pier's height).
"""

import math
import os
import random
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
import props  # noqa: E402

STONE = ["a59c8e", "9a9184", "b0a898", "8f877c"]
PLASTER = "efe6d2"
BEAM = "5a3a24"
TILE = ["9c3a2a", "8a3226", "a84432"]
GLASS = "3a4250"
WOOD = "e0a868"
WOOD_DARK = "8a5a32"
IRON = "2e2e36"
GOLD = "ffd23a"


def stones_wall(name, x0, x1, y0, y1, z, axis, thick, holes=(), seed=0):
    """A wall of stones laid in courses, running along `axis` ("x" or "z") from x0 to x1 at
    the other coordinate z, from y0 to y1; `holes` are (a0, a1, b0, b1) openings."""
    rng = random.Random(seed)
    parts = []
    course = 0.38
    y = y0
    row = 0
    while y < y1 - 0.01:
        h = min(course, y1 - y)
        a = x0 - (0.3 if row % 2 else 0.0)
        while a < x1 - 0.01:
            length = rng.uniform(0.55, 0.85)
            b = min(a + length, x1)
            a_ = max(a, x0)
            mid_a, mid_y = (a_ + b) / 2, y + h / 2
            if any(h0 <= mid_a <= h1 and v0 <= mid_y <= v1 for h0, h1, v0, v1 in holes):
                a = b
                continue
            size = (b - a_ - 0.02, h - 0.02, thick + rng.uniform(-0.03, 0.03))
            if axis == "x":
                at, sz = (mid_a, mid_y, z), size
            else:
                at, sz = (z, mid_y, mid_a), (size[2], size[1], size[0])
            stone = kit.box("stone", at, sz, STONE[rng.randrange(len(STONE))], bevel=0.03, segments=1)
            parts.append(stone)
            a = b
        y += h
        row += 1
    return parts


def tiled_roof(half_x, half_z, eave_y, ridge_y, overhang=0.5, seed=0):
    """A pitched roof, ridge along Z, in overlapping rows of tiles, with a ridge cap and
    barge boards on the gables."""
    rng = random.Random(seed)
    parts = []
    run = half_x + overhang
    rise = ridge_y - eave_y
    slope_len = math.hypot(run, rise)
    angle = math.atan2(rise, run)
    rows = int(slope_len / 0.32)
    for side in (1, -1):
        for r in range(rows):
            t = (r + 0.5) / rows
            x = side * run * (1 - t)
            y = eave_y + rise * t
            # Each row a strip of tiles, each a little different.
            z = -half_z - overhang
            while z < half_z + overhang - 0.01:
                w = rng.uniform(0.32, 0.4)
                w = min(w, half_z + overhang - z)
                c = TILE[rng.randrange(len(TILE))]
                tile = kit.box("tile", (x, y, z + w / 2), (slope_len / rows * 1.25, 0.06, w - 0.025), c, bevel=0.012, segments=1, rot=(0, 0, -side * angle))
                parts.append(tile)
                z += w
    parts.append(kit.box("ridge", (0, ridge_y + 0.06, 0), (0.32, 0.18, 2 * (half_z + overhang) + 0.1), TILE[1], bevel=0.05))
    for gz in (half_z + overhang, -half_z - overhang):
        for side in (1, -1):
            mid = Vector((side * run / 2, eave_y + rise / 2 - 0.06, gz))
            parts.append(kit.box("barge", tuple(mid), (slope_len + 0.15, 0.22, 0.08), BEAM, bevel=0.02, rot=(0, 0, -side * angle)))
    return parts


def window(at, facing, w, h, shutters=True):
    """A window in a wall facing +X or -X (facing = (±1, 0)): frame, dark glass, mullions and
    open shutters."""
    parts = []
    fx, fz = facing
    x, y, z = at
    if fx:
        parts.append(kit.box("frame", (x, y, z), (0.12, h + 0.16, w + 0.16), BEAM, bevel=0.02))
        parts.append(kit.box("pane", (x + fx * 0.03, y, z), (0.06, h, w), GLASS))
        parts.append(kit.box("mullion", (x + fx * 0.07, y, z), (0.04, h, 0.05), BEAM))
        parts.append(kit.box("transom", (x + fx * 0.07, y, z), (0.04, 0.05, w), BEAM))
        if shutters:
            for s in (1, -1):
                sh = kit.box("shutter", (x + fx * 0.08, y, z + s * (w / 2 + 0.28)), (0.05, h + 0.1, 0.5), "2f6a4f", bevel=0.01)
                parts.append(sh)
                for k in range(3):
                    parts.append(kit.box("slat", (x + fx * 0.11, y - h / 2 + 0.15 + k * (h - 0.2) / 2, z + s * (w / 2 + 0.28)), (0.02, 0.05, 0.46), "26574a"))
    return parts


def side_window(at, facing_z, w, h):
    """A window in a wall facing +Z or -Z: frame, glass, cross bars."""
    x, y, z = at
    f = facing_z
    return [
        kit.box("frame", (x, y, z), (w + 0.16, h + 0.16, 0.12), BEAM, bevel=0.02),
        kit.box("pane", (x, y, z + f * 0.03), (w, h, 0.06), GLASS),
        kit.box("mullion", (x, y, z + f * 0.07), (0.05, h, 0.04), BEAM),
        kit.box("transom", (x, y, z + f * 0.07), (w, 0.05, 0.04), BEAM),
    ]


def tavern():
    """The Salty Dog: a stone ground floor, a jettied timber-framed upper floor, a tiled roof
    with a chimney, a planked door under a stone arch, shuttered windows, a hanging sign
    with a tankard, a lantern, barrels and a bench by the door."""
    parts = []
    hx, hz = 3.0, 3.6
    # Foundation plinth.
    parts.append(kit.box("plinth", (0, 0.12, 0), (2 * hx + 0.3, 0.3, 2 * hz + 0.3), STONE[3], bevel=0.04))
    door = (-0.6, 0.6, 0.2, 2.25)
    lower_win = [(z - 0.6, z + 0.6, 0.95, 2.05) for z in (-2.2, 2.2)]
    parts += stones_wall("front", -hz, hz, 0.25, 2.8, hx, "z", 0.3, holes=[door] + lower_win, seed=1)
    parts += stones_wall("back", -hz, hz, 0.25, 2.8, -hx, "z", 0.3, holes=[(-0.8, 0.8, 0.9, 2.0)], seed=2)
    parts += stones_wall("left", -hx, hx, 0.25, 2.8, -hz, "x", 0.3, holes=[(-0.7, 0.7, 0.9, 2.0)], seed=3)
    parts += stones_wall("right", -hx, hx, 0.25, 2.8, hz, "x", 0.3, seed=4)
    # A core behind the stones so the openings show darkness, not sky.
    parts.append(kit.box("core", (0, 1.5, 0), (2 * hx - 0.3, 2.6, 2 * hz - 0.3), "2a2420"))
    # Floor beam between the storeys.
    parts.append(kit.box("joist", (0, 2.86, 0), (2 * hx + 0.5, 0.14, 2 * hz + 0.5), BEAM, bevel=0.03))
    # Upper floor: plaster, jettied out, framed in dark timbers.
    ux, uz = hx + 0.2, hz + 0.2
    parts.append(kit.box("upper", (0, 4.25, 0), (2 * ux, 2.7, 2 * uz), PLASTER))
    for face_x in (ux, -ux):
        s = 1 if face_x > 0 else -1
        for z in (-uz + 0.06, -1.2, 1.2, uz - 0.06):
            parts.append(kit.box("post", (face_x + s * 0.04, 4.25, z), (0.1, 2.7, 0.16), BEAM))
        parts.append(kit.box("rail", (face_x + s * 0.04, 4.25, 0), (0.08, 0.14, 2 * uz), BEAM))
        for z0, z1 in ((-uz, -1.2), (1.2, uz)):
            a = Vector((face_x + s * 0.04, 2.95, z0 if z0 < 0 else z1))
            b = Vector((face_x + s * 0.04, 4.15, z1 if z0 < 0 else z0))
            parts.append(kit.tube("brace", [tuple(a), tuple(b)], 0.06, 4, BEAM))
    for face_z in (uz, -uz):
        s = 1 if face_z > 0 else -1
        for x in (-ux + 0.06, 0.0, ux - 0.06):
            parts.append(kit.box("post", (x, 4.25, face_z + s * 0.04), (0.16, 2.7, 0.1), BEAM))
        parts.append(kit.box("rail", (0, 4.25, face_z + s * 0.04), (2 * ux, 0.14, 0.08), BEAM))
    # Gable ends above the upper floor, plastered with a timber cross.
    for gz in (uz, -uz):
        tri = kit.prism("gable", [(-ux, 5.6), (ux, 5.6), (0.0, 7.75)], 0.12, PLASTER, centre=(0, 0, gz), plane="xy")
        parts.append(tri)
        s = 1 if gz > 0 else -1
        parts.append(kit.box("king", (0, 6.6, gz + s * 0.07), (0.12, 2.0, 0.06), BEAM))
    parts += tiled_roof(ux, uz, 5.55, 7.8, overhang=0.45, seed=5)
    # Chimney through the roof at the back corner.
    cx, cz = -1.6, 2.2
    chim = stones_wall("chim", cz - 0.45, cz + 0.45, 5.0, 8.9, cx - 0.45, "z", 0.2, seed=6) + stones_wall("chim", cz - 0.45, cz + 0.45, 5.0, 8.9, cx + 0.45, "z", 0.2, seed=7)
    chim += stones_wall("chim", cx - 0.45, cx + 0.45, 5.0, 8.9, cz - 0.45, "x", 0.2, seed=8) + stones_wall("chim", cx - 0.45, cx + 0.45, 5.0, 8.9, cz + 0.45, "x", 0.2, seed=9)
    parts += chim
    parts.append(kit.box("chimcap", (cx, 9.0, cz), (1.15, 0.16, 1.15), STONE[3], bevel=0.03))
    for dx in (-0.2, 0.2):
        parts.append(kit.lathe("pot", [(0.12, 0.0), (0.1, 0.3), (0.13, 0.36), (0.0, 0.36)], 8, "b05a3a", centre=(cx + dx, 9.08, cz)))
    # The door under a stone arch, with a step.
    parts.append(kit.box("door", (hx + 0.08, 1.15, 0), (0.08, 1.95, 1.15), WOOD_DARK, bevel=0.015))
    for k in range(-2, 3):
        parts.append(kit.box("doorplank", (hx + 0.13, 1.15, k * 0.22), (0.03, 1.9, 0.02), "6a4428"))
    for y in (0.6, 1.7):
        parts.append(kit.box("hinge", (hx + 0.14, y, -0.2), (0.03, 0.07, 0.75), IRON))
    parts.append(kit.lathe("ring", [(0.06, -0.012), (0.075, 0.0), (0.06, 0.012)], 10, GOLD, caps=False, centre=(hx + 0.16, 1.15, 0.38), axis="x"))
    for k in range(9):
        a = math.pi * k / 8
        parts.append(kit.box("arch", (hx + 0.05, 2.15 + 0.32 * math.sin(a), 0.72 * math.cos(a)), (0.34, 0.24, 0.26), STONE[k % 4], bevel=0.03, rot=(-(a - math.pi / 2), 0, 0)))
    parts.append(kit.box("step", (hx + 0.55, 0.1, 0), (0.7, 0.2, 1.6), STONE[0], bevel=0.03))
    for z in (-2.2, 2.2):
        parts += window((hx + 0.12, 1.5, z), (1, 0), 1.0, 0.9)
        parts += window((ux + 0.12, 4.3, z * 0.85), (1, 0), 0.8, 0.85)
    parts += window((-hx - 0.12, 1.45, 0.0), (-1, 0), 1.2, 0.9, shutters=False)
    parts += side_window((0.0, 1.45, -hz - 0.12), -1, 1.0, 0.9)
    # Hanging sign: a bracket, chains and a board with a tankard on it.
    parts.append(kit.tube("bracket", [(hx + 0.2, 3.3, 1.6), (hx + 1.8, 3.3, 1.6)], 0.05, 6, IRON))
    parts.append(kit.tube("brace", [(hx + 0.2, 2.75, 1.6), (hx + 1.0, 3.28, 1.6)], 0.03, 5, IRON))
    for dz in (-0.4, 0.4):
        parts.append(kit.tube("chain", [(hx + 1.3, 3.3, 1.6 + dz), (hx + 1.3, 3.05, 1.6 + dz)], 0.012, 4, IRON))
    parts.append(kit.box("sign", (hx + 1.3, 2.72, 1.6), (0.06, 0.65, 1.0), "2f6a4f", bevel=0.02))
    parts.append(kit.box("signedge", (hx + 1.3, 2.72, 1.6), (0.04, 0.72, 1.08), GOLD))
    for sx in (1, -1):
        mug = kit.lathe("tankard", [(0.0, 0.0), (0.13, 0.0), (0.12, 0.3), (0.13, 0.32), (0.0, 0.32)], 10, GOLD, centre=(hx + 1.3 + sx * 0.04, 2.55, 1.55))
        parts.append(mug)
        parts.append(kit.tube("handle", [(hx + 1.3 + sx * 0.04, 2.83, 1.68), (hx + 1.3 + sx * 0.04, 2.78, 1.8), (hx + 1.3 + sx * 0.04, 2.62, 1.68)], 0.025, 5, GOLD))
        parts.append(kit.ellipsoid("froth", (hx + 1.3 + sx * 0.04, 2.9, 1.55), (0.13, 0.06, 0.13), "fff8ea", rings=4, sectors=8))
    # The lantern by the door (the game lights it at (3.3, 2.6, 1.6)).
    lamp = Vector((hx + 0.3, 2.6, 1.6))
    parts.append(kit.tube("lampbracket", [(hx + 0.15, 2.95, 1.6), tuple(lamp + Vector((0, 0.38, 0)))], 0.025, 5, IRON))
    parts.append(kit.lathe("lamptop", [(0.18, 0.0), (0.1, 0.12), (0.0, 0.18)], 8, IRON, centre=tuple(lamp + Vector((0, 0.17, 0)))))
    parts.append(kit.lathe("lampbase", [(0.0, 0.0), (0.17, 0.0), (0.17, 0.04), (0.0, 0.04)], 8, IRON, centre=tuple(lamp - Vector((0, 0.2, 0)))))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        parts.append(kit.box("lampbar", tuple(lamp + Vector((math.cos(a) * 0.14, 0.0, math.sin(a) * 0.14))), (0.02, 0.36, 0.02), IRON))
    # Barrels and a bench by the door.
    for i, (x, z) in enumerate(((hx + 0.6, -1.5), (hx + 0.5, -2.35))):
        b = props.barrel("tavbarrel%d" % i, light=True, seed=20 + i)
        kit.place(b, (x, 0, z))
        parts.append(b)
    parts.append(kit.box("bench", (hx + 0.55, 0.45, 2.6), (0.4, 0.07, 1.4), WOOD_DARK, bevel=0.015))
    for dz in (-0.55, 0.55):
        parts.append(kit.box("benchleg", (hx + 0.55, 0.22, 2.6 + dz), (0.32, 0.44, 0.08), WOOD_DARK))
    parts.append(kit.lathe("mug", [(0.0, 0.0), (0.06, 0.0), (0.055, 0.14), (0.0, 0.14)], 8, "8a8a92", centre=(hx + 0.55, 0.49, 2.3)))
    return kit.join("tavern", parts)


def tavern_panes():
    """The window glass alone, which the game lights from dusk (tavern windows)."""
    hx, ux = 3.0, 3.2
    parts = []
    for z in (-2.2, 2.2):
        parts.append(kit.box("pane", (hx + 0.16, 1.5, z), (0.02, 0.9, 1.0), "ffffff"))
        parts.append(kit.box("pane", (ux + 0.16, 4.3, z * 0.85), (0.02, 0.85, 0.8), "ffffff"))
    return kit.join("tavern_panes", parts)


LH_HEIGHT = 13.0


def lighthouse():
    """A striped lighthouse: a stone base, a tapering tower in red and white bands with little
    windows, a railed gallery, a glazed lamp room and a red cap with a ball and vane. The
    door faces -Z."""
    parts = []
    parts.append(kit.lathe("base", [(0.0, -0.3), (2.75, -0.3), (2.75, 0.35), (2.55, 0.5), (0.0, 0.5)], 8, STONE[1], smooth=False))
    stripes = 5
    for i in range(stripes):
        y0 = LH_HEIGHT * i / stripes
        y1 = LH_HEIGHT * (i + 1) / stripes
        r0 = 2.3 - 0.8 * i / stripes
        r1 = 2.3 - 0.8 * (i + 1) / stripes
        parts.append(kit.lathe("band", [(r0, y0), (r1, y1)], 20, "f4efe2" if i % 2 == 0 else "c8302a", caps=False))
    parts.append(kit.lathe("inner", [(0.0, 0.2), (1.4, 0.2), (1.4, LH_HEIGHT), (0.0, LH_HEIGHT)], 10, "2a2420"))
    # Windows spiralling up, and the door at the foot.
    for k in range(4):
        y = 2.8 + k * 2.6
        a = -math.pi / 2 + k * 1.3
        r = 2.3 - 0.8 * y / LH_HEIGHT
        d = Vector((math.cos(a), 0, math.sin(a)))
        parts.append(kit.box("lhwin", tuple(d * r + Vector((0, y, 0))), (0.12, 0.6, 0.4), GLASS, rot=(0, -a, 0)))
        parts.append(kit.box("lhwinframe", tuple(d * (r - 0.02) + Vector((0, y, 0))), (0.1, 0.72, 0.52), BEAM, rot=(0, -a, 0)))
    parts.append(kit.box("door", (0, 1.0, -2.28), (1.05, 1.95, 0.12), WOOD_DARK, bevel=0.02))
    for k in range(7):
        a = math.pi * k / 6
        parts.append(kit.box("doorarch", (0.62 * math.cos(a), 2.0 + 0.3 * math.sin(a), -2.25), (0.22, 0.2, 0.25), STONE[k % 4], bevel=0.02, rot=(0, 0, a - math.pi / 2)))
    top = LH_HEIGHT
    # Gallery: corbelled platform and a railing.
    parts.append(kit.lathe("corbel", [(1.5, top - 0.6), (2.25, top - 0.05), (2.3, top + 0.2), (1.0, top + 0.2)], 20, "3a3a42"))
    for k in range(16):
        a = 2 * math.pi * k / 16
        parts.append(kit.tube("baluster", [(math.cos(a) * 2.15, top + 0.2, math.sin(a) * 2.15), (math.cos(a) * 2.15, top + 1.15, math.sin(a) * 2.15)], 0.035, 5, "3a3a42"))
    ring = [(math.cos(2 * math.pi * k / 32) * 2.15, top + 1.2, math.sin(2 * math.pi * k / 32) * 2.15) for k in range(33)]
    parts.append(kit.tube("handrail", ring, 0.05, 6, "3a3a42", caps=False))
    # Lamp room: posts between glass panes (the panes are a separate part), cap and vane.
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        parts.append(kit.box("mullion", (math.cos(a) * 1.08, top + 1.15, math.sin(a) * 1.08), (0.1, 1.9, 0.1), "3a3a42", rot=(0, -a, 0)))
    parts.append(kit.lathe("roomfloor", [(0.0, top + 0.2), (1.15, top + 0.2), (1.15, top + 0.3), (0.0, top + 0.3)], 12, "3a3a42"))
    parts.append(kit.lathe("cap", [(0.0, top + 2.0), (1.5, top + 2.0), (1.48, top + 2.15), (0.9, top + 2.75), (0.25, top + 3.2), (0.0, top + 3.3)], 16, "c8302a"))
    parts.append(kit.ellipsoid("ball", (0, top + 3.42, 0), (0.18, 0.18, 0.18), GOLD, rings=6, sectors=10))
    parts.append(kit.tube("vanepost", [(0, top + 3.5, 0), (0, top + 4.3, 0)], 0.03, 5, IRON))
    parts.append(kit.prism("vane", [(-0.5, 0.0), (0.3, 0.0), (0.5, 0.12), (0.3, 0.24), (-0.5, 0.24), (-0.35, 0.12)], 0.02, IRON, centre=(0, top + 4.0, 0), plane="xy"))
    return kit.join("lighthouse", parts)


def lighthouse_glass():
    """The lamp room's glass, which the game lights at night."""
    top = LH_HEIGHT
    return kit.lathe("lighthouse_glass", [(1.04, top + 0.3), (1.04, top + 2.0)], 8, "fff3b0", caps=False)


def stall():
    """The merchant's stall: a plank floor, plank walls on three sides, a counter across the
    open front under a striped scalloped awning, a sign with a gold coin, goods stacked
    inside (crates, sacks, a barrel, scales on the counter) and a lantern."""
    rng = random.Random(3)
    parts = []
    # Floor and posts.
    for k in range(10):
        x = -3.0 + k * 0.6
        parts.append(kit.box("floorplank", (x + 0.3, -0.08, 0), (0.56, 0.12, 4.9), WOOD if k % 2 else "d29a5c", bevel=0.01))
    for x, z in ((-2.9, -2.35), (-2.9, 2.35), (1.85, -2.35), (1.85, 2.35)):
        parts.append(kit.box("post", (x, 1.45, z), (0.2, 2.9, 0.2), BEAM, bevel=0.02))
    # Plank walls, vertical boards with a little gap.
    for k in range(8):
        z = -2.1 + k * 0.6
        parts.append(kit.box("board", (-2.95, 1.4, z), (0.08, 2.8, 0.56), "a0522d" if k % 2 else "8f4a28", bevel=0.01))
    for sz in (1, -1):
        for k in range(8):
            x = -2.6 + k * 0.6
            parts.append(kit.box("board", (x, 1.4, sz * 2.38), (0.56, 2.8, 0.08), "a0522d" if k % 2 else "8f4a28", bevel=0.01))
    # Counter.
    parts.append(kit.box("counter", (1.6, 0.55, 0), (0.6, 1.1, 4.0), "c08a50", bevel=0.02))
    for k in range(7):
        parts.append(kit.box("counterplank", (1.92, 0.55, -1.8 + k * 0.6), (0.04, 1.05, 0.54), WOOD_DARK))
    parts.append(kit.box("countertop", (1.62, 1.13, 0), (0.9, 0.1, 4.2), "5e3a22", bevel=0.02))
    # Roof and awning.
    parts.append(kit.box("roof", (-0.5, 2.95, 0), (5.7, 0.14, 5.3), "7d3c20", bevel=0.03, rot=(0, 0, -0.08)))
    stripes = 8
    for i in range(stripes):
        z = -2.4 + (i + 0.5) * 4.8 / stripes
        c = "d63c3c" if i % 2 == 0 else "fff8ea"
        parts.append(kit.box("awning", (2.55, 2.55, z), (1.6, 0.05, 4.8 / stripes), c, rot=(0, 0, -0.38)))
        # A scallop hanging off the front edge.
        parts.append(kit.prism("scallop", [(z - 0.3, 0.0), (z + 0.3, 0.0), (z, -0.25)], 0.04, c, centre=(3.3, 2.26, 0), plane="zy"))
    for z in (-2.35, 2.35):
        parts.append(kit.tube("awningpole", [(3.3, 0.0, z), (3.3, 2.3, z)], 0.05, 6, BEAM))
    # Sign on the roof: a board with a big gold coin.
    parts.append(kit.box("signboard", (1.2, 3.5, 0), (0.1, 0.8, 2.6), "b07a42", bevel=0.02))
    parts.append(kit.lathe("coin", [(0.0, -0.03), (0.32, -0.03), (0.32, 0.03), (0.0, 0.03)], 16, GOLD, centre=(1.27, 3.5, 0), axis="x"))
    parts.append(kit.lathe("coinrim", [(0.26, 0.03), (0.3, 0.05), (0.26, 0.07)], 16, "e0a020", caps=False, centre=(1.27, 3.5, 0), axis="x"))
    # Goods inside.
    for i, (x, z, s) in enumerate(((-2.3, -1.6, 0.7), (-2.3, -0.8, 0.6), (-2.25, -1.25, 0.5))):
        y = s / 2 if i < 2 else 0.6 + s / 2
        parts.append(kit.box("crate", (x, y, z), (s, s, s), "a87442", bevel=0.02))
        for k in range(2):
            parts.append(kit.box("slat", (x, y - s / 4 + k * s / 2, z), (s + 0.02, 0.05, s + 0.02), "7a5430"))
    for i in range(3):
        x, z = -2.2 + i * 0.5, 1.5 + (i % 2) * 0.3
        sack = kit.ellipsoid("sack", (x, 0.35, z), (0.28, 0.38, 0.25), "c9b48a", rings=8, sectors=10)
        kit.jitter(sack, 0.02, i)
        parts.append(sack)
        parts.append(kit.lathe("tie", [(0.08, 0.0), (0.05, 0.12), (0.09, 0.2), (0.0, 0.22)], 8, "c9b48a", centre=(x, 0.7, z)))
    b = props.barrel("stallbarrel", light=True, seed=31)
    kit.place(b, (-0.8, 0, -1.9))
    parts.append(b)
    # Scales on the counter.
    sx, sy, sz_ = 1.6, 1.18, -1.2
    parts.append(kit.lathe("scalebase", [(0.0, 0.0), (0.12, 0.0), (0.06, 0.05), (0.03, 0.4), (0.0, 0.42)], 8, GOLD, centre=(sx, sy, sz_)))
    parts.append(kit.tube("beam", [(sx, sy + 0.4, sz_ - 0.25), (sx, sy + 0.4, sz_ + 0.25)], 0.015, 5, GOLD))
    for dz in (-0.25, 0.25):
        parts.append(kit.lathe("pan", [(0.0, 0.0), (0.1, 0.02), (0.11, 0.05), (0.0, 0.03)], 10, GOLD, centre=(sx, sy + 0.2, sz_ + dz)))
        parts.append(kit.tube("string", [(sx, sy + 0.4, sz_ + dz), (sx, sy + 0.24, sz_ + dz)], 0.006, 3, IRON))
    # A little stack of coins and a ledger.
    for k in range(4):
        parts.append(kit.lathe("coins", [(0.0, 0.0), (0.06, 0.0), (0.06, 0.018), (0.0, 0.018)], 10, GOLD, centre=(1.55, 1.18 + k * 0.02, 0.8)))
    parts.append(kit.box("ledger", (1.6, 1.21, 0.3), (0.3, 0.05, 0.4), "6a2a2a", bevel=0.01, rot=(0, 0.2, 0)))
    # The lantern (the game lights it 2.4 m above the merchant, at x = -0.9).
    lamp = Vector((-0.9, 2.4, 0.0))
    parts.append(kit.tube("lampchain", [(-0.9, 2.88, 0), tuple(lamp + Vector((0, 0.2, 0)))], 0.012, 4, IRON))
    parts.append(kit.lathe("lamptop", [(0.17, 0.0), (0.09, 0.11), (0.0, 0.16)], 8, IRON, centre=tuple(lamp + Vector((0, 0.17, 0)))))
    parts.append(kit.lathe("lampbase", [(0.0, 0.0), (0.16, 0.0), (0.16, 0.04), (0.0, 0.04)], 8, IRON, centre=tuple(lamp - Vector((0, 0.2, 0)))))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        parts.append(kit.box("lampbar", tuple(lamp + Vector((math.cos(a) * 0.13, 0.0, math.sin(a) * 0.13))), (0.02, 0.36, 0.02), IRON))
    return kit.join("stall", parts)


PIER_LEN = 24.0
PIER_HALF = 1.6


def pier():
    """The pier from its root (origin) out along +X: deck planks with gaps, stringers, posts
    down into the sea every 3 m with cross bracing, a sagging rope rail, bollards with rope
    on them, a ladder down to the water and two lamp posts at the end (the game lights them
    2.6 m up). Deck top at y = 0."""
    rng = random.Random(5)
    parts = []
    x = 0.0
    k = 0
    while x < PIER_LEN - 0.01:
        w = 0.56
        c = WOOD if k % 2 == 0 else "d29a5c"
        length = 2 * PIER_HALF + rng.uniform(-0.1, 0.15)
        parts.append(kit.box("plank", (x + 0.3, -0.06, rng.uniform(-0.05, 0.05)), (w, 0.12, length), c, bevel=0.012, segments=1, rot=(0, rng.uniform(-0.015, 0.015), 0)))
        x += 0.6
        k += 1
    for z in (-1.0, 0.0, 1.0):
        parts.append(kit.box("stringer", (PIER_LEN / 2, -0.24, z * (PIER_HALF - 0.3)), (PIER_LEN, 0.2, 0.18), WOOD_DARK))
    px = 2.0
    posts = []
    while px <= PIER_LEN:
        for side in (1, -1):
            z = side * (PIER_HALF - 0.15)
            parts.append(kit.lathe("post", [(0.18, -5.3), (0.17, -0.1), (0.15, 0.85), (0.0, 0.92)], 8, "7d3c20", centre=(px, 0, z)))
            posts.append((px, z))
        # Cross bracing under the deck.
        parts.append(kit.tube("brace", [(px, -0.3, -(PIER_HALF - 0.15)), (px, -1.8, PIER_HALF - 0.15)], 0.07, 5, WOOD_DARK))
        px += 3.0
    # Rope rail sagging between the posts.
    for side in (1, -1):
        z = side * (PIER_HALF - 0.15)
        prev = None
        for px_, pz in [p for p in posts if p[1] == z]:
            if prev is not None:
                pts = [(prev + (px_ - prev) * t, 0.82 - 0.18 * math.sin(math.pi * t), z) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
                parts.append(kit.tube("rope", pts, 0.03, 5, "caa36a", caps=False))
            prev = px_
    # Bollards with rope, a coil, a ladder at the end.
    for bx, bz in ((9.5, 1.2), (16.5, -1.2), (22.0, 1.2)):
        parts.append(kit.lathe("bollard", [(0.0, 0.0), (0.18, 0.0), (0.15, 0.25), (0.22, 0.32), (0.22, 0.4), (0.0, 0.42)], 10, IRON, centre=(bx, 0, bz)))
        coil = [(bx + 0.25 * math.cos(2 * math.pi * i / 12), 0.12 + 0.06 * i / 12, bz + 0.25 * math.sin(2 * math.pi * i / 12)) for i in range(13)]
        parts.append(kit.tube("loop", coil, 0.035, 5, "caa36a", caps=False))
    for lz in (-0.35, 0.35):
        parts.append(kit.tube("ladder", [(PIER_LEN + 0.1, 0.1, lz), (PIER_LEN + 0.1, -2.5, lz)], 0.05, 6, WOOD_DARK))
    for y in (-0.3, -0.75, -1.2, -1.65, -2.1):
        parts.append(kit.box("rung", (PIER_LEN + 0.1, y, 0), (0.08, 0.06, 0.75), WOOD_DARK))
    # Lamp posts at the end (lit 2.6 m up, 0.4 m from the end).
    for side in (1, -1):
        foot = Vector((PIER_LEN - 0.4, 0.0, side * (PIER_HALF - 0.15)))
        parts.append(kit.lathe("lamppost", [(0.11, 0.0), (0.08, 0.2), (0.06, 2.3), (0.08, 2.38), (0.0, 2.4)], 8, IRON, centre=tuple(foot)))
        lamp = foot + Vector((0, 2.6, 0))
        parts.append(kit.lathe("lamptop", [(0.2, 0.0), (0.1, 0.13), (0.0, 0.2)], 8, IRON, centre=tuple(lamp + Vector((0, 0.2, 0)))))
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            parts.append(kit.box("lampbar", tuple(lamp + Vector((math.cos(a) * 0.15, 0.0, math.sin(a) * 0.15))), (0.025, 0.4, 0.025), IRON))
    return kit.join("pier", parts)


def flagpole():
    """The flag by the pier's root: a tall pole with a gold ball and a red flag with a coin."""
    parts = [kit.lathe("pole", [(0.15, 0.0), (0.12, 0.3), (0.08, 9.0), (0.0, 9.05)], 8, BEAM)]
    parts.append(kit.ellipsoid("ball", (0, 9.12, 0), (0.14, 0.14, 0.14), GOLD, rings=6, sectors=8))
    rows = []
    for i in range(9):
        t = i / 8
        rows.append([(0.1 + 1.8 * t, 8.7 - 1.0 * v, 0.12 * math.sin(t * math.pi * 1.5) * t) for v in (0.0, 0.5, 1.0)])
    cloth = kit.grid_surface("flag", list(zip(*rows)), "d63c3c")
    sol = cloth.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.03
    kit.apply_all(cloth)
    parts.append(cloth)
    parts.append(kit.noink(kit.lathe("coin", [(0.0, -0.03), (0.28, -0.03), (0.28, 0.03), (0.0, 0.03)], 14, GOLD, centre=(1.0, 8.2, 0.1), axis="z"), 0.3))
    parts.append(kit.tube("halyard", [(0.12, 9.0, 0.02), (0.12, 0.8, 0.02)], 0.01, 3, "caa36a"))
    return kit.join("flagpole", parts)


def main(names):
    builders = {
        "tavern": lambda: [tavern(), tavern_panes()],
        "lighthouse": lambda: [lighthouse(), lighthouse_glass()],
        "stall": lambda: [stall()],
        "pier": lambda: [pier(), flagpole()],
    }
    for name in names or builders:
        kit.reset()
        objs = builders[name]()
        kit.export(name, objs, ao_distance=0.6, ao_strength=0.8)


if __name__ == "__main__":
    main(kit.args())

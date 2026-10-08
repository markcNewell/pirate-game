"""The places of Act IV (docs/specs/2026-10-08-m11-the-drowned-fleet.md): Isla Calavera's skull
rock, its tooth-stones and carvings; Isla Ceniza's dead ash trees; the Black Reef's rocks, wreck
masts and great green lanterns.

    blender -b --factory-startup --python art/blender/places.py [-- calavera ashtrees reef]

Frames (Godot axes): the skull rock's centre on the ground at the origin, its face looking along
-Z (game/world/calavera.gd turns it to face the beach); everything else stands on y = 0 at the
origin.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

STONE = "c8bfa8"
STONE_DARK = "9a917c"
HOLLOW = "1a1714"
MOSS = "6a7a4a"
ASH_BARK = "6a6460"
ASH_DARK = "3e3a38"
REEF = "2e2e34"
REEF_LIGHT = "4a4a52"
IRON = "2e2e36"
GREEN_GLASS = "9cff8a"
WOOD = "6a4a2c"


def calavera():
    """A rock shaped like a skull, buried in the beach to its cheekbones: a domed brow, two eye
    hollows and a nose hole looking along -Z, cheekbones, and grass on its crown. About 26 m
    across and 15 m high."""
    parts = []
    dome = kit.ellipsoid("dome", (0, 1.5, 2.0), (12.5, 13.5, 10.5), STONE, rings=18, sectors=28)
    for v in dome.data.vertices:
        x, y, z = kit.G(v.co)
        # The face is flatter than the back of the head, and narrower below the brow.
        if z < -4.0:
            z = -4.0 + (z + 4.0) * 0.45
        if y < 5.0 and z < 0.0:
            x *= 0.9
        y = max(y, -0.5)
        v.co = kit.V(x, y, z)
    kit.jitter(dome, 0.35, 3)
    kit.paint_where(dome, STONE_DARK, lambda x, y, z: (int(x * 0.7) + int(y * 0.9) + int(z * 0.5)) % 4 == 0)
    kit.paint_where(dome, MOSS, lambda x, y, z: y > 12.0)
    parts.append(dome)
    brow = kit.ellipsoid("brow", (0, 8.6, -6.6), (9.5, 1.5, 2.2), STONE, rings=6, sectors=16)
    kit.jitter(brow, 0.2, 5)
    parts.append(brow)
    for sx in (1, -1):
        eye = kit.noink(kit.ellipsoid("eye", (sx * 4.4, 5.6, -7.25), (2.7, 2.6, 0.9), HOLLOW, rings=8, sectors=12), 0.3)
        parts.append(eye)
        cheek = kit.ellipsoid("cheek", (sx * 7.0, 2.4, -5.4), (2.6, 2.0, 2.2), STONE, rings=6, sectors=10)
        kit.jitter(cheek, 0.2, 7 if sx > 0 else 8)
        parts.append(cheek)
    nose = kit.noink(kit.prism("nose", [(-1.2, 0.0), (1.2, 0.0), (0.0, 2.4)], 0.6, HOLLOW, centre=(0, 1.6, -7.7), plane="xy"), 0.3)
    parts.append(nose)
    # The upper teeth: worn stumps along the ground under the nose.
    for k in range(7):
        x = -4.2 + k * 1.4
        tooth = kit.box("tooth", (x, 0.5, -6.9), (1.0, 1.4, 0.8), "e2dcc8", bevel=0.25)
        parts.append(tooth)
    return kit.join("calavera", parts)


def tooth_stone():
    """A standing stone shaped like a great worn tooth (2.4 m): the jaw's teeth along the beach."""
    ob = kit.lathe("tooth_stone", [(0.0, 0.0), (0.55, 0.0), (0.62, 0.8), (0.58, 1.6), (0.42, 2.2), (0.0, 2.45)], 10, "e2dcc8")
    ob.scale = (1.0, 1.0, 0.75)
    kit.transform_apply(ob)
    kit.jitter(ob, 0.04, 11)
    kit.paint_where(ob, STONE_DARK, lambda x, y, z: y < 0.25)
    return ob


def carving():
    """A slab of pale stone leaning back, cut with a skull over an arrow and a row of notches."""
    parts = [kit.box("slab", (0, 0.55, 0), (1.2, 1.1, 0.25), STONE, bevel=0.06, rot=(-0.2, 0, 0))]
    cut = "3a3428"
    parts.append(kit.noink(kit.ellipsoid("cut_skull", (0, 0.78, -0.17), (0.18, 0.2, 0.02), cut, rings=4, sectors=8), 0.0))
    parts.append(kit.noink(kit.box("cut_arrow", (0, 0.42, -0.1), (0.06, 0.4, 0.02), cut, rot=(-0.2, 0, 0)), 0.0))
    parts.append(kit.noink(kit.prism("cut_head", [(-0.14, 0.0), (0.14, 0.0), (0.0, -0.16)], 0.02, cut, centre=(0, 0.2, -0.06), plane="xy"), 0.0))
    for k in range(3):
        parts.append(kit.noink(kit.box("notch", (-0.4 + 0.1 * k, 0.95, -0.2), (0.03, 0.14, 0.02), cut, rot=(-0.2, 0, 0)), 0.0))
    return kit.join("carving", parts)


def dead_tree(name, height, seed):
    """A dead tree of Isla Ceniza: a bare grey trunk, twisted, with a few broken branches."""
    rng = random.Random(seed)
    parts = []
    lean = rng.uniform(-0.6, 0.6)
    pts = [(0, 0, 0), (lean * 0.3, height * 0.4, 0.1), (lean * 0.7, height * 0.75, -0.1), (lean, height, 0.0)]
    parts.append(kit.tube("trunk", pts, [0.32, 0.22, 0.14, 0.05], 8, ASH_BARK))
    for k in range(4):
        t = 0.45 + 0.15 * k
        base = (lean * t, height * t, 0.0)
        a = rng.uniform(0, 2 * math.pi)
        reach = rng.uniform(1.0, 2.2) * (1.0 - 0.15 * k)
        tip = (base[0] + math.cos(a) * reach, base[1] + rng.uniform(0.4, 1.2), base[2] + math.sin(a) * reach)
        mid = ((base[0] + tip[0]) / 2, (base[1] + tip[1]) / 2 + 0.2, (base[2] + tip[2]) / 2)
        parts.append(kit.tube("branch", [base, mid, tip], [0.1, 0.06, 0.02], 5, ASH_DARK if k % 2 else ASH_BARK))
    return kit.join(name, parts)


def reef_rock(name, size, seed):
    """A black, jagged reef rock breaking the surface: a few leaning spikes."""
    rng = random.Random(seed)
    parts = []
    for k in range(4):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.0, 0.8) * size
        h = rng.uniform(1.4, 3.2) * size
        foot = (math.cos(a) * r, -1.5, math.sin(a) * r)
        top = (foot[0] + rng.uniform(-0.5, 0.5), h, foot[2] + rng.uniform(-0.5, 0.5))
        spike = kit.tube("spike", [foot, top], [0.9 * size, 0.08], 6, REEF if k % 2 else REEF_LIGHT)
        kit.jitter(spike, 0.08 * size, seed + k)
        parts.append(spike)
    return kit.join(name, parts)


def wreck_mast():
    """A drowned ship's mast standing out of the sea at a lean: a broken yard and a rag of sail."""
    parts = [kit.tube("mast", [(0, -3.0, 0), (0.6, 4.0, 0.2), (1.0, 8.0, 0.35)], [0.28, 0.22, 0.16], 8, "4a3a2c")]
    parts.append(kit.tube("yard", [(-2.0, 6.0, 0.0), (0.8, 6.6, 0.3), (3.2, 7.4, 0.5)], 0.11, 6, "4a3a2c"))
    rag = kit.prism("rag", [(-0.2, 0.0), (1.6, 0.0), (1.4, -1.6), (0.6, -2.2), (0.0, -1.1)], 0.03, "8a8474", centre=(0.9, 6.6, 0.35), plane="xy")
    parts.append(rag)
    parts.append(kit.noink(kit.tube("weed", [(0.35, 1.5, 0.1), (0.5, 0.2, 0.3)], 0.05, 4, "3a6a3a"), 0.2))
    return kit.join("wreck_mast", parts)


def great_lantern(broken=False):
    """Ocaso's lantern of the deep on its stone plinth: a 3 m post and an iron cage of green
    glass as tall as a man. Broken, the cage lies smashed at the foot of the post."""
    parts = [kit.box("plinth", (0, 0.3, 0), (1.3, 0.6, 1.3), "6a6a6e", bevel=0.08)]
    parts.append(kit.tube("post", [(0, 0.6, 0), (0, 3.0, 0)], 0.12, 8, IRON))
    head_y = 3.0
    if broken:
        parts.append(kit.tube("snapped", [(0, 3.0, 0), (0.1, 3.3, 0.05)], [0.12, 0.04], 6, IRON))
        cage_at = (0.9, 0.35, 0.5)
        parts.append(kit.lathe("cage", [(0.0, -0.4), (0.45, -0.4), (0.5, 0.4), (0.0, 0.5)], 8, IRON, centre=cage_at))
        for k in range(5):
            a = 2 * math.pi * k / 5
            parts.append(kit.noink(kit.prism("shard", [(0.0, 0.0), (0.2, 0.05), (0.1, 0.25)], 0.02, "6ac87a", centre=(1.4 + math.cos(a) * 0.8, 0.02, 0.4 + math.sin(a) * 0.8), plane="xz"), 0.2))
        return kit.join("great_lantern_broken", parts)
    parts.append(kit.lathe("lamp_base", [(0.0, 0.0), (0.55, 0.0), (0.55, 0.12), (0.0, 0.12)], 8, IRON, centre=(0, head_y, 0)))
    parts.append(kit.noink(kit.lathe("lamp_glass", [(0.45, 0.12), (0.52, 0.8), (0.42, 1.5)], 8, GREEN_GLASS, caps=False, centre=(0, head_y, 0)), 0.0))
    for k in range(6):
        a = 2 * math.pi * k / 6
        parts.append(kit.tube("cage_bar", [(math.cos(a) * 0.53, head_y + 0.1, math.sin(a) * 0.53), (math.cos(a) * 0.56, head_y + 0.8, math.sin(a) * 0.56), (math.cos(a) * 0.45, head_y + 1.5, math.sin(a) * 0.45)], 0.035, 4, IRON))
    parts.append(kit.lathe("lamp_roof", [(0.62, head_y + 1.5), (0.3, head_y + 1.85), (0.06, head_y + 2.05), (0.0, head_y + 2.05)], 8, IRON))
    parts.append(kit.lathe("lamp_ring", [(0.12, head_y + 2.05), (0.12, head_y + 2.3)], 8, IRON, caps=False))
    return kit.join("great_lantern", parts)


def chart_case():
    """The pilot's chart in a leather tube with brass caps (0.7 m), weed still on it."""
    tube = kit.lathe("case", [(0.0, -0.35), (0.07, -0.35), (0.07, 0.35), (0.0, 0.35)], 10, "6a3a22", axis="x", centre=(0, 0.08, 0))
    caps = [kit.lathe("cap", [(0.075, -0.05), (0.075, 0.05)], 10, "c8a040", axis="x", caps=False, centre=(sx * 0.32, 0.08, 0)) for sx in (1, -1)]
    strap = kit.tube("strap", [(-0.25, 0.15, 0), (0.0, 0.25, 0), (0.25, 0.15, 0)], 0.012, 4, "3a2414", caps=False)
    weed = kit.noink(kit.tube("weed", [(0.1, 0.15, 0.05), (0.15, 0.02, 0.08)], 0.012, 4, "3a6a3a"), 0.2)
    return kit.join("chart_case", [tube, strap, weed] + caps)


def workshop():
    """Doctor Ocaso's workshop, dug into Isla Ceniza's hill: a front of rough grey stone with an
    arched door (facing -Z), two round windows of green glass, a crooked chimney and a lean-to
    roof of scorched planks over a long table of bottles. About 7 m wide."""
    parts = [kit.box("front", (0, 2.2, 0.6), (7.0, 4.4, 1.2), "6e6a66", bevel=0.12)]
    kit.jitter(parts[0], 0.06, 81)
    kit.paint_where(parts[0], "565250", lambda x, y, z: (int(x * 2) + int(y * 2)) % 3 == 0)
    parts.append(kit.noink(kit.prism("door", [(-0.8, 0.0), (0.8, 0.0), (0.8, 1.8), (0.0, 2.5), (-0.8, 1.8)], 0.1, "141210", centre=(0, 0.0, -0.02), plane="xy"), 0.2))
    for sx in (-1, 1):
        parts.append(kit.noink(kit.lathe("window", [(0.0, -0.02), (0.45, -0.02), (0.45, 0.02), (0.0, 0.02)], 12, "6aff8a", axis="z", centre=(sx * 2.3, 2.6, -0.04)), 0.1))
        parts.append(kit.lathe("window_rim", [(0.45, -0.06), (0.55, -0.06), (0.55, 0.06), (0.45, 0.06)], 12, "3a3634", axis="z", caps=False, centre=(sx * 2.3, 2.6, -0.04)))
    parts.append(kit.tube("chimney", [(2.4, 4.0, 1.0), (2.5, 5.6, 1.1), (2.3, 6.6, 1.0)], [0.45, 0.4, 0.42], 8, "4a4644"))
    parts.append(kit.box("lean_to", (-1.8, 2.7, -1.3), (3.4, 0.12, 2.4), "3a2e24", rot=(0.35, 0, 0)))
    for sx in (-3.3, -0.4):
        parts.append(kit.tube("post", [(sx, 0.0, -2.3), (sx, 2.35, -2.3)], 0.08, 6, "3a2e24"))
    parts.append(kit.box("table", (-1.8, 0.9, -1.6), (2.6, 0.12, 0.8), "4a3a2c"))
    for k in range(7):
        x = -2.9 + k * 0.36
        colour = ("6aff8a", "c8302a", "4a8ae0", "e0b04a")[k % 4]
        parts.append(kit.lathe("bottle", [(0.0, 0.0), (0.07, 0.0), (0.07, 0.18), (0.025, 0.26), (0.0, 0.26)], 8, colour, centre=(x, 0.96, -1.6 + 0.12 * (k % 2))))
    return kit.join("workshop", parts)


def brazier():
    """A brazier of Ocaso's: an iron basket of coals on three legs (the game lights it green)."""
    parts = [kit.lathe("basket", [(0.0, 0.85), (0.32, 0.9), (0.45, 1.2), (0.42, 1.25)], 10, IRON, caps=False)]
    for k in range(3):
        a = 2 * math.pi * k / 3
        parts.append(kit.tube("leg", [(math.cos(a) * 0.35, 1.0, math.sin(a) * 0.35), (math.cos(a) * 0.5, 0.0, math.sin(a) * 0.5)], 0.03, 5, IRON))
    parts.append(kit.ellipsoid("coals", (0, 1.12, 0), (0.36, 0.1, 0.36), "2a2420", rings=4, sectors=10))
    return kit.join("brazier", parts)


def beacon():
    """A beacon on an island's height: a square stack of logs round a pole, on a ring of stones."""
    parts = []
    for k in range(10):
        a = 2 * math.pi * k / 10
        parts.append(kit.ellipsoid("stone", (math.cos(a) * 1.5, 0.15, math.sin(a) * 1.5), (0.35, 0.25, 0.3), "8c8478", rings=4, sectors=6))
    for layer in range(5):
        y = 0.25 + layer * 0.32
        along = layer % 2 == 0
        for sx in (-1, 1):
            if along:
                parts.append(kit.tube("log", [(-1.0, y, sx * 0.75), (1.0, y, sx * 0.75)], 0.14, 6, "6a4a2c"))
            else:
                parts.append(kit.tube("log", [(sx * 0.75, y, -1.0), (sx * 0.75, y, 1.0)], 0.14, 6, "5a3e24"))
    parts.append(kit.tube("pole", [(0, 0, 0), (0, 3.4, 0)], 0.08, 6, "4a3a2c"))
    parts.append(kit.ellipsoid("kindling", (0, 0.9, 0), (0.7, 0.6, 0.7), "a07a4a", rings=4, sectors=8))
    return kit.join("beacon", parts)


def heart():
    """The Heart of Ash: a fist-sized black stone, faceted, cracked through with green fire."""
    ob = kit.ellipsoid("heart", (0, 0.2, 0), (0.2, 0.22, 0.18), "1a1a1e", rings=6, sectors=8)
    kit.jitter(ob, 0.025, 91)
    kit.paint_where(ob, "8aff9a", lambda x, y, z: abs(x * 3.0 + z * 2.0 - (y - 0.2) * 4.0) < 0.12 or abs(x - z * 2.5) < 0.05)
    return ob


def main(names):
    builders = {
        "calavera": lambda: [calavera(), tooth_stone(), carving()],
        "ashtrees": lambda: [dead_tree("deadtree_%d" % i, h, 60 + i) for i, h in enumerate((6.0, 7.5, 9.0))],
        "reef": lambda: [reef_rock("reef_rock_0", 1.0, 70), reef_rock("reef_rock_1", 1.4, 71), wreck_mast(), great_lantern(), great_lantern(True), chart_case()],
        "ceniza": lambda: [workshop(), brazier(), beacon(), heart()],
    }
    for name in names or builders:
        kit.reset()
        kit.export(name, builders[name](), ao_distance=0.8)


if __name__ == "__main__":
    main(kit.args())

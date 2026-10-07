"""Small props: barrels, crates, chests and the like.

    blender -b --factory-startup --python art/blender/props.py [-- NAME ...]
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
from kit import V  # noqa: E402

WOODS = ["9a6838", "a87442", "8f5f33", "a06c3c"]


def _radius(t, r_end, r_mid):
    return r_end + (r_mid - r_end) * math.sin(t * math.pi)


def staves(name, height, r_end, r_mid, count, woods, rings=10, thick=0.035, gap=0.006, seed=1):
    """A barrel body of `count` separate staves, each a curved slab bulging like a real barrel."""
    import bmesh
    rng = random.Random(seed)
    parts = []
    span = 2 * math.pi / count
    for s in range(count):
        bm = bmesh.new()
        a0 = s * span + gap / r_mid / 2
        a1 = (s + 1) * span - gap / r_mid / 2
        across = 3
        outer, inner = [], []
        for k in range(rings + 1):
            t = k / rings
            y = t * height
            r = _radius(t, r_end, r_mid)
            ro, ri = [], []
            for j in range(across + 1):
                a = a0 + (a1 - a0) * j / across
                ro.append(bm.verts.new(V(r * math.cos(a), y, r * math.sin(a))))
                ri.append(bm.verts.new(V((r - thick) * math.cos(a), y, (r - thick) * math.sin(a))))
            outer.append(ro)
            inner.append(ri)
        for k in range(rings):
            for j in range(across):
                bm.faces.new((outer[k][j], outer[k][j + 1], outer[k + 1][j + 1], outer[k + 1][j]))
                bm.faces.new((inner[k][j], inner[k + 1][j], inner[k + 1][j + 1], inner[k][j + 1]))
            for j in (0, across):
                bm.faces.new((outer[k][j], outer[k + 1][j], inner[k + 1][j], inner[k][j]))
        for k in (0, rings):
            for j in range(across):
                bm.faces.new((outer[k][j], inner[k][j], inner[k][j + 1], outer[k][j + 1]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = kit.obj_from_bmesh("%s_%d" % (name, s), bm, woods[(s * 5 + seed) % len(woods)])
        kit.smooth_by_angle(ob, 35)
        parts.append(ob)
    return parts


def hoop(name, y, r_end, r_mid, height_total, band, thick, color):
    """An iron band hugging the barrel's bulge at height `y`."""
    prof = []
    for k in range(3):
        yy = y - band / 2 + band * k / 2
        prof.append((_radius(yy / height_total, r_end, r_mid) + thick, yy))
    inner = [(_radius(yy / height_total, r_end, r_mid) - 0.002, yy) for _r, yy in reversed(prof)]
    return kit.lathe(name, prof + inner + [prof[0]], 40, color, caps=False, smooth=False)


def disc_planks(name, y, r, thick, colors, planks=4, gap=0.006):
    """A round lid or floor of planks, each cut to the circle."""
    parts = []
    w = 2 * r / planks
    for i in range(planks):
        x0 = -r + i * w + gap / 2
        x1 = -r + (i + 1) * w - gap / 2
        pts = []
        steps = 6
        for k in range(steps + 1):
            x = x0 + (x1 - x0) * k / steps
            pts.append((x, -math.sqrt(max(0.0, r * r - x * x))))
        for k in range(steps, -1, -1):
            x = x0 + (x1 - x0) * k / steps
            pts.append((x, math.sqrt(max(0.0, r * r - x * x))))
        ob = kit.prism("%s_%d" % (name, i), pts, thick, colors[i % len(colors)], centre=(0, y, 0), plane="xz", bevel=0.004)
        parts.append(ob)
    return parts


def barrel(name="barrel", height=0.95, r_end=0.33, r_mid=0.4, top=True, hoops=(0.09, 0.25, 0.70, 0.86), seed=1):
    parts = staves(name + "_stave", height, r_end, r_mid, 14, WOODS, seed=seed)
    for k, h in enumerate(hoops):
        parts.append(hoop("%s_hoop%d" % (name, k), h, r_end, r_mid, height, 0.05, 0.012, "34303a"))
    sunk = 0.045
    if top:
        parts += disc_planks(name + "_lid", height - sunk, r_end - 0.03, 0.03, ["b7854f", "a87442", "b07c48"])
        parts.append(kit.lathe(name + "_bung", [(0.035, 0), (0.035, 0.02), (0.025, 0.028), (0.0, 0.03)], 10, "5a3a22", centre=(0.13, height - sunk + 0.012, 0.09)))
    parts += disc_planks(name + "_floor", sunk, r_end - 0.03, 0.03, ["8f5f33"])
    return kit.join(name, parts)


def supply_barrel():
    """The floating / pier supply barrel: a barrel with a white X stencil and rope lashing."""
    return barrel("supply_barrel")


STEEL = "d8dde2"
STEEL_DARK = "9aa2ac"
BRASS = "e0b04a"
BRASS_DARK = "a87a2a"
LEATHER = "4a2c1c"
WOOD_DARK = "6b4128"


def cutlass():
    """A cutlass held at the grip (origin), blade forward along -Z, edge down: a curved blade
    with a fuller, a brass shell guard with a knuckle bow, a wrapped grip and a pommel."""
    parts = []
    # The blade: a curved outline in the Z/Y plane, thin across X.
    length = 0.64
    pts_top, pts_bot = [], []
    n = 16
    for i in range(n + 1):
        t = i / n
        z = -0.06 - length * t
        curve = 0.05 * t * t
        width = 0.046 * (1 - 0.25 * t)
        back = curve + 0.006
        edge = curve - width
        if t > 0.86:
            # The clipped point: the back sweeps down to meet the edge.
            k = (t - 0.86) / 0.14
            back = back - (back - edge) * k ** 1.3 * 0.92
        pts_top.append((z, back))
        pts_bot.append((z, edge))
    outline = pts_top + list(reversed(pts_bot))
    blade = kit.prism("blade", outline, 0.007, STEEL, plane="zy", bevel=0.0025, segments=1)
    kit.apply_all(blade)
    # Thin the edge: squash vertices toward the edge side.
    for v in blade.data.vertices:
        x, y, z = kit.G(v.co)
        t = min(1.0, max(0.0, (-0.06 - z) / length))
        curve = 0.05 * t * t
        width = 0.046 * (1 - 0.25 * t)
        k = (y - (curve - width)) / max(1e-4, width)
        v.co = kit.V(x * (0.25 + 0.75 * min(1.0, max(0.0, k)) ** 0.5), y, z)
    kit.smooth_by_angle(blade, 30)
    parts.append(blade)
    fuller = [(0.0, 0.0 + 0.05 * (t * 0.7) ** 2 - 0.012, -0.08 - length * 0.7 * t) for t in (0.0, 0.33, 0.66, 1.0)]
    for side in (1, -1):
        f = kit.tube("fuller", [(side * 0.0036, y, z) for _x, y, z in fuller], 0.0035, 5, STEEL_DARK, caps=True)
        kit.noink(f)
        parts.append(f)
    # Shell guard: a shallow brass dish round the blade's root.
    parts.append(kit.lathe("shell", [(0.0, 0.0), (0.05, 0.008), (0.056, 0.016), (0.0, 0.02)], 20, BRASS, centre=(0, -0.012, -0.068), axis="z"))
    # Knuckle bow from the shell under the fist to the pommel.
    bow = []
    for i in range(9):
        t = i / 8
        bow.append((0.0, -0.05 - 0.012 * math.sin(t * math.pi), -0.065 + 0.14 * t))
    bow[-1] = (0.0, -0.012, 0.078)
    parts.append(kit.tube("bow", bow, 0.0065, 6, BRASS, caps=True))
    # Grip, wrapped in leather with raised turns.
    grip = kit.lathe("grip", [(0.0, -0.06), (0.017, -0.058), (0.0185, -0.01), (0.017, 0.05), (0.0, 0.052)], 12, LEATHER, axis="z")
    parts.append(grip)
    for k in range(6):
        z = -0.045 + k * 0.018
        r = kit.lathe("wrap%d" % k, [(0.0, z - 0.004), (0.0195, z - 0.0035), (0.0195, z + 0.0035), (0.0, z + 0.004)], 12, "6a4028", axis="z")
        kit.noink(r)
        parts.append(r)
    parts.append(kit.ellipsoid("pommel", (0, -0.002, 0.07), (0.021, 0.021, 0.024), BRASS, rings=8, sectors=12))
    return kit.join("cutlass", parts)


def flintlock():
    """A flintlock pistol held at the butt (origin, in the fist), barrel forward along -Z."""
    parts = []
    by = 0.055
    barrel = kit.lathe("barrel", [(0.0, -0.06), (0.017, -0.06), (0.016, -0.3), (0.019, -0.31), (0.019, -0.335), (0.0, -0.335)], 8, "3a3a42", centre=(0, by, 0), axis="z", smooth=False)
    parts.append(barrel)
    parts.append(kit.lathe("bore", [(0.0, -0.3355), (0.008, -0.3355), (0.008, -0.33), (0.0, -0.33)], 10, "121214", centre=(0, by, 0), axis="z"))
    for z in (-0.12, -0.22):
        parts.append(kit.lathe("band", [(0.0, z - 0.006), (0.02, z - 0.006), (0.02, z + 0.006), (0.0, z + 0.006)], 12, BRASS, centre=(0, by - 0.006, 0), axis="z"))
    # Stock: forward under the barrel, then down and back into a curved butt in the fist.
    stock_pts = [(0.0, by - 0.022, -0.28), (0.0, by - 0.024, -0.16), (0.0, by - 0.026, -0.05), (0.0, 0.01, 0.0), (0.0, -0.04, 0.035), (0.0, -0.085, 0.055)]
    stock = kit.tube("stock", stock_pts, [0.012, 0.016, 0.02, 0.024, 0.026, 0.03], 10, WOOD_DARK)
    stock.scale = (0.8, 1.0, 1.0)
    kit.transform_apply(stock)
    parts.append(stock)
    parts.append(kit.ellipsoid("buttcap", (0, -0.1, 0.064), (0.026, 0.024, 0.03), BRASS, rings=8, sectors=10))
    # Lock plate, hammer and frizzen on the right side.
    parts.append(kit.box("lockplate", (0.017, by - 0.01, -0.04), (0.006, 0.03, 0.07), "56565e", bevel=0.003))
    parts.append(kit.tube("cock", [(0.02, by - 0.005, -0.005), (0.022, by + 0.02, -0.01), (0.02, by + 0.032, -0.025)], [0.006, 0.006, 0.005], 6, "56565e"))
    parts.append(kit.box("frizzen", (0.012, by + 0.02, -0.06), (0.012, 0.025, 0.01), "56565e", bevel=0.002))
    # Trigger and its guard.
    parts.append(kit.box("trigger", (0, by - 0.05, -0.04), (0.005, 0.03, 0.008), BRASS, rot=(0.4, 0, 0)))
    guard = [(0.0, by - 0.03, -0.085), (0.0, by - 0.07, -0.07), (0.0, by - 0.078, -0.035), (0.0, by - 0.06, -0.005), (0.0, by - 0.035, 0.005)]
    parts.append(kit.tube("guard", guard, 0.004, 6, BRASS))
    return kit.join("flintlock", parts)


def main(names):
    builders = {
        "supply_barrel": supply_barrel,
        "cutlass": cutlass,
        "flintlock": flintlock,
    }
    for name in names or builders:
        kit.reset()
        builders[name]()
        kit.export(name)


if __name__ == "__main__":
    main(kit.args())

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


def staves(name, height, r_end, r_mid, count, woods, rings=10, thick=0.035, gap=0.006, seed=1, across=3):
    """A barrel body of `count` separate staves, each a curved slab bulging like a real barrel."""
    import bmesh
    rng = random.Random(seed)
    parts = []
    span = 2 * math.pi / count
    for s in range(count):
        bm = bmesh.new()
        a0 = s * span + gap / r_mid / 2
        a1 = (s + 1) * span - gap / r_mid / 2
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


def barrel(name="barrel", height=0.95, r_end=0.33, r_mid=0.4, top=True, hoops=(0.09, 0.25, 0.70, 0.86), seed=1, light=False):
    """A barrel of staves; `light` builds it with fewer faces (for barrels in bigger models)."""
    if light:
        parts = staves(name + "_stave", height, r_end, r_mid, 12, WOODS, rings=6, seed=seed, across=2)
    else:
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


CHESTS = [
    # wood, darker wood, metal, metal shade, trim
    ("8a5a32", "6e4626", "3a2c22", "2a2018", "5a3a22"),
    ("7a4a2a", "5e3820", "c9d2dc", "9aa4b0", "e4ecf2"),
    ("8f2f24", "6e2218", "ffd23a", "d0a020", "ffe680"),
]


def chest(tier):
    """A treasure chest, front toward -Z, on the ground at y = 0 (0.84 wide, 0.62 tall): planked
    box, a domed lid of curved slats, metal bands, corner caps, studs, a lock plate with a
    keyhole and handles on the ends. Tier 0 is plain wood and iron, 1 wood bound in silver,
    2 a red captain's chest bound in gold with a skull on the lid."""
    wood, wood_dark, metal, metal_dark, trim = CHESTS[tier]
    parts = []
    hx, hz = 0.42, 0.28
    body_h = 0.42
    # Body: planks running along, each its own shade.
    for k in range(4):
        y = 0.02 + (k + 0.5) * body_h / 4
        for sz in (1, -1):
            parts.append(kit.box("plank", (0, y, sz * (hz - 0.015)), (2 * hx - 0.02, body_h / 4 - 0.012, 0.035), wood if (k + (sz > 0)) % 2 else wood_dark, bevel=0.005, segments=1))
        for sx in (1, -1):
            parts.append(kit.box("endplank", (sx * (hx - 0.015), y, 0), (0.035, body_h / 4 - 0.012, 2 * hz - 0.02), wood_dark if k % 2 else wood, bevel=0.005, segments=1))
    parts.append(kit.box("core", (0, body_h / 2 + 0.01, 0), (2 * hx - 0.05, body_h, 2 * hz - 0.05), "2a1e16"))
    parts.append(kit.box("bottom", (0, 0.015, 0), (2 * hx + 0.02, 0.03, 2 * hz + 0.02), wood_dark, bevel=0.008))
    # Lid: a half barrel of slats from the back hinge over to the front.
    slats = 7
    lid_r = hz + 0.01
    lid_y = body_h + 0.02
    for k in range(slats):
        a0 = math.pi * k / slats
        a1 = math.pi * (k + 1) / slats
        am = (a0 + a1) / 2
        c = (0, lid_y + math.sin(am) * lid_r * 0.75, math.cos(am) * lid_r)
        w = 2 * lid_r * math.sin((a1 - a0) / 2) * 1.05
        parts.append(kit.box("slat", c, (2 * hx - 0.02, 0.035, w), wood if k % 2 else wood_dark, bevel=0.006, segments=1, rot=(-(am - math.pi / 2), 0, 0)))
    for sx in (1, -1):
        cap = []
        for k in range(9):
            a = math.pi * k / 8
            cap.append((math.cos(a) * lid_r, lid_y + math.sin(a) * lid_r * 0.75))
        parts.append(kit.prism("lidend", [(z, y) for z, y in cap], 0.04, wood_dark, centre=(sx * (hx - 0.02), 0, 0), plane="zy"))
    # Metal: bands over the lid and down the body, corners, lid rim.
    for bx in (-0.26, 0.26):
        band = []
        for k in range(9):
            a = math.pi * k / 8
            band.append((bx, lid_y + math.sin(a) * (lid_r * 0.75 + 0.02), math.cos(a) * (lid_r + 0.02)))
        lb = kit.tube("lidband", band, 0.02, 6, metal, caps=False)
        for v in lb.data.vertices:
            v.co.x = bx + (v.co.x - bx) * 2.2
        parts.append(lb)
        for sz in (1, -1):
            parts.append(kit.box("band", (bx, body_h / 2 + 0.02, sz * (hz + 0.005)), (0.07, body_h, 0.015), metal, bevel=0.004))
        parts.append(kit.box("bandbottom", (bx, 0.03, 0), (0.07, 0.015, 2 * hz + 0.02), metal))
    parts.append(kit.box("rim", (0, lid_y, 0), (2 * hx + 0.03, 0.04, 2 * hz + 0.03), metal_dark, bevel=0.006))
    for sx in (1, -1):
        for sz in (1, -1):
            parts.append(kit.box("corner", (sx * (hx - 0.01), body_h / 2 + 0.02, sz * (hz - 0.01)), (0.07, body_h + 0.02, 0.07), metal, bevel=0.01))
    # Studs along the bands.
    for bx in (-0.26, 0.26):
        for y in (0.1, 0.22, 0.34):
            parts.append(kit.noink(kit.ellipsoid("stud", (bx, y, -hz - 0.018), (0.013, 0.013, 0.008), trim, rings=4, sectors=6), 0.3))
    # Lock plate and keyhole on the front, a hasp from the lid.
    parts.append(kit.box("lock", (0, body_h - 0.02, -hz - 0.02), (0.13, 0.15, 0.025), metal, bevel=0.01))
    parts.append(kit.noink(kit.prism("keyhole", [(-0.012, -0.03), (0.012, -0.03), (0.006, 0.0), (0.014, 0.012), (0.0, 0.024), (-0.014, 0.012), (-0.006, 0.0)], 0.01, "121214", centre=(0, body_h - 0.04, -hz - 0.033), plane="xy")))
    parts.append(kit.box("hasp", (0, body_h + 0.05, -hz - 0.02), (0.06, 0.1, 0.02), metal_dark, bevel=0.006))
    # Handles on the ends.
    for sx in (1, -1):
        loop = [(sx * (hx + 0.03), body_h * 0.7 - 0.05 * math.sin(math.pi * t), -0.1 + 0.2 * t) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
        parts.append(kit.tube("handle", loop, 0.012, 5, metal))
        for z in (-0.1, 0.1):
            parts.append(kit.box("handleplate", (sx * (hx + 0.012), body_h * 0.7, z), (0.015, 0.06, 0.04), metal_dark))
    if tier == 2:
        top = lid_y + lid_r * 0.75 + 0.02
        parts.append(kit.ellipsoid("skull", (0, top + 0.03, -0.02), (0.07, 0.04, 0.065), "f4efe2", rings=6, sectors=8))
        for a in (0.7, -0.7):
            parts.append(kit.box("bone", (0, top + 0.01, -0.02), (0.2, 0.025, 0.03), "f4efe2", rot=(0, a, 0)))
        for sx in (1, -1):
            parts.append(kit.noink(kit.ellipsoid("socket", (sx * 0.025, top + 0.05, -0.065), (0.016, 0.012, 0.01), "1a1418", rings=4, sectors=6), 0.2))
    return kit.join("chest_%d" % tier, parts)


def cannonball():
    """An iron cannonball, 0.48 m across, with a faint casting seam."""
    ball = kit.ellipsoid("cannonball", (0, 0, 0), (0.24, 0.24, 0.24), "2b2b30", rings=10, sectors=16)
    seam = [(0.243 * math.cos(2 * math.pi * i / 24), 0.0, 0.243 * math.sin(2 * math.pi * i / 24)) for i in range(25)]
    s = kit.noink(kit.tube("seam", seam, 0.008, 4, "3a3a42", caps=False), 0.0)
    return kit.join("cannonball", [ball, s])


def splinter():
    """A splinter of wood, about 0.45 m: a twisted, jagged shard along Z."""
    pts = [(0.0, 0.0, -0.22), (0.01, 0.01, -0.08), (-0.01, 0.0, 0.06), (0.0, -0.01, 0.22)]
    ob = kit.tube("splinter", pts, [0.004, 0.045, 0.04, 0.006], 4, "b07a42", twist=0.4)
    kit.paint_where(ob, "8a5a30", lambda x, y, z: x > 0.0)
    kit.flat(ob)
    return ob


def wreck_plank():
    """A broken hull plank floating after a sinking: 2.2 m, a jagged snapped end, nails."""
    rng = random.Random(4)
    outline = [(-0.16, -1.1), (0.16, -1.1), (0.16, 0.85), (0.1, 0.95), (0.13, 1.02), (0.04, 1.1), (0.0, 0.98), (-0.06, 1.08), (-0.12, 0.96), (-0.16, 1.0)]
    plank = kit.prism("plank", outline, 0.07, "a0522d", plane="xz", bevel=0.01)
    kit.paint_where(plank, "7d3c20", lambda x, y, z: y < 0.0)
    parts = [plank]
    for z in (-0.95, -0.2, 0.55):
        for x in (-0.08, 0.08):
            parts.append(kit.noink(kit.ellipsoid("nail", (x, 0.037, z), (0.014, 0.008, 0.014), "2e2e36", rings=4, sectors=6), 0.0))
    return kit.join("wreck_plank", parts)


def bucket(name="bucket", water=True):
    """A wooden bucket on a rope handle (the handle's top at the origin, where a fist holds
    it), hanging down: staves, two iron hoops and, when full, the water."""
    top = -0.42
    height = 0.32
    parts = [kit.lathe("bucketbody", [(0.0, 0.0), (0.15, 0.0), (0.2, height), (0.18, height), (0.13, 0.03), (0.0, 0.03)], 14, "8a5a32", centre=(0, top - height, 0))]
    for k in range(14):
        a = 2 * math.pi * k / 14
        parts.append(kit.noink(kit.tube("staveline", [(0.152 * math.cos(a), top - height + 0.01, 0.152 * math.sin(a)), (0.201 * math.cos(a), top - 0.01, 0.201 * math.sin(a))], 0.005, 3, "6a4428"), 0.0))
    for h in (0.07, 0.25):
        r = 0.15 + 0.05 * h / height + 0.006
        parts.append(kit.lathe("hoop", [(r, top - height + h - 0.018), (r, top - height + h + 0.018)], 14, "34303a", caps=False))
    if water:
        parts.append(kit.noink(kit.lathe("water", [(0.0, 0.0), (0.185, 0.0)], 14, "4fb6f5", centre=(0, top - 0.035, 0), caps=False), 0.0))
    handle = [(-0.2, top + 0.01, 0.0), (-0.16, top + 0.25, 0.0), (-0.06, top + 0.4, 0.0), (0.0, top + 0.42, 0.0), (0.06, top + 0.4, 0.0), (0.16, top + 0.25, 0.0), (0.2, top + 0.01, 0.0)]
    parts.append(kit.tube("handle", handle, 0.013, 5, "caa36a", caps=False))
    for sx in (1, -1):
        parts.append(kit.box("lug", (sx * 0.2, top - 0.03, 0), (0.03, 0.08, 0.05), "34303a"))
    return kit.join(name, parts)


def shovel():
    """A spade, the grip at the origin (held in the fist, the shaft running down along -Y) and
    a pointed iron blade at the bottom."""
    parts = [kit.tube("shaft", [(0, 0.12, 0), (0, -0.5, 0), (0, -1.0, 0)], [0.022, 0.024, 0.024], 8, "b07a42")]
    parts.append(kit.tube("tgrip", [(-0.09, 0.14, 0), (0.09, 0.14, 0)], 0.025, 8, "8a5a32"))
    parts.append(kit.lathe("collar", [(0.03, -1.02), (0.036, -0.94)], 8, "4a4a52", caps=False))
    blade = kit.prism("blade", [(-0.13, -1.0), (0.13, -1.0), (0.14, -1.2), (0.08, -1.32), (0.0, -1.38), (-0.08, -1.32), (-0.14, -1.2)], 0.02, "7a7e86", plane="xy", bevel=0.005)
    kit.paint_where(blade, "a8acb4", lambda x, y, z: y < -1.28)
    parts.append(blade)
    return kit.join("shovel", parts)


def hammer():
    """A carpenter's hammer, held at the grip (origin), the head up along +Y."""
    parts = [kit.tube("handle", [(0, -0.08, 0), (0, 0.12, 0), (0, 0.28, 0)], [0.022, 0.02, 0.018], 8, "b07a42")]
    parts.append(kit.box("head", (0, 0.3, 0), (0.05, 0.06, 0.16), "4a4a52", bevel=0.008))
    parts.append(kit.lathe("face", [(0.0, 0.0), (0.032, 0.0), (0.032, 0.03), (0.0, 0.03)], 10, "6a6e76", centre=(0, 0.3, -0.08), axis="z"))
    parts.append(kit.prism("claw", [(0.0, 0.03), (0.0, -0.03), (0.09, -0.05), (0.11, 0.0)], 0.04, "4a4a52", centre=(0, 0.3, 0.06), plane="zy"))
    return kit.join("hammer", parts)


def main(names):
    builders = {
        "fx": lambda: [cannonball(), splinter(), wreck_plank()],
        "tools": lambda: [bucket(), bucket("bucket_empty", water=False), shovel(), hammer()],
        "chests": lambda: [chest(t) for t in range(3)],
        "supply_barrel": supply_barrel,
        "cutlass": cutlass,
        "flintlock": flintlock,
    }
    for name in names or builders:
        kit.reset()
        objs = builders[name]()
        kit.export(name, objs if isinstance(objs, list) else None)


if __name__ == "__main__":
    main(kit.args())

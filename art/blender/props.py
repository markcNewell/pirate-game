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


def flame():
    """A toon camp-fire flame about 0.8 m tall: three licking tongues in orange round a yellow
    heart and a pale core, standing on the origin. Drawn unlit, so its colours are its look."""
    parts = []

    def tongue(name, height, radius, lean, turn, color):
        pts, radii = [], []
        for i in range(9):
            t = i / 8
            a = turn + t * 1.2
            # Bulging low, curling and thinning to a point at the top.
            pts.append((lean * t * t * math.cos(a), height * t, lean * t * t * math.sin(a)))
            radii.append(radius * math.sin(math.pi * min(1.0, 0.15 + t * 0.95)) ** 0.8 * (1 - 0.85 * t) + 0.004)
        return kit.tube(name, pts, radii, 8, color)

    for k in range(3):
        a = 2 * math.pi * k / 3
        parts.append(tongue("outer", 0.75 - 0.12 * k, 0.24, 0.16, a, "ff8a2a"))
    for k in range(2):
        parts.append(tongue("heart", 0.5 - 0.08 * k, 0.17, 0.08, 1.0 + k * 3.1, "ffd040"))
    parts.append(tongue("core", 0.3, 0.1, 0.03, 0.4, "fff4c0"))
    for p in parts:
        kit.noink(p)
    return kit.join("flame", parts)


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


def skull():
    """A skeleton captain's skull, about 0.3 m long: a gold-crowned skull with deep sockets and
    teeth, sitting on its jaw (the game adds a green glow in its sockets)."""
    bone, dark = "f0e8d0", "1a1714"
    parts = []
    cran = kit.ellipsoid("cranium", (0, 0.17, 0.01), (0.12, 0.13, 0.145), bone, rings=12, sectors=16)
    parts.append(cran)
    for sx in (1, -1):
        parts.append(kit.noink(kit.ellipsoid("socket", (sx * 0.05, 0.15, -0.115), (0.037, 0.04, 0.022), dark, rings=6, sectors=10), 0.3))
        parts.append(kit.ellipsoid("cheek", (sx * 0.08, 0.1, -0.09), (0.03, 0.022, 0.03), bone, rings=6, sectors=8))
    parts.append(kit.noink(kit.prism("nose", [(-0.018, 0.0), (0.018, 0.0), (0.0, 0.04)], 0.03, dark, centre=(0, 0.08, -0.13), plane="xy"), 0.3))
    parts.append(kit.box("maxilla", (0, 0.05, -0.09), (0.12, 0.035, 0.07), bone, bevel=0.012))
    for i in range(7):
        parts.append(kit.noink(kit.box("tooth", (-0.045 + i * 0.015, 0.028, -0.122), (0.012, 0.02, 0.01), "fbf8ee", bevel=0.002), 0.2))
    jaw = [(math.sin(math.radians(-70 + 140 * i / 8)) * 0.08, 0.012, -0.02 - math.cos(math.radians(-70 + 140 * i / 8)) * 0.09) for i in range(9)]
    parts.append(kit.tube("jaw", jaw, 0.018, 8, bone))
    # A gold crown band with points, his mark of rank.
    band = kit.lathe("crown", [(0.118, 0.24), (0.124, 0.25), (0.124, 0.28), (0.118, 0.285)], 20, "ffd23a", caps=False, centre=(0, 0, 0.01))
    parts.append(band)
    for k in range(6):
        a = 2 * math.pi * k / 6
        point = kit.prism("point", [(-0.016, 0.0), (0.016, 0.0), (0.0, 0.032)], 0.01, "ffd23a", plane="xy")
        # Each point faces outward from the band.
        kit.place(point, (math.cos(a) * 0.123, 0.278, 0.01 + math.sin(a) * 0.123), (0, math.pi / 2 - a, 0))
        parts.append(point)
    parts.append(kit.ellipsoid("gem", (0, 0.265, -0.13), (0.018, 0.018, 0.01), "9cff8a", rings=4, sectors=8))
    return kit.join("skull", parts)


CRATE_WOOD = ["b8864e", "a87442", "c4955a"]


def cargo_crate(goods):
    """A Merchant Alliance crate (0.8 x 0.6 x 0.6, on the ground at y = 0), planked and battened,
    stencilled with the Alliance's anchor, its lid ajar on what it holds: rum bottles, bolts of
    silk or sacks of spice."""
    name = ["rum", "silk", "spice", "salt", "tea", "hueso"][goods]
    parts = []
    hx, hy, hz = 0.4, 0.3, 0.3
    parts.append(kit.box("core", (0, hy, 0), (2 * hx - 0.04, 2 * hy - 0.02, 2 * hz - 0.04), "4a3020"))
    for k in range(3):
        y = (k + 0.5) * 2 * hy / 3
        for sz in (1, -1):
            parts.append(kit.box("plank", (0, y, sz * (hz - 0.012)), (2 * hx - 0.06, 2 * hy / 3 - 0.014, 0.03), CRATE_WOOD[(k + (sz > 0)) % 3], bevel=0.005))
        for sx in (1, -1):
            parts.append(kit.box("plank", (sx * (hx - 0.012), y, 0), (0.03, 2 * hy / 3 - 0.014, 2 * hz - 0.06), CRATE_WOOD[(k + 1) % 3], bevel=0.005))
    for sx in (1, -1):
        for sz in (1, -1):
            parts.append(kit.box("batten", (sx * (hx - 0.02), hy, sz * (hz - 0.02)), (0.06, 2 * hy, 0.06), "6b4a2c", bevel=0.008))
    # The anchor stencil on the front and back, in Alliance blue.
    for sz in (1, -1):
        z = sz * (hz + 0.004)
        blue = "2c4e8a"
        parts.append(kit.noink(kit.box("shank", (0, 0.32, z), (0.025, 0.24, 0.006), blue), 0.0))
        parts.append(kit.noink(kit.box("stock", (0, 0.42, z), (0.13, 0.025, 0.006), blue), 0.0))
        arc = [(0.1 * math.sin(math.radians(a)), 0.25 - 0.06 * math.cos(math.radians(a)), z) for a in range(-80, 81, 20)]
        parts.append(kit.noink(kit.tube("arms", arc, 0.013, 4, blue), 0.0))
    # Lid: two planks, one pushed aside.
    parts.append(kit.box("lid", (-0.18, 2 * hy + 0.015, 0), (0.42, 0.03, 2 * hz), CRATE_WOOD[0], bevel=0.006))
    # The other half of the lid leans against the crate's side.
    parts.append(kit.box("lid", (hx + 0.07, hy + 0.02, 0.0), (0.03, 0.4, 2 * hz), CRATE_WOOD[2], bevel=0.006, rot=(0.0, 0.0, 0.2)))
    top = 2 * hy
    if goods == 0:
        for k in range(3):
            x = 0.06 + k * 0.1
            parts.append(kit.lathe("bottle", [(0.0, 0.0), (0.04, 0.0), (0.042, 0.12), (0.018, 0.17), (0.016, 0.23), (0.0, 0.235)], 10, "3a6a3a", centre=(x, top - 0.08, -0.1 + 0.08 * (k % 2))))
            parts.append(kit.noink(kit.lathe("cork", [(0.0, 0.0), (0.018, 0.0), (0.018, 0.03), (0.0, 0.03)], 8, "b08a5a", centre=(x, top + 0.15, -0.1 + 0.08 * (k % 2))), 0.3))
        parts.append(kit.noink(kit.ellipsoid("straw", (0.15, top - 0.02, 0.05), (0.16, 0.04, 0.2), "d8c070", rings=4, sectors=8), 0.3))
    elif goods == 1:
        for k, c in enumerate(("c8302a", "6a3aa0", "e0b030")):
            parts.append(kit.tube("bolt", [(0.02, top + 0.01, -0.2 + k * 0.15), (0.36, top + 0.01, -0.2 + k * 0.15)], 0.06, 12, c))
    elif goods == 4:
        # Merrow's finest: paper-wrapped tea bricks in straw, a red seal on each.
        for k in range(4):
            x = 0.0 + 0.14 * (k % 2)
            z = -0.12 + 0.2 * (k // 2)
            parts.append(kit.box("teabrick", (x + 0.05, top + 0.02 + 0.03 * (k % 2), z), (0.12, 0.06, 0.16), "e8dcc0", bevel=0.01))
            parts.append(kit.noink(kit.ellipsoid("seal", (x + 0.05, top + 0.055 + 0.03 * (k % 2), z), (0.025, 0.006, 0.025), "b8302a", rings=3, sectors=8), 0.0))
        parts.append(kit.noink(kit.ellipsoid("straw", (0.2, top - 0.02, 0.0), (0.18, 0.04, 0.24), "d8c070", rings=4, sectors=8), 0.3))
    elif goods == 5:
        # Señor Hueso inside, peeking out from under the lid with a cheerful bony wave.
        bone = "f0e8d0"
        parts.append(kit.ellipsoid("hueso_skull", (0.12, top + 0.06, -0.05), (0.1, 0.11, 0.12), bone, rings=8, sectors=12))
        for sx in (1, -1):
            parts.append(kit.noink(kit.ellipsoid("hueso_eye", (0.12 + sx * 0.04, top + 0.08, -0.16), (0.025, 0.03, 0.01), "1a1714", rings=4, sectors=8), 0.3))
        parts.append(kit.tube("hueso_arm", [(0.25, top - 0.05, 0.1), (0.35, top + 0.15, 0.12), (0.42, top + 0.3, 0.1)], 0.018, 6, bone))
        for k in range(3):
            parts.append(kit.tube("hueso_finger", [(0.42, top + 0.3, 0.1), (0.42 + 0.03 * (k - 1), top + 0.4, 0.1)], 0.008, 4, bone))
        parts.append(kit.tube("ladle", [(0.0, top - 0.05, 0.15), (-0.05, top + 0.25, 0.2)], 0.012, 5, "6a6e76"))
    elif goods == 3:
        # Quill's salt: white sacks tied at the neck, a scoop and spilled grains.
        for k in range(2):
            sack = kit.ellipsoid("saltsack", (0.08 + k * 0.2, top + 0.04, -0.06 + 0.12 * k), (0.12, 0.1, 0.12), "f2efe6", rings=8, sectors=10)
            kit.jitter(sack, 0.008, 7 + k)
            parts.append(sack)
            parts.append(kit.noink(kit.lathe("tie", [(0.03, top + 0.12), (0.03, top + 0.15)], 8, "b08a5a", caps=False, centre=(0.08 + k * 0.2, 0, -0.06 + 0.12 * k)), 0.3))
        parts.append(kit.noink(kit.ellipsoid("spill", (0.3, top + 0.0, 0.18), (0.08, 0.015, 0.06), "ffffff", rings=3, sectors=6), 0.0))
    else:
        for k, c in enumerate(("c9b48a", "b89a6a")):
            sack = kit.ellipsoid("sack", (0.1 + k * 0.17, top + 0.03, -0.05 + 0.1 * k), (0.11, 0.09, 0.12), c, rings=8, sectors=10)
            kit.jitter(sack, 0.008, k)
            parts.append(sack)
            parts.append(kit.noink(kit.ellipsoid("spice", (0.1 + k * 0.17, top + 0.1, -0.05 + 0.1 * k), (0.06, 0.03, 0.06), ("c85a2a", "e0a020")[k], rings=4, sectors=8), 0.3))
    return kit.join("crate_" + name, parts)


def grave():
    """A fresh-dug pirate's grave (about 2 m long along Z, its head at -Z): a heaped mound of
    dark earth with clods round it, stones at the edge and a driftwood cross lashed with rope.
    A green fire stands on the mound's middle in the game."""
    rng = random.Random(7)
    earth, dark = "5a3e26", "3e2a1a"
    mound = kit.ellipsoid("mound", (0, 0.0, 0.05), (0.55, 0.28, 1.05), earth, rings=8, sectors=16)
    kit.jitter(mound, 0.03, 2)
    kit.paint_where(mound, dark, lambda x, y, z: y < 0.06)
    parts = [mound]
    for k in range(9):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.75, 1.05)
        clod = kit.ellipsoid("clod", (math.cos(a) * 0.62 * r, 0.03, math.sin(a) * 1.15 * r), (0.09, 0.06, 0.08), dark if k % 2 else earth, rings=4, sectors=6)
        kit.jitter(clod, 0.015, k)
        parts.append(clod)
    for k in range(5):
        x = rng.uniform(-0.6, 0.6)
        z = rng.choice((-1, 1)) * rng.uniform(0.9, 1.15)
        stone = kit.ellipsoid("stone", (x, 0.04, z), (0.08, 0.06, 0.07), ("8a8a84", "a09a90")[k % 2], rings=4, sectors=6)
        kit.jitter(stone, 0.012, 10 + k)
        parts.append(stone)
    wood = "9a8a70"
    parts.append(kit.tube("post", [(0.0, -0.15, -1.18), (0.02, 0.45, -1.2), (0.0, 0.95, -1.2)], [0.045, 0.04, 0.035], 6, wood, twist=0.3))
    parts.append(kit.tube("arm", [(-0.3, 0.7, -1.19), (0.0, 0.72, -1.21), (0.3, 0.69, -1.2)], [0.032, 0.035, 0.03], 6, wood, twist=0.2))
    for k in range(3):
        y = 0.66 + 0.04 * k
        parts.append(kit.noink(kit.lathe("lash", [(0.05, y), (0.05, y + 0.025)], 8, "c8b080", caps=False, centre=(0, 0, -1.2)), 0.3))
    return kit.join("grave", parts)


def journal():
    """A sailor's journal lying open on the sand (about 0.36 x 0.26): a battered leather cover,
    two fanned page blocks written in faded ink, a red ribbon."""
    leather = "5a2e1a"
    parts = []
    for side in (-1, 1):
        parts.append(kit.box("cover", (side * 0.09, 0.012, 0.0), (0.185, 0.012, 0.26), leather, bevel=0.004, rot=(0, 0, side * -0.06)))
        pages = kit.box("pages", (side * 0.088, 0.032, 0.0), (0.17, 0.026, 0.245), "f2e8cc", bevel=0.006, rot=(0, 0, side * -0.06))
        parts.append(pages)
        for k in range(7):
            z = -0.09 + k * 0.03
            w = 0.12 if k % 3 else 0.08
            parts.append(kit.noink(kit.box("ink", (side * (0.09 + (0.12 - w) * 0.3), 0.0465 + side * -0.0055 * 0.5, z), (w, 0.002, 0.006), "4a3a2e", rot=(0, 0, side * -0.06)), 0.0))
    parts.append(kit.box("spine", (0, 0.01, 0), (0.03, 0.02, 0.262), "4a2414", bevel=0.006))
    parts.append(kit.noink(kit.tube("ribbon", [(0.0, 0.05, 0.1), (0.02, 0.03, 0.16), (0.05, 0.008, 0.2)], 0.008, 4, "b8302a"), 0.4))
    return kit.join("journal", parts)


def rowboat():
    """The Spanish dead's rowing boat, drawn up on a beach (about 3.8 m long along Z, its bow at
    -Z): a thick double-ended hull, dark with a red strake, two thwarts, a pair of oars and a
    pennant at the stern with the Admiral's black raven."""
    hull_dark, hull, strake, wale, inside = "3a2e26", "7a5a3e", "a8322a", "2a2220", "8a6c4c"

    def outer(y):
        # Half-beam and half-length of the outside of the hull at height y (0 keel .. 0.5 rim).
        t = y / 0.5
        return 0.1 + 0.52 * math.sin(t * math.pi / 2) ** 0.8, 1.3 + 0.6 * math.sin(t * math.pi / 2) ** 0.7

    rings = []
    heights = (0.0, 0.05, 0.1, 0.16, 0.22, 0.28, 0.34, 0.39, 0.43, 0.47, 0.5)
    for y in heights:
        rx, rz = outer(y)
        rings.append((y, rx, rz, 0, 0))
    for y in reversed(heights[2:]):
        rx, rz = outer(y)
        rings.append((y, max(0.05, rx - 0.05), rz - 0.06, 0, 0))
    body = kit.loft("hull", rings, hull, sides=32, power=2.0)

    def inner(x, y, z):
        rx, rz = outer(y)
        return (x / rx) ** 2 + (z / rz) ** 2 < 0.93
    kit.paint_where(body, hull_dark, lambda x, y, z: y < 0.13 and not inner(x, y, z))
    kit.paint_where(body, strake, lambda x, y, z: 0.37 < y < 0.45 and not inner(x, y, z))
    kit.paint_where(body, wale, lambda x, y, z: y >= 0.45 and not inner(x, y, z))
    kit.paint_where(body, inside, inner)
    parts = [body]
    for z in (-0.55, 0.45):
        parts.append(kit.box("thwart", (0, 0.36, z), (1.0, 0.04, 0.24), "8a6a4a", bevel=0.006))
    for side in (-1, 1):
        oar = [(side * 0.25, 0.14, -1.2), (side * 0.15, 0.3, 0.4), (side * 0.1, 0.42, 1.4)]
        parts.append(kit.tube("oar", oar, [0.028, 0.03, 0.03], 6, "b08a5a"))
        parts.append(kit.prism("blade", [(-0.08, 0.0), (0.08, 0.0), (0.06, -0.5), (-0.06, -0.5)], 0.02, "b08a5a", centre=(side * 0.26, 0.12, -1.2), plane="xz"))
    parts.append(kit.tube("staff", [(0, 0.3, 1.55), (0, 1.3, 1.65)], 0.02, 5, "3a2e26"))
    flag = kit.prism("pennant", [(0.0, 0.0), (0.0, 0.3), (0.45, 0.18), (0.4, 0.15), (0.45, 0.1)], 0.01, "b8302a", centre=(0.02, 1.0, 1.65), plane="xy")
    parts.append(flag)
    raven = kit.noink(kit.prism("raven", [(0.08, 0.08), (0.14, 0.12), (0.2, 0.11), (0.24, 0.14), (0.22, 0.09), (0.28, 0.07), (0.18, 0.06), (0.12, 0.03)], 0.014, "1a1418", centre=(0.02, 1.0, 1.65), plane="xy"), 0.2)
    parts.append(raven)
    return kit.join("rowboat", parts)


def open_grave(name="grave_open", salted=False):
    """An old pirate grave dug open (about 2 m along Z, its head at -Z): a dark pit with the
    spoil heaped beside it and a weathered driftwood cross. Salted, the pit is filled level with
    white salt."""
    rng = random.Random(11 if salted else 5)
    earth, dark = "5a3e26", "2a1c12"
    rim = kit.loft("rim", [(-0.02, 0.62, 1.12, 0, 0), (0.06, 0.6, 1.1, 0, 0), (0.08, 0.5, 0.98, 0, 0), (-0.25, 0.42, 0.88, 0, 0)], earth, sides=20, power=2.6, cap_bottom=False, cap_top=True)
    kit.paint_where(rim, dark, lambda x, y, z: y < 0.0)
    parts = [rim]
    if salted:
        salt = kit.loft("salt", [(0.0, 0.48, 0.96, 0, 0), (0.08, 0.4, 0.86, 0, 0), (0.1, 0.25, 0.6, 0, 0)], "f4f1ea", sides=20, power=2.4, cap_bottom=False)
        kit.jitter(salt, 0.01, 3)
        parts.append(salt)
        for k in range(8):
            a = rng.uniform(0, 2 * math.pi)
            parts.append(kit.noink(kit.ellipsoid("grain", (math.cos(a) * 0.7, 0.02, math.sin(a) * 1.2), (0.06, 0.02, 0.06), "e8e4dc", rings=3, sectors=6), 0.0))
    spoil = kit.ellipsoid("spoil", (0.95, 0.02, 0.1), (0.42, 0.24, 0.85), earth, rings=6, sectors=12)
    kit.jitter(spoil, 0.035, 4)
    parts.append(spoil)
    for k in range(5):
        clod = kit.ellipsoid("clod", (rng.uniform(0.6, 1.3), 0.03, rng.uniform(-1.0, 1.0)), (0.08, 0.05, 0.07), dark, rings=4, sectors=6)
        kit.jitter(clod, 0.012, 20 + k)
        parts.append(clod)
    wood = "8a7a62"
    parts.append(kit.tube("post", [(0.0, -0.15, -1.25), (0.03, 0.4, -1.27), (0.05, 0.85, -1.25)], [0.045, 0.04, 0.035], 6, wood, twist=0.3))
    parts.append(kit.tube("arm", [(-0.28, 0.62, -1.24), (0.02, 0.66, -1.27), (0.3, 0.6, -1.25)], [0.03, 0.034, 0.028], 6, wood, twist=0.2))
    return kit.join(name, parts)


def keg():
    """A Spanish powder keg (0.7 m tall): dark staves, red bands and a white skull stencilled on
    its side; a fuse poking from the bung."""
    body = barrel("keg_body", height=0.7, r_end=0.24, r_mid=0.29, hoops=(0.07, 0.63), seed=8)
    parts = [body]
    for h in (0.3, 0.42):
        parts.append(kit.lathe("band", [(0.292, h), (0.292, h + 0.05)], 16, "b8302a", caps=False))
    parts.append(kit.noink(kit.ellipsoid("stencil", (0, 0.36, -0.292), (0.07, 0.07, 0.006), "f2ece0", rings=4, sectors=8), 0.0))
    for sx in (1, -1):
        parts.append(kit.noink(kit.box("stencilbone", (0, 0.27, -0.292), (0.16, 0.02, 0.006), "f2ece0", rot=(0, 0, sx * 0.6)), 0.0))
    parts.append(kit.tube("fuse", [(0.08, 0.7, 0.0), (0.12, 0.8, 0.02), (0.1, 0.88, 0.06)], 0.012, 4, "c8b080"))
    return kit.join("keg", parts)


def powder_store():
    """The Spanish powder store on Cutlass Cay: two big grey rocks leaning together like old
    friends (Jonah's landmark), a patched sailcloth tied between them over crates and coils of
    fuse. The kegs are separate (they blow up)."""
    parts = []
    # Two boulders leaning in until their tops nearly touch.
    for sx in (1, -1):
        rock = kit.ellipsoid("bigrock", (0.0, 1.1, 0.0), (0.85, 1.35, 0.95), "8a8a84", rings=9, sectors=12)
        kit.jitter(rock, 0.12, 30 + sx)
        rock.rotation_euler = (0, 0, sx * 0.42)
        kit.transform_apply(rock)
        rock.location = (sx * 1.55, 0.0, 0.0)
        kit.transform_apply(rock)
        kit.paint_where(rock, "6e6e68", lambda x, y, z: y < 0.45)
        kit.paint_where(rock, "6a8a4a", lambda x, y, z: y > 2.05)
        parts.append(rock)
    # A sailcloth from between their tops down to the sand behind: a lean-to over the powder.
    rows = []
    for k in range(6):
        t = k / 5
        row = []
        for i in range(9):
            u = i / 8
            x = -1.15 + 2.3 * u
            sag = 0.18 * math.sin(math.pi * u) * math.sin(math.pi * t)
            row.append((x, 2.0 * (1.0 - t) + 0.05 - sag, -0.3 + 2.4 * t))
        rows.append(row)
    cloth = kit.grid_surface("sailcloth", rows, "c8b890")
    kit.orient(cloth, lambda x, y, z: (0, 1, 0))
    sol = cloth.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.02
    kit.apply_all(cloth)
    kit.paint_where(cloth, "a89a70", lambda x, y, z: abs(x - 0.3) < 0.25 and 0.6 < z < 1.2)
    parts.append(cloth)
    for sx in (1, -1):
        parts.append(kit.tube("peg_rope", [(sx * 1.15, 0.05, 2.1), (sx * 1.4, 0.0, 2.5)], 0.01, 4, "c8b080"))
    for x, z in ((-0.5, 1.1), (0.45, 1.3)):
        parts.append(kit.box("crate", (x, 0.25, z), (0.6, 0.5, 0.5), "a87442", bevel=0.02))
    for k in range(2):
        coil = [(0.35 * math.cos(a / 4.0) + 0.0, 0.05 + 0.02 * k, 0.35 * math.sin(a / 4.0) - 0.6) for a in range(26)]
        parts.append(kit.tube("coil", coil, 0.025, 5, "c8b080", caps=False))
    return kit.join("powder_store", parts)


def bonfire():
    """The dig camp's bonfire (the flame is the game's): a ring of stones round a stack of logs,
    ash and embers, 2.4 m across."""
    rng = random.Random(3)
    parts = []
    for k in range(12):
        a = 2 * math.pi * k / 12
        st = kit.ellipsoid("stone", (math.cos(a) * 1.2, 0.08, math.sin(a) * 1.2), (0.22, 0.16, 0.18), ("7a7a74", "8e8a80")[k % 2], rings=5, sectors=8)
        kit.jitter(st, 0.02, k)
        parts.append(st)
    parts.append(kit.noink(kit.lathe("ash", [(0.0, 0.02), (1.0, 0.02), (1.05, 0.0)], 18, "3a3634"), 0.3))
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-0.2, 0.2)
        parts.append(kit.tube("log", [(math.cos(a) * 0.85, 0.08, math.sin(a) * 0.85), (math.cos(a) * 0.1, 0.75, math.sin(a) * 0.1)], [0.1, 0.07], 7, ("4a3220", "3a2818")[k % 2]))
    for k in range(6):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.2, 0.8)
        parts.append(kit.noink(kit.ellipsoid("ember", (math.cos(a) * r, 0.05, math.sin(a) * r), (0.06, 0.03, 0.05), "7dff8a", rings=3, sectors=6), 0.0))
    return kit.join("bonfire", parts)


def dig_camp():
    """The Spanish dig camp round its bonfire (centred on it, ~16 m across): a palisade of
    sharpened stakes with a gap for a gate, two tents, a rack of spades and the Admiral's flag."""
    rng = random.Random(9)
    parts = []
    for k in range(44):
        a = 2 * math.pi * k / 48 + 0.35
        r = 7.6 + rng.uniform(-0.1, 0.1)
        h = 2.2 + rng.uniform(-0.25, 0.25)
        x, z = math.cos(a) * r, math.sin(a) * r
        parts.append(kit.tube("stake", [(x, -0.2, z), (x, h - 0.3, z), (x * 1.0, h, z)], [0.14, 0.13, 0.01], 6, ("8a6a44", "7a5a38")[k % 2]))
    rail = []
    for k in range(45):
        a = 2 * math.pi * k / 48 + 0.35
        rail.append((math.cos(a) * 7.45, 1.3, math.sin(a) * 7.45))
    parts.append(kit.tube("rail", rail, 0.06, 5, "5a4228", caps=True))
    for (x, z, yaw) in ((-3.5, 2.5, 0.4), (3.2, 3.4, -0.5)):
        tent = tent_shape(1.4, 1.7, 2.6, "c8b48a")
        kit.place(tent, (x, 0, z), (0, yaw, 0))
        parts.append(tent)
    parts.append(kit.box("rack", (4.2, 0.9, -2.6), (1.6, 0.08, 0.08), "6a4a2c"))
    for k in range(4):
        x = 3.6 + 0.4 * k
        parts.append(kit.tube("spade", [(x, 0.0, -2.5), (x, 1.2, -2.66)], 0.025, 5, "b08a5a"))
        parts.append(kit.box("blade", (x, 0.15, -2.48), (0.22, 0.28, 0.02), "7a7e86"))
    parts.append(kit.tube("flagpole", [(-4.8, 0.0, -3.5), (-4.8, 4.8, -3.5)], 0.05, 6, "3a2e26"))
    parts.append(kit.prism("flag", [(0.0, 0.0), (0.0, 0.9), (1.4, 0.75), (1.3, 0.45), (1.4, 0.15)], 0.02, "1a1418", centre=(-4.78, 3.8, -3.5), plane="xy"))
    parts.append(kit.noink(kit.prism("flagraven", [(0.3, 0.3), (0.55, 0.5), (0.8, 0.45), (0.95, 0.6), (0.9, 0.35), (1.05, 0.28), (0.7, 0.25)], 0.024, "e0b04a", centre=(-4.78, 3.8, -3.5), plane="xy"), 0.2))
    return kit.join("dig_camp", parts)


def coconut():
    """Captain Coco: a coconut (0.22 m) with a painted face, two wide eyes and a cheerful
    smile, sitting on its flat side."""
    nut = kit.ellipsoid("coconut", (0, 0.11, 0), (0.1, 0.11, 0.1), "6a4428", rings=8, sectors=12)
    kit.jitter(nut, 0.006, 2)
    kit.paint_where(nut, "4a2e18", lambda x, y, z: y > 0.19)
    parts = [nut]
    for sx in (1, -1):
        parts.append(kit.noink(kit.ellipsoid("eye", (sx * 0.035, 0.14, -0.088), (0.022, 0.026, 0.008), "f8f4ea", rings=4, sectors=8), 0.2))
        parts.append(kit.noink(kit.ellipsoid("pupil", (sx * 0.033, 0.137, -0.096), (0.01, 0.012, 0.004), "1a1714", rings=3, sectors=6), 0.0))
    smile = [(0.045 * math.sin(a), 0.09 - 0.018 * math.cos(a), -0.095) for a in [-1.2 + 0.3 * k for k in range(9)]]
    parts.append(kit.noink(kit.tube("smile", smile, 0.006, 4, "1a1714"), 0.0))
    return kit.join("coconut", parts)


def planks():
    """A bundle of wreck planks (1.6 m) lashed with rope, for Jonah's raft."""
    parts = []
    for k in range(3):
        x = -0.12 + 0.12 * k
        y = 0.05 + 0.02 * (k % 2)
        p = kit.box("plank", (x, y, 0.0), (0.11, 0.04, 1.6 - 0.1 * (k % 2)), ("a0522d", "8a5a30", "b07a42")[k], bevel=0.008)
        kit.paint_where(p, "6e3a20", lambda px, py, pz: pz > 0.7)
        parts.append(p)
    for z in (-0.45, 0.45):
        parts.append(kit.noink(kit.lathe("rope", [(0.2, z - 0.02), (0.2, z + 0.02)], 10, "c8b080", caps=False, centre=(0, 0.06, 0), axis="z"), 0.3))
    return kit.join("planks", parts)


def oil_jar():
    """A stone jar of lamp oil (0.5 m), corked and tied, with a rope handle."""
    jar = kit.lathe("jar", [(0.0, 0.0), (0.14, 0.0), (0.2, 0.15), (0.2, 0.32), (0.1, 0.44), (0.07, 0.48), (0.0, 0.48)], 14, "b89a70")
    kit.paint_where(jar, "8a6a48", lambda x, y, z: 0.2 < y < 0.26)
    cork = kit.lathe("cork", [(0.0, 0.47), (0.065, 0.47), (0.06, 0.53), (0.0, 0.53)], 8, "c8a070")
    handle = kit.tube("handle", [(-0.12, 0.4, 0), (-0.1, 0.56, 0), (0.1, 0.56, 0), (0.12, 0.4, 0)], 0.012, 4, "c8b080", caps=False)
    drip = kit.noink(kit.ellipsoid("drip", (0.17, 0.3, -0.08), (0.03, 0.06, 0.02), "3a2a14", rings=3, sectors=6), 0.0)
    return kit.join("oil_jar", [jar, cork, handle, drip])


def cannon_carriage():
    """A cannon on its wooden carriage (1.6 m), the barrel along -Z: hauled to Merrow's battery."""
    parts = []
    for side in (-1, 1):
        parts.append(kit.prism("cheek", [(-0.55, 0.0), (0.55, 0.0), (0.55, 0.26), (0.2, 0.36), (-0.55, 0.3)], 0.08, "7a5a38", centre=(side * 0.26, 0.12, 0), plane="zy", bevel=0.01))
    parts.append(kit.box("bed", (0, 0.16, 0), (0.5, 0.08, 1.2), "6a4a2c", bevel=0.01))
    for z in (-0.5, 0.45):
        for side in (-1, 1):
            parts.append(kit.lathe("wheel", [(0.0, -0.05), (0.17, -0.05), (0.17, 0.05), (0.0, 0.05)], 12, "5a3e24", centre=(side * 0.34, 0.17, z), axis="x"))
    barrel = kit.lathe("barrel", [(0.0, -1.0), (0.1, -1.0), (0.11, -0.95), (0.09, -0.85), (0.11, 0.2), (0.15, 0.32), (0.13, 0.42), (0.0, 0.45)], 14, "2e2e36", centre=(0, 0.56, 0), axis="z")
    kit.paint_where(barrel, "4a4a52", lambda x, y, z: z > 0.25)
    parts.append(barrel)
    return kit.join("cannon_carriage", parts)


def bronze_piece():
    """A broken piece of a drowned bell: green bronze, crusted with weed, curved like a shell."""
    import bmesh
    piece = kit.lathe("bronze", [(0.12, 0.55), (0.17, 0.42), (0.2, 0.22), (0.24, 0.08), (0.3, 0.0)], 16, "4a8a6a", caps=False)
    bm = bmesh.new()
    bm.from_mesh(piece.data)
    # Keep one jagged slice of the bell's side.
    bm.verts.ensure_lookup_table()
    drop = [v for v in bm.verts if abs(math.atan2(kit.G(v.co)[0], kit.G(v.co)[2])) > 0.75 + 0.1 * math.sin(kit.G(v.co)[1] * 30.0)]
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    bm.to_mesh(piece.data)
    bm.free()
    for v in piece.data.vertices:
        x, y, z = kit.G(v.co)
        v.co = kit.V(x, y, z - 0.2)
    sol = piece.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.03
    kit.apply_all(piece)
    kit.paint_where(piece, "2e6a4a", lambda x, y, z: y < 0.1)
    weed = kit.noink(kit.tube("weed", [(0.05, 0.3, 0.02), (0.08, 0.15, 0.06), (0.06, 0.02, 0.1)], 0.012, 4, "3a6a3a"), 0.2)
    return kit.join("bronze_piece", [piece, weed])


def brine_barrel():
    """A barrel of Black Reef brine, white salt crusted round its hoops and lid."""
    body = barrel("brine_body", height=0.8, r_end=0.28, r_mid=0.34, hoops=(0.08, 0.72), seed=12)
    parts = [body]
    for h in (0.08, 0.72):
        parts.append(kit.noink(kit.lathe("crust", [(0.3, h - 0.03), (0.33, h + 0.03)], 14, "f2efe6", caps=False), 0.3))
    parts.append(kit.noink(kit.ellipsoid("lidsalt", (0.05, 0.81, 0.02), (0.18, 0.025, 0.15), "f2efe6", rings=4, sectors=8), 0.3))
    return kit.join("brine_barrel", parts)


def barricade():
    """A barricade (2 m long along X): sharpened stakes crossed through a log."""
    parts = [kit.tube("log", [(-1.0, 0.45, 0), (1.0, 0.45, 0)], 0.1, 8, "7a5a38")]
    for k in range(6):
        x = -0.85 + 0.34 * k
        for sz in (1, -1):
            parts.append(kit.tube("stake", [(x, 0.0, -sz * 0.45), (x, 0.45, 0.0), (x, 0.95, sz * 0.5)], [0.04, 0.045, 0.005], 6, "a07a4a"))
    return kit.join("barricade", parts)


def hand_lantern():
    """Linnet's lantern, hanging from its bail (the top of the bail at the origin): a squat
    iron cage round green glass."""
    parts = [kit.tube("bail", [(-0.05, -0.12, 0), (0.0, 0.0, 0), (0.05, -0.12, 0)], 0.008, 4, "2e2e36", caps=False)]
    parts.append(kit.lathe("lamptop", [(0.075, -0.14), (0.04, -0.1), (0.0, -0.085)], 8, "2e2e36"))
    parts.append(kit.lathe("lampbase", [(0.0, -0.33), (0.07, -0.33), (0.07, -0.3), (0.0, -0.3)], 8, "2e2e36"))
    parts.append(kit.noink(kit.lathe("lampglass", [(0.055, -0.3), (0.062, -0.22), (0.055, -0.14)], 8, "c8ffb8", caps=False), 0.0))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        parts.append(kit.box("lampbar", (math.cos(a) * 0.06, -0.22, math.sin(a) * 0.06), (0.012, 0.17, 0.012), "2e2e36"))
    return kit.join("hand_lantern", parts)


def tent_shape(half_w, h, length, color):
    """A ridge tent along Z: two sloping canvas sides, closed ends with a dark door at the front
    (-Z), a ridge pole sticking out at both ends."""
    rows = [[(-half_w, 0.0, z), (0.0, h, z), (half_w, 0.0, z)] for z in (-length / 2, length / 2)]
    roof = kit.grid_surface("tent", rows, color)
    kit.orient(roof, lambda x, y, z: (x, 0.3, 0))
    sol = roof.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.02
    kit.apply_all(roof)
    back = kit.prism("tentback", [(-half_w, 0.0), (half_w, 0.0), (0.0, h)], 0.02, kit.shade(color, 0.9) if hasattr(kit, "shade") else color, centre=(0, 0, length / 2), plane="xy")
    door = kit.noink(kit.prism("tentdoor", [(-0.45, 0.0), (0.45, 0.0), (0.0, 1.1)], 0.02, "3a2a1a", centre=(0, 0, -length / 2), plane="xy"), 0.3)
    front = kit.prism("tentfront", [(-half_w, 0.0), (half_w, 0.0), (0.0, h)], 0.02, color, centre=(0, 0, -length / 2 + 0.02), plane="xy")
    pole = kit.tube("ridge", [(0, h + 0.02, -length / 2 - 0.2), (0, h + 0.02, length / 2 + 0.2)], 0.035, 5, "6a4a2c")
    return kit.join("tent", [roof, back, front, door, pole])


def bottle():
    """A green glass bottle bobbing on its side, corked, a rolled letter inside."""
    glass = kit.lathe("bottle", [(0.0, -0.13), (0.055, -0.13), (0.06, 0.05), (0.025, 0.11), (0.022, 0.17), (0.0, 0.17)], 12, "5aa070", axis="z")
    cork = kit.lathe("cork", [(0.0, 0.16), (0.02, 0.16), (0.02, 0.2), (0.0, 0.2)], 8, "b08a5a", axis="z")
    letter = kit.noink(kit.tube("letter", [(0, 0, -0.1), (0, 0, 0.06)], 0.03, 8, "f2e8cc"), 0.3)
    return kit.join("bottle", [glass, cork, letter])


def main(names):
    builders = {
        "story": lambda: [grave(), journal(), rowboat(), open_grave(), open_grave("grave_salted", salted=True), keg(), powder_store(), bonfire(), dig_camp(), bottle(), hand_lantern()],
        "loot": lambda: [skull(), coconut(), planks(), oil_jar(), cannon_carriage(), bronze_piece(), brine_barrel(), barricade()] + [cargo_crate(g) for g in range(6)],
        "fx": lambda: [cannonball(), splinter(), wreck_plank(), flame()],
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

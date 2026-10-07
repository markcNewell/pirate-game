"""Island scenery: palms, rocks, bushes, flowers, grass tufts, the skeleton camp and the beached
wreck. The game places them (game/world/island_mesh.gd); each model here is one variant.

    blender -b --factory-startup --python art/blender/nature.py [-- palm rocks ...]

Palms lean toward +X (the game turns them), rocks sit on their base at y = 0.
"""

import math
import os
import random
import sys

import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
from kit import V  # noqa: E402

TRUNK = "b07a42"
TRUNK_DARK = "8a5a30"
LEAF = "3faa4c"
LEAF_DARK = "2e8a3c"
LEAF_LIGHT = "58b84e"
DRY = "b89a52"
ROCK = "8f8b86"
ROCK_DARK = "6f6b68"
MOSS = "5a9a40"
COCONUT = "6b4128"


def trunk_curve(height, lean, t):
    """A point up the trunk (t 0..1): rising, leaning more toward the top, with a slight S."""
    return Vector((lean * t * t + 0.25 * math.sin(t * math.pi) * lean * 0.3, height * t, 0.0))


def frond(name, root, direction, length, droop, width, seed, dry=False):
    """One palm frond: a midrib arching out and drooping, with a fringe of leaflets on both
    sides (a ribbon with notched edges, folded along the rib)."""
    rng = random.Random(seed)
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 1, 0))).normalized()
    n = 14
    rib = []
    for i in range(n + 1):
        t = i / n
        # Up a little, then out and down.
        p = Vector(root) + d * length * t * (1 - 0.15 * t) + Vector((0, 0.5 * length * t * (1 - t) - droop * t ** 2.2, 0))
        rib.append(p)
    bm = bmesh.new()
    rows = []
    for i, p in enumerate(rib):
        t = i / n
        w = width * math.sin(math.pi * min(1.0, t * 1.15)) * (1 - 0.35 * t)
        # Notch the edge: alternate leaflet tips and gaps between them.
        notch = 0.55 if i % 2 else 1.0
        tip = p + Vector((0, -0.06 * w, 0))
        fold = Vector((0, 0.18 * w, 0))
        left = p + side * w * notch - fold * 0.2 + d * 0.12 * w
        right = p - side * w * notch - fold * 0.2 + d * 0.12 * w
        rows.append([bm.verts.new(V(tuple(left))), bm.verts.new(V(tuple(p + fold * 0.3))), bm.verts.new(V(tuple(right)))])
    for r0, r1 in zip(rows, rows[1:]):
        bm.faces.new((r0[0], r1[0], r1[1], r0[1]))
        bm.faces.new((r0[1], r1[1], r1[2], r0[2]))
    ob = kit.obj_from_bmesh(name, bm)
    sol = ob.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.04
    sol.offset = 0.0
    kit.apply_all(ob)
    kit.paint(ob, DRY if dry else LEAF)
    if not dry:
        # Lighter toward the tips, darker at the rib.
        kit.paint_where(ob, LEAF_LIGHT, lambda x, y, z: (Vector((x, y, z)) - Vector(root)).length > length * 0.7)
        kit.paint_where(ob, LEAF_DARK, lambda x, y, z: (Vector((x, y, z)) - Vector(root)).length < length * 0.25)
    kit.smooth_by_angle(ob, 50)
    rib_ob = kit.tube(name + "_rib", [tuple(p + Vector((0, 0.02, 0))) for p in rib[::2]], [0.05, 0.04, 0.035, 0.03, 0.022, 0.015, 0.008, 0.005][: len(rib[::2])], 5, TRUNK if not dry else DRY)
    kit.noink(rib_ob, 0.3)
    return [ob, rib_ob]


def palm(name, height, lean, seed):
    rng = random.Random(seed)
    parts = []
    segs = 11
    for i in range(segs):
        t0, t1 = i / segs, (i + 1) / segs
        a, b = trunk_curve(height, lean, t0), trunk_curve(height, lean, t1)
        r0 = 0.38 - 0.16 * t0
        r1 = 0.38 - 0.16 * t1
        # Each segment flares at its top like a palm's ringed bark.
        seg = kit.tube("seg", [tuple(a), tuple(a + (b - a) * 0.75), tuple(b)], [r0 * 0.92, r0 * 0.97, r1 * 1.12], 9, TRUNK if i % 2 == 0 else TRUNK_DARK)
        parts.append(seg)
    top = trunk_curve(height, lean, 1.0)
    # The crown: a knob, fronds all round, a few drooping dry ones, coconuts.
    parts.append(kit.ellipsoid("crown", tuple(top + Vector((0, 0.15, 0))), (0.32, 0.38, 0.32), LEAF_DARK, rings=6, sectors=10))
    count = 9
    for k in range(count):
        a = 2 * math.pi * k / count + rng.uniform(-0.15, 0.15)
        d = Vector((math.cos(a), 0, math.sin(a)))
        length = rng.uniform(3.6, 4.4)
        parts += frond("frond%d" % k, top + Vector((0, 0.3, 0)) + d * 0.2, d, length, rng.uniform(2.0, 2.8), 0.75, seed * 31 + k)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.6
        d = Vector((math.cos(a), -1.6, math.sin(a)))
        parts += frond("dry%d" % k, top + Vector((0, 0.05, 0)), d, rng.uniform(1.4, 1.9), 0.4, 0.38, seed * 17 + k, dry=True)
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.3
        parts.append(kit.ellipsoid("coconut", tuple(top + Vector((math.cos(a) * 0.3, -0.25 - 0.1 * (k % 2), math.sin(a) * 0.3))), (0.17, 0.19, 0.17), COCONUT, rings=6, sectors=8))
    return kit.join(name, parts)


def rock(name, size, seed, moss=True, flat=0.75):
    """A faceted rock: a lumpy icosphere, flattened, sitting on y = 0, moss on its top faces."""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    ob = kit.obj_from_bmesh(name, bm)
    # Big lumps pushed out along a few random directions and dents along others, then a little
    # jitter (Blender axes here: z is up).
    dirs = [Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized() for _ in range(5)]
    for v in ob.data.vertices:
        p = v.co.normalized()
        s = 1.0 + sum(0.18 * max(0.0, p.dot(d)) ** 2 for d in dirs[:3]) - sum(0.15 * max(0.0, p.dot(d)) ** 4 for d in dirs[3:])
        v.co = p * s * Vector((1.2, 1.0, flat)) * size
    kit.jitter(ob, 0.04 * size, seed)
    # Sit it on the ground: squash the bottom flat.
    lo = min(v.co.z for v in ob.data.vertices)
    for v in ob.data.vertices:
        v.co.z -= lo
        if v.co.z < 0.15 * size:
            v.co.z *= 0.4
    kit.paint(ob, ROCK)
    for p in ob.data.polygons:
        if (p.index * 7 + seed) % 5 == 0:
            p.material_index = kit._slot(ob, ROCK_DARK)
    if moss:
        for p in ob.data.polygons:
            if p.normal.z > 0.75 and p.center.z > 0.5 * size:
                p.material_index = kit._slot(ob, MOSS)
    kit.flat(ob)
    return ob


def bush(name, size, seed, berries=None):
    rng = random.Random(seed)
    parts = []
    blobs = rng.randint(4, 6)
    for k in range(blobs):
        a = 2 * math.pi * k / blobs + rng.uniform(-0.3, 0.3)
        r = 0.35 * size if k else 0.0
        c = (math.cos(a) * r, 0.42 * size + rng.uniform(-0.05, 0.12) * size + (0.12 * size if k == 0 else 0), math.sin(a) * r)
        rad = size * rng.uniform(0.38, 0.5)
        blob = kit.ellipsoid("blob", c, (rad, rad * 0.82, rad), LEAF_DARK if k % 2 else "3f8a35", rings=7, sectors=10)
        kit.jitter(blob, rad * 0.07, seed + k)
        parts.append(blob)
        # Leaf tips poking out of the blob's surface.
        kit.displace(blob, 0.08 * size, 0.35 * size, seed=seed * 5 + k)
    if berries:
        for j in range(9):
            u = rng.uniform(0, 2 * math.pi)
            w = rng.uniform(0.2, 0.9)
            d = Vector((math.cos(u) * math.sqrt(1 - w * w), w, math.sin(u) * math.sqrt(1 - w * w)))
            c = Vector((0, 0.45 * size, 0)) + d * 0.52 * size
            parts.append(kit.noink(kit.ellipsoid("berry", tuple(c), (0.05 * size,) * 3, berries, rings=4, sectors=6), 0.3))
    return kit.join(name, parts)


def flowers(name, petal, seed):
    rng = random.Random(seed)
    parts = []
    for k in range(6):
        x, z = rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45)
        h = rng.uniform(0.18, 0.32)
        parts.append(kit.tube("stem", [(x, 0.0, z), (x + 0.02, h * 0.6, z), (x, h, z)], 0.012, 4, "2f6b26"))
        for j in range(2):
            a = rng.uniform(0, 2 * math.pi)
            parts.append(kit.noink(kit.ellipsoid("leaf", (x + math.cos(a) * 0.05, h * 0.3, z + math.sin(a) * 0.05), (0.06, 0.012, 0.025), "3f8a35", rings=3, sectors=6), 0.3))
        centre = Vector((x, h + 0.01, z))
        for p in range(5):
            a = 2 * math.pi * p / 5
            pc = centre + Vector((math.cos(a) * 0.045, 0.0, math.sin(a) * 0.045))
            parts.append(kit.noink(kit.ellipsoid("petal", tuple(pc), (0.04, 0.012, 0.03), petal, rings=3, sectors=6), 0.3))
        parts.append(kit.noink(kit.ellipsoid("eye", tuple(centre + Vector((0, 0.01, 0))), (0.022, 0.015, 0.022), "ffd84a" if petal != "ffd84a" else "e07a2a", rings=3, sectors=6), 0.3))
    return kit.join(name, parts)


def tuft(name, seed):
    """A tuft of long grass blades fanning out of the ground."""
    rng = random.Random(seed)
    parts = []
    for k in range(9):
        a = 2 * math.pi * k / 9 + rng.uniform(-0.3, 0.3)
        lean = rng.uniform(0.1, 0.35)
        h = rng.uniform(0.28, 0.5)
        d = Vector((math.cos(a), 0, math.sin(a)))
        base_p = d * 0.05
        mid = base_p + d * lean * 0.4 + Vector((0, h * 0.6, 0))
        tip = base_p + d * lean + Vector((0, h, 0))
        blade = kit.tube("blade", [tuple(base_p), tuple(mid), tuple(tip)], [0.03, 0.022, 0.003], 3, "5aa848" if k % 2 else "6ab854")
        parts.append(kit.noink(blade, 0.0))
    return kit.join(name, parts)


def camp():
    """A skeleton camp, its fire at the origin: a patched canvas tent on poles with guy ropes,
    a ring of stones round charred logs, a cooking pot on a tripod, a crate, a barrel and bones.
    The tent stands 3 m out along +X, its ridge along Z (as the game placed it)."""
    import props
    parts = []
    cloth, cloth_dark = "8a7f6a", "6e6552"
    tent = Vector((3.0, 0, 0))
    for s in (-1.3, 1.3):
        parts.append(kit.tube("pole", [tuple(tent + Vector((0, 0, s))), tuple(tent + Vector((0, 1.9, s)))], 0.055, 6, "5e4630"))
    parts.append(kit.tube("ridge", [tuple(tent + Vector((0, 1.9, -1.45))), tuple(tent + Vector((0, 1.9, 1.45)))], 0.05, 6, "5e4630"))
    for sx in (1, -1):
        rows = []
        for i in range(7):
            z = -1.35 + 2.7 * i / 6
            row = []
            for j in range(5):
                t = j / 4
                # Down from the ridge to the ground, sagging between the poles.
                sag = 0.12 * math.sin(math.pi * i / 6) * math.sin(math.pi * t)
                row.append(tuple(tent + Vector((sx * (0.05 + 1.15 * t), 1.88 - 1.85 * t - sag, z))))
            rows.append(row)
        canvas = kit.grid_surface("canvas", rows, cloth if sx > 0 else cloth_dark)
        sol = canvas.modifiers.new("solid", "SOLIDIFY")
        sol.thickness = 0.03
        kit.apply_all(canvas)
        kit.smooth_by_angle(canvas, 50)
        parts.append(canvas)
        # A patch sewn on, and guy ropes to pegs.
        parts.append(kit.box("patch", tuple(tent + Vector((sx * 0.68, 0.95, 0.4))), (0.04, 0.42, 0.5), "a89878", rot=(0, 0, sx * 0.79)))
        for z in (-1.3, 1.3):
            peg = tent + Vector((sx * 1.9, 0.0, z * 1.25))
            parts.append(kit.tube("guy", [tuple(tent + Vector((0, 1.88, z))), tuple(peg + Vector((0, 0.12, 0)))], 0.012, 4, "caa36a"))
            parts.append(kit.box("peg", tuple(peg + Vector((0, 0.06, 0))), (0.05, 0.14, 0.05), "5e4630"))
    # Fire ring, logs and embers.
    for k in range(9):
        a = 2 * math.pi * k / 9
        s = rock("stone", 0.17 + 0.03 * (k % 3), 50 + k, moss=False)
        kit.place(s, (math.cos(a) * 0.78, -0.03, math.sin(a) * 0.78), (0, a, 0))
        parts.append(s)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        d = Vector((math.cos(a), 0, math.sin(a)))
        parts.append(kit.tube("log", [tuple(-d * 0.5 + Vector((0, 0.1, 0))), tuple(d * 0.4 + Vector((0, 0.22, 0)))], 0.08, 7, "2b2018"))
        parts.append(kit.noink(kit.ellipsoid("ember", tuple(d * 0.42 + Vector((0, 0.23, 0))), (0.06, 0.06, 0.06), "ff7a2a", rings=4, sectors=6), 0.3))
    parts.append(kit.noink(kit.ellipsoid("ash", (0, 0.03, 0), (0.45, 0.04, 0.45), "3a3430", rings=4, sectors=10), 0.2))
    # Tripod and pot over the fire.
    for k in range(3):
        a = 2 * math.pi * k / 3
        parts.append(kit.tube("tripod", [(math.cos(a) * 0.95, 0.0, math.sin(a) * 0.95), (0, 1.35, 0)], 0.03, 5, "4a3424"))
    parts.append(kit.tube("chain", [(0, 1.35, 0), (0, 0.95, 0)], 0.012, 4, "2e2e36"))
    parts.append(kit.lathe("pot", [(0.0, 0.0), (0.18, 0.02), (0.23, 0.12), (0.22, 0.3), (0.19, 0.34), (0.0, 0.34)], 12, "2e2e36", centre=(0, 0.62, 0)))
    # Stores: a crate and a barrel by the tent, bones about.
    crate_at = (2.0, 0.3, 1.9)
    parts.append(kit.box("crate", crate_at, (0.62, 0.6, 0.62), "a87442", bevel=0.02, rot=(0, 0.3, 0)))
    for k in range(3):
        parts.append(kit.box("slat", (crate_at[0], 0.12 + k * 0.19, crate_at[2]), (0.66, 0.05, 0.66), "7a5430", rot=(0, 0.3, 0)))
    b = props.barrel("campbarrel", light=True, seed=6)
    kit.place(b, (3.9, 0, -1.9))
    parts.append(b)
    rng = random.Random(9)
    for k in range(4):
        x, z = rng.uniform(-2.2, 2.2), rng.uniform(-2.2, 2.2)
        if math.hypot(x, z) < 1.1:
            x += 1.5
        a = rng.uniform(0, math.pi)
        d = Vector((math.cos(a), 0, math.sin(a))) * 0.18
        parts.append(kit.tube("bone", [(x - d.x, 0.04, z - d.z), (x + d.x, 0.04, z + d.z)], [0.035, 0.022, 0.035], 6, "e8dcbe"))
    parts.append(kit.ellipsoid("skull", (-1.6, 0.1, 1.3), (0.11, 0.1, 0.12), "e8dcbe", rings=6, sectors=10))
    return kit.join("camp", parts)


def wreck():
    """An old wreck run aground: bare ribs of a hull lying over, a few planks still on, a keel,
    a snapped mast beside it. Origin at the keel's middle, keel along Z, ribs rising in a U
    toward +Y (the game heels it over and buries it in the sand)."""
    rng = random.Random(13)
    parts = []
    wood, dark, grey = "8a6a4a", "5e4630", "9a8a74"
    w, h = 3.3, 3.6
    parts.append(kit.box("keel", (0, 0.1, 0), (0.6, 0.52, 13.6), dark, bevel=0.05))
    for i in range(9):
        z = -6.0 + i * 1.5
        narrow = 1.0 - abs(z) / 12.0
        broken_at = rng.randint(4, 8) if rng.random() < 0.5 else 8
        pts = []
        for k in range(0, 9):
            t = math.pi * k / 8
            if k > broken_at:
                break
            pts.append((w * narrow * math.cos(t), h * (1.0 - math.sin(t)), z))
        rib = kit.tube("rib", pts, [0.17] * (len(pts) - 1) + [0.1], 6, wood if i % 2 else grey)
        parts.append(rib)
        if broken_at < 8:
            tip = Vector(pts[-1])
            for j in range(4):
                parts.append(kit.tube("splinter", [tuple(tip), tuple(tip + Vector((rng.uniform(-0.1, 0.1), rng.uniform(0.1, 0.3), rng.uniform(-0.1, 0.1))))], [0.06, 0.005], 4, wood))
    for j in range(4):
        t = math.pi * (0.6 + j * 0.09)
        p = (w * 0.86 * math.cos(t), h * (1.0 - math.sin(t)), 0.3 * j - 0.4)
        plank = kit.box("plank", p, (0.1, 0.32, 4.6 - j * 0.9), wood if j % 2 else grey, bevel=0.02, rot=(0, 0, t - math.pi / 2))
        parts.append(plank)
    # Barnacles and weed on the low side.
    for k in range(18):
        t = math.pi * rng.uniform(0.55, 0.95)
        z = rng.uniform(-5, 5)
        parts.append(kit.ellipsoid("barnacle", (w * 0.9 * math.cos(t), h * (1 - math.sin(t)) + 0.1, z), (0.07, 0.05, 0.07), "c9c4b0", rings=4, sectors=6))
    return kit.join("wreck", parts)


def mast_log():
    """The wreck's snapped mast, lying along Z from its foot at the origin (9.5 m)."""
    parts = [kit.tube("mast", [(0, 0, 0), (0, 0, 4.8), (0, 0, 9.5)], [0.3, 0.27, 0.24], 9, "5e4630")]
    for z in (1.5, 4.5, 7.0):
        parts.append(kit.lathe("band", [(0.29 - z * 0.006, z - 0.06), (0.29 - z * 0.006, z + 0.06)], 9, "3a3a42", caps=False, axis="z"))
    rng = random.Random(3)
    for k in range(6):
        a = 2 * math.pi * k / 6
        parts.append(kit.tube("splinter", [(math.cos(a) * 0.2, math.sin(a) * 0.2, 9.45), (math.cos(a) * 0.12, math.sin(a) * 0.12, 9.6 + rng.uniform(0.1, 0.4))], [0.07, 0.005], 4, "5e4630"))
    return kit.join("mast_log", parts)


def main(names):
    def palms():
        return [palm("palm_0", 6.5, 1.4, 1), palm("palm_1", 8.0, 2.0, 2), palm("palm_2", 9.5, 2.6, 3)]

    def rocks():
        return [rock("rock_%d" % i, 1.0, 10 + i, flat=[0.75, 0.6, 0.9, 0.7][i]) for i in range(4)]

    def bushes():
        return [bush("bush_0", 1.0, 1), bush("bush_1", 1.0, 2), bush("bush_2", 1.0, 3, berries="d63c3c")]

    def flower_beds():
        return [flowers("flowers_%d" % i, c, 20 + i) for i, c in enumerate(("ff6b6b", "ffd84a", "f2f2ff", "ff9ad5"))]

    builders = {
        "palms": palms,
        "rocks": rocks,
        "bushes": bushes,
        "flowers": flower_beds,
        "tufts": lambda: [tuft("tuft_%d" % i, 40 + i) for i in range(2)],
        "camp": lambda: [camp()],
        "wreck": lambda: [wreck(), mast_log()],
    }
    for name in names or builders:
        kit.reset()
        objs = builders[name]()
        kit.export(name, objs, ao_distance=0.4, ao_strength=0.7)


if __name__ == "__main__":
    main(kit.args())

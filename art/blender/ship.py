"""The galleon: hull, decks, hold, masts and rigging as one static model, plus the parts the game
moves (sails and their yards, the wheel, the capstan, the cannon barrels, the flag) and hole and
patch pieces.

    blender -b --factory-startup --python art/blender/ship.py [-- ship_hull ship_parts ...]

Everything is painted in palette slots (kit.slot), which the game swaps for a crew's colours or
the skeleton ship's. The layout comes from shipshape.py, the game's own numbers.
"""

import math
import os
import random
import sys

import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
import shipshape as S  # noqa: E402
from kit import V  # noqa: E402

slot = kit.slot
ROPE_R = 0.028


def hull_point(z, y, side, out=0.0):
    """A point on the hull side (Godot), pushed `out` metres along its normal."""
    n = S.side_normal(z, y, side)
    w = S.half_width(z, y)
    return (side * w + n[0] * out, y + n[1] * out, z + n[2] * out)


def z_samples(step=0.25, z0=-S.HALF_LENGTH, z1=S.HALF_LENGTH, cuts=()):
    zs = []
    z = z0
    while z < z1 - 1e-6:
        zs.append(z)
        z += step
    zs.append(z1)
    zs += [c for c in cuts if z0 < c < z1]
    zs = sorted(set(round(v, 5) for v in zs))
    return zs


GAP_CUTS = (S.LADDER_Z - S.LADDER_GAP, S.LADDER_Z + S.LADDER_GAP, S.QUARTER_Z)

# Set while building the skeleton ship: its bulwarks are smashed through in places.
WRECK = False
BROKEN = {1: [(-9.0, -7.7), (4.3, 5.4)], -1: [(-10.6, -9.6), (0.9, 1.9), (8.0, 9.2)]}


def rail(z, side):
    """The bulwark's top at z on one side: ShipShape's, or broken down on the skeleton ship."""
    top = S.rail_top(z)
    if WRECK:
        for z0, z1 in BROKEN[side]:
            if z0 <= z <= z1:
                floor = S.QUARTER_Y if z >= S.QUARTER_Z else S.DECK_Y
                return floor + 0.18 + 0.16 * abs(math.sin(z * 23.0)) + 0.25 * max(0.0, 1 - min(z - z0, z1 - z) / 0.3)
    return top


# ---------------------------------------------------------------------------------------------
# Hull


def strakes():
    """The planks of the hull, keel to rail: (y_bottom, y_top, slot, shade)."""
    rows = []
    edges = [S.KEEL_Y, -1.65, -1.1, -0.55, 0.0, 0.15, 0.55, 0.95, 1.35, 1.75, 2.15, 2.5, S.DECK_Y]
    for i, (a, b) in enumerate(zip(edges, edges[1:])):
        if b <= 0.15:
            name = "bottom"
        elif a >= 2.15 and b <= 2.5:
            name = "stripe"
        elif a >= 2.5:
            name = "hull_dark"
        else:
            name = "hull"
        rows.append((a, b, name, 1.0 if i % 2 == 0 else 0.93))
    return rows


def hull_side(side):
    """One side of the hull in strakes, each with grooved edges so the seams read."""
    bm = bmesh.new()
    zs = z_samples(0.25, cuts=GAP_CUTS)
    groove = 0.012
    bands = strakes()
    # The bulwark above the deck: two strakes up to the rail top (which rises at the ends).
    for b in range(2):
        bands.append((("deck", b), None, "rail", 1.0 if b == 0 else 0.94))
    for a, b, name, shade in bands:
        rows = []
        for z in zs:
            if isinstance(a, tuple):
                top = rail(z, side)
                k = a[1]
                y0 = S.DECK_Y + (top - S.DECK_Y) * k / 2
                y1 = S.DECK_Y + (top - S.DECK_Y) * (k + 1) / 2
            else:
                y0, y1 = a, b
            ys = [y0, y0 + min(0.03, (y1 - y0) * 0.3), y1 - min(0.03, (y1 - y0) * 0.3), y1]
            row = []
            for j, y in enumerate(ys):
                inset = -groove if j in (0, 3) else 0.0
                row.append(bm.verts.new(V(hull_point(z, y, side, inset))))
            rows.append(row)
        for r0, r1 in zip(rows, rows[1:]):
            for j in range(3):
                bm.faces.new((r0[j], r1[j], r1[j + 1], r0[j + 1]))
    ob = kit.obj_from_bmesh("hull_side_%d" % side, bm)
    kit.orient(ob, lambda x, y, z: S.side_normal(z, y, side))
    ob.data.materials.clear()
    # Paint by band, looked up from each face's height.
    for poly in ob.data.polygons:
        x, y, z = kit.G(poly.center)
        band = None
        for a, b, name, shade in bands:
            if isinstance(a, tuple):
                top = rail(z, side)
                lo = S.DECK_Y + (top - S.DECK_Y) * a[1] / 2
                hi = S.DECK_Y + (top - S.DECK_Y) * (a[1] + 1) / 2
            else:
                lo, hi = a, b
            if lo - 1e-4 <= y <= hi + 1e-4:
                band = (name, shade)
                break
        if band:
            poly.material_index = kit._slot(ob, slot(band[0]), band[1])
    kit.smooth_by_angle(ob, 35)
    return ob


def hull_ends():
    """The bottom along the keel, the stem at the bow and the flat transom at the stern."""
    parts = []
    # Keel: a timber along the bottom, curving up into the stem at the bow.
    pts = []
    for z in z_samples(1.0, -12.6, S.HALF_LENGTH):
        pts.append((0.0, S.KEEL_Y - 0.08, z))
    stem = []
    for i in range(9):
        t = i / 8
        a = t * math.pi / 2
        stem.append((0.0, S.KEEL_Y - 0.08 + (S.DECK_Y + 0.6 - S.KEEL_Y) * math.sin(a), -12.6 - 0.9 * math.sin(a) * 0.9 - 0.25 * (1 - math.cos(a))))
    keel = kit.tube("keel", list(reversed(stem[1:])) + pts, 0.16, 4, slot("trim"), twist=0.0)
    parts.append(keel)
    # The flat bottom between the two sides along the keel line.
    bm = bmesh.new()
    zs = z_samples(0.5)
    prev = None
    for z in zs:
        w = S.half_width(z, S.KEEL_Y)
        row = (bm.verts.new(V(-w, S.KEEL_Y, z)), bm.verts.new(V(w, S.KEEL_Y, z)))
        if prev:
            bm.faces.new((prev[0], prev[1], row[1], row[0]))
        prev = row
    bottom = kit.obj_from_bmesh("bottom", bm, slot("bottom"))
    parts.append(bottom)
    # The bow: close the narrow gap between the two sides with the stem's planking.
    z = -S.HALF_LENGTH
    bm = bmesh.new()
    ys = [S.KEEL_Y, -1.0, 0.15, 1.0, 2.15, 2.5, S.DECK_Y, S.rail_top(z)]
    prev = None
    for y in ys:
        w = S.half_width(z, y)
        row = (bm.verts.new(V(-w, y, z)), bm.verts.new(V(w, y, z)))
        if prev:
            bm.faces.new((prev[0], prev[1], row[1], row[0]))
        prev = row
    bow = kit.obj_from_bmesh("bow", bm, slot("hull_dark"))
    parts.append(bow)
    # The transom: flat planks across the stern, in bands like the sides.
    z = S.HALF_LENGTH
    for a, b, name, shade in strakes() + [(S.DECK_Y, S.rail_top(z), "hull_dark", 0.9)]:
        bm = bmesh.new()
        w0, w1 = S.half_width(z, a), S.half_width(z, b)
        vs = [bm.verts.new(V(-w0, a, z)), bm.verts.new(V(w0, a, z)), bm.verts.new(V(w1, b, z)), bm.verts.new(V(-w1, b, z))]
        bm.faces.new(vs)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        t = kit.obj_from_bmesh("transom", bm, slot(name), )
        kit.paint(t, slot(name), shade)
        # Face aft.
        for p in t.data.polygons:
            if kit.G(p.normal)[2] < 0:
                p.flip()
        parts.append(t)
    return parts


def wale(y, z0, z1, side, out=0.06, h=0.14, name="hull_dark", shade=0.85):
    """A thick timber along the hull side at height y, from z0 to z1."""
    bm = bmesh.new()
    rows = []
    for z in z_samples(0.25, z0, z1):
        n = Vector(S.side_normal(z, y, side))
        base = Vector(hull_point(z, y, side, -0.01))
        up = Vector((0, 1, 0))
        rows.append([bm.verts.new(V(tuple(base + up * dy + n * dn))) for dy, dn in ((-h / 2, 0), (-h / 2 + 0.02, out), (h / 2 - 0.02, out), (h / 2, 0))])
    for r0, r1 in zip(rows, rows[1:]):
        for j in range(3):
            bm.faces.new((r0[j], r0[j + 1], r1[j + 1], r1[j]))
    for r in (rows[0], rows[-1]):
        bm.faces.new(r)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = kit.obj_from_bmesh("wale", bm)
    kit.paint(ob, slot(name), shade)
    kit.smooth_by_angle(ob, 30)
    return ob


def bulwark_inside(side):
    """The inside of the bulwark (planked, with stanchions) and the cap rail on top."""
    parts = []
    t = S.RAIL_THICKNESS
    bm = bmesh.new()
    zs = z_samples(0.25, -12.4, S.HALF_LENGTH - 0.05, cuts=GAP_CUTS)
    rows = []
    for z in zs:
        w = S.half_width(z, S.DECK_Y)
        floor = S.QUARTER_Y if z >= S.QUARTER_Z else S.DECK_Y
        top = rail(z, side)
        rows.append([bm.verts.new(V(side * (w - t), y, z)) for y in (floor, floor + (top - floor) * 0.5, top)])
    for r0, r1 in zip(rows, rows[1:]):
        for j in range(2):
            bm.faces.new((r0[j], r1[j], r1[j + 1], r0[j + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    inner = kit.obj_from_bmesh("bulwark", bm)
    kit.paint(inner, slot("rail"), 0.86)
    kit.orient(inner, lambda x, y, z: (-side, 0, 0))
    parts.append(inner)
    # Cap rail: a rounded timber along the top, a touch wider than the bulwark.
    bm = bmesh.new()
    rows = []
    for z in zs:
        w = S.half_width(z, S.DECK_Y)
        top = rail(z, side)
        xo, xi = side * (w + 0.04), side * (w - t - 0.04)
        rows.append([bm.verts.new(V(x, y, z)) for x, y in ((xo, top - 0.05), (xo, top + 0.04), ((xo + xi) / 2, top + 0.075), (xi, top + 0.04), (xi, top - 0.05))])
    for r0, r1 in zip(rows, rows[1:]):
        for j in range(4):
            bm.faces.new((r0[j], r1[j], r1[j + 1], r0[j + 1]))
    for r in (rows[0], rows[-1]):
        bm.faces.new(r)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    cap = kit.obj_from_bmesh("caprail", bm)
    kit.paint(cap, slot("hull_dark"))
    kit.smooth_by_angle(cap, 50)
    parts.append(cap)
    # Stanchions: upright timbers inside the bulwark every metre or so.
    z = -11.6
    while z < S.STERN_Z - 0.2:
        if abs(z - S.LADDER_Z) > S.LADDER_GAP + 0.1 and abs(z - S.QUARTER_Z) > 0.2:
            w = S.half_width(z, S.DECK_Y)
            floor = S.QUARTER_Y if z >= S.QUARTER_Z else S.DECK_Y
            top = rail(z, side)
            parts.append(kit.box("stanchion", (side * (w - t - 0.04), (floor + top) / 2, z), (0.08, top - floor, 0.1), slot("rail"), bevel=0.012, segments=1))
        z += 1.05
    return parts


def end_walls():
    """The inside of the bulwark across the bow (behind the beakhead) and across the stern
    above the quarterdeck, so neither end is see-through from on deck."""
    parts = []
    t = S.RAIL_THICKNESS
    for z, floor, face in ((S.BOW_DECK_Z - 0.02, S.DECK_Y, 1), (S.HALF_LENGTH - 0.05, S.QUARTER_Y, -1)):
        w = S.half_width(z, S.DECK_Y) - t
        top = S.rail_top(z)
        wall = kit.box("endwall", (0, (floor + top) / 2, z), (2 * w, top - floor, 0.06), slot("rail"))
        kit.paint(wall, slot("rail"), 0.86)
        parts.append(wall)
        parts.append(kit.box("endcap", (0, top + 0.03, z), (2 * w + 0.2, 0.1, 0.22), slot("hull_dark"), bevel=0.02))
    return parts


def gunport(z, y, side):
    """A closed gunport on the hull: a frame in the stripe colour, a lid with hinges and a ring."""
    n = Vector(S.side_normal(z, y, side))
    at = Vector(hull_point(z, y, side, 0.0))
    rot = (0, math.atan2(-n[2], n[0]) if side > 0 else math.atan2(n[2], -n[0]), 0)
    parts = []
    frame = kit.box("portframe", (0, 0, 0), (0.06, 0.62, 0.74), slot("stripe"), bevel=0.012)
    lid = kit.box("portlid", (side * 0.035, 0, 0), (0.05, 0.5, 0.62), slot("hull_dark"), bevel=0.01)
    hinges = [kit.box("hinge", (side * 0.065, 0.18 - k * 0.36, 0.05), (0.012, 0.05, 0.5), slot("iron")) for k in range(2)]
    ring = kit.lathe("ring", [(0.03, -0.006), (0.042, 0.0), (0.03, 0.006)], 10, slot("iron"), caps=False, centre=(side * 0.07, -0.12, 0.0), axis="x")
    for p in [frame, lid, ring] + hinges:
        kit.place(p, tuple(at), rot)
        parts.append(p)
    return parts


def channels_and_deadeyes(mast, side):
    """A ledge on the hull by each mast, deadeyes on it and iron chainplates down the side;
    the shrouds' feet. Returns the parts and the deadeye tops (where shrouds start)."""
    z0 = S.MAST_Z[mast]
    y = S.DECK_Y + 0.35
    parts, feet = [], []
    zs = [z0 - 1.1, z0 - 0.35, z0 + 0.4, z0 + 1.15]
    span = (zs[0] - 0.4, zs[-1] + 0.4)
    # The channel: a thick plank sticking out from the hull.
    bm = bmesh.new()
    rows = []
    for z in z_samples(0.2, *span):
        base = Vector(hull_point(z, y, side, -0.02))
        n = Vector(S.side_normal(z, y, side))
        n.y = 0
        n.normalize()
        rows.append([bm.verts.new(V(tuple(base + n * o + Vector((0, dy, 0))))) for o, dy in ((0, -0.05), (0.42, -0.05), (0.42, 0.05), (0, 0.05))])
    for r0, r1 in zip(rows, rows[1:]):
        for j in range(4):
            bm.faces.new((r0[j], r0[(j + 1) % 4], r1[(j + 1) % 4], r1[j]))
    for r in (rows[0], rows[-1]):
        bm.faces.new(r)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ch = kit.obj_from_bmesh("channel", bm)
    kit.paint(ch, slot("hull_dark"))
    parts.append(ch)
    for z in zs:
        base = Vector(hull_point(z, y, side, 0.0))
        n = Vector(S.side_normal(z, y, side))
        n.y = 0
        n.normalize()
        c = base + n * 0.3
        dead = kit.lathe("deadeye", [(0.0, -0.06), (0.075, -0.05), (0.085, 0.0), (0.075, 0.05), (0.0, 0.06)], 10, slot("trim"), centre=tuple(c + Vector((0, 0.13, 0))), axis="x")
        parts.append(dead)
        # Chainplate: an iron strap from the deadeye down the hull.
        low = Vector(hull_point(z, y - 1.0, side, 0.02))
        parts.append(kit.tube("chain", [tuple(c + Vector((0, 0.06, 0))), tuple(c - Vector((0, 0.08, 0))), tuple(low)], 0.018, 4, slot("iron")))
        feet.append(c + Vector((0, 0.2, 0)))
    return parts, feet


def rigging(feet, top, ratlines=True):
    """Shrouds from the deadeyes up to the mast, with ratlines across them to climb."""
    parts = []
    # Thin rope reads better with a fine line: full ink would make the rigging a window grid.
    for f in feet:
        parts.append(kit.noink(kit.tube("shroud", [tuple(f), tuple(top)], ROPE_R, 5, slot("rope"), caps=False), 0.45))
    if ratlines and len(feet) > 1:
        h0, h1 = feet[0].y + 0.5, feet[0].y + (top.y - feet[0].y) * 0.9
        y = h0
        while y < h1:
            row = []
            for f in feet:
                t = (y - f.y) / (top.y - f.y)
                row.append(tuple(f + (top - f) * t))
            parts.append(kit.noink(kit.tube("ratline", row, ROPE_R * 0.6, 4, slot("rope"), caps=False), 0.25))
            y += 0.42
    return parts


def mast(m, with_nest, snapped=False):
    z = S.MAST_Z[m]
    h = S.MAST_HEIGHT[m]
    base = S.LOWER_Y
    top = S.DECK_Y + h
    if snapped:
        # Broken off above the highest yard, the stump splintered.
        top = S.DECK_Y + 0.92 * h
    parts = []
    # The lower mast, the top platform, and the topmast above it, tapering all the way.
    lower_top = S.DECK_Y + 0.62 * h
    prof = [(S.MAST_RADIUS, base), (S.MAST_RADIUS, S.DECK_Y + 0.5), (S.MAST_RADIUS * 0.86, lower_top + 0.6)]
    parts.append(kit.lathe("mast", prof, 12, slot("mast"), centre=(0, 0, z)))
    parts.append(kit.lathe("topmast", [(0.24, lower_top - 0.4), (0.2, top - 1.0), (0.15, top)], 10, slot("mast"), centre=(0, 0, z)))
    # Iron bands round the lower mast.
    y = S.DECK_Y + 1.6
    while y < lower_top - 0.3:
        r = S.MAST_RADIUS * (1 - 0.14 * (y - S.DECK_Y) / (lower_top - S.DECK_Y)) + 0.012
        parts.append(kit.lathe("band", [(r, y - 0.05), (r, y + 0.05)], 12, slot("iron"), caps=False, centre=(0, 0, z)))
        y += 1.4
    # Partners: an octagonal collar where the mast goes through the deck.
    parts.append(kit.lathe("partner", [(0.62, S.DECK_Y), (0.6, S.DECK_Y + 0.14), (0.42, S.DECK_Y + 0.2)], 8, slot("hull_dark"), centre=(0, 0, z), smooth=False))
    # The top: a platform with crosstrees.
    parts.append(kit.box("top", (0, lower_top + 0.4, z), (2.4, 0.12, 1.6), slot("hull_dark"), bevel=0.03))
    for dz in (-0.55, 0.55):
        parts.append(kit.box("crosstree", (0, lower_top + 0.26, z + dz), (2.6, 0.14, 0.14), slot("mast"), bevel=0.02))
    # The cap at the masthead and a truck on the very top (or splinters, if snapped).
    if snapped:
        rng = random.Random(m + 11)
        for k in range(7):
            a = 2 * math.pi * k / 7
            r = 0.15
            base_p = (math.cos(a) * r * 0.8, top - 0.05, z + math.sin(a) * r * 0.8)
            tip_p = (math.cos(a) * r * 0.5, top + rng.uniform(0.15, 0.55), z + math.sin(a) * r * 0.5)
            parts.append(kit.tube("splinter", [base_p, tip_p], [0.06, 0.008], 4, slot("mast")))
    else:
        parts.append(kit.lathe("cap", [(0.26, top - 0.25), (0.28, top), (0.0, top + 0.06)], 10, slot("hull_dark"), centre=(0, 0, z)))
    if with_nest:
        nest = S.DECK_Y + 0.72 * h
        parts.append(kit.lathe("nest", [(0.95, nest - 0.05), (1.05, nest + 0.3), (1.18, nest + 1.0), (1.1, nest + 1.0), (0.98, nest + 0.3), (0.0, nest + 0.05)], 16, slot("hull_dark"), centre=(0, 0, z)))
        parts.append(kit.lathe("nestrim", [(1.16, nest + 0.95), (1.24, nest + 0.98), (1.24, nest + 1.08), (1.14, nest + 1.08)], 18, slot("stripe"), centre=(0, 0, z), caps=False))
        for k in range(8):
            a = 2 * math.pi * k / 8
            parts.append(kit.box("nestrib", (math.cos(a) * 1.12, nest + 0.5, z + math.sin(a) * 1.12), (0.06, 0.95, 0.06), slot("mast"), rot=(0, -a, 0)))
    return parts, Vector((0, lower_top + 0.2, z))


def bowsprit():
    root = Vector((0, S.DECK_Y + 0.6, -12.0))
    tip = Vector((0, S.DECK_Y + 3.8, -19.5))
    d = (tip - root)
    parts = [kit.tube("bowsprit", [tuple(root), tuple(root + d * 0.6), tuple(tip)], [0.28, 0.22, 0.13], 10, slot("mast"))]
    for t in (0.35, 0.62, 0.85):
        p = root + d * t
        r = 0.28 - 0.15 * t + 0.015
        parts.append(kit.tube("sprit_band", [tuple(p - d.normalized() * 0.05), tuple(p + d.normalized() * 0.05)], r, 10, slot("iron")))
    return parts, tip


def figurehead():
    """A gilded mermaid under the bowsprit, arms back, looking ahead."""
    gold = slot("gold")
    base = Vector((0, S.DECK_Y - 0.2, -13.35))
    parts = []
    body = [(0, -0.9, 0.25), (0, -0.55, 0.1), (0, -0.15, -0.05), (0, 0.25, -0.1), (0, 0.55, -0.08)]
    parts.append(kit.tube("mer_body", [tuple(base + Vector(p)) for p in body], [0.12, 0.17, 0.2, 0.19, 0.12], 10, gold))
    parts.append(kit.ellipsoid("mer_head", tuple(base + Vector((0, 0.78, -0.12))), (0.15, 0.17, 0.16), gold, rings=8, sectors=12))
    parts.append(kit.tube("mer_hair", [tuple(base + Vector((0, 0.85, -0.05))), tuple(base + Vector((0, 0.7, 0.12))), tuple(base + Vector((0, 0.4, 0.2)))], [0.14, 0.12, 0.06], 8, gold))
    for sx in (1, -1):
        parts.append(kit.tube("mer_arm", [tuple(base + Vector((sx * 0.17, 0.42, -0.08))), tuple(base + Vector((sx * 0.25, 0.2, 0.08))), tuple(base + Vector((sx * 0.15, 0.05, 0.22)))], [0.06, 0.05, 0.045], 8, gold))
    tail = [(0, -0.9, 0.25), (0, -1.25, 0.45), (0, -1.45, 0.75)]
    parts.append(kit.tube("mer_tail", [tuple(base + Vector(p)) for p in tail], [0.12, 0.09, 0.05], 8, gold))
    for sx in (1, -1):
        parts.append(kit.ellipsoid("fluke", tuple(base + Vector((sx * 0.14, -1.5, 0.82))), (0.16, 0.05, 0.1), gold, rings=6, sectors=8))
    # Scroll rails from the bow out to her.
    for sx in (1, -1):
        rail = [(sx * 0.6, S.DECK_Y + 0.3, -12.4), (sx * 0.45, S.DECK_Y + 0.0, -12.9), (sx * 0.2, S.DECK_Y - 0.1, -13.3)]
        parts.append(kit.tube("headrail", rail, 0.06, 6, gold))
    return parts


def anchor(at, side):
    iron = slot("iron")
    parts = []
    top = Vector(at)
    parts.append(kit.tube("shank", [tuple(top), tuple(top + Vector((0, -1.5, 0)))], 0.07, 8, iron))
    parts.append(kit.box("stock", tuple(top + Vector((0, -0.12, 0))), (0.09, 0.09, 0.95), slot("trim"), bevel=0.02))
    ring = []
    for i in range(13):
        a = 2 * math.pi * i / 12
        ring.append(tuple(top + Vector((0, 0.16 + 0.12 * math.sin(a), 0.12 * math.cos(a)))))
    parts.append(kit.tube("ring", ring, 0.025, 6, iron, caps=False))
    arc = []
    for i in range(9):
        a = math.radians(-70 + 140 * i / 8)
        arc.append(tuple(top + Vector((0, -1.5 + 0.45 * (1 - math.cos(a)), 0.5 * math.sin(a)))))
    parts.append(kit.tube("arms", arc, 0.065, 8, iron))
    for s_ in (1, -1):
        tip = top + Vector((0, -1.5 + 0.45 * (1 - math.cos(math.radians(70))), s_ * 0.5 * math.sin(math.radians(70))))
        parts.append(kit.prism("fluke", [(-0.12, -0.14), (0.12, -0.14), (0.0, 0.16)], 0.04, iron, centre=tuple(tip + Vector((0, 0.05, 0))), plane="zy"))
    # The cathead it hangs from, out from the bow.
    cat_root = Vector((side * (S.half_width(at[2], S.DECK_Y) - 0.4), S.DECK_Y + 0.9, at[2]))
    cat_tip = Vector((side * (S.half_width(at[2], S.DECK_Y) + 0.55), S.DECK_Y + 1.05, at[2]))
    parts.append(kit.tube("cathead", [tuple(cat_root), tuple(cat_tip)], 0.1, 6, slot("hull_dark")))
    parts.append(kit.tube("cable", [tuple(cat_tip), tuple(top + Vector((0, 0.2, 0)))], ROPE_R, 5, slot("rope")))
    return parts


def stern():
    """The stern gallery: windows in gilded frames across the transom, carved boards above
    and below them, quarter galleries on each side and the rudder."""
    parts = []
    z = S.HALF_LENGTH
    gold = slot("gold")
    for x in (-1.8, -0.6, 0.6, 1.8):
        parts.append(kit.box("winframe", (x, S.DECK_Y + 0.9, z + 0.05), (0.68, 0.72, 0.08), gold, bevel=0.015))
        parts.append(kit.box("winpane", (x, S.DECK_Y + 0.9, z + 0.08), (0.56, 0.56, 0.04), slot("trim")))
        parts.append(kit.box("winbar", (x, S.DECK_Y + 0.9, z + 0.1), (0.04, 0.56, 0.03), gold))
        parts.append(kit.box("winbar", (x, S.DECK_Y + 0.9, z + 0.1), (0.56, 0.04, 0.03), gold))
    for y, hgt in ((S.DECK_Y + 1.38, 0.18), (S.DECK_Y + 0.42, 0.14)):
        w = S.half_width(z, y) - 0.15
        parts.append(kit.box("sternboard", (0, y, z + 0.05), (2 * w, hgt, 0.1), gold, bevel=0.02))
    # Carved panels on the upper transom, and a taffrail of turned posts along its top.
    top_y = S.rail_top(z)
    # A carved scroll band: a row of arched panels under thin gilt mouldings.
    for x in (-2.1, -1.05, 0.0, 1.05, 2.1):
        if abs(x) < S.half_width(z, S.DECK_Y + 2.0) - 0.5:
            arch = [(x - 0.38, S.DECK_Y + 1.9), (x + 0.38, S.DECK_Y + 1.9)]
            for i in range(9):
                a = math.pi * i / 8
                arch.append((x + 0.38 * math.cos(a), S.DECK_Y + 2.45 + 0.22 * math.sin(a)))
            arch = [arch[0], arch[1]] + arch[2:]
            parts.append(kit.prism("transomarch", [arch[0]] + [arch[1]] + arch[2:], 0.04, slot("trim"), centre=(0, 0, z + 0.02), plane="xy"))
    for y in (S.DECK_Y + 1.78, S.DECK_Y + 2.84):
        w_ = S.half_width(z, y) - 0.2
        parts.append(kit.box("moulding", (0, y, z + 0.035), (2 * w_, 0.07, 0.06), slot("gold"), bevel=0.015))
    w = S.half_width(z, top_y) - 0.1
    n = 11
    for k in range(n):
        x = -w + 2 * w * k / (n - 1)
        parts.append(kit.lathe("taffpost", [(0.035, 0.0), (0.05, 0.08), (0.03, 0.22), (0.05, 0.38), (0.035, 0.45)], 8, slot("rail"), centre=(x, top_y + 0.07, z - 0.08)))
    parts.append(kit.box("taffrail", (0, top_y + 0.55, z - 0.08), (2 * w + 0.12, 0.09, 0.14), slot("hull_dark"), bevel=0.02))
    # The name board (the game letters the name on it) between the windows and the stripe.
    parts.append(kit.box("nameboard", (0, S.DECK_Y + 0.1, z + 0.035), (3.6, 0.5, 0.06), slot("hull_dark"), bevel=0.02))
    # Quarter galleries: little rounded bay windows on each side at the stern, with a roof
    # and a carved skirt below.
    for side in (1, -1):
        zc = 11.7
        y0, y1 = S.DECK_Y + 0.25, S.DECK_Y + 1.35
        rows = []
        bm = bmesh.new()
        prof = [(y0 - 0.35, 0.02), (y0 - 0.05, 0.3), (y0, 0.34), (y1, 0.34), (y1 + 0.05, 0.38), (y1 + 0.3, 0.05)]
        zs_g = [zc - 0.75 + 1.5 * i / 10 for i in range(11)]
        for z in zs_g:
            bulge = math.sin(math.pi * (z - zs_g[0]) / 1.5)
            row = []
            for y, out in prof:
                p = hull_point(z, y, side, -0.03 + out * bulge ** 0.6)
                row.append(bm.verts.new(V(p)))
            rows.append(row)
        for r0, r1 in zip(rows, rows[1:]):
            for j in range(len(prof) - 1):
                bm.faces.new((r0[j], r1[j], r1[j + 1], r0[j + 1]))
        gal = kit.obj_from_bmesh("gallery", bm)
        kit.orient(gal, lambda x, y, z, side=side: (side, 0, 0))
        kit.paint(gal, slot("hull_dark"))
        kit.paint_where(gal, slot("gold"), lambda x, y, z: y > y1 - 0.01 and y < y1 + 0.06)
        kit.paint_where(gal, slot("stripe"), lambda x, y, z: y < y0 + 0.01 and y > y0 - 0.06)
        kit.smooth_by_angle(gal, 40)
        parts.append(gal)
        for dz in (-0.42, 0.0, 0.42):
            z = zc + dz
            bulge = math.sin(math.pi * (z - zs_g[0]) / 1.5) ** 0.6
            p = Vector(hull_point(z, (y0 + y1) / 2, side, -0.03 + 0.34 * bulge + 0.01))
            parts.append(kit.box("galwin", tuple(p), (0.04, 0.6, 0.26), slot("trim")))
            parts.append(kit.box("galframe", tuple(p - Vector((side * 0.01, 0, 0))), (0.04, 0.7, 0.34), slot("gold")))
    # Rudder on the sternpost.
    rud = kit.prism("rudder", [(0.0, S.KEEL_Y), (0.0, 2.6), (0.35, 2.6), (0.9, 0.0), (0.9, S.KEEL_Y)], 0.16, slot("hull_dark"), centre=(0, 0, z), plane="zy", bevel=0.03)
    parts.append(rud)
    for y in (-1.6, -0.4, 0.8, 1.9):
        parts.append(kit.box("pintle", (0, y, z + 0.25), (0.2, 0.08, 0.55), slot("iron"), bevel=0.01))
    # The stern lantern on its bracket (ShipView puts the glowing box in it).
    lamp = Vector((0, S.QUARTER_Y + S.RAIL_HEIGHT, S.STERN_Z + 0.2))
    parts.append(kit.tube("lampost", [tuple(lamp), tuple(lamp + Vector((0, 0.95, 0)))], 0.06, 8, slot("trim")))
    parts.append(kit.lathe("lampbase", [(0.0, 0.0), (0.24, 0.0), (0.2, 0.08), (0.0, 0.08)], 8, gold, centre=tuple(lamp + Vector((0, 0.86, 0)))))
    parts.append(kit.lathe("lamptop", [(0.22, 0.0), (0.12, 0.2), (0.04, 0.32), (0.0, 0.34)], 8, gold, centre=tuple(lamp + Vector((0, 1.5, 0)))))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        parts.append(kit.box("lampbar", tuple(lamp + Vector((math.cos(a) * 0.17, 1.18, math.sin(a) * 0.17))), (0.03, 0.62, 0.03), gold))
    return parts


def deck_planks():
    """The main deck and quarterdeck in long planks with grooves and staggered butt joints."""
    parts = []
    t = S.RAIL_THICKNESS
    plank = 0.28
    count = int(math.ceil(S.BEAM / plank))
    for deck_y, z0, z1 in ((S.DECK_Y, S.BOW_DECK_Z - 0.6, S.QUARTER_Z), (S.QUARTER_Y, S.QUARTER_Z, S.STERN_Z + 0.35)):
        zs = z_samples(0.5, z0, z1, cuts=(S.HATCH_Z0, S.HATCH_Z1))
        bm = bmesh.new()
        shades = []
        for p in range(count):
            x0 = -count * plank / 2 + p * plank + 0.006
            x1 = x0 + plank - 0.012
            for za, zb in zip(zs, zs[1:]):
                wa = S.half_width(za, S.DECK_Y) - t
                wb = S.half_width(zb, S.DECK_Y) - t
                pieces = [(x0, x1)]
                if deck_y == S.DECK_Y and S.HATCH_Z0 - 1e-3 <= za and zb <= S.HATCH_Z1 + 1e-3:
                    # Cut round the hatch opening.
                    pieces = [(a, min(b, -S.HATCH_X)) for a, b in pieces if a < -S.HATCH_X] + \
                             [(max(a, S.HATCH_X), b) for a, b in pieces if b > S.HATCH_X]
                for pa, pb in pieces:
                    a0, b0 = max(-wa, pa), min(wa, pb)
                    a1, b1 = max(-wb, pa), min(wb, pb)
                    if b0 <= a0 + 0.005 or b1 <= a1 + 0.005:
                        continue
                    vs = [bm.verts.new(V(a0, deck_y, za)), bm.verts.new(V(b0, deck_y, za)), bm.verts.new(V(b1, deck_y, zb)), bm.verts.new(V(a1, deck_y, zb))]
                    bm.faces.new(vs)
                    # Each plank its own shade, and a butt joint every few metres, staggered.
                    butt = int((za + p * 1.37) / 3.2)
                    shades.append(0.9 + 0.1 * ((p * 7 + butt * 3) % 5) / 4)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = kit.obj_from_bmesh("deck", bm)
        ob.data.materials.clear()
        for i, poly in enumerate(ob.data.polygons):
            poly.material_index = kit._slot(ob, slot("deck"), round(shades[i], 2))
            if kit.G(poly.normal)[1] < 0:
                poly.flip()
        parts.append(ob)
        # A dark caulk layer just below, showing in the grooves.
        bm = bmesh.new()
        for za, zb in zip(zs, zs[1:]):
            wa = S.half_width(za, S.DECK_Y) - t
            wb = S.half_width(zb, S.DECK_Y) - t
            if deck_y == S.DECK_Y and S.HATCH_Z0 - 1e-3 <= za and zb <= S.HATCH_Z1 + 1e-3:
                for sx in (1, -1):
                    vs = [bm.verts.new(V(sx * S.HATCH_X, deck_y - 0.015, za)), bm.verts.new(V(sx * wa, deck_y - 0.015, za)), bm.verts.new(V(sx * wb, deck_y - 0.015, zb)), bm.verts.new(V(sx * S.HATCH_X, deck_y - 0.015, zb))]
                    bm.faces.new(vs)
                continue
            vs = [bm.verts.new(V(-wa, deck_y - 0.015, za)), bm.verts.new(V(wa, deck_y - 0.015, za)), bm.verts.new(V(wb, deck_y - 0.015, zb)), bm.verts.new(V(-wb, deck_y - 0.015, zb))]
            bm.faces.new(vs)
        ob = kit.obj_from_bmesh("caulk", bm, slot("trim"))
        for poly in ob.data.polygons:
            if kit.G(poly.normal)[1] < 0:
                poly.flip()
        kit.noink(ob)
        parts.append(ob)
    return parts


def quarterdeck_front():
    """The bulkhead under the quarterdeck's front edge: a door into the cabin, two windows,
    a gold trim and a balustrade along the edge above, open at the stairs."""
    parts = []
    t = S.RAIL_THICKNESS
    qz = S.QUARTER_Z
    wq = S.half_width(qz, S.DECK_Y) - t
    bm = bmesh.new()
    vs = [bm.verts.new(V(-wq, S.DECK_Y, qz)), bm.verts.new(V(wq, S.DECK_Y, qz)), bm.verts.new(V(wq, S.QUARTER_Y, qz)), bm.verts.new(V(-wq, S.QUARTER_Y, qz))]
    bm.faces.new(vs)
    wall = kit.obj_from_bmesh("bulkhead", bm, slot("hull_dark"))
    for p in wall.data.polygons:
        if kit.G(p.normal)[2] > 0:
            p.flip()
    parts.append(wall)
    # Vertical panelling.
    for k in range(-6, 7):
        x = k * 0.5
        if abs(x) > wq - 0.1:
            continue
        parts.append(kit.box("panel", (x, (S.DECK_Y + S.QUARTER_Y) / 2, qz - 0.02), (0.04, S.QUARTER_Y - S.DECK_Y, 0.03), slot("trim")))
    for sx in (1, -1):
        door_x = sx * 2.0
        parts.append(kit.box("door", (door_x, S.DECK_Y + 0.95, qz - 0.04), (0.9, 1.9, 0.06), slot("rail"), bevel=0.02))
        parts.append(kit.box("doorframe", (door_x, S.DECK_Y + 1.0, qz - 0.03), (1.04, 2.04, 0.04), slot("gold"), bevel=0.01))
        parts.append(kit.ellipsoid("knob", (door_x - sx * 0.3, S.DECK_Y + 0.95, qz - 0.09), (0.035, 0.035, 0.03), slot("gold"), rings=6, sectors=8))
        parts.append(kit.box("cabinwin", (sx * 1.2, S.DECK_Y + 1.35, qz - 0.04), (0.4, 0.4, 0.04), slot("trim")))
        parts.append(kit.box("cabinframe", (sx * 1.2, S.DECK_Y + 1.35, qz - 0.03), (0.5, 0.5, 0.04), slot("gold")))
    parts.append(kit.box("qtrim", (0, S.QUARTER_Y - 0.08, qz - 0.06), (2 * wq, 0.16, 0.12), slot("stripe"), bevel=0.02))
    s = S.STAIR_HALF_WIDTH
    for sx in (1, -1):
        mid = sx * (s + wq) / 2
        parts.append(kit.box("qrail", (mid, S.QUARTER_Y + 0.88, qz + 0.05), (wq - s, 0.09, 0.12), slot("hull_dark"), bevel=0.02))
        n = int((wq - s) / 0.28)
        for k in range(n + 1):
            x = sx * (s + 0.06 + k * (wq - s - 0.12) / max(1, n))
            parts.append(kit.lathe("baluster", [(0.028, 0.0), (0.034, 0.08), (0.02, 0.2), (0.038, 0.42), (0.02, 0.66), (0.03, 0.84)], 8, slot("rail"), centre=(x, S.QUARTER_Y, qz + 0.05)))
    return parts


def stairs():
    parts = []
    n = 6
    rise = (S.QUARTER_Y - S.DECK_Y) / n
    run = (S.QUARTER_Z - S.STAIR_BOTTOM_Z) / n
    w = S.STAIR_HALF_WIDTH
    for i in range(n):
        top = S.DECK_Y + rise * (i + 1)
        z = S.STAIR_BOTTOM_Z + run * (i + 0.5)
        parts.append(kit.box("tread", (0, top - 0.04, z), (2 * w - 0.1, 0.08, run + 0.06), slot("deck"), bevel=0.012))
        parts.append(kit.box("riser", (0, top - rise / 2 - 0.04, z - run / 2 + 0.03), (2 * w - 0.14, rise - 0.08, 0.04), slot("hull_dark")))
    for sx in (1, -1):
        x = sx * (w - 0.05)
        # Stringer and a handrail on turned posts.
        parts.append(kit.prism("stringer", [(S.STAIR_BOTTOM_Z - 0.05, S.DECK_Y), (S.QUARTER_Z, S.QUARTER_Y - 0.25), (S.QUARTER_Z, S.QUARTER_Y + 0.02), (S.STAIR_BOTTOM_Z - 0.05, S.DECK_Y + 0.35)], 0.1, slot("hull_dark"), centre=(x, 0, 0), plane="zy", bevel=0.01))
        posts = [(S.STAIR_BOTTOM_Z + 0.1, S.DECK_Y + rise * 0.5), (S.QUARTER_Z - 0.1, S.QUARTER_Y)]
        for pz, py in posts:
            parts.append(kit.lathe("newel", [(0.06, 0.0), (0.08, 0.1), (0.05, 0.5), (0.08, 0.9), (0.06, 1.0)], 8, slot("rail"), centre=(x, py, pz)))
        parts.append(kit.tube("handrail", [(x, posts[0][1] + 1.0, posts[0][0]), (x, posts[1][1] + 1.0, posts[1][0])], 0.045, 8, slot("hull_dark")))
    return parts


def hatch():
    parts = []
    x = S.HATCH_X
    z0, z1 = S.HATCH_Z0, S.HATCH_Z1
    y = S.DECK_Y + S.COAMING / 2
    t = 0.08
    rim = slot("hull_dark")
    parts.append(kit.box("coaming", (-x - t, y, (z0 + z1) / 2), (2 * t, S.COAMING, z1 - z0 + 4 * t), rim, bevel=0.02))
    parts.append(kit.box("coaming", (x + t, y, (z0 + z1) / 2), (2 * t, S.COAMING, z1 - z0 + 4 * t), rim, bevel=0.02))
    parts.append(kit.box("coaming", (0, y, z0 - t), (2 * x, S.COAMING, 2 * t), rim, bevel=0.02))
    parts.append(kit.box("coaming", (0, y, z1 + t), (2 * x, S.COAMING, 2 * t), rim, bevel=0.02))
    lz = z1 - 0.12
    for lx in (-0.32, 0.32):
        parts.append(kit.tube("ladderrail", [(lx, S.LOWER_Y, lz), (lx, S.DECK_Y + 0.3, lz)], 0.05, 6, slot("mast")))
    ry = S.LOWER_Y + 0.3
    while ry < S.DECK_Y:
        parts.append(kit.box("rung", (0, ry, lz), (0.64, 0.06, 0.07), slot("rope"), bevel=0.01))
        ry += 0.35
    return parts


def side_ladder(side):
    parts = []
    z = S.LADDER_Z
    y = -0.8
    prev = {}
    rails = {-0.38: [], 0.38: []}
    while y <= S.DECK_Y + 0.15:
        for dz in (-0.38, 0.38):
            rails[dz].append((side * (S.half_width(z + dz, y) + 0.12), y, z + dz))
        parts.append(kit.box("step", (side * (S.half_width(z, y) + 0.14), y, z), (0.14, 0.06, 0.82), slot("rope"), bevel=0.012))
        y += 0.35
    for pts in rails.values():
        parts.append(kit.tube("siderail", pts, 0.05, 6, slot("hull_dark")))
    return parts


def cannon_carriage(gun):
    """The fixed part of a deck gun: a wooden carriage with cheeks, an axle and four trucks."""
    parts = []
    side = S.cannon_side(gun)
    px, py, pz = S.cannon_pivot_of(gun)
    deck = S.DECK_Y
    cx = px - side * 0.05
    for dz in (-0.3, 0.3):
        cheek = kit.prism("cheek", [(-0.62, 0.0), (0.62, 0.0), (0.62, 0.55), (0.3, 0.55), (0.25, 0.85), (-0.15, 0.85), (-0.2, 0.55), (-0.62, 0.42)], 0.1, slot("hull_dark"), centre=(0, deck + 0.18, 0), plane="xy", bevel=0.015)
        if side < 0:
            cheek.scale = (-1, 1, 1)
            kit.transform_apply(cheek)
            for p in cheek.data.polygons:
                p.flip()
        kit.place(cheek, (cx, 0, pz + dz))
        parts.append(cheek)
    parts.append(kit.box("bed", (cx, deck + 0.3, pz), (1.1, 0.12, 0.5), slot("hull_dark"), bevel=0.015))
    for dx in (-0.4, 0.4):
        parts.append(kit.tube("axle", [(cx + dx, deck + 0.2, pz - 0.38), (cx + dx, deck + 0.2, pz + 0.38)], 0.05, 6, slot("iron")))
        for dz in (-0.42, 0.42):
            parts.append(kit.lathe("truck", [(0.0, -0.05), (0.2, -0.05), (0.21, 0.0), (0.2, 0.05), (0.0, 0.05)], 12, slot("trim"), centre=(cx + dx, deck + 0.2, pz + dz), axis="z"))
    # The breeching rope from the carriage to the bulwark.
    w = S.half_width(pz, S.DECK_Y) - S.RAIL_THICKNESS
    for dz in (-0.5, 0.5):
        parts.append(kit.tube("breech", [(side * w, deck + 0.6, pz + dz * 1.3), (cx - side * 0.3, deck + 0.45, pz + dz * 0.6), (cx - side * 0.62, deck + 0.4, pz)], ROPE_R, 5, slot("rope")))
    return parts


def shot_rack(gun):
    """Cannonballs in a wooden rack against the bulwark beside each gun."""
    parts = []
    side = S.cannon_side(gun)
    z = S.CANNON_Z[gun // 2] + 0.95
    x = side * (S.half_width(z, S.DECK_Y) - S.RAIL_THICKNESS - 0.22)
    parts.append(kit.box("rack", (x, S.DECK_Y + 0.08, z), (0.3, 0.16, 0.95), slot("hull_dark"), bevel=0.015))
    for k in range(4):
        parts.append(kit.ellipsoid("shot", (x, S.DECK_Y + 0.24, z - 0.33 + k * 0.22), (0.1, 0.1, 0.1), slot("iron"), rings=6, sectors=10))
    return parts


def sail_post_fitting(m):
    """The pin rail by each mast where the sail ropes are worked: two posts, a rail of
    belaying pins and ropes coiled on them."""
    px, py, pz = S.sail_post(m)
    parts = []
    for dx in (-0.3, 0.3):
        parts.append(kit.box("bitt", (px + dx, py + 0.65, pz), (0.16, 1.3, 0.16), slot("hull_dark"), bevel=0.02))
    parts.append(kit.box("pinrail", (px, py + 1.0, pz), (0.85, 0.1, 0.14), slot("mast"), bevel=0.015))
    for k in range(5):
        x = px - 0.32 + k * 0.16
        parts.append(kit.lathe("pin", [(0.0, -0.18), (0.02, -0.16), (0.02, 0.0), (0.035, 0.02), (0.03, 0.12), (0.0, 0.14)], 6, slot("mast"), centre=(x, py + 1.0, pz)))
        coil = []
        for i in range(13):
            a = 2 * math.pi * i / 12
            coil.append((x + 0.035 * math.cos(a), py + 0.82 + 0.13 * math.sin(a), pz + 0.07))
        parts.append(kit.tube("coil", coil, 0.02, 5, slot("rope"), caps=False))
    # Ropes running from the rail up toward the yards.
    for dx in (-0.16, 0.16):
        parts.append(kit.tube("halyard", [(px + dx, py + 1.05, pz), (dx * 0.3, S.DECK_Y + 9.0, S.MAST_Z[m] - 0.5)], ROPE_R * 0.8, 4, slot("rope"), caps=False))
    return parts


def mast_lamp():
    """A lantern on an iron bracket on the main mast (ShipView lights a box inside it)."""
    at = Vector((0.45, S.DECK_Y + 2.4, S.MAST_Z[1] - 0.45))
    parts = [kit.tube("lampbracket", [(0.2, S.DECK_Y + 2.95, S.MAST_Z[1] - 0.2), tuple(at + Vector((0, 0.55, 0)))], 0.025, 5, slot("iron"))]
    parts.append(kit.lathe("lamptop", [(0.21, 0.0), (0.12, 0.13), (0.03, 0.22), (0.0, 0.24)], 8, slot("trim"), centre=tuple(at + Vector((0, 0.18, 0)))))
    parts.append(kit.lathe("lampbase", [(0.0, 0.0), (0.2, 0.0), (0.2, 0.04), (0.0, 0.04)], 8, slot("trim"), centre=tuple(at - Vector((0, 0.22, 0)))))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        parts.append(kit.box("lampbar", tuple(at + Vector((math.cos(a) * 0.16, 0.0, math.sin(a) * 0.16))), (0.025, 0.4, 0.025), slot("trim")))
    return parts


def wheel_stand():
    w = S.WHEEL
    parts = [kit.box("wheelstand", (w[0], w[1] + 0.55, w[2]), (0.45, 1.1, 0.36), slot("hull_dark"), bevel=0.03)]
    parts.append(kit.box("wheelcap", (w[0], w[1] + 1.12, w[2]), (0.55, 0.08, 0.44), slot("stripe"), bevel=0.015))
    # Binnacle beside it: a box with a brass compass dome.
    b = (w[0] + 1.1, w[1], w[2] - 0.3)
    parts.append(kit.box("binnacle", (b[0], b[1] + 0.5, b[2]), (0.45, 1.0, 0.45), slot("hull_dark"), bevel=0.03))
    parts.append(kit.lathe("dome", [(0.18, 0.0), (0.17, 0.08), (0.1, 0.17), (0.0, 0.2)], 12, slot("gold"), centre=(b[0], b[1] + 1.0, b[2])))
    return parts


def map_table():
    t = S.MAP_TABLE
    parts = [kit.box("tabletop", (t[0], t[1] + 0.88, t[2]), (1.25, 0.08, 0.85), slot("mast"), bevel=0.02)]
    for lx in (-0.52, 0.52):
        for lz in (-0.32, 0.32):
            parts.append(kit.lathe("leg", [(0.05, 0.0), (0.07, 0.1), (0.04, 0.4), (0.06, 0.82), (0.05, 0.84)], 8, slot("hull_dark"), centre=(t[0] + lx, t[1], t[2] + lz)))
    chart = kit.box("chart", (t[0], t[1] + 0.93, t[2]), (0.84, 0.012, 0.6), "f2e2b8", rot=(0, 0.15, 0))
    parts.append(chart)
    for a in (0.7, -0.7):
        parts.append(kit.noink(kit.box("x", (t[0] + 0.12, t[1] + 0.94, t[2] + 0.05), (0.18, 0.006, 0.036), "c8302a", rot=(0, a, 0))))
    parts.append(kit.lathe("candle", [(0.04, 0.0), (0.04, 0.16), (0.0, 0.17)], 8, "f4ecd8", centre=(t[0] - 0.42, t[1] + 0.92, t[2] - 0.25)))
    parts.append(kit.lathe("dish", [(0.0, 0.0), (0.08, 0.0), (0.08, 0.02), (0.0, 0.02)], 10, slot("gold"), centre=(t[0] - 0.42, t[1] + 0.92, t[2] - 0.25)))
    parts.append(kit.lathe("spyglass", [(0.03, -0.25), (0.035, 0.0), (0.04, 0.2)], 8, slot("gold"), centre=(t[0] + 0.3, t[1] + 0.96, t[2] - 0.2), axis="x"))
    return parts


def clutter():
    import props
    parts = []
    for centre, half, kind in S.CLUTTER:
        if kind == "barrel":
            b = props.barrel("deckbarrel", height=half[1] * 2, r_end=half[0] * 0.85, r_mid=half[0], hoops=(0.08, 0.22, 0.65, 0.8), light=True)
            kit.place(b, (centre[0], centre[1] - half[1], centre[2]))
            parts.append(b)
        elif kind == "crate":
            parts += crate(centre, half)
        else:
            parts.append(rope_coil(centre, half[0]))
    return parts


def crate(centre, half):
    parts = []
    cx, cy, cz = centre
    hx, hy, hz = half
    parts.append(kit.box("cratebody", centre, (2 * hx - 0.04, 2 * hy - 0.04, 2 * hz - 0.04), slot("deck"), bevel=0.01))
    # Planks on each face and corner battens.
    for k in range(3):
        y = cy - hy + (k + 0.5) * 2 * hy / 3
        for sz in (1, -1):
            parts.append(kit.box("plank", (cx, y, cz + sz * (hz - 0.01)), (2 * hx - 0.06, 2 * hy / 3 - 0.02, 0.03), slot("deck"), bevel=0.006))
        for sx in (1, -1):
            parts.append(kit.box("plank", (cx + sx * (hx - 0.01), y, cz), (0.03, 2 * hy / 3 - 0.02, 2 * hz - 0.06), slot("deck"), bevel=0.006))
    for sx in (1, -1):
        for sz in (1, -1):
            parts.append(kit.box("batten", (cx + sx * (hx - 0.02), cy, cz + sz * (hz - 0.02)), (0.07, 2 * hy, 0.07), slot("hull_dark"), bevel=0.008))
    parts.append(kit.box("lid", (cx, cy + hy - 0.015, cz), (2 * hx, 0.04, 2 * hz), slot("deck"), bevel=0.008))
    return parts


def rope_coil(centre, r):
    """A flat coil of rope on deck, spiralling in."""
    pts = []
    turns = 3.2
    n = 64
    for i in range(n + 1):
        t = i / n
        a = 2 * math.pi * turns * t
        rr = r * (1 - 0.6 * t)
        pts.append((centre[0] + rr * math.cos(a), centre[1] - 0.06 + 0.03 * math.sin(t * math.pi), centre[2] + rr * math.sin(a)))
    return kit.tube("coil", pts, 0.045, 6, slot("rope"))


def lower_deck():
    """The hold: plank floor, planked walls on frames, beams and knees under the deck,
    hammocks, stores at the bow and the banana barrel."""
    import props
    parts = []
    fy, top = S.LOWER_Y, S.DECK_Y
    zs = z_samples(0.5, S.LOWER_Z0, S.LOWER_Z1)
    # Floor planks.
    bm = bmesh.new()
    shades = []
    planks = 10
    for za, zb in zip(zs, zs[1:]):
        wa, wb = S.lower_wall_x(za), S.lower_wall_x(zb)
        for p in range(planks):
            u0 = -1 + 2 * p / planks + 0.004
            u1 = -1 + 2 * (p + 1) / planks - 0.004
            vs = [bm.verts.new(V(u0 * wa, fy, za)), bm.verts.new(V(u1 * wa, fy, za)), bm.verts.new(V(u1 * wb, fy, zb)), bm.verts.new(V(u0 * wb, fy, zb))]
            bm.faces.new(vs)
            shades.append(0.86 + 0.14 * ((p * 3 + int(za + p)) % 4) / 3)
    floor = kit.obj_from_bmesh("hold_floor", bm)
    floor.data.materials.clear()
    for i, poly in enumerate(floor.data.polygons):
        poly.material_index = kit._slot(floor, "6b4a32", round(shades[i], 2))
        if kit.G(poly.normal)[1] < 0:
            poly.flip()
    parts.append(floor)
    under = kit.box("hold_floor_under", (0, fy - 0.02, (S.LOWER_Z0 + S.LOWER_Z1) / 2), (2 * S.lower_wall_x(0), 0.02, S.LOWER_Z1 - S.LOWER_Z0), "3a281c")
    kit.noink(under)
    parts.append(under)
    # Walls: planks facing in.
    for side in (1, -1):
        bm = bmesh.new()
        bands = 8
        shades = []
        for za, zb in zip(zs, zs[1:]):
            wa, wb = S.lower_wall_x(za), S.lower_wall_x(zb)
            for k in range(bands):
                y0 = fy + (top - fy) * k / bands
                y1 = fy + (top - fy) * (k + 1) / bands - 0.01
                vs = [bm.verts.new(V(side * wa, y0, za)), bm.verts.new(V(side * wb, y0, zb)), bm.verts.new(V(side * wb, y1, zb)), bm.verts.new(V(side * wa, y1, za))]
                bm.faces.new(vs)
                shades.append(0.82 if k % 2 else 0.9)
        wall = kit.obj_from_bmesh("hold_wall", bm)
        wall.data.materials.clear()
        for i, poly in enumerate(wall.data.polygons):
            poly.material_index = kit._slot(wall, slot("hull_dark"), shades[i])
            if kit.G(poly.normal)[0] * side > 0:
                poly.flip()
        parts.append(wall)
    for end in (S.LOWER_Z0, S.LOWER_Z1):
        w = S.lower_wall_x(end)
        parts.append(kit.box("bulkhead", (0, (fy + top) / 2, end + (0.02 if end < 0 else -0.02)), (2 * w, top - fy, 0.04), slot("hull_dark")))
        for k in range(-4, 5):
            parts.append(kit.box("bh_plank", (k * 0.5, (fy + top) / 2, end + (0.045 if end < 0 else -0.045)), (0.05, top - fy, 0.03), "5a3c24"))
    # Ceiling: the deck's underside.
    for za, zb in zip(zs, zs[1:]):
        over_hatch = S.HATCH_Z0 - 1e-3 <= za and zb <= S.HATCH_Z1 + 1e-3
        wa = S.half_width(za, top) - S.RAIL_THICKNESS
        wb = S.half_width(zb, top) - S.RAIL_THICKNESS
        bm = bmesh.new()
        spans = [(-wa, -S.HATCH_X, -wb, -S.HATCH_X), (S.HATCH_X, wa, S.HATCH_X, wb)] if over_hatch else [(-wa, wa, -wb, wb)]
        for a0, b0, a1, b1 in spans:
            vs = [bm.verts.new(V(a0, top - 0.02, za)), bm.verts.new(V(a1, top - 0.02, zb)), bm.verts.new(V(b1, top - 0.02, zb)), bm.verts.new(V(b0, top - 0.02, za))]
            bm.faces.new(vs)
        c = kit.obj_from_bmesh("ceiling", bm, "4a3424")
        for poly in c.data.polygons:
            if kit.G(poly.normal)[1] > 0:
                poly.flip()
        kit.noink(c)
        parts.append(c)
    # Frames (ribs) against the walls and beams with knees overhead.
    z = S.LOWER_Z0 + 0.8
    while z < S.LOWER_Z1 - 0.3:
        w = S.lower_wall_x(z)
        for side in (1, -1):
            parts.append(kit.box("frame", (side * (w - 0.07), (fy + top) / 2 - 0.1, z), (0.14, top - fy - 0.2, 0.18), "7a5430", bevel=0.02))
        if z < S.HATCH_Z0 - 0.3 or z > S.HATCH_Z1 + 0.3:
            bw = S.half_width(z, top) - S.RAIL_THICKNESS
            parts.append(kit.box("beam", (0, top - 0.17, z), (2 * bw, 0.3, 0.26), "8a6038", bevel=0.02))
            for side in (1, -1):
                parts.append(knee(side, bw, top, z))
        z += 1.6
    # Hammocks slung along the walls.
    for side, z0 in ((-1, -6.4), (1, -6.0), (-1, -3.4)):
        parts += hammock(side, z0, fy + 2.35)
    # Stores at the bow end: barrels and a crate.
    for i, (x, zz) in enumerate(((-0.75, -8.3), (0.05, -8.6), (0.8, -8.1), (-0.9, -7.3))):
        b = props.barrel("store%d" % i, seed=i + 2, light=True)
        kit.place(b, (x, fy, zz))
        parts.append(b)
    parts += crate((-1.1, fy + 0.3, 4.9), (0.35, 0.3, 0.35))
    # The banana barrel: open, heaped with bunches.
    bx, by, bz = S.BANANA_BARREL
    bb = props.barrel("bananabarrel", height=0.8, r_end=0.38, r_mid=0.44, top=False, hoops=(0.08, 0.22, 0.6, 0.72), seed=9, light=True)
    kit.place(bb, (bx, by, bz))
    parts.append(bb)
    parts += banana_heap((bx, by + 0.72, bz), 0.36)
    # Lanterns hanging from the beams (ShipView puts glowing boxes where the old ones were).
    for z in (-7.0, -1.0, 3.5):
        parts += hanging_lantern((0, S.DECK_Y - 0.55, z))
    return parts


def knee(side, bw, top, z):
    """An L-shaped bracket in the corner where a beam meets the hull wall."""
    under = top - 0.32
    shape = [(0.0, 0.0), (0.55, 0.0), (0.55, 0.12), (0.12, 0.55), (0.0, 0.55)]
    outline = [(side * (bw - u), under - v) for u, v in shape]
    if side < 0:
        outline.reverse()
    return kit.prism("knee", outline, 0.16, "7a5430", centre=(0, 0, z), plane="xy", bevel=0.01)


def hammock(side, z0, y):
    parts = []
    length = 1.9
    x_out = side * (S.lower_wall_x(z0) - 0.25)
    x_in = side * (S.lower_wall_x(z0) - 1.0)
    rows = []
    for i in range(9):
        t = i / 8
        z = z0 + t * length
        sag = 0.35 * math.sin(t * math.pi)
        row = []
        for k in range(5):
            u = k / 4
            dip = 0.12 * math.sin(u * math.pi)
            row.append((x_out + (x_in - x_out) * u, y - sag - dip, z))
        rows.append(row)
    cloth = kit.grid_surface("hammock", rows, "e9dcc0")
    sol = cloth.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.03
    kit.apply_all(cloth)
    kit.smooth_by_angle(cloth, 60)
    parts.append(cloth)
    for end in (z0, z0 + length):
        tie = Vector(((x_out + x_in) / 2, y, end))
        parts.append(kit.tube("hamrope", [tuple(tie), tuple(tie + Vector((side * 0.3, 0.45, (end - z0 - length / 2) * 0.25)))], 0.02, 4, slot("rope")))
    return parts


def banana_heap(at, r):
    parts = []
    rng = random.Random(4)
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-0.2, 0.2)
        rr = r * (0.55 if k < 6 else 0.0)
        c = Vector(at) + Vector((math.cos(a) * rr, 0.06 + (0.12 if k == 6 else 0), math.sin(a) * rr))
        # A bunch: curved fingers fanned from a stem.
        for f in range(4):
            fa = a + (f - 1.5) * 0.35
            pts = [tuple(c), tuple(c + Vector((math.cos(fa) * 0.08, 0.05, math.sin(fa) * 0.08))), tuple(c + Vector((math.cos(fa) * 0.16, 0.0, math.sin(fa) * 0.16)))]
            parts.append(kit.tube("banana", pts, [0.025, 0.035, 0.018], 6, "ffd84a"))
        parts.append(kit.noink(kit.ellipsoid("stem", tuple(c), (0.025, 0.025, 0.025), "6a5a2a", rings=4, sectors=6)))
    return parts


def hanging_lantern(at):
    at = Vector(at)
    parts = [kit.tube("lanthang", [tuple(at + Vector((0, 0.55, 0))), tuple(at + Vector((0, 0.2, 0)))], 0.012, 4, slot("iron"))]
    parts.append(kit.lathe("lanttop", [(0.2, 0.0), (0.1, 0.12), (0.0, 0.16)], 8, slot("trim"), centre=tuple(at + Vector((0, 0.17, 0)))))
    parts.append(kit.lathe("lantbase", [(0.0, 0.0), (0.19, 0.0), (0.19, 0.04), (0.0, 0.04)], 8, slot("trim"), centre=tuple(at - Vector((0, 0.21, 0)))))
    return parts


def hull(skeleton=False):
    parts = []
    for side in (1, -1):
        parts.append(hull_side(side))
        parts += bulwark_inside(side)
        for y, z0, z1 in ((0.95, -11.6, 12.9), (2.5, -12.2, 12.9)):
            parts.append(wale(y, z0, z1, side))
        for z in (-8.6, -5.6, 0.4, 3.4, 6.6, 9.6):
            parts += gunport(z, 1.6, side)
        parts += side_ladder(side)
    parts += hull_ends()
    parts += end_walls()
    parts += deck_planks()
    parts += quarterdeck_front()
    parts += stairs()
    parts += hatch()
    tops = []
    for m in range(2):
        mp, top = mast(m, with_nest=(m == 1), snapped=(skeleton and m == 0))
        parts += mp
        tops.append(top)
        for side in (1, -1):
            ch, feet = channels_and_deadeyes(m, side)
            parts += ch
            parts += rigging(feet, top + Vector((side * 0.3, 0, 0)))
    sprit, tip = bowsprit()
    parts += sprit
    head_top = Vector((0, S.DECK_Y + S.MAST_HEIGHT[0] * (0.92 if skeleton else 1.0), S.MAST_Z[0]))
    main_top = Vector((0, S.DECK_Y + S.MAST_HEIGHT[1], S.MAST_Z[1]))
    parts.append(kit.tube("forestay", [tuple(head_top), tuple(tip)], ROPE_R, 5, slot("rope"), caps=False))
    parts.append(kit.tube("mainstay", [tuple(main_top), tuple(tops[0] + Vector((0, 0.3, 0)))], ROPE_R, 5, slot("rope"), caps=False))
    parts.append(kit.tube("backstay", [tuple(main_top), (0, S.QUARTER_Y + 1.0, S.STERN_Z)], ROPE_R, 5, slot("rope"), caps=False))
    parts += figurehead()
    for side in (1, -1):
        parts += anchor((side * (S.half_width(-10.5, 2.0) + 0.2), 2.4, -10.5), side)
    parts += stern()
    for gun in range(S.cannon_count()):
        parts += cannon_carriage(gun)
        parts += shot_rack(gun)
    for m in range(2):
        parts += sail_post_fitting(m)
    parts += mast_lamp()
    parts += wheel_stand()
    parts += map_table()
    parts += clutter()
    parts += lower_deck()
    if skeleton:
        parts += wreckage()
    return kit.join("hull", parts)


def wreckage():
    """What years on the sea bed did to the skeleton ship: holes stove in its sides, barnacles
    and weed along the waterline, and bones about its deck."""
    rng = random.Random(21)
    parts = []
    for side in (1, -1):
        for z, y in ((-6.8, 1.9), (2.6, 1.2), (7.8, 2.0), (-10.2, 1.4)):
            if side < 0:
                z += 1.3
            n = Vector(S.side_normal(z, y, side))
            at = Vector(hull_point(z, y, side, 0.01))
            outline = []
            for i in range(12):
                a = 2 * math.pi * i / 12
                r = rng.uniform(0.18, 0.36)
                outline.append((math.cos(a) * r, math.sin(a) * r))
            hole = kit.prism("stove", [(w_, u) for u, w_ in outline], 0.05, "121614", plane="zy")
            kit.place(hole, tuple(at), (0, math.atan2(-n.z, n.x) if side > 0 else math.atan2(n.z, -n.x), 0))
            kit.noink(hole, 0.4)
            parts.append(hole)
            for i in range(6):
                a = 2 * math.pi * i / 6 + rng.uniform(-0.3, 0.3)
                base_p = at + Vector((0, math.sin(a) * 0.3, math.cos(a) * 0.3))
                tip = base_p - n * rng.uniform(0.0, 0.08) + Vector((0, math.sin(a), math.cos(a))) * rng.uniform(0.08, 0.2)
                parts.append(kit.tube("plankend", [tuple(base_p), tuple(tip)], [0.035, 0.006], 4, slot("hull")))
        # Barnacles in clusters near the waterline, and weed hanging off the lower wale.
        for k in range(26):
            z = rng.uniform(-11.0, 12.0)
            y = rng.uniform(-0.3, 0.45)
            at = hull_point(z, y, side, 0.01)
            parts.append(kit.lathe("barnacle", [(0.0, 0.0), (0.05, 0.0), (0.035, 0.05 * side), (0.015, 0.06 * side), (0.0, 0.055 * side)], 6, "c9c4b0", centre=at, axis="x"))
        for k in range(16):
            z = -10.5 + k * 1.45 + rng.uniform(-0.3, 0.3)
            top_p = Vector(hull_point(z, 0.88, side, 0.07))
            length = rng.uniform(0.5, 1.1)
            pts = [tuple(top_p + Vector((side * 0.02 * math.sin(i), -length * i / 4, 0.05 * math.sin(i * 1.7)))) for i in range(5)]
            parts.append(kit.tube("weed", pts, [0.035, 0.03, 0.025, 0.018, 0.008], 5, "3a6a3a"))
    # A skull and some bones lying about the deck.
    for x, z, a in ((-1.4, -1.8, 0.4), (2.2, 2.0, 1.2), (-2.5, 4.2, 2.0)):
        parts.append(kit.ellipsoid("deckskull", (x, S.DECK_Y + 0.1, z), (0.11, 0.1, 0.12), slot("bone"), rings=6, sectors=10))
        for b in range(2):
            ang = a + b * 1.1
            d = Vector((math.cos(ang), 0, math.sin(ang))) * 0.25
            parts.append(kit.tube("deckbone", [(x + 0.3 - d.x, S.DECK_Y + 0.04, z - d.z), (x + 0.3 + d.x, S.DECK_Y + 0.04, z + d.z)], 0.03, 6, slot("bone")))
    return parts


# ---------------------------------------------------------------------------------------------
# Moving parts


SAIL_BELLY = 0.9
SAIL_THICKNESS = 0.08


def sail(name, width, height, torn=False, seed=0):
    """A sail hanging from its yard at y = 0, bellied toward the bow (-Z): a thin closed slab
    in cloth panels, with a reef band of little ties and a bolt rope round the edge. A torn
    sail (the skeleton ship's) has ragged rents and a frayed foot."""
    cols, rows = (28, 20) if torn else (14, 10)
    bm = bmesh.new()
    front, back = [], []
    rng = random.Random(seed)
    # How much shorter each column's foot is, for a frayed hem.
    fray = [0.0] * (cols + 1)
    if torn:
        for c in range(cols + 1):
            fray[c] = max(0.0, rng.uniform(-0.04, 0.12))
    for r in range(rows + 1):
        v = r / rows
        fr, br = [], []
        for c in range(cols + 1):
            u = c / cols
            vv = v * (1 - fray[c]) if r == rows else v
            belly = SAIL_BELLY * math.sin(math.pi * u) * (0.45 + 0.55 * math.sin(math.pi * min(1.0, vv * 1.1)))
            y = -vv * height + (0.25 * math.sin(math.pi * u) if r == rows else 0.0)
            x = (u - 0.5) * width * (1 - 0.06 * vv)
            fr.append(bm.verts.new(V(x, y, -belly - SAIL_THICKNESS / 2)))
            br.append(bm.verts.new(V(x, y, -belly + SAIL_THICKNESS / 2)))
        front.append(fr)
        back.append(br)
    holes = set()
    if torn:
        blobs = [(rng.uniform(0.12, 0.88), rng.uniform(0.15, 0.85), rng.uniform(0.06, 0.13)) for _ in range(6)]
        for r in range(rows):
            for c in range(cols):
                u, v = (c + 0.5) / cols, (r + 0.5) / rows
                wobble = 0.35 * math.sin(u * 37 + v * 11 + seed) * math.sin(v * 29 - u * 7)
                for bu, bv, br_ in blobs:
                    d = math.hypot((u - bu) * width / height, v - bv) / br_
                    if d + wobble < 1.0:
                        holes.add((c, r))
                # Rents along the foot.
                if r == rows - 1 and math.sin(u * 23 + seed) > 0.55:
                    holes.add((c, r))
    if holes:
        # Fray the rents: nudge every grid point on a hole's edge so the edges wander instead
        # of following the grid. Front and back move together.
        cw, ch = width / cols, height / rows
        for r in range(1, rows):
            for c in range(1, cols):
                around = [(c - 1, r - 1), (c, r - 1), (c - 1, r), (c, r)]
                n_holes = sum(1 for cell in around if cell in holes)
                if 0 < n_holes < 4:
                    dx = rng.uniform(-0.45, 0.45) * cw
                    dy = rng.uniform(-0.45, 0.45) * ch
                    for grid in (front, back):
                        grid[r][c].co.x += dx
                        grid[r][c].co.z += dy
    for r in range(rows):
        for c in range(cols):
            if (c, r) in holes:
                continue
            bm.faces.new((front[r][c], front[r][c + 1], front[r + 1][c + 1], front[r + 1][c]))
            bm.faces.new((back[r][c], back[r + 1][c], back[r + 1][c + 1], back[r][c + 1]))
    # Close every open edge between the two faces so the slab is solid.
    def closed(c, r):
        return 0 <= c < cols and 0 <= r < rows and (c, r) not in holes
    for r in range(rows):
        for c in range(cols):
            if not closed(c, r):
                continue
            if not closed(c - 1, r):
                bm.faces.new((front[r][c], front[r + 1][c], back[r + 1][c], back[r][c]))
            if not closed(c + 1, r):
                bm.faces.new((front[r][c + 1], back[r][c + 1], back[r + 1][c + 1], front[r + 1][c + 1]))
            if not closed(c, r - 1):
                bm.faces.new((front[r][c], back[r][c], back[r][c + 1], front[r][c + 1]))
            if not closed(c, r + 1):
                bm.faces.new((front[r + 1][c], front[r + 1][c + 1], back[r + 1][c + 1], back[r + 1][c]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = kit.obj_from_bmesh(name, bm)
    ob.data.materials.clear()
    for poly in ob.data.polygons:
        x, y, z = kit.G(poly.center)
        u = x / width + 0.5
        p = int(u * 7)
        shade = 1.0 if p % 2 == 0 else 0.94
        if torn:
            # Old stains: broad and soft, not a patchwork.
            stain = math.sin(x * 0.7 + seed) * math.sin(y * 0.9 - seed * 0.5)
            k = min(1.0, max(0.0, (stain - 0.3) / 0.5))
            shade *= 1.0 - 0.1 * k * k * (3 - 2 * k)
        poly.material_index = kit._slot(ob, slot("sail"), round(shade, 2))
    kit.smooth_by_angle(ob, 70)
    parts = [ob]
    # Reef band with ties, a third of the way down.
    vy = 0.28
    band_y = -vy * height
    pts_f = []
    for c in range(cols + 1):
        u = c / cols
        belly = SAIL_BELLY * math.sin(math.pi * u) * (0.45 + 0.55 * math.sin(math.pi * min(1.0, vy * 1.1)))
        pts_f.append(((u - 0.5) * width * (1 - 0.06 * vy), band_y, -belly - SAIL_THICKNESS / 2 - 0.012))
    band = kit.tube("reefband", pts_f, 0.03, 5, slot("sail"))
    kit.paint(band, slot("sail"), 0.86)
    parts.append(band)
    for c in range(1, cols, 1):
        x, y, z = pts_f[c]
        tie = kit.tube("reefpoint", [(x, y, z - 0.01), (x, y - 0.28, z - 0.03)], 0.012, 4, slot("rope"))
        kit.noink(tie, 0.3)
        parts.append(tie)
    # Bolt rope down the sides.
    for c in (0, cols):
        side_pts = []
        for r in range(rows + 1):
            v = r / rows
            u = c / cols
            side_pts.append(((u - 0.5) * width * (1 - 0.06 * v), -v * height + (0.25 * math.sin(math.pi * u) if r == rows else 0.0), 0.0))
        parts.append(kit.tube("boltrope", side_pts, 0.05, 6, slot("rope")))
    sail_ob = kit.join(name, parts)
    sail_ob["no_ao"] = True
    return sail_ob


def yard(name, width):
    parts = [kit.tube(name, [(-width / 2 - 0.4, 0, 0), (0, 0, 0), (width / 2 + 0.4, 0, 0)], [0.1, 0.17, 0.1], 10, slot("mast"))]
    for sx in (1, -1):
        parts.append(kit.lathe("yardarm", [(0.11, -0.04), (0.11, 0.04)], 10, slot("iron"), caps=False, centre=(sx * (width / 2 + 0.2), 0, 0), axis="x"))
    # The footrope the crew would stand on, hanging below.
    foot = []
    for i in range(9):
        t = i / 8
        x = (t - 0.5) * (width + 0.6)
        foot.append((x, -0.55 - 0.25 * math.sin(t * math.pi), 0.15))
    parts.append(kit.tube("footrope", foot, ROPE_R, 4, slot("rope"), caps=False))
    return kit.join(name, parts)


def wheel():
    """The ship's wheel: axle along z, centre at the origin, eight spokes with turned handles."""
    parts = []
    r = 0.52
    ring = [(math.cos(2 * math.pi * i / 32) * r, math.sin(2 * math.pi * i / 32) * r, 0.0) for i in range(33)]
    parts.append(kit.tube("rim", ring, 0.05, 8, slot("mast"), caps=False))
    ring2 = [(math.cos(2 * math.pi * i / 32) * 0.22, math.sin(2 * math.pi * i / 32) * 0.22, 0.0) for i in range(33)]
    parts.append(kit.tube("inner", ring2, 0.035, 6, slot("mast"), caps=False))
    for i in range(8):
        a = 2 * math.pi * i / 8
        d = Vector((math.cos(a), math.sin(a), 0))
        parts.append(kit.tube("spoke", [tuple(d * 0.1), tuple(d * (r + 0.02))], 0.035, 6, slot("mast")))
        prof = [(0.0, 0.0), (0.045, 0.02), (0.05, 0.07), (0.035, 0.15), (0.05, 0.21), (0.0, 0.25)]
        pts = [tuple(d * (r + 0.02 + h)) for _rr, h in prof]
        radii = [max(0.012, rr) for rr, _h in prof]
        parts.append(kit.tube("handle", pts, radii, 8, slot("hull_dark")))
    parts.append(kit.lathe("hub", [(0.0, -0.12), (0.11, -0.12), (0.12, 0.0), (0.11, 0.12), (0.0, 0.12)], 12, slot("hull_dark"), axis="z"))
    parts.append(kit.lathe("boss", [(0.0, 0.12), (0.07, 0.12), (0.06, 0.16), (0.0, 0.17)], 12, slot("gold"), axis="z"))
    return kit.join("wheel", parts)


def capstan():
    """The anchor capstan: a waisted drum with whelps, a round head with bar holes and four bars."""
    parts = [kit.lathe("drum", [(0.0, 0.0), (0.55, 0.0), (0.5, 0.12), (0.4, 0.4), (0.44, 0.7), (0.5, 0.78), (0.0, 0.78)], 16, slot("hull_dark"))]
    for k in range(8):
        a = 2 * math.pi * k / 8
        parts.append(kit.box("whelp", (math.cos(a) * 0.43, 0.42, math.sin(a) * 0.43), (0.06, 0.62, 0.12), slot("mast"), rot=(0, -a, 0), bevel=0.01))
    parts.append(kit.lathe("head", [(0.0, 0.78), (0.64, 0.78), (0.66, 0.85), (0.64, 0.98), (0.0, 0.98)], 16, slot("mast")))
    parts.append(kit.lathe("headtop", [(0.0, 0.98), (0.3, 0.98), (0.2, 1.05), (0.0, 1.07)], 12, slot("gold")))
    for i in range(4):
        a = 2 * math.pi * i / 4
        d = Vector((math.cos(a), 0, math.sin(a)))
        parts.append(kit.tube("bar", [tuple(d * 0.5 + Vector((0, 0.88, 0))), tuple(d * 1.45 + Vector((0, 0.88, 0)))], [0.055, 0.045], 8, slot("mast")))
    return kit.join("capstan", parts)


def cannon():
    """A cannon barrel along -Z from its trunnions (origin), muzzle at -BARREL_LENGTH: a cast
    iron gun with reinforcing rings, a cascabel knob and a flared muzzle."""
    L = S.BARREL_LENGTH
    prof = [(0.0, 0.66), (0.08, 0.66), (0.14, 0.6), (0.22, 0.56), (0.27, 0.5), (0.27, 0.42), (0.25, 0.4),
            (0.25, 0.1), (0.235, 0.05), (0.235, -0.75), (0.215, -0.8), (0.215, -1.8), (0.2, -1.85),
            (0.19, -L + 0.22), (0.215, -L + 0.18), (0.225, -L + 0.06), (0.21, -L), (0.11, -L), (0.11, -L + 0.3), (0.0, -L + 0.3)]
    parts = [kit.lathe("barrel", [(r, z) for r, z in prof], 16, slot("iron"), axis="z")]
    parts.append(kit.ellipsoid("cascabel", (0, 0, 0.72), (0.09, 0.09, 0.09), slot("iron"), rings=6, sectors=10))
    parts.append(kit.tube("trunnion", [(-0.34, 0, 0), (0.34, 0, 0)], 0.085, 10, slot("iron")))
    parts.append(kit.noink(kit.lathe("bore", [(0.0, -L - 0.001), (0.1, -L - 0.001), (0.1, -L + 0.02), (0.0, -L + 0.02)], 12, "121214", axis="z")))
    return kit.join("cannon", parts)


def flag():
    """A black flag with a skull and crossed bones, flying toward +x from its pole, cut into
    strips so the cloth shader has vertices to ripple."""
    cols, rows = 16, 5
    w, h, t = 2.4, 0.75, 0.03
    bm = bmesh.new()
    grid = {}
    for side in (-1, 1):
        for i in range(cols + 1):
            for j in range(rows + 1):
                grid[(side, i, j)] = bm.verts.new(V(w * i / cols, -h + 2 * h * j / rows, side * t))
    for side in (-1, 1):
        for i in range(cols):
            for j in range(rows):
                q = (grid[(side, i, j)], grid[(side, i + 1, j)], grid[(side, i + 1, j + 1)], grid[(side, i, j + 1)])
                bm.faces.new(q if side > 0 else tuple(reversed(q)))
    for i in range(cols):
        for j in (0, rows):
            bm.faces.new((grid[(-1, i, j)], grid[(-1, i + 1, j)], grid[(1, i + 1, j)], grid[(1, i, j)]))
    for i in (0, cols):
        for j in range(rows):
            bm.faces.new((grid[(-1, i, j)], grid[(1, i, j)], grid[(1, i, j + 1)], grid[(-1, i, j + 1)]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    cloth = kit.obj_from_bmesh("flag", bm, slot("flag"))
    parts = [cloth]
    for z in (-0.04, 0.04):
        skull = kit.ellipsoid("skull", (1.2, 0.12, z), (0.28, 0.27, 0.025), slot("bone"), rings=8, sectors=12)
        jaw = kit.box("jaw", (1.2, -0.13, z), (0.3, 0.14, 0.04), slot("bone"), bevel=0.03)
        parts += [skull, jaw]
        for sx in (1, -1):
            parts.append(kit.noink(kit.ellipsoid("socket", (1.2 + sx * 0.1, 0.13, z * 1.35), (0.07, 0.08, 0.012), slot("flag"), rings=4, sectors=8)))
        for a in (0.7, -0.7):
            parts.append(kit.box("crossbone", (1.2, -0.38, z), (0.95, 0.09, 0.03), slot("bone"), rot=(0, 0, a), bevel=0.02))
    for p in parts[1:]:
        kit.noink(p)
    return kit.join("flag", parts)


def hole():
    """A splintered hole: a dark ragged opening with broken plank ends pointing in."""
    rng = random.Random(3)
    parts = []
    outline = []
    for i in range(14):
        a = 2 * math.pi * i / 14
        r = 0.3 * (0.75 + 0.35 * rng.random())
        outline.append((math.cos(a) * r, math.sin(a) * r))
    parts.append(kit.prism("hole", [(y, z) for z, y in outline], 0.08, "161210", plane="zy"))
    for i in range(9):
        a = 2 * math.pi * i / 9 + rng.uniform(-0.2, 0.2)
        r0 = 0.28
        base = Vector((0, math.sin(a) * r0, math.cos(a) * r0))
        tip = base * 1.0 + Vector((-rng.uniform(0.12, 0.3), 0, 0)) - base.normalized() * rng.uniform(0.05, 0.12)
        sp = kit.tube("splinter", [tuple(base), tuple(tip)], [0.035, 0.004], 4, slot("deck"))
        kit.paint(sp, slot("deck"), 0.8)
        parts.append(sp)
    return kit.join("hole", parts)


def patch():
    """Two planks nailed over a hole, with nail heads."""
    parts = []
    for k, (y, sh) in enumerate(((0.12, 1.0), (-0.12, 0.9))):
        p = kit.box("patchplank", (0, y, 0), (0.08, 0.2, 0.84), slot("deck"), bevel=0.012, rot=(0.06 * (1 if k else -1), 0, 0))
        kit.paint(p, slot("deck"), sh)
        parts.append(p)
        for z in (-0.36, 0.36):
            parts.append(kit.noink(kit.ellipsoid("nail", (-0.045, y, z), (0.012, 0.018, 0.018), slot("iron"), rings=4, sectors=6)))
    return kit.join("patch", parts)


def emblem():
    """The crew's emblem on the main course: a round flag-coloured disc with a skull and crossed
    bones, one in front of the sail's bulge and one in its hollow behind, so it shows from both
    sides. Centred on the sail's middle (where the bulge is SAIL_BELLY deep)."""
    parts = []
    depth = SAIL_BELLY * 0.99
    for side in (-1, 1):
        z = -depth - 0.09 if side < 0 else -depth + 0.15
        disc = kit.lathe("disc", [(0.0, z), (1.15, z), (1.15, z + side * 0.012), (0.0, z + side * 0.012)], 28, slot("flag"), axis="z")
        parts.append(disc)
        ring = [(1.05 * math.cos(2 * math.pi * k / 32), 1.05 * math.sin(2 * math.pi * k / 32), z + side * 0.02) for k in range(33)]
        parts.append(kit.noink(kit.tube("ring", ring, 0.035, 5, slot("bone"), caps=False), 0.0))
        skull = kit.ellipsoid("skull", (0, 0.18, z + side * 0.025), (0.36, 0.34, 0.02), slot("bone"), rings=8, sectors=14)
        jaw = kit.box("jaw", (0, -0.12, z + side * 0.025), (0.38, 0.18, 0.03), slot("bone"), bevel=0.04)
        parts += [kit.noink(skull, 0.0), kit.noink(jaw, 0.0)]
        for sx in (1, -1):
            parts.append(kit.noink(kit.ellipsoid("socket", (sx * 0.13, 0.2, z + side * 0.045), (0.09, 0.1, 0.012), slot("flag"), rings=4, sectors=8), 0.0))
        parts.append(kit.noink(kit.prism("nose", [(-0.04, 0.0), (0.04, 0.0), (0.0, 0.08)], 0.015, slot("flag"), centre=(0, 0.02, z + side * 0.045), plane="xy"), 0.0))
        for a in (0.7, -0.7):
            parts.append(kit.noink(kit.box("bone", (0, -0.5, z + side * 0.02), (1.25, 0.12, 0.025), slot("bone"), rot=(0, 0, a), bevel=0.04), 0.0))
            for e in (1, -1):
                d = Vector((math.cos(a), math.sin(a), 0)) * 0.6 * e
                for o in (1, -1):
                    n = Vector((-math.sin(a), math.cos(a), 0)) * 0.05 * o
                    parts.append(kit.noink(kit.ellipsoid("knob", (d.x + n.x, -0.5 + d.y + n.y, z + side * 0.02), (0.07, 0.07, 0.015), slot("bone"), rings=4, sectors=8), 0.0))
    return kit.join("emblem", parts)


def parts_model():
    objs = []
    for m in range(2):
        for k, (top, height, width) in enumerate(S.sails_for(m)):
            objs.append(yard("yard_%d_%d" % (m, k), width))
            objs.append(sail("sail_%d_%d" % (m, k), width, height))
            objs.append(sail("sail_torn_%d_%d" % (m, k), width, height, torn=True, seed=m * 2 + k + 1))
    objs.append(wheel())
    objs.append(emblem())
    objs.append(capstan())
    objs.append(cannon())
    objs.append(flag())
    objs.append(hole())
    objs.append(patch())
    return objs


def main(names):
    def wreck():
        global WRECK
        WRECK = True
        try:
            return [hull(skeleton=True)]
        finally:
            WRECK = False

    builders = {
        "ship_hull": lambda: [hull()],
        "ship_wreck": wreck,
        "ship_parts": parts_model,
    }
    for name in names or builders:
        kit.reset()
        objs = builders[name]()
        kit.export(name, objs, ao_distance=0.2 if name == "ship_parts" else 0.5, ao_strength=0.9)


if __name__ == "__main__":
    main(kit.args())

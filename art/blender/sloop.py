"""The sloop: the tiny free ship from the shipyards (docs/specs/2026-10-12-m26-shipyards.md).
One open deck with a mast and its square sail, a wheel at the stern, an anchor winch at the
bow, a little map table and a crate of bananas. No guns and no hold.

    blender -b --factory-startup --python art/blender/sloop.py [-- sloop_hull sloop_parts]

Drawn mostly with ship.py's own builders, pointed at sloopshape.py instead of the galleon's
numbers, so she wears the same planking, rails and palette slots (the crew's colours).
"""

import math
import os
import sys

import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
import ship as G  # noqa: E402
import sloopshape as S  # noqa: E402
from kit import V  # noqa: E402

slot = kit.slot


def z_samples(step=0.25, z0=None, z1=None, cuts=()):
    """ship.z_samples, but over the sloop's length (its defaults are the galleon's)."""
    z0 = -S.HALF_LENGTH if z0 is None else z0
    z1 = S.HALF_LENGTH if z1 is None else z1
    zs = []
    z = z0
    while z < z1 - 1e-6:
        zs.append(z)
        z += step
    zs.append(z1)
    zs += [c for c in cuts if z0 < c < z1]
    return sorted(set(round(v, 5) for v in zs))


def strakes():
    """The planks from keel to deck: (y_bottom, y_top, slot, shade), as ship.strakes."""
    edges = [S.KEEL_Y, -0.55, -0.2, 0.0, 0.1, 0.4, 0.7, 0.95, S.DECK_Y]
    rows = []
    for i, (a, b) in enumerate(zip(edges, edges[1:])):
        if b <= 0.1:
            name = "bottom"
        elif a >= 0.7 and b <= 0.95:
            name = "stripe"
        elif a >= 0.95:
            name = "hull_dark"
        else:
            name = "hull"
        rows.append((a, b, name, 1.0 if i % 2 == 0 else 0.93))
    return rows


def use_sloop():
    """Point ship.py's builders at the sloop."""
    G.S = S
    G.z_samples = z_samples
    G.strakes = strakes
    G.GAP_CUTS = (S.LADDER_Z - S.LADDER_GAP, S.LADDER_Z + S.LADDER_GAP)
    G.WRECK = False


def ends():
    """Keel and stem, the bottom, the bow closed off and the little transom."""
    parts = []
    pts = [(0.0, S.KEEL_Y - 0.05, z) for z in z_samples(0.5, -5.3, S.HALF_LENGTH)]
    stem = []
    for i in range(7):
        a = (i / 6) * math.pi / 2
        stem.append((0.0, S.KEEL_Y - 0.05 + (S.DECK_Y + 0.35 - S.KEEL_Y) * math.sin(a), -5.3 - 0.45 * math.sin(a)))
    parts.append(kit.tube("keel", list(reversed(stem[1:])) + pts, 0.09, 4, slot("trim")))
    bm = bmesh.new()
    prev = None
    for z in z_samples(0.4):
        w = S.half_width(z, S.KEEL_Y)
        row = (bm.verts.new(V(-w, S.KEEL_Y, z)), bm.verts.new(V(w, S.KEEL_Y, z)))
        if prev:
            bm.faces.new((prev[0], prev[1], row[1], row[0]))
        prev = row
    parts.append(kit.obj_from_bmesh("bottom", bm, slot("bottom")))
    z = -S.HALF_LENGTH
    bm = bmesh.new()
    prev = None
    for y in (S.KEEL_Y, 0.0, 0.7, S.DECK_Y, S.rail_top(z)):
        w = S.half_width(z, y)
        row = (bm.verts.new(V(-w, y, z)), bm.verts.new(V(w, y, z)))
        if prev:
            bm.faces.new((prev[0], prev[1], row[1], row[0]))
        prev = row
    parts.append(kit.obj_from_bmesh("bow", bm, slot("hull_dark")))
    z = S.HALF_LENGTH
    for a, b, name, shade in strakes() + [(S.DECK_Y, S.rail_top(z), "hull_dark", 0.9)]:
        bm = bmesh.new()
        w0, w1 = S.half_width(z, a), S.half_width(z, b)
        bm.faces.new([bm.verts.new(V(-w0, a, z)), bm.verts.new(V(w0, a, z)), bm.verts.new(V(w1, b, z)), bm.verts.new(V(-w1, b, z))])
        t = kit.obj_from_bmesh("transom", bm, slot(name))
        kit.paint(t, slot(name), shade)
        for p in t.data.polygons:
            if kit.G(p.normal)[2] < 0:
                p.flip()
        parts.append(t)
    return parts


def deck():
    """The deck in planks, with a dark caulk layer in the grooves."""
    parts = []
    t = S.RAIL_THICKNESS
    plank = 0.22
    count = int(math.ceil(S.BEAM / plank))
    zs = z_samples(0.4, S.BOW_DECK_Z - 0.3, S.STERN_Z + 0.3)
    bm = bmesh.new()
    shades = []
    for p in range(count):
        x0 = -count * plank / 2 + p * plank + 0.005
        x1 = x0 + plank - 0.01
        for za, zb in zip(zs, zs[1:]):
            wa = S.half_width(za, S.DECK_Y) - t
            wb = S.half_width(zb, S.DECK_Y) - t
            a0, b0 = max(-wa, x0), min(wa, x1)
            a1, b1 = max(-wb, x0), min(wb, x1)
            if b0 <= a0 + 0.005 or b1 <= a1 + 0.005:
                continue
            bm.faces.new([bm.verts.new(V(a0, S.DECK_Y, za)), bm.verts.new(V(b0, S.DECK_Y, za)), bm.verts.new(V(b1, S.DECK_Y, zb)), bm.verts.new(V(a1, S.DECK_Y, zb))])
            butt = int((za + p * 1.37) / 2.4)
            shades.append(0.9 + 0.1 * ((p * 7 + butt * 3) % 5) / 4)
    ob = kit.obj_from_bmesh("deck", bm)
    ob.data.materials.clear()
    for i, poly in enumerate(ob.data.polygons):
        poly.material_index = kit._slot(ob, slot("deck"), round(shades[i], 2))
        if kit.G(poly.normal)[1] < 0:
            poly.flip()
    parts.append(ob)
    bm = bmesh.new()
    for za, zb in zip(zs, zs[1:]):
        wa = S.half_width(za, S.DECK_Y) - t
        wb = S.half_width(zb, S.DECK_Y) - t
        bm.faces.new([bm.verts.new(V(-wa, S.DECK_Y - 0.012, za)), bm.verts.new(V(wa, S.DECK_Y - 0.012, za)), bm.verts.new(V(wb, S.DECK_Y - 0.012, zb)), bm.verts.new(V(-wb, S.DECK_Y - 0.012, zb))])
    caulk = kit.obj_from_bmesh("caulk", bm, slot("trim"))
    for poly in caulk.data.polygons:
        if kit.G(poly.normal)[1] < 0:
            poly.flip()
    parts.append(kit.noink(caulk))
    return parts


def bulwark(side):
    """The inside of the low bulwark and the cap rail along its top, broken at the ladder."""
    parts = []
    t = S.RAIL_THICKNESS
    for z0, z1 in ((S.BOW_DECK_Z - 0.3, S.LADDER_Z - S.LADDER_GAP), (S.LADDER_Z + S.LADDER_GAP, S.STERN_Z + 0.4)):
        zs = z_samples(0.25, z0, z1)
        bm = bmesh.new()
        rows = []
        for z in zs:
            w = S.half_width(z, S.DECK_Y)
            rows.append([bm.verts.new(V(side * (w - t), y, z)) for y in (S.DECK_Y, S.DECK_Y + S.RAIL_HEIGHT)])
        for r0, r1 in zip(rows, rows[1:]):
            bm.faces.new((r0[0], r1[0], r1[1], r0[1]))
        inner = kit.obj_from_bmesh("bulwark", bm)
        kit.paint(inner, slot("rail"), 0.86)
        kit.orient(inner, lambda x, y, z: (-side, 0, 0))
        parts.append(inner)
        bm = bmesh.new()
        rows = []
        top = S.DECK_Y + S.RAIL_HEIGHT
        for z in zs:
            w = S.half_width(z, S.DECK_Y)
            xo, xi = side * (w + 0.03), side * (w - t - 0.03)
            rows.append([bm.verts.new(V(x, y, z)) for x, y in ((xo, top - 0.04), (xo, top + 0.03), ((xo + xi) / 2, top + 0.06), (xi, top + 0.03), (xi, top - 0.04))])
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
    return parts


def mast():
    """The mast, its partners, a cap, two shrouds a side and a stay to the bowsprit."""
    z = S.MAST_Z[0]
    top = S.DECK_Y + S.MAST_HEIGHT[0]
    parts = [kit.lathe("mast", [(S.MAST_RADIUS, S.KEEL_Y + 0.3), (S.MAST_RADIUS, S.DECK_Y + 0.4), (0.12, top)], 10, slot("mast"), centre=(0, 0, z))]
    parts.append(kit.lathe("partner", [(0.36, S.DECK_Y), (0.34, S.DECK_Y + 0.1), (0.24, S.DECK_Y + 0.15)], 8, slot("hull_dark"), centre=(0, 0, z), smooth=False))
    parts.append(kit.lathe("cap", [(0.16, top - 0.15), (0.17, top), (0.0, top + 0.05)], 8, slot("hull_dark"), centre=(0, 0, z)))
    head = (0.0, top - 0.6, z)
    for side in (1, -1):
        for dz in (-0.35, 0.45):
            foot = (side * (S.half_width(z + dz, S.DECK_Y) + 0.04), S.DECK_Y + S.RAIL_HEIGHT * 0.6, z + dz)
            parts.append(kit.tube("shroud", [foot, head], G.ROPE_R, 4, slot("rope"), caps=False))
    tip = (0.0, S.DECK_Y + 0.45, -S.HALF_LENGTH - 1.6)
    parts.append(kit.tube("bowsprit", [(0.0, S.DECK_Y + 0.25, -S.HALF_LENGTH + 0.8), tip], [0.1, 0.06], 8, slot("mast")))
    parts.append(kit.tube("forestay", [head, tip], G.ROPE_R, 4, slot("rope"), caps=False))
    parts.append(kit.tube("backstay", [(0.0, top - 0.3, z), (0.0, S.DECK_Y + S.RAIL_HEIGHT, S.STERN_Z)], G.ROPE_R, 4, slot("rope"), caps=False))
    return parts


def fittings():
    """The wheel's pedestal, the winch's base, the sail post, the map table and the bananas."""
    parts = []
    w = S.WHEEL
    parts.append(kit.box("pedestal", (w[0], w[1] + 0.45, w[2]), (0.3, 0.9, 0.24), slot("hull_dark"), bevel=0.02))
    c = S.CAPSTAN
    parts.append(kit.box("winchbase", (c[0], c[1] + 0.08, c[2]), (0.9, 0.16, 0.9), slot("hull_dark"), bevel=0.02))
    # A pin rail round the mast's foot, with belaying pins, where the halyards are made fast.
    p = S.SAIL_POST
    for dx, dz, sx, sz in ((0.0, -0.3, 0.66, 0.06), (0.0, 0.3, 0.66, 0.06), (-0.3, 0.0, 0.06, 0.66), (0.3, 0.0, 0.06, 0.66)):
        parts.append(kit.box("pinrail", (p[0] + dx, p[1] + 0.62, p[2] + dz), (sx, 0.06, sz), slot("hull_dark"), bevel=0.01))
    for dx, dz in ((-0.3, -0.3), (0.3, -0.3), (-0.3, 0.3), (0.3, 0.3)):
        parts.append(kit.box("stanchion", (p[0] + dx, p[1] + 0.31, p[2] + dz), (0.06, 0.62, 0.06), slot("mast")))
    for k in range(4):
        x = -0.2 + 0.13 * k
        parts.append(kit.box("pin", (p[0] + x, p[1] + 0.72, p[2] + 0.3), (0.025, 0.2, 0.025), slot("mast")))
    t = S.MAP_TABLE
    parts.append(kit.box("tabletop", (t[0], t[1] + 0.74, t[2]), (0.8, 0.06, 0.6), slot("mast"), bevel=0.015))
    for lx in (-0.32, 0.32):
        for lz in (-0.22, 0.22):
            parts.append(kit.box("leg", (t[0] + lx, t[1] + 0.36, t[2] + lz), (0.06, 0.72, 0.06), slot("hull_dark")))
    parts.append(kit.box("chart", (t[0], t[1] + 0.78, t[2]), (0.56, 0.01, 0.42), "f2e2b8", rot=(0, 0.2, 0)))
    for a in (0.7, -0.7):
        parts.append(kit.noink(kit.box("x", (t[0] + 0.08, t[1] + 0.79, t[2] + 0.04), (0.13, 0.005, 0.03), "c8302a", rot=(0, a, 0))))
    b = S.BANANAS
    parts += G.crate((b[0], b[1] + 0.3, b[2]), (0.3, 0.3, 0.3))
    parts += G.banana_heap((b[0], b[1] + 0.6, b[2]), 0.22)
    return parts


def hull():
    use_sloop()
    parts = []
    for side in (1, -1):
        parts.append(G.hull_side(side))
        parts += bulwark(side)
        parts.append(G.wale(0.55, -5.0, 5.4, side, out=0.05, h=0.1))
        parts += G.side_ladder(side)
    parts += ends()
    parts += deck()
    parts += mast()
    parts += fittings()
    return kit.join("hull", parts)


def parts_model():
    use_sloop()
    return [
        G.yard("yard", S.SAIL_WIDTH),
        G.furl("furl", S.SAIL_WIDTH),
        G.sail("sail", S.SAIL_WIDTH, S.SAIL_HEIGHT),
    ]


def main(names):
    builders = {"sloop_hull": lambda: [hull()], "sloop_parts": parts_model}
    for name in names or builders:
        kit.reset()
        kit.export(name, builders[name](), ao_distance=0.3, ao_strength=0.9)


if __name__ == "__main__":
    main(kit.args())

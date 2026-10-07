"""People: the pirate (four looks, one rig), with every animation.

    blender -b --factory-startup --python art/blender/characters.py [-- pirate ...]

The pirate is exported as one model: the rig, the body (shirt and skin painted in marker
colours the game swaps for each player's own) and one mesh per look, named look0..look3, of
which the game shows one.
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
import rig  # noqa: E402
from kit import SHIRT, SHIRT_DARK, SKIN, SKIN_DARK  # noqa: E402

INK = "2a2430"
BOOT = "3a2a22"
BOOT_DARK = "2a1e18"
BELT = "4a2c1c"
GOLD = "ffd23a"

TROUSERS = ["5b4a3a", "34405a", "2c2c3a", "6a6458", "7a6a50", "3a3a48", "4a2a2a", "50483e"]
HAIR = ["5a3420", "1e1a1a", "a8a49c", "5e2e16", "c89a58", "3a2418", "2a1a12", "6a4a32"]
LOOKS = 8


def smooth_part(ob, levels=1, angle=60):
    kit.subsurf(ob, levels)
    kit.apply_all(ob)
    kit.smooth_by_angle(ob, angle)
    return ob


# ---------------------------------------------------------------------------------------------
# Body


def torso(color=SHIRT, grow=0.0, name="torso"):
    g = grow
    rings = [
        (0.86, 0.172 + g, 0.125 + g, 0, 0.0),
        (0.95, 0.178 + g, 0.13 + g, 0, -0.006),
        (1.05, 0.19 + g, 0.142 + g, 0, -0.018),
        (1.16, 0.208 + g, 0.148 + g, 0, -0.016),
        (1.27, 0.232 + g, 0.152 + g, 0, -0.01),
        (1.36, 0.24 + g, 0.143 + g, 0, -0.002),
        (1.425, 0.212 + g, 0.122 + g, 0, 0.006),
        (1.47, 0.135 + g, 0.09 + g, 0, 0.01),
        (1.5, 0.078 + g, 0.064 + g, 0, 0.01),
    ]
    ob = kit.loft(name, rings, color, sides=20, power=2.4)
    return smooth_part(ob)


def arm_points(side):
    sx = 1 if side == "r" else -1
    sh = rig.joint("upper_arm_" + side)
    el = rig.joint("forearm_" + side)
    wr = rig.joint("hand_" + side)
    inner = Vector((sx * 0.12, 1.41, 0.0))
    return inner, sh, el, wr


def sleeve(side, color=SHIRT, rolled=False, cuff=None):
    """The shirt sleeve from inside the shoulder to the wrist (or rolled to the elbow)."""
    inner, sh, el, wr = arm_points(side)
    if rolled:
        end = el + (wr - el) * 0.25
        pts = [inner, sh, sh + (el - sh) * 0.5, el, end]
        radii = [0.085, 0.088, 0.082, 0.078, 0.08]
    else:
        pts = [inner, sh, sh + (el - sh) * 0.5, el, el + (wr - el) * 0.5, wr - (wr - el).normalized() * 0.03]
        radii = [0.085, 0.087, 0.078, 0.07, 0.068, 0.078]
    ob = kit.tube("sleeve_" + side, [tuple(p) for p in pts], radii, 12, color)
    smooth_part(ob)
    parts = [ob]
    if rolled:
        # The rolled cuff above the elbow, and the bare forearm.
        a = el + (wr - el) * 0.12
        b = el + (wr - el) * 0.3
        parts.append(kit.tube("cuff_" + side, [tuple(a), tuple(b)], [0.088, 0.088], 12, SHIRT_DARK))
        parts.append(kit.tube("forearm_" + side, [tuple(el), tuple(wr)], [0.06, 0.054], 10, SKIN))
    elif cuff:
        a = wr - (wr - el).normalized() * 0.075
        b = wr - (wr - el).normalized() * 0.02
        parts.append(kit.tube("cuff_" + side, [tuple(a), tuple(b)], [0.08, 0.082], 12, cuff))
    for p in parts:
        rig.set_weights(p, rig.limb_weights(side, "upper_arm", "forearm", "hand", start_parent="chest"))
    return parts


def trousers(color):
    parts = []
    pelvis = kit.loft("pelvis", [
        (0.72, 0.16, 0.115, 0, 0.0),
        (0.8, 0.18, 0.128, 0, 0.0),
        (0.92, 0.183, 0.132, 0, 0.0),
        (0.99, 0.178, 0.128, 0, -0.004),
    ], color, sides=20, power=2.4)
    smooth_part(pelvis)
    rig.set_weights(pelvis, lambda p: rig.blend("hips", "thigh_" + ("r" if p.x > 0 else "l"), (0.8 - p.y) / 0.08 * 0.04, 0.04) if abs(p.x) > 0.06 and p.y < 0.84 else {"hips": 1.0})
    parts.append(pelvis)
    for side, sx in (("r", 1), ("l", -1)):
        hip = rig.joint("thigh_" + side)
        knee = rig.joint("shin_" + side)
        ankle = rig.joint("foot_" + side)
        pts = [hip + Vector((0, 0.04, 0)), hip, hip + (knee - hip) * 0.5, knee, knee + (ankle - knee) * 0.45, ankle + Vector((0, 0.12, 0))]
        leg = kit.tube("leg_" + side, [tuple(p) for p in pts], [0.11, 0.108, 0.098, 0.082, 0.084, 0.078], 12, color)
        smooth_part(leg)
        rig.set_weights(leg, rig.limb_weights(side, "thigh", "shin", "foot", start_parent="hips", soft=0.06))
        parts.append(leg)
    return parts


def boots():
    parts = []
    for side, sx in (("r", 1), ("l", -1)):
        ankle = rig.joint("foot_" + side)
        x = ankle.x
        shaft = kit.tube("shaft_" + side, [(x, 0.09, 0.02), (x, 0.2, 0.015), (x, 0.3, 0.012)], [0.084, 0.086, 0.09], 14, BOOT)
        top = kit.tube("bootcuff_" + side, [(x, 0.285, 0.012), (x, 0.37, 0.01)], [0.104, 0.112], 14, BOOT_DARK)
        smooth_part(shaft)
        smooth_part(top)
        rig.set_weights(shaft, rig.rigid("shin_" + side))
        rig.set_weights(top, rig.rigid("shin_" + side))
        # Foot: a rounded slab from the heel to an upturned toe, on a dark sole.
        foot = kit.loft("foot_" + side, [
            (0.0, 0.072, 0.155, x, -0.045),
            (0.05, 0.076, 0.16, x, -0.05),
            (0.105, 0.066, 0.1, x, -0.005),
            (0.135, 0.045, 0.055, x, 0.015),
        ], BOOT, sides=16, power=2.3)
        smooth_part(foot)
        kit.paint_where(foot, BOOT_DARK, lambda px, py, pz: py < 0.018)
        rig.set_weights(foot, lambda p, side=side: rig.blend("shin_" + side, "foot_" + side, (0.08 - p.y) * 1.0, 0.03) if p.z > -0.02 else {"foot_" + side: 1.0})
        parts += [shaft, top, foot]
    return parts


def belt(buckle=GOLD, color=BELT):
    band = kit.lathe("belt", [(0.186, 0.925), (0.192, 0.935), (0.192, 0.985), (0.186, 0.995)], 24, color, caps=False)
    band.scale = (1.0, 0.73, 1.0)
    kit.transform_apply(band)
    frame = kit.box("buckle", (0, 0.96, -0.142), (0.075, 0.064, 0.016), buckle, bevel=0.005)
    pin = kit.box("buckle_in", (0, 0.96, -0.151), (0.04, 0.032, 0.006), color)
    parts = [band, frame, pin]
    for p in parts:
        rig.set_weights(p, rig.rigid("hips"))
    return parts


def hand(side):
    """A big toon hand curled round a grip, the grip running forward through the fist."""
    sx = 1 if side == "r" else -1
    parts = []
    palm = kit.box("palm", (0, -0.055, 0), (0.05, 0.09, 0.09), SKIN, bevel=0.018, segments=3)
    parts.append(palm)
    # Four curled fingers round a grip axis (along Z) on the palm side.
    gx, gy = -0.036, -0.11
    for i, z in enumerate((-0.033, -0.011, 0.011, 0.033)):
        pts = []
        r = 0.033
        for k in range(6):
            a = math.radians(-10 + 200 * k / 5)
            pts.append((gx + r * math.cos(a), gy - r * math.sin(a), z))
        pts = [(0.014, -0.09, z)] + pts
        tip = 0.0125 if i in (1, 2) else 0.0115
        f = kit.tube("finger%d" % i, pts, [0.014, 0.014, 0.0135, 0.013, tip, tip, tip * 0.85], 8, SKIN)
        parts.append(f)
    thumb = kit.tube("thumb", [(-0.015, -0.03, -0.04), (-0.034, -0.062, -0.055), (-0.05, -0.088, -0.05), (-0.056, -0.104, -0.034)], [0.019, 0.018, 0.016, 0.013], 8, SKIN)
    parts.append(thumb)
    ob = kit.join("hand_" + side, parts)
    smooth_part(ob, 1, 70)
    ob.scale = (1.1, 1.1, 1.1)
    kit.transform_apply(ob)
    if sx < 0:
        ob.matrix_world = Matrix.Scale(-1, 4, Vector((1, 0, 0))) @ ob.matrix_world
        kit.transform_apply(ob)
    # Into the rest pose: turned out with the A of the arm, at the wrist.
    wr = rig.joint("hand_" + side)
    kit.place(ob, tuple(wr), (0, 0, math.radians(37.7) * sx))
    kit.transform_apply(ob)
    rig.set_weights(ob, rig.rigid("hand_" + side))
    return [ob]


def _flip_normals(ob):
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


def neck():
    ob = kit.tube("neck", [(0, 1.44, 0.01), (0, 1.52, 0.0), (0, 1.58, -0.005)], [0.062, 0.06, 0.06], 12, SKIN)
    rig.set_weights(ob, lambda p: rig.blend("neck", "head", (p.y - 1.545) * 1.0, 0.02))
    return [ob]


HEAD_C = Vector((0, 1.665, -0.012))
HEAD_R = (0.125, 0.15, 0.135)


def head_shape():
    """The skull: an egg with a broad jaw, a flat back and a strong chin."""
    ob = kit.ellipsoid("head", tuple(HEAD_C), HEAD_R, SKIN, rings=22, sectors=30)
    kit.transform_apply(ob)
    for v in ob.data.vertices:
        x, y, z = kit.G(v.co)
        ny = (y - HEAD_C.y) / HEAD_R[1]
        nz = (z - HEAD_C.z) / HEAD_R[2]
        if ny < 0.1:
            k = min(1.0, (0.1 - ny) / 0.5)
            x *= 1.0 + 0.12 * k * (1.0 if ny > -0.8 else 0.6)
            if nz < 0:
                z -= 0.022 * k * -nz
        if nz > 0:
            z = HEAD_C.z + (z - HEAD_C.z) * 0.9
        if ny > 0.45:
            x *= 1.0 - 0.08 * (ny - 0.45)
        v.co = kit.V(x, y, z)
    return ob


def surface_z(x, y):
    """How far forward the face is at (x, y): the skull's front, before the jaw shaping."""
    nx = x / HEAD_R[0]
    ny = (y - HEAD_C.y) / HEAD_R[1]
    return HEAD_C.z - HEAD_R[2] * math.sqrt(max(0.0, 1 - nx * nx - ny * ny))


def face(brow_color, mouth=True, gruff=1.0, lids=False):
    parts = []
    # A big nose, a shade ruddier than the face, on a short bridge.
    parts.append(kit.ellipsoid("nose", (0, 1.64, surface_z(0, 1.64) - 0.028), (0.038, 0.042, 0.038), SKIN_DARK, rings=8, sectors=12))
    parts.append(kit.noink(kit.ellipsoid("bridge", (0, 1.675, surface_z(0, 1.675) - 0.008), (0.02, 0.035, 0.018), SKIN, rings=6, sectors=8)))
    for sx in (1, -1):
        ex, ey = sx * 0.05, 1.69
        ez = surface_z(ex, ey)
        eye = kit.ellipsoid("eye", (ex, ey, ez + 0.004), (0.023, 0.032, 0.013), "1a1418", rings=8, sectors=12)
        glint = kit.ellipsoid("glint", (ex - sx * 0.006, ey + 0.01, ez - 0.008), (0.007, 0.008, 0.004), "ffffff", rings=4, sectors=6)
        parts += [kit.noink(eye), kit.noink(glint)]
        if lids:
            parts.append(kit.noink(kit.ellipsoid("lid", (ex, ey + 0.014, ez), (0.027, 0.017, 0.014), SKIN, rings=6, sectors=10)))
        # Heavy brows, low at the middle for a gruff look.
        brow = kit.box("brow", (sx * 0.054, 1.737, surface_z(sx * 0.054, 1.737) - 0.006), (0.066, 0.022, 0.022), brow_color, bevel=0.008, segments=2, rot=(0.3, sx * 0.3, sx * 0.24 * gruff))
        parts.append(kit.noink(brow, 0.3))
        parts.append(kit.ellipsoid("ear", (sx * 0.133, 1.665, 0.004), (0.026, 0.042, 0.03), SKIN, rings=6, sectors=10))
        parts.append(kit.noink(kit.ellipsoid("earhole", (sx * 0.144, 1.662, 0.0), (0.008, 0.02, 0.014), SKIN_DARK, rings=4, sectors=6)))
    if mouth:
        pts = [(x, 1.582 + 0.012 * (x / 0.035) ** 2 + 0.004 * x / 0.035, surface_z(x, 1.582) - 0.03) for x in (-0.035, -0.017, 0.0, 0.017, 0.035)]
        parts.append(kit.noink(kit.tube("mouth", pts, 0.0065, 6, "5a2424")))
    return parts


def head(look_parts):
    skull = head_shape()
    parts = [skull]
    for p in parts + look_parts:
        rig.set_weights(p, rig.rigid("head"))
    return parts + look_parts


# ---------------------------------------------------------------------------------------------
# Looks


def tricorn(color="25222c", trim=GOLD):
    """A three-cornered hat: a round crown in a brim turned up on three sides."""
    import bmesh
    bm = bmesh.new()
    rings, sides = 6, 36
    verts = []
    for k in range(rings + 1):
        r = 0.1 + 0.16 * k / rings
        row = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            # Corners at the front and the two back quarters; turned up between them.
            up = 0.5 - 0.5 * math.cos(3 * (a + math.pi / 2))
            lift = up ** 1.5 * 0.1 * (k / rings) ** 1.4
            row.append(bm.verts.new(kit.V(r * math.cos(a), 1.83 + lift, r * math.sin(a))))
        verts.append(row)
    for a, b in zip(verts, verts[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((a[i], a[j], b[j], b[i]))
    brim = kit.obj_from_bmesh("brim", bm, color)
    m = brim.modifiers.new("solid", "SOLIDIFY")
    m.thickness = 0.014
    m.offset = 0
    kit.apply_all(brim)
    kit.smooth_by_angle(brim, 50)
    crown = kit.lathe("crown", [(0.125, 1.8), (0.128, 1.86), (0.12, 1.92), (0.09, 1.955), (0.0, 1.965)], 24, color)
    edge = []
    for i in range(sides + 1):
        a = 2 * math.pi * i / sides
        up = 0.5 - 0.5 * math.cos(3 * (a + math.pi / 2))
        edge.append((0.262 * math.cos(a), 1.83 + up ** 1.5 * 0.1 + 0.004, 0.262 * math.sin(a)))
    trim_ob = kit.tube("trim", edge, 0.008, 6, trim, caps=False)
    hat = kit.join("tricorn", [brim, crown, trim_ob])
    kit.place(hat, (0, 0, 0))
    return [hat]


def shell(name, color, grow, keep, thick=0.012, rings=16, sectors=24):
    """A cap round the skull: the skull's ellipsoid grown by `grow`, keeping vertices where
    keep(x, y, z) is true (Godot coordinates), given some thickness outward."""
    import bmesh
    r = (HEAD_R[0] + grow, HEAD_R[1] + grow, HEAD_R[2] + grow)
    ob = kit.ellipsoid(name, tuple(HEAD_C), r, color, rings=rings, sectors=sectors)
    kit.transform_apply(ob)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    dead = [v for v in bm.verts if not keep(*kit.G(v.co))]
    bmesh.ops.delete(bm, geom=dead, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    m = ob.modifiers.new("solid", "SOLIDIFY")
    m.thickness = thick
    m.offset = 1.0
    kit.apply_all(ob)
    kit.smooth_by_angle(ob, 70)
    return ob


def on_shell(direction, grow):
    d = Vector(direction).normalized()
    return tuple(HEAD_C + Vector((d.x * (HEAD_R[0] + grow), d.y * (HEAD_R[1] + grow), d.z * (HEAD_R[2] + grow))))


def bushy_beard(color):
    parts = []
    beard = kit.ellipsoid("beard", (0, 1.56, -0.08), (0.13, 0.11, 0.09), color, rings=12, sectors=18)
    kit.transform_apply(beard)
    for v in beard.data.vertices:
        x, y, z = kit.G(v.co)
        if z > -0.05:
            z = -0.05 + (z + 0.05) * 0.35
        # Shaggy lumps along the bottom.
        if y < 1.53:
            y -= 0.012 * (1 + math.sin(x * 70))
        v.co = kit.V(x, y, z)
    parts.append(beard)
    for sx in (1, -1):
        parts.append(kit.tube("tache", [(sx * 0.005, 1.607, surface_z(0, 1.6) - 0.03), (sx * 0.045, 1.6, surface_z(0.045, 1.6) - 0.024), (sx * 0.08, 1.585, surface_z(0.08, 1.585) - 0.012)], [0.02, 0.021, 0.014], 8, color))
    return parts


def hair_back(color, length=0.0):
    """Hair round the back and sides below a hat or scarf, with a ragged bottom edge."""
    def keep(x, y, z):
        bottom = 1.575 - length + 0.018 * math.sin(x * 55 + 1.0)
        return z > -0.02 and bottom < y < 1.8
    return [shell("hair", color, 0.006, keep, thick=0.016)]


def bandana(color="c8302a", dots="fff2d0"):
    """A spotted bandana tied at the back, its tails hanging down."""
    def keep(x, y, z):
        back = max(0.0, (z - HEAD_C.z) / HEAD_R[2])
        return y > 1.705 - 0.05 * back
    parts = [shell("bandana", color, 0.004, keep, thick=0.012)]
    for i, (a, b) in enumerate([(0.5, 0.45), (1.3, 0.6), (2.2, 0.4), (3.0, 0.55), (-0.4, 0.5), (-1.2, 0.35), (-2.0, 0.6), (-2.8, 0.45), (0.9, 0.9), (-0.9, 0.9), (2.6, 0.9), (-2.6, 0.9), (0.0, 1.3)]):
        d = (math.cos(a) * math.cos(b), math.sin(b), math.sin(a) * math.cos(b))
        pos = on_shell(d, 0.0145)
        if pos[1] < 1.73:
            continue
        dot = kit.ellipsoid("dot%d" % i, pos, (0.013, 0.013, 0.013), dots, rings=4, sectors=8)
        kit.noink(dot)
        parts.append(dot)
    knot_at = on_shell((0, 0.05, 1), 0.02)
    parts.append(kit.ellipsoid("knot", knot_at, (0.036, 0.03, 0.03), color, rings=6, sectors=10))
    back = Vector(knot_at)
    for sx in (1, -1):
        parts.append(kit.tube("tail", [tuple(back), tuple(back + Vector((sx * 0.03, -0.07, 0.02))), tuple(back + Vector((sx * 0.045, -0.15, 0.01)))], [0.022, 0.02, 0.013], 6, color))
    return parts


def eyepatch(side=1):
    ex = side * 0.05
    patch = kit.ellipsoid("patch", (ex, 1.69, surface_z(ex, 1.69) + 0.002), (0.037, 0.035, 0.014), "16121a", rings=6, sectors=10)
    strap = []
    for i in range(33):
        t = i / 32
        a = math.radians(-115 + 230 * t) * side
        # From above the patch, round the back of the head, coming down over the far ear.
        y = 1.72 + 0.04 * math.sin(t * math.pi) - 0.06 * t
        strap.append((math.sin(a) * (HEAD_R[0] + 0.005), y, HEAD_C.z - math.cos(a) * (HEAD_R[2] + 0.004)))
    band = kit.tube("strap", strap, 0.006, 5, "16121a", caps=False)
    return [patch, band]


def headscarf():
    def keep(x, y, z):
        back = max(0.0, (z - HEAD_C.z) / HEAD_R[2])
        return y > 1.758 - 0.15 * back
    parts = [shell("scarf", SHIRT_DARK, 0.004, keep, thick=0.014)]
    back = Vector(on_shell((0, 0.05, 1), 0.02))
    parts.append(kit.ellipsoid("scarf_knot", tuple(back), (0.04, 0.034, 0.03), SHIRT_DARK, rings=6, sectors=10))
    parts.append(kit.tube("scarf_tail", [tuple(back), tuple(back + Vector((0.02, -0.08, 0.03))), tuple(back + Vector((0.035, -0.2, 0.025)))], [0.034, 0.028, 0.014], 8, SHIRT_DARK))
    return parts


def bicorne(color="1e1d2a", trim=GOLD):
    """A captain's hat worn side to side: a big half-moon with gold edging and a skull."""
    outline = []
    for i in range(25):
        a = math.pi * i / 24
        outline.append((math.cos(a) * 0.27, 0.0 + math.sin(a) * 0.17))
    hat = kit.prism("bicorne", outline, 0.17, color, centre=(0, 1.77, 0.0), plane="xy", bevel=0.02, segments=3)
    kit.apply_all(hat)
    kit.transform_apply(hat)
    # Pinch the front and back faces together toward the top, like a folded hat.
    for v in hat.data.vertices:
        x, y, z = kit.G(v.co)
        t = max(0.0, min(1.0, (y - 1.77) / 0.17))
        v.co = kit.V(x, y, z * (1.0 - 0.75 * t))
    kit.smooth_by_angle(hat, 40)
    edge = [(math.cos(math.pi * i / 24) * 0.272, 1.77 + math.sin(math.pi * i / 24) * 0.172, -0.085 * (1.0 - 0.75 * math.sin(math.pi * i / 24)) - 0.004) for i in range(25)]
    trim_ob = kit.tube("trim", edge, 0.009, 6, trim, caps=False)
    skull = kit.ellipsoid("skull", (0, 1.86, -0.052), (0.03, 0.028, 0.01), "f4efe2", rings=6, sectors=8)
    bones = [kit.box("bone%d" % i, (0, 1.855, -0.048), (0.085, 0.013, 0.01), "f4efe2", rot=(0, 0, 0.6 * (1 if i else -1))) for i in range(2)]
    for b in bones + [skull]:
        kit.noink(b, 0.3)
    return [hat, trim_ob, skull] + bones


def curly_moustache(color):
    parts = []
    for sx in (1, -1):
        pts = [(sx * 0.004, 1.607, surface_z(0, 1.6) - 0.03), (sx * 0.04, 1.6, surface_z(0.04, 1.6) - 0.026), (sx * 0.078, 1.598, surface_z(0.078, 1.6) - 0.012), (sx * 0.096, 1.62, surface_z(0.09, 1.62) - 0.006), (sx * 0.083, 1.635, surface_z(0.083, 1.635) - 0.008)]
        parts.append(kit.tube("tache", pts, [0.016, 0.018, 0.013, 0.009, 0.006], 8, color))
    return parts


def earring(side=-1):
    pts = []
    for i in range(17):
        a = 2 * math.pi * i / 16
        pts.append((side * 0.142, 1.6 + 0.017 * math.cos(a), 0.005 + 0.017 * math.sin(a)))
    ob = kit.tube("earring", pts, 0.0045, 5, GOLD, caps=False)
    kit.noink(ob, 0.3)
    return [ob]


def waistcoat(color):
    """An open waistcoat over the shirt, with the shirt showing in a V at the front."""
    vest = torso(color, grow=0.012, name="vest")
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(vest.data)
    dead = []
    for f in bm.faces:
        x, y, z = kit.G(f.calc_center_median())
        open_w = 0.02 + (y - 0.95) * 0.16
        if z < -0.05 and abs(x) < open_w and y > 0.9:
            dead.append(f)
        if y > 1.44 or y < 0.9:
            dead.append(f)
    bmesh.ops.delete(bm, geom=list(dict.fromkeys(dead)), context="FACES")
    bm.to_mesh(vest.data)
    bm.free()
    m = vest.modifiers.new("solid", "SOLIDIFY")
    m.thickness = 0.008
    kit.apply_all(vest)
    buttons = [kit.noink(kit.ellipsoid("button", (0.075 + (y - 0.95) * 0.16, y, -0.155), (0.011, 0.011, 0.007), GOLD, rings=4, sectors=6)) for y in (1.0, 1.1)]
    for p in [vest] + buttons:
        rig.set_weights(p, rig.torso_weights)
    return [vest] + buttons


def sash(color="b8352c"):
    band = kit.lathe("sash", [(0.186, 0.99), (0.194, 1.0), (0.196, 1.06), (0.19, 1.07)], 24, color, caps=False)
    band.scale = (1.0, 0.75, 1.0)
    kit.transform_apply(band)
    knot = kit.ellipsoid("sash_knot", (-0.16, 1.03, -0.04), (0.03, 0.035, 0.03), color, rings=6, sectors=8)
    tail = kit.tube("sash_tail", [(-0.17, 1.02, -0.04), (-0.19, 0.92, -0.035), (-0.2, 0.82, -0.03)], [0.025, 0.022, 0.018], 6, color)
    parts = [band, knot, tail]
    for p in parts:
        rig.set_weights(p, rig.rigid("hips"))
    return parts


def coat(color="23284a", trim=GOLD):
    """A captain's coat: the body open over the shirt, tails at the back, gold buttons."""
    body = torso(color, grow=0.016, name="coat")
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(body.data)
    dead = []
    for f in bm.faces:
        x, y, z = kit.G(f.calc_center_median())
        open_w = 0.035 + (y - 0.9) * 0.12
        if z < -0.05 and abs(x) < open_w:
            dead.append(f)
        if y > 1.46:
            dead.append(f)
    bmesh.ops.delete(bm, geom=list(dict.fromkeys(dead)), context="FACES")
    bm.to_mesh(body.data)
    bm.free()
    m = body.modifiers.new("solid", "SOLIDIFY")
    m.thickness = 0.01
    kit.apply_all(body)
    rig.set_weights(body, rig.torso_weights)
    parts = [body]
    for sx in (1, -1):
        tail = kit.loft("coattail", [(0.62, 0.075, 0.03, sx * 0.09, 0.13), (0.75, 0.08, 0.035, sx * 0.09, 0.125), (0.9, 0.08, 0.03, sx * 0.085, 0.12)], color, sides=10, power=3)
        rig.set_weights(tail, rig.rigid("hips"))
        parts.append(tail)
        for y in (1.0, 1.1, 1.2):
            b = kit.noink(kit.ellipsoid("button", (sx * (0.07 + (y - 0.9) * 0.12), y, -0.163 + (0.0 if y < 1.15 else 0.004)), (0.012, 0.012, 0.008), trim, rings=4, sectors=6))
            rig.set_weights(b, rig.torso_weights)
            parts.append(b)
    for side in ("r", "l"):
        inner, sh, el, wr = arm_points(side)
        sl = kit.tube("coatsleeve", [tuple(sh + (inner - sh) * 0.5), tuple(sh), tuple(el), tuple(wr - (wr - el).normalized() * 0.04)], [0.084, 0.085, 0.073, 0.074], 12, color)
        smooth_part(sl)
        cuff = kit.tube("coatcuff", [tuple(wr - (wr - el).normalized() * 0.09), tuple(wr - (wr - el).normalized() * 0.035)], [0.082, 0.085], 12, trim)
        for p in (sl, cuff):
            rig.set_weights(p, rig.limb_weights(side, "upper_arm", "forearm", "hand", start_parent="chest"))
            parts.append(p)
    return parts


def braces(color="5a3a22"):
    parts = []
    for sx in (1, -1):
        pts = [(sx * 0.07, 0.99, -0.138), (sx * 0.09, 1.2, -0.152), (sx * 0.1, 1.38, -0.12), (sx * 0.1, 1.45, -0.02), (sx * 0.08, 1.38, 0.115), (sx * 0.06, 1.2, 0.14), (sx * 0.05, 0.99, 0.127)]
        b = kit.tube("brace", pts, 0.012, 6, color, caps=False)
        b.scale = (1, 1, 1)
        rig.set_weights(b, rig.torso_weights)
        parts.append(b)
    return parts


def straw_hat(color="d8b868", band="b8352c"):
    """A wide straw hat with a frayed brim and a red band."""
    rng = __import__("random").Random(3)
    rows = []
    for k in range(5):
        r = 0.13 + 0.2 * k / 4
        row = []
        for i in range(32):
            a = 2 * math.pi * i / 32
            fray = 0.02 * math.sin(i * 2.7) if k == 4 else 0.0
            droop = -0.04 * (k / 4) ** 2
            row.append((math.cos(a) * (r + fray), 1.82 + droop, math.sin(a) * (r + fray)))
        rows.append(row)
    brim = kit.grid_surface("strawbrim", rows, color, close_u=True)
    kit.orient(brim, lambda x, y, z: (0, 1, 0))
    sol = brim.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.015
    kit.apply_all(brim)
    kit.smooth_by_angle(brim, 50)
    crown = kit.lathe("strawcrown", [(0.135, 1.8), (0.14, 1.9), (0.125, 1.97), (0.0, 1.99)], 20, color)
    hatband = kit.lathe("strawband", [(0.142, 1.83), (0.146, 1.87)], 20, band, caps=False)
    weave = [kit.noink(kit.lathe("weave", [(0.141 - 0.003 * k, 1.88 + 0.03 * k), (0.141 - 0.003 * k, 1.885 + 0.03 * k)], 20, "b89a48", caps=False), 0.0) for k in range(3)]
    return [brim, crown, hatband] + weave


def beanie(color=SHIRT_DARK):
    """A knitted watch cap with a turned-up cuff, in the shirt's darker colour."""
    def keep(x, y, z):
        return y > 1.69
    cap = shell("beanie", color, 0.008, keep, thick=0.02)
    for v in cap.data.vertices:
        x, y, z = kit.G(v.co)
        if y > 1.76:
            v.co = kit.V(x, y + 0.03 * (y - 1.76) / 0.06, z)
    cuff = kit.lathe("cuff", [(HEAD_R[0] + 0.03, 1.685), (HEAD_R[0] + 0.035, 1.73), (HEAD_R[0] + 0.02, 1.745)], 22, color, caps=False, centre=tuple(HEAD_C + Vector((0, -1.665, 0))))
    for v in cuff.data.vertices:
        x, y, z = kit.G(v.co)
        v.co = kit.V(x, y, HEAD_C.z + (z - HEAD_C.z) * HEAD_R[2] / HEAD_R[0])
    return [cap, cuff]


def neck_scarf(color="e0c048"):
    """A spotted neckerchief knotted at the front."""
    ring = [(0.08 * math.cos(2 * math.pi * i / 16), 1.47 + 0.01 * math.sin(2 * math.pi * i / 16), 0.07 * math.sin(2 * math.pi * i / 16) - 0.005) for i in range(17)]
    band = kit.tube("scarf", ring, 0.03, 8, color, caps=False)
    knot = kit.ellipsoid("knot", (0.0, 1.45, -0.095), (0.035, 0.03, 0.025), color, rings=6, sectors=8)
    tails = [kit.tube("tail", [(sx * 0.01, 1.44, -0.1), (sx * 0.04, 1.37, -0.13), (sx * 0.035, 1.3, -0.135)], [0.025, 0.02, 0.008], 6, color) for sx in (1, -1)]
    return [band, knot] + tails


def cavalier(color="3a2430", feather="e8e0d0"):
    """A broad-brimmed hat pinned up on one side with a big curling feather."""
    rows = []
    for k in range(5):
        r = 0.12 + 0.2 * k / 4
        row = []
        for i in range(32):
            a = 2 * math.pi * i / 32
            # Turned up on the left side (-X).
            up = max(0.0, -math.cos(a)) ** 2 * 0.14 * (k / 4) ** 1.5
            row.append((math.cos(a) * r, 1.83 + up - 0.02 * (k / 4), math.sin(a) * r))
        rows.append(row)
    brim = kit.grid_surface("cavbrim", rows, color, close_u=True)
    kit.orient(brim, lambda x, y, z: (0, 1, 0))
    sol = brim.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.015
    kit.apply_all(brim)
    kit.smooth_by_angle(brim, 50)
    crown = kit.lathe("cavcrown", [(0.13, 1.8), (0.135, 1.9), (0.115, 1.98), (0.05, 2.0), (0.0, 2.0)], 20, color)
    band = kit.lathe("cavband", [(0.137, 1.83), (0.14, 1.86)], 20, GOLD, caps=False)
    pts = [(-0.12, 1.86, 0.02), (-0.2, 1.97, 0.06), (-0.22, 2.06, 0.16), (-0.18, 2.08, 0.26), (-0.1, 2.02, 0.32)]
    plume = kit.tube("feather", pts, [0.02, 0.05, 0.055, 0.04, 0.012], 8, feather)
    pin = kit.ellipsoid("brooch", (-0.13, 1.88, -0.02), (0.025, 0.025, 0.012), "c8302a", rings=4, sectors=8)
    return [brim, crown, band, plume, kit.noink(pin, 0.3)]


def mutton_chops(color):
    parts = []
    for sx in (1, -1):
        chop = kit.ellipsoid("chop", (sx * 0.105, 1.6, -0.05), (0.04, 0.075, 0.06), color, rings=8, sectors=10)
        kit.jitter(chop, 0.004, 7)
        parts.append(chop)
    parts += [kit.tube("tache", [(sx * 0.005, 1.607, surface_z(0, 1.6) - 0.03), (sx * 0.06, 1.6, surface_z(0.06, 1.6) - 0.02), (sx * 0.1, 1.6, -0.06)], [0.016, 0.018, 0.022], 8, color) for sx in (1, -1)]
    return parts


def bandolier(color="4a2c1c", buckle=GOLD):
    """A strap across the chest from the right shoulder to the left hip, with powder flasks."""
    pts = [(0.17, 1.42, -0.06), (0.1, 1.3, -0.165), (-0.02, 1.12, -0.17), (-0.15, 0.97, -0.13), (-0.19, 0.94, 0.0), (-0.12, 1.1, 0.14), (0.06, 1.3, 0.15), (0.17, 1.42, 0.06)]
    parts = [kit.tube("bandolier", pts, 0.022, 6, color, caps=False)]
    for k, t in enumerate((0.25, 0.4, 0.55)):
        i = int(t * 7)
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        p = a + (b - a) * (t * 7 - i) + Vector((0, 0, -0.03))
        parts.append(kit.lathe("flask", [(0.0, -0.05), (0.025, -0.045), (0.028, 0.02), (0.012, 0.045), (0.0, 0.05)], 8, "8a6a3a", centre=tuple(p)))
    parts.append(kit.box("buckle", (0.06, 1.24, -0.172), (0.05, 0.045, 0.012), buckle, bevel=0.004))
    for p in parts:
        rig.set_weights(p, rig.torso_weights)
    return parts


def look(index):
    """Everything that differs between the eight looks: [head extras], [body extras], options."""
    hair = HAIR[index]
    if index == 0:
        # Tricorn, bushy beard, brown waistcoat.
        head_bits = tricorn() + bushy_beard(hair) + hair_back(hair, 0.03) + face(hair, mouth=False)
        body_bits = waistcoat("6b4a2c")
        return head_bits, body_bits, {"rolled": False, "cuff": None}
    if index == 1:
        # Red bandana, eyepatch, earring, goatee; sleeves rolled, a red sash.
        goatee = [kit.ellipsoid("goatee", (0, 1.548, surface_z(0, 1.56) - 0.035), (0.034, 0.045, 0.03), hair, rings=6, sectors=8)]
        head_bits = bandana() + eyepatch(1) + earring(-1) + goatee + face(hair)
        body_bits = sash()
        return head_bits, body_bits, {"rolled": True, "cuff": None}
    if index == 2:
        # Captain: bicorne, curly moustache, long coat.
        queue = [kit.tube("queue", [(0, 1.62, 0.13), (0, 1.55, 0.155), (0, 1.44, 0.15)], [0.03, 0.027, 0.012], 8, hair),
                 kit.ellipsoid("ribbon", (0, 1.6, 0.145), (0.035, 0.022, 0.025), "16121a", rings=6, sectors=10)]
        head_bits = bicorne() + curly_moustache(hair) + hair_back(hair, -0.02) + queue + face(hair, gruff=0.6)
        body_bits = coat()
        return head_bits, body_bits, {"rolled": False, "cuff": None, "coat": True}
    if index == 3:
        # Headscarf in the shirt's colour, sideburns, braces, a ponytail.
        sideburns = [kit.box("sideburn", (sx * 0.124, 1.64, -0.04), (0.018, 0.06, 0.032), hair, bevel=0.008) for sx in (1, -1)]
        pony = [kit.tube("pony", [(0, 1.64, 0.115), (0, 1.57, 0.15), (0, 1.47, 0.15)], [0.034, 0.03, 0.016], 8, hair)]
        head_bits = headscarf() + sideburns + pony + earring(1) + face(hair)
        body_bits = braces()
        return head_bits, body_bits, {"rolled": True, "cuff": None}
    if index == 4:
        # Straw hat, sandy stubble, a sash and rolled sleeves: the deckhand.
        stubble = [kit.noink(kit.ellipsoid("stubble", (0, 1.57, surface_z(0, 1.58) + 0.012), (0.105, 0.06, 0.06), hair, rings=8, sectors=12), 0.2)]
        head_bits = straw_hat() + hair_back(hair, 0.0) + stubble + face(hair, gruff=0.3)
        body_bits = sash("2f6a4f")
        return head_bits, body_bits, {"rolled": True, "cuff": None}
    if index == 5:
        # Knitted cap, a big chinstrap beard and a yellow neckerchief.
        beard = [kit.ellipsoid("beard", (0, 1.55, surface_z(0, 1.56) + 0.0), (0.13, 0.08, 0.07), hair, rings=10, sectors=14)]
        head_bits = beanie() + beard + face(hair, mouth=False)
        body_bits = neck_scarf()
        for p in body_bits:
            rig.set_weights(p, lambda q: rig.blend("chest", "neck", (q.y - 1.47) * 1.0, 0.04))
        return head_bits, body_bits, {"rolled": False, "cuff": None}
    if index == 6:
        # The cavalier: feathered hat, long hair, goatee, a burgundy coat.
        goatee = [kit.ellipsoid("goatee", (0, 1.545, surface_z(0, 1.56) - 0.03), (0.03, 0.05, 0.028), hair, rings=6, sectors=8)]
        locks = [kit.tube("lock", [(sx * 0.12, 1.7, 0.02), (sx * 0.14, 1.58, 0.04), (sx * 0.13, 1.46, 0.06)], [0.04, 0.035, 0.02], 8, hair) for sx in (1, -1)]
        head_bits = cavalier() + hair_back(hair, 0.1) + locks + goatee + curly_moustache(hair) + face(hair, gruff=0.4)
        body_bits = coat("5a1a24", trim="d8c070")
        return head_bits, body_bits, {"rolled": False, "cuff": None, "coat": True}
    # The bruiser: bald and shining, mutton chops, both ears ringed, a bandolier.
    head_bits = mutton_chops(hair) + earring(1) + earring(-1) + face(hair, gruff=1.4)
    body_bits = bandolier()
    return head_bits, body_bits, {"rolled": True, "cuff": None}


def pirate():
    arm = rig.build_armature("rig")
    base = []
    base.append(torso())
    for p in base:
        rig.set_weights(p, rig.torso_weights)
    base += neck()
    for side in ("r", "l"):
        base += hand(side)
    body = kit.join("body", base)
    rig.bind(body, arm)
    meshes = [body]
    for i in range(LOOKS):
        head_bits, body_bits, opt = look(i)
        parts = head(head_bits)
        if not opt.get("coat"):
            for side in ("r", "l"):
                parts += sleeve(side, rolled=opt["rolled"], cuff=opt["cuff"])
        else:
            for side in ("r", "l"):
                parts += sleeve(side)
        parts += trousers(TROUSERS[i]) + boots() + belt() + body_bits
        ob = kit.join("look%d" % i, parts)
        rig.bind(ob, arm)
        meshes.append(ob)
    rig.animate(arm)
    rig.rest(arm)
    return [arm] + meshes


# ---------------------------------------------------------------------------------------------
# The skeleton crew

BONE = "e8dcbe"
BONE_DARK = "c4b48c"
SOCKET = "1a1714"
RAGS = "5e6a5a"
RAGS_DARK = "454f44"


def bone_seg(name, a, b, r, knob=1.6, color=BONE):
    """A long bone from a to b: a slim shaft with a knobbly joint at each end."""
    a, b = Vector(a), Vector(b)
    d = (b - a)
    pts = [a + d * t for t in (0.0, 0.12, 0.5, 0.88, 1.0)]
    shaft = kit.tube(name, [tuple(p) for p in pts], [r * knob, r * 1.05, r * 0.9, r * 1.05, r * knob], 8, color)
    ends = [kit.ellipsoid(name + "_k", tuple(p), (r * knob * 1.1,) * 3, color, rings=6, sectors=8) for p in (a, b)]
    return [shaft] + ends


def skull():
    """The skull: a cranium, deep dark sockets, a nose hole, cheekbones, teeth and a jaw."""
    c = Vector((0, 1.68, -0.01))
    parts = []
    cran = kit.ellipsoid("cranium", tuple(c), (0.112, 0.125, 0.13), BONE, rings=14, sectors=20)
    for v in cran.data.vertices:
        x, y, z = kit.G(v.co)
        # Narrow the face below the brow and pull the back of the skull round.
        if y < c.y - 0.02 and z < c.z:
            x *= 0.88
        v.co = kit.V(x, y, z)
    parts.append(cran)
    for sx in (1, -1):
        parts.append(kit.noink(kit.ellipsoid("socket", (sx * 0.045, 1.675, -0.118), (0.033, 0.036, 0.022), SOCKET, rings=8, sectors=10), 0.3))
        parts.append(kit.ellipsoid("cheek", (sx * 0.075, 1.63, -0.085), (0.03, 0.022, 0.03), BONE, rings=6, sectors=8))
    parts.append(kit.noink(kit.prism("nose", [(-0.016, 0.0), (0.016, 0.0), (0.0, 0.036)], 0.03, SOCKET, centre=(0, 1.615, -0.12), plane="xy"), 0.3))
    # Upper teeth on the maxilla, a gappy lower row on the jaw.
    parts.append(kit.box("maxilla", (0, 1.585, -0.09), (0.11, 0.03, 0.06), BONE, bevel=0.012))
    for i in range(7):
        x = -0.042 + i * 0.014
        parts.append(kit.noink(kit.box("tooth", (x, 1.565, -0.118), (0.011, 0.018, 0.01), "fbf8ee", bevel=0.002), 0.2))
    jaw = []
    for i in range(9):
        t = i / 8
        a = math.radians(-70 + 140 * t)
        jaw.append((math.sin(a) * 0.075, 1.535 + 0.025 * abs(math.sin(a)) ** 2, -0.03 - math.cos(a) * 0.085))
    parts.append(kit.tube("jaw", jaw, 0.016, 8, BONE))
    for i in range(5):
        if i == 2:
            continue
        x = -0.03 + i * 0.015
        parts.append(kit.noink(kit.box("ltooth", (x, 1.552, -0.112), (0.01, 0.016, 0.009), "fbf8ee", bevel=0.002), 0.2))
    return parts


def ribcage():
    parts = []
    for k in range(6):
        y = 1.2 + k * 0.034
        w = 0.15 - abs(k - 2.5) * 0.012
        for sx in (1, -1):
            arc = []
            for i in range(9):
                t = i / 8
                a = math.radians(20 + 150 * t)
                arc.append((sx * math.sin(a) * w, y - 0.03 * t, 0.07 - (1 - math.cos(a)) * 0.095))
            parts.append(kit.tube("rib", arc, 0.011, 6, BONE, caps=True))
    parts.append(kit.box("sternum", (0, 1.29, -0.118), (0.035, 0.2, 0.018), BONE, bevel=0.008))
    for sx in (1, -1):
        parts += bone_seg("clavicle", (sx * 0.02, 1.405, -0.105), (sx * 0.19, 1.42, -0.01), 0.011, knob=1.4)
    return parts


def spine_column(y0, y1, count):
    parts = []
    for i in range(count):
        y = y0 + (y1 - y0) * (i + 0.5) / count
        parts.append(kit.lathe("vert", [(0.0, y - 0.024), (0.03, y - 0.022), (0.034, y), (0.03, y + 0.022), (0.0, y + 0.024)], 10, BONE if i % 2 else BONE_DARK, centre=(0, 0, 0.055)))
        parts.append(kit.box("spinous", (0, y, 0.09), (0.014, 0.022, 0.03), BONE, bevel=0.005))
    return parts


def pelvis_bones():
    parts = [kit.ellipsoid("sacrum", (0, 0.95, 0.05), (0.06, 0.07, 0.04), BONE, rings=8, sectors=10)]
    for sx in (1, -1):
        wing = kit.ellipsoid("ilium", (sx * 0.1, 0.97, 0.0), (0.075, 0.07, 0.03), BONE, rings=8, sectors=10)
        kit.place(wing, (0, 0, 0))
        wing.rotation_euler = (0, 0, 0)
        parts.append(wing)
        parts.append(kit.ellipsoid("hipball", (sx * 0.1, 0.9, 0.0), (0.045, 0.045, 0.045), BONE_DARK, rings=6, sectors=8))
    parts.append(kit.tube("pubis", [(-0.09, 0.88, -0.04), (0.0, 0.86, -0.07), (0.09, 0.88, -0.04)], 0.018, 8, BONE))
    return parts


def bony_hand(side):
    """A bony fist round a grip, in the same place and pose as the pirate's hand."""
    sx = 1 if side == "r" else -1
    parts = [kit.box("carpals", (0, -0.045, 0), (0.028, 0.06, 0.07), BONE, bevel=0.012)]
    gx, gy = -0.036, -0.11
    for i, z in enumerate((-0.03, -0.01, 0.01, 0.03)):
        pts = [(0.008, -0.075, z * 0.8)]
        r = 0.031
        for k in range(6):
            a = math.radians(-10 + 200 * k / 5)
            pts.append((gx + r * math.cos(a), gy - r * math.sin(a), z))
        parts.append(kit.tube("phalanx%d" % i, pts, 0.0075, 6, BONE))
        for p in pts[1::2]:
            parts.append(kit.ellipsoid("knuckle", p, (0.011, 0.011, 0.011), BONE_DARK, rings=4, sectors=6))
    parts.append(kit.tube("thumb", [(-0.012, -0.03, -0.035), (-0.03, -0.06, -0.05), (-0.046, -0.085, -0.045), (-0.052, -0.1, -0.03)], 0.009, 6, BONE))
    ob = kit.join("bhand_" + side, parts)
    ob.scale = (1.1, 1.1, 1.1)
    kit.transform_apply(ob)
    if sx < 0:
        ob.matrix_world = Matrix.Scale(-1, 4, Vector((1, 0, 0))) @ ob.matrix_world
        kit.transform_apply(ob)
    kit.place(ob, tuple(rig.joint("hand_" + side)), (0, 0, math.radians(37.7) * sx))
    rig.set_weights(ob, rig.rigid("hand_" + side))
    return [ob]


def ragged(ob, depth, seed=0, below=None):
    """Tear the hem of a cloth piece: lower vertices near its bottom edge jag up and down."""
    rng = __import__("random").Random(seed)
    ys = [kit.G(v.co)[1] for v in ob.data.vertices]
    lo = min(ys)
    for v in ob.data.vertices:
        x, y, z = kit.G(v.co)
        if y < lo + depth:
            v.co = kit.V(x, y + rng.uniform(0, depth * 1.5), z)
    return ob


def skeleton():
    arm = rig.build_armature("rig")
    parts = []
    head_parts = skull()
    for p in head_parts:
        rig.set_weights(p, rig.rigid("head"))
    parts += head_parts
    neck_parts = spine_column(1.46, 1.56, 3)
    for p in neck_parts:
        rig.set_weights(p, rig.rigid("neck"))
    parts += neck_parts
    column = spine_column(0.98, 1.44, 9)
    for p in column:
        rig.set_weights(p, rig.torso_weights)
    parts += column
    cage = ribcage()
    for p in cage:
        rig.set_weights(p, rig.rigid("chest"))
    parts += cage
    hips = pelvis_bones()
    for p in hips:
        rig.set_weights(p, rig.rigid("hips"))
    parts += hips
    for side in ("r", "l"):
        sh, el, wr = rig.joint("upper_arm_" + side), rig.joint("forearm_" + side), rig.joint("hand_" + side)
        upper = bone_seg("humerus", tuple(sh), tuple(el), 0.02)
        for p in upper:
            rig.set_weights(p, rig.rigid("upper_arm_" + side))
        fore = bone_seg("radius", tuple(el + Vector((0, 0, -0.012))), tuple(wr + Vector((0, 0, -0.012))), 0.012, knob=1.3)
        fore += bone_seg("ulna", tuple(el + Vector((0, 0, 0.012))), tuple(wr + Vector((0, 0, 0.012))), 0.011, knob=1.4)
        for p in fore:
            rig.set_weights(p, rig.rigid("forearm_" + side))
        parts += upper + fore + bony_hand(side)
        hip, knee, ankle = rig.joint("thigh_" + side), rig.joint("shin_" + side), rig.joint("foot_" + side)
        femur = bone_seg("femur", tuple(hip), tuple(knee), 0.026)
        for p in femur:
            rig.set_weights(p, rig.rigid("thigh_" + side))
        shin = bone_seg("tibia", tuple(knee + Vector((0, 0, -0.008))), tuple(ankle), 0.02)
        shin += bone_seg("fibula", tuple(knee + Vector((0.025 * (1 if side == "r" else -1), -0.02, 0.012))), tuple(ankle + Vector((0.022 * (1 if side == "r" else -1), 0.02, 0.012))), 0.01, knob=1.3)
        shin.append(kit.ellipsoid("kneecap", tuple(knee + Vector((0, 0, -0.032))), (0.026, 0.03, 0.016), BONE, rings=6, sectors=8))
        for p in shin:
            rig.set_weights(p, rig.rigid("shin_" + side))
        foot = [kit.ellipsoid("heel", tuple(ankle + Vector((0, -0.05, 0.03))), (0.035, 0.035, 0.045), BONE, rings=6, sectors=8)]
        for k in range(4):
            dx = (-0.03 + k * 0.02)
            foot.append(kit.tube("toe", [tuple(ankle + Vector((dx * 0.5, -0.06, -0.01))), tuple(ankle + Vector((dx, -0.085, -0.12))), tuple(ankle + Vector((dx * 1.1, -0.09, -0.17)))], 0.009, 6, BONE))
        for p in foot:
            rig.set_weights(p, rig.rigid("foot_" + side))
        parts += femur + shin + foot
    body = kit.join("skeleton", parts)
    rig.bind(body, arm)
    meshes = [body]
    for i in range(3):
        ob = kit.join("look%d" % i, skeleton_look(i))
        rig.bind(ob, arm)
        meshes.append(ob)
    rig.animate(arm)
    rig.rest(arm)
    return [arm] + meshes


def torn_breeches(color, seed):
    parts = []
    for p in trousers(color):
        if p.name.startswith("leg"):
            # Cut the legs off above the knee and tear the hem.
            import bmesh
            bm = bmesh.new()
            bm.from_mesh(p.data)
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if kit.G(v.co)[1] < 0.6], context="VERTS")
            bm.to_mesh(p.data)
            bm.free()
            ragged(p, 0.06, seed=seed + len(parts))
            sol = p.modifiers.new("solid", "SOLIDIFY")
            sol.thickness = 0.008
            kit.apply_all(p)
        parts.append(p)
    return parts


def rag_vest(color, seed):
    """What is left of a shirt on a skeleton: narrowed to the ribcage, open at the front,
    holed through and ragged at the hem."""
    import bmesh
    rng = __import__("random").Random(seed)
    vest = torso(color, grow=-0.02, name="ragvest")
    for v in vest.data.vertices:
        x, y, z = kit.G(v.co)
        v.co = kit.V(x * 0.74, y, z * 0.8 + 0.01)
    bm = bmesh.new()
    bm.from_mesh(vest.data)
    holes = [(rng.uniform(-0.15, 0.15), rng.uniform(1.0, 1.35), rng.choice((-1, 1))) for _ in range(6)]
    dead = []
    for f in bm.faces:
        x, y, z = kit.G(f.calc_center_median())
        if z < -0.04 and abs(x) < 0.03 + (y - 0.95) * 0.12:
            dead.append(f)
        elif y > 1.45 or y < 0.98 + 0.05 * abs(math.sin(x * 40)):
            dead.append(f)
        elif any(abs(x - hx) < 0.05 and abs(y - hy) < 0.05 and z * hz > 0 for hx, hy, hz in holes):
            dead.append(f)
    bmesh.ops.delete(bm, geom=list(dict.fromkeys(dead)), context="FACES")
    bm.to_mesh(vest.data)
    bm.free()
    sol = vest.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.008
    kit.apply_all(vest)
    rig.set_weights(vest, rig.torso_weights)
    return [vest]


def morion(color="6a6a72"):
    """A rusty Spanish helmet: a domed skull cap, a brim curving up at front and back and a comb
    along the top."""
    dome = kit.lathe("dome", [(0.0, 1.97), (0.07, 1.96), (0.12, 1.9), (0.14, 1.8), (0.14, 1.74)], 18, color)
    rows = []
    for k in range(4):
        r = 0.14 + 0.12 * k / 3
        row = []
        for i in range(28):
            a = 2 * math.pi * i / 28
            up = (abs(math.sin(a)) ** 2) * 0.1 * (k / 3) ** 1.3
            row.append((math.cos(a) * r * 0.9, 1.75 + up, -0.01 + math.sin(a) * r))
        rows.append(row)
    brim = kit.grid_surface("brim", rows, color, close_u=True)
    kit.orient(brim, lambda x, y, z: (0, 1, 0))
    sol = brim.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.012
    kit.apply_all(brim)
    comb = kit.prism("comb", [(-0.13, 0.0), (0.13, 0.0), (0.08, 0.08), (0.0, 0.1), (-0.08, 0.08)], 0.015, color, centre=(0, 1.93, -0.01), plane="zy")
    rust = [kit.noink(kit.ellipsoid("rust", (0.07 * math.cos(a), 1.86 + 0.05 * math.sin(a * 3), -0.01 + 0.13 * math.sin(a)), (0.03, 0.02, 0.03), "8a5a3a", rings=4, sectors=6), 0.0) for a in (0.6, 2.2, 4.0)]
    return [dome, brim, comb] + rust


def skeleton_look(i):
    """The skeleton's outfits: 0 torn breeches, a sash and a battered tricorn; 1 a faded
    bandana and the rags of a shirt; 2 a rusty morion helmet and a loincloth."""
    parts = []
    if i == 0:
        parts += torn_breeches(RAGS, 1) + sash(RAGS_DARK)
        hat = tricorn("2b2622", trim="6a6040")
        for p in hat:
            p.scale = (0.95, 1.0, 0.95)
        head_bits = hat
    elif i == 1:
        parts += torn_breeches("4a4a5a", 2) + rag_vest("8a8470", 5)
        head_bits = bandana("8a3a2e", dots="c8bca0")
    else:
        cloth = kit.loft("loincloth", [(0.82, 0.15, 0.1, 0, 0.0), (0.92, 0.165, 0.115, 0, 0.0), (0.98, 0.16, 0.11, 0, 0.0)], RAGS, sides=16, power=2.4)
        rig.set_weights(cloth, rig.rigid("hips"))
        flap = kit.prism("flap", [(-0.07, 0.0), (0.07, 0.0), (0.09, -0.22), (0.03, -0.27), (-0.02, -0.24), (-0.08, -0.26)], 0.012, RAGS, centre=(0, 0.88, -0.125), plane="xy")
        rig.set_weights(flap, rig.rigid("hips"))
        parts += [cloth, flap] + sash("5a2a24")
        head_bits = morion()
    for p in head_bits:
        rig.set_weights(p, rig.rigid("head"))
    return parts + head_bits


def merchant():
    """The outpost's merchant: stout, in a long green coat over a cream shirt and an apron, a
    wide-brimmed hat, grey whiskers and little gold spectacles. Same rig as the pirates."""
    arm = rig.build_armature("rig")
    coat_c, coat_dark = "2f7a4f", "245f3d"
    parts = []
    # A big round belly under the shirt.
    body = kit.loft("torso", [
        (0.86, 0.19, 0.15, 0, 0.0),
        (0.95, 0.215, 0.19, 0, -0.03),
        (1.06, 0.235, 0.21, 0, -0.05),
        (1.17, 0.24, 0.2, 0, -0.04),
        (1.28, 0.24, 0.16, 0, -0.015),
        (1.37, 0.235, 0.14, 0, 0.0),
        (1.43, 0.2, 0.115, 0, 0.006),
        (1.475, 0.13, 0.09, 0, 0.01),
        (1.5, 0.078, 0.064, 0, 0.01),
    ], "efe6d2", sides=22, power=2.2)
    smooth_part(body)
    rig.set_weights(body, rig.torso_weights)
    parts.append(body)
    # The coat: open at the front, falling to the knees.
    coat = kit.loft("coat", [
        (0.55, 0.25, 0.22, 0, 0.0),
        (0.86, 0.215, 0.175, 0, -0.01),
        (0.95, 0.235, 0.205, 0, -0.03),
        (1.06, 0.255, 0.225, 0, -0.05),
        (1.17, 0.26, 0.215, 0, -0.04),
        (1.28, 0.258, 0.175, 0, -0.015),
        (1.37, 0.252, 0.155, 0, 0.0),
        (1.44, 0.21, 0.125, 0, 0.006),
        (1.49, 0.14, 0.1, 0, 0.01),
    ], coat_c, sides=22, power=2.2, cap_bottom=False, cap_top=False)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(coat.data)
    dead = [f for f in bm.faces if kit.G(f.calc_center_median())[2] < -0.1 and abs(kit.G(f.calc_center_median())[0]) < 0.08 + (kit.G(f.calc_center_median())[1] - 0.55) * 0.12]
    bmesh.ops.delete(bm, geom=list(dict.fromkeys(dead)), context="FACES")
    bm.to_mesh(coat.data)
    bm.free()
    sol = coat.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.015
    kit.apply_all(coat)
    smooth_part(coat)
    kit.paint_where(coat, coat_dark, lambda x, y, z: y < 0.62)
    rig.set_weights(coat, lambda p: rig.torso_weights(p) if p.y > 0.95 else rig.blend("hips", "thigh_" + ("r" if p.x > 0 else "l"), (0.8 - p.y) * 0.3, 0.2) if abs(p.x) > 0.05 else {"hips": 1.0})
    parts.append(coat)
    # Apron down the front, following the belly and hanging straight below it.
    belly = [(0.86, 0.19, 0.15, -0.0), (0.95, 0.215, 0.19, -0.03), (1.06, 0.235, 0.21, -0.05),
             (1.17, 0.24, 0.2, -0.04), (1.28, 0.24, 0.16, -0.015), (1.37, 0.235, 0.14, 0.0)]

    def front_z(x, y):
        y = max(0.86, min(1.37, y))
        for (y0, rx0, rz0, z0), (y1, rx1, rz1, z1) in zip(belly, belly[1:]):
            if y0 <= y <= y1:
                t = (y - y0) / (y1 - y0)
                rx, rz, zo = rx0 + (rx1 - rx0) * t, rz0 + (rz1 - rz0) * t, z0 + (z1 - z0) * t
                k = min(0.999, abs(x) / rx) ** 2.2
                return zo - rz * (1 - k) ** (1 / 2.2)
        return -0.2

    rows = []
    for j in range(11):
        y = 0.6 + 0.7 * j / 10
        w = 0.19 if y < 1.1 else 0.19 - (y - 1.1) * 0.3
        rows.append([(w * (i / 4 - 1), y, front_z(w * (i / 4 - 1), y) - 0.022) for i in range(9)])
    apron = kit.grid_surface("apron", rows, "f4efe2")
    kit.orient(apron, lambda x, y, z: (0, 0, -1))
    sol = apron.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.012
    kit.apply_all(apron)
    kit.smooth_by_angle(apron, 60)
    pocket = kit.box("pocket", (0.06, 0.82, front_z(0.06, 0.86) - 0.04), (0.16, 0.12, 0.02), "e4dccb")
    for p in (apron, pocket):
        rig.set_weights(p, lambda q: rig.torso_weights(q) if q.y > 0.95 else {"hips": 1.0})
        parts.append(p)
    for side in ("r", "l"):
        inner, sh, el, wr = arm_points(side)
        sl = kit.tube("sleeve", [tuple(inner), tuple(sh), tuple(el), tuple(wr - (wr - el).normalized() * 0.03)], [0.09, 0.095, 0.085, 0.088], 12, coat_c)
        smooth_part(sl)
        cuff = kit.tube("cuff", [tuple(wr - (wr - el).normalized() * 0.09), tuple(wr - (wr - el).normalized() * 0.03)], [0.092, 0.095], 12, coat_dark)
        for p in (sl, cuff):
            rig.set_weights(p, rig.limb_weights(side, "upper_arm", "forearm", "hand", start_parent="chest"))
            parts.append(p)
        parts += hand(side)
    parts += neck()
    parts += trousers("5b4636") + boots() + belt(buckle="c0c0c8", color="3a2a22")
    # Head: grey whiskers, spectacles, a wide round hat.
    hair = "c8c4bc"
    head_bits = face(hair, gruff=-0.5)
    head_bits += [kit.ellipsoid("beard", (0, 1.55, surface_z(0, 1.55) - 0.01), (0.1, 0.075, 0.06), hair, rings=8, sectors=12)]
    head_bits += curly_moustache(hair)
    head_bits += hair_back(hair, 0.0)
    for sx in (1, -1):
        ring = [(sx * 0.05 + 0.027 * math.cos(2 * math.pi * i / 12), 1.69 + 0.024 * math.sin(2 * math.pi * i / 12), surface_z(sx * 0.05, 1.69) - 0.025) for i in range(13)]
        head_bits.append(kit.noink(kit.tube("specs", ring, 0.0045, 4, GOLD, caps=False), 0.3))
    head_bits.append(kit.noink(kit.tube("bridge", [(-0.024, 1.695, surface_z(0, 1.69) - 0.03), (0.024, 1.695, surface_z(0, 1.69) - 0.03)], 0.004, 4, GOLD), 0.3))
    hat = [kit.lathe("brim", [(0.0, 1.8), (0.32, 1.79), (0.34, 1.81), (0.3, 1.82), (0.0, 1.83)], 24, "6b4a2c"),
           kit.lathe("crown", [(0.135, 1.8), (0.14, 1.9), (0.12, 1.98), (0.0, 2.0)], 20, "6b4a2c"),
           kit.lathe("hatband", [(0.142, 1.82), (0.145, 1.86)], 20, "2f6a4f", caps=False)]
    head_bits += hat
    parts += head(head_bits)
    ob = kit.join("merchant", parts)
    rig.bind(ob, arm)
    rig.animate(arm)
    rig.rest(arm)
    return [arm, ob]


def fp_arm():
    """Your own right arm in first person: the fist round a grip at the origin (the grip runs
    along -Z, as weapons are made), the forearm and sleeve running back to the lower right."""
    built = hand("r")[0]
    # Undo the rest pose's placement: back to the hanging hand, wrist at the origin.
    wr = rig.joint("hand_r")
    built.matrix_world = kit.godot_basis((0, 0, math.radians(-37.7))).to_4x4() @ Matrix.Translation(-kit.V(tuple(wr))) @ built.matrix_world
    kit.transform_apply(built)
    # Turn it so the fingers point left and a little down, the palm toward the grip's left side.
    turn = math.radians(-62)
    grip = Vector((-0.0396, -0.121, 0.0))
    g = Vector((grip.x * math.cos(turn) - grip.y * math.sin(turn), grip.x * math.sin(turn) + grip.y * math.cos(turn), 0.0))
    built.matrix_world = Matrix.Translation(-kit.V(tuple(g))) @ kit.godot_basis((0, 0, turn)).to_4x4() @ built.matrix_world
    kit.transform_apply(built)
    wrist = -g
    elbow = wrist + Vector((0.14, -0.12, 0.3))
    fore = kit.tube("fp_fore", [tuple(wrist + (elbow - wrist) * 0.05), tuple(elbow)], [0.048, 0.056], 12, SKIN)
    cuff_a = wrist + (elbow - wrist) * 0.36
    sleeve_ = kit.tube("fp_sleeve", [tuple(cuff_a), tuple(elbow), tuple(elbow + Vector((0.05, -0.05, 0.14)))], [0.064, 0.07, 0.074], 14, SHIRT)
    cuff = kit.tube("fp_cuff", [tuple(cuff_a - (elbow - wrist).normalized() * 0.01), tuple(cuff_a + (elbow - wrist).normalized() * 0.045)], [0.07, 0.072], 14, SHIRT_DARK)
    for p in (fore, sleeve_, cuff):
        smooth_part(p)
    ob = kit.join("fp_arm", [built, fore, sleeve_, cuff])
    for g_ in list(ob.vertex_groups):
        ob.vertex_groups.remove(g_)
    return [ob]


def main(names):
    builders = {"pirate": pirate, "skeleton": skeleton, "merchant": merchant, "fp_arm": fp_arm}
    for name in names or builders:
        kit.reset()
        objs = builders[name]()
        kit.export(name, objs, animations=name in ("pirate", "skeleton", "merchant"), ao_distance=0.12, ao_strength=0.8)


if __name__ == "__main__":
    main(kit.args())

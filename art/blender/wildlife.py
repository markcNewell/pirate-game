"""Wildlife: gulls (a body and one wing, which the game mirrors and flaps), crabs, dolphins and
the whale. All face -Z.

    blender -b --factory-startup --python art/blender/wildlife.py [-- gull crab ...]
"""

import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

INK = "1a1418"


def body_loft(name, stations, color, sides=14, power=2.0):
    """A body along Z from stations (z, half width, half height, y offset)."""
    rings = []
    for z, w, h, y in stations:
        rings.append((z, w, h, y))
    # kit.loft stacks rings along Y; build it along Y and turn it to lie along Z.
    ob = kit.loft(name, [(z, w, h, 0.0, -y) for z, w, h, y in rings], color, sides=sides, power=power)
    kit.place(ob, (0, 0, 0), (math.pi / 2, 0, 0))
    return ob


def gull():
    """A gull, 1 m wingspan once scaled: white body with a grey back, yellow beak with a red
    spot, black eye, grey tail; and one wing (root at the origin, out along +X) with a grey
    back and black tip, swept back a little."""
    parts = []
    body = body_loft("gull", [(-0.38, 0.0, 0.0, 0.07), (-0.33, 0.07, 0.08, 0.08), (-0.22, 0.1, 0.11, 0.06), (0.0, 0.13, 0.14, 0.0), (0.2, 0.1, 0.1, 0.01), (0.38, 0.05, 0.03, 0.04), (0.46, 0.0, 0.0, 0.05)], "ffffff", sides=12)
    kit.smooth_by_angle(body, 70)
    kit.paint_where(body, "c9d0d8", lambda x, y, z: y > 0.08 and z > -0.15)
    parts.append(body)
    parts.append(kit.ellipsoid("head", (0, 0.09, -0.3), (0.085, 0.085, 0.1), "ffffff", rings=8, sectors=10))
    beak = kit.tube("beak", [(0, 0.08, -0.38), (0, 0.075, -0.46), (0, 0.06, -0.52)], [0.025, 0.018, 0.004], 6, "ffc030")
    parts.append(beak)
    parts.append(kit.noink(kit.ellipsoid("spot", (0, 0.06, -0.47), (0.012, 0.01, 0.012), "e04a2a", rings=3, sectors=5), 0.2))
    for sx in (1, -1):
        parts.append(kit.noink(kit.ellipsoid("eye", (sx * 0.06, 0.12, -0.33), (0.016, 0.018, 0.016), INK, rings=4, sectors=6), 0.2))
    parts.append(kit.prism("tail", [(-0.08, 0.0), (0.08, 0.0), (0.1, 0.16), (0.0, 0.13), (-0.1, 0.16)], 0.02, "a8b0b8", centre=(0, 0.04, 0.38), plane="xz"))
    for sx in (1, -1):
        parts.append(kit.tube("leg", [(sx * 0.04, -0.08, 0.08), (sx * 0.04, -0.1, 0.22)], 0.012, 4, "ff9a40"))
    b = kit.join("gull_body", parts)
    w = []
    outline = [(0.0, -0.1), (0.25, -0.12), (0.5, -0.1), (0.72, -0.04), (0.95, 0.08), (0.88, 0.14), (0.6, 0.13), (0.3, 0.12), (0.0, 0.1)]
    wing = kit.prism("wing", outline, 0.025, "dfe4ea", centre=(0, 0, 0), plane="xz", bevel=0.008)
    kit.apply_all(wing)
    kit.paint_where(wing, "b8c0c8", lambda x, y, z: y > 0.004)
    kit.paint_where(wing, "2a2a32", lambda x, y, z: x > 0.68)
    # A gentle arch along the span.
    for v in wing.data.vertices:
        x, y, z = kit.G(v.co)
        v.co = kit.V(x, y + 0.05 * math.sin(min(1.0, x / 0.95) * math.pi), z)
    kit.smooth_by_angle(wing, 40)
    w.append(wing)
    return [b, kit.join("gull_wing", w)]


def crab():
    """A crab facing -Z: a bumpy round shell, eyes on stalks, two big claws and three jointed
    legs a side."""
    red, dark, pale = "e0482e", "b8361f", "ffb08a"
    parts = []
    shell = kit.ellipsoid("shell", (0, 0.11, 0), (0.2, 0.08, 0.16), red, rings=8, sectors=14)
    kit.paint_where(shell, pale, lambda x, y, z: y < 0.08)
    parts.append(shell)
    for k in range(5):
        a = math.pi * (0.2 + 0.6 * k / 4)
        parts.append(kit.ellipsoid("bump", (math.cos(a) * 0.1, 0.17, -math.sin(a) * 0.04 + 0.03), (0.03, 0.02, 0.03), dark, rings=4, sectors=6))
    for sx in (1, -1):
        parts.append(kit.tube("stalk", [(sx * 0.05, 0.15, -0.12), (sx * 0.06, 0.24, -0.14)], 0.012, 5, red))
        parts.append(kit.ellipsoid("eye", (sx * 0.06, 0.255, -0.14), (0.024, 0.024, 0.024), "ffffff", rings=5, sectors=8))
        parts.append(kit.noink(kit.ellipsoid("pupil", (sx * 0.06, 0.258, -0.16), (0.012, 0.013, 0.008), INK, rings=4, sectors=6), 0.2))
        # Claw: arm and a pincer of two jaws.
        parts.append(kit.tube("arm", [(sx * 0.14, 0.1, -0.1), (sx * 0.22, 0.13, -0.18), (sx * 0.22, 0.15, -0.26)], [0.03, 0.028, 0.03], 6, red))
        parts.append(kit.ellipsoid("palm", (sx * 0.22, 0.16, -0.31), (0.06, 0.05, 0.075), red, rings=6, sectors=8))
        parts.append(kit.tube("jaw", [(sx * 0.2, 0.18, -0.36), (sx * 0.19, 0.2, -0.42), (sx * 0.18, 0.18, -0.45)], [0.025, 0.018, 0.006], 5, red))
        parts.append(kit.tube("jaw", [(sx * 0.24, 0.14, -0.36), (sx * 0.24, 0.13, -0.42)], [0.022, 0.006], 5, dark))
        for k in range(3):
            z = -0.05 + k * 0.07
            parts.append(kit.tube("leg", [(sx * 0.16, 0.09, z), (sx * 0.27, 0.13, z + 0.02), (sx * 0.33, 0.0, z + 0.04)], [0.018, 0.015, 0.008], 5, red))
    return [kit.join("crab", parts)]


def dolphin():
    """A dolphin facing -Z: a smooth body with a beak, a curved dorsal fin, flippers, flukes,
    a grey-blue back fading to a pale belly, eyes and a little smile."""
    back, belly = "6c7d8e", "dbe6ec"
    parts = []
    body = body_loft("dolphin", [
        (-1.25, 0.0, 0.0, -0.02), (-1.18, 0.04, 0.04, -0.03), (-0.95, 0.07, 0.06, -0.05), (-0.85, 0.15, 0.15, 0.0),
        (-0.55, 0.25, 0.27, 0.03), (-0.1, 0.29, 0.31, 0.02), (0.35, 0.24, 0.25, 0.0), (0.75, 0.13, 0.15, 0.0),
        (1.05, 0.06, 0.08, 0.02), (1.2, 0.04, 0.05, 0.03)], back, sides=16)
    kit.smooth_by_angle(body, 80)
    kit.paint_where(body, belly, lambda x, y, z: y < -0.05 - 0.02 * abs(x))
    parts.append(body)
    fin = kit.prism("dorsal", [(-0.15, 0.0), (0.25, 0.0), (0.22, 0.12), (0.12, 0.3), (0.05, 0.36)], 0.05, back, centre=(0, 0.26, 0.05), plane="zy", bevel=0.015)
    parts.append(fin)
    for sx in (1, -1):
        flip = kit.prism("flipper", [(0.0, -0.05), (0.0, 0.05), (0.3, 0.02), (0.38, -0.06)], 0.03, back, centre=(0, 0, 0), plane="xz", bevel=0.01)
        if sx < 0:
            for v in flip.data.vertices:
                v.co.x = -v.co.x
            for p in flip.data.polygons:
                p.flip()
        kit.place(flip, (sx * 0.2, -0.15, -0.45), (0, 0, -sx * 0.4))
        parts.append(flip)
        fluke = kit.prism("fluke", [(0.0, -0.06), (0.0, 0.06), (0.32, 0.18), (0.38, 0.1), (0.3, -0.02)], 0.03, back, centre=(0, 0, 0), plane="xz", bevel=0.01)
        if sx < 0:
            for v in fluke.data.vertices:
                v.co.x = -v.co.x
            for p in fluke.data.polygons:
                p.flip()
        kit.place(fluke, (0, 0.03, 1.15))
        parts.append(fluke)
        parts.append(kit.noink(kit.ellipsoid("eye", (sx * 0.14, 0.07, -0.85), (0.025, 0.03, 0.025), INK, rings=4, sectors=6), 0.2))
    parts.append(kit.noink(kit.tube("smile", [(-0.06, -0.035, -1.02), (0.0, -0.05, -1.12), (0.06, -0.035, -1.02)], 0.007, 4, "4a5868"), 0.2))
    return [kit.join("dolphin", parts)]


def whale():
    """A humpback's back as it breaks the surface, facing -Z: a long dark body with knobbly
    tubercles on its head, a small dorsal hump, a pale throat and long white-edged flippers."""
    skin, belly = "3e5a78", "c9d6de"
    parts = []
    body = body_loft("whale", [
        (-4.2, 0.0, 0.0, -0.3), (-4.0, 0.7, 0.5, -0.3), (-3.2, 1.5, 1.05, -0.15), (-1.8, 2.05, 1.3, 0.0), (0.0, 2.2, 1.25, 0.05),
        (2.0, 1.75, 1.0, 0.1), (3.6, 0.9, 0.6, 0.25), (4.6, 0.35, 0.3, 0.4), (5.2, 0.18, 0.18, 0.5)], skin, sides=18)
    kit.smooth_by_angle(body, 80)
    kit.paint_where(body, belly, lambda x, y, z: y < -0.55 and z < 2.0)
    parts.append(body)
    # Throat grooves on the pale underside.
    for k in range(-3, 4):
        parts.append(kit.noink(kit.tube("groove", [(k * 0.28, -1.0 - 0.02 * abs(k), -3.4), (k * 0.4, -1.2 - 0.02 * abs(k), -1.0)], 0.03, 4, "a8b8c4"), 0.0))
    for k in range(9):
        x = (k % 3 - 1) * 0.45
        z = -3.6 + (k // 3) * 0.55
        parts.append(kit.ellipsoid("tubercle", (x, 0.55 + 0.25 * (k // 3), z), (0.12, 0.08, 0.12), "34506c", rings=4, sectors=6))
    parts.append(kit.prism("hump", [(-0.4, 0.0), (0.6, 0.0), (0.3, 0.35), (0.0, 0.4)], 0.18, skin, centre=(0, 1.1, 2.2), plane="zy", bevel=0.06))
    for sx in (1, -1):
        flip = kit.tube("flipper", [(sx * 1.6, -0.6, -1.4), (sx * 3.0, -1.0, -0.6), (sx * 4.2, -1.3, 0.3)], [0.35, 0.3, 0.12], 8, skin)
        for v in flip.data.vertices:
            v.co.z = -0.6 + (v.co.z + 0.6) * 0.35
        kit.paint_where(flip, "e8eef2", lambda x, y, z, sx=sx: (x * sx) > 2.0 and z < -0.2)
        parts.append(flip)
        parts.append(kit.noink(kit.ellipsoid("eye", (sx * 1.55, -0.2, -2.7), (0.08, 0.07, 0.08), INK, rings=4, sectors=6), 0.2))
    return [kit.join("whale", parts)]


def main(names):
    builders = {"gull": gull, "crab": crab, "dolphin": dolphin, "whale": whale}
    for name in names or builders:
        kit.reset()
        objs = builders[name]()
        kit.export(name, objs, ao_distance=0.2, ao_strength=0.6)


if __name__ == "__main__":
    main(kit.args())

"""Clouds: fair-weather cumulus and the storm's heavy cloud, each one smooth puffy surface
(overlapping puffs melted together by a voxel remesh) with a flat bottom.

    blender -b --factory-startup --python art/blender/sky.py [-- clouds]
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402


def cloud(name, seed, width=6.0, height=2.6, puffs=9, flat=0.0, color="ffffff", base_color=None):
    """A cloud about `width` across: big puffs along the middle, smaller ones round them,
    melted into one surface; flat underneath at y = flat."""
    rng = random.Random(seed)
    parts = []
    # A wide, low base of flattened puffs.
    for i in range(puffs):
        t = (i / (puffs - 1)) * 2 - 1 if puffs > 1 else 0.0
        x = t * width * 0.4 + rng.uniform(-0.2, 0.2)
        r = (1.0 - 0.35 * abs(t)) * height * 0.42 * rng.uniform(0.85, 1.1)
        z = rng.uniform(-0.5, 0.5) * width * 0.12
        parts.append(kit.ellipsoid("base", (x, r * 0.5, z), (r * 1.3, r * 0.75, r * 1.1), color, rings=10, sectors=14))
    # Round heads bubbling up on top, biggest in the middle: the cauliflower crown.
    for i in range(puffs + 3):
        t = rng.uniform(-1, 1) * (1 - 0.1 * rng.random())
        x = t * width * 0.33
        r = height * (0.42 - 0.2 * abs(t)) * rng.uniform(0.8, 1.15)
        y = height * (0.62 - 0.35 * abs(t)) + rng.uniform(-0.1, 0.1) * height
        z = rng.uniform(-0.4, 0.4) * width * 0.1
        parts.append(kit.ellipsoid("head", (x, y, z), (r, r, r), color, rings=10, sectors=14))
    ob = kit.join(name, parts)
    rm = ob.modifiers.new("remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = width / 60.0
    kit.apply_all(ob)
    # Flatten the underside.
    for v in ob.data.vertices:
        x, y, z = kit.G(v.co)
        if y < flat + 0.15:
            v.co = kit.V(x, max(y, flat) if y > flat - 0.2 else flat, z)
    dec = ob.modifiers.new("decimate", "DECIMATE")
    dec.ratio = 0.22
    kit.apply_all(ob)
    sm = ob.modifiers.new("smooth", "SMOOTH")
    sm.iterations = 1
    sm.factor = 0.4
    kit.apply_all(ob)
    kit.paint(ob, color)
    if base_color:
        kit.paint_where(ob, base_color, lambda x, y, z: y < flat + 0.25)
    kit.smooth_by_angle(ob, 85)
    return ob


def main(names):
    def clouds():
        out = [cloud("cloud_%d" % i, 10 + i, width=[6.0, 5.0, 7.0, 4.2][i], height=[2.6, 2.4, 2.8, 2.2][i], puffs=[9, 7, 11, 6][i]) for i in range(4)]
        out += [cloud("storm_%d" % i, 30 + i, width=8.0, height=2.4, puffs=12, color=["8e96a3", "7c8492"][i], base_color=["6e7682", "626a76"][i]) for i in range(2)]
        return out

    builders = {"clouds": clouds}
    for name in names or builders:
        kit.reset()
        objs = builders[name]()
        kit.export(name, objs, ao=False)


if __name__ == "__main__":
    main(kit.args())

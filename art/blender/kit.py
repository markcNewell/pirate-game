"""Shared kit for the asset scripts in art/blender/.

Each asset script imports this, builds its model and calls export(). Run them through
tools/build_models.sh, which calls

    blender -b --factory-startup --python art/blender/<name>.py

Coordinates: every helper here takes GODOT coordinates (Y up, the model faces -Z, +X is its
right), the same numbers as the game's code, and converts to Blender's Z-up frame itself. The
glTF exporter turns them back, so a point written as (x, y, z) here lands at (x, y, z) in Godot.

Colour: faces are coloured by material, one material per colour (see mat()). On export the
colours are written to the vertices as raw sRGB numbers, which is what the game's toon shader
expects (the same as MeshBuilder), and soft shadow in creases (ambient occlusion, baked by
Cycles) goes in the vertex alpha. Materials themselves are not exported.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT_DIR = os.path.join(ROOT, "art", "models")

# The same colours as Toon.PALETTE in game/util/toon.gd.
PALETTE = {
    "hull": "a0522d",
    "hull_dark": "7d3c20",
    "bottom": "6e2a22",
    "stripe": "ffd23a",
    "deck": "e0a868",
    "rail": "8a4524",
    "mast": "b07a42",
    "rope": "caa36a",
    "trim": "2a1e1a",
    "sail": "fff8ea",
    "flag": "1d1d26",
    "bone": "f4efe2",
    "lantern": "ffe08a",
    "sand": "e6c88c",
    "wet_sand": "cdae74",
    "grass": "4c9a3b",
    "grass_dark": "3d8231",
    "rock": "8f8b86",
    "trunk": "b07a42",
    "leaf": "3faa4c",
    "cloud": "ffffff",
    "gold": "ffd23a",
    "iron": "2e2e36",
}

# Ship parts are painted in slot colours the game swaps for the ship's palette (a crew's
# colours or the skeleton ship's): Models.SLOTS in game/util/models.gd lists the same names.
SLOTS = ["hull", "hull_dark", "bottom", "stripe", "deck", "rail", "mast", "rope", "trim", "sail",
         "flag", "bone", "lantern", "gold", "iron"]


def slot(name):
    """The marker colour for a palette slot (see SLOTS)."""
    return "f0%02xf1" % (16 + 8 * SLOTS.index(name))


# Marker colours the game swaps for a player's own (Models.recolor in game/util/models.gd).
SHIRT = "ff00ff"
SHIRT_DARK = "b000b0"
SKIN = "00ffff"
SKIN_DARK = "00b0b0"


def hexrgb(h):
    """'a0522d' or '#a0522d' or a palette name -> (r, g, b) sRGB floats."""
    h = PALETTE.get(h, h).lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def shade(h, k):
    """A colour darkened (k < 1) or lightened (k > 1), as hex."""
    r, g, b = hexrgb(h)
    if k <= 1.0:
        c = (r * k, g * k, b * k)
    else:
        t = k - 1.0
        c = (r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t)
    return "".join("%02x" % round(max(0.0, min(1.0, v)) * 255) for v in c)


def mix(a, b, t):
    ca, cb = hexrgb(a), hexrgb(b)
    return "".join("%02x" % round((x + (y - x) * t) * 255) for x, y in zip(ca, cb))


# ---------------------------------------------------------------------------------------------
# Scene


def reset():
    """An empty scene in metres."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    random.seed(7)


def V(x, y=None, z=None):
    """Godot (x, y, z) -> Blender Vector (x, -z, y)."""
    if y is None:
        x, y, z = x
    return Vector((x, -z, y))


def G(v):
    """Blender Vector -> Godot (x, y, z) tuple."""
    return (v.x, v.z, -v.y)


def link(obj, collection=None):
    (collection or bpy.context.scene.collection).objects.link(obj)
    return obj


def obj_from_bmesh(name, bm, color=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    if color is not None:
        paint(ob, color)
    return ob


def active(ob):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)


# ---------------------------------------------------------------------------------------------
# Colour


def mat(color, shade=1.0):
    """The material for one colour (hex, palette name or slot marker), darkened by `shade`
    (written to the vertex alpha with the crease shadow, so slot colours stay swappable).
    Blender shows it in linear light; the export writes the sRGB numbers."""
    h = PALETTE.get(color, color).lstrip("#").lower()
    name = "c_%s_%.3f" % (h, shade)
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        r, g, b = hexrgb(h)
        lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in (r, g, b)]
        m.diffuse_color = (*(c * shade for c in lin), 1.0)
        m["hex"] = h
        m["shade"] = shade
    return m


def _slot(ob, color, shade=1.0):
    m = mat(color, shade)
    for i, s in enumerate(ob.data.materials):
        if s == m:
            return i
    ob.data.materials.append(m)
    return len(ob.data.materials) - 1


def paint(ob, color, shade=1.0):
    """Every face of `ob` in one colour."""
    ob.data.materials.clear()
    ob.data.materials.append(mat(color, shade))
    for p in ob.data.polygons:
        p.material_index = 0
    return ob


def paint_where(ob, color, test, shade=1.0):
    """Faces whose centre (Godot coordinates) passes test(x, y, z) get `color`."""
    i = _slot(ob, color, shade)
    mw = ob.matrix_world
    for p in ob.data.polygons:
        if test(*G(mw @ p.center)):
            p.material_index = i
    return ob


def orient(ob, outward):
    """Turn every face of `ob` to face outward(x, y, z) -> (dx, dy, dz) (Godot), for open
    surfaces whose winding Blender cannot guess."""
    for p in ob.data.polygons:
        n = G(ob.matrix_world.to_3x3() @ p.normal)
        d = outward(*G(ob.matrix_world @ p.center))
        if n[0] * d[0] + n[1] * d[1] + n[2] * d[2] < 0:
            p.flip()
    ob.data.update()
    return ob


def noink(ob, weight=0.0):
    """Draw this part's ink outline thinner (weight < 1) or not at all (0): small details on a
    face or a coat, which would drown in a full-width line. Survives join()."""
    attr = ob.data.attributes.get("ink") or ob.data.attributes.new("ink", "FLOAT", "FACE")
    for i in range(len(ob.data.polygons)):
        attr.data[i].value = 1.0 - weight
    return ob


def paint_faces(ob, color, faces, shade=1.0):
    i = _slot(ob, color, shade)
    for f in faces:
        ob.data.polygons[f].material_index = i
    return ob


# ---------------------------------------------------------------------------------------------
# Shapes (all positions in Godot coordinates)


def box(name, centre, size, color, bevel=0.0, segments=2, rot=None):
    """A box `size` (full extents) at `centre`, optionally bevelled and rotated
    (rot = Godot Euler radians, applied X then Y then Z)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size
    bmesh.ops.scale(bm, vec=Vector((sx, sz, sy)), verts=bm.verts)
    ob = obj_from_bmesh(name, bm, color)
    if bevel > 0:
        bevel_mod(ob, bevel, segments)
    place(ob, centre, rot)
    return ob


def place(ob, at, rot=None):
    """Move `ob` to Godot point `at`, rotated by Godot Euler `rot` (radians, order XYZ...
    applied as Godot does: Y * X * Z)."""
    m = Matrix.Identity(4)
    if rot is not None:
        m = godot_basis(rot).to_4x4()
    m.translation = V(at)
    ob.matrix_world = m @ ob.matrix_world
    # Bake it in, so every vertex reads in world coordinates (scripts shape vertices directly).
    transform_apply(ob)
    return ob


def godot_basis(rot):
    """Godot Euler (x, y, z) radians, YXZ order, as a Blender rotation matrix."""
    rx, ry, rz = rot
    # In Blender's frame: Godot X -> Blender X, Godot Y -> Blender Z, Godot Z -> Blender -Y.
    mx = Matrix.Rotation(rx, 3, "X")
    my = Matrix.Rotation(ry, 3, "Z")
    mz = Matrix.Rotation(-rz, 3, "Y")
    return my @ mx @ mz


def lathe(name, profile, sides, color, centre=(0, 0, 0), axis="y", caps=True, smooth=True):
    """A solid of revolution round the Godot Y axis (or "x" / "z"): profile is [(radius, h)]
    from bottom to top. Caps close the ends where the radius is above zero."""
    bm = bmesh.new()
    rings = []
    for r, h in profile:
        ring = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            ring.append(bm.verts.new(_axis_point(axis, r * math.cos(a), h, r * math.sin(a))))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if caps:
        for ring, (r, _h) in ((rings[0], profile[0]), (rings[-1], profile[-1])):
            if r > 1e-6:
                bm.faces.new(ring)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bmesh(name, bm, color)
    place(ob, centre)
    if smooth:
        smooth_by_angle(ob, 50)
    return ob


def _axis_point(axis, u, h, w):
    # Godot point for a lathe sample: h along the axis, (u, w) across it.
    if axis == "y":
        return V(u, h, w)
    if axis == "x":
        return V(h, u, w)
    return V(u, w, h)


def tube(name, points, radii, sides, color, caps=True, twist=0.0):
    """A tube through Godot `points` with a radius per point (or one radius), smooth round."""
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(points)
    pts = [V(p) for p in points]
    bm = bmesh.new()
    rings = []
    prev_side = None
    for k, p in enumerate(pts):
        if k == 0:
            d = pts[1] - pts[0]
        elif k == len(pts) - 1:
            d = pts[-1] - pts[-2]
        else:
            d = (pts[k + 1] - pts[k - 1])
        d.normalize()
        if prev_side is None:
            ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            side = d.cross(ref).normalized()
        else:
            # Parallel transport, so the tube does not twist along a bend.
            side = (prev_side - d * prev_side.dot(d)).normalized()
        prev_side = side
        up = d.cross(side).normalized()
        ring = []
        for i in range(sides):
            a = 2 * math.pi * i / sides + twist * k
            ring.append(bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * radii[k]))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if caps:
        if radii[0] > 1e-6:
            bm.faces.new(list(reversed(rings[0])))
        if radii[-1] > 1e-6:
            bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bmesh(name, bm, color)
    smooth_by_angle(ob, 60)
    return ob


def ellipsoid(name, centre, radii, color, rings=8, sectors=12):
    """A UV sphere scaled to Godot radii (rx, ry, rz)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=sectors, v_segments=rings, radius=1.0)
    rx, ry, rz = radii
    bmesh.ops.scale(bm, vec=Vector((rx, rz, ry)), verts=bm.verts)
    ob = obj_from_bmesh(name, bm, color)
    place(ob, centre)
    smooth_by_angle(ob, 80)
    return ob


def prism(name, outline, depth, color, centre=(0, 0, 0), plane="xy", bevel=0.0, segments=2):
    """A flat shape: a 2D outline [(u, v)] extruded `depth` thick, centred on its plane.
    plane "xy": outline in Godot X/Y, thickness along Z (a sign, a blade seen from the side);
    "xz": outline seen from above, thickness along Y; "zy": outline in Z/Y, thickness along X."""
    bm = bmesh.new()
    front, back = [], []
    for u, w in outline:
        for lst, d in ((front, depth / 2), (back, -depth / 2)):
            if plane == "xy":
                p = V(u, w, d)
            elif plane == "xz":
                p = V(u, d, w)
            else:
                p = V(d, w, u)
            lst.append(bm.verts.new(p))
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bmesh(name, bm, color)
    if bevel > 0:
        bevel_mod(ob, bevel, segments)
    place(ob, centre)
    return ob


def loft(name, rings, color, sides=16, power=2.0, cap_bottom=True, cap_top=True):
    """A body stacked from horizontal rings: [(y, rx, rz, x_off, z_off)], bottom to top.
    `power` above 2 squares the rings off (a superellipse): chests, crates, rocks."""
    bm = bmesh.new()
    loops = []
    for y, rx, rz, xo, zo in rings:
        loop = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            ca, sa = math.cos(a), math.sin(a)
            e = 2.0 / power
            x = rx * math.copysign(abs(ca) ** e, ca)
            z = rz * math.copysign(abs(sa) ** e, sa)
            loop.append(bm.verts.new(V(xo + x, y, zo + z)))
        loops.append(loop)
    for a, b in zip(loops, loops[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_bottom:
        bm.faces.new(list(reversed(loops[0])))
    if cap_top:
        bm.faces.new(loops[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bmesh(name, bm, color)


def grid_surface(name, rows, color, close_u=False):
    """A surface through a grid of Godot points (rows of equal length)."""
    bm = bmesh.new()
    vs = [[bm.verts.new(V(p)) for p in row] for row in rows]
    for a, b in zip(vs, vs[1:]):
        n = len(a)
        for i in range(n if close_u else n - 1):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    return obj_from_bmesh(name, bm, color)


# ---------------------------------------------------------------------------------------------
# Modifiers and finishing


def bevel_mod(ob, width, segments=2, angle=40, limit="ANGLE"):
    m = ob.modifiers.new("bevel", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = limit
    m.angle_limit = math.radians(angle)
    m.harden_normals = False
    m.miter_outer = "MITER_ARC"
    return m


def subsurf(ob, levels=1):
    m = ob.modifiers.new("subsurf", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    return m


def apply_all(ob):
    active(ob)
    for m in list(ob.modifiers):
        if m.type == "ARMATURE":
            continue
        bpy.ops.object.modifier_apply(modifier=m.name)
    return ob


def smooth_by_angle(ob, degrees=40):
    """Smooth shading across soft bends, hard edges where faces meet sharply."""
    me = ob.data
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(degrees))
    return ob


def flat(ob):
    ob.data.shade_flat()
    return ob


def displace(ob, strength, scale, seed=0, subdivide=0):
    """Lumpy noise (rocks, foliage)."""
    if subdivide:
        m = ob.modifiers.new("sub", "SUBSURF")
        m.levels = subdivide
        m.subdivision_type = "SIMPLE"
    tex = bpy.data.textures.new("noise%d" % seed, "VORONOI")
    tex.noise_scale = scale
    m = ob.modifiers.new("disp", "DISPLACE")
    m.texture = tex
    m.strength = strength
    m.mid_level = 0.5
    m.texture_coords = "GLOBAL"
    ob.location += Vector((seed * 13.7, seed * 7.1, 0))
    apply_all(ob)
    ob.location -= Vector((seed * 13.7, seed * 7.1, 0))
    return ob


def jitter(ob, amount, seed=0):
    """Nudge every vertex a little, for a hand-made look."""
    rng = random.Random(seed)
    for v in ob.data.vertices:
        v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * amount
    return ob


def join(name, objs):
    objs = [o for o in objs if o is not None]
    for o in objs:
        apply_all(o)
    active(objs[0])
    for o in objs[1:]:
        o.select_set(True)
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def transform_apply(ob):
    active(ob)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def mirror_x(ob):
    """A copy of `ob` mirrored across Godot X = 0 (left from right)."""
    c = ob.copy()
    c.data = ob.data.copy()
    link(c)
    c.matrix_world = Matrix.Scale(-1, 4, Vector((1, 0, 0))) @ ob.matrix_world
    transform_apply(c)
    active(c)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.flip_normals()
    bpy.ops.object.mode_set(mode="OBJECT")
    return c


def duplicate(ob, at=None, rot=None):
    """A copy of `ob`; with `at`/`rot`, moved there (rotation about the Godot origin first)."""
    c = ob.copy()
    c.data = ob.data.copy()
    link(c)
    if at is not None or rot is not None:
        m = Matrix.Identity(4)
        if rot is not None:
            m = godot_basis(rot).to_4x4()
        m.translation = V(at or (0, 0, 0))
        c.matrix_world = m @ ob.matrix_world
    return c


# ---------------------------------------------------------------------------------------------
# Baking and export


def _hemisphere(n):
    """n directions spread evenly over the +Z hemisphere, denser toward the pole (cosine
    weighted), always the same."""
    out = []
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        u = (i + 0.5) / n
        r = math.sqrt(u)
        a = i * golden
        out.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(max(0.0, 1 - u)))))
    return out


def bake_ao(objs, distance=0.6, rays=48):
    """Soft shadow in creases, per vertex, by casting rays from each vertex over the
    hemisphere round its normal and counting what they hit within `distance`. Every object
    shadows every other. Written to an "AO" attribute (1 open, 0 fully enclosed)."""
    from mathutils.bvhtree import BVHTree
    bm_all = bmesh.new()
    for ob in objs:
        apply_all(ob)
        tmp = ob.data.copy()
        tmp.transform(ob.matrix_world)
        bm_all.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    tree = BVHTree.FromBMesh(bm_all)
    bm_all.free()
    dirs = _hemisphere(rays)
    for ob in objs:
        me = ob.data
        mw = ob.matrix_world
        nm = mw.to_3x3().inverted().transposed()
        vals = []
        # A part marked no_ao still shades its neighbours but takes no shade itself (cloth,
        # which would only look dirty with it).
        for v in (me.vertices if not ob.get("no_ao") else []):
            p = mw @ v.co
            n = (nm @ v.normal).normalized()
            t = n.orthogonal().normalized()
            b = n.cross(t)
            origin = p + n * 0.002
            occ = 0.0
            for d in dirs:
                w = t * d.x + b * d.y + n * d.z
                hit = tree.ray_cast(origin, w, distance)
                if hit[0] is not None:
                    occ += 1.0 - (hit[3] / distance) ** 0.5 * 0.5
            vals.append(1.0 - occ / len(dirs))
        if "AO" in me.color_attributes:
            me.color_attributes.remove(me.color_attributes["AO"])
        attr = me.color_attributes.new("AO", "FLOAT_COLOR", "CORNER")
        for loop in me.loops:
            a = vals[loop.vertex_index] if vals else 1.0
            attr.data[loop.index].color = (a, a, a, 1.0)


# How strongly the toon shader darkens by the vertex alpha (crease_shadow in toon.gdshader).
CREASE = 0.55


def write_colors(ob, ao_strength=1.0):
    """Material colours -> a "Col" corner attribute of sRGB numbers, AO in its alpha."""
    me = ob.data
    ao = me.color_attributes.get("AO")
    ao_vals = [d.color[0] for d in ao.data] if ao else None
    if "Col" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["Col"])
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for p in me.polygons:
        m = me.materials[p.material_index] if me.materials else None
        rgb = hexrgb(m["hex"]) if m is not None and "hex" in m else (1, 0, 1)
        shade = m.get("shade", 1.0) if m is not None else 1.0
        for li in p.loop_indices:
            a = 1.0
            if ao_vals is not None:
                a = 1.0 - (1.0 - ao_vals[li]) * ao_strength
            if shade != 1.0:
                # The shader darkens by mix(1, alpha, CREASE): fold the shade into that.
                total = (1.0 - CREASE * (1.0 - a)) * shade
                a = max(0.0, 1.0 - (1.0 - total) / CREASE)
            col.data[li].color = (*rgb, a)
    if ao is not None:
        me.color_attributes.remove(me.color_attributes["AO"])
    me.color_attributes.active_color = me.color_attributes["Col"]
    me.color_attributes.render_color_index = me.color_attributes.active_color_index
    # Outline weight per corner, as the U of the first UV map (Models reads it). The "ink"
    # attribute holds how much LESS ink a face gets, so parts without it default to full.
    less = me.attributes.get("ink")
    less = [d.value for d in less.data] if less is not None and less.domain == "FACE" else None
    for uv in list(me.uv_layers):
        me.uv_layers.remove(uv)
    uv = me.uv_layers.new(name="outline")
    for p in me.polygons:
        w = 1.0 - (less[p.index] if less else 0.0)
        for li in p.loop_indices:
            uv.data[li].uv = (w, 0.0)


def export(name, objs=None, animations=False, ao=True, ao_strength=1.0, ao_distance=0.6):
    """Write art/models/<name>.glb from `objs` (default: every mesh and armature)."""
    if objs is None:
        objs = [o for o in bpy.context.scene.objects if o.type in ("MESH", "ARMATURE")]
    meshes = [o for o in objs if o.type == "MESH"]
    for ob in meshes:
        apply_all(ob)
    if ao:
        bake_ao(meshes, distance=ao_distance)
    for ob in meshes:
        write_colors(ob, ao_strength if ao else 0.0)
    for o in bpy.context.view_layer.objects:
        o.select_set(o in objs)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="NONE",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_normals=True,
        export_tangents=False,
        export_texcoords=True,
        export_yup=True,
        export_skins=True,
        export_animations=animations,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_optimize_animation_size=True,
        export_extras=False,
    )
    tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    print("EXPORTED %s (%d triangles)" % (os.path.relpath(path, ROOT), tris))
    return path


def args():
    """Arguments after `--` on the Blender command line."""
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

"""The humanoid rig every person in the game shares (pirates, skeletons, the merchant), its
weights helpers and its animations.

Bones are named in Godot style (snake case, _l / _r). The character faces -Z with its right
hand toward +X (Godot coordinates, as everywhere in the kit).

Poses are written as rotations about the GODOT axes, per bone, in degrees, as Euler (x, y, z)
in Godot's YXZ order. A bone's rotation is about its own joint and follows its parent, but its
axes are the rest pose's world axes: so (+30, 0, 0) on a hanging thigh always swings it forward,
whatever the bone's roll. Handy signs:
    +x: a hanging limb swings forward; the spine leans back; the head tilts up.
    +y: turn to the character's left.
    +z: the right arm lifts out to the side (the left arm needs -z); the body leans left.
Upper arms are measured from hanging straight down (see HANG), not from the A of the rest pose.
"""

import math

import bpy
from mathutils import Euler, Matrix, Vector

import kit
from kit import V

FPS = 30

# name: (head, tail, parent), Godot coordinates. A-pose arms (about 50 degrees down).
BONES = {
    "root": ((0, 0, 0), (0, 0.25, 0), None),
    "hips": ((0, 0.9, 0), (0, 1.04, 0), "root"),
    "spine": ((0, 1.04, 0), (0, 1.2, 0), "hips"),
    "chest": ((0, 1.2, 0), (0, 1.44, 0), "spine"),
    "neck": ((0, 1.44, 0.0), (0, 1.54, -0.01), "chest"),
    "head": ((0, 1.54, -0.01), (0, 1.8, -0.01), "neck"),
    "upper_arm_r": ((0.2, 1.4, 0.0), (0.37, 1.18, 0.0), "chest"),
    "forearm_r": ((0.37, 1.18, 0.0), (0.5, 0.97, -0.02), "upper_arm_r"),
    "hand_r": ((0.5, 0.97, -0.02), (0.56, 0.87, -0.03), "forearm_r"),
    "upper_arm_l": ((-0.2, 1.4, 0.0), (-0.37, 1.18, 0.0), "chest"),
    "forearm_l": ((-0.37, 1.18, 0.0), (-0.5, 0.97, -0.02), "upper_arm_l"),
    "hand_l": ((-0.5, 0.97, -0.02), (-0.56, 0.87, -0.03), "forearm_l"),
    "thigh_r": ((0.1, 0.9, 0.0), (0.11, 0.5, -0.01), "hips"),
    "shin_r": ((0.11, 0.5, -0.01), (0.115, 0.1, 0.02), "thigh_r"),
    "foot_r": ((0.115, 0.1, 0.02), (0.12, 0.03, -0.15), "shin_r"),
    "thigh_l": ((-0.1, 0.9, 0.0), (-0.11, 0.5, -0.01), "hips"),
    "shin_l": ((-0.11, 0.5, -0.01), (-0.115, 0.1, 0.02), "thigh_l"),
    "foot_l": ((-0.115, 0.1, 0.02), (-0.12, 0.03, -0.15), "shin_l"),
}

UPPER_BODY = ["spine", "chest", "neck", "head", "upper_arm_r", "forearm_r", "hand_r",
              "upper_arm_l", "forearm_l", "hand_l"]


def joint(name):
    return Vector(BONES[name][0])


def build_armature(name="rig"):
    arm = bpy.data.armatures.new(name)
    ob = kit.link(bpy.data.objects.new(name, arm))
    kit.active(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    for b, (head, tail, parent) in BONES.items():
        eb = arm.edit_bones.new(b)
        eb.head = V(head)
        eb.tail = V(tail)
        # Roll so the bone's X axis lies as near the world X as it can: poses are converted
        # anyway (see pose_basis), this only keeps things tidy in Blender.
        eb.align_roll(Vector((0, 0, 1)) if abs((eb.tail - eb.head).normalized().z) < 0.7 else Vector((0, -1, 0)))
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


# ---------------------------------------------------------------------------------------------
# Weights


def seg_t(p, a, b):
    """How far along a->b the point p projects (0..1, clamped) and its distance from the line."""
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return t, (a + ab * t - p).length


def set_weights(ob, fn):
    """fn(Vector godot_point) -> {bone: weight}; written as vertex groups (normalised)."""
    groups = {}
    for v in ob.data.vertices:
        x, y, z = kit.G(ob.matrix_world @ v.co)
        w = fn(Vector((x, y, z)))
        total = sum(w.values()) or 1.0
        for b, val in w.items():
            if val <= 0:
                continue
            if b not in groups:
                groups[b] = ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)
            groups[b].add([v.index], val / total, "REPLACE")
    return ob


def rigid(bone):
    return lambda p: {bone: 1.0}


def blend(a, b, t, soft=0.5):
    """Weights across a joint: `t` in -1..1 around it, 0 at the joint."""
    k = max(0.0, min(1.0, 0.5 + t / (2 * soft)))
    return {a: 1.0 - k, b: k}


def limb_weights(side, upper, lower, end, start_parent=None, soft=0.05):
    """Weights for a limb (arm or leg) of three bones: blended at each joint over `soft` m."""
    s = "_" + side
    a, b, c = joint(upper + s), joint(lower + s), joint(end + s)

    def fn(p):
        t1, _ = seg_t(p, a, b)
        d_elbow = (p - b).dot((c - a).normalized())
        if d_elbow < -soft:
            w = {upper + s: 1.0}
            if start_parent and t1 < 0.25:
                w = blend(start_parent, upper + s, (t1 - 0.12) / 0.12 * soft, soft)
            return w
        if d_elbow < soft:
            return blend(upper + s, lower + s, d_elbow, soft)
        d_wrist = (p - c).dot((c - b).normalized())
        if d_wrist < -soft * 0.6:
            return {lower + s: 1.0}
        if d_wrist < soft * 0.6:
            return blend(lower + s, end + s, d_wrist, soft * 0.6)
        return {end + s: 1.0}
    return fn


def torso_weights(p):
    """Hips -> spine -> chest by height, the neck at the top, shoulders shared with the arms."""
    y = p.y
    if y < 1.0:
        w = {"hips": 1.0}
    elif y < 1.1:
        w = blend("hips", "spine", (y - 1.05) / 0.05 * 0.05, 0.05)
    elif y < 1.24:
        w = blend("spine", "chest", (y - 1.2) / 0.05 * 0.05, 0.05)
    elif y < 1.47:
        w = {"chest": 1.0}
    else:
        w = blend("chest", "neck", (y - 1.49) / 0.03 * 0.03, 0.03)
    # Shoulders: share with the upper arm so a raised arm drags the cloth a little.
    for side, sx in (("r", 1), ("l", -1)):
        j = joint("upper_arm_" + side)
        d = (p - j).length
        if p.x * sx > 0.12 and d < 0.11 and y > 1.3:
            k = max(0.0, 1.0 - d / 0.11) * 0.6
            w = {b: v * (1 - k) for b, v in w.items()}
            w["upper_arm_" + side] = w.get("upper_arm_" + side, 0.0) + k
    return w


def bind(ob, armature):
    ob.parent = armature
    m = ob.modifiers.new("rig", "ARMATURE")
    m.object = armature
    return ob


# ---------------------------------------------------------------------------------------------
# Poses and animation


def _godot_rot(r):
    rx, ry, rz = (math.radians(a) for a in r)
    return kit.godot_basis((rx, ry, rz))


def pose_basis(armature, bone, rot_deg):
    """The pose-space rotation (bone local) that turns `bone` by Godot Euler `rot_deg`
    expressed in rest-pose world axes."""
    rest = armature.data.bones[bone].matrix_local.to_3x3()
    q = _godot_rot(rot_deg)
    return (rest.inverted() @ q @ rest).to_quaternion()


# The rest pose holds the arms out in an A; poses measure arm angles from hanging straight down
# instead, so an upper arm's z is how far it is raised out to the side.
HANG = {"upper_arm_r": -37.7, "upper_arm_l": 37.7}


def apply_pose(armature, pose, frame):
    """Key every bone at `frame`: bones not named in `pose` hang at rest (arms down)."""
    for pb in armature.pose.bones:
        pb.rotation_mode = "QUATERNION"
        rot = list(pose.get(pb.name, (0, 0, 0)))
        rot[2] += HANG.get(pb.name, 0.0)
        pb.rotation_quaternion = pose_basis(armature, pb.name, rot)
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        if pb.name == "root":
            off = pose.get("_root", (0, 0, 0))
            rest = armature.data.bones["root"].matrix_local.to_3x3()
            pb.location = rest.inverted() @ V(off)
            pb.keyframe_insert("location", frame=frame)


def mirror(pose):
    """The pose with left and right swapped (x rotations kept, y and z flipped)."""
    out = {}
    for b, r in pose.items():
        if b == "_root":
            out[b] = (-r[0], r[1], r[2])
            continue
        nb = b[:-2] + ("_l" if b.endswith("_r") else "_r") if b[-2:] in ("_r", "_l") else b
        out[nb] = (r[0], -r[1], -r[2])
    return out


def merge(*poses):
    out = {}
    for p in poses:
        out.update(p)
    return out


def action(armature, name, keys, loop=True):
    """An animation from [(time_seconds, pose)]. For loops the first pose is repeated at the end
    time given by the last key."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if armature.animation_data is None:
        armature.animation_data_create()
    armature.animation_data.action = act
    for t, pose in keys:
        apply_pose(armature, pose, 1 + round(t * FPS))
    end = 1 + round(keys[-1][0] * FPS)
    act.use_frame_range = True
    act.frame_start = 1
    act.frame_end = end
    for fc in _fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.easing = "AUTO"
    track = armature.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, act)
    armature.animation_data.action = None
    return act


def _fcurves(act):
    # Blender 4.4+ keeps keys in layered channelbags.
    if hasattr(act, "layers") and act.layers:
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    yield from bag.fcurves
    else:
        yield from act.fcurves


# Arms hang relaxed from the A-pose: down to the sides, elbows a touch bent.
ARMS_DOWN = {
    "upper_arm_r": (0, 0, 5), "upper_arm_l": (0, 0, -5),
    "forearm_r": (12, 0, 0), "forearm_l": (12, 0, 0),
    "hand_r": (0, 0, 5), "hand_l": (0, 0, -5),
}


def cycle(period, poses_at):
    """Keys from a function of phase 0..1, sampled at 8 points round the cycle."""
    n = 8
    return [(period * i / n, poses_at(i / n)) for i in range(n + 1)]


def s(phase, offset=0.0):
    return math.sin(2 * math.pi * (phase + offset))


def c(phase, offset=0.0):
    return math.cos(2 * math.pi * (phase + offset))


def anim_idle(arm):
    def at(p):
        b = s(p)
        return merge(ARMS_DOWN, {
            "chest": (-2 + 1.5 * b, 0, 0),
            "spine": (0.5 * b, 0, 0),
            "head": (2 - 1.5 * b, 4 * s(p, 0.2) * 0.3, 0),
            "upper_arm_r": (2 * b, 0, 5 + 1.5 * b), "upper_arm_l": (2 * b, 0, -5 - 1.5 * b),
            "thigh_r": (0, 0, 2), "thigh_l": (0, 0, -2),
            "_root": (0, -0.006 + 0.006 * b, 0),
        })
    return action(arm, "idle", cycle(2.4, at))


def gait(stride, lift, lean, arm_swing, bounce, knee):
    """A walking or running cycle: phase 0 = right foot planted forward."""
    def at(p):
        r = c(p)          # +1: right leg forward
        lift_r = max(0.0, s(p, 0.5))   # right leg lifting while it swings forward (back half)
        lift_l = max(0.0, s(p))
        return merge(ARMS_DOWN, {
            "thigh_r": (stride * r + lift * lift_r, 0, 2),
            "thigh_l": (-stride * r + lift * lift_l, 0, -2),
            "shin_r": (-knee * lift_r - 6, 0, 0),
            "shin_l": (-knee * lift_l - 6, 0, 0),
            "foot_r": (-8 * r + 10 * lift_r, 0, 0),
            "foot_l": (8 * r + 10 * lift_l, 0, 0),
            "hips": (0, 6 * r * stride / 30, 2 * s(p, 0.25)),
            "spine": (-lean, -4 * r * stride / 30, 0),
            "chest": (-lean * 0.5, -6 * r * stride / 30, 0),
            "head": (lean * 1.2, 8 * r * stride / 30, 0),
            "upper_arm_r": (-arm_swing * r, 0, 7), "upper_arm_l": (arm_swing * r, 0, -7),
            "forearm_r": (20 + 25 * max(0.0, -r), 0, 0), "forearm_l": (20 + 25 * max(0.0, r), 0, 0),
            "_root": (0, bounce * abs(s(p, 0.25)) - bounce * 0.5, 0),
        })
    return at


def anim_walk(arm):
    return action(arm, "walk", cycle(0.62, gait(32, 22, 6, 34, 0.05, 55)))


def anim_run(arm):
    return action(arm, "run", cycle(0.5, gait(46, 30, 14, 55, 0.09, 95)))


def anim_jump(arm):
    pose = merge(ARMS_DOWN, {
        "thigh_r": (45, 0, 4), "shin_r": (-70, 0, 0), "foot_r": (20, 0, 0),
        "thigh_l": (5, 0, -4), "shin_l": (-35, 0, 0), "foot_l": (10, 0, 0),
        "upper_arm_r": (25, 0, 30), "upper_arm_l": (-15, 0, -25),
        "forearm_r": (40, 0, 0), "forearm_l": (30, 0, 0),
        "spine": (-6, 0, 0), "head": (8, 0, 0),
    })
    return action(arm, "jump", [(0.0, pose), (0.5, pose)])


def anim_swim(arm):
    """Treading water: legs kicking slowly, arms sweeping wide in front."""
    def at(p):
        return {
            "spine": (-18, 0, 0), "chest": (-6, 0, 0), "head": (28, 0, 0),
            "thigh_r": (10 + 25 * s(p), 0, 6), "thigh_l": (10 - 25 * s(p), 0, -6),
            "shin_r": (-30 - 25 * max(0.0, c(p)), 0, 0), "shin_l": (-30 - 25 * max(0.0, -c(p)), 0, 0),
            "foot_r": (30, 0, 0), "foot_l": (30, 0, 0),
            "upper_arm_r": (60, -25 * s(p), 20 + 15 * c(p)),
            "upper_arm_l": (60, 25 * s(p), -20 - 15 * c(p)),
            "forearm_r": (30, 0, 10), "forearm_l": (30, 0, -10),
            "hand_r": (0, 0, 30 * c(p)), "hand_l": (0, 0, -30 * c(p)),
            "_root": (0, 0.03 * s(p, 0.25), 0),
        }
    return action(arm, "swim", cycle(1.4, at))


def anim_wheel(arm):
    """Both hands on the spokes in front, rocking with the sea."""
    def at(p):
        return {
            "upper_arm_r": (55, 0, 4 + 3 * s(p)), "upper_arm_l": (55, 0, -4 + 3 * s(p)),
            "forearm_r": (35, 0, 0), "forearm_l": (35, 0, 0),
            "hand_r": (0, 0, 20), "hand_l": (0, 0, -20),
            "spine": (-4, 0, 2 * s(p)), "chest": (-2, 0, 0), "head": (4, 0, 0),
            "thigh_r": (4, 0, 4), "thigh_l": (-2, 0, -6),
            "shin_r": (-6, 0, 0), "shin_l": (-4, 0, 0),
        }
    return action(arm, "wheel", cycle(3.0, at))


def anim_haul(arm):
    """Hand over hand on a rope above the head."""
    def at(p):
        a, b = s(p), -s(p)
        return {
            "upper_arm_r": (140 + 22 * a, 0, 8), "upper_arm_l": (140 + 22 * b, 0, -8),
            "forearm_r": (25 - 20 * a, 0, 0), "forearm_l": (25 - 20 * b, 0, 0),
            "spine": (6 + 3 * a, 0, 0), "chest": (4, 0, 0), "head": (12, 0, 0),
            "thigh_r": (14, 0, 4), "thigh_l": (-12, 0, -4),
            "shin_r": (-18, 0, 0), "shin_l": (-6, 0, 0),
            "_root": (0, -0.03, 0),
        }
    return action(arm, "haul", cycle(1.1, at))


def anim_push(arm):
    """Leaning into the capstan bar, stepping."""
    def at(p):
        r = c(p)
        return {
            "spine": (-22, 0, 0), "chest": (-8, 0, 0), "head": (24, 0, 0),
            "upper_arm_r": (70, 0, 6), "upper_arm_l": (70, 0, -6),
            "forearm_r": (40, 0, 0), "forearm_l": (40, 0, 0),
            "thigh_r": (20 * r + 10, 0, 2), "thigh_l": (-20 * r + 10, 0, -2),
            "shin_r": (-25 - 20 * max(0.0, s(p, 0.5)), 0, 0), "shin_l": (-25 - 20 * max(0.0, s(p)), 0, 0),
            "_root": (0, -0.05, 0),
        }
    return action(arm, "push", cycle(1.3, at))


def anim_cannon(arm):
    """Crouched behind a gun, hands on its back end."""
    def at(p):
        return {
            "spine": (-25, 0, 0), "chest": (-8, 0, 0), "head": (28, 0, 0),
            "thigh_r": (55, 0, 10), "thigh_l": (20, 0, -10),
            "shin_r": (-75, 0, 0), "shin_l": (-60, 0, 0),
            "foot_r": (20, 0, 0), "foot_l": (35, 0, 0),
            "upper_arm_r": (65, 0, 8), "upper_arm_l": (65, 0, -8),
            "forearm_r": (35, 0, 0), "forearm_l": (35, 0, 0),
            "_root": (0, -0.2 + 0.01 * s(p), 0),
        }
    return action(arm, "cannon", cycle(2.0, at))


def anim_carry(arm):
    """Upper body only: a chest held in front at belly height."""
    pose = {
        "upper_arm_r": (40, 0, 14), "upper_arm_l": (40, 0, -14),
        "forearm_r": (55, 0, 0), "forearm_l": (55, 0, 0),
        "hand_r": (0, 0, 35), "hand_l": (0, 0, -35),
        "spine": (6, 0, 0), "chest": (4, 0, 0), "head": (-4, 0, 0),
    }
    return action(arm, "carry", [(0.0, pose), (1.0, pose)])


def anim_bucket(arm):
    """Upper body only: a full bucket hanging from the left hand."""
    pose = merge({b: ARMS_DOWN[b] for b in ("upper_arm_r", "forearm_r", "hand_r")}, {
        "upper_arm_l": (6, 0, -14), "forearm_l": (6, 0, 0), "hand_l": (0, 0, 0),
        "spine": (0, 0, -4), "chest": (0, 0, -3),
    })
    return action(arm, "bucket", [(0.0, pose), (1.0, pose)])


def anim_slash(arm):
    """Upper body only: a cutlass cut from the right shoulder across to the left hip."""
    ready = merge(ARMS_DOWN, {"upper_arm_r": (35, 0, 10), "forearm_r": (45, 0, 0)})
    wind = merge(ARMS_DOWN, {
        "upper_arm_r": (120, 20, 60), "forearm_r": (70, 0, 0), "hand_r": (-30, 0, 0),
        "chest": (4, 30, 0), "spine": (0, 12, 0),
    })
    cut = merge(ARMS_DOWN, {
        "upper_arm_r": (55, -50, 5), "forearm_r": (10, 0, 0), "hand_r": (25, 0, 0),
        "chest": (-6, -30, 0), "spine": (-4, -15, 0), "upper_arm_l": (10, 0, -20),
    })
    return action(arm, "slash", [(0.0, ready), (0.12, wind), (0.24, cut), (0.5, ready)], loop=False)


def anim_shoot(arm):
    """Upper body only: pistol raised at arm's length, a kick, and back."""
    aim = merge(ARMS_DOWN, {
        "upper_arm_r": (85, 0, 12), "forearm_r": (5, 0, 0), "hand_r": (0, 0, 0),
        "chest": (0, -12, 0), "head": (0, 10, 0),
    })
    kick = merge(aim, {"upper_arm_r": (100, 0, 12), "forearm_r": (20, 0, 0), "hand_r": (-25, 0, 0)})
    return action(arm, "shoot", [(0.0, aim), (0.06, kick), (0.3, aim), (0.5, aim)], loop=False)


def anim_hurt(arm):
    base = merge(ARMS_DOWN, {})
    hit = merge(ARMS_DOWN, {
        "spine": (12, 0, 4), "chest": (10, 8, 0), "head": (16, -10, 0),
        "upper_arm_r": (-10, 0, 18), "upper_arm_l": (-10, 0, -18),
        "forearm_r": (40, 0, 0), "forearm_l": (40, 0, 0),
    })
    return action(arm, "hurt", [(0.0, base), (0.08, hit), (0.4, base)], loop=False)


def anim_dig(arm):
    """Driving a shovel into the ground and heaving it up."""
    up = {
        "upper_arm_r": (70, -20, 10), "upper_arm_l": (55, 25, -10),
        "forearm_r": (50, 0, 0), "forearm_l": (40, 0, 0),
        "spine": (-10, -10, 0), "chest": (-5, 0, 0), "head": (10, 0, 0),
        "thigh_r": (10, 0, 6), "thigh_l": (-8, 0, -6), "shin_r": (-15, 0, 0),
    }
    down = merge(up, {
        "upper_arm_r": (35, -20, 8), "upper_arm_l": (25, 20, -8),
        "forearm_r": (25, 0, 0), "forearm_l": (20, 0, 0),
        "spine": (-30, -5, 0), "chest": (-12, 0, 0), "head": (30, 0, 0),
        "thigh_r": (35, 0, 6), "shin_r": (-45, 0, 0), "thigh_l": (5, 0, -6), "shin_l": (-25, 0, 0),
        "_root": (0, -0.1, 0),
    })
    return action(arm, "dig", [(0.0, up), (0.35, down), (0.6, down), (1.0, up)])


def anim_hammer(arm):
    """Knocking a patch on: right arm hammering, left hand holding the plank."""
    base = {
        "upper_arm_l": (75, 15, -10), "forearm_l": (30, 0, 0),
        "spine": (-8, 0, 0), "head": (6, 0, 0),
    }
    up = merge(base, {"upper_arm_r": (95, -10, 15), "forearm_r": (85, 0, 0), "hand_r": (-30, 0, 0)})
    hit = merge(base, {"upper_arm_r": (70, -12, 12), "forearm_r": (30, 0, 0), "hand_r": (20, 0, 0)})
    return action(arm, "hammer", [(0.0, up), (0.16, hit), (0.24, hit), (0.45, up)])


def anim_bail(arm):
    """Swinging a bucket of water up and over the side."""
    low = {
        "upper_arm_r": (20, 0, 10), "upper_arm_l": (20, 0, -10),
        "forearm_r": (40, 0, 0), "forearm_l": (40, 0, 0),
        "spine": (-25, 0, 0), "head": (20, 0, 0), "thigh_r": (20, 0, 4), "thigh_l": (20, 0, -4),
        "shin_r": (-30, 0, 0), "shin_l": (-30, 0, 0), "_root": (0, -0.08, 0),
    }
    high = {
        "upper_arm_r": (120, 0, 10), "upper_arm_l": (120, 0, -10),
        "forearm_r": (20, 0, 0), "forearm_l": (20, 0, 0),
        "spine": (8, 0, 0), "head": (5, 0, 0),
    }
    return action(arm, "bail", [(0.0, low), (0.4, high), (0.7, high), (1.1, low)])


ANIMATIONS = [anim_idle, anim_walk, anim_run, anim_jump, anim_swim, anim_wheel, anim_haul,
              anim_push, anim_cannon, anim_carry, anim_bucket, anim_slash, anim_shoot,
              anim_hurt, anim_dig, anim_hammer, anim_bail]


def animate(arm):
    bpy.context.scene.render.fps = FPS
    for a in ANIMATIONS:
        a(arm)


def rest(arm):
    """Back to the rest pose (for baking and binding), with no action playing."""
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    for track in arm.animation_data.nla_tracks:
        track.mute = True

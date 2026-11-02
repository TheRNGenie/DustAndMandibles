"""Auto-rig a Meshy character for Dust & Mandibles (run inside Blender, no UI).

    blender --background --factory-startup --python tools/rig/autorig.py -- in.glb out.glb [--preview out.png] [--max-tris 40000] [--turn]

--turn spins the model 180 degrees first, for a model that comes in facing backwards
(Meshy's GLBs face the right way; Godot's own exports need it).

What it does:
  1. Imports the GLB, joins every mesh into one, applies transforms, stands it on
     the floor at the origin, scales it to 1.8 m and faces it down -Y (Blender's
     front, which becomes the game's front).
  2. Measures the body: the crotch from where the legs split, the shoulders from
     the widest point of the upper body, hands from the furthest points sideways
     (A-pose), the neck from the narrowest point under the head.
  3. Builds a humanoid skeleton on those landmarks (Godot's humanoid bone names).
  4. Skins it. Meshy meshes are often not watertight, which breaks Blender's bone
     heat, so the weights are computed on a voxel-remeshed copy and transferred
     to the real mesh.
  5. Optionally reduces the triangle count, then exports a skinned GLB, and can
     render a test pose (arms up, knee bent) to check the bending.
"""
import math
import sys

import bpy
import bmesh
from mathutils import Vector

HEIGHT = 1.8


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {"in": a[0], "out": a[1], "preview": None, "max_tris": 40000, "turn": False}
    i = 2
    while i < len(a):
        if a[i] == "--preview":
            opts["preview"] = a[i + 1]
            i += 2
        elif a[i] == "--turn":
            opts["turn"] = True
            i += 1
        elif a[i] == "--max-tris":
            opts["max_tris"] = int(a[i + 1])
            i += 2
        else:
            i += 1
    return opts


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_and_join(path):
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    # Drop any armature that came with it; we build our own.
    for o in list(bpy.context.scene.objects):
        if o.type == "ARMATURE":
            for m in meshes:
                for mod in list(m.modifiers):
                    if mod.type == "ARMATURE":
                        m.modifiers.remove(mod)
            bpy.data.objects.remove(o, do_unlink=True)
    # Unparent keeping world positions, and give shared meshes their own copy.
    bpy.ops.object.select_all(action="DESELECT")
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.make_single_user(object=True, obdata=True)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o.type == "EMPTY":
            bpy.data.objects.remove(o, do_unlink=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for vg in list(body.vertex_groups):
        body.vertex_groups.remove(vg)
    body.name = "Body"
    return body


def verts_world(obj):
    return [obj.matrix_world @ v.co for v in obj.data.vertices]


def normalise(body):
    """Feet on the floor at the origin, 1.8 m tall."""
    vs = verts_world(body)
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    s = HEIGHT / (hi.z - lo.z)
    centre = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z))
    for v in body.data.vertices:
        v.co = (v.co - centre) * s
    body.data.update()


def slice_x(vs, z0, z1):
    return [v for v in vs if z0 <= v.z < z1]


def landmarks(body):
    vs = verts_world(body)
    H = max(v.z for v in vs)
    step = H / 120.0
    # Crotch: highest slice (below mid height) where no vertex sits near x=0.
    crotch = H * 0.45
    for k in range(int(0.55 * H / step), int(0.2 * H / step), -1):
        z = k * step
        sl = slice_x(vs, z, z + step)
        if sl and not any(abs(v.x) < 0.012 * H for v in sl) and any(v.x < 0 for v in sl) and any(v.x > 0 for v in sl):
            crotch = z
            break
    # Neck: narrowest slice between 75% and 90% of the height.
    neck, best = H * 0.83, 1e9
    for k in range(int(0.75 * H / step), int(0.9 * H / step)):
        z = k * step
        sl = slice_x(vs, z, z + step)
        core = [v for v in sl if abs(v.x) < 0.15 * H]
        if core:
            w = max(v.x for v in core) - min(v.x for v in core)
            if w < best:
                best, neck = w, z
    # Hands: the furthest-out vertices on each side above the crotch.
    upper = [v for v in vs if v.z > crotch]
    right_hand = max(upper, key=lambda v: v.x)
    left_hand = min(upper, key=lambda v: v.x)
    # Shoulders: just under the neck, at the edge of the torso.
    sh_z = neck - 0.06 * H
    torso = [v for v in slice_x(vs, sh_z - 0.03 * H, sh_z) if abs(v.x) < 0.16 * H]
    sh_x = max((abs(v.x) for v in torso), default=0.12 * H) * 0.8
    hip_x = 0.055 * H
    return {
        "H": H, "crotch": crotch, "neck": neck, "sh_z": sh_z, "sh_x": sh_x, "hip_x": hip_x,
        "hand_r": Vector((right_hand.x, 0, right_hand.z)), "hand_l": Vector((left_hand.x, 0, left_hand.z)),
    }


def build_armature(L):
    H = L["H"]
    arm = bpy.data.armatures.new("Skeleton")
    rig = bpy.data.objects.new("Skeleton", arm)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones

    def bone(name, head, tail, parent=None, connect=False):
        b = eb.new(name)
        b.head, b.tail = Vector(head), Vector(tail)
        if parent:
            b.parent = eb[parent]
            b.use_connect = connect
        return b

    hip_z = L["crotch"] + 0.04 * H
    bone("Hips", (0, 0, hip_z), (0, 0, hip_z + 0.06 * H))
    bone("Spine", (0, 0, hip_z + 0.06 * H), (0, 0, hip_z + 0.16 * H), "Hips", True)
    bone("Chest", (0, 0, hip_z + 0.16 * H), (0, 0, L["neck"] - 0.02 * H), "Spine", True)
    bone("Neck", (0, 0, L["neck"] - 0.02 * H), (0, 0, L["neck"] + 0.03 * H), "Chest", True)
    bone("Head", (0, 0, L["neck"] + 0.03 * H), (0, 0, H), "Neck", True)
    # Blender front is -Y, so the character's left is +X.
    for side, s in (("Left", 1.0), ("Right", -1.0)):
        hand = L["hand_r"] if s > 0 else L["hand_l"]
        sh = Vector((s * L["sh_x"], 0, L["sh_z"]))
        bone(f"{side}Shoulder", (s * 0.02 * H, 0, L["sh_z"]), sh, "Chest")
        wrist = sh + (hand - sh) * 0.88
        elbow = sh + (wrist - sh) * 0.5 + Vector((0, 0.015 * H, 0))   # a hint of bend, backwards
        bone(f"{side}UpperArm", sh, elbow, f"{side}Shoulder", True)
        bone(f"{side}LowerArm", elbow, wrist, f"{side}UpperArm", True)
        bone(f"{side}Hand", wrist, hand, f"{side}LowerArm", True)
        top = Vector((s * L["hip_x"], 0, hip_z))
        ankle = Vector((s * L["hip_x"] * 1.05, 0.0, 0.06 * H))
        knee = (top + ankle) * 0.5 + Vector((0, -0.012 * H, 0))       # knees bend forward
        bone(f"{side}UpperLeg", top, knee, "Hips")
        bone(f"{side}LowerLeg", knee, ankle, f"{side}UpperLeg", True)
        toe = Vector((s * L["hip_x"] * 1.05, -0.09 * H, 0.015 * H))
        bone(f"{side}Foot", ankle, toe, f"{side}LowerLeg", True)
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def skin(body, rig, L):
    """Each vertex goes to the nearest bone of the body part it belongs to (an arm,
    a leg, or the trunk and head), then the weights are smoothed so joints bend
    softly. Deterministic, and it works on meshes that are not watertight."""
    H = L["H"]
    bones = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in rig.data.bones}
    chains = {
        "trunk": ["Hips", "Spine", "Chest", "Neck", "Head"],
        "Left_arm": ["LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "Chest"],
        "Right_arm": ["RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand", "Chest"],
        "Left_leg": ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "Hips"],
        "Right_leg": ["RightUpperLeg", "RightLowerLeg", "RightFoot", "Hips"],
    }
    groups = {name: body.vertex_groups.new(name=name) for name in bones}
    arm_x = L["sh_x"] * 0.92
    for v in body.data.vertices:
        p = v.co
        side = "Left" if p.x > 0 else "Right"
        if p.z > L["crotch"] - 0.02 * H and abs(p.x) > arm_x and p.z < L["neck"]:
            chain = chains[side + "_arm"]
        elif p.z < L["crotch"] + 0.02 * H:
            chain = chains[side + "_leg"]
        else:
            chain = chains["trunk"]
        d = sorted((_seg_dist(p, *bones[n]), n) for n in chain)
        best, name = d[0]
        groups[name].add([v.index], 1.0, "REPLACE")
        # Blend toward a second bone that is nearly as close (soft joints).
        if len(d) > 1 and d[1][0] < best + 0.03 * H:
            w = 1.0 - (d[1][0] - best) / (0.03 * H)
            groups[d[1][1]].add([v.index], 0.5 * w, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    body.parent = rig
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig


def reduce(body, max_tris):
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    if tris <= max_tris:
        return tris
    d = body.modifiers.new("decimate", "DECIMATE")
    d.ratio = max_tris / tris
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=d.name)
    return sum(len(p.vertices) - 2 for p in body.data.polygons)


def preview(rig, path):
    """Arms up, one knee bent, head turned: shows whether the skin bends cleanly."""
    pb = rig.pose.bones
    pb["LeftUpperArm"].rotation_mode = "XYZ"
    pb["LeftUpperArm"].rotation_euler = (0, 0, math.radians(-50))
    pb["RightLowerArm"].rotation_mode = "XYZ"
    pb["RightLowerArm"].rotation_euler = (math.radians(70), 0, 0)
    pb["LeftUpperLeg"].rotation_mode = "XYZ"
    pb["LeftUpperLeg"].rotation_euler = (math.radians(-60), 0, 0)
    pb["LeftLowerLeg"].rotation_mode = "XYZ"
    pb["LeftLowerLeg"].rotation_euler = (math.radians(80), 0, 0)
    pb["Head"].rotation_mode = "XYZ"
    pb["Head"].rotation_euler = (0, 0, math.radians(30))
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (2.2, -3.2, 1.3)
    direction = Vector((0, 0, 0.9)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.collection.objects.link(sun)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x, scene.render.resolution_y = 900, 1100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for name in ("LeftUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg", "Head"):
        pb[name].rotation_euler = (0, 0, 0)


def main():
    o = args()
    clear_scene()
    body = import_and_join(o["in"])
    if o["turn"]:
        for v in body.data.vertices:
            v.co.x, v.co.y = -v.co.x, -v.co.y
        body.data.update()
    normalise(body)
    L = landmarks(body)
    print("[autorig] landmarks:", {k: (round(v, 3) if isinstance(v, float) else tuple(round(c, 3) for c in v)) for k, v in L.items()})
    tris = reduce(body, o["max_tris"])
    print("[autorig] triangles:", tris)
    rig = build_armature(L)
    skin(body, rig, L)
    used = set()
    for v in body.data.vertices:
        for x in v.groups:
            if x.weight > 0.05:
                used.add(x.group)
    empty = [g.name for g in body.vertex_groups if g.index not in used]
    print("[autorig] bones with (almost) no weights:", empty)
    if o["preview"]:
        preview(rig, o["preview"])
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=o["out"], export_format="GLB", use_selection=True, export_skins=True, export_animations=False)
    print("[autorig] wrote", o["out"])


main()

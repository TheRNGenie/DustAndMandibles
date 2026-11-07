"""Assemble Logan's separate Meshy revolver parts into the game's gun space
(run inside Blender, no UI):

    blender --background --factory-startup --python tools/rig/prep_revolver.py -- <parts_dir> <out_dir>

<parts_dir> holds frame, cylinder, barrel, hammer, trigger, grips, cartridge and
speed_loader .glb (as sent). Gun space is Godot's: barrel along -Z, +Y up, real
(viewmodel) size, the cylinder turning about Z at the old drum's place. Each
part is placed by matching one of its points (in its own glTF frame) to a gun
space point, then written as rv_<part>.glb in gun space; rv_parts.json keeps
the pivots and the chamber ring for the game (GunModels / ViewModel).
"""
import json
import os
import sys

import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slim import slim_textures  # noqa: E402

# glTF part frame -> gun frame (both Y up).
SIDE = lambda p: Vector((-p.z, p.y, p.x))          # side-on, barrel along -X (Meshy guns)
SIDE_FLIP = lambda p: Vector((-p.z, p.y, -p.x))    # side-on, facing the other way
SAME = lambda p: Vector((p.x, p.y, p.z))           # already along Z (the cylinder)
ROUND = lambda p: Vector((p.x, p.z, -p.y))         # upright cartridge: bullet to -Z
LOADER = lambda p: Vector((-p.x, p.y, -p.z))       # speed loader: bullets to -Z

# The cylinder turns here (the old drum's place).
AXIS = Vector((0.0, 0.018, -0.005))
FRAME_S = 0.187
# The frame's cylinder window centre (its glTF frame), measured off a side render.
WINDOW = Vector((-0.140, 0.20, 0.0))


def frame_pt(x, y):
    """A point on the frame (its own glTF side view) in gun space."""
    return AXIS + Vector((0.0, (y - WINDOW.y) * FRAME_S, (x - WINDOW.x) * FRAME_S))


# name: (file, mapping, scale, anchor in the part's glTF frame (None: bbox centre), gun point, tris)
PARTS = {
    "frame": ("frame", SIDE, FRAME_S, WINDOW, AXIS, 14000),
    "cylinder": ("cylinder", SAME, 0.0566, None, AXIS, 8000),
    "barrel": ("barrel", SIDE, 0.0893, Vector((0.951, 0.1185, 0.0)), frame_pt(-0.43, 0.29) + Vector((0, 0, 0.034)), 12000),
    "hammer": ("hammer", SIDE_FLIP, 0.053, Vector((-0.090, -0.307, 0.0)), frame_pt(0.08, 0.15), 3000),
    "trigger": ("trigger", SIDE, 0.032, Vector((0.126, 0.397, 0.0)), frame_pt(-0.03, 0.03), 2000),
    "grip_r": ("grips", SIDE_FLIP, 0.079, None, frame_pt(0.2745, -0.1375) + Vector((0.011, 0, 0)), 3000),
    "grip_l": ("grips", SIDE_FLIP, 0.079, None, frame_pt(0.2745, -0.1375) + Vector((-0.011, 0, 0)), 3000),
    "cartridge": ("cartridge", ROUND, 0.0526, None, Vector(), 1500),
    "speed_loader": ("speed_loader", LOADER, 0.08, None, Vector(), 6000),
}
PIVOTS = {"cylinder": AXIS, "hammer": frame_pt(0.08, 0.15), "trigger": frame_pt(-0.03, 0.03)}


def place(src, out, name, spec):
    file, fn, s, anchor, target, max_tris = spec
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, file + ".glb"))
    meshes = [m for m in bpy.context.scene.objects if m.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.make_single_user(object=True, obdata=True)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    for e in [x for x in bpy.context.scene.objects if x.type == "EMPTY"]:
        bpy.data.objects.remove(e, do_unlink=True)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris > max_tris:
        d = obj.modifiers.new("decimate", "DECIMATE")
        d.ratio = max_tris / tris
        bpy.ops.object.modifier_apply(modifier=d.name)
    # Blender (Z up) -> glTF (Y up): (x, z, -y).
    pts = [Vector((v.co.x, v.co.z, -v.co.y)) for v in obj.data.vertices]
    if anchor is None:
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        anchor = (lo + hi) * 0.5
    off = target - fn(anchor) * s
    g = [fn(p) * s + off for p in pts]
    mirror = name == "grip_l"
    for v, p in zip(obj.data.vertices, g):
        if mirror:
            p = Vector((2.0 * target.x - p.x, p.y, p.z))
        v.co = Vector((p.x, -p.z, p.y))  # gun (Y up) -> Blender for export
    # A mirrored or left-handed mapping turns the faces inside out: flip them back.
    det_neg = fn in (SIDE_FLIP,)
    if det_neg ^ mirror:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
    obj.data.update()
    slim_textures(1024, True)
    lo = Vector((min(p.x for p in g), min(p.y for p in g), min(p.z for p in g)))
    hi = Vector((max(p.x for p in g), max(p.y for p in g), max(p.z for p in g)))
    print("[rv] %s box %s .. %s" % (name, tuple(round(c, 4) for c in lo), tuple(round(c, 4) for c in hi)))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, "rv_%s.glb" % name), export_format="GLB",
                              use_selection=True, export_image_format="JPEG", export_jpeg_quality=88)
    return [round(c, 4) for c in lo], [round(c, 4) for c in hi]


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    src, out = a[0], a[1]
    os.makedirs(out, exist_ok=True)
    boxes = {}
    for name, spec in PARTS.items():
        boxes[name] = place(src, out, name, spec)
    info = {"pivots": {k: [round(c, 4) for c in v] for k, v in PIVOTS.items()}, "boxes": boxes}
    with open(os.path.join(out, "rv_parts.json"), "w") as fh:
        json.dump(info, fh, indent=1)
    print("[rv] wrote", out)


main()

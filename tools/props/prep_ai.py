"""Get an AI-made model (fal trellis GLB) ready for the game (run inside Blender, no UI).

    blender -b --factory-startup --python tools/props/prep_ai.py -- in.glb out.glb
        [--size 1.0] [--axis x|y|z|max] [--max-tris 1500] [--cut-below 0.0]
        [--rot-z 0] [--origin bottom|center|top] [--tex 1024] [--part front|back --split 0.12]
        [--dims x,y,z]   (stretch to exactly these extents instead of --size)

Joins it into one mesh, optionally drops everything below `cut-below` (a share
of its height: a base plate, a stray gondola), turns it `rot-z` degrees about
the vertical, scales its extent along `axis` to `size` metres, puts the origin
at the bottom centre (or the middle), reduces it to `max-tris` triangles with
smooth normals (the ink outline pushes along them), keeps only the colour map
(the cel shader reads nothing else) at `tex` pixels, and exports a GLB.
--part front keeps only the share `split` of the length at -Y (a propeller),
back the rest; both keep the whole model's frame, so the parts line up.
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rig"))
from slim import slim_textures  # noqa: E402


def opts():
    a = sys.argv[sys.argv.index("--") + 1:]
    o = {"in": a[0], "out": a[1], "size": 1.0, "axis": "max", "max_tris": 1500, "cut_below": 0.0,
            "rot_z": 0.0, "origin": "bottom", "tex": 1024, "part": "", "split": 0.12, "dims": ""}
    i = 2
    while i < len(a):
        o[a[i].lstrip("-").replace("-", "_")] = a[i + 1]
        i += 2
    for k in ("size", "cut_below", "rot_z", "split"):
        o[k] = float(o[k])
    for k in ("max_tris", "tex"):
        o[k] = int(o[k])
    return o


def bounds(ob):
    vs = [v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def main():
    o = opts()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=o["in"])
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
    body = bpy.context.view_layer.objects.active
    for e in [x for x in bpy.context.scene.objects if x.type != "MESH"]:
        bpy.data.objects.remove(e, do_unlink=True)
    lo, hi = bounds(body)
    if o["cut_below"] > 0.0:
        cut = lo.z + (hi.z - lo.z) * o["cut_below"]
        bm = bmesh.new()
        bm.from_mesh(body.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < cut], context="VERTS")
        bm.to_mesh(body.data)
        bm.free()
    if o["rot_z"] != 0.0:
        body.data.transform(Matrix.Rotation(math.radians(o["rot_z"]), 4, "Z"))
    lo, hi = bounds(body)
    ext = hi - lo
    if o["axis"] == "max":
        e = max(ext)
    else:
        e = {"x": ext.x, "y": ext.y, "z": ext.z}[o["axis"]]
    s = o["size"] / e
    cz = {"bottom": lo.z, "top": hi.z}.get(o["origin"], (lo.z + hi.z) * 0.5)
    c = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, cz))
    body.data.transform(Matrix.Translation(-c))
    if o["dims"]:
        dx, dy, dz = [float(v) for v in o["dims"].split(",")]
        body.data.transform(Matrix.Diagonal((dx / ext.x, dy / ext.y, dz / ext.z, 1.0)))
        s = dy / ext.y
    else:
        body.data.transform(Matrix.Scale(s, 4))
    body.data.update()
    if o["part"]:
        y_cut = (lo.y - c.y) * s + (hi.y - lo.y) * s * o["split"]
        bm = bmesh.new()
        bm.from_mesh(body.data)
        front = o["part"] == "front"
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v.co.y >= y_cut) == front], context="VERTS")
        bm.to_mesh(body.data)
        bm.free()
    # Weld the seams the generator leaves, then decimate.
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005 * o["size"])
    bm.to_mesh(body.data)
    bm.free()
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    if tris > o["max_tris"]:
        d = body.modifiers.new("decimate", "DECIMATE")
        d.ratio = o["max_tris"] / tris
        d.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=d.name)
    for p in body.data.polygons:
        p.use_smooth = True
    lo, hi = bounds(body)
    print("[prep] triangles:", sum(len(p.vertices) - 2 for p in body.data.polygons), "size", [round(x, 3) for x in (hi - lo)])
    slim_textures(o["tex"])
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=o["out"], export_format="GLB", use_selection=True,
            export_image_format="JPEG", export_jpeg_quality=88)


main()

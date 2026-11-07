"""Get a Meshy prop (a hat, a gun) ready for the game (run inside Blender, no UI).

    blender --background --factory-startup --python tools/rig/prep_prop.py -- in.glb out.glb --size 0.5 [--axis xy|z] [--max-tris 8000] [--preview out.png]

Joins it into one mesh, centres it, and scales it so its largest extent along
`--axis` is `--size` metres (xy = widest across, for hats; z = height). Hats sit
with their lowest point at 0. Reduces triangles, shrinks textures to 2K, and
exports a GLB.
"""
import math
import sys

import os
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slim import slim_textures  # noqa: E402
from mathutils import Vector


def opts():
    a = sys.argv[sys.argv.index("--") + 1:]
    o = {"in": a[0], "out": a[1], "size": 0.5, "axis": "xy", "max_tris": 8000, "preview": None}
    i = 2
    while i < len(a):
        k = a[i].lstrip("-").replace("-", "_")
        o[k] = a[i + 1]
        i += 2
    o["size"] = float(o["size"])
    o["max_tris"] = int(o["max_tris"])
    return o


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
    for e in [x for x in bpy.context.scene.objects if x.type == "EMPTY"]:
        bpy.data.objects.remove(e, do_unlink=True)
    vs = [v.co for v in body.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    ext = max(hi.x - lo.x, hi.y - lo.y) if o["axis"] == "xy" else hi.z - lo.z
    s = o["size"] / ext
    c = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z if o["axis"] == "xy" else (lo.z + hi.z) * 0.5))
    for v in body.data.vertices:
        v.co = (v.co - c) * s
    body.data.update()
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    if tris > o["max_tris"]:
        d = body.modifiers.new("decimate", "DECIMATE")
        d.ratio = o["max_tris"] / tris
        bpy.ops.object.modifier_apply(modifier=d.name)
    print("[prop] triangles:", sum(len(p.vertices) - 2 for p in body.data.polygons), "scale", round(s, 4))
    slim_textures(1 << 16, True)  # as sent: every map, full size (Logan, 2026-11-07)
    if o["preview"]:
        scene = bpy.context.scene
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("c"))
        scene.collection.objects.link(cam)
        cam.location = Vector((0.0, -1.0, 0.45)) * (o["size"] * 1.8)
        cam.rotation_euler = (Vector((0, 0, o["size"] * 0.15)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.color_type = "TEXTURE"
        scene.render.resolution_x, scene.render.resolution_y = 600, 450
        scene.render.filepath = o["preview"]
        bpy.ops.render.render(write_still=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=o["out"], export_format="GLB", use_selection=True, export_image_format="AUTO")
    print("[prop] wrote", o["out"])


main()

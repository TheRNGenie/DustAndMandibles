"""Reduce GLBs to a triangle budget, keeping their textures as they are
(run inside Blender, no UI):

    blender --background --factory-startup --python tools/rig/decimate_glb.py -- <in_dir> <out_dir> <max_tris>

Every <in_dir>/*.glb is joined into one mesh, decimated (collapse) to at most
<max_tris> triangles and written to <out_dir> with the same name.
"""
import glob
import os
import sys

import bpy


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    src, out, max_tris = a[0], a[1], int(a[2])
    os.makedirs(out, exist_ok=True)
    for f in sorted(glob.glob(os.path.join(src, "*.glb"))):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=f)
        meshes = [m for m in bpy.context.scene.objects if m.type == "MESH"]
        bpy.ops.object.select_all(action="DESELECT")
        for m in meshes:
            m.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        if len(meshes) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        if tris > max_tris:
            d = obj.modifiers.new("decimate", "DECIMATE")
            d.ratio = max_tris / tris
            bpy.ops.object.modifier_apply(modifier=d.name)
        after = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        dst = os.path.join(out, os.path.basename(f))
        bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_image_format="AUTO")
        print("[dec] %s %d -> %d" % (os.path.basename(f), tris, after))


main()

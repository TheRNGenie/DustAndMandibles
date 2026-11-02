"""Fit a Meshy gun or held item into the game's gun space and split off its
moving parts (run inside Blender, no UI).

    blender --background --factory-startup --python tools/rig/prep_gun.py -- in.glb out_dir name \\
        --fit z|y --min x,y,z --max x,y,z [--mirror] [--max-tris 16000] \\
        [--shift x,y,z] [--no-turn] [--part lever:xmin,xmax,ymin,ymax,zmin,zmax ...]

Gun space is the game's (Godot) frame: barrel along -Z, +Y up, real size.
Meshy guns come side-on with the barrel along -X and +Z up (Blender), so each
model is turned to face down -Z first. `--fit z` scales it so its length matches
the box from --min to --max, puts the muzzle at the box's front and centres it
across; `--fit y` scales by height and centres it (items). `--mirror` flips it
left-right (a crank on the wrong side). Each `--part` box cuts out the faces that
lie entirely inside it as its own mesh (still in gun space), e.g. a lever or
barrels that animate. Writes <name>_body.glb and <name>_<part>.glb.
"""
import json
import sys

import os
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slim import slim_textures  # noqa: E402
import bmesh
from mathutils import Vector


def opts():
    a = sys.argv[sys.argv.index("--") + 1:]
    o = {"in": a[0], "out": a[1], "name": a[2], "fit": "z", "min": None, "max": None, "mirror": False,
         "max_tris": 16000, "parts": [], "shift": Vector(), "turn": True}
    i = 3
    while i < len(a):
        k = a[i]
        if k == "--mirror":
            o["mirror"] = True
            i += 1
            continue
        if k == "--keep-maps":
            o["keep_maps"] = True
            i += 1
            continue
        if k == "--no-turn":
            o["turn"] = False
            i += 1
            continue
        v = a[i + 1]
        if k == "--fit":
            o["fit"] = v
        elif k in ("--min", "--max"):
            o[k[2:]] = Vector([float(x) for x in v.split(",")])
        elif k == "--shift":
            o["shift"] = Vector([float(x) for x in v.split(",")])
        elif k == "--max-tris":
            o["max_tris"] = int(v)
        elif k == "--part":
            name, box = v.split(":")
            o["parts"].append((name, [float(x) for x in box.split(",")]))
        i += 2
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
    obj = bpy.context.view_layer.objects.active
    for e in [x for x in bpy.context.scene.objects if x.type == "EMPTY"]:
        bpy.data.objects.remove(e, do_unlink=True)
    # Reduce first (cheaper to move fewer vertices).
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris > o["max_tris"]:
        d = obj.modifiers.new("decimate", "DECIMATE")
        d.ratio = o["max_tris"] / tris
        bpy.ops.object.modifier_apply(modifier=d.name)
    # Blender -> game frame, turned so the barrel (-X) points down -Z.
    g = []
    for v in obj.data.vertices:
        g0 = Vector((v.co.x, v.co.z, -v.co.y))
        g1 = Vector((-g0.z, g0.y, g0.x)) if o["turn"] else g0
        if o["mirror"]:
            g1.x = -g1.x
        g.append(g1)
    lo = Vector((min(p.x for p in g), min(p.y for p in g), min(p.z for p in g)))
    hi = Vector((max(p.x for p in g), max(p.y for p in g), max(p.z for p in g)))
    tmin, tmax = o["min"], o["max"]
    if o["fit"] == "z":
        s = (tmax.z - tmin.z) / (hi.z - lo.z)
        off = Vector(((tmin.x + tmax.x) * 0.5 - (lo.x + hi.x) * 0.5 * s,
                      (tmin.y + tmax.y) * 0.5 - (lo.y + hi.y) * 0.5 * s,
                      tmin.z - lo.z * s))
    else:
        s = (tmax.y - tmin.y) / (hi.y - lo.y)
        off = (tmin + tmax) * 0.5 - (lo + hi) * 0.5 * s
    off += o["shift"]
    g = [p * s + off for p in g]
    print("[gun] scale %.4f  box %s .. %s" % (s, tuple(round(c, 3) for c in lo * s + off), tuple(round(c, 3) for c in hi * s + off)))
    for v, p in zip(obj.data.vertices, g):
        v.co = Vector((p.x, -p.z, p.y))   # back to Blender axes for export
    if o["mirror"]:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
    obj.data.update()
    slim_textures(2048 if o.get("keep_maps") else 1024, bool(o.get("keep_maps")))
    info = {}
    # Cut out the moving parts.
    for name, box in o["parts"]:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bm = bmesh.from_edit_mesh(obj.data)
        for f in bm.faces:
            inside = True
            for vv in f.verts:
                gx, gy, gz = vv.co.x, vv.co.z, -vv.co.y
                if not (box[0] <= gx <= box[1] and box[2] <= gy <= box[3] and box[4] <= gz <= box[5]):
                    inside = False
                    break
            f.select = inside
        bmesh.update_edit_mesh(obj.data)
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        part = [x for x in bpy.context.selected_objects if x != obj][0]
        part.name = name
        pts = [Vector((v.co.x, v.co.z, -v.co.y)) for v in part.data.vertices]
        if pts:
            c = sum(pts, Vector()) / len(pts)
            info[name] = {"centre": [round(c.x, 4), round(c.y, 4), round(c.z, 4)], "verts": len(pts)}
        print("[gun] part", name, info.get(name))
        bpy.ops.object.select_all(action="DESELECT")
        part.select_set(True)
        bpy.ops.export_scene.gltf(filepath="%s/%s_%s.glb" % (o["out"], o["name"], name), export_format="GLB",
                                  use_selection=True, export_image_format="JPEG", export_jpeg_quality=90)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath="%s/%s_body.glb" % (o["out"], o["name"]), export_format="GLB",
                              use_selection=True, export_image_format="JPEG", export_jpeg_quality=90)
    with open("%s/%s.json" % (o["out"], o["name"]), "w") as fh:
        json.dump({"scale": s, "parts": info}, fh)
    print("[gun] wrote", o["name"])


main()

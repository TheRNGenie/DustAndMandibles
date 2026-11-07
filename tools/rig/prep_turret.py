"""Split the fal turret models into their moving parts and fit them to the game
(run inside Blender, no UI):

    blender --background --factory-startup --python tools/rig/prep_turret.py -- <in_dir> <out_dir> [names]

tools/rig/turret_parts.json says, per model, which way it points, where it swivels
and pitches, and which bits spin or swing. Faces are sorted by their centre into
base / head (swivels) / gun (swivels and pitches) / spin_N / swing, the model is
turned so the gun points down -Z, scaled to its height in metres, stood on y = 0
and centred on its swivel, and each part is written as <name>_<part>.glb in that
turret space (no decimation, textures as made). <name>.json keeps the pivots.
"""
import json
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))


def gl(v):  # Blender -> glTF
    return Vector((v.x, v.z, -v.y))


def bl(v):  # glTF -> Blender
    return Vector((v.x, -v.z, v.y))


def inside(p, b):
    return b[0] <= p.x <= b[1] and b[2] <= p.y <= b[3] and b[4] <= p.z <= b[5]


def classify(c, spec):
    for b in spec.get("drop", []):  # cut out entirely (Logan: no gunner on the Thunder Mule)
        if inside(c, b):
            return "drop"
    for i, s in enumerate(spec.get("spin", [])):
        if inside(c, s["box"]):
            return "spin%d" % i
    if "swing" in spec and inside(c, spec["swing"]["box"]):
        return "swing"
    if spec.get("static") or spec.get("static_base"):
        return "base"
    if c.y <= spec["yaw_y"]:
        return "base"
    gb = spec.get("gun_box")
    if c.y > spec["gun_min_y"] and (gb is None or inside(c, gb)) and not spec.get("no_pitch"):
        return "gun"
    return "head"


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    src, out = a[0], a[1]
    only = set(a[2].split(",")) if len(a) > 2 else None
    specs = json.load(open(os.path.join(HERE, "turret_parts.json")))
    os.makedirs(out, exist_ok=True)
    for name, spec in specs.items():
        if name.startswith("_") or (only and name not in only):
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(src, name + ".glb"))
        meshes = [m for m in bpy.context.scene.objects if m.type == "MESH"]
        bpy.ops.object.select_all(action="DESELECT")
        for m in meshes:
            m.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if len(meshes) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        for e in [x for x in bpy.context.scene.objects if x.type == "EMPTY"]:
            bpy.data.objects.remove(e, do_unlink=True)
        # The fit: turn so `forward` points down -Z, scale to height, stand on y = 0.
        f = Vector(spec["forward"]); f.y = 0; f.normalize()
        import math
        ang = math.atan2(-f.x, -f.z)  # yaw that takes -Z to f
        rot = Matrix.Rotation(-ang, 3, "Y")  # takes f to -Z (glTF Y up)
        ys = [gl(v.co).y for v in obj.data.vertices]
        lo, hi = min(ys), max(ys)
        s = float(spec["height"]) / (hi - lo)

        def fit(p):
            q = rot @ (Vector(p) - Vector((0, lo, 0)))
            return q * s

        # Sort the faces (by centre, in the model's own frame) into parts.
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        groups = {}
        for face in bm.faces:
            c = gl(face.calc_center_median())
            groups.setdefault(classify(c, spec), []).append(face.index)
        bm.free()
        # Move every vertex into turret space.
        for v in obj.data.vertices:
            v.co = bl(fit(gl(v.co)))
        obj.data.update()
        info = {"height": spec["height"], "parts": {}}
        # One copy of the whole mesh per part, keeping only that part's faces
        # (face indices are the original ones in every copy).
        objs = {}
        groups.pop("drop", None)
        for part, faces in groups.items():
            keep = set(faces)
            o = obj.copy()
            o.data = obj.data.copy()
            o.name = part
            bpy.context.scene.collection.objects.link(o)
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bm.faces.ensure_lookup_table()
            bmesh.ops.delete(bm, geom=[fc for fc in bm.faces if fc.index not in keep], context="FACES")
            bm.to_mesh(o.data)
            bm.free()
            objs[part] = o
        bpy.data.objects.remove(obj, do_unlink=True)
        # One GLB per turret, a node per part (base / head / gun / spinN / swing),
        # so the parts share one set of textures.
        bpy.ops.object.select_all(action="DESELECT")
        for part, o in objs.items():
            o.select_set(True)
            info["parts"][part] = len(o.data.polygons)
        bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format="GLB",
                                  use_selection=True, export_image_format="AUTO")
        pts = {}
        if "yaw_y" in spec:
            pts["yaw"] = list(fit((0, spec["yaw_y"], 0)))
        if "pitch" in spec:
            pts["pitch"] = list(fit(spec["pitch"]))
        if "muzzle" in spec:
            pts["muzzle"] = list(fit(spec["muzzle"]))
        if "swing" in spec:
            pts["swing"] = list(fit(spec["swing"]["at"]))
            pts["swing_axis"] = list(rot @ Vector(spec["swing"]["axis"]))
        for i, sp in enumerate(spec.get("spin", [])):
            pts["spin%d" % i] = list(fit(sp["at"]))
            pts["spin%d_axis" % i] = list(rot @ Vector(sp["axis"]))
        info["points"] = {k: [round(c, 4) for c in v] for k, v in pts.items()}
        json.dump(info, open(os.path.join(out, name + ".json"), "w"), indent=1)
        print("[tp] %s %s" % (name, info["parts"]))


main()

"""Fit the fal weapon models into the game's gun space and cut out their moving
parts (run inside Blender, no UI):

    blender --background --factory-startup --python tools/rig/prep_armory.py -- <in_dir> <out_dir> [names]

tools/rig/armory_parts.json says, per weapon (all in the model's own Blender
frame, +Z up, as fal made it):
  fwd      "+x" | "-x" | "+y" | "-y": the way the muzzle points
  yaw      degrees to turn the model about Z first (a model made at an angle)
  rot      [[axis, degrees], ...]: turns before the yaw, in order (stand a
           flat model up); fist/muzzle/grip/parts are read after all turns
  fist     [along, up]: the middle of the pistol grip where the fist closes
  muzzle   [along, up]: the middle of the muzzle mouth
           ("along" is the model's own x or y coordinate, whichever fwd names)
  grip     [[along, up] top, [along, up] bottom] of the pistol grip: when given,
           the scale makes the grip grip_len metres long (a hand's worth) and
           the fist sits a third of the way down it (fist is then ignored)
  target   {"fist": [x, y, z], "muzzle_z": z}: the code gun's fist and muzzle
           depth in gun space (ArmoryGuns.hands / muzzle), which fixes the
           scale (fist-to-muzzle distance) and the place (fist on the fist)
  parts    {name: {"box": [a0, a1, up0, up1, c0, c1] | [[...], ...], "pivot": [a, up, c]}}
           in the model's own frame like fist/muzzle (a = along, c = across:
           the other horizontal axis); faces whose centre is in a box go to
           that part (the first that matches); the pivot comes out in gun space
  extra    {name: {"src": model, "at": [a, up, c], "size": d}}: a part made from
           another model, fitted whole: centred on `at`, `size` across (raw units)
Gun space is the code guns' (gen/armory_guns.gd): barrel along -Z, +Y up,
real size, origin just above the trigger. Writes
one <name>.glb with a node per part (body, cylinder, ..., each still in gun
space, not moved to its pivot) and <name>.json with the scale, muzzle, fist,
support hand, crop ring and pivots. No decimation and no
texture changes: the mesh is placed, scaled and cut, nothing else.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
AXES = {"+x": Vector((1, 0, 0)), "-x": Vector((-1, 0, 0)), "+y": Vector((0, 1, 0)), "-y": Vector((0, -1, 0))}


def g2b(v):  # Godot gun space -> Blender (right X, forward +Y, up Z)
    return Vector((v[0], -v[2], v[1]))


def b2g(v):
    return [round(v.x, 5), round(v.z, 5), round(-v.y, 5)]


def inside(p, b):
    return b[0] <= p[0] <= b[1] and b[2] <= p[1] <= b[3] and b[4] <= p[2] <= b[5]


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    src, out = a[0], a[1]
    only = set(a[2].split(",")) if len(a) > 2 else None
    specs = json.load(open(os.path.join(HERE, "armory_parts.json"), encoding="utf-8"))
    os.makedirs(out, exist_ok=True)
    for name, spec in specs.items():
        if name.startswith("_") or (only and name not in only):
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(src, spec.get("src", name) + ".glb"))
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

        # Source frame: forward u, up Z, right r = u x Z (after the optional yaw).
        yaw = Matrix.Rotation(math.radians(spec.get("yaw", 0.0)), 3, "Z")
        for axis, deg in reversed(spec.get("rot", [])):  # turns applied first, in order (a model lying flat)
            yaw = yaw @ Matrix.Rotation(math.radians(deg), 3, axis.upper())
        u = AXES[spec["fwd"]]
        up = Vector((0, 0, 1))
        r = u.cross(up)
        # Lateral middle: the model's centre across (fal centres them).
        lat = 0.0
        src_m = Matrix((r, u, up))  # rows: picks (right, forward, up) components
        sgn = 1.0 if spec["fwd"][0] == "+" else -1.0  # fist/muzzle "along" are read off the profile axis
        fa, fh = spec["fist"][0] * sgn, spec["fist"][1]
        ma, mh = spec["muzzle"][0] * sgn, spec["muzzle"][1]
        t = spec["target"]
        fist_g = Vector(t["fist"])
        s = (fist_g.z - t["muzzle_z"]) / (ma - fa)
        if "grip" in spec:  # size it by the hand: the grip comes out grip_len long, the fist a third of the way down it
            (ta, th), (ba, bh) = spec["grip"]
            top, bot = Vector((ta * sgn, th)), Vector((ba * sgn, bh))
            s = spec.get("grip_len", 0.13) / (bot - top).length
            fa, fh = top + (bot - top) * 0.35
        if spec.get("scale_by") == "length":  # fist and muzzle too close to judge size by: match the code gun's length
            along = [(src_m @ (yaw @ v.co)).y for v in obj.data.vertices]
            s = t["length"] / (max(along) - min(along))
        # source point -> target Blender frame: scale the (right, fwd, up) parts,
        # then move the fist onto the target fist.
        fist_src = Vector((lat, fa, fh))
        fist_b = g2b(fist_g)

        def fit(p):
            q = src_m @ (yaw @ p)
            return (q - fist_src) * s + fist_b

        # Sort faces into parts by centre, in the model's own (profile) frame:
        # [along, up, across] = its x or y (whichever fwd names), z, the other one.
        parts = spec.get("parts", {})
        ax = 0 if spec["fwd"][1] == "x" else 1

        def raw(p):
            q = yaw @ p
            return [q[ax], q.z, q[1 - ax]]

        def raw_to_g(rp):  # a raw [along, up, across] point -> gun space
            p = Vector((0.0, 0.0, rp[1]))
            p[ax] = rp[0]
            p[1 - ax] = rp[2] if len(rp) > 2 else 0.0
            return b2g(fit(yaw.inverted() @ p))

        bm = bmesh.new()
        bm.from_mesh(obj.data)
        groups = {}
        for f in bm.faces:
            g = raw(f.calc_center_median())
            label = "body"
            for pn, pd in parts.items():
                boxes = pd["box"] if isinstance(pd["box"][0], list) else [pd["box"]]
                if any(inside(g, b) for b in boxes):
                    label = pn
                    break
            groups.setdefault(label, []).append(f.index)
        bm.free()
        pivots = {pn: raw_to_g(pd["pivot"]) for pn, pd in parts.items() if "pivot" in pd}
        for v in obj.data.vertices:
            v.co = fit(v.co)
        obj.data.update()
        muzzle_g = b2g((Vector((lat, ma, mh)) - fist_src) * s + fist_b)
        info = {"scale": s, "muzzle": muzzle_g, "fist": list(t["fist"]), "parts": {}}
        if "rest" in spec:  # held this much further out than the code gun (a bulky top or back)
            info["rest"] = spec["rest"]
        if "support" in spec:  # where the support hand holds (heavies)
            info["support"] = raw_to_g(spec["support"])
        if "ring" in spec:  # the crop ring round the barrel: centre, facing, radius (gun space)
            rg = spec["ring"]
            c0, c1 = Vector(raw_to_g(rg["at"])), Vector(raw_to_g(rg["to"]))
            info["ring"] = {"at": list(c0), "n": list((c0 - c1).normalized()), "r": rg["r"] * s}
        made = []
        for part, faces in groups.items():
            keep = set(faces)
            o = obj.copy()
            o.data = obj.data.copy()
            o.name = part
            o.data.name = part
            bpy.context.scene.collection.objects.link(o)
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
            bm.to_mesh(o.data)
            bm.free()
            made.append(o)
            if part != "body":
                info["parts"][part] = {"pivot": pivots.get(part, [0, 0, 0]), "faces": len(faces)}
                if "axis" in parts[part]:
                    info["parts"][part]["axis"] = parts[part]["axis"]
        bpy.data.objects.remove(obj, do_unlink=True)
        # Extra parts from another model (the Bramble Pistol's loaded bramble
        # ball): fitted whole, centred on `at` (raw) and `size` (raw) across.
        for pn, ed in spec.get("extra", {}).items():
            before = set(bpy.context.scene.objects)
            bpy.ops.import_scene.gltf(filepath=os.path.join(src, ed["src"] + ".glb"))
            new = [o for o in set(bpy.context.scene.objects) - before if o.type == "MESH"]
            bpy.ops.object.select_all(action="DESELECT")
            for o in new:
                o.select_set(True)
            bpy.context.view_layer.objects.active = new[0]
            bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            if len(new) > 1:
                bpy.ops.object.join()
            eo = bpy.context.view_layer.objects.active
            for e in [x for x in bpy.context.scene.objects if x.type == "EMPTY"]:
                bpy.data.objects.remove(e, do_unlink=True)
            vs = [v.co.copy() for v in eo.data.vertices]
            lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
            hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
            k = ed["size"] * s / max(hi - lo)
            centre_g = Vector(raw_to_g(ed["at"]))
            centre_b = g2b(centre_g)
            for v in eo.data.vertices:
                v.co = (v.co - (lo + hi) * 0.5) * k + centre_b
            eo.data.update()
            eo.name = pn
            eo.data.name = pn
            made.append(eo)
            info["parts"][pn] = {"pivot": list(centre_g), "faces": len(eo.data.polygons), "from": ed["src"]}
        # One file: a node per part, all in gun space (textures shared, not copied per part).
        bpy.ops.object.select_all(action="DESELECT")
        for o in made:
            o.select_set(True)
        bpy.context.view_layer.objects.active = made[0]
        bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format="GLB",
                                  use_selection=True, export_image_format="AUTO")
        json.dump(info, open(os.path.join(out, name + ".json"), "w"), indent=1)
        print("[pa] %s scale %.3f muzzle %s parts %s" % (name, s, muzzle_g, {k: len(v) for k, v in groups.items()}))


main()

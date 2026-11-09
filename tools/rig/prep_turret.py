"""Split the fal turret models into their moving parts and fit them to the game
(run inside Blender, no UI):

    blender --background --factory-startup --python tools/rig/prep_turret.py -- <in_dir> <out_dir> [names]

tools/rig/turret_parts.json says, per model, which way it points, where it swivels
and pitches, and which bits spin or swing (optional: centre, base_box, a list of
gun boxes, head_box, gun_tilt_deg, yaw_pivot_y; see its _doc). Faces are sorted by their centre into
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
    for b in spec.get("base_box", []):  # loose props (spare bales, ramrod) that stay put
        if inside(c, b):
            return "base"
    for i, s in enumerate(spec.get("spin", [])):
        if inside(c, s["box"]):
            return "spin%d" % i
    if "swing" in spec and inside(c, spec["swing"]["box"]):
        return "swing"
    for f in spec.get("force", []):  # {"box": [...], "part": "gun"|"head"|"base"}: whole pieces the height rules would split
        if inside(c, f["box"]):
            return f["part"]
    for cap in spec.get("gun_capsule", []):  # [[x,y,z], [x,y,z], radius]: a slanted barrel
        a, b = Vector(cap[0]), Vector(cap[1])
        t = max(0.0, min(1.0, (c - a).dot(b - a) / max((b - a).length_squared, 1e-9)))
        if (c - (a + (b - a) * t)).length <= cap[2]:
            return "gun"
    if spec.get("static") or spec.get("static_base"):
        return "base"
    if c.y <= spec["yaw_y"]:
        return "base"
    gb = spec.get("gun_box")
    if gb is not None and not isinstance(gb[0], list):
        gb = [gb]  # one box, or a list of them (a gun that wraps round its crutch)
    for b in spec.get("head_box", []):  # carriage cheeks / stand arches hugging the gun
        if inside(c, b):
            return "head"
    if c.y > spec["gun_min_y"] and (gb is None or any(inside(c, b) for b in gb)) and not spec.get("no_pitch"):
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

        cx, cz = spec.get("centre", (0.0, 0.0))  # (a model made off-centre: swivel about its middle)

        def fit(p):
            q = rot @ (Vector(p) - Vector((cx, lo, cz)))
            return q * s

        # Sort the faces (by centre, in the model's own frame) into parts.
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        groups = {}
        lo_hi = {}
        for face in bm.faces:
            c = gl(face.calc_center_median())
            part = classify(c, spec)
            groups.setdefault(part, []).append(face.index)
            if part.startswith("spin"):
                for v in face.verts:
                    g = gl(v.co)
                    a0, a1 = lo_hi.get(part, (g.copy(), g.copy()))
                    lo_hi[part] = (Vector(map(min, a0, g)), Vector(map(max, a1, g)))
        bm.free()
        spin_centres = {k: (v[0] + v[1]) * 0.5 for k, v in lo_hi.items()}
        # Small loose pieces (bolts, levers, slivers) go whole to the part most of
        # their faces fell in, so nothing floats off or tears when the gun moves.
        label = {}
        for part, faces in groups.items():
            for fi in faces:
                label[fi] = part
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        seen = set()
        small = max(40, int(len(bm.faces) * spec.get("island_share", 0.03)))
        specks = []
        for f0 in bm.faces:
            if f0.index in seen:
                continue
            island = []
            stack = [f0]
            seen.add(f0.index)
            while stack:
                f = stack.pop()
                island.append(f.index)
                for v in f.verts:
                    for nf in v.link_faces:
                        if nf.index not in seen:
                            seen.add(nf.index)
                            stack.append(nf)
            if len(island) > small:
                continue
            votes = {}
            for fi in island:
                votes[label[fi]] = votes.get(label[fi], 0) + 1
            win = max(votes, key=votes.get)
            for fi in island:
                label[fi] = win
            if len(votes) == 1 and len(island) <= spec.get("speck_faces", 1500):
                specks.append(island)
        # Specks: a small piece that fell wholly in one part (a charm, a bolt, a
        # lever) goes with whatever it sits against instead, so it can't be left
        # hanging in the air when the gun turns or tips up.
        if specks:
            from mathutils.kdtree import KDTree
            centres = [f.calc_center_median() for f in bm.faces]
            tree = KDTree(len(centres))
            for i, co in enumerate(centres):
                tree.insert(co, i)
            tree.balance()
            moved = 0
            for island in specks:
                own = set(island)
                best = None
                for fi in island[::max(1, len(island) // 40)]:
                    for co, j, dist in tree.find_n(centres[fi], len(own) + 24):
                        if j not in own:
                            if best is None or dist < best[0]:
                                best = (dist, label[j])
                            break
                if best is not None and best[1] != label[island[0]] and {best[1], label[island[0]]} <= {"base", "head", "gun"}:
                    for fi in island:
                        label[fi] = best[1]
                    moved += 1
            print("[tp] %s: %d of %d specks moved to the part they touch" % (name, moved, len(specks)))
        bm.free()
        groups = {}
        for fi, part in label.items():
            groups.setdefault(part, []).append(fi)
        groups.pop("drop", None)
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
        # gun_tilt_deg: the gun as made sits this far nose-up (negative: nose-down);
        # turn it level about its pitch pivot so it aims where the turret aims.
        tilt = None
        if spec.get("gun_tilt_deg") and "pitch" in spec:
            piv = fit(spec["pitch"])
            tilt = Matrix.Rotation(math.radians(-float(spec["gun_tilt_deg"])), 3, "X")
            for part in ("gun", "swing"):
                if part in objs:
                    for v in objs[part].data.vertices:
                        v.co = bl(piv + tilt @ (gl(v.co) - piv))
                    objs[part].data.update()
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
            pts["yaw"] = list(fit((cx, spec.get("yaw_pivot_y", spec["yaw_y"]), cz)))  # (the sight point: keep it above the lip)
        if "pitch" in spec:
            pts["pitch"] = list(fit(spec["pitch"]))
        if "muzzle" in spec:
            m = fit(spec["muzzle"])
            if tilt is not None:
                m = piv + tilt @ (m - piv)
            pts["muzzle"] = list(m)
        if "swing" in spec:
            pts["swing"] = list(fit(spec["swing"]["at"]))
            pts["swing_axis"] = list(rot @ Vector(spec["swing"]["axis"]))
        for i, sp in enumerate(spec.get("spin", [])):
            at = Vector(sp["at"])
            if sp.get("auto_centre", True) and ("spin%d" % i) in spin_centres:
                # Spin about the middle of the cluster itself (across the axis), so the
                # barrels turn in place instead of orbiting a guessed point.
                ax = Vector(sp["axis"]).normalized()
                c = spin_centres["spin%d" % i]
                at = c - ax * (c - at).dot(ax)
            pts["spin%d" % i] = list(fit(at))
            pts["spin%d_axis" % i] = list(rot @ Vector(sp["axis"]))
        info["points"] = {k: [round(c, 4) for c in v] for k, v in pts.items()}
        json.dump(info, open(os.path.join(out, name + ".json"), "w"), indent=1)
        print("[tp] %s %s" % (name, info["parts"]))


main()

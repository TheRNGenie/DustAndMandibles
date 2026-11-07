class_name RiggedTurret
extends RefCounted
## Turrets built from the fal models (tools/rig/prep_turret.py): one GLB per
## turret in assets/rigged/turrets with a mesh node per moving part (base, head,
## gun, spin0, spin1, swing), all in turret space (gun down -Z, standing on y = 0),
## and <id>.json with the pivots. build() hands back the same parts dictionary
## TurretBuilder does, each mesh moved so its pivot is at its node's origin, with
## the model's own textures ("textured": the turret leaves its materials alone).

const DIR := "res://assets/rigged/turrets/"

static var _cache: Dictionary = {}


static func has(id: StringName) -> bool:
	return ResourceLoader.exists(DIR + String(id) + ".glb")


static func build(id: StringName, _team: Color) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var info: Dictionary = {}
	var f := FileAccess.open(DIR + String(id) + ".json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			info = parsed
	var pts: Dictionary = info.get("points", {})
	var meshes := _meshes(load(DIR + String(id) + ".glb") as PackedScene)
	var yaw := _pt(pts, "yaw", Vector3.ZERO)
	# A swinging part (mortar tube, bramble cradle) is the gun, pitching about its hinge.
	var swing := meshes.has("swing")
	var pitch := _pt(pts, "swing" if swing else "pitch", yaw)
	var muzzle := _pt(pts, "muzzle", pitch + Vector3(0, 0.3, -0.4))
	var out := {
		"textured": true,
		# Static bases (traps, mortars on a fixed bed) don't swivel.
		"fixed_yaw": not pts.has("yaw"),
		"head_y": yaw.y,
		"gun_y": pitch.y - yaw.y,
		"base": meshes.get("base", ArrayMesh.new()),
		"head": _moved(meshes.get("head"), -yaw),
		"gun": _moved(meshes.get("swing" if swing else "gun"), -pitch),
		"muzzle": muzzle - pitch,
		"recoil": 0.05,
	}
	for i in 2:
		var key := "spin%d" % i
		if not meshes.has(key) or not pts.has(key):
			continue
		var at := _pt(pts, key, pitch)
		var axis := _pt(pts, key + "_axis", Vector3.BACK).normalized()
		# The turret spins each cluster about its own local Z: turn the mesh so the
		# part's axis lies along Z, and give the node the basis that turns it back.
		var b := _basis_z(axis)
		var name := "spin" if i == 0 else "spin_b"
		out[name] = _moved(meshes[key], -at, b.inverse())
		out[name + "_at"] = at - pitch if pts.has("yaw") or swing else at - pitch
		out[name + "_basis"] = b
	# Twin barrels: the second muzzle mirrors the first across the gun.
	if meshes.has("spin1") and absf(muzzle.x) > 0.05:
		out["muzzle_b"] = Vector3(-muzzle.x, muzzle.y, muzzle.z) - pitch
	_cache[id] = out
	return out


static func _pt(pts: Dictionary, key: String, fallback: Vector3) -> Vector3:
	var a: Variant = pts.get(key)
	if a is Array and (a as Array).size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


## Part name -> mesh, from the GLB's mesh nodes (names may carry a numeric suffix).
static func _meshes(scene: PackedScene) -> Dictionary:
	var out := {}
	if scene == null:
		return out
	var root := scene.instantiate()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var key := String(mi.name).get_slice(".", 0).get_slice("_", 0).to_lower()
		if key in ["base", "head", "gun", "spin0", "spin1", "swing"]:
			# Bake the node's own transform in, so every part shares turret space.
			out[key] = _moved(mi.mesh, Vector3.ZERO, _global(mi))
	root.free()
	return out


static func _global(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent() as Node3D
	while p != null:
		t = p.transform * t
		p = p.get_parent() as Node3D
	return t


## A basis whose Z axis is `axis`.
static func _basis_z(axis: Vector3) -> Basis:
	var z := axis.normalized()
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	return Basis(x, z.cross(x).normalized(), z)


## `mesh` with every vertex moved by `offset` then transformed by `xf`.
static func _moved(mesh: Variant, offset: Vector3, xf: Variant = null) -> ArrayMesh:
	var src := mesh as Mesh
	var out := ArrayMesh.new()
	if src == null:
		return out
	var t := Transform3D.IDENTITY
	if xf is Transform3D:
		t = xf
	elif xf is Basis:
		t = Transform3D(xf, Vector3.ZERO)
	t = t * Transform3D(Basis(), offset)
	if t.is_equal_approx(Transform3D.IDENTITY) and src is ArrayMesh:
		return src as ArrayMesh
	for i in src.get_surface_count():
		var arr := src.surface_get_arrays(i)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for k in v.size():
			v[k] = t * v[k]
		arr[Mesh.ARRAY_VERTEX] = v
		if arr[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for k in nr.size():
				nr[k] = (t.basis * nr[k]).normalized()
			arr[Mesh.ARRAY_NORMAL] = nr
		if arr[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
			var tg: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
			for k in range(0, tg.size(), 4):
				var d := (t.basis * Vector3(tg[k], tg[k + 1], tg[k + 2])).normalized()
				tg[k] = d.x
				tg[k + 1] = d.y
				tg[k + 2] = d.z
			arr[Mesh.ARRAY_TANGENT] = tg
		out.add_surface_from_arrays(src.surface_get_primitive_type(i), arr)
		out.surface_set_material(i, src.surface_get_material(i))
	return out

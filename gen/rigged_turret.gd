class_name RiggedTurret
extends RefCounted
## Turrets built from the fal models (tools/rig/prep_turret.py): one GLB per
## turret in assets/rigged/turrets with a mesh node per moving part (base, head,
## gun, spin0, spin1, swing), all in turret space (gun down -Z, standing on y = 0),
## and <id>.json with the pivots. build() hands back the same parts dictionary
## TurretBuilder does, each mesh moved so its pivot is at its node's origin, with
## the model's own textures ("textured": the turret leaves its materials alone).

const DIR := "res://assets/rigged/turrets/"
## Keep the import's distance detail levels on the moving parts.
const KEEP_LODS := true

static var _cache: Dictionary = {}


static func has(id: StringName) -> bool:
	return ResourceLoader.exists(DIR + String(id) + ".glb")


## Already built (build() is then free).
static func is_built(id: StringName) -> bool:
	return _cache.has(id)


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
		"base": _part(meshes, "base", Vector3.ZERO),
		"head": _part(meshes, "head", -yaw),
		"gun": _part(meshes, "swing" if swing else "gun", -pitch),
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
		out[name] = _part(meshes, key, -at, b.inverse())
		out[name + "_at"] = at - pitch
		out[name + "_basis"] = b
	# Twin barrels: the second muzzle mirrors the first across the gun.
	if meshes.has("spin1") and absf(muzzle.x) > 0.05:
		out["muzzle_b"] = Vector3(-muzzle.x, muzzle.y, muzzle.z) - pitch
	_cache[id] = out
	WorldPreload.let_go(DIR + String(id) + ".glb") # (the lobby's background load, if it held it)
	return out


## Just the pivot heights (the coverage preview's head_y), from the .json alone:
## no model load.
static func head_y(id: StringName) -> float:
	if _cache.has(id):
		return float(_cache[id]["head_y"])
	var f := FileAccess.open(DIR + String(id) + ".json", FileAccess.READ)
	if f == null:
		return 0.0
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var pts: Dictionary = (parsed as Dictionary).get("points", {}) if parsed is Dictionary else {}
	return _pt(pts, "yaw", Vector3.ZERO).y


## One part's mesh in its pivot's space: the node's own transform from the GLB,
## then the pivot offset, then `b` (the spin clusters' turn), all in one pass.
static func _part(meshes: Dictionary, key: String, offset: Vector3, b: Basis = Basis()) -> ArrayMesh:
	if not meshes.has(key):
		return ArrayMesh.new()
	var mi: Array = meshes[key]
	var node_xf: Transform3D = mi[1]
	var moved := _moved(mi[0], Transform3D(b, Vector3.ZERO) * Transform3D(Basis(), offset) * node_xf)
	return moved if moved != null else ArrayMesh.new()


static func _pt(pts: Dictionary, key: String, fallback: Vector3) -> Vector3:
	var a: Variant = pts.get(key)
	if a is Array and (a as Array).size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


## Part name -> [mesh, node transform], from the GLB's mesh nodes (names may carry a numeric suffix).
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
			# With the node's own transform, baked in later (_part) so every part
			# shares turret space.
			out[key] = [mi.mesh, _global(mi)]
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


## `mesh` with every vertex transformed by `t`, keeping the import's distance
## detail levels (LODs) and materials. Only positions, normals and tangents
## change, and the vertex order stays, so the LODs' index lists still fit.
static func _moved(mesh: Variant, t: Transform3D) -> ArrayMesh: # (null: a surface it couldn't read)
	var src := mesh as Mesh
	if src == null:
		return ArrayMesh.new()
	if t.is_equal_approx(Transform3D.IDENTITY) and src is ArrayMesh:
		return src as ArrayMesh
	var out := ArrayMesh.new()
	var rot := Transform3D(t.basis, Vector3.ZERO)
	var turned := not t.basis.is_equal_approx(Basis())
	# A pure turn keeps normals unit length; anything else needs renormalising.
	var rigid := t.basis.orthonormalized().is_equal_approx(t.basis)
	for i in src.get_surface_count():
		var arr := src.surface_get_arrays(i)
		if not (arr[Mesh.ARRAY_VERTEX] is PackedVector3Array):
			# Godot can't read back a compressed position-only surface (the
			# import's shadow meshes): unpack it here.
			var pos := _unpack_positions(src, i)
			if pos.is_empty():
				return null
			arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_VERTEX] = t * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		if turned and arr[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			var nr: PackedVector3Array = rot * (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array)
			if not rigid:
				for k in nr.size():
					nr[k] = nr[k].normalized()
			arr[Mesh.ARRAY_NORMAL] = nr
		if turned and arr[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
			var tg: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
			for k in range(0, tg.size(), 4):
				var d := (t.basis * Vector3(tg[k], tg[k + 1], tg[k + 2])).normalized()
				tg[k] = d.x
				tg[k + 1] = d.y
				tg[k + 2] = d.z
			arr[Mesh.ARRAY_TANGENT] = tg
		# Written uncompressed: re-compressing the moved vertices drew the moving
		# parts black and broken on screen (v0.1.62).
		out.add_surface_from_arrays(src.surface_get_primitive_type(i), arr, [], _lods(src, i) if KEEP_LODS else {})
		out.surface_set_material(i, src.surface_get_material(i))
		if src is ArrayMesh:
			out.surface_set_name(i, (src as ArrayMesh).surface_get_name(i))
	# No shadow mesh carried over: the moved copy left broken shadows (v0.1.62).
	# Shadows use the part itself, as before v0.1.62.
	return out


## Positions of a compressed surface with nothing but positions: four 16-bit
## values a vertex, x y z scaled into the surface's bounding box. Empty if the
## surface isn't laid out that way.
static func _unpack_positions(src: Mesh, surface: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var d := RenderingServer.mesh_get_surface(src.get_rid(), surface)
	var n := int(d.get("vertex_count", 0))
	var bytes: PackedByteArray = d.get("vertex_data", PackedByteArray())
	var fmt := int(d.get("format", 0))
	if n <= 0 or bytes.size() != n * 8 or not (fmt & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) or (fmt & Mesh.ARRAY_FORMAT_NORMAL):
		return out
	var box: AABB = d.get("aabb", AABB())
	var k := box.size / 65535.0
	out.resize(n)
	for v in n:
		var o := v * 8
		out[v] = box.position + Vector3(bytes.decode_u16(o), bytes.decode_u16(o + 2), bytes.decode_u16(o + 4)) * k
	return out


## The import's LODs of one surface, as add_surface_from_arrays takes them
## (distance -> index list). Unchanged by moving the vertices.
static func _lods(src: Mesh, surface: int) -> Dictionary:
	var out := {}
	var d := RenderingServer.mesh_get_surface(src.get_rid(), surface)
	var lods: Array = d.get("lods", [])
	if lods.is_empty():
		return out
	var count := int(d.get("index_count", 0))
	var base: PackedByteArray = d.get("index_data", PackedByteArray())
	var wide := count > 0 and base.size() >= count * 4
	for l: Dictionary in lods:
		var bytes: PackedByteArray = l.get("index_data", PackedByteArray())
		var idx: PackedInt32Array
		if wide:
			idx = bytes.to_int32_array()
		else:
			idx.resize(bytes.size() / 2)
			for k in idx.size():
				idx[k] = bytes.decode_u16(k * 2)
		out[float(l.get("edge_length", 0.0))] = idx
	return out

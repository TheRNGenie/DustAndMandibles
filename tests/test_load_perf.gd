extends TestCase
## Load-time work (DECISIONS: load times): the faster terrain mesh builder makes
## the same triangles as the old SurfaceTool one, and the terrain cache hands
## back the same nodes, meshes and shapes as a fresh build.


## The old CliffBuilder._grid_mesh (SurfaceTool, then index()), kept as the reference.
static func _reference_grid_mesh(grid: Array, outward: Vector3) -> ArrayMesh:
	var rows := grid.size()
	var cols: int = (grid[0] as Array).size()
	var normals: Array = []
	for r in rows:
		var nrow: Array[Vector3] = []
		for c in cols:
			var p_up: Vector3 = grid[mini(r + 1, rows - 1)][c]
			var p_dn: Vector3 = grid[maxi(r - 1, 0)][c]
			var p_rt: Vector3 = grid[r][mini(c + 1, cols - 1)]
			var p_lt: Vector3 = grid[r][maxi(c - 1, 0)]
			var n := (p_up - p_dn).cross(p_rt - p_lt).normalized()
			if n.dot(outward) < 0.0:
				n = -n
			nrow.append(n)
		normals.append(nrow)
	var st := MeshKit.begin()
	var col := Color(1, 1, 1, 1)
	for r in rows - 1:
		for c in cols - 1:
			var a: Vector3 = grid[r][c]
			var b: Vector3 = grid[r][c + 1]
			var cc: Vector3 = grid[r + 1][c + 1]
			var d: Vector3 = grid[r + 1][c]
			var na: Vector3 = normals[r][c]
			var nb: Vector3 = normals[r][c + 1]
			var nc: Vector3 = normals[r + 1][c + 1]
			var nd: Vector3 = normals[r + 1][c]
			MeshKit.tri(st, a, b, cc, na, nb, nc, col, (na + nb + nc).normalized())
			MeshKit.tri(st, a, cc, d, na, nc, nd, col, (na + nc + nd).normalized())
	return MeshKit.finish(st)


## Every triangle as "p0|p1|p2" (positions and normals, in winding order, rotated
## to start at the smallest), sorted: equal lists mean the same surface.
static func _tris(mesh: ArrayMesh) -> PackedStringArray:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var out: PackedStringArray = []
	for t in idx.size() / 3:
		var keys: PackedStringArray = []
		for j in 3:
			var i := idx[t * 3 + j]
			keys.append("%s/%s" % [str(v[i].snappedf(0.0001)), str(n[i].snappedf(0.001))])
		var lo := 0
		for j in 3:
			if keys[j] < keys[lo]:
				lo = j
		out.append("%s|%s|%s" % [keys[lo], keys[(lo + 1) % 3], keys[(lo + 2) % 3]])
	out.sort()
	return out


func test_grid_mesh_matches_the_surface_tool_build() -> void:
	MapDef.select(MapDef.CANYON)
	var cb := CliffBuilder.new(1234)
	for cid in 2:
		var grid: Array = []
		for y: float in [0.0, 0.6, 1.2, 1.8, 30.0, 59.0, 60.0]:
			var row: Array[Vector3] = []
			for z: float in [-12.0, -11.0, -10.0, -9.5, 0.0, 4.0, 12.0]:
				row.append(cb.face_point(cid, y, z))
			grid.append(row)
		var outward := cb.map.cliffs[cid].inward
		var fast := cb._grid_mesh(grid, outward)
		var ref := _reference_grid_mesh(grid, outward)
		assert_eq(_tris(fast), _tris(ref), "cliff %d face triangles" % cid)
	# A floor-like grid facing up, with a repeated row (degenerate triangles).
	var flat: Array = []
	for x: float in [-3.0, -1.5, -1.5, 0.0, 1.5]:
		var row: Array[Vector3] = []
		for z: float in [-3.0, -1.5, 0.0, 1.5]:
			row.append(Vector3(x, sin(x * z) * 0.3, z))
		flat.append(row)
	assert_eq(_tris(cb._grid_mesh(flat, Vector3.UP)), _tris(_reference_grid_mesh(flat, Vector3.UP)), "floor grid")


func test_terrain_cache_returns_the_same_terrain() -> void:
	MapDef.select(MapDef.CANYON)
	CliffBuilder._built.clear()
	var first := Node3D.new()
	CliffBuilder.new(4321).build(first)
	var second := Node3D.new()
	CliffBuilder.new(4321).build(second)
	assert_eq(second.get_child_count(), first.get_child_count(), "same top-level nodes")
	for i in first.get_child_count():
		var a := first.get_child(i)
		var b := second.get_child(i)
		assert_eq(b.name, a.name)
		assert_eq(b.get_class(), a.get_class(), str(a.name))
		var ma := a as MeshInstance3D if a is MeshInstance3D else a.get_child(0) as MeshInstance3D
		var mb := b as MeshInstance3D if b is MeshInstance3D else b.get_child(0) as MeshInstance3D
		if ma != null and mb != null:
			assert_eq(mb.mesh, ma.mesh, "%s shares the built mesh" % a.name)
			assert_eq(mb.material_override, ma.material_override, "%s material" % a.name)
			assert_eq(mb.cast_shadow, ma.cast_shadow, "%s shadows" % a.name)
		if a is StaticBody3D:
			var ca := a.get_child(1) as CollisionShape3D
			var cbs := b.get_child(1) as CollisionShape3D
			assert_true(ca != null and cbs != null and cbs.shape == ca.shape, "%s shares its collision shape" % a.name)
	assert_true(CliffBuilder._built.has("canyon_4321"), "cached by map and seed")
	first.free()
	second.free()
	CliffBuilder._built.clear()

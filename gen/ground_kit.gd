class_name GroundKit
extends RefCounted
## Helpers for the maps' ground dressing (all visual only): Voronoi crack nets,
## Catmull-Rom paths, ground patches and flat decals that follow a height
## function `h(x, z) -> y`, and a few small shapes (spirals, wedges, rings).


## Voronoi cell edges of `pts` as point pairs [a0, b0, a1, b1, ...], from the
## circumcentres of the Delaunay triangles either side of each shared edge.
## Edges longer than `max_len` (the open hull) are dropped.
static func voronoi_edges(pts: PackedVector2Array, max_len: float) -> PackedVector2Array:
	var tris := Geometry2D.triangulate_delaunay(pts)
	var centres: Array[Vector2] = []
	var owner := {}
	var out := PackedVector2Array()
	for t in tris.size() / 3:
		var a := pts[tris[t * 3]]
		var b := pts[tris[t * 3 + 1]]
		var c := pts[tris[t * 3 + 2]]
		centres.append(_circumcentre(a, b, c))
		for e in 3:
			var i0 := tris[t * 3 + e]
			var i1 := tris[t * 3 + (e + 1) % 3]
			var key := Vector2i(mini(i0, i1), maxi(i0, i1))
			if owner.has(key):
				var p := centres[int(owner[key])]
				var q := centres[t]
				if p.distance_to(q) <= max_len:
					out.append(p)
					out.append(q)
			else:
				owner[key] = t
	return out


static func _circumcentre(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 0.00001:
		return (a + b + c) / 3.0
	var a2 := a.length_squared()
	var b2 := b.length_squared()
	var c2 := c.length_squared()
	return Vector2((a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d,
			(a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d)


## A smooth Catmull-Rom path through `ctrl`, `per_seg` points per span.
static func spline(ctrl: Array[Vector2], per_seg: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := ctrl.size()
	for i in n - 1:
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, n - 1)]
		for k in per_seg:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(k) / float(per_seg)))
	out.append(ctrl[n - 1])
	return out


## Distance from p to a polyline, and the index of the nearest segment's start.
static func path_distance(path: Array[Vector2], p: Vector2) -> Vector2:
	var best := INF
	var at := 0
	for i in path.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])
		var d := q.distance_to(p)
		if d < best:
			best = d
			at = i
	return Vector2(best, at)


## A ground patch on a square grid (cells `step` m) over `rect`, keeping the cells
## whose centre passes `keep(x, z)`; vertex heights from `h(x, z)`, smooth normals.
static func patch(rect: Rect2, step: float, h: Callable, keep: Callable) -> ArrayMesh:
	var nx := ceili(rect.size.x / step)
	var nz := ceili(rect.size.y / step)
	var ys := PackedFloat32Array()
	ys.resize((nx + 1) * (nz + 1))
	var needed := PackedByteArray()
	needed.resize((nx + 1) * (nz + 1))
	var cells: Array[Vector2i] = []
	for i in nx:
		for j in nz:
			var cx := rect.position.x + (i + 0.5) * step
			var cz := rect.position.y + (j + 0.5) * step
			if bool(keep.call(cx, cz)):
				cells.append(Vector2i(i, j))
				for k: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1), Vector2i(i + 1, j + 1)]:
					needed[k.x * (nz + 1) + k.y] = 1
	if cells.is_empty():
		return ArrayMesh.new()
	for i in nx + 1:
		for j in nz + 1:
			if needed[i * (nz + 1) + j] == 1:
				ys[i * (nz + 1) + j] = float(h.call(rect.position.x + i * step, rect.position.y + j * step))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var index_of := {}
	var idx := PackedInt32Array()
	for c in cells:
		var quad: Array[int] = []
		for k: Vector2i in [Vector2i(c.x, c.y), Vector2i(c.x + 1, c.y), Vector2i(c.x + 1, c.y + 1), Vector2i(c.x, c.y + 1)]:
			var key := k.x * (nz + 1) + k.y
			if not index_of.has(key):
				var y := ys[key]
				var yl := ys[key - (nz + 1)] if k.x > 0 and needed[key - (nz + 1)] == 1 else y
				var yr := ys[key + (nz + 1)] if k.x < nx and needed[key + (nz + 1)] == 1 else y
				var yd := ys[key - 1] if k.y > 0 and needed[key - 1] == 1 else y
				var yu := ys[key + 1] if k.y < nz and needed[key + 1] == 1 else y
				index_of[key] = verts.size()
				verts.append(Vector3(rect.position.x + k.x * step, y, rect.position.y + k.y * step))
				normals.append(Vector3(yl - yr, 2.0 * step, yd - yu).normalized())
			quad.append(int(index_of[key]))
		# Clockwise seen from above (Godot's front faces).
		idx.append_array([quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]])
	var colors := PackedColorArray()
	colors.resize(verts.size())
	colors.fill(Color.WHITE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A flat ellipse (or ring, with `inner` > 0 as a fraction of the radii) lying on
## the ground `lift` m up, turned `yaw`, following `h`.
static func disc(st: SurfaceTool, h: Callable, centre: Vector2, radii: Vector2, yaw: float, lift: float,
		color: Color, inner: float = 0.0, segs: int = 12) -> void:
	var col := MeshKit.vcol(color)
	var rot := Vector2.from_angle(yaw)
	var rings: Array[float] = [inner, lerpf(inner, 1.0, 0.5), 1.0]
	var pts: Array = []
	for f: float in rings:
		var row: Array[Vector3] = []
		for s in segs:
			var a := TAU * float(s) / float(segs)
			var l := Vector2(cos(a) * radii.x, sin(a) * radii.y) * f
			var w := centre + Vector2(l.x * rot.x - l.y * rot.y, l.x * rot.y + l.y * rot.x)
			row.append(Vector3(w.x, float(h.call(w.x, w.y)) + lift, w.y))
		pts.append(row)
	for r in rings.size() - 1:
		for s in segs:
			var s1 := (s + 1) % segs
			var a: Vector3 = pts[r][s]
			var b: Vector3 = pts[r][s1]
			var c: Vector3 = pts[r + 1][s1]
			var d: Vector3 = pts[r + 1][s]
			if r > 0 or inner > 0.0:
				MeshKit.tri(st, a, b, c, Vector3.UP, Vector3.UP, Vector3.UP, col, Vector3.UP)
			MeshKit.tri(st, a, c, d, Vector3.UP, Vector3.UP, Vector3.UP, col, Vector3.UP)


## A ground-hugging strip `w` m wide along a polyline (seams, trails, streaks).
static func strip(st: SurfaceTool, h: Callable, path: Array[Vector2], w: float, lift: float, color: Color) -> void:
	var col := MeshKit.vcol(color)
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var side := (b - a).orthogonal().normalized() * w * 0.5
		var pa := Vector3(a.x, float(h.call(a.x, a.y)) + lift, a.y)
		var pb := Vector3(b.x, float(h.call(b.x, b.y)) + lift, b.y)
		var s3 := Vector3(side.x, 0.0, side.y)
		MeshKit.quad(st, pa - s3, pb - s3, pb + s3, pa + s3, Vector3.UP, col)


## A seam (thin dark crack) between two ground points, in 1 m pieces so it hugs the ground.
static func seam(st: SurfaceTool, h: Callable, a: Vector2, b: Vector2, w: float, lift: float, color: Color) -> void:
	var n := maxi(ceili(a.distance_to(b)), 1)
	var path: Array[Vector2] = []
	for k in n + 1:
		path.append(a.lerp(b, float(k) / float(n)))
	strip(st, h, path, w, lift, color)


## An Archimedean spiral of little boxes lying flat (ammonites): `turns` turns
## out to radius `r`, `count` segments, in the plane of `xf` (local XZ).
static func spiral(st: SurfaceTool, xf: Transform3D, r: float, turns: float, count: int, thick: float, color: Color) -> void:
	var prev := Vector3.ZERO
	for i in count + 1:
		var f := float(i) / float(count)
		var a := f * turns * TAU
		var p := Vector3(cos(a), 0.0, sin(a)) * r * (0.12 + 0.88 * f)
		if i > 0:
			var mid := (prev + p) * 0.5
			var d := p - prev
			var b := Basis(Vector3.UP, atan2(d.x, d.z))
			MeshKit.add_box(st, xf * Transform3D(b, mid), Vector3(thick * (0.5 + f), thick * 0.75, d.length() * 1.15), color)
		prev = p


## A wedge (triangular prism) of drifted sand: `length` along x, rising to `height`
## on its -z edge and tapering to nothing `width` m out along +z.
static func wedge(st: SurfaceTool, xf: Transform3D, length: float, width: float, height: float, color: Color) -> void:
	var col := MeshKit.vcol(color)
	var hl := length * 0.5
	var a0 := xf * Vector3(-hl, 0, 0)
	var a1 := xf * Vector3(hl, 0, 0)
	var t0 := xf * Vector3(-hl * 0.8, height, 0)
	var t1 := xf * Vector3(hl * 0.8, height, 0)
	var f0 := xf * Vector3(-hl * 0.7, 0, width)
	var f1 := xf * Vector3(hl * 0.7, 0, width)
	var b0 := xf * Vector3(-hl, 0, -0.05)
	var b1 := xf * Vector3(hl, 0, -0.05)
	var up := (xf.basis * Vector3(0, width, height).normalized()).normalized()
	MeshKit.quad(st, t0, t1, f1, f0, up, col)
	var back := (xf.basis * Vector3.FORWARD).normalized()
	MeshKit.quad(st, b0, b1, t1, t0, back, col)
	MeshKit.tri(st, a0, t0, f0, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, col, xf.basis * Vector3.LEFT)
	MeshKit.tri(st, a1, t1, f1, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, col, xf.basis * Vector3.RIGHT)

class_name MeshKit
extends RefCounted
## Writes primitive shapes (box, cylinder, cone, ellipsoid) into a SurfaceTool with
## vertex colours, so a whole prop becomes one mesh with one toon material.
## Vertex alpha < 1 marks glowing parts (see toon.gdshader).

## Begins a SurfaceTool for triangle meshes.
static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func finish(st: SurfaceTool) -> ArrayMesh:
	st.index()
	return st.commit()


## Adds one triangle. Winding is fixed so the face points along `outward`
## (Godot treats clockwise triangles as front faces).
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, col: Color, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var tmp := b
		b = c
		c = tmp
		var tn := nb
		nb = nc
		nc = tn
	st.set_color(col)
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


## Flat-shaded quad a-b-c-d (in order around the edge).
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		n: Vector3, col: Color) -> void:
	tri(st, a, b, c, n, n, n, col, n)
	tri(st, a, c, d, n, n, n, col, n)


## Linear vertex colour; `glow` 0..1 makes the part emissive.
static func vcol(c: Color, glow: float = 0.0) -> Color:
	var lin := c.srgb_to_linear()
	lin.a = 1.0 - glow
	return lin


static func _normal_basis(xf: Transform3D) -> Basis:
	return xf.basis.inverse().transposed()


## Box centred on xf.origin. `jitter` randomly offsets corners for a hand-made wobble.
## Collision builds set this to 0 so walkable surfaces come out perfectly flat.
static var jitter_scale := 1.0


static func add_box(st: SurfaceTool, xf: Transform3D, size: Vector3, color: Color,
		jitter: float = 0.0, rng: RandomNumberGenerator = null, glow: float = 0.0) -> void:
	jitter *= jitter_scale
	var h := size * 0.5
	var corners: Array[Vector3] = []
	for i in 8:
		var p := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		if jitter > 0.0 and rng != null:
			p += Vector3(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter),
					rng.randf_range(-jitter, jitter))
		corners.append(xf * p)
	var col := vcol(color, glow)
	var nbas := _normal_basis(xf)
	# Faces as corner index loops with their local normals.
	var faces: Array = [
		[[1, 3, 7, 5], Vector3.RIGHT], [[0, 4, 6, 2], Vector3.LEFT],
		[[2, 6, 7, 3], Vector3.UP], [[0, 1, 5, 4], Vector3.DOWN],
		[[4, 5, 7, 6], Vector3.BACK], [[0, 2, 3, 1], Vector3.FORWARD],
	]
	for f: Array in faces:
		var idx: Array = f[0]
		var n: Vector3 = (nbas * (f[1] as Vector3)).normalized()
		quad(st, corners[idx[0]], corners[idx[1]], corners[idx[2]], corners[idx[3]], n, col)


## Cylinder (or cone when r_top = 0) along local Y, centred on xf.origin.
static func add_cylinder(st: SurfaceTool, xf: Transform3D, r_bottom: float, r_top: float,
		height: float, segments: int, color: Color, caps: bool = true, glow: float = 0.0) -> void:
	var col := vcol(color, glow)
	var nbas := _normal_basis(xf)
	var hy := height * 0.5
	var slope := (r_bottom - r_top) / maxf(height, 0.0001)
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var p0b := xf * (d0 * r_bottom + Vector3(0, -hy, 0))
		var p1b := xf * (d1 * r_bottom + Vector3(0, -hy, 0))
		var p0t := xf * (d0 * r_top + Vector3(0, hy, 0))
		var p1t := xf * (d1 * r_top + Vector3(0, hy, 0))
		var n0 := (nbas * (d0 + Vector3(0, slope, 0))).normalized()
		var n1 := (nbas * (d1 + Vector3(0, slope, 0))).normalized()
		var out := (n0 + n1).normalized()
		tri(st, p0b, p1b, p1t, n0, n1, n1, col, out)
		if r_top > 0.0001:
			tri(st, p0b, p1t, p0t, n0, n1, n0, col, out)
		if caps:
			var up := (nbas * Vector3.UP).normalized()
			var cb := xf * Vector3(0, -hy, 0)
			tri(st, cb, p0b, p1b, -up, -up, -up, col, -up)
			if r_top > 0.0001:
				var ct := xf * Vector3(0, hy, 0)
				tri(st, ct, p0t, p1t, up, up, up, col, up)


## A solid wheel rim (a thick ring) round xf's local Y: outer and inner walls and
## both flat faces, so it reads solid from every side (no see-through band).
static func add_rim(st: SurfaceTool, xf: Transform3D, r_out: float, r_in: float, width: float, segments: int, color: Color) -> void:
	var col := vcol(color)
	var nb := _normal_basis(xf)
	var hy := width * 0.5
	var up := (nb * Vector3.UP).normalized()
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var o0b := xf * (d0 * r_out + Vector3(0, -hy, 0))
		var o1b := xf * (d1 * r_out + Vector3(0, -hy, 0))
		var o0t := xf * (d0 * r_out + Vector3(0, hy, 0))
		var o1t := xf * (d1 * r_out + Vector3(0, hy, 0))
		var i0b := xf * (d0 * r_in + Vector3(0, -hy, 0))
		var i1b := xf * (d1 * r_in + Vector3(0, -hy, 0))
		var i0t := xf * (d0 * r_in + Vector3(0, hy, 0))
		var i1t := xf * (d1 * r_in + Vector3(0, hy, 0))
		var n0 := (nb * d0).normalized()
		var n1 := (nb * d1).normalized()
		var out := (n0 + n1).normalized()
		tri(st, o0b, o1b, o1t, n0, n1, n1, col, out)
		tri(st, o0b, o1t, o0t, n0, n1, n0, col, out)
		tri(st, i0b, i1t, i1b, -n0, -n1, -n1, col, -out)
		tri(st, i0b, i0t, i1t, -n0, -n0, -n1, col, -out)
		tri(st, o0t, o1t, i1t, up, up, up, col, up)
		tri(st, o0t, i1t, i0t, up, up, up, col, up)
		tri(st, o0b, i1b, o1b, -up, -up, -up, col, -up)
		tri(st, o0b, i0b, i1b, -up, -up, -up, col, -up)


## Ellipsoid centred on xf.origin with smooth normals. `bumps` adds noisy displacement.
static func add_ellipsoid(st: SurfaceTool, xf: Transform3D, radii: Vector3, rings: int,
		segments: int, color: Color, bumps: float = 0.0, rng: RandomNumberGenerator = null,
		glow: float = 0.0) -> void:
	var col := vcol(color, glow)
	var nbas := _normal_basis(xf)
	var pts: Array = []
	var nrm: Array = []
	for r in rings + 1:
		var v := PI * float(r) / float(rings)
		var row_p: Array[Vector3] = []
		var row_n: Array[Vector3] = []
		for s in segments:
			var u := TAU * float(s) / float(segments)
			var unit := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
			var k := 1.0
			if bumps > 0.0 and rng != null and r > 0 and r < rings:
				k += rng.randf_range(-bumps, bumps)
			var p := unit * radii * k
			var n := Vector3(unit.x / radii.x, unit.y / radii.y, unit.z / radii.z)
			row_p.append(xf * p)
			row_n.append((nbas * n).normalized())
		pts.append(row_p)
		nrm.append(row_n)
	for r in rings:
		var pa: Array[Vector3] = pts[r]
		var pb: Array[Vector3] = pts[r + 1]
		var na: Array[Vector3] = nrm[r]
		var nb: Array[Vector3] = nrm[r + 1]
		for s in segments:
			var s1 := (s + 1) % segments
			var out := (na[s] + nb[s1]).normalized()
			if r > 0:
				tri(st, pa[s], pa[s1], pb[s1], na[s], na[s1], nb[s1], col, out)
			if r < rings - 1:
				tri(st, pa[s], pb[s1], pb[s], na[s], nb[s1], nb[s], col, out)


## A capsule-ish segment between two points (cylinder + ellipsoid end caps).
static func add_limb(st: SurfaceTool, a: Vector3, b: Vector3, radius: float, color: Color,
		segments: int = 8) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.0001:
		return
	var xf := Transform3D(basis_from_y(dir / length), (a + b) * 0.5)
	add_cylinder(st, xf, radius, radius, length, segments, color, false)
	add_ellipsoid(st, Transform3D(Basis(), a), Vector3.ONE * radius, 4, segments, color)
	add_ellipsoid(st, Transform3D(Basis(), b), Vector3.ONE * radius, 4, segments, color)


## A basis whose Y axis points along `y_dir`.
static func basis_from_y(y_dir: Vector3) -> Basis:
	var y := y_dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## A smooth turned shape (like a lathe): `profile` is a list of Vector2(radius, y)
## from bottom to top, spun round the Y axis of xf. `squash` scales the X and Z
## radii (for oval cross-sections). Normals are smoothed along the profile.
static func lathe(st: SurfaceTool, xf: Transform3D, profile: Array, segments: int, color: Color,
		squash: Vector2 = Vector2.ONE, glow: float = 0.0) -> void:
	var col := vcol(color, glow)
	var nbas := _normal_basis(xf)
	var n_rows := profile.size()
	var rings: Array = []
	var norms: Array = []
	# Profiles may run top-down (limbs) or bottom-up; normals must point out either way.
	var flip := -1.0 if (profile[n_rows - 1] as Vector2).y < (profile[0] as Vector2).y else 1.0
	for r in n_rows:
		var pr: Vector2 = profile[r]
		var prev: Vector2 = profile[maxi(r - 1, 0)]
		var next: Vector2 = profile[mini(r + 1, n_rows - 1)]
		var tangent := next - prev
		# Outward normal of the profile curve in (radius, y): rotate the tangent.
		var pn := Vector2(tangent.y, -tangent.x).normalized() * flip if tangent.length() > 0.00001 else Vector2(1, 0)
		var ring: Array[Vector3] = []
		var nring: Array[Vector3] = []
		for s in segments:
			var u := TAU * float(s) / float(segments)
			var dir := Vector3(cos(u) * squash.x, 0.0, sin(u) * squash.y)
			ring.append(xf * Vector3(dir.x * pr.x, pr.y, dir.z * pr.x))
			var nd := Vector3(cos(u) / maxf(squash.x, 0.001), 0.0, sin(u) / maxf(squash.y, 0.001)).normalized()
			nring.append((nbas * (nd * pn.x + Vector3(0, pn.y, 0))).normalized())
		rings.append(ring)
		norms.append(nring)
	for r in n_rows - 1:
		for s in segments:
			var s1 := (s + 1) % segments
			var a: Vector3 = rings[r][s]
			var b: Vector3 = rings[r][s1]
			var c: Vector3 = rings[r + 1][s1]
			var d: Vector3 = rings[r + 1][s]
			var na: Vector3 = norms[r][s]
			var nb: Vector3 = norms[r][s1]
			var nc: Vector3 = norms[r + 1][s1]
			var nd2: Vector3 = norms[r + 1][s]
			tri(st, a, c, b, na, nc, nb, col, (na + nb + nc).normalized())
			tri(st, a, d, c, na, nd2, nc, col, (na + nc + nd2).normalized())


## A smooth tube through `points` (world/mesh space) with a radius per point,
## for hair locks, straps, ropes and curved horns. Round, with end caps.
static func tube(st: SurfaceTool, points: Array, radii: Array, segments: int, color: Color, glow: float = 0.0) -> void:
	var col := vcol(color, glow)
	var n := points.size()
	if n < 2:
		return
	var rings: Array = []
	var norms: Array = []
	var prev_side := Vector3.ZERO
	for i in n:
		var p: Vector3 = points[i]
		var t: Vector3 = (points[mini(i + 1, n - 1)] as Vector3) - (points[maxi(i - 1, 0)] as Vector3)
		t = t.normalized() if t.length() > 0.00001 else Vector3.UP
		var side := prev_side
		if side == Vector3.ZERO or absf(side.dot(t)) > 0.95:
			side = t.cross(Vector3.UP if absf(t.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
		side = (side - t * side.dot(t)).normalized()
		prev_side = side
		var up := t.cross(side).normalized()
		var r: float = radii[mini(i, radii.size() - 1)]
		var ring: Array[Vector3] = []
		var nring: Array[Vector3] = []
		for s in segments:
			var u := TAU * float(s) / float(segments)
			var d := side * cos(u) + up * sin(u)
			ring.append(p + d * r)
			nring.append(d)
		rings.append(ring)
		norms.append(nring)
	for i in n - 1:
		for s in segments:
			var s1 := (s + 1) % segments
			tri(st, rings[i][s], rings[i + 1][s1], rings[i][s1], norms[i][s], norms[i + 1][s1], norms[i][s1], col, norms[i][s])
			tri(st, rings[i][s], rings[i + 1][s], rings[i + 1][s1], norms[i][s], norms[i + 1][s], norms[i + 1][s1], col, norms[i][s])
	# Rounded-ish end caps (fans).
	for e: int in [0, n - 1]:
		var c: Vector3 = points[e]
		var tt: Vector3 = ((points[mini(e + 1, n - 1)] as Vector3) - (points[maxi(e - 1, 0)] as Vector3)).normalized()
		var cap_n := -tt if e == 0 else tt
		for s in segments:
			var s1 := (s + 1) % segments
			tri(st, c, rings[e][s], rings[e][s1], cap_n, cap_n, cap_n, col, cap_n)

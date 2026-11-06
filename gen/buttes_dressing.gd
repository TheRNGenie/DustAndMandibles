class_name ButtesDressing
extends RefCounted
## Pinwheel Buttes dressing (all visual only, no colliders). The dry lake gets a
## quarter of its own between each pair of buttes (a salt pan, dust-devil scars,
## animal trails, a rubble field); each butte a second layer of its story
## (alcoves and the windmill's wreckage, varnish, caves and a fossil, jointed
## and toppled columns and the mine's workings, slots, split fins and the water
## tower's leaks); and the desert round it aprons of drift and gravel, a rock
## garden of hoodoos, a dune sea and rubble fading into the haze.

var t: MapTerrain
var cb: CliffBuilder
var map: MapDef
## The animal trails (lakebed paths between the Basalt and Buttress buttes).
var trails: Array = []
var _trail_box := Rect2()

## Prevailing wind, blowing from the north-west to the south-east (XZ).
const WIND := Vector2(0.70710678, 0.70710678)


func _init(terrain: MapTerrain) -> void:
	t = terrain
	cb = terrain.cb
	map = terrain.map
	_plan_trails()


func build(parent: Node3D) -> void:
	var decals := MeshKit.begin()
	var props := MeshKit.begin()
	_salt_pan(parent, decals, props)
	_dust_devils(parent, decals, props)
	_animal_trails(decals, props)
	_rubble_field(decals, props)
	LoadTimes.mark("  buttes: lakebed")
	for cid in map.count():
		_butte(parent, cid, decals, props)
	LoadTimes.mark("  buttes: butte dressing")
	_desert(parent, decals, props)
	LoadTimes.mark("  buttes: desert")
	t._add_visual(parent, "LakeMarks", MeshKit.finish(decals), Materials.toon(0.0), false)
	t._add_visual(parent, "LakeProps", MeshKit.finish(props), Materials.toon(0.02))
	_dust_motes(parent)


# ------------------------------------------------------------------ helpers

func _floor(x: float, z: float) -> float:
	return MapTerrain.floor_at(cb, x, z)


func _ground() -> Callable:
	return func(x: float, z: float) -> float: return MapTerrain.floor_at(cb, x, z)


func _at(p: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(p.x, _floor(p.x, p.y) + lift, p.y)


## The lake quarter between butte q and the next one round: its middle direction.
func _quarter_dir(q: int) -> Vector2:
	var b := deg_to_rad(45.0 + 90.0 * q)
	return Vector2(sin(b), -cos(b))


## Metres inside the nearest butte's outline (negative outside).
func _in_butte(p: Vector2) -> float:
	var best := -INF
	for cid in map.count():
		var uv := map.local_uv(cid, Vector3(p.x, 0.0, p.y))
		var d := map.prow_u(cid, uv.y) - uv.x
		if d < -12.0 or d > MapTerrain.BUTTE_BACK + 12.0:
			continue
		best = maxf(best, MapTerrain.outline_edge(cb, cid, d, uv.y))
	return best


## A random lakebed point in quarter q, clear of the buttes (and their scree) and
## of the fissures in the middle.
func _quarter_point(rng: RandomNumberGenerator, q: int, r_min: float = 36.0, r_max: float = 110.0, clear: float = 14.0) -> Vector2:
	var c := Vector2(map.center.x, map.center.z)
	var base := _quarter_dir(q).angle()
	for k in 80:
		var p := c + Vector2.from_angle(base + rng.randf_range(-PI / 4.0, PI / 4.0)) * rng.randf_range(r_min, r_max)
		if _in_butte(p) < -clear:
			return p
	return c + _quarter_dir(q) * 90.0


## Where butte cid's outer wall stands at height y, `t_round` (0..1) of the way
## round it, and the way out from it.
func _wall_point(cid: int, t_round: float, y: float) -> Array:
	var p := t._rim_point_at(cid, t_round, -MapTerrain.BUTTE_EDGE * 0.5)
	var out := t._rim_out(cid, p)
	var q := p
	for k in 60:
		q = p + out * (k * 0.25)
		var uv := map.local_uv(cid, q)
		if MapTerrain.butte_height(cb, cid, map.prow_u(cid, uv.y) - uv.x, uv.y) < y:
			break
	return [Vector3(q.x, y, q.z), out]


## A dark streak down a wall from (t_round, y_top), `length` long, in pieces that
## follow the wall, widening `widen` times towards the bottom.
func _streak(st: SurfaceTool, cid: int, t_round: float, y_top: float, length: float, w: float, widen: float, col: Color, col_low: Color) -> Vector3:
	var pieces := maxi(ceili(length / 3.0), 2)
	var last := Vector3.ZERO
	for j in pieces:
		var f := (float(j) + 0.5) / float(pieces)
		var wp: Array = _wall_point(cid, t_round, y_top - length * f)
		var out: Vector3 = wp[1]
		var b := Basis(out.cross(Vector3.UP).normalized(), Vector3.UP, out)
		last = wp[0]
		MeshKit.add_box(st, Transform3D(b, (wp[0] as Vector3) + out * 0.08), Vector3(w * lerpf(1.0, widen, f), length / pieces * 1.1, 0.06), col.lerp(col_low, f))
	return last


# ------------------------------------------------------------------ lakebed: salt pan

func _salt_pan(parent: Node3D, decals: SurfaceTool, props: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7070
	var c := Vector2(map.center.x, map.center.z) + _quarter_dir(0) * 72.0
	var poly := PackedVector2Array()
	var n := rng.randi_range(8, 12)
	for k in n:
		var a := TAU * (float(k) + rng.randf_range(-0.3, 0.3)) / float(n)
		poly.append(c + Vector2.from_angle(a) * rng.randf_range(25.0, 34.0))
	var outer: PackedVector2Array = Geometry2D.offset_polygon(poly, 7.0)[0]
	var rect := Rect2(c - Vector2(45, 45), Vector2(90, 90))
	var lift := func(x: float, z: float) -> float: return MapTerrain.floor_at(cb, x, z) + 0.03
	var lift_edge := func(x: float, z: float) -> float: return MapTerrain.floor_at(cb, x, z) + 0.025
	var in_pan := func(x: float, z: float) -> bool: return Geometry2D.is_point_in_polygon(Vector2(x, z), poly)
	var in_edge := func(x: float, z: float) -> bool:
		var p := Vector2(x, z)
		return Geometry2D.is_point_in_polygon(p, outer) and not Geometry2D.is_point_in_polygon(p, poly) and p.length() < MapTerrain.LAKE_R - 1.0
	t._add_visual(parent, "SaltPan", GroundKit.patch(rect, 1.0, lift, in_pan), Materials.strata(Color("#F0EBE0")), false)
	t._add_visual(parent, "SaltPanEdge", GroundKit.patch(rect, 1.0, lift_edge, in_edge), Materials.strata(Color("#EADCC0")), false)
	# Raised salt ridges round the cells of a polygon net.
	var pts := PackedVector2Array()
	var tries := 0
	while pts.size() < 70 and tries < 2000:
		tries += 1
		var p := c + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 34.0
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		var ok := true
		for q in pts:
			if q.distance_to(p) < 3.0:
				ok = false
				break
		if ok:
			pts.append(p)
	var edges := GroundKit.voronoi_edges(pts, 7.0)
	for e in edges.size() / 2:
		var a := edges[e * 2]
		var b := edges[e * 2 + 1]
		if not Geometry2D.is_point_in_polygon(a, poly) or not Geometry2D.is_point_in_polygon(b, poly):
			continue
		var w := rng.randf_range(0.05, 0.08)
		var hh := rng.randf_range(0.06, 0.12)
		var segs := maxi(ceili(a.distance_to(b)), 1)
		var dir := (b - a).normalized()
		for k in segs:
			var p0 := a.lerp(b, float(k) / segs)
			var p1 := a.lerp(b, float(k + 1) / segs)
			var h := hh + rng.randf_range(-0.02, 0.02)
			MeshKit.add_box(decals, Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), _at((p0 + p1) * 0.5, 0.03 + h * 0.5)), Vector3(w, h, p0.distance_to(p1) + 0.04), Color("#F8F4EC"))
	# Salt mounds on faint evaporation rings, in the pan's lowest hollows.
	var spots: Array[Vector2] = []
	for k in 50:
		var p := c + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 30.0
		if Geometry2D.is_point_in_polygon(p, poly):
			spots.append(p)
	spots.sort_custom(func(p: Vector2, q: Vector2) -> bool: return _floor(p.x, p.y) < _floor(q.x, q.y))
	for k in mini(15, spots.size()):
		var p := spots[k]
		var rr := rng.randf_range(0.3, 0.8)
		GroundKit.disc(decals, _ground(), p, Vector2.ONE * rr * 1.2, 0.0, 0.035, Color("#D8C8A8"))
		MeshKit.add_ellipsoid(decals, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _at(p, 0.03)), Vector3(rr, rng.randf_range(0.08, 0.2), rr * 0.85), 3, 9, Color("#F0ECE0"))
	# Crystal clusters: the glints seen from the butte tops.
	for k in 7:
		var p := c + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 24.0
		for j in rng.randi_range(3, 7):
			var tilt := deg_to_rad(rng.randf_range(30.0, 70.0)) * (0.5 if j == 0 else 1.0)
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, tilt)
			var hh := rng.randf_range(0.3, 0.8)
			var w := rng.randf_range(0.08, 0.2)
			MeshKit.add_box(props, Transform3D(b, _at(p + Vector2.from_angle(rng.randf() * TAU) * 0.15, 0.03) + b * Vector3(0, hh * 0.45, 0)), Vector3(w, hh, w * 0.8), Color("#FBF8F2"))
	# A few salt patches out on their own.
	for k in 4:
		var a := rng.randf() * TAU
		var p := c + Vector2.from_angle(a) * rng.randf_range(38.0, 46.0)
		if p.length() < MapTerrain.LAKE_R - 3.0 and _in_butte(p) < -4.0:
			GroundKit.disc(decals, _ground(), p, Vector2(rng.randf_range(1.0, 2.0), rng.randf_range(0.8, 1.5)), rng.randf() * TAU, 0.02, Color("#F0EBE0"))


# ------------------------------------------------------------------ lakebed: dust devils

func _dust_devils(parent: Node3D, decals: SurfaceTool, props: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var scars: Array[Vector3] = []
	for k in 10:
		for tries in 30:
			var p := _quarter_point(rng, 1, 40.0, 108.0, 16.0)
			var r := rng.randf_range(3.0, 6.0)
			var ok := p.length() + r < MapTerrain.LAKE_R - 2.0
			for s in scars:
				if Vector2(s.x, s.y).distance_to(p) < s.z + r + 3.0:
					ok = false
			if ok:
				scars.append(Vector3(p.x, p.y, r))
				break
	var in_scar := func(x: float, z: float) -> bool:
		for s in scars:
			if Vector2(s.x, s.y).distance_to(Vector2(x, z)) < s.z:
				return true
		return false
	var lift := func(x: float, z: float) -> float: return MapTerrain.floor_at(cb, x, z) + 0.025
	var box := Rect2(Vector2(scars[0].x, scars[0].y), Vector2.ZERO)
	for s in scars:
		box = box.expand(Vector2(s.x, s.y) - Vector2.ONE * s.z).expand(Vector2(s.x, s.y) + Vector2.ONE * s.z)
	t._add_visual(parent, "DustDevilScars", GroundKit.patch(box.grow(1.0), 0.75, lift, in_scar), Materials.strata(Color("#F2E4C6")), false)
	for s in scars:
		var p := Vector2(s.x, s.y)
		# The berm of swept-up dust round the edge, and debris dropped downwind.
		MeshKit.add_rim(decals, Transform3D(Basis(), _at(p, 0.03)), s.z + 0.45, s.z + 0.12, rng.randf_range(0.06, 0.1), 28, Color("#C8B090"))
		for j in rng.randi_range(3, 5):
			var q := p + WIND.rotated(rng.randf_range(-0.6, 0.6)) * (s.z + rng.randf_range(0.8, 1.6))
			var sz := rng.randf_range(0.1, 0.3)
			MeshKit.add_box(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _at(q, 0.03)), Vector3(sz, 0.04, sz * 0.7), Color("#8A7058").lightened(rng.randf() * 0.2))
	# Drifts of fine dust banked against cracks, all lying the same way.
	for k in 18:
		var p := _quarter_point(rng, 1, 38.0, 110.0, 10.0)
		var yaw := atan2(WIND.x, WIND.y) + rng.randf_range(-0.15, 0.15)
		var b := Basis(Vector3.UP, yaw)
		var length := rng.randf_range(0.8, 1.5)
		GroundKit.wedge(decals, Transform3D(b, _at(p, 0.0)), length, rng.randf_range(0.3, 0.6), rng.randf_range(0.15, 0.3), Color("#D8C8A8"))
		var side := Vector2(WIND.y, -WIND.x)
		GroundKit.seam(decals, _ground(), p - side * length * 0.7 - WIND * 0.05, p + side * length * 0.7 - WIND * 0.05, 0.07, 0.03, Color("#8A6E50"))
	# Whirlwind traces: spiral scratches where the devils danced.
	for k in 4:
		var p := _quarter_point(rng, 1, 45.0, 105.0, 14.0)
		var size := rng.randf_range(2.0, 4.0)
		var turns := rng.randf_range(1.5, 2.0)
		var arcs := rng.randi_range(8, 12)
		var a0 := rng.randf() * TAU
		for j in arcs:
			var path: Array[Vector2] = []
			for m in 5:
				var f := (float(j) + float(m) / 4.0 * 0.7) / float(arcs)
				var a := a0 + f * turns * TAU
				path.append(p + Vector2.from_angle(a) * size * exp(1.6 * (f - 1.0)))
			GroundKit.strip(decals, _ground(), path, 0.04, 0.03, Color("#9A7E60"))


# ------------------------------------------------------------------ lakebed: animal trails

## A point on the lakebed just off butte cid's foot, nearest `toward`.
func _foot_point(cid: int, toward: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for k in 40:
		var p := t._rim_point_at(cid, float(k) / 40.0, 26.0)
		var q := Vector2(p.x, p.z)
		var d := q.distance_to(toward)
		if d < best_d:
			best_d = d
			best = q
	return best


func _plan_trails() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7272
	var c := Vector2(map.center.x, map.center.z)
	var mid := c + _quarter_dir(2) * 70.0
	var a := _foot_point(2, mid)
	var b := _foot_point(3, mid)
	var side := (b - a).orthogonal().normalized()
	if side.dot(mid - c) < 0.0:
		side = -side
	var pool := c + _quarter_dir(2) * 42.0 - a.lerp(b, 0.5)
	# Direct, swinging out wide of the fissures, and looping in towards the old water.
	var routes := [[5, 2.0, Vector2.ZERO], [7, 3.0, side * 14.0], [8, 2.0, pool]]
	for route: Array in routes:
		var ctrl: Array[Vector2] = []
		var n := int(route[0])
		for k in n:
			var f := float(k) / float(n - 1)
			var jit := Vector2.ZERO if k == 0 or k == n - 1 else Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * float(route[1])
			ctrl.append(a.lerp(b, f) + (route[2] as Vector2) * sin(f * PI) + jit)
		var path := GroundKit.spline(ctrl, 8)
		trails.append([path, rng.randf_range(1.2, 1.8)])
		for p in path:
			_trail_box = _trail_box.expand(p) if _trail_box.has_area() else Rect2(p, Vector2(0.01, 0.01))
	_trail_box = _trail_box.grow(3.0)


## True on (or right beside) an animal trail: the lake's cracks are worn away there.
func on_trail(p: Vector3) -> bool:
	var q := Vector2(p.x, p.z)
	if not _trail_box.has_point(q):
		return false
	for tr: Array in trails:
		if GroundKit.path_distance(tr[0], q).x < 1.2:
			return true
	return false


func _animal_trails(decals: SurfaceTool, props: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7373
	for tr: Array in trails:
		var path: Array[Vector2] = tr[0]
		var w := float(tr[1])
		GroundKit.strip(decals, _ground(), path, w, 0.02, Color("#B89870"))
		GroundKit.strip(decals, _ground(), path, w * 0.45, 0.024, Color("#AE8E66"))
		# Hoof prints in little clusters, stepping left and right.
		var i := 2
		var sgn := 1.0
		while i < path.size() - 2:
			var dir := (path[i + 1] - path[i - 1]).normalized()
			var c := path[i] + dir.orthogonal() * sgn * rng.randf_range(0.1, 0.35)
			for k in rng.randi_range(4, 8):
				var q := c + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
				GroundKit.disc(decals, _ground(), q, Vector2(rng.randf_range(0.03, 0.06), rng.randf_range(0.03, 0.05)), dir.angle(), 0.03, Color("#8A6E50"), 0.0, 6)
			sgn = -sgn
			i += rng.randi_range(2, 3)
	# A resting hollow where the trails meet by the Basalt butte, a few bones at its edge.
	var path0: Array[Vector2] = trails[0][0]
	var hollow := path0[4] + (path0[5] - path0[3]).normalized().orthogonal() * 2.5
	GroundKit.disc(decals, _ground(), hollow, Vector2(1.5, 1.0), rng.randf() * TAU, 0.022, Color("#A88060"))
	for k in 20:
		var q := hollow + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.0, 2.6)
		GroundKit.disc(decals, _ground(), q, Vector2(0.05, 0.04), rng.randf() * TAU, 0.03, Color("#8A6E50"), 0.0, 6)
	for k in 4:
		var q := hollow + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.4, 1.8)
		MeshKit.add_box(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _at(q, 0.04)), Vector3(0.04, 0.035, rng.randf_range(0.1, 0.3)), Color("#E8DCC4"))


# ------------------------------------------------------------------ lakebed: rubble field

func _rubble_field(decals: SurfaceTool, props: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7474
	var ochre := [Color("#D99A3E"), Color("#C88438"), Color("#E0A850")]
	var red := [Color("#B8452C"), Color("#C9603A"), Color("#A84030")]
	var made := 0
	var tries := 0
	while made < 70 and tries < 900:
		tries += 1
		var p := _quarter_point(rng, 3, 36.0, 112.0, 4.0)
		# Thicker near the butte feet, thin out in the open.
		var near := 1.0 - smoothstep(6.0, 30.0, -_in_butte(p)) * 0.7
		if rng.randf() > near:
			continue
		made += 1
		var col: Color = (ochre[rng.randi() % 3] if rng.randf() < 0.6 else red[rng.randi() % 3])
		var w := rng.randf_range(0.3, 1.2) * rng.randf_range(0.85, 1.15)
		var hh := rng.randf_range(0.05, 0.15)
		MeshKit.add_box(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)), _at(p, hh * 0.4)), Vector3(w, hh, w * rng.randf_range(0.6, 1.0)), col.darkened(rng.randf() * 0.1), w * 0.06, rng)
	# Big slabs that fell from height, some leaning together like little tents.
	for k in 10:
		var p := _quarter_point(rng, 3, 50.0, 106.0, 8.0)
		var col: Color = (ochre[k % 3] if k % 5 < 3 else red[k % 3])
		var w := rng.randf_range(2.0, 4.0)
		var th := rng.randf_range(0.2, 0.4)
		var yaw := rng.randf() * TAU
		if k < 3:
			# A tent of two slabs leaning on each other.
			for sgn: float in [-1.0, 1.0]:
				var b := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, sgn * 0.9)
				MeshKit.add_box(props, Transform3D(b, _at(p, w * 0.3) + Basis(Vector3.UP, yaw) * Vector3(sgn * w * 0.3, 0, 0)), Vector3(w * 0.8, th, w * 0.7), col, 0.05, rng)
			GroundKit.disc(decals, _ground(), p, Vector2(w * 0.6, w * 0.4), yaw, 0.012, Color("#6A5A40"))
			continue
		var tilt := deg_to_rad(rng.randf_range(10.0, 30.0))
		var b2 := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
		MeshKit.add_box(props, Transform3D(b2, _at(p, sin(tilt) * w * 0.35)), Vector3(w, th, w * rng.randf_range(0.6, 0.9)), col, 0.06, rng)
		GroundKit.disc(decals, _ground(), p, Vector2(w * 0.5, w * 0.35), yaw, 0.012, Color("#6A5A40"))
		if k >= 6:
			# Its impact cracked the dried mud in a starburst.
			for j in rng.randi_range(4, 6):
				var a := rng.randf() * TAU
				GroundKit.seam(decals, _ground(), p + Vector2.from_angle(a) * w * 0.4, p + Vector2.from_angle(a) * (w * 0.4 + rng.randf_range(1.0, 2.0)), 0.05, 0.03, Color("#6E5438"))
	# A big old bone half buried near the middle of the field (like the mesa's fossil bed).
	var mid := Vector2(map.center.x, map.center.z) + _quarter_dir(3) * 64.0
	var yaw := rng.randf() * TAU
	MeshKit.add_box(props, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, 0.06), _at(mid, 0.0)), Vector3(1.8, 0.2, 0.15), Color("#E0D0B0"))
	for k in 3:
		MeshKit.add_box(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _at(mid + Vector2.from_angle(yaw + 1.6) * 0.3 + Vector2.from_angle(yaw) * (k - 1) * 0.6, 0.12)), Vector3(0.6, 0.2, 0.5), (ochre[k % 3] as Color), 0.05, rng)


# ------------------------------------------------------------------ butte upgrades

func _butte(parent: Node3D, cid: int, decals: SurfaceTool, props: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8800 + cid * 13
	var rock := MeshKit.begin()
	match map.cliffs[cid].style:
		&"ledges":
			_ledges(cid, rng, rock, props)
		&"layers":
			_layers(cid, rng, rock, props)
		&"basalt":
			_basalt(cid, rng, rock, props)
		&"buttress":
			_buttress(cid, rng, rock, props, decals)
	var m := MeshKit.finish(rock)
	if m.get_surface_count() > 0:
		t._add_visual(parent, "ButteRockMore%d" % cid, m, t.rock_material(cid))


## Ledges: erosion alcoves with seep stains below, the windmill's scattered
## wreckage and its dry trough, and nests on the highest shelves.
func _ledges(cid: int, rng: RandomNumberGenerator, rock: SurfaceTool, props: SurfaceTool) -> void:
	var used: Array[Vector2] = []
	for k in 5:
		var tr := 0.0
		var y := 0.0
		for tries in 30:
			tr = rng.randf()
			# Mid-riser (the shelves sit at 20 and 40 m), above the scree.
			y = rng.randf_range(27.0, 34.0) if rng.randf() < 0.4 else rng.randf_range(45.0, 53.0)
			var ok := true
			for u in used:
				if absf(u.x - tr) < 0.06 and absf(u.y - y) < 8.0:
					ok = false
			if ok:
				break
		used.append(Vector2(tr, y))
		var wp: Array = _wall_point(cid, tr, y)
		var at: Vector3 = wp[0]
		var out: Vector3 = wp[1]
		var w := rng.randf_range(3.0, 5.0)
		var hh := rng.randf_range(1.5, 2.5)
		var b := Basis(out.cross(Vector3.UP).normalized(), Vector3.UP, out)
		# Sunk into the wall so only its dark mouth shows.
		var deep := rng.randf_range(1.0, 1.5)
		MeshKit.add_ellipsoid(props, Transform3D(b, at - out * (deep - 0.12)), Vector3(w * 0.5, hh * 0.5, deep), 4, 10, Color("#3A1808"))
		# The overhanging lip of harder rock above it.
		MeshKit.add_box(rock, Transform3D(b, at + Vector3(0, hh * 0.5 + 0.25, 0) + out * 0.2), Vector3(w * 1.15, 0.5, 1.2), Color.WHITE, 0.15, rng)
		var foot := _streak(props, cid, tr, y - hh * 0.45, rng.randf_range(8.0, 15.0), 0.15, 2.6, Color("#6E2A22"), Color("#8E4A3A"))
		MeshKit.add_ellipsoid(props, Transform3D(b * Basis(Vector3.RIGHT, -0.9), foot + out * 0.3), Vector3(0.75, 0.4, 0.06), 3, 8, Color("#5A2A18"))
	# The windmill's wreckage round where it fell.
	var base := cb.plateau_point(cid, 37.0, 9.0)
	var yaw := map.facing_yaw(cid)
	for k in 5:
		var a := yaw + rng.randf_range(-PI, PI)
		var p := base + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(3.0, 8.0)
		var bb := Basis(Vector3.UP, rng.randf() * TAU)
		p.y = cb.ground_height_at(cid, p) + (-0.06 if k % 2 == 0 else 0.02)
		GroundKit.wedge(props, Transform3D(bb, p), rng.randf_range(0.8, 1.5), 0.3, 0.05, Palette.WOOD)
	var coil: Array = []
	var radii: Array = []
	for k in 16:
		var a := float(k) / 15.0 * TAU * 0.75
		coil.append(base + Basis(Vector3.UP, yaw + 0.6) * Vector3(cos(a) * 1.2 - 1.5, 1.1 + 0.25 * sin(a * 2.0), sin(a) * 1.2))
		radii.append(0.03)
	MeshKit.tube(props, coil, radii, 5, Palette.METAL.darkened(0.2))
	for k in 4:
		var p := base + Basis(Vector3.UP, yaw) * Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(4.5, 6.5))
		p.y = cb.ground_height_at(cid, p) + 0.02
		MeshKit.add_cylinder(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), rng.randf_range(0.15, 0.3), rng.randf_range(0.15, 0.3), 0.04, 7, Palette.METAL)
	var sp := base + Basis(Vector3.UP, yaw) * Vector3(2.4, 0.0, 1.5)
	sp.y = cb.ground_height_at(cid, sp) + 0.06
	var sb := Basis(Vector3.UP, yaw + 0.3)
	MeshKit.add_box(props, Transform3D(sb, sp + sb * Vector3(-0.5, 0, 0)), Vector3(1.0, 0.08, 0.1), Palette.METAL)
	var sb2 := sb * Basis(Vector3.UP, deg_to_rad(25.0))
	MeshKit.add_box(props, Transform3D(sb2, sp + sb2 * Vector3(0.5, 0, 0)), Vector3(1.0, 0.08, 0.1), Palette.METAL)
	_trough(props, cb.plateau_point(cid, 33.5, 5.0), yaw + 0.2, Vector3(2.0, 0.4, 0.6), false, Color("#E3CFAA"))
	# Nests on the highest shelves.
	var shelves: Array = (t.butte_log.get(cid, []) as Array).duplicate()
	shelves.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector3).y > (b[0] as Vector3).y)
	for k in mini(4, shelves.size()):
		var s: Array = shelves[k]
		var top: Vector3 = (s[0] as Vector3) + Vector3(0, (s[1] as Vector3).y * 0.5 + 0.05, 0) + (s[2] as Vector3) * 0.8
		for j in 7:
			var a := TAU * float(j) / 7.0
			MeshKit.add_box(props, Transform3D(Basis(Vector3.UP, a + 1.5) * Basis(Vector3.RIGHT, 0.3), top + Vector3(cos(a) * 0.15, 0.04, sin(a) * 0.15)), Vector3(0.025, 0.025, rng.randf_range(0.12, 0.22)), Palette.WOOD_DARK.darkened(0.3))
		for j in rng.randi_range(2, 3):
			MeshKit.add_ellipsoid(props, Transform3D(Basis(), top + Vector3(rng.randf_range(-0.05, 0.05), 0.04, rng.randf_range(-0.05, 0.05))), Vector3(0.025, 0.03, 0.025), 3, 6, Color("#F0ECE0"))


## An open wooden trough (one end broken out, or one long side caved in), with
## dust lying in its bottom.
func _trough(st: SurfaceTool, at: Vector3, yaw: float, size: Vector3, caved: bool, dust: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	var wood := Palette.WOOD if caved else Palette.WOOD_DARK
	MeshKit.add_box(st, Transform3D(b, at + Vector3(0, 0.04, 0)), Vector3(size.x, 0.06, size.z), wood)
	MeshKit.add_box(st, Transform3D(b, at + b * Vector3(0, size.y * 0.5, size.z * 0.5)), Vector3(size.x, size.y, 0.06), wood)
	MeshKit.add_box(st, Transform3D(b, at + b * Vector3(-size.x * 0.5, size.y * 0.5, 0)), Vector3(0.06, size.y, size.z), wood)
	if caved:
		var cv := b * Basis(Vector3.RIGHT, deg_to_rad(40.0))
		MeshKit.add_box(st, Transform3D(cv, at + b * Vector3(0, size.y * 0.4, -size.z * 0.35)), Vector3(size.x, size.y, 0.06), wood)
		MeshKit.add_box(st, Transform3D(b, at + b * Vector3(size.x * 0.5, size.y * 0.5, 0)), Vector3(0.06, size.y, size.z), wood)
		# The dry waterline round the inside.
		MeshKit.add_box(st, Transform3D(b, at + b * Vector3(0, 0.3, size.z * 0.5 - 0.04)), Vector3(size.x * 0.98, 0.04, 0.02), Color("#4A3A2A"))
	else:
		MeshKit.add_box(st, Transform3D(b, at + b * Vector3(0, size.y * 0.5, -size.z * 0.5)), Vector3(size.x, size.y, 0.06), wood)
		# The broken end: a stub of board.
		MeshKit.add_box(st, Transform3D(b * Basis(Vector3.BACK, 0.4), at + b * Vector3(size.x * 0.5 + 0.1, size.y * 0.25, 0.1)), Vector3(0.06, size.y * 0.5, size.z * 0.5), wood)
		MeshKit.add_box(st, Transform3D(b, at + Vector3(0, 0.2, 0)), Vector3(size.x * 0.96, 0.04, size.z * 0.9), dust)


## Layers: varnish streaks from the hard lips, shallow caves, lichen on the arch,
## an ammonite in the wall and petrified roots hanging from cracks.
func _layers(cid: int, rng: RandomNumberGenerator, rock: SurfaceTool, props: SurfaceTool) -> void:
	var made := 0
	while made < 26:
		var tr := rng.randf()
		var p := t._rim_point_at(cid, tr, 0.0)
		var out := t._rim_out(cid, p)
		# More on the sun-facing (south) walls.
		if out.z < 0.2 and rng.randf() < 0.5:
			continue
		made += 1
		var y := floorf(rng.randf_range(30.0, 58.0) / 4.0) * 4.0 + 0.5 + rng.randf_range(-0.3, 0.3)
		var col := Color("#5A4030").lightened(rng.randf_range(-0.15, 0.15))
		_streak(props, cid, tr, y, rng.randf_range(6.0, 18.0), rng.randf_range(0.2, 0.6), 1.3, col, col.darkened(0.1))
	for k in 5:
		var tr := rng.randf()
		var y := floorf(rng.randf_range(30.0, 52.0) / 4.0) * 4.0 + 2.5
		var wp: Array = _wall_point(cid, tr, y)
		var at: Vector3 = wp[0]
		var out: Vector3 = wp[1]
		var b := Basis(out.cross(Vector3.UP).normalized(), Vector3.UP, out)
		var w := rng.randf_range(1.5, 2.5)
		var hh := rng.randf_range(1.0, 1.5)
		var deep := rng.randf_range(0.8, 1.2)
		MeshKit.add_ellipsoid(props, Transform3D(b, at - out * (deep - 0.1)), Vector3(w * 0.5, hh * 0.5, deep), 4, 10, Color("#2A1A10"))
		MeshKit.add_box(rock, Transform3D(b, at + Vector3(0, hh * 0.5 + 0.15, 0) + out * 0.15), Vector3(w * 1.3, 0.3, 0.8), Color.WHITE, 0.08, rng)
		if k < 2:
			MeshKit.add_ellipsoid(props, Transform3D(b, at - Vector3(0, hh * 0.5 + 0.9, 0) + out * 0.05), Vector3(0.5, 0.25, 0.04), 3, 8, Color("#4A3828"))
	# Lichen on the arch (most on its north side) and round the pillar's feet.
	var c := map.cliffs[cid]
	var foot_a := map.to_world(cid, map.prow_u(cid, map.span_v) - 6.0, map.span_v + 1.5)
	var foot_b := foot_a + c.along * 22.0 + c.inward * 6.0
	foot_a.y = _floor(foot_a.x, foot_a.z) - 1.0
	foot_b.y = _floor(foot_b.x, foot_b.z) - 1.0
	var top := maxf(foot_a.y, foot_b.y) + 44.0
	var side := (foot_b - foot_a).cross(Vector3.UP).normalized()
	if side.z > 0.0:
		side = -side # the north face
	for k in 15:
		var f := rng.randf_range(0.12, 0.88)
		var p0 := ArchBuilder._point(foot_a, foot_b, top, f - 0.01)
		var p1 := ArchBuilder._point(foot_a, foot_b, top, f + 0.01)
		var mid := (p0 + p1) * 0.5
		var dir := (p1 - p0).normalized()
		var up := dir.cross(side).normalized()
		if up.y < 0.0:
			up = -up
		var fat := lerpf(2.8, 6.0, pow(absf(f - 0.5) * 2.0, 1.6))
		var rr := rng.randf_range(0.6, 1.0) if k < 4 else rng.randf_range(0.2, 0.5)
		var on_side := k % 3 == 0
		var n := side if on_side else up
		var at := mid + up * fat * (0.2 if on_side else 0.7) + side * (fat * 1.1 if on_side else rng.randf_range(-0.6, 0.6) * fat)
		var col := Color("#7A8A6A").lerp(Color("#8A9A7A"), rng.randf()).lightened(rng.randf_range(-0.1, 0.1))
		MeshKit.add_ellipsoid(props, Transform3D(MeshKit.basis_from_y(n), at), Vector3(rr, 0.03, rr * rng.randf_range(0.6, 0.9)), 2, 9, col)
	for k in 5:
		var a := rng.randf() * TAU
		var at := foot_b + Vector3(cos(a) * 5.55, rng.randf_range(1.3, 2.4), sin(a) * 5.55)
		MeshKit.add_ellipsoid(props, Transform3D(MeshKit.basis_from_y(Vector3(cos(a), 0.0, sin(a))), at), Vector3(rng.randf_range(0.25, 0.5), 0.03, 0.3), 2, 9, Color("#7A8A6A"))
	# An ammonite standing out of the wall, facing the lake.
	var fw: Array = _wall_point(cid, 0.16, 33.0)
	var fo: Vector3 = fw[1]
	GroundKit.spiral(props, Transform3D(MeshKit.basis_from_y(fo), (fw[0] as Vector3) + fo * 0.02), 0.6, 2.5, 20, 0.12, Color("#C0A070"))
	# Petrified roots hanging out of cracks.
	for k in 7:
		var wp: Array = _wall_point(cid, rng.randf(), rng.randf_range(32.0, 42.0))
		var at: Vector3 = wp[0]
		var out: Vector3 = wp[1]
		var length := rng.randf_range(1.5, 4.0)
		var pts: Array = []
		var rads: Array = []
		var r0 := rng.randf_range(0.03, 0.06)
		for j in 6:
			var f := float(j) / 5.0
			pts.append(at + out * (0.1 + sin(f * PI * 0.6) * 0.6) - Vector3(0, f * f * length, 0) + out.cross(Vector3.UP) * sin(f * 3.0 + k) * 0.15)
			rads.append(r0 * (1.0 - f * 0.7))
		MeshKit.tube(props, pts, rads, 5, Color("#6A5A4A"))


## Basalt: joint lines round the columns, a few columns broken and toppled, and
## the mine's workings (tailings, a spur line, a vent shaft, tools and a sign).
func _basalt(cid: int, rng: RandomNumberGenerator, rock: SurfaceTool, props: SurfaceTool) -> void:
	var cols: Array = t.butte_log.get(cid, [])
	for col: Array in cols:
		var at: Vector3 = col[0]
		var r := float(col[1])
		var h := float(col[2])
		var base := at.y - h * 0.5
		# (Raised 18 m, above the scree heaped round the foot.)
		for jy: float in [26.0, 34.0, 42.0]:
			if jy < h - 1.0 and (jy < 40.0 or rng.randf() < 0.5):
				MeshKit.add_cylinder(props, Transform3D(Basis(), Vector3(at.x, base + jy, at.z)), r + 0.05, r * 0.95 + 0.05, 0.08, 6, Color("#2E2C30"))
	# Broken columns: a heap where each snapped, the rest lying out past the scree.
	var shortest := cols.duplicate()
	shortest.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) < float(b[2]))
	for k in mini(5, shortest.size()):
		var col: Array = shortest[k * 3 % shortest.size()]
		var at: Vector3 = col[0]
		var r := float(col[1])
		var h := float(col[2])
		var out: Vector3 = col[3]
		var tip := at + Vector3(0, h * 0.5, 0)
		for j in rng.randi_range(5, 7):
			var s := rng.randf_range(0.2, 0.5)
			MeshKit.add_box(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), tip + Vector3(rng.randf_range(-r, r) * 0.7, s * 0.4, rng.randf_range(-r, r) * 0.7)), Vector3.ONE * s, Color.WHITE, s * 0.2, rng)
		var length := rng.randf_range(6.0, 12.0)
		var lie := at + out * rng.randf_range(24.0, 28.0)
		lie.y = _floor(lie.x, lie.z) + r * 0.6
		var lb := Basis(Vector3.UP, atan2(out.x, out.z) + rng.randf_range(-0.6, 0.6)) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(70.0, 80.0)))
		MeshKit.add_cylinder(rock, Transform3D(lb, lie), r, r * 0.95, length, 6, Color.WHITE)
		for j in rng.randi_range(3, 5):
			var s := rng.randf_range(0.2, 0.45)
			MeshKit.add_box(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), lie + lb * Vector3(0, length * 0.5 + 0.2, 0) + Vector3(rng.randf_range(-0.5, 0.5), -r * 0.4, rng.randf_range(-0.5, 0.5))), Vector3.ONE * s, Color.WHITE, s * 0.2, rng)
	# The mine's workings, round the existing portal.
	var knoll := cb.plateau_point(cid, 37.5, -12.0)
	var b := Basis(Vector3.UP, map.facing_yaw(cid) + PI)
	var front := knoll + b * Vector3(0, 0, -2.2)
	var dark := Color("#3A3838")
	var tail := front + b * Vector3(4.2, 0.0, -3.0)
	MeshKit.add_ellipsoid(props, Transform3D(b, tail), Vector3(2.5, 1.0, 3.5), 4, 10, dark, 0.15, rng)
	for k in 18:
		var p := tail + b * Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-4.5, 4.5))
		var on := Vector2((p - tail).x, (p - tail).z).length() < 2.6
		p.y = (tail.y + 0.85) if on else (front.y + 0.05)
		var s := rng.randf_range(0.1, 0.4)
		MeshKit.add_box(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(s, s * 0.6, s * 0.8), dark.lightened(rng.randf() * 0.15), s * 0.15, rng)
	# The spur line off the main rails, to a loading platform.
	var sb := b * Basis(Vector3.UP, deg_to_rad(20.0))
	var split := front + b * Vector3(0.0, 0.0, -3.0)
	for k in 3:
		MeshKit.add_box(props, Transform3D(sb, split + sb * Vector3(0, 0.08, -0.8 - k * 1.2)), Vector3(1.4, 0.1, 0.18), Palette.WOOD_DARK)
	for sx: float in [-0.5, 0.5]:
		MeshKit.add_box(props, Transform3D(sb, split + sb * Vector3(sx, 0.16, -2.0)), Vector3(0.08, 0.08, 4.0), Palette.METAL)
	MeshKit.add_box(props, Transform3D(sb, split + sb * Vector3(0, 0.15, -4.8)), Vector3(2.0, 0.3, 1.5), Palette.WOOD, 0.03, rng)
	# A vent shaft up behind the portal, dust drifting off it.
	var vent := knoll + b * Vector3(-3.0, 0.0, 7.5)
	vent.y = cb.ground_height_at(cid, vent)
	MeshKit.add_box(props, Transform3D(b, vent + Vector3(0, 0.12, 0)), Vector3(1.2, 0.3, 1.2), Color("#0E0A08"))
	for sx: float in [-0.7, 0.7]:
		for sz: float in [-0.7, 0.7]:
			MeshKit.add_box(props, Transform3D(b, vent + b * Vector3(sx, 1.25, sz)), Vector3(0.15, 2.5, 0.15), Palette.WOOD_DARK)
	for k in 4:
		var bb := b * Basis(Vector3.UP, PI * 0.5 * k)
		MeshKit.add_box(props, Transform3D(bb, vent + bb * Vector3(0, 2.45, 0.7)), Vector3(1.55, 0.15, 0.15), Palette.WOOD_DARK)
	var vy := vent.y
	GroundKit.disc(props, func(_x: float, _z: float) -> float: return vy, Vector2(vent.x, vent.z) + Vector2(0.8, 0.6), Vector2(1.0, 0.7), 0.6, 0.05, Color("#8A8280"))
	# Picks leaning on the tailings and lying about, and a weathered warning sign.
	for k in 3:
		var p := tail + b * Vector3(-2.2 + k * 0.4, 0.0, -1.5 + k * 1.6)
		p.y = front.y
		var pb := b * Basis(Vector3.UP, k * 1.1) * Basis(Vector3.BACK, 0.5 if k < 2 else 1.5)
		MeshKit.add_box(props, Transform3D(pb, p + pb * Vector3(0, 0.4, 0)), Vector3(0.05, 0.8, 0.05), Palette.WOOD)
		MeshKit.add_box(props, Transform3D(pb * Basis(Vector3.BACK, 0.15), p + pb * Vector3(0, 0.8, 0)), Vector3(0.45, 0.06, 0.05), Palette.METAL)
	var sign_at := front + b * Vector3(-2.6, 0.0, -1.6)
	var signb := b * Basis(Vector3.BACK, deg_to_rad(15.0))
	MeshKit.add_box(props, Transform3D(signb, sign_at + signb * Vector3(0, 0.6, 0)), Vector3(0.08, 1.2, 0.08), Palette.WOOD_DARK)
	MeshKit.add_box(props, Transform3D(signb, sign_at + signb * Vector3(0, 1.25, 0)), Vector3(0.8, 0.5, 0.04), Palette.WOOD.lightened(0.15))


## Buttress: dark slots between close fins, split fin tips, and the water
## tower's leaks: a snapped pipe, rust stains, a caved trough, a pump handle.
func _buttress(cid: int, rng: RandomNumberGenerator, rock: SurfaceTool, props: SurfaceTool, decals: SurfaceTool) -> void:
	var fins: Array = t.butte_log.get(cid, [])
	var slots := 0
	for i in fins.size():
		for j in range(i + 1, fins.size()):
			var a: Vector3 = fins[i][0]
			var bb: Vector3 = fins[j][0]
			var d := Vector2(a.x - bb.x, a.z - bb.z).length()
			if d > 7.5 or d < 4.0 or slots >= 11:
				continue
			slots += 1
			var mid := (a + bb) * 0.5
			var out := ((fins[i][1] as Vector3) + (fins[j][1] as Vector3)).normalized()
			var fy := float(fins[i][2])
			var hh := rng.randf_range(4.0, 10.0)
			var y := fy + rng.randf_range(30.0, 40.0)
			var b := Basis(out.cross(Vector3.UP).normalized(), Vector3.UP, out)
			MeshKit.add_box(props, Transform3D(b, Vector3(mid.x, y, mid.z) + out * 1.6), Vector3(rng.randf_range(0.4, 0.8), hh, rng.randf_range(1.5, 2.5)), Color("#1A1410"))
			MeshKit.add_box(props, Transform3D(b, Vector3(mid.x, y + hh * 0.5 + 2.0, mid.z) + out * 2.75), Vector3(0.15, rng.randf_range(3.0, 5.0), 0.05), Color("#6A5A40"))
	# Split fin tips, with the bits that fell out of the split at the next step down.
	for k in mini(5, fins.size()):
		var f: Array = fins[(k * 3 + 1) % fins.size()]
		var p: Vector3 = f[0]
		var out: Vector3 = f[1]
		var fy := float(f[2])
		var b := Basis(Vector3.UP, atan2(out.x, out.z))
		var tip := Vector3(p.x, fy + 53.0, p.z) + out * 2.0
		var spread := deg_to_rad(rng.randf_range(15.0, 25.0)) * 0.5
		for sgn: float in [-1.0, 1.0]:
			var tb := b * Basis(Vector3.BACK, sgn * spread)
			MeshKit.add_box(rock, Transform3D(tb, tip + b * Vector3(sgn * 0.85, 1.2, 0)), Vector3(1.5, 2.6, 3.6), Color.WHITE, 0.2, rng)
		MeshKit.add_box(props, Transform3D(b, tip + Vector3(0, 0.6, 0)), Vector3(0.06, 2.0, 3.7), Color("#1A1410"))
		for j in rng.randi_range(3, 5):
			var s := rng.randf_range(0.2, 0.5)
			MeshKit.add_box(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, fy + 37.0 + s * 0.4, p.z) + out * rng.randf_range(4.5, 8.5) + b * Vector3(rng.randf_range(-1.0, 1.0), 0, 0)), Vector3.ONE * s, Color.WHITE, s * 0.2, rng)
	# The water tower's leaks (it leans on the rim behind the fence).
	var at := cb.plateau_point(cid, 38.0, 12.0)
	var lean := Basis(Vector3.UP, map.facing_yaw(cid)) * Basis(Vector3.BACK, 0.16)
	var xf := Transform3D(lean, at)
	MeshKit.add_cylinder(props, xf * Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(0.7, 4.55, 0.4)), 0.08, 0.08, 1.5, 7, Palette.METAL)
	var drip := xf * Vector3(1.2, 0.0, 0.4)
	var ground := func(x: float, z: float) -> float: return cb.ground_height_at(cid, Vector3(x, 0.0, z))
	var dp := Vector2(drip.x, drip.z)
	GroundKit.disc(decals, ground, dp, Vector2(1.0, 0.75), rng.randf() * TAU, 0.03, Color("#B86830"))
	var downhill := Vector2(-map.cliffs[cid].inward.x, -map.cliffs[cid].inward.z).normalized()
	for k in 7:
		var q := dp + downhill * (1.4 + k * 0.7) + downhill.orthogonal() * rng.randf_range(-0.4, 0.4)
		GroundKit.disc(decals, ground, q, Vector2.ONE * rng.randf_range(0.1, 0.2), 0.0, 0.03, Color("#B86830"))
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		MeshKit.add_cylinder(props, xf * Transform3D(Basis(Vector3.RIGHT, PI), Vector3(cos(a) * 0.8, 5.1 - 0.12, sin(a) * 0.8)), 0.03, 0.0, rng.randf_range(0.15, 0.3), 5, Color("#E0D8C8"))
	var trough_at := cb.plateau_point(cid, 34.0, 15.5)
	_trough(props, trough_at, map.facing_yaw(cid) + 0.3, Vector3(3.0, 0.5, 0.8), true, Color.WHITE)
	var hb := Basis(Vector3.UP, map.facing_yaw(cid) + 1.1)
	var hp := trough_at + hb * Vector3(0.0, 0.03, 1.2)
	MeshKit.add_box(props, Transform3D(hb, hp), Vector3(0.6, 0.04, 0.08), Palette.METAL)
	MeshKit.add_box(props, Transform3D(hb, hp + hb * Vector3(0.3, 0.0, 0.12)), Vector3(0.04, 0.04, 0.3), Palette.METAL)


# ------------------------------------------------------------------ desert ring

func _desert_h(x: float, z: float) -> float:
	return MapTerrain.floor_at(cb, x, z) - 0.05


func _desert(parent: Node3D, decals: SurfaceTool, props: SurfaceTool) -> void:
	var h := func(x: float, z: float, _r: float) -> float: return MapTerrain.floor_at(cb, x, z) - 0.05
	var lake_r := MapTerrain.LAKE_R
	# Wind-scoured pavement round the buttes, open desert, then ground fading into the haze.
	t._add_visual(parent, "DesertApron", t.ring_rows(_radii(lake_r, 200.0, 4.0), 192, h), Materials.strata(Color("#C8A060")), false)
	t._add_visual(parent, "Desert", t.ring_rows(_radii(200.0, 1200.0, 8.0), 192, h), Materials.strata(Color("#D9A35E")), false)
	t._add_visual(parent, "DesertHaze", t.ring_rows(_radii(1200.0, CliffBuilder.HINTER, 40.0), 96, h), Materials.strata(Color("#DCC4A0")), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9090
	_apron(parent, decals, props, rng)
	_rock_garden(props, decals, rng)
	_dune_sea(parent, props, decals, rng)


func _radii(r0: float, r1: float, first: float) -> Array[float]:
	var rs: Array[float] = []
	var step := first
	var r := r0
	while r < r1:
		rs.append(r)
		r += step
		step = minf(step * 1.12, 90.0)
	rs.append(r1)
	return rs


func _dat(p: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(p.x, _desert_h(p.x, p.y) + lift, p.y)


## Butte aprons: drifts banked on each butte's lee side, and gravel pans in the gaps.
func _apron(parent: Node3D, decals: SurfaceTool, props: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var sand := [MeshKit.begin(), MeshKit.begin(), MeshKit.begin()] # plain, basalt-dark, layers-pale
	var c := Vector2(map.center.x, map.center.z)
	for cid in map.count():
		var style := map.cliffs[cid].style
		var which := 1 if style == &"basalt" else (2 if style == &"layers" else 0)
		var bc := c + Vector2(map.cliffs[cid].origin.x, map.cliffs[cid].origin.z).normalized() * 58.0
		for k in rng.randi_range(3, 5):
			# Out past the scree on the butte's south-east (downwind) side.
			var p := bc + WIND.rotated(rng.randf_range(-0.7, 0.7)) * rng.randf_range(52.0, 66.0)
			var length := rng.randf_range(8.0, 15.0)
			var yaw := atan2(WIND.x, WIND.y) + PI * 0.5 + rng.randf_range(-0.3, 0.3)
			var hh := rng.randf_range(1.0, 1.5)
			var b := Basis(Vector3.UP, yaw)
			MeshKit.add_ellipsoid(sand[which], Transform3D(b, _dat(p, -0.2)), Vector3(length * 0.5, hh, rng.randf_range(1.0, 1.5)), 4, 12, Color.WHITE)
			MeshKit.add_box(props, Transform3D(b, _dat(p, hh - 0.2)), Vector3(length * 0.55, 0.05, 0.15), Color("#E6CFA6"))
	var mats := [Color("#D9A35E"), Color("#C89848"), Color("#E6D0A0")]
	for k in 3:
		var m := MeshKit.finish(sand[k])
		if m.get_surface_count() > 0:
			t._add_visual(parent, "Drifts%d" % k, m, Materials.strata(mats[k]), false)
	# Gravel pans between neighbouring buttes, with stones from both.
	var pans: Array[Vector2] = []
	for q in 4:
		pans.append(c + _quarter_dir(q) * rng.randf_range(138.0, 150.0))
	for q in 4:
		var pan := pans[q]
		var tilt := pan.normalized().orthogonal()
		# Kidney-shaped: a wobbly blob with a second one overlapping its side.
		var in_pan := func(x: float, z: float) -> bool:
			var rel := Vector2(x, z) - pan
			return rel.length() < 11.0 + 3.0 * sin(rel.angle() * 2.0 + pan.x) or (rel + tilt * 8.0).length() < 8.0
		var lift := func(x: float, z: float) -> float: return MapTerrain.floor_at(cb, x, z) + 0.2
		t._add_visual(parent, "GravelPan%d" % q, GroundKit.patch(Rect2(pan - Vector2(22, 22), Vector2(44, 44)), 1.5, lift, in_pan), Materials.strata(Color("#C9A070")), false)
	for q in 4:
		var pal_a: Color = map.cliffs[q].rock
		var pal_b: Color = map.cliffs[(q + 1) % 4].rock
		for k in 50:
			var a := rng.randf() * TAU
			var r := pow(rng.randf(), 0.4) * 13.0 # thicker towards the edges
			var p := pans[q] + Vector2.from_angle(a) * r
			var s := rng.randf_range(0.3, 0.8)
			var col := (pal_a if rng.randf() < 0.5 else pal_b).darkened(rng.randf() * 0.2)
			MeshKit.add_box(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _dat(p, 0.25 + s * 0.15)), Vector3(s, s * 0.45, s * 0.8), col, s * 0.12, rng)
		for k in 7:
			var p := pans[q] + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 10.0)
			var s := rng.randf_range(0.8, 1.5)
			MeshKit.add_box(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _dat(p, 0.25 + s * 0.25)), Vector3(s, s * 0.6, s * 0.9), (pal_a if k % 2 == 0 else pal_b).darkened(0.1), s * 0.12, rng)
			GroundKit.disc(decals, func(x: float, z: float) -> float: return MapTerrain.floor_at(cb, x, z) + 0.2, p + WIND * s * 0.9, Vector2(s * 0.6, s * 0.35), WIND.angle(), 0.02, Color("#6A5A40"))


## The rock garden: clusters of hoodoos, lone standing stones, balanced rocks and
## dry gutters running out between them.
func _rock_garden(props: SurfaceTool, decals: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var c := Vector2(map.center.x, map.center.z)
	var clusters: Array[Vector2] = []
	var tries := 0
	while clusters.size() < 7 and tries < 300:
		tries += 1
		var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(220.0, 470.0)
		var ok := true
		for q in clusters:
			if q.distance_to(p) < 60.0:
				ok = false
		if ok:
			clusters.append(p)
	var hoodoos: Array[Vector2] = []
	for cl in clusters:
		var n := rng.randi_range(3, 5)
		for k in n:
			var p := cl + (Vector2.ZERO if k == 0 else Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(5.0, 12.0))
			var scale := 1.0 if k == 0 else rng.randf_range(0.5, 0.8)
			_hoodoo(props, rng, p, scale, k < 4)
			hoodoos.append(p)
		# A balanced rock at the cluster's edge.
		var pp := cl + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(14.0, 20.0)
		var ph := rng.randf_range(1.5, 3.0)
		var pr := rng.randf_range(0.6, 1.0)
		MeshKit.add_cylinder(props, Transform3D(Basis(), _dat(pp, ph * 0.5 - 0.3)), pr * 1.3, pr, ph, 8, Color("#A87848"))
		var cw := rng.randf_range(3.0, 5.0)
		MeshKit.add_ellipsoid(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _dat(pp, ph - 0.2 + 0.35)), Vector3(cw * 0.5, rng.randf_range(0.3, 0.5), cw * 0.4), 4, 10, Color("#C09060"), 0.1, rng)
	# Standing stones out between the clusters.
	var stones := 0
	tries = 0
	while stones < 10 and tries < 300:
		tries += 1
		var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(210.0, 490.0)
		var ok := true
		for q in clusters:
			if q.distance_to(p) < 30.0:
				ok = false
		if not ok:
			continue
		stones += 1
		var r := rng.randf_range(0.8, 1.5)
		var hh := rng.randf_range(8.0, 15.0)
		var b := Basis()
		if stones <= 4:
			b = Basis(Vector3(WIND.y, 0.0, -WIND.x), deg_to_rad(rng.randf_range(5.0, 10.0)))
		var at := _dat(p, -0.5)
		MeshKit.add_cylinder(props, Transform3D(b, at + b * Vector3(0, hh * 0.5, 0)), r * 1.1, r * 0.85, hh, 8, Color("#B87848"))
		MeshKit.add_cylinder(props, Transform3D(b, at + b * Vector3(0, hh * 0.6, 0)), r * 1.02, r * 1.0, 0.1, 8, Color("#4A3020"))
	# Dry gutters running out from the buttes through the garden.
	for k in 12:
		var a := rng.randf() * TAU
		var r0 := rng.randf_range(205.0, 420.0)
		var length := rng.randf_range(15.0, 40.0)
		var path: Array[Vector2] = []
		for j in 9:
			var f := float(j) / 8.0
			path.append(c + Vector2.from_angle(a + sin(f * 3.0 + k) * 0.01) * (r0 + f * length))
		GroundKit.strip(decals, func(x: float, z: float) -> float: return _desert_h(x, z), path, 0.06, 0.03, Color("#8A6E50"))


## A hoodoo: a tapering pedestal, a softer neck and a wider cap rock.
func _hoodoo(st: SurfaceTool, rng: RandomNumberGenerator, p: Vector2, scale: float, seam: bool) -> void:
	var at := _dat(p, -0.4)
	var bh := rng.randf_range(2.0, 5.0) * scale + 1.0
	var br := rng.randf_range(1.5, 3.0) * maxf(scale, 0.7)
	var tr := br * rng.randf_range(0.5, 0.6)
	var nh := rng.randf_range(1.0, 3.0) * scale + 0.5
	var nr := minf(rng.randf_range(0.5, 1.0), tr * 0.9)
	var ch := rng.randf_range(1.0, 2.0) * maxf(scale, 0.7)
	var cr := nr + rng.randf_range(0.7, 1.5)
	var segs := 9
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, bh * 0.5, 0)), br, tr, bh, segs, Color("#C8864A"))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, bh + nh * 0.5, 0)), tr * 0.8, nr, nh, segs, Color("#D0946A"))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, bh + nh + ch * 0.5 - 0.1, 0)), cr * 0.85, cr, ch, segs, Color("#B07040"))
	if seam:
		MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, bh, 0)), tr * 0.82, tr * 0.82, 0.08, segs, Color("#5A3A22"))


## The dune sea: rows of long asymmetric ridges across the wind (gentle on the
## windward north-west side, steep in the lee), cross dunes, stony flats, playa
## crusts, grass tufts, and rubble mounds as the dunes fade out past 1200 m.
func _dune_sea(parent: Node3D, props: SurfaceTool, decals: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var c := Vector2(map.center.x, map.center.z)
	var ridge := Vector2(WIND.y, -WIND.x) # crest line, north-east to south-west
	var bands := [MeshKit.begin(), MeshKit.begin(), MeshKit.begin()]
	var made := 0
	var row := -1450.0
	while row < 1450.0:
		var along := -1450.0 + rng.randf_range(0.0, 40.0)
		while along < 1450.0:
			var length := rng.randf_range(40.0, 80.0)
			var mid := c + WIND * row + ridge * (along + length * 0.5)
			var r := mid.distance_to(c)
			along += length + rng.randf_range(60.0, 200.0)
			if r < 500.0 or r > 1400.0 or rng.randf() < 0.35:
				continue
			# Fading out (lower and sparser) from 1200 m.
			var fade := 1.0 - smoothstep(1200.0, 1400.0, r)
			if r > 1200.0 and rng.randf() > fade:
				continue
			var hh := rng.randf_range(3.0, 5.0) * maxf(fade, 0.15)
			var band := 0 if r < 750.0 else (1 if r < 1000.0 else 2)
			if rng.randf() < 0.25:
				# A gap where the wind punches through.
				var l1 := length * rng.randf_range(0.35, 0.6)
				_dune(bands[band], rng, mid - ridge * (length - l1) * 0.5 - ridge * 6.0, ridge, l1, hh, rng.randf_range(4.0, 6.0), rng.randf_range(2.0, 4.0))
				var l2 := length - l1
				_dune(bands[band], rng, mid + ridge * (length - l2) * 0.5 + ridge * 6.0, ridge, l2, hh, rng.randf_range(4.0, 6.0), rng.randf_range(2.0, 4.0))
			else:
				_dune(bands[band], rng, mid, ridge, length, hh, rng.randf_range(4.0, 6.0), rng.randf_range(2.0, 4.0))
			made += 1
			# Grass tufts at the windward foot, in the inner, damper half.
			if r < 800.0 and rng.randf() < 0.3:
				for k in rng.randi_range(1, 3):
					var tp := mid - WIND * rng.randf_range(5.0, 7.0) + ridge * rng.randf_range(-length, length) * 0.4
					_tuft(props, rng, tp)
		row += rng.randf_range(40.0, 70.0)
	# Cross dunes across the main ridges.
	for k in 10:
		var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(520.0, 1150.0)
		var dir := ridge.rotated(deg_to_rad(rng.randf_range(60.0, 90.0)))
		_dune(bands[0 if p.distance_to(c) < 750.0 else (1 if p.distance_to(c) < 1000.0 else 2)], rng, p, dir, rng.randf_range(15.0, 30.0), rng.randf_range(1.0, 2.0), rng.randf_range(2.0, 3.0), rng.randf_range(1.0, 2.0))
	var cols := [Color("#D9A35E"), Color("#DFB880"), Color("#E6CFA6")]
	for k in 3:
		var m := MeshKit.finish(bands[k])
		if m.get_surface_count() > 0:
			t._add_visual(parent, "Dunes%d" % k, m, Materials.strata(cols[k]), false)
	# Sand-blasted stones on the flats, and a few white playa crusts.
	for k in 25:
		var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(520.0, 1150.0)
		var s := rng.randf_range(0.5, 1.5)
		MeshKit.add_box(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _dat(p, 0.03)), Vector3(s, rng.randf_range(0.05, 0.1), s * 0.7), Color("#B89060").darkened(rng.randf() * 0.15), s * 0.05, rng)
	for k in 4:
		var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(560.0, 1100.0)
		GroundKit.disc(decals, func(x: float, z: float) -> float: return _desert_h(x, z), p, Vector2(rng.randf_range(4.0, 6.0), rng.randf_range(3.0, 4.5)), rng.randf() * TAU, 0.04, Color("#E8E0D0"), 0.0, 16)
	# Rubble mounds where the dunes give out.
	for k in 18:
		var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1200.0, 1400.0)
		var w := rng.randf_range(3.0, 6.0)
		MeshKit.add_ellipsoid(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _dat(p, -0.2)), Vector3(w * 0.5, rng.randf_range(0.5, 1.0), w * 0.4), 3, 9, Color("#B89060"), 0.2, rng)


## One dune: a ridge `length` long along `dir`, `hh` tall, its gentle windward
## slope `ww` wide and its steep lee `lw` wide, the crest wandering a little.
func _dune(st: SurfaceTool, rng: RandomNumberGenerator, mid: Vector2, dir: Vector2, length: float, hh: float, ww: float, lw: float) -> void:
	var across := dir.orthogonal()
	if across.dot(WIND) < 0.0:
		across = -across # +across = downwind (the lee)
	var vs := [-1.0, -0.7, -0.4, -0.15, 0.0, 0.35, 0.7, 1.0]
	var n_u := 11
	var phase := rng.randf() * TAU
	var wander := rng.randf_range(2.0, 4.0)
	var grid: Array = []
	for i in n_u:
		var f := float(i) / float(n_u - 1)
		var crest := mid + dir * (f - 0.5) * length + across * sin(f * PI * 1.5 + phase) * wander
		var taper := sin(f * PI)
		var row: Array[Vector3] = []
		for v: float in vs:
			var off := v * (ww if v < 0.0 else lw)
			var p := crest + across * off
			var prof := (1.0 - pow(absf(v), 1.6)) if v < 0.0 else (1.0 - pow(v, 1.15))
			row.append(_dat(p, -0.3 + (hh + 0.3) * maxf(prof, 0.0) * pow(taper, 0.6)))
		grid.append(row)
	var col := MeshKit.vcol(Color.WHITE)
	for i in n_u - 1:
		for j in vs.size() - 1:
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i + 1][j]
			var cc: Vector3 = grid[i + 1][j + 1]
			var d: Vector3 = grid[i][j + 1]
			var nrm := (cc - a).cross(b - d).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			MeshKit.quad(st, a, b, cc, d, nrm, col)


func _tuft(st: SurfaceTool, rng: RandomNumberGenerator, p: Vector2) -> void:
	var at := _dat(p, 0.0)
	for k in rng.randi_range(3, 5):
		var hh := rng.randf_range(0.3, 0.6)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		MeshKit.add_box(st, Transform3D(b, at + Vector3(rng.randf_range(-0.15, 0.15), hh * 0.45, rng.randf_range(-0.15, 0.15))), Vector3(0.04, hh, 0.04), Color("#6A7A5A").darkened(rng.randf() * 0.15))


# ------------------------------------------------------------------ dust motes

## Fine dust stirred up round each butte's foot, drifting slowly upward.
func _dust_motes(parent: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.88, 0.82, 0.69, 0.4)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	quad.material = mat
	for cid in map.count():
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 10.0
		pm.direction = Vector3.UP
		pm.spread = 25.0
		pm.initial_velocity_min = 0.3
		pm.initial_velocity_max = 0.5
		pm.gravity = Vector3.ZERO
		var motes := GPUParticles3D.new()
		motes.name = "DustMotes%d" % cid
		motes.amount = 25
		motes.lifetime = 5.0
		motes.preprocess = 5.0
		motes.process_material = pm
		motes.draw_pass_1 = quad
		motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		motes.visibility_aabb = AABB(Vector3(-14, -2, -14), Vector3(28, 8, 28))
		var foot := map.to_world(cid, 6.0, 0.0)
		motes.position = Vector3(foot.x, _floor(foot.x, foot.z) + 1.0, foot.z)
		parent.add_child(motes)

class_name MesaDressing
extends RefCounted
## Three-Cliff Mesa dressing (all visual only, no colliders). The basin's three
## wedges each get their own ground: a dry wash in front of the Red Gate, an
## alkali flat before the Pale Ridge and a fossil bed before the Iron Wall, with
## a sinkhole where they meet. Each wall gets its wind-window arches, fallen
## boulders and a relic (a broken rope bridge, a survey tripod, a mine rail), and
## every tunnel a fan of crumbled rock. Behind the plateaus the high desert steps
## up in terraces cut by arroyos (stumps, slot canyons, old camps), rolls out
## past mesas and arches, and three signature mesas loom on the horizon.

var t: MapTerrain
var cb: CliffBuilder
var map: MapDef
## Each wall's direction from the middle, and each cliff's (unit, XZ).
var _wall_dir: Array[Vector2] = []
var _cliff_dir: Array[Vector2] = []
## The basin's outline (lips and wall feet) pulled in by a margin.
var _basin_poly := PackedVector2Array()
## The dry wash's path (from the Red Gate's foot towards the sinkhole).
var _wash: Array[Vector2] = []
var _hills := FastNoiseLite.new()
var _roll := FastNoiseLite.new()
var _ripple := FastNoiseLite.new()
## Arroyos: [bearing (rad), half width m, depth m].
var _arroyos: Array = []
var _centre_cache := {}

const SINK_R := 8.0
const TERRACE_W := 28.0
const TERRACE_H := 5.0
const RIM_R := 84.0


func _init(terrain: MapTerrain) -> void:
	t = terrain
	cb = terrain.cb
	map = terrain.map
	_hills.seed = 777
	_hills.frequency = 0.004
	_hills.fractal_octaves = 3
	_roll.seed = 778
	_roll.frequency = 1.0
	_roll.fractal_octaves = 1
	_ripple.seed = 779
	_ripple.frequency = 0.3
	_ripple.fractal_octaves = 1
	var c := Vector2(map.center.x, map.center.z)
	for i in map.count():
		var m := t.wall_at(i, -3.6, 0.5)
		_wall_dir.append((Vector2(m.x, m.z) - c).normalized())
		_cliff_dir.append((Vector2(map.cliffs[i].origin.x, map.cliffs[i].origin.z) - c).normalized())
	_basin_poly = _outline(1.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	# Two or three arroyos per wall's arc; the first in each is the big one (its slot canyon).
	for i in map.count():
		var base := _wall_dir[i].angle()
		for k in (3 if i != 1 else 2):
			var off := deg_to_rad(18.0) if k == 0 else deg_to_rad(rng.randf_range(-55.0, 55.0))
			_arroyos.append([base + off, 2.0 if k == 0 else rng.randf_range(1.0, 1.6), 2.0 if k == 0 else rng.randf_range(1.0, 1.6)])


func build(parent: Node3D) -> void:
	var decals := MeshKit.begin()  # flat ground marks, small stones (no outline)
	var props := MeshKit.begin()   # relics, fossils, boulders' marks (outlined)
	_dry_wash(parent, decals, props)
	LoadTimes.mark("  mesa: dry wash")
	_alkali_flat(parent, decals)
	_fossil_bed(parent, decals, props)
	_sinkhole(decals, props)
	LoadTimes.mark("  mesa: alkali, fossils, sinkhole")
	for i in map.count():
		_wall_dressing(parent, i, decals, props)
	LoadTimes.mark("  mesa: walls")
	_hinterland(parent, props)
	LoadTimes.mark("  mesa: hinterland")
	t._add_visual(parent, "BasinMarks", MeshKit.finish(decals), Materials.toon(0.0), false)
	t._add_visual(parent, "BasinRelics", MeshKit.finish(props), Materials.toon(0.02))


# ------------------------------------------------------------------ basin layout

## The basin's outline: each lip, then the foot of the wall to the next lip,
## pulled in by `margin` metres.
func _outline(margin: float) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in map.count():
		var prev := (i + map.count() - 1) % map.count()
		var next := (i + 1) % map.count()
		var v0 := t._wall_v(i, prev)
		var v1 := t._wall_v(i, next)
		for k in 9:
			var p := map.to_world(i, 0.0, lerpf(v0, v1, float(k) / 8.0))
			poly.append(Vector2(p.x, p.z))
		for k in 17:
			var p := t.wall_at(i, -3.6, float(k) / 16.0)
			poly.append(Vector2(p.x, p.z))
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
	var shrunk := Geometry2D.offset_polygon(poly, -margin)
	return shrunk[0] if not shrunk.is_empty() else poly


func _inside(x: float, z: float) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(x, z), _basin_poly)


## Which wall's wedge (x, z) lies in.
func _wedge(x: float, z: float) -> int:
	# The borders wander a little rather than running dead straight.
	var d := Vector2(x - map.center.x, z - map.center.z).normalized().rotated(_ripple.get_noise_2d(x * 0.5, z * 0.5) * 0.18)
	var best := 0
	for i in range(1, map.count()):
		if d.dot(_wall_dir[i]) > d.dot(_wall_dir[best]):
			best = i
	return best


## Metres from (x, z) to its wedge's edges (the rays out to the two cliffs
## either side) or the sinkhole's rim, whichever is nearest.
func _edge_dist(x: float, z: float) -> float:
	var p := Vector2(x - map.center.x, z - map.center.z)
	var w := _wedge(x, z)
	var a := _cliff_dir[w]
	var b := _cliff_dir[(w + 1) % map.count()]
	var da := absf(p.cross(a)) if p.dot(a) > 0.0 else p.length()
	var db := absf(p.cross(b)) if p.dot(b) > 0.0 else p.length()
	return minf(minf(da, db), p.length() - SINK_R - 1.0)


## The wash's half width at path index `at`.
func _wash_hw(at: float) -> float:
	return 2.0 + 0.5 * sin(at * 0.35)


## Height of the dressed basin ground (each wedge's overlay) at (x, z).
func top_at(x: float, z: float) -> float:
	var y := MapTerrain.floor_at(cb, x, z)
	var r := Vector2(x - map.center.x, z - map.center.z).length()
	if r < SINK_R + 1.0:
		return y + 0.04
	var fade := smoothstep(0.0, 3.5, _edge_dist(x, z))
	var w := _wedge(x, z)
	if w == 1:
		return y + 0.06
	if w == 2:
		return y + 0.04 + 0.11 * fade
	var pd := GroundKit.path_distance(_wash, Vector2(x, z))
	var hw := _wash_hw(pd.y)
	var bank := smoothstep(hw, hw + 1.5, pd.x) * 0.3
	var ripple := _ripple.get_noise_2d(x, z) * 0.04 * smoothstep(hw + 1.0, hw + 3.0, pd.x)
	return y + 0.04 + (bank + ripple) * fade


func _top() -> Callable:
	return func(x: float, z: float) -> float: return top_at(x, z)


## The bounds of wedge w (out to the walls).
func _rect(w: int) -> Rect2:
	var c := Vector2(map.center.x, map.center.z)
	var r := Rect2(c, Vector2.ZERO)
	for k in 9:
		r = r.expand(c + _wall_dir[w].rotated(lerpf(-PI / 3.0, PI / 3.0, float(k) / 8.0)) * 40.0)
	return r


## A random basin point in wedge `w`, at least `edge` m from its edges.
func _wedge_point(rng: RandomNumberGenerator, w: int, edge: float, r_min: float = SINK_R + 2.0) -> Vector2:
	for k in 200:
		var a := _wall_dir[w].angle() + rng.randf_range(-PI / 3.0, PI / 3.0)
		var r := rng.randf_range(r_min, 34.0)
		var p := Vector2(map.center.x, map.center.z) + Vector2.from_angle(a) * r
		if _inside(p.x, p.y) and _wedge(p.x, p.y) == w and _edge_dist(p.x, p.y) >= edge:
			return p
	return Vector2(map.center.x, map.center.z) + _wall_dir[w] * 18.0


func _at(p: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(p.x, top_at(p.x, p.y) + lift, p.y)


# ------------------------------------------------------------------ wedge A: dry wash

func _dry_wash(parent: Node3D, decals: SurfaceTool, props: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8101
	var c := Vector2(map.center.x, map.center.z)
	var foot := t.wall_at(0, -4.5, 0.5)
	var start := Vector2(foot.x, foot.z)
	var end := c + _wall_dir[0] * (SINK_R + 2.5)
	var side := (end - start).orthogonal().normalized()
	var ctrl: Array[Vector2] = []
	for k in 7:
		var f := float(k) / 6.0
		var jit := 0.0 if k == 0 or k == 6 else rng.randf_range(2.0, 3.0) * (1.0 if k % 2 == 0 else -1.0)
		ctrl.append(start.lerp(end, f) + side * jit)
	_wash = GroundKit.spline(ctrl, 6)
	var keep_sand := func(x: float, z: float) -> bool:
		if _wedge(x, z) != 0 or Vector2(x, z).distance_to(c) < SINK_R + 1.0 or not _inside(x, z):
			return false
		var pd := GroundKit.path_distance(_wash, Vector2(x, z))
		return pd.x > _wash_hw(pd.y)
	var keep_bed := func(x: float, z: float) -> bool:
		if _wedge(x, z) != 0 or Vector2(x, z).distance_to(c) < SINK_R + 1.0 or not _inside(x, z):
			return false
		var pd := GroundKit.path_distance(_wash, Vector2(x, z))
		return pd.x <= _wash_hw(pd.y)
	t._add_visual(parent, "WashSand", GroundKit.patch(_rect(0), 1.0, _top(), keep_sand), Materials.strata(Color("#E0D0B8")), false)
	t._add_visual(parent, "WashBed", GroundKit.patch(_rect(0), 1.0, _top(), keep_bed), Materials.strata(Color("#A88A64")), false)
	# Bleached river stones paving the bed, in clusters along the line.
	var n := _wash.size()
	var k := 1
	while k < n - 2:
		var p := _wash[k]
		var dir := (_wash[k + 1] - _wash[k - 1]).normalized()
		for j in rng.randi_range(5, 12):
			var q := p + dir * rng.randf_range(-0.9, 0.9) + dir.orthogonal() * rng.randf_range(-1.0, 1.0) * _wash_hw(k) * 0.65
			var rr := rng.randf_range(0.15, 0.5)
			var hh := rng.randf_range(0.08, 0.2)
			var col := Color("#E8DCC8") * rng.randf_range(0.9, 1.1)
			col.a = 1.0
			MeshKit.add_ellipsoid(decals, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _at(q, hh * 0.25)), Vector3(rr, hh * 0.5, rr * rng.randf_range(0.6, 0.9)), 3, 7, col)
		k += rng.randi_range(2, 3)
	# Flood-dropped boulders where the bed bends, on the outside of each bend.
	var placed := 0
	for i in range(2, n - 2):
		var turn := (_wash[i] - _wash[i - 2]).angle_to(_wash[i + 2] - _wash[i])
		if absf(turn) < 0.12 or placed >= 18 or rng.randf() < 0.3:
			continue
		var out := (_wash[i + 1] - _wash[i - 1]).normalized().orthogonal() * -signf(turn)
		var q := _wash[i] + out * _wash_hw(i) * rng.randf_range(0.3, 0.8)
		var rr := rng.randf_range(0.4, 1.2)
		MeshKit.add_ellipsoid(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _at(q, rr * 0.25)), Vector3(rr * 1.15, rr * 0.7, rr), 4, 8, Color("#E2D4BC").darkened(rng.randf() * 0.12), 0.15, rng)
		placed += 1
	# Big half-buried boulders at the wash's mouth, partly blocking the view up it.
	var mouth := _wash[0]
	var into := (_wash[3] - _wash[0]).normalized()
	for j in 4:
		var q := mouth + into * rng.randf_range(1.5, 4.0) + into.orthogonal() * (rng.randf_range(1.5, 3.0) * (1.0 if j % 2 == 0 else -1.0))
		var rr := rng.randf_range(1.5, 2.5)
		MeshKit.add_ellipsoid(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _at(q, -rr * 0.35)), Vector3(rr * 1.2, rr * 0.8, rr), 5, 10, Color("#DCCCB0").darkened(rng.randf() * 0.1), 0.15, rng)
	# Dead shrub stumps along the tops of the banks.
	for j in 34:
		var i := rng.randi_range(2, n - 3)
		var dir := (_wash[i + 1] - _wash[i - 1]).normalized()
		var q := _wash[i] + dir.orthogonal() * (_wash_hw(i) + rng.randf_range(1.6, 2.6)) * (1.0 if rng.randf() < 0.5 else -1.0)
		if not _inside(q.x, q.y) or _wedge(q.x, q.y) != 0:
			continue
		var hh := rng.randf_range(0.15, 0.3)
		var rr := rng.randf_range(0.1, 0.2)
		MeshKit.add_cylinder(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _at(q, hh * 0.5 - 0.03)), rr, rr * 0.6, hh, 6, Color("#5A4A3A"))
	# A fan of fine gravel where the wash spills out towards the middle.
	var tail := _wash[n - 1]
	var tail_dir := (_wash[n - 1] - _wash[n - 4]).normalized()
	GroundKit.disc(decals, _top(), tail + tail_dir * 1.0, Vector2(3.0, 2.0), tail_dir.angle(), 0.025, Color("#D0C0A0"))


# ------------------------------------------------------------------ wedge B: alkali flat

func _alkali_flat(parent: Node3D, decals: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8202
	var c := Vector2(map.center.x, map.center.z)
	var keep := func(x: float, z: float) -> bool:
		return _wedge(x, z) == 1 and Vector2(x, z).distance_to(c) >= SINK_R + 1.0 and _inside(x, z)
	t._add_visual(parent, "AlkaliFlat", GroundKit.patch(_rect(1), 1.0, _top(), keep), Materials.strata(Color("#E8E0D0")), false)
	# Cracked mud: seams along the edges of a Voronoi net.
	var pts := PackedVector2Array()
	for k in 52:
		pts.append(_wedge_point(rng, 1, 0.0, SINK_R + 1.0))
	var edges := GroundKit.voronoi_edges(pts, 9.0)
	for e in edges.size() / 2:
		var a := edges[e * 2]
		var b := edges[e * 2 + 1]
		var m := (a + b) * 0.5
		if not keep.call(m.x, m.y) or not keep.call(a.x, a.y) or not keep.call(b.x, b.y):
			continue
		GroundKit.seam(decals, _top(), a, b, rng.randf_range(0.05, 0.12), 0.015, Color("#B8A880"))
	# Salt crystals on brine stains, in the lowest hollows.
	var spots: Array[Vector2] = []
	for k in 60:
		spots.append(_wedge_point(rng, 1, 1.0))
	spots.sort_custom(func(p: Vector2, q: Vector2) -> bool: return MapTerrain.floor_at(cb, p.x, p.y) < MapTerrain.floor_at(cb, q.x, q.y))
	for k in 18:
		var p := spots[k]
		GroundKit.disc(decals, _top(), p, Vector2.ONE * rng.randf_range(0.4, 0.8), 0.0, 0.012, Color("#C0A880"))
		for j in rng.randi_range(3, 7):
			var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.35)
			var hh := rng.randf_range(0.1, 0.3)
			var rr := rng.randf_range(0.05, 0.15)
			MeshKit.add_ellipsoid(decals, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _at(q, hh * 0.4)), Vector3(rr, hh * 0.5, rr), 3, 6, Color("#F0ECE0"))
	# Where the water last pooled: a dark ring of once-wet ground across the wedge.
	var arc: Array[Vector2] = []
	var base := _wall_dir[1].angle()
	for k in 41:
		var a := base + lerpf(-PI / 3.0, PI / 3.0, float(k) / 40.0)
		var p := c + Vector2.from_angle(a) * (17.0 + 1.2 * sin(a * 5.0))
		if keep.call(p.x, p.y) and _edge_dist(p.x, p.y) > 1.5:
			arc.append(p)
		elif arc.size() > 1:
			GroundKit.strip(decals, _top(), arc, 2.0, 0.01, Color("#B8A080"))
			arc = []
		else:
			arc = []
	if arc.size() > 1:
		GroundKit.strip(decals, _top(), arc, 2.0, 0.01, Color("#B8A080"))
	# Pressure ridges where the drying mud buckled up.
	for k in 3:
		var p := _wedge_point(rng, 1, 3.0, 12.0)
		var along := (p - c).normalized().rotated(rng.randf_range(-0.3, 0.3))
		var length := rng.randf_range(4.0, 8.0)
		MeshKit.add_ellipsoid(decals, Transform3D(Basis(Vector3.UP, atan2(along.x, along.y)), _at(p, -0.02)), Vector3(0.25, 0.1, length * 0.5), 3, 8, Color("#E8E0D0"))


# ------------------------------------------------------------------ wedge C: fossil bed

func _fossil_bed(parent: Node3D, decals: SurfaceTool, props: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8303
	var c := Vector2(map.center.x, map.center.z)
	var keep := func(x: float, z: float) -> bool:
		return _wedge(x, z) == 2 and Vector2(x, z).distance_to(c) >= SINK_R + 1.0 and _inside(x, z)
	t._add_visual(parent, "FossilBed", GroundKit.patch(_rect(2), 1.0, _top(), keep), Materials.strata(Color("#D2A874")), false)
	var taken: Array[Vector2] = []
	# The three display fossils first, well apart (mini landmarks).
	for k in 3:
		var p := _free_point(rng, 2, 5.0, taken, 7.0, 13.0)
		taken.append(p)
		var yaw := rng.randf() * TAU
		match k:
			0:
				_ribcage(props, p, yaw)
			1:
				GroundKit.spiral(props, Transform3D(Basis(Vector3.UP, yaw), _at(p, 0.05)), 1.0, 2.6, 26, 0.16, Color("#C0A070"))
				MeshKit.add_cylinder(props, Transform3D(Basis(), _at(p, 0.06)), 0.12, 0.1, 0.08, 8, Color("#A88858"))
			2:
				_trilobite(props, p, yaw)
	# Ammonites, the three largest with a centre boss.
	for k in 10:
		var p := _free_point(rng, 2, 3.0, taken, 2.0)
		taken.append(p)
		var big := k < 3
		var rr := rng.randf_range(0.6, 0.75) if big else rng.randf_range(0.25, 0.5)
		GroundKit.spiral(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _at(p, 0.03)), rr, rng.randf_range(2.0, 3.0), rng.randi_range(15, 20), 0.08 * (1.0 if big else 0.7), Color("#C0A070"))
		if big:
			MeshKit.add_cylinder(props, Transform3D(Basis(), _at(p, 0.04)), 0.08, 0.07, 0.04, 8, Color("#A88858"))
	# Bone fragments: some broken in two, some with a slight bend.
	for k in 18:
		var p := _free_point(rng, 2, 3.0, taken, 1.2)
		var yaw := rng.randf() * TAU
		var length := rng.randf_range(0.6, 2.0)
		var w := rng.randf_range(0.08, 0.15)
		var b := Basis(Vector3.UP, yaw)
		var col := Color("#E0D0B0").darkened(rng.randf() * 0.08)
		match k % 4:
			0:
				for sgn: float in [-1.0, 1.0]:
					MeshKit.add_box(props, Transform3D(b, _at(p, 0.02) + b * Vector3(0, 0, sgn * (length * 0.25 + 0.05))), Vector3(w, 0.04, length * 0.5), col)
			1:
				MeshKit.add_box(props, Transform3D(b, _at(p, 0.02) + b * Vector3(0, 0, -length * 0.25)), Vector3(w, 0.04, length * 0.5), col)
				var b2 := b * Basis(Vector3.UP, deg_to_rad(10.0))
				MeshKit.add_box(props, Transform3D(b2, _at(p, 0.02) + b * Vector3(0, 0, 0.0) + b2 * Vector3(0, 0, length * 0.25)), Vector3(w, 0.04, length * 0.5), col)
			_:
				MeshKit.add_box(props, Transform3D(b, _at(p, 0.02)), Vector3(w, 0.04, length), col)
	# Shell imprints pressed into the hardpan, a little denser near the middle.
	for k in 26:
		var p := _free_point(rng, 2, 3.0, taken, 0.8)
		if k % 2 == 0:
			p = p.lerp(c + _wall_dir[2] * 21.0, 0.35)
		var rr := rng.randf_range(0.15, 0.4)
		var hh := rng.randf_range(0.03, 0.08)
		MeshKit.add_ellipsoid(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _at(p, 0.0)), Vector3(rr, hh, rr * 0.85), 3, 9, Color("#C8A878"))
		GroundKit.disc(decals, _top(), p, Vector2(rr * 0.65, rr * 0.55), rng.randf() * TAU, hh + 0.008, Color("#A08060"))


## A random point in wedge w at least `edge` m from its edges and `gap` m from
## every point in `taken` (fossils thin out to nothing at the bed's edges).
func _free_point(rng: RandomNumberGenerator, w: int, edge: float, taken: Array[Vector2], gap: float, r_min: float = SINK_R + 2.0) -> Vector2:
	var p := Vector2.ZERO
	for k in 60:
		p = _wedge_point(rng, w, edge, maxf(r_min, SINK_R + 2.0))
		var ok := true
		for q in taken:
			if q.distance_to(p) < gap:
				ok = false
				break
		if ok:
			return p
	return p


## A complete ribcage: a spine and eight pairs of curved ribs arching from it.
func _ribcage(st: SurfaceTool, p: Vector2, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var at := _at(p, 0.06)
	var bone := Color("#E0D0B0")
	MeshKit.add_box(st, Transform3D(b, at), Vector3(0.14, 0.12, 1.6), bone)
	for k in 8:
		var z := lerpf(-0.65, 0.65, float(k) / 7.0)
		var span := 0.42 * (1.0 - absf(z) * 0.4)
		for sgn: float in [-1.0, 1.0]:
			var up := b * Basis(Vector3.BACK, sgn * 0.5)
			MeshKit.add_box(st, Transform3D(up, at + b * Vector3(sgn * span * 0.5, 0.1, z)), Vector3(span, 0.06, 0.07), bone)
			var down := b * Basis(Vector3.BACK, -sgn * 0.7)
			MeshKit.add_box(st, Transform3D(down, at + b * Vector3(sgn * span * 1.15, 0.08, z)), Vector3(span * 0.6, 0.06, 0.07), bone)


## A trilobite impression: an oval of overlapping lobes, a head shield and a tail.
func _trilobite(st: SurfaceTool, p: Vector2, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var at := _at(p, 0.0)
	var col := Color("#B89466")
	MeshKit.add_ellipsoid(st, Transform3D(b, at + b * Vector3(0, 0, -0.45)), Vector3(0.36, 0.06, 0.2), 3, 10, col.darkened(0.08))
	for k in 7:
		var z := lerpf(-0.25, 0.4, float(k) / 6.0)
		var w := 0.34 * (1.0 - float(k) / 9.0)
		MeshKit.add_ellipsoid(st, Transform3D(b, at + b * Vector3(0, 0, z)), Vector3(w, 0.05, 0.08), 3, 8, col)
	MeshKit.add_ellipsoid(st, Transform3D(b, at + b * Vector3(0, 0.02, 0.0)), Vector3(0.09, 0.06, 0.55), 3, 8, col.darkened(0.12))
	MeshKit.add_ellipsoid(st, Transform3D(b, at + b * Vector3(0, 0, 0.52)), Vector3(0.12, 0.04, 0.1), 3, 8, col)


# ------------------------------------------------------------------ the sinkhole

func _sinkhole(decals: SurfaceTool, props: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8404
	var c := Vector2(map.center.x, map.center.z)
	var h := _top()
	# Darkening rings, deepest-looking at the middle (the collider stays level).
	GroundKit.disc(decals, h, c, Vector2.ONE * (SINK_R + 1.3), 0.0, 0.01, Color("#9A7850"), (SINK_R - 0.2) / (SINK_R + 1.3), 24)
	GroundKit.disc(decals, h, c, Vector2.ONE * SINK_R, 0.0, 0.012, Color("#8A6840"), 0.6, 24)
	GroundKit.disc(decals, h, c, Vector2.ONE * SINK_R * 0.62, 0.0, 0.014, Color("#6E5032"), 0.45, 20)
	GroundKit.disc(decals, h, c, Vector2.ONE * SINK_R * 0.3, 0.0, 0.016, Color("#4E3622"), 0.0, 16)
	# Cracks radiating out from the middle into the wedges.
	for k in 6:
		var a := TAU * float(k) / 6.0 + rng.randf_range(-0.3, 0.3)
		var p := c + Vector2.from_angle(a) * 2.0
		var length := SINK_R + rng.randf_range(4.0, 6.0)
		var dir := Vector2.from_angle(a)
		while p.distance_to(c) < length:
			dir = dir.rotated(rng.randf_range(-0.35, 0.35))
			var q := p + dir * rng.randf_range(1.2, 2.2)
			GroundKit.seam(decals, h, p, q, rng.randf_range(0.06, 0.11), 0.03, Color("#3E2A1A"))
			p = q
	# Crumbled rock round the rim, tilted in as if the ground gave way.
	for k in 26:
		var a := TAU * float(k) / 26.0 + rng.randf_range(-0.08, 0.08)
		var dir := Vector2.from_angle(a)
		var p := c + dir * (SINK_R + rng.randf_range(-0.6, 0.9))
		var s := rng.randf_range(0.3, 1.0)
		var tilt := deg_to_rad(rng.randf_range(15.0, 30.0))
		var b := Basis(Vector3.UP, atan2(dir.x, dir.y)) * Basis(Vector3.RIGHT, tilt)
		var col: Color = [Color("#8A6A48"), Color("#7A5A3A"), Color("#9A7A55"), Color("#6E5034")][k % 4]
		MeshKit.add_box(props, Transform3D(b, _at(p, s * 0.2)), Vector3(s * rng.randf_range(0.8, 1.4), s * 0.6, s), col.darkened(rng.randf() * 0.1), s * 0.15, rng)


# ------------------------------------------------------------------ the walls

## Where wall i's face (out on the basin side) stands at height y, at s along it,
## and the way out from it.
func face_point(i: int, s: float, y: float) -> Array:
	var lo := -3.6
	var hi := -0.3
	for k in 10:
		var mid := (lo + hi) * 0.5
		if t.wall_at(i, mid, s, true).y < y:
			lo = mid
		else:
			hi = mid
	var p := t.wall_at(i, (lo + hi) * 0.5, s, true)
	var out := Vector3(map.center.x - p.x, 0.0, map.center.z - p.z).normalized()
	return [Vector3(p.x, y, p.z), out]


func _near_tunnel(i: int, p: Vector2, gap: float) -> bool:
	for k: int in [i * 2, i * 2 + 1]:
		if k >= map.tunnels.size():
			continue
		var m: Vector3 = map.tunnels[k][0]
		var o: Vector3 = map.tunnels[k][1]
		var rel := p - Vector2(m.x, m.z)
		# The mouth itself and the lane the bugs take out of it.
		if rel.length() < gap or (rel.dot(Vector2(o.x, o.z)) > 0.0 and absf(rel.cross(Vector2(o.x, o.z))) < gap * 0.6 and rel.length() < 12.0):
			return true
	return false


func _wall_dressing(parent: Node3D, i: int, decals: SurfaceTool, props: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7300 + i * 31
	var rock := MeshKit.begin()
	var length := t.wall_length(i)
	var top := WorldLayout.CLIFF_HEIGHT
	# Wind windows: an arch of rock spans the top of each notch cut through the ridge.
	var widest := 0
	for w in MapTerrain.WALL_WINDOWS[i].size():
		if float(MapTerrain.WALL_WINDOWS[i][w][1]) > float(MapTerrain.WALL_WINDOWS[i][widest][1]):
			widest = w
	for w in MapTerrain.WALL_WINDOWS[i].size():
		var win: Array = MapTerrain.WALL_WINDOWS[i][w]
		var sc := float(win[0])
		var hw := float(win[1])
		var depth := float(win[2])
		var crest := t._plain_crest(i, sc)
		var ds := hw / length * 1.05
		var fa := t.wall_at(i, 0.6, sc - ds)
		var fb := t.wall_at(i, 0.6, sc + ds)
		fa.y = crest - depth * 0.7
		fb.y = crest - depth * 0.7
		var rise := depth * 0.7 - 0.6
		var crown := clampf(hw * 0.32, 0.6, 1.1)
		ArchBuilder.arch(rock, rng, fa, fb, rise, crown * 1.5, crown)
		# Prongs of rock hanging from the arch's underside.
		var apex_y := maxf(fa.y, fb.y) + rise
		for k in rng.randi_range(6, 8):
			var f := rng.randf_range(0.25, 0.75)
			var pt := ArchBuilder._point(fa, fb, apex_y, f)
			var ph := rng.randf_range(0.3, 0.8)
			MeshKit.add_cylinder(rock, Transform3D(Basis(Vector3.RIGHT, PI), pt - Vector3(0, crown * 0.6 + ph * 0.5, 0)), rng.randf_range(0.12, 0.22), 0.0, ph, 5, Color.WHITE)
		# The Red Gate's keystone: a dark capstone over its widest window.
		if i == 0 and w == widest:
			var x := (fb - fa).normalized()
			var kb := Basis(x, Vector3.UP, x.cross(Vector3.UP).normalized())
			MeshKit.add_box(props, Transform3D(kb, ArchBuilder._point(fa, fb, apex_y, 0.5) + Vector3(0, crown * 0.75 + 0.15, 0)), Vector3(2.0, 0.4, 0.6) * 1.6, Color("#5A2018"), 0.05, rng)
	# Fallen boulders along the foot, clear of the tunnel lanes.
	var counts := [12, 9, 13]
	var made := 0
	var tries := 0
	while made < int(counts[i]) and tries < 200:
		tries += 1
		var s := rng.randf_range(0.04, 0.96)
		var r := rng.randf_range(-9.0, -5.0)
		var base := t.wall_at(i, r, s)
		var p := Vector2(base.x, base.z)
		if _near_tunnel(i, p, 4.5) or not _inside(p.x, p.y):
			continue
		if i == 0 and GroundKit.path_distance(_wash, p).x < 3.0:
			continue
		made += 1
		var y := top_at(p.x, p.y)
		match i:
			0:
				var rr := rng.randf_range(1.5, 4.0)
				var sink := rng.randf_range(0.3, 0.8) if made % 2 == 0 else 0.0
				if made <= 4:
					# Cracked through: two halves apart with a dark seam between.
					var yaw := rng.randf() * TAU
					var b := Basis(Vector3.UP, yaw)
					var gap := rng.randf_range(0.1, 0.3)
					for sgn: float in [-1.0, 1.0]:
						MeshKit.add_ellipsoid(rock, Transform3D(b, Vector3(p.x, y + rr * 0.45 - sink, p.y) + b * Vector3(sgn * (rr * 0.32 + gap * 0.5), 0, 0)), Vector3(rr * 0.5, rr * 0.75, rr), 4, 8, Color.WHITE, 0.15, rng)
					MeshKit.add_box(props, Transform3D(b, Vector3(p.x, y + rr * 0.35 - sink, p.y)), Vector3(gap + 0.05, rr * 1.0, rr * 1.4), Color("#2A1410"))
				else:
					MeshKit.add_ellipsoid(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y + rr * 0.45 - sink, p.y)), Vector3(rr * 1.2, rr * 0.75, rr), 4, 9, Color.WHITE, 0.25, rng)
			1:
				var rr := rng.randf_range(1.4, 3.2)
				var c3 := Vector3(p.x, y + rr * 0.6, p.y)
				MeshKit.add_ellipsoid(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c3), Vector3(rr, rr * 0.88, rr * 0.95), 5, 10, Color.WHITE, 0.08, rng)
				for k in rng.randi_range(3, 5):
					var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.1, 0.9), rng.randf_range(-1.0, 1.0)).normalized()
					var pr := rng.randf_range(0.15, 0.3)
					MeshKit.add_ellipsoid(props, Transform3D(MeshKit.basis_from_y(d), c3 + d * Vector3(rr, rr * 0.88, rr * 0.95) * 0.97), Vector3(pr, pr * 0.3, pr), 3, 7, Color("#7A6850"))
			_:
				var sz := Vector3(rng.randf_range(2.0, 4.5), rng.randf_range(1.5, 3.5), rng.randf_range(2.0, 4.0))
				var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
				var c3 := Vector3(p.x, y + sz.y * 0.4, p.y)
				MeshKit.add_box(rock, Transform3D(b, c3), sz, Color.WHITE, 0.45, rng)
				if made % 4 == 0:
					# Another fallen on top of it.
					var s2 := sz * rng.randf_range(0.45, 0.65)
					MeshKit.add_box(rock, Transform3D(b * Basis(Vector3.UP, 0.7), c3 + Vector3(0, sz.y * 0.5 + s2.y * 0.45, 0)), s2, Color.WHITE, 0.3, rng)
				if made % 2 == 1:
					# Iron stain run down its top.
					MeshKit.add_box(props, Transform3D(b, c3 + b * Vector3(rng.randf_range(-0.3, 0.3) * sz.x, sz.y * 0.5 + 0.03, 0)), Vector3(0.25, 0.05, sz.z * 0.85), Color("#C06830"))
	match i:
		0:
			_rope_bridge(props, rng)
		1:
			_honeycomb(props, rng, top)
			_survey_tripod(props, rng)
		2:
			_iron_seeps(decals, props, rng, top)
			_mine_rail(props, rng)
	_tunnel_aprons(i, rock, rng)
	t._add_visual(parent, "WallRock%d" % i, MeshKit.finish(rock), t.wall_material(i))


## Red Gate: a rope bridge hanging broken against the wall, its far end severed and drooping.
func _rope_bridge(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var start: Array = face_point(0, 0.1, 40.0)
	var end: Array = face_point(0, 0.36, 33.0)
	var a: Vector3 = start[0] + (start[1] as Vector3) * 1.0
	var b: Vector3 = end[0] + (end[1] as Vector3) * 1.0
	var out := ((start[1] as Vector3) + (end[1] as Vector3)).normalized()
	var pts: Array[Vector3] = []
	for k in 13:
		var f := float(k) / 12.0
		var p := a.lerp(b, f)
		p.y -= sin(f * PI * 0.8) * 2.0 + f * f * 3.0
		pts.append(p)
	for sgn: float in [-1.0, 1.0]:
		for k in 12:
			var p0 := pts[k] + out * sgn * 0.45
			var p1 := pts[k + 1] + out * sgn * 0.45
			var dir := p1 - p0
			MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y(dir.normalized()), (p0 + p1) * 0.5), Vector3(0.15, dir.length() * 1.05, 0.15), Palette.WOOD_DARK)
	for k in 13:
		if k == 9:
			continue # a missing plank
		var p := pts[k]
		var along := (pts[mini(k + 1, 12)] - pts[maxi(k - 1, 0)]).normalized()
		MeshKit.add_box(st, Transform3D(Basis(out, along.cross(out).normalized(), along).orthonormalized() * Basis(Vector3.FORWARD, rng.randf_range(-0.15, 0.15)), p), Vector3(1.05, 0.05, 0.28), Palette.WOOD, 0.02, rng)
	# Anchor posts driven into the rock at the near end.
	for sgn: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), a + out * sgn * 0.45 + Vector3(0, 0.5, 0)), Vector3(0.22, 1.4, 0.22), Palette.WOOD_DARK)


## Pale Ridge: tafoni, clusters of shallow dark pits in two bands up the face.
func _honeycomb(st: SurfaceTool, rng: RandomNumberGenerator, top: float) -> void:
	var made := 0
	while made < 52:
		var band := top + (8.0 if rng.randf() < 0.5 else 18.0)
		var s := rng.randf_range(0.12, 0.88)
		var y0 := band + rng.randf_range(-1.5, 1.5)
		for k in rng.randi_range(5, 12):
			var fp: Array = face_point(1, clampf(s + rng.randf_range(-0.03, 0.03), 0.05, 0.95), y0 + rng.randf_range(-1.6, 1.6))
			var out: Vector3 = fp[1]
			var rr := rng.randf_range(0.15, 0.4)
			MeshKit.add_ellipsoid(st, Transform3D(MeshKit.basis_from_y(out), (fp[0] as Vector3) + out * 0.05), Vector3(rr, rng.randf_range(0.1, 0.2) * 0.5, rr * rng.randf_range(0.7, 1.0)), 3, 8, Color("#7A6850"))
			made += 1


## Pale Ridge: a collapsed survey tripod with a faded brass cap, a leg snapped off.
func _survey_tripod(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var base := t.wall_at(1, -8.0, 0.16)
	var p := Vector2(base.x, base.z)
	var at := _at(p, 0.0)
	var apex := at + Vector3(0.3, 1.35, 0.1)
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.4
		var foot := at + Vector3(cos(a), 0.0, sin(a)) * 0.75
		if k == 2:
			# The snapped leg: a stub hangs from the head, the rest lies beside it.
			var stub := apex.lerp(foot, 0.35)
			MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y((stub - apex).normalized()), (apex + stub) * 0.5), Vector3(0.06, apex.distance_to(stub), 0.05), Palette.WOOD)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, a + 0.4), foot + Vector3(0.4, 0.03, 0.2)), Vector3(0.06, 0.05, 1.0), Palette.WOOD)
			continue
		MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y((apex - foot).normalized()), (apex + foot) * 0.5), Vector3(0.06, apex.distance_to(foot), 0.05), Palette.WOOD)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, 0.3), apex + Vector3(0, 0.03, 0)), 0.075, 0.075, 0.04, 10, Color("#B8A040"))


## Iron Wall: rust-orange seep streaks down the face, a dark pool at a few of their feet.
func _iron_seeps(decals: SurfaceTool, st: SurfaceTool, rng: RandomNumberGenerator, top: float) -> void:
	for k in 10:
		var s := rng.randf_range(0.08, 0.92)
		if absf(s - float(MapTerrain.WALL_WINDOWS[2][0][0])) < 0.06:
			s += 0.12
		var y_top := top + rng.randf_range(4.0, 20.0)
		var length := rng.randf_range(8.0, 20.0)
		var w := rng.randf_range(0.2, 0.4)
		var pieces := 4
		for j in pieces:
			var f := (float(j) + 0.5) / float(pieces)
			var y := y_top - length * f
			var fp: Array = face_point(2, s, y)
			var out: Vector3 = fp[1]
			var wide := w * (1.3 if f > 0.5 else 1.0)
			var b := Basis(out.cross(Vector3.UP).normalized(), Vector3.UP, out)
			MeshKit.add_box(st, Transform3D(b, (fp[0] as Vector3) + out * 0.15), Vector3(wide, length / pieces * 1.08, 0.06), Color("#C06830").darkened(rng.randf() * 0.12))
		if k % 3 == 0:
			var foot := t.wall_at(2, -5.0, s)
			GroundKit.disc(decals, _top(), Vector2(foot.x, foot.z), Vector2(rng.randf_range(0.5, 1.0), rng.randf_range(0.4, 0.8)), rng.randf() * TAU, 0.012, Color("#6A4030"))


## Iron Wall: a rusted rail and rotten ties half buried, and an old cart wheel.
func _mine_rail(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var base := t.wall_at(2, -9.0, 0.86)
	var p := Vector2(base.x, base.z)
	var out := (Vector2(map.center.x, map.center.z) - p).normalized()
	var b := Basis(Vector3.UP, atan2(out.x, out.y))
	var rust := Color("#8A4020")
	MeshKit.add_box(st, Transform3D(b * Basis(Vector3.RIGHT, 0.02), _at(p, 0.03)), Vector3(0.1, 0.15, 6.0), rust)
	for k in 3:
		var q := p + out * lerpf(-2.2, 2.2, float(k) / 2.0)
		MeshKit.add_box(st, Transform3D(b * Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)), _at(q, 0.0)), Vector3(1.3, 0.1, 0.22), Palette.WOOD_DARK.darkened(0.25))
	var wq := p + out.orthogonal() * 1.8 + out * 1.0
	var wxf := Transform3D(Basis(Vector3.RIGHT, 0.05), _at(wq, 0.06))
	MeshKit.add_rim(st, wxf, 0.3, 0.25, 0.1, 14, rust)
	for k in 4:
		MeshKit.add_box(st, wxf * Transform3D(Basis(Vector3.UP, PI * float(k) / 4.0), Vector3.ZERO), Vector3(0.04, 0.04, 0.52), rust)


## A fan of crumbled rock spilling 4-6 m out of each of wall i's tunnels.
func _tunnel_aprons(i: int, st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for k: int in [i * 2, i * 2 + 1]:
		if k >= map.tunnels.size():
			continue
		var m: Vector3 = map.tunnels[k][0]
		var o: Vector3 = map.tunnels[k][1]
		var out := Vector2(o.x, o.z).normalized()
		var mouth := Vector2(m.x, m.z)
		var count := rng.randi_range(15, 25)
		for j in count:
			var dist := rng.randf_range(0.8, 5.5)
			var dir := out.rotated(rng.randf_range(-PI / 4.0, PI / 4.0))
			var p := mouth + dir * dist
			var s := lerpf(1.0, 0.25, dist / 5.5) * rng.randf_range(0.7, 1.0)
			var b := Basis(Vector3.UP, rng.randf() * TAU)
			if j < 3:
				b = b * Basis(Vector3.RIGHT, rng.randf_range(0.7, 1.1)) # freshly fallen, on edge
			var y := MapTerrain.floor_at(cb, p.x, p.y)
			if j % 2 == 0:
				MeshKit.add_box(st, Transform3D(b, Vector3(p.x, y + s * 0.2, p.y)), Vector3(s, s * 0.55, s * 0.8), Color.WHITE, s * 0.12, rng)
			else:
				MeshKit.add_ellipsoid(st, Transform3D(b, Vector3(p.x, y + s * 0.15, p.y)), Vector3(s * 0.6, s * 0.35, s * 0.5), 3, 7, Color.WHITE, 0.2, rng)


# ------------------------------------------------------------------ hinterland

## The high desert's height at (x, z) (r from the middle): terraces stepping up
## from the plateaus' backs, cut by arroyos, then rolling desert out to the horizon.
func land(x: float, z: float, r: float) -> float:
	var top := WorldLayout.CLIFF_HEIGHT
	var ang := atan2(z - map.center.z, x - map.center.x)
	var cut := 0.0
	var pour := 0.0
	if r < 200.0:
		var centres := _arroyo_centres(r)
		for k in _arroyos.size():
			var a: Array = _arroyos[k]
			var d := absf(wrapf(ang - centres[k], -PI, PI)) * r
			# Wider where it pours over a terrace's riser.
			var near_riser := 1.0 - smoothstep(0.0, 4.0, absf(fposmod(r - RIM_R, TERRACE_W) - 1.0))
			var hw := float(a[1]) * (1.0 + 0.6 * near_riser)
			if d > hw * 3.0:
				continue
			var kk := exp(-(d / hw) * (d / hw))
			cut = maxf(cut, float(a[2]) * kk)
			pour = maxf(pour, kk)
		cut *= smoothstep(RIM_R + 2.0, RIM_R + 12.0, r) * (1.0 - smoothstep(170.0, 196.0, r))
	var terr := _terrace(r, pour) + _hills.get_noise_2d(x * 4.0, z * 4.0) * 0.3 - cut
	if r <= 200.0:
		return terr
	var roll := top + 38.0 + _roll.get_noise_2d(x * 0.008, z * 0.008) * 12.0 + _roll.get_noise_2d(x * 0.025 + 50.0, z * 0.025) * 3.0
	return lerpf(terr, roll, smoothstep(200.0, 300.0, r))


## Each arroyo's bearing at radius r (wandering a few degrees every 20 m or so).
func _arroyo_centres(r: float) -> PackedFloat32Array:
	if _centre_cache.has(r):
		return _centre_cache[r]
	var out := PackedFloat32Array()
	for a: Array in _arroyos:
		out.append(float(a[0]) + deg_to_rad(5.0) * _hills.get_noise_2d(float(a[0]) * 300.0, r * 2.5))
	_centre_cache[r] = out
	return out


## The terraces: four 5 m steps 28 m deep from the rim; `pour` (0..1, in an
## arroyo) softens the riser into a smooth pour-over.
func _terrace(r: float, pour: float = 0.0) -> float:
	var top := WorldLayout.CLIFF_HEIGHT
	var tier := clampi(floori((r - RIM_R) / TERRACE_W), 0, 3)
	var base := top + 30.0 + tier * TERRACE_H
	var start := RIM_R + tier * TERRACE_W
	var w := lerpf(1.5, 5.0, pour)
	return lerpf(base, base + TERRACE_H, smoothstep(start, start + w, r))


func _hinterland(parent: Node3D, props: SurfaceTool) -> void:
	var h := func(x: float, z: float, r: float) -> float: return land(x, z, r)
	# The terraces, each its own ring (warmer higher up).
	var tints := [Color("#D9A35E"), Color("#D3974F"), Color("#CE8C48"), Color("#C88040")]
	for tier in 4:
		var r0 := RIM_R + tier * TERRACE_W
		var r1 := r0 + TERRACE_W if tier < 3 else 200.0
		var rs: Array[float] = []
		for f: float in [0.0, 0.5, 1.0, 1.5, 2.2, 3.0, 4.0, 5.0]:
			rs.append(r0 + f)
		var r := r0 + 7.0
		while r < r1 - 0.5:
			rs.append(r)
			r += 2.5
		rs.append(r1)
		t._add_visual(parent, "Terrace%d" % tier, t.ring_rows(rs, 360, h), Materials.strata(tints[tier]), false)
	# Rolling desert, cooler and bluer with distance so it recedes.
	t._add_visual(parent, "RollingDesert", t.ring_rows(_radii(200.0, 400.0, 5.0), 240, h), Materials.strata(Color("#CFA062")), false)
	t._add_visual(parent, "FarDesert", t.ring_rows(_radii(400.0, 600.0, 12.0), 120, h), Materials.strata(Color("#C4A27A")), false)
	t._add_visual(parent, "Horizon", t.ring_rows(_radii(600.0, CliffBuilder.HINTER, 30.0), 120, h), Materials.strata(Color("#B9A48A")), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9191
	_rim_dressing(parent, props, rng)
	_desert_dressing(parent, props, rng)
	_signature_mesas(parent)


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


func _land_at(a: float, r: float) -> Vector3:
	var x := map.center.x + cos(a) * r
	var z := map.center.z + sin(a) * r
	return Vector3(x, land(x, z, r), z)


## Terraced rim: stones down the arroyos, petrified stumps, a slot canyon per wall's arc.
func _rim_dressing(parent: Node3D, props: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for k in _arroyos.size():
		var a: Array = _arroyos[k]
		for j in rng.randi_range(10, 15):
			var r := rng.randf_range(RIM_R + 8.0, 185.0)
			var ang := _arroyo_centres(r)[k] + rng.randf_range(-0.5, 0.5) * float(a[1]) / r
			var p := _land_at(ang, r)
			var s := rng.randf_range(0.1, 0.3)
			MeshKit.add_box(props, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p + Vector3(0, s * 0.15, 0)), Vector3(s * 1.6, s * 0.5, s * 1.2), Color("#B8904A").darkened(rng.randf() * 0.15), s * 0.1, rng)
	# Petrified stumps: one behind each plateau on the first terrace's edge
	# (against the sky from the yard), more up high, a few fallen.
	var stumps := MeshKit.begin()
	var spots: Array = []
	for cid in map.count():
		spots.append([_cliff_dir[cid].angle() + rng.randf_range(-0.12, 0.12), RIM_R + 4.0])
	for k in 5:
		spots.append([rng.randf() * TAU, rng.randf_range(150.0, 192.0)])
	for k in spots.size():
		var p := _land_at(float(spots[k][0]), float(spots[k][1]))
		var rb := rng.randf_range(0.4, 0.8)
		var rt := rb * rng.randf_range(0.7, 0.8)
		var hh := rng.randf_range(1.5, 3.0)
		if k >= map.count() and k % 2 == 0:
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5)
			MeshKit.add_cylinder(stumps, Transform3D(b, p + Vector3(0, rb * 0.8, 0)), rb, rt, hh * 1.5, 9, Color.WHITE)
		else:
			MeshKit.add_cylinder(stumps, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p + Vector3(0, hh * 0.5 - 0.3, 0)), rb, rt, hh, 9, Color.WHITE)
	var greys := ["#5A5050", "#4E4646", "#6A5E5A", "#544A48", "#3E3838", "#6E625C", "#7A6E66"]
	t._add_visual(parent, "PetrifiedStumps", MeshKit.finish(stumps), t.banded("mesa_stump", Color("#6A6060"), greys, 0.15))
	# Slot canyons: dark slits in the second terrace's riser, in each arc's big arroyo.
	for i in map.count():
		var slot := MeshKit.begin()
		var a := float(_arroyos[_first_arroyo(i)][0])
		var r := RIM_R + TERRACE_W - 1.0
		var at := _land_at(a, r)
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := out.cross(Vector3.UP).normalized()
		var b := Basis(side, Vector3.UP, out)
		for sgn: float in [-1.0, 1.0]:
			MeshKit.add_box(slot, Transform3D(b, at + side * sgn * 1.65 + out * 3.0 + Vector3(0, 5.0, 0)), Vector3(1.5, 12.0, 8.0), Color.WHITE, 0.2, rng)
			for k in rng.randi_range(3, 4):
				var hh := rng.randf_range(1.0, 3.5)
				MeshKit.add_box(slot, Transform3D(b * Basis(Vector3.BACK, rng.randf_range(-0.2, 0.2)), at + side * sgn * 1.65 + out * rng.randf_range(0.0, 6.0) + Vector3(0, 11.0 + hh * 0.5, 0)), Vector3(1.4, hh, rng.randf_range(1.5, 2.5)), Color.WHITE, 0.15, rng)
		for k in rng.randi_range(3, 5):
			var s := rng.randf_range(0.4, 1.0)
			MeshKit.add_box(slot, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + side * rng.randf_range(-0.8, 0.8) - out * rng.randf_range(0.0, 1.0) + Vector3(0, s * 0.3, 0)), Vector3.ONE * s, Color.WHITE, s * 0.15, rng)
		t._add_visual(parent, "SlotCanyon%d" % i, MeshKit.finish(slot), t.wall_material(i))
		MeshKit.add_box(props, Transform3D(b, at + out * (-0.75) + Vector3(0, 5.0, 0)), Vector3(1.8, 10.0, 0.3), Color("#0E0A08"))
		MeshKit.add_box(props, Transform3D(b, at + out * 3.0 + Vector3(0, 5.0, 0)), Vector3(1.8, 10.0, 7.5), Color("#1A120E"))


func _first_arroyo(wall: int) -> int:
	var idx := 0
	for i in wall:
		idx += 3 if i != 1 else 2
	return idx


## Rolling desert: flat-topped mesas (some joined by arches) and the old camps.
func _desert_dressing(parent: Node3D, props: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var batches: Array[SurfaceTool] = []
	for cid in map.count():
		batches.append(MeshKit.begin())
	var mesas: Array[Vector3] = [] # x, z, base radius
	# Arch pairs first: two mesas a span apart with an arch between their feet.
	for k in 4:
		var a := rng.randf() * TAU
		var r := rng.randf_range(280.0, 520.0)
		var r1 := rng.randf_range(12.0, 16.0)
		var r2 := rng.randf_range(12.0, 16.0)
		var gap := rng.randf_range(15.0, 25.0)
		var c := Vector2(map.center.x, map.center.z) + Vector2.from_angle(a) * r
		var dir := Vector2.from_angle(a + PI * 0.5 + rng.randf_range(-0.5, 0.5))
		var ca := c - dir * (r1 * 1.15 + gap * 0.5)
		var cb2 := c + dir * (r2 * 1.15 + gap * 0.5)
		var cid := _nearest_cliff(a)
		_mesa(batches[cid], rng, ca, r1, false)
		_mesa(batches[cid], rng, cb2, r2, false)
		mesas.append(Vector3(ca.x, ca.y, r1))
		mesas.append(Vector3(cb2.x, cb2.y, r2))
		var fa := Vector3(ca.x + dir.x * r1 * 1.0, 0.0, ca.y + dir.y * r1 * 1.0)
		var fb := Vector3(cb2.x - dir.x * r2 * 1.0, 0.0, cb2.y - dir.y * r2 * 1.0)
		fa.y = land(fa.x, fa.z, Vector2(fa.x, fa.z).length()) - 1.0
		fb.y = land(fb.x, fb.z, Vector2(fb.x, fb.z).length()) - 1.0
		ArchBuilder.arch(batches[cid], rng, fa, fb, rng.randf_range(12.0, 18.0), rng.randf_range(2.6, 3.2), rng.randf_range(1.2, 1.6))
	# The rest scattered at least 40 m apart.
	var tries := 0
	while mesas.size() < 18 and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(230.0, 580.0)
		var c := Vector2(map.center.x, map.center.z) + Vector2.from_angle(a) * r
		var br := rng.randf_range(12.0, 25.0)
		var ok := true
		for m in mesas:
			if Vector2(m.x, m.y).distance_to(c) < 40.0 + (br + m.z) * 0.8:
				ok = false
				break
		if not ok:
			continue
		_mesa(batches[_nearest_cliff(a)], rng, c, br, mesas.size() % 3 == 0)
		mesas.append(Vector3(c.x, c.y, br))
	for cid in map.count():
		var m := MeshKit.finish(batches[cid])
		if m.get_surface_count() > 0:
			t._add_visual(parent, "NearMesas%d" % cid, m, t.rock_material(cid))
	# An abandoned camp on the high ground behind each plateau.
	for cid in map.count():
		var p := _land_at(_cliff_dir[cid].angle() + rng.randf_range(-0.25, 0.25), rng.randf_range(150.0, 180.0))
		_camp(props, rng, p)


func _nearest_cliff(a: float) -> int:
	var d := Vector2.from_angle(a)
	var best := 0
	for i in range(1, map.count()):
		if d.dot(_cliff_dir[i]) > d.dot(_cliff_dir[best]):
			best = i
	return best


## A small flat-topped mesa: a talus base and a sheer cap, sometimes with fallen blocks.
func _mesa(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector2, base_r: float, blocks: bool) -> void:
	var y := land(c.x, c.y, c.distance_to(Vector2(map.center.x, map.center.z)))
	var segs := rng.randi_range(12, 16)
	var bh := rng.randf_range(6.0, 10.0)
	var cap_r := base_r * rng.randf_range(0.65, 0.75)
	var ch := rng.randf_range(8.0, 20.0)
	var at := Vector3(c.x, y, c.y)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, bh * 0.5 - 3.0, 0)), base_r * 1.15, cap_r * 1.05, bh + 6.0, segs, Color.WHITE)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, bh + ch * 0.5 - 0.5, 0)), cap_r, cap_r * 0.96, ch, segs, Color.WHITE)
	if blocks:
		for k in rng.randi_range(8, 12):
			var a := rng.randf() * TAU
			var p := c + Vector2.from_angle(a) * base_r * rng.randf_range(1.1, 1.4)
			var s := rng.randf_range(1.0, 3.0)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), Vector3(p.x, land(p.x, p.y, p.distance_to(Vector2.ZERO)) + s * 0.3, p.y)), Vector3(s, s * 0.8, s * 1.2), Color.WHITE, s * 0.15, rng)


## A survey party's camp: a collapsed tent frame, a fire ring on a char stain, crates.
func _camp(st: SurfaceTool, rng: RandomNumberGenerator, p: Vector3) -> void:
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	# The A-frame: one end still standing, the other fallen flat.
	for sgn: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(b * Basis(Vector3.BACK, sgn * 0.55), p + b * Vector3(sgn * 0.55, 0.85, -1.0)), Vector3(0.08, 2.0, 0.08), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(b * Basis(Vector3.RIGHT, -1.2), p + b * Vector3(0.0, 0.85, 0.2)), Vector3(0.07, 0.07, 2.6), Palette.WOOD)
	for sgn: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(b * Basis(Vector3.UP, sgn * 0.4), p + b * Vector3(sgn * 0.5, 0.05, 1.6)), Vector3(0.08, 0.08, 2.0), Palette.WOOD)
	# Fire ring.
	var fire := p + b * Vector3(2.6, 0.0, 0.4)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), fire + Vector3(0, 0.0, 0)), Vector3(0.9, 0.03, 0.8), 2, 10, Color("#2A2018"))
	for k in 8:
		var a := TAU * float(k) / 8.0
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, a + rng.randf_range(-0.3, 0.3)), fire + Vector3(cos(a) * 0.6, 0.08, sin(a) * 0.6)), Vector3(0.22, 0.16, 0.18), Color("#3A3430"), 0.03, rng)
	for k in rng.randi_range(2, 3):
		MeshKit.add_box(st, Transform3D(b * Basis(Vector3.UP, rng.randf_range(-0.5, 0.5)), p + b * Vector3(-2.0 - k * 0.7, 0.2 + (0.4 if k == 2 else 0.0), rng.randf_range(-0.5, 0.5))), Vector3(0.6, 0.4, 0.4), Palette.WOOD_DARK, 0.02, rng)


## Three tall mesas on the horizon, one behind each plateau, each its own profile:
## a forked caprock, a leaning caprock with its fallen rock, and a wedding cake.
func _signature_mesas(parent: Node3D) -> void:
	var st := MeshKit.begin()
	var col := Color("#C98A5E")
	for cid in map.count():
		var a := _cliff_dir[cid].angle()
		var at := _land_at(a, 800.0) - Vector3(0, 10.0, 0)
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := out.cross(Vector3.UP).normalized()
		match cid:
			0:
				MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, 18.0, 0)), 130.0, 82.0, 36.0, 14, col.darkened(0.2))
				MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, 36.0 + 50.0, 0)), 78.0, 72.0, 100.0, 14, col.darkened(0.1))
				for sgn: float in [-1.0, 1.0]:
					MeshKit.add_cylinder(st, Transform3D(Basis(), at + side * sgn * 44.0 + Vector3(0, 136.0 + 8.0, 0)), 36.0, 36.0, 16.0, 12, col)
			1:
				MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, 16.0, 0)), 115.0, 75.0, 32.0, 14, col.darkened(0.2))
				MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, 32.0 + 55.0, 0)), 72.0, 66.0, 110.0, 14, col.darkened(0.12))
				var lean := Basis(out, deg_to_rad(8.0))
				MeshKit.add_cylinder(st, Transform3D(lean, at + side * 13.0 + Vector3(0, 142.0 + 7.0, 0)), 76.0, 78.0, 18.0, 14, col)
				for k in 4:
					var p := at + side * (95.0 + k * 22.0) + out * (k * 9.0 - 14.0)
					var hh := 5.0 + k * 1.6
					MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, k * 1.3), p + Vector3(0, hh * 0.5 + 8.0, 0)), 20.0 - k * 3.0, 14.0 - k * 2.0, hh, 9, col.darkened(0.15 + k * 0.03))
			_:
				var y := 0.0
				var radii := [100.0, 85.0, 70.0]
				var heights := [42.0, 52.0, 44.0]
				for k in 3:
					MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, y + float(heights[k]) * 0.5, 0)), float(radii[k]), float(radii[k]) * 0.97, float(heights[k]), 16, col.darkened(0.25 - k * 0.1))
					y += float(heights[k])
	t._add_visual(parent, "SignatureMesas", MeshKit.finish(st), Materials.strata(Palette.SAND), false)

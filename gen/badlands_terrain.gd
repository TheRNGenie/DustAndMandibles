class_name BadlandsTerrain
extends RefCounted
## The canyon's badlands (Badlands Terrain Redesign), out to REACH in every
## direction: one layered height field (broad plateaus, eroded washes and
## gullies, hogback ridges, fine detail, stepped into terraces) built as ground
## either side of the canyon in three rings of detail, with washes, caliche
## basins and varnished mesa tops in the ground's vertex colours (the badlands
## shader paints them). Mesas, buttes, hoodoos, arches and balanced rocks grow
## from the same field, scrub and boulders gather by the washes and under the
## mesa faces, a ring of banded peaks closes the rim and far silhouettes stand
## on the horizon. Visual only: no collision, no shadows.

const SHADER: Shader = preload("res://shaders/badlands_ground.gdshader")
const SILHOUETTE: Shader = preload("res://shaders/horizon_silhouette.gdshader")
const REACH := 2000.0
## Height of the open desert (about the plateaus' back walls, so they meet).
const BASE := WorldLayout.CLIFF_HEIGHT + 40.0
## Ground pieces each side: [d from, d to, z from, z to, step, skirt], d in
## metres out from the plateau's back edge. The near ring round the play area
## and the corridor (4 m), the mid ring (14 m), the far ring (60 m); a skirt
## hangs from every piece's edge so the joins never open a crack.
const PIECES := [
	[0.0, 300.0, -400.0, 400.0, 4.0, 2.0],
	[300.0, 800.0, -400.0, 400.0, 14.0, 6.0],
	[0.0, 800.0, -1000.0, -400.0, 14.0, 6.0],
	[0.0, 800.0, 400.0, 1000.0, 14.0, 6.0],
	[800.0, REACH, -1000.0, 1000.0, 60.0, 20.0],
	[0.0, REACH, -REACH, -1000.0, 60.0, 20.0],
	[0.0, REACH, 1000.0, REACH, 60.0, 20.0],
]
const TERRACE := 7.0
## Coarse grid the formations are picked from (metres), inside and outside MID_R.
const SCAN := 16.0
const SCAN_FAR := 48.0
const NEAR_R := 420.0
const MID_R := 900.0

var cb: CliffBuilder
var _plateau := FastNoiseLite.new()
var _erosion := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _init(cliffs: CliffBuilder) -> void:
	cb = cliffs
	_rng.seed = 8128
	_plateau.seed = 2211
	_plateau.frequency = 0.0018
	_plateau.fractal_octaves = 2
	_erosion.seed = 2212
	_erosion.frequency = 0.005
	_erosion.fractal_octaves = 4
	_ridge.seed = 2213
	_ridge.frequency = 0.003
	_ridge.fractal_octaves = 2
	_detail.seed = 2214
	_detail.frequency = 0.02
	_detail.fractal_octaves = 3


## Ground material (masks on) or the formations' rock (vertex colour tints).
static func material(ground: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("noise_tex", Materials.noise_texture(7, 0.02))
	mat.set_shader_parameter("masks", ground)
	mat.set_shader_parameter("base_y", BASE)
	# A soft rim: the toon rim light turns whole far slopes white at this scale.
	mat.set_shader_parameter("rim_strength", 0.12)
	return mat


# ---------------------------------------------------------------- the height field

## The badlands at (x, z): (height, wash, mesa top, caliche), the last three 0-1.
func sample(x: float, z: float) -> Vector4:
	var p := _plateau.get_noise_2d(x, z)
	var mesa := smoothstep(0.12, 0.19, p)
	var apron := smoothstep(-0.04, 0.13, p) # the pediment rising to a mesa's foot
	var basin := smoothstep(-0.08, -0.3, p)
	var ch := 1.0 - absf(_erosion.get_noise_2d(x, z))
	var wash := pow(ch, 9.0)
	var gully := ch * ch * ch
	# Hogbacks run across the canyon (long in x).
	var r := _ridge.get_noise_2d(x * 0.35, z * 1.4)
	var hog := pow(maxf(1.0 - absf(r) * 1.7, 0.0), 3.0) * (1.0 - mesa)
	var h := apron * 9.0 + mesa * 32.0 + hog * 15.0 - basin * 7.0
	h -= wash * (5.0 + 9.0 * (1.0 - mesa)) + gully * 3.5
	# Terraces: harder layers stand out as ledges.
	var t := h / TERRACE
	var terr := (floorf(t) + smoothstep(0.55, 1.0, t - floorf(t))) * TERRACE
	h = lerpf(h, terr, 0.55 + 0.35 * mesa)
	h += _detail.get_noise_2d(x, z) * (2.2 + 1.5 * hog)
	return Vector4(BASE + h, smoothstep(0.45, 0.85, wash) * (1.0 - mesa * 0.8),
			smoothstep(0.7, 1.0, mesa), basin * (1.0 - wash))


func height(x: float, z: float) -> float:
	return sample(x, z).x


## Out of the canyon and its plateaus (where formations may stand).
func clear_of_canyon(x: float, z: float, margin: float = 0.0) -> bool:
	var az := absf(z)
	if az < WorldLayout.WORLD_HALF_Z + 30.0:
		return absf(x) > 140.0 + margin
	if az < CliffBuilder.FAR_Z + 60.0:
		return absf(x - cb.center_x(clampf(z, -CliffBuilder.FAR_Z, CliffBuilder.FAR_Z))) > 250.0 + margin
	return true


# ---------------------------------------------------------------- build

func build(parent: Node3D) -> void:
	var ground := material(true)
	var rock := material(false)
	for cid in 2:
		_ground(parent, cid, ground)
	var spots := _scan()
	var st := MeshKit.begin()
	var scatter := MeshKit.begin()
	var arches := MeshKit.begin()
	_mesas(st, spots["mesas"])
	_buttes(st, spots["buttes"])
	_hoodoos(st, spots["hoodoos"])
	_arches(arches, spots["edges"])
	_balanced(st, scatter, spots["edges"])
	_scatter(st, scatter, spots["slopes"], spots["washes"])
	_peaks(st)
	_add(parent, "BadlandsRock", MeshKit.finish(st), rock)
	# Matte (no highlight blob): the scrub and the balanced rocks' boulders.
	var matte := Materials.toon(0.0).duplicate() as ShaderMaterial
	matte.set_shader_parameter("spec_strength", 0.0)
	_add(parent, "BadlandsScatter", MeshKit.finish(scatter), matte)
	_add(parent, "BadlandsArches", MeshKit.finish(arches), Materials.strata(Palette.SAND))
	horizon_silhouettes(parent)


func _add(parent: Node3D, node_name: String, mesh: ArrayMesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Where the ground strip of cliff `cid` starts at z: [seam point, d0, x0].
func _seam(cid: int, z: float) -> Array:
	# Just inside the plateau's back edge (deeper out in the wild canyon).
	var d0 := WorldLayout.TERRAIN_DEPTH - 3.0 if absf(z) < WorldLayout.WORLD_HALF_Z else 137.0
	if absf(z) > CliffBuilder.FAR_Z:
		d0 = -WorldLayout.HALF_GAP # past the canyon's end: run right to the middle
	var seam := cb.plateau_point(cid, maxf(d0, 0.0), clampf(z, -CliffBuilder.FAR_Z, CliffBuilder.FAR_Z))
	return [seam, d0, seam.x if d0 >= 0.0 else 0.0]


static func _steps(from: float, to: float, step: float) -> Array[float]:
	var out: Array[float] = []
	var n := maxi(int(ceilf((to - from) / step - 0.01)), 1)
	for i in n + 1:
		out.append(lerpf(from, to, float(i) / n))
	return out


## One cliff's side of the badlands, piece by piece (PIECES).
func _ground(parent: Node3D, cid: int, mat: Material) -> void:
	var s := WorldLayout.side_sign(cid)
	var seams: Dictionary = {}
	var end_ref := [cb.plateau_point(cid, 60.0, -CliffBuilder.FAR_Z).y - 0.6, cb.plateau_point(cid, 60.0, CliffBuilder.FAR_Z).y - 0.6]
	for k in PIECES.size():
		var pc: Array = PIECES[k]
		var ds := _steps(pc[0], pc[1], pc[4])
		var zs := _steps(pc[2], pc[3], pc[4])
		var grid: Array = []
		var colors := PackedColorArray()
		for d in ds:
			var row: Array[Vector3] = []
			for z in zs:
				if not seams.has(z):
					seams[z] = _seam(cid, z)
				var sm: Array = seams[z]
				var seam: Vector3 = sm[0]
				var x := float(sm[2]) + s * d
				var f := sample(x, z)
				var t := smoothstep(0.0, 140.0, d)
				var y := lerpf(seam.y - 0.6, f.x, t)
				if float(sm[1]) < 0.0:
					t = maxf(smoothstep(0.0, 300.0, absf(z) - CliffBuilder.FAR_Z), smoothstep(160.0, 300.0, d))
					y = lerpf(float(end_ref[1 if z > 0.0 else 0]), f.x, t)
				row.append(Vector3(x, y, z))
				colors.append(Color(f.y * t, f.z * t, f.w * t, 1.0))
			grid.append(row)
		var mi := MeshInstance3D.new()
		mi.name = "Badlands%d_%d" % [cid, k]
		mi.mesh = _skirted(cb._grid_arrays(grid, Vector3.UP, colors), ds.size(), zs.size(), float(pc[5]))
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## The grid mesh with a curtain `drop` metres deep hung round its edge (same
## normals and colours as the edge, facing out).
static func _skirted(arr: Array, rows: int, cols: int, drop: float) -> ArrayMesh:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var loop: Array[int] = []
	for j in cols:
		loop.append(j)
	for r in range(1, rows):
		loop.append(r * cols + cols - 1)
	for j in range(cols - 2, -1, -1):
		loop.append((rows - 1) * cols + j)
	for r in range(rows - 2, 0, -1):
		loop.append(r * cols)
	var mid := Vector3.ZERO
	for i in loop:
		mid += v[i]
	mid /= loop.size()
	var base := v.size()
	for i in loop:
		v.append(v[i] - Vector3(0.0, drop, 0.0))
		n.append(n[i])
		c.append(c[i])
	var m := loop.size()
	for k in m:
		var a := loop[k]
		var b := loop[(k + 1) % m]
		var a2 := base + k
		var b2 := base + (k + 1) % m
		var out := (v[a] + v[b]) * 0.5 - mid
		out.y = 0.0
		# Clockwise from outside (Godot's front face), as MeshKit.tri winds them.
		if (v[b] - v[a]).cross(v[b2] - v[a]).dot(out) > 0.0:
			idx.append_array([a, b2, b, a, a2, b2])
		else:
			idx.append_array([a, b, b2, a, b2, a2])
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = idx
	var out_mesh := ArrayMesh.new()
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out_mesh


## Reads the field on a coarse grid and sorts the spots the formations grow on.
func _scan() -> Dictionary:
	var out := {"mesas": [], "buttes": [], "hoodoos": [], "edges": [], "slopes": [], "washes": []}
	for ring in 2:
		var step := SCAN if ring == 0 else SCAN_FAR
		var lim := MID_R if ring == 0 else REACH * 0.86
		var n := int(lim / step)
		for ix in range(-n, n + 1):
			for iz in range(-n, n + 1):
				var x := ix * step + _rng.randf_range(-0.3, 0.3) * step
				var z := iz * step + _rng.randf_range(-0.3, 0.3) * step
				var r := Vector2(x, z).length()
				if (ring == 1 and absf(x) < MID_R and absf(z) < MID_R) or r > lim:
					continue
				if not clear_of_canyon(x, z, 20.0):
					continue
				var p := _plateau.get_noise_2d(x, z)
				var f := sample(x, z)
				var gx := height(x + 4.0, z) - height(x - 4.0, z)
				var gz := height(x, z + 4.0) - height(x, z - 4.0)
				var grad := Vector2(gx, gz) / 8.0
				var at := Vector3(x, f.x, z)
				var item := [at, p, grad, r]
				# The crowns of the plateaus: a taller remnant mesa stands on them.
				if p > 0.24 and _peak_of(x, z, p, step * 2.0):
					out["mesas"].append(item)
				# Just under the mesa threshold, a lone high spot: a butte.
				elif p > 0.03 and p < 0.11 and _peak_of(x, z, p, step * 2.5):
					out["buttes"].append(item)
				if ring == 0 and r < NEAR_R + 200.0:
					if grad.length() > 0.4 and f.y < 0.3:
						out["hoodoos"].append(item)
					if p > 0.1 and p < 0.15 and grad.length() > 0.25:
						out["edges"].append(item)
					if grad.length() > 0.15 and p > 0.04 and p < 0.14:
						out["slopes"].append(item)
					if f.y > 0.25 and f.y < 0.8:
						out["washes"].append(item)
	return out


## Is p the highest plateau value within `r` of (x, z)?
func _peak_of(x: float, z: float, p: float, r: float) -> bool:
	for k in 8:
		var a := TAU * k / 8.0
		if _plateau.get_noise_2d(x + cos(a) * r, z + sin(a) * r) > p:
			return false
	return true


## Up to `cap` of the spots in a seeded random order, at least `gap` apart.
func _thin(spots: Array, cap: int, gap: float) -> Array:
	var out: Array = []
	var order := spots.duplicate()
	for i in range(order.size() - 1, 0, -1): # (seeded: every peer builds the same)
		var j := _rng.randi_range(0, i)
		var tmp: Variant = order[i]
		order[i] = order[j]
		order[j] = tmp
	for s: Array in order:
		var at: Vector3 = s[0]
		var ok := true
		for o: Array in out:
			if Vector2(at.x - (o[0] as Vector3).x, at.z - (o[0] as Vector3).z).length() < gap:
				ok = false
				break
		if ok:
			out.append(s)
			if out.size() >= cap:
				break
	return out


static func _tint(rng: RandomNumberGenerator, lo: float = 0.82, hi: float = 0.95) -> Color:
	var k := rng.randf_range(lo, hi)
	return Color(k, k * rng.randf_range(0.96, 1.0), k * rng.randf_range(0.92, 1.0))


# ---------------------------------------------------------------- landforms

## Flat-top remnant mesas on the plateau crowns: terraced, tapering sides, a
## flat caprock with an overhanging lip and a talus apron. Far ones are a plain
## two-piece stack.
func _mesas(st: SurfaceTool, spots: Array) -> void:
	for s: Array in _thin(spots, 26, 220.0):
		var at: Vector3 = s[0]
		var far := float(s[3]) > MID_R
		var w := _rng.randf_range(20.0, 60.0)
		var h := _rng.randf_range(20.0, 60.0)
		var yaw := Basis(Vector3.UP, _rng.randf() * TAU)
		var segs := 7 if far else _rng.randi_range(9, 13)
		var base := at - Vector3(0, 3.0, 0)
		var squash := Vector3(1.0, 1.0, _rng.randf_range(0.6, 1.0))
		var b := yaw.scaled(squash)
		MeshKit.add_cylinder(st, Transform3D(b, base + Vector3(0, h * 0.1, 0)), w * 1.5, w * 1.05, h * 0.2, segs, _tint(_rng, 0.86, 0.95))
		if far:
			MeshKit.add_cylinder(st, Transform3D(b, base + Vector3(0, h * 0.6, 0)), w * 1.05, w * 0.92, h * 0.8, segs, _tint(_rng))
			continue
		var tiers := _rng.randi_range(2, 4)
		var y := h * 0.2
		var r := w * 1.05
		for k in tiers:
			var th := h * 0.7 / tiers
			var r1 := r * _rng.randf_range(0.86, 0.95)
			MeshKit.add_cylinder(st, Transform3D(b.rotated(Vector3.UP, _rng.randf_range(-0.2, 0.2)), base + Vector3(0, y + th * 0.5, 0)), r, r1, th, segs, _tint(_rng))
			# A narrow ledge where a harder layer sticks out.
			MeshKit.add_cylinder(st, Transform3D(b, base + Vector3(0, y + th, 0)), r1 * 1.04, r1 * 1.04, 0.8, segs, _tint(_rng, 0.75, 0.82))
			y += th
			r = r1 * 0.97
		# Caprock: a darker slab wider than the top of the body.
		MeshKit.add_cylinder(st, Transform3D(b, base + Vector3(0, y + h * 0.05, 0)), r * 1.06, r * 1.1, h * 0.1, segs, _tint(_rng, 0.74, 0.82))
		_talus(st, base, w * 1.4, w * 0.25)


## Lone buttes: narrow and steep, grooved, a cap stone a little wider than the body.
func _buttes(st: SurfaceTool, spots: Array) -> void:
	for s: Array in _thin(spots, 40, 140.0):
		var at: Vector3 = s[0]
		var far := float(s[3]) > MID_R
		var r := _rng.randf_range(4.0, 12.5)
		var h := _rng.randf_range(30.0, 70.0)
		var base := at - Vector3(0, 2.0, 0)
		var segs := 6 if far else _rng.randi_range(8, 11)
		var yaw := Basis(Vector3.UP, _rng.randf() * TAU)
		MeshKit.add_cylinder(st, Transform3D(yaw, base + Vector3(0, h * 0.08, 0)), r * 2.2, r * 1.2, h * 0.16, segs, _tint(_rng, 0.86, 0.95))
		if far:
			MeshKit.add_cylinder(st, Transform3D(yaw, base + Vector3(0, h * 0.55, 0)), r * 1.2, r, h * 0.8, segs, _tint(_rng))
			continue
		# The body in stacked drums that twist a little: the steps read as erosion grooves.
		var y := h * 0.16
		var rr := r * 1.15
		var drums := _rng.randi_range(4, 6)
		for k in drums:
			var th := h * 0.74 / drums
			var r1 := rr * _rng.randf_range(0.9, 1.0)
			MeshKit.add_cylinder(st, Transform3D(yaw.rotated(Vector3.UP, k * 0.37), base + Vector3(_rng.randf_range(-0.3, 0.3), y + th * 0.5, _rng.randf_range(-0.3, 0.3))), rr, r1, th, segs, _tint(_rng, 0.78 if k % 2 == 0 else 0.88, 0.95))
			y += th
			rr = r1
		MeshKit.add_cylinder(st, Transform3D(yaw, base + Vector3(0, y + h * 0.04, 0)), rr * 1.18, rr * 1.12, h * 0.08, segs, _tint(_rng, 0.6, 0.7))


## Hoodoo clusters on the steep steps: thin dark necks under pale cap stones.
func _hoodoos(st: SurfaceTool, spots: Array) -> void:
	for s: Array in _thin(spots, 30, 60.0):
		var c: Vector3 = s[0]
		for i in _rng.randi_range(3, 8):
			var p := c + Vector3(_rng.randf_range(-9.0, 9.0), 0.0, _rng.randf_range(-9.0, 9.0))
			p.y = height(p.x, p.z) - 0.6
			var h := _rng.randf_range(4.0, 12.0)
			var r := _rng.randf_range(0.5, 1.5)
			var yaw := Basis(Vector3.UP, _rng.randf() * TAU)
			MeshKit.add_cylinder(st, Transform3D(yaw, p + Vector3(0, h * 0.25, 0)), r * 1.5, r * 1.1, h * 0.5, 7, _tint(_rng, 0.8, 0.9))
			MeshKit.add_cylinder(st, Transform3D(yaw, p + Vector3(0, h * 0.68, 0)), r * 1.1, r * 0.6, h * 0.36, 7, _tint(_rng, 0.6, 0.7))
			MeshKit.add_ellipsoid(st, Transform3D(yaw, p + Vector3(0, h * 0.9, 0)), Vector3(r * 1.7, r * 0.7, r * 1.5), 4, 8, _tint(_rng, 0.95, 1.0), 0.15, _rng, 0.55)


## Natural arches where a mesa edge has been punched through (5-8 of them).
func _arches(st: SurfaceTool, spots: Array) -> void:
	for s: Array in _thin(spots, 7, 260.0):
		var at: Vector3 = s[0]
		var g: Vector2 = s[2]
		var along := Vector3(-g.y, 0.0, g.x).normalized()
		if along.length() < 0.5:
			along = Vector3.FORWARD
		var span := _rng.randf_range(15.0, 40.0)
		var a := at - along * span * 0.5
		var b := at + along * span * 0.5
		a.y = height(a.x, a.z) - 1.5
		b.y = height(b.x, b.z) - 1.5
		if not clear_of_canyon(a.x, a.z, 10.0) or not clear_of_canyon(b.x, b.z, 10.0):
			continue
		ArchBuilder.arch(st, _rng, a, b, _rng.randf_range(8.0, 20.0), span * 0.16, span * 0.08)


## Balanced rocks: a dark varnished boulder on a pale, eroded pedestal.
func _balanced(rock: SurfaceTool, scatter: SurfaceTool, spots: Array) -> void:
	for s: Array in _thin(spots, 10, 90.0):
		var at: Vector3 = s[0] + Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0))
		at.y = height(at.x, at.z) - 0.4
		var ph := _rng.randf_range(2.0, 5.0)
		var pr := _rng.randf_range(0.5, 1.0)
		MeshKit.add_cylinder(rock, Transform3D(Basis(), at + Vector3(0, ph * 0.5, 0)), pr * 1.4, pr, ph, 7, _tint(_rng, 0.95, 1.0), true, 0.6)
		var br := _rng.randf_range(1.0, 2.0)
		MeshKit.add_ellipsoid(scatter, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), at + Vector3(0, ph + br * 0.6, 0)), Vector3(br * 1.2, br * 0.8, br), 5, 9, Color("#5A3028"), 0.2, _rng)


## A ring of fallen blocks round a mesa's foot.
func _talus(st: SurfaceTool, base: Vector3, r: float, s: float) -> void:
	for i in 6:
		var a := _rng.randf() * TAU
		var p := base + Vector3(cos(a), 0, sin(a)) * r * _rng.randf_range(0.9, 1.15)
		p.y = height(p.x, p.z) + s * 0.1
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), p), Vector3(s, s * 0.6, s * 0.8), 3, 6, _tint(_rng, 0.75, 0.85), 0.2, _rng)


## Boulder fields under the mesa faces (in the strata of the height they lie
## at) and scrub along the washes (near ring).
func _scatter(rock: SurfaceTool, st: SurfaceTool, slopes: Array, washes: Array) -> void:
	for s: Array in _thin(slopes, 70, 26.0):
		var c: Vector3 = s[0]
		for i in _rng.randi_range(2, 5):
			var p := c + Vector3(_rng.randf_range(-7.0, 7.0), 0.0, _rng.randf_range(-7.0, 7.0))
			var r := _rng.randf_range(0.8, 3.2)
			p.y = height(p.x, p.z) + r * 0.4
			MeshKit.add_ellipsoid(rock, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), p), Vector3(r * 1.2, r * 0.85, r), 4, 8, _tint(_rng, 0.72, 0.9), 0.22, _rng)
	var greens := [Color("#5E6B34"), Color("#6E7A3C"), Color("#4E5A2E"), Color("#7A7444")]
	for s: Array in _thin(washes, 110, 18.0):
		var c: Vector3 = s[0]
		for i in _rng.randi_range(1, 4):
			var p := c + Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0))
			var r := _rng.randf_range(1.0, 2.0)
			p.y = height(p.x, p.z) + r * 0.2
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), p), Vector3(r, r * 0.6, r * 0.9), 3, 6, greens[_rng.randi() % greens.size()], 0.3, _rng)


## The ring of peaks at the rim: three or four differently tinted layers each,
## with a broken, uneven crest.
func _peaks(st: SurfaceTool) -> void:
	var n := 30
	for i in n:
		var a := TAU * float(i) / n + _rng.randf_range(-0.05, 0.05)
		var dist := _rng.randf_range(REACH * 0.9, REACH * 0.98)
		var base := Vector3(cos(a) * dist, BASE - 20.0, sin(a) * dist)
		var r := _rng.randf_range(150.0, 280.0)
		var h := _rng.randf_range(160.0, 340.0)
		var layers := _rng.randi_range(3, 4)
		var y := 0.0
		var rr := r
		for k in layers:
			var th := h * (0.55 / layers)
			var r1 := rr * _rng.randf_range(0.7, 0.82)
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), base + Vector3(0, y + th * 0.5, 0)), rr, r1, th, 7, _tint(_rng, 0.7 + 0.08 * (k % 2), 0.9))
			y += th
			rr = r1
		# The crest: a few leaning cones of different heights.
		for k in _rng.randi_range(2, 4):
			var off := Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4)) * rr
			var ch := h * _rng.randf_range(0.25, 0.45)
			var lean := Basis(Vector3.UP, _rng.randf() * TAU).rotated(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0.0, 0.18))
			MeshKit.add_cylinder(st, Transform3D(lean, base + off + Vector3(0, y + ch * 0.5, 0)), rr * _rng.randf_range(0.5, 0.8), rr * _rng.randf_range(0.0, 0.12), ch, 6, _tint(_rng, 0.72, 0.86))


# ---------------------------------------------------------------- the far horizon

## Faint landforms far past the badlands' rim (1400-1600 m, drawn behind
## everything by the silhouette shader): three tall flat-topped mesas to the
## north-north-west (a forked caprock, a leaning offset caprock, a stepped
## "wedding cake") and four pinwheel buttes to the east-south-east, one pair
## joined by a thin natural arch.
static func horizon_silhouettes(parent: Node3D) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1515
	var st := MeshKit.begin()
	var white := Color.WHITE
	var y0 := BASE - 30.0
	# North-north-west (north is -Z, east +X).
	var nnw := [[332.0, 1480.0], [339.0, 1580.0], [346.0, 1420.0]]
	for i in 3:
		var b := deg_to_rad(float(nnw[i][0]))
		var at := Vector3(sin(b), 0, -cos(b)) * float(nnw[i][1]) + Vector3(0, y0, 0)
		var h := [170.0, 150.0, 180.0][i] as float
		var w := rng.randf_range(90.0, 120.0)
		var yaw := Basis(Vector3.UP, rng.randf() * TAU)
		MeshKit.add_cylinder(st, Transform3D(yaw, at + Vector3(0, h * 0.06, 0)), w * 1.7, w * 1.15, h * 0.12, 9, white)
		match i:
			0: # A forked caprock: the top split by a deep notch.
				MeshKit.add_cylinder(st, Transform3D(yaw, at + Vector3(0, h * 0.45, 0)), w * 1.1, w * 0.95, h * 0.66, 9, white)
				for side: float in [-1.0, 1.0]:
					MeshKit.add_box(st, Transform3D(yaw, at + yaw.x * side * w * 0.48 + Vector3(0, h * 0.89, 0)), Vector3(w * 0.8, h * 0.22, w * 1.5), white)
			1: # A leaning caprock slid off to one side.
				MeshKit.add_cylinder(st, Transform3D(yaw, at + Vector3(0, h * 0.5, 0)), w * 1.1, w * 0.85, h * 0.76, 9, white)
				var tilt := yaw.rotated(yaw.z, 0.12)
				MeshKit.add_box(st, Transform3D(tilt, at + yaw.x * w * 0.35 + Vector3(0, h * 0.93, 0)), Vector3(w * 1.7, h * 0.14, w * 1.3), white)
			2: # The wedding cake: stacked tiers, each narrower.
				var y := h * 0.12
				var r := w * 1.15
				for k in 4:
					var th := h * 0.88 / 4.0
					MeshKit.add_cylinder(st, Transform3D(yaw, at + Vector3(0, y + th * 0.5, 0)), r, r * 0.97, th, 9, white)
					y += th
					r *= 0.74
	# East-south-east: four buttes turned like the arms of a pinwheel.
	var b2 := deg_to_rad(112.0)
	var hub := Vector3(sin(b2), 0, -cos(b2)) * 1520.0 + Vector3(0, y0, 0)
	var tops: Array[Vector3] = []
	for k in 4:
		var a := TAU * k / 4.0 + 0.3
		var arm := Vector3(cos(a), 0, sin(a))
		var at := hub + arm * 120.0
		var h := rng.randf_range(100.0, 135.0)
		# Long and thin, swept round the hub (the pinwheel's vanes).
		var yaw := Basis(Vector3.UP, -a + 0.6)
		MeshKit.add_cylinder(st, Transform3D(yaw, at + Vector3(0, h * 0.06, 0)), 60.0, 42.0, h * 0.12, 8, white)
		MeshKit.add_box(st, Transform3D(yaw, at + Vector3(0, h * 0.55, 0)), Vector3(38.0, h * 0.9, 110.0), white)
		tops.append(at + Vector3(0, h * 0.62, 0))
	# The hint of an arch: a thin rock band bowing between two of the buttes.
	var a0 := tops[0]
	var a1 := tops[1]
	var prev := a0
	for j in 12:
		var t := float(j + 1) / 12.0
		var p := a0.lerp(a1, t) + Vector3(0, sin(t * PI) * 40.0, 0)
		MeshKit.add_limb(st, prev, p, 9.0, white, 6)
		prev = p
	var mat := ShaderMaterial.new()
	mat.shader = SILHOUETTE
	var mi := MeshInstance3D.new()
	mi.name = "HorizonSilhouettes"
	mi.mesh = MeshKit.finish(st)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Far past the camera's far plane: never culled (the shader brings it in).
	mi.extra_cull_margin = 16384.0
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- dust devils

## A dust devil: a spinning column of dust wandering the near badlands (visual
## only, like the tumbleweeds but upright). Added by CanyonDressing.
class DustDevil extends GPUParticles3D:
	const TunnelRumble := preload("res://scenes/bugs/tunnel_rumble.gd")
	var terrain: BadlandsTerrain
	var seed_value := 0
	var _dir := Vector3.RIGHT
	var _turn := 0.0
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.seed = seed_value
		amount = 90
		lifetime = 4.0
		local_coords = false
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 50, 40))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = 2.5
		pm.emission_ring_inner_radius = 0.5
		pm.emission_ring_height = 1.0
		pm.direction = Vector3.UP
		pm.spread = 8.0
		pm.initial_velocity_min = 5.0
		pm.initial_velocity_max = 8.0
		pm.gravity = Vector3.ZERO
		pm.orbit_velocity_min = 0.5
		pm.orbit_velocity_max = 0.8
		pm.radial_velocity_min = 0.4
		pm.radial_velocity_max = 1.2
		pm.scale_min = 1.2
		pm.scale_max = 2.6
		var grad := Gradient.new()
		var dust := Palette.SAND.darkened(0.1)
		grad.set_color(0, Color(dust, 0.0))
		grad.add_point(0.15, Color(dust, 0.55))
		grad.set_color(grad.get_point_count() - 1, Color(dust.lightened(0.2), 0.0))
		var ramp := GradientTexture1D.new()
		ramp.gradient = grad
		pm.color_ramp = ramp
		process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(2.2, 2.2)
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = TunnelRumble.PUFF_SHADER
		mat.shader = sh
		quad.material = mat
		draw_pass_1 = quad
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(200.0, 380.0)
		position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		_dir = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
		emitting = true

	func _process(delta: float) -> void:
		if terrain == null:
			return
		_turn += delta * _rng.randf_range(-0.6, 0.6)
		_dir = _dir.rotated(Vector3.UP, _turn * delta)
		var p := position + _dir * 4.0 * delta
		# Stay out in the badlands (turn back at the canyon or the far edge).
		if not terrain.clear_of_canyon(p.x, p.z, 30.0) or Vector2(p.x, p.z).length() > 500.0:
			_dir = -_dir
			p = position
		p.y = terrain.height(p.x, p.z)
		position = p

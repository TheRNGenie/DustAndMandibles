class_name CliffBuilder
extends RefCounted
## Generates the canyon: two plateaus, two cliff faces with an overhanging lip and
## carved climb lanes, the canyon floor and end walls. Keeps its noise so later
## systems (bug climbing in M2) can query the exact cliff surface.

const FACE_Y_STEP := 0.6
const FACE_Z_STEP := 1.0
const PLATEAU_D_STEP := 1.0
const PLATEAU_Z_STEP := 1.5
const FLOOR_STEP := 1.5
const FLOOR_HALF_X := 27.0

var _noise: Array[FastNoiseLite] = []
var _floor_noise := FastNoiseLite.new()
## Beyond the play area the canyon stops being a straight trench: it meanders,
## pinches and widens, and its walls get buttresses, jagged rims and mesas.
var _wild := FastNoiseLite.new()


func _init(seed_value: int = 1234) -> void:
	for i in 2:
		var n := FastNoiseLite.new()
		n.seed = seed_value + i * 101
		n.frequency = 1.0
		n.fractal_octaves = 3
		_noise.append(n)
	_floor_noise.seed = seed_value + 7
	_floor_noise.frequency = 0.05
	_wild.seed = seed_value + 31
	_wild.frequency = 1.0
	_wild.fractal_octaves = 2


# ---------------------------------------------------------------- the wild canyon

## 0 inside the play area, rising to 1 a short way past it. Everything below
## only changes the canyon where this is above 0, so gameplay is untouched.
func wildness(z: float) -> float:
	return smoothstep(WorldLayout.WORLD_HALF_Z, WorldLayout.WORLD_HALF_Z + 70.0, absf(z))


## Sideways drift of the canyon's centre line (it bends left and right).
func center_x(z: float) -> float:
	var w := wildness(z)
	if w <= 0.0:
		return 0.0
	return w * (42.0 * sin(z * 0.0105 + 0.7) + 16.0 * sin(z * 0.027 + 2.1) + 6.0 * _wild.get_noise_1d(z * 0.02))


## How much wider (or narrower) than the play area the canyon is here.
func width_scale(z: float) -> float:
	return 1.0 + wildness(z) * (0.42 * _wild.get_noise_1d(z * 0.006 + 40.0) + 0.12)


## Canyon-relative point -> world point (identity in the play area).
func warp(p: Vector3) -> Vector3:
	if wildness(p.z) <= 0.0:
		return p
	return Vector3(center_x(p.z) + p.x * width_scale(p.z), p.y, p.z)


## World x -> canyon-relative x.
func unwarp_x(x: float, z: float) -> float:
	if wildness(z) <= 0.0:
		return x
	return (x - center_x(z)) / width_scale(z)


## Canyon-relative x on the floor -> world x (for placing things on the floor).
func floor_x(x: float, z: float) -> float:
	return warp(Vector3(x, 0.0, z)).x


## Buttresses: big rock fins that jut out of the far walls into the canyon,
## stepped like eroded sandstone. Metres of protrusion at (y, z).
func _buttress(cliff_id: int, y: float, z: float) -> float:
	var k := _wild.get_noise_2d(z * 0.035 + cliff_id * 300.0, 7.0)
	var fin := maxf(k - 0.15, 0.0) * 16.0
	if fin <= 0.0:
		return 0.0
	# Narrower toward the top, in three stepped tiers, with a ragged edge.
	var h := WorldLayout.CLIFF_HEIGHT
	var tier := floorf(y / (h / 3.0))
	var taper := 1.0 - tier * 0.28 - (y / h) * 0.15
	return fin * maxf(taper, 0.0) + _noise[cliff_id].get_noise_2d(z * 0.6, y * 0.4) * 1.2 * minf(fin, 1.0)


# ---------------------------------------------------------------- surface queries

## Lip wobble along the canyon (metres toward the canyon).
func edge_offset(cliff_id: int, z: float) -> float:
	var w := wildness(z)
	var jag := 0.0
	if w > 0.0:
		# A ragged, zig-zagging rim far from the play area.
		jag = w * (_noise[cliff_id].get_noise_2d(z * 0.018, 900.0) * 7.0 + _noise[cliff_id].get_noise_2d(z * 0.11, 950.0) * 2.2)
	return _noise[cliff_id].get_noise_2d(z * 0.05, 500.0) * 0.8 + jag


## How far (metres) the cliff face at height y sits toward the canyon from the nominal lip line.
func face_offset(cliff_id: int, y: float, z: float) -> float:
	var n := _noise[cliff_id]
	var prof := 0.0
	if y < WorldLayout.UNDERSIDE_BOTTOM:
		# Recessed face with a wider base.
		prof = -WorldLayout.OVERHANG + 2.5 * (1.0 - clampf(y, 0.0, WorldLayout.UNDERSIDE_BOTTOM) / WorldLayout.UNDERSIDE_BOTTOM)
	elif y < WorldLayout.LIP_BAND_BOTTOM:
		var t := (y - WorldLayout.UNDERSIDE_BOTTOM) / (WorldLayout.LIP_BAND_BOTTOM - WorldLayout.UNDERSIDE_BOTTOM)
		prof = lerpf(-WorldLayout.OVERHANG, 0.0, t)
	var below_lip := 1.0 - smoothstep(WorldLayout.ROUGH_TOP, WorldLayout.UNDERSIDE_BOTTOM + 0.6, y)
	var w := wildness(z)
	var rough := (n.get_noise_2d(z * 0.12, y * 0.12) * (1.0 + 2.2 * w) + n.get_noise_2d(z * 0.5, y * 0.5) * (0.3 + 0.9 * w)) * below_lip
	if w > 0.0:
		# Horizontal ledges where softer layers eroded, and buttresses.
		rough += w * (sin(y * 0.55 + n.get_noise_1d(z * 0.05) * 3.0) * 0.9 + _buttress(cliff_id, y, z))
	var lane := 0.0
	for lz in WorldLayout.LANE_Z:
		var dz := z - lz
		lane -= 0.8 * exp(-dz * dz / 1.5) # vertical crack marking the lane
		for ly in WorldLayout.LEDGE_Y:
			var dy := (y - ly) / 0.45
			lane += 1.0 * exp(-dz * dz / 4.0) * exp(-dy * dy) # small ledge
	return edge_offset(cliff_id, z) + prof + rough + lane * below_lip


## World position on a cliff face.
func face_point(cliff_id: int, y: float, z: float) -> Vector3:
	var s := WorldLayout.side_sign(cliff_id)
	return warp(Vector3(s * (WorldLayout.HALF_GAP - face_offset(cliff_id, y, z)), y, z))


## Outward surface normal of a cliff face (pointing into the canyon).
func face_normal(cliff_id: int, y: float, z: float) -> Vector3:
	var e := 0.4
	var dy := face_point(cliff_id, y + e, z) - face_point(cliff_id, y - e, z)
	var dz := face_point(cliff_id, y, z + e) - face_point(cliff_id, y, z - e)
	var n := dz.cross(dy).normalized()
	var outward := Vector3(-WorldLayout.side_sign(cliff_id), 0.0, 0.0)
	return n if n.dot(outward) >= 0.0 else -n


## Plateau coordinates (d back from the lip, z) of a world position.
func plateau_coords(cliff_id: int, pos: Vector3) -> Vector2:
	return Vector2(WorldLayout.side_sign(cliff_id) * unwarp_x(pos.x, pos.z) - WorldLayout.HALF_GAP, pos.z)


## Ground height under a world position on a plateau.
func ground_height_at(cliff_id: int, pos: Vector3) -> float:
	var pc := plateau_coords(cliff_id, pos)
	return plateau_height(cliff_id, maxf(pc.x, 0.0), pc.y)


## Plateau ground height at plateau coordinates (d back from lip, z along the canyon).
func plateau_height(cliff_id: int, d: float, z: float) -> float:
	var n := _noise[cliff_id]
	var flat := n.get_noise_2d(d * 0.08, z * 0.08) * 0.35 * smoothstep(0.0, 3.0, d)
	var back_hill := smoothstep(34.0, 48.0, d)
	var side_hill := smoothstep(23.0, 36.0, absf(z)) * smoothstep(3.0, 12.0, d)
	var hill_noise := 0.7 + 0.6 * (n.get_noise_2d(d * 0.03 + 50.0, z * 0.03) * 0.5 + 0.5)
	var hills := maxf(back_hill, side_hill) * 8.0 * hill_noise
	var w := wildness(z)
	if w > 0.0:
		# Out in the wilds: mesas and buttes with flat tops and steep sides,
		# and a rim that rises and falls.
		var m := _wild.get_noise_2d(d * 0.02 + cliff_id * 500.0, z * 0.02)
		var mesa := smoothstep(0.18, 0.3, m) * (14.0 + 10.0 * _wild.get_noise_2d(d * 0.05, z * 0.05 + 70.0))
		var swell := _wild.get_noise_2d(d * 0.01 + 900.0, z * 0.012) * 9.0
		hills += w * (mesa * smoothstep(8.0, 22.0, d) + swell * smoothstep(0.0, 10.0, d))
	return WorldLayout.CLIFF_HEIGHT + flat + hills


func plateau_point(cliff_id: int, d: float, z: float) -> Vector3:
	var s := WorldLayout.side_sign(cliff_id)
	var e := edge_offset(cliff_id, z) * (1.0 - smoothstep(0.0, 4.0 + 8.0 * wildness(z), d))
	return warp(Vector3(s * (WorldLayout.HALF_GAP - e + d), plateau_height(cliff_id, d, z), z))


## Canyon floor height under a world position.
func floor_height(x: float, z: float) -> float:
	return _raw_floor(unwarp_x(x, z), z)


func _raw_floor(x: float, z: float) -> float:
	var meander := 6.0 * sin(z * 0.035)
	var dx := x - meander
	var riverbed := -1.2 * exp(-dx * dx / 12.0)
	return _floor_noise.get_noise_2d(x, z) * 0.5 + riverbed


# ---------------------------------------------------------------- mesh building

## How far the canyon continues past the playable stretch (visual only, fades into fog).
const FAR_Z := 700.0
const FAR_STEP := 4.0


## Builds all canyon meshes and collisions under `parent`. The playable stretch
## (|z| <= WORLD_HALF_Z) is detailed and collidable; the canyon then keeps going
## into the distance in both directions at low detail, without collision.
func build(parent: Node3D) -> void:
	var rock := Materials.strata(Palette.SAND)
	var floor_mat := Materials.strata(Color("#D9A35E"))
	var near := Vector2(-WorldLayout.WORLD_HALF_Z, WorldLayout.WORLD_HALF_Z)
	for cid in 2:
		_add_static(parent, "Plateau%d" % cid, _build_plateau(cid, near, PLATEAU_Z_STEP, PLATEAU_D_STEP, WorldLayout.TERRAIN_DEPTH), rock)
		_add_static(parent, "CliffFace%d" % cid, _build_face(cid, near, FACE_Z_STEP, FACE_Y_STEP), rock)
	_add_static(parent, "CanyonFloor", _build_floor(near, FLOOR_STEP), floor_mat)
	# Distant canyon, both directions (a little overlap hides the seam).
	for side: float in [-1.0, 1.0]:
		var a := side * (WorldLayout.WORLD_HALF_Z - 2.0)
		var b := side * FAR_Z
		var span := Vector2(minf(a, b), maxf(a, b))
		var tag := "N" if side > 0.0 else "S"
		for cid in 2:
			_add_visual(parent, "FarPlateau%d%s" % [cid, tag], _build_plateau(cid, span, FAR_STEP, 3.0, 140.0), rock)
			_add_visual(parent, "FarFace%d%s" % [cid, tag], _build_face(cid, span, 2.5, 1.6), rock)
		_add_visual(parent, "FarFloor%s" % tag, _build_floor(span, FAR_STEP), floor_mat)
	_add_visual(parent, "FarRocks", _wild_rocks(), rock)
	_add_arches(parent, rock)


## Stone arches. Two span the canyon over the play area (north of the turret
## lanes and well clear of the airship's southern approach), one stands on each
## plateau beside the play area, all solid for grapple hooks; more span the
## wild canyon further out.
func _add_arches(parent: Node3D, rock: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var st := MeshKit.begin()
	# Two great arches right over the play area, feet behind each build grid
	# (and clear of the houses, windmill, water tower and scrap heap), crowns
	# about 35 m above the plateaus: hook one from the lip and swing across.
	# They sit either side of the zip line and well north of the airship.
	ArchBuilder.arch(st, rng, plateau_point(0, 41.0, -24.0) - Vector3(0, 2.0, 0), plateau_point(1, 41.0, -10.0) - Vector3(0, 2.0, 0), 30.0, 6.0, 2.8)
	ArchBuilder.arch(st, rng, plateau_point(0, 40.0, 26.0) - Vector3(0, 2.0, 0), plateau_point(1, 40.0, 14.0) - Vector3(0, 2.0, 0), 33.0, 6.0, 2.8)
	# Spanning arches further north: feet set back on each plateau.
	ArchBuilder.arch(st, rng, plateau_point(0, 9.0, 46.0) - Vector3(0, 1.5, 0), plateau_point(1, 9.0, 52.0) - Vector3(0, 1.5, 0), 26.0, 5.5, 2.6)
	ArchBuilder.arch(st, rng, plateau_point(0, 14.0, 80.0) - Vector3(0, 1.5, 0), plateau_point(1, 11.0, 72.0) - Vector3(0, 1.5, 0), 19.0, 5.0, 2.4)
	# A smaller arch on each plateau, off the build grid.
	ArchBuilder.arch(st, rng, plateau_point(0, 40.0, -62.0) - Vector3(0, 1.0, 0), plateau_point(0, 46.0, -40.0) - Vector3(0, 1.0, 0), 13.0, 3.6, 1.8)
	ArchBuilder.arch(st, rng, plateau_point(1, 38.0, 44.0) - Vector3(0, 1.0, 0), plateau_point(1, 44.0, 66.0) - Vector3(0, 1.0, 0), 12.0, 3.4, 1.7)
	_add_static(parent, "Arches", MeshKit.finish(st), rock)
	# Far arches (scenery only).
	var far := MeshKit.begin()
	for z: float in [-210.0, 190.0, -360.0, 330.0, 480.0]:
		var dz := rng.randf_range(-12.0, 12.0)
		ArchBuilder.arch(far, rng, plateau_point(0, rng.randf_range(6.0, 16.0), z - dz) - Vector3(0, 2.0, 0),
				plateau_point(1, rng.randf_range(6.0, 16.0), z + dz) - Vector3(0, 2.0, 0), rng.randf_range(16.0, 30.0), 6.0, 2.8)
	_add_visual(parent, "FarArches", MeshKit.finish(far), rock)


## Out past the play area: rock spires and toppled boulders on the canyon floor,
## and pinnacles and balanced rocks along the rims.
func _wild_rocks() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var st := MeshKit.begin()
	var cols := [Palette.ROCK_A, Palette.ROCK_B, Palette.ROCK_C, Color("#B85A3A"), Color("#D99A62")]
	for i in 70:
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := side * rng.randf_range(WorldLayout.WORLD_HALF_Z + 25.0, FAR_Z - 40.0)
		var rel := rng.randf_range(-16.0, 16.0)
		var base := warp(Vector3(rel, _raw_floor(rel, z) - 0.5, z))
		var h := rng.randf_range(10.0, 34.0)
		var r := rng.randf_range(2.0, 4.5)
		_spire(st, rng, base, h, r, cols[rng.randi() % cols.size()] as Color)
	for i in 50:
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := side * rng.randf_range(WorldLayout.WORLD_HALF_Z + 30.0, FAR_Z - 40.0)
		var cid := i % 2
		var d := rng.randf_range(4.0, 40.0)
		var base := plateau_point(cid, d, z) - Vector3(0, 0.6, 0)
		_spire(st, rng, base, rng.randf_range(5.0, 18.0), rng.randf_range(1.2, 3.2), cols[rng.randi() % cols.size()] as Color)
	for i in 90:
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := side * rng.randf_range(WorldLayout.WORLD_HALF_Z + 10.0, FAR_Z - 20.0)
		var rel := rng.randf_range(-20.0, 20.0)
		var s := rng.randf_range(1.5, 6.0)
		var at := warp(Vector3(rel, _raw_floor(rel, z) + s * 0.3, z))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), Vector3(s * 1.2, s * 0.8, s), 5, 9, cols[rng.randi() % cols.size()] as Color, 0.25, rng)
	return MeshKit.finish(st)


## A stacked, weathered stone spire with a wider cap (a hoodoo or a pinnacle).
func _spire(st: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, h: float, r: float, col: Color) -> void:
	var segs := rng.randi_range(4, 7)
	var at := base
	for k in segs:
		var seg_h := h / segs
		var t := float(k) / segs
		var rr := r * lerpf(1.15, 0.55, t) * rng.randf_range(0.8, 1.15)
		var c := col.darkened(0.12 * float(k % 2)).lightened(rng.randf() * 0.06)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.BACK, rng.randf_range(-0.06, 0.06)), at + Vector3(0, seg_h * 0.5, 0)),
				rr * 0.9, rr, seg_h, 8, c)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), at + Vector3(0, seg_h, 0)), Vector3(rr * 1.1, seg_h * 0.12, rr * 1.1), 3, 8, c.darkened(0.15), 0.2, rng)
		at += Vector3(rng.randf_range(-0.35, 0.35), seg_h, rng.randf_range(-0.35, 0.35))
	# Cap stone, sometimes a big balanced boulder.
	var cap := r * rng.randf_range(0.9, 1.6)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, cap * 0.35, 0)), Vector3(cap * 1.3, cap * 0.6, cap * 1.1), 5, 9, col.darkened(0.2), 0.2, rng)


func _add_visual(parent: Node3D, node_name: String, mesh: ArrayMesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)


func _add_static(parent: Node3D, node_name: String, mesh: ArrayMesh, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	col.shape = shape
	body.add_child(col)


func _face_rows(y_step: float) -> Array[float]:
	var rows: Array[float] = []
	var h := WorldLayout.CLIFF_HEIGHT
	var y := -2.0
	while y < h - 3.0:
		rows.append(y)
		y += y_step
	rows.append_array([h - 3.0, h - 2.6, h - 2.2, h - 1.8, h - 1.4, h - 0.7, h])
	return rows


static func _zs(span: Vector2, step: float) -> Array[float]:
	var zs: Array[float] = []
	var z := span.x
	while z < span.y - 0.001:
		zs.append(z)
		z += step
	zs.append(span.y)
	return zs


func _build_face(cid: int, span: Vector2, z_step: float, y_step: float) -> ArrayMesh:
	var grid: Array = []
	var zs := _zs(span, z_step)
	for y in _face_rows(y_step):
		var row: Array[Vector3] = []
		for zz in zs:
			row.append(face_point(cid, y, zz))
		grid.append(row)
	var outward := Vector3(-WorldLayout.side_sign(cid), 0.0, 0.0)
	return _grid_mesh(grid, outward)


func _build_plateau(cid: int, span: Vector2, z_step: float, d_step: float, depth: float) -> ArrayMesh:
	var grid: Array = []
	var zs := _zs(span, z_step)
	var d := 0.0
	while d <= depth + 0.001:
		var row: Array[Vector3] = []
		for z in zs:
			row.append(plateau_point(cid, d, z))
		grid.append(row)
		d += d_step
	return _grid_mesh(grid, Vector3.UP)


func _build_floor(span: Vector2, step: float) -> ArrayMesh:
	var grid: Array = []
	var zs := _zs(span, step)
	var x := -FLOOR_HALF_X
	while x <= FLOOR_HALF_X + 0.001:
		var row: Array[Vector3] = []
		for z in zs:
			row.append(warp(Vector3(x, _raw_floor(x, z), z)))
		grid.append(row)
		x += step
	return _grid_mesh(grid, Vector3.UP)


## Turns a 2D grid of positions (Array of Array[Vector3]) into a smooth-shaded mesh
## whose faces point roughly along `outward`.
func _grid_mesh(grid: Array, outward: Vector3) -> ArrayMesh:
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

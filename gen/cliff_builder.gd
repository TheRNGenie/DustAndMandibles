class_name CliffBuilder
extends RefCounted
## Generates the canyon: two plateaus, two cliff faces with an overhanging lip and
## carved climb lanes, the canyon floor and end walls. Keeps its noise so later
## systems (bug climbing in M2) can query the exact cliff surface.

const FACE_Y_STEP := 0.5
const FACE_Z_STEP := 1.0
const PLATEAU_D_STEP := 1.0
const PLATEAU_Z_STEP := 1.5
const FLOOR_STEP := 1.5
const FLOOR_HALF_X := 27.0

var _noise: Array[FastNoiseLite] = []
var _floor_noise := FastNoiseLite.new()


func _init(seed_value: int = 1234) -> void:
	for i in 2:
		var n := FastNoiseLite.new()
		n.seed = seed_value + i * 101
		n.frequency = 1.0
		n.fractal_octaves = 3
		_noise.append(n)
	_floor_noise.seed = seed_value + 7
	_floor_noise.frequency = 0.05


# ---------------------------------------------------------------- surface queries

## Lip wobble along the canyon (metres toward the canyon).
func edge_offset(cliff_id: int, z: float) -> float:
	return _noise[cliff_id].get_noise_2d(z * 0.05, 500.0) * 0.8


## How far (metres) the cliff face at height y sits toward the canyon from the nominal lip line.
func face_offset(cliff_id: int, y: float, z: float) -> float:
	var n := _noise[cliff_id]
	var prof := 0.0
	if y < WorldLayout.UNDERSIDE_BOTTOM:
		# Recessed face with a wider base.
		prof = -WorldLayout.OVERHANG + 1.4 * (1.0 - clampf(y, 0.0, 25.0) / WorldLayout.UNDERSIDE_BOTTOM)
	elif y < WorldLayout.LIP_BAND_BOTTOM:
		var t := (y - WorldLayout.UNDERSIDE_BOTTOM) / (WorldLayout.LIP_BAND_BOTTOM - WorldLayout.UNDERSIDE_BOTTOM)
		prof = lerpf(-WorldLayout.OVERHANG, 0.0, t)
	var below_lip := 1.0 - smoothstep(24.5, 26.0, y)
	var rough := (n.get_noise_2d(z * 0.12, y * 0.12) * 1.0 + n.get_noise_2d(z * 0.5, y * 0.5) * 0.3) * below_lip
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
	return Vector3(s * (WorldLayout.HALF_GAP - face_offset(cliff_id, y, z)), y, z)


## Plateau ground height at plateau coordinates (d back from lip, z along the canyon).
func plateau_height(cliff_id: int, d: float, z: float) -> float:
	var n := _noise[cliff_id]
	var flat := n.get_noise_2d(d * 0.08, z * 0.08) * 0.35 * smoothstep(0.0, 3.0, d)
	var back_hill := smoothstep(34.0, 48.0, d)
	var side_hill := smoothstep(23.0, 36.0, absf(z)) * smoothstep(3.0, 12.0, d)
	var hill_noise := 0.7 + 0.6 * (n.get_noise_2d(d * 0.03 + 50.0, z * 0.03) * 0.5 + 0.5)
	var hills := maxf(back_hill, side_hill) * 8.0 * hill_noise
	return WorldLayout.CLIFF_HEIGHT + flat + hills


func plateau_point(cliff_id: int, d: float, z: float) -> Vector3:
	var s := WorldLayout.side_sign(cliff_id)
	var e := edge_offset(cliff_id, z) * (1.0 - smoothstep(0.0, 4.0, d))
	return Vector3(s * (WorldLayout.HALF_GAP - e + d), plateau_height(cliff_id, d, z), z)


func floor_height(x: float, z: float) -> float:
	var meander := 6.0 * sin(z * 0.035)
	var dx := x - meander
	var riverbed := -1.2 * exp(-dx * dx / 12.0)
	return _floor_noise.get_noise_2d(x, z) * 0.5 + riverbed


# ---------------------------------------------------------------- mesh building

## Builds all canyon meshes and collisions under `parent`.
func build(parent: Node3D) -> void:
	var rock := Materials.strata(Palette.SAND)
	var floor_mat := Materials.strata(Color("#D9A35E"))
	for cid in 2:
		_add_static(parent, "Plateau%d" % cid, _build_plateau(cid), rock)
		_add_static(parent, "CliffFace%d" % cid, _build_face(cid), rock)
	_add_static(parent, "CanyonFloor", _build_floor(), floor_mat)
	for end_sign: float in [-1.0, 1.0]:
		_add_static(parent, "EndWall%d" % int(end_sign), _build_end_wall(end_sign), rock)


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


func _face_rows() -> Array[float]:
	var rows: Array[float] = []
	var y := -2.0
	while y < 25.0:
		rows.append(y)
		y += FACE_Y_STEP
	rows.append_array([25.0, 25.4, 25.8, 26.2, 26.6, 27.3, WorldLayout.CLIFF_HEIGHT])
	return rows


func _build_face(cid: int) -> ArrayMesh:
	var rows := _face_rows()
	var grid: Array = []
	var z := -WorldLayout.WORLD_HALF_Z
	var zs: Array[float] = []
	while z <= WorldLayout.WORLD_HALF_Z + 0.001:
		zs.append(z)
		z += FACE_Z_STEP
	for y in rows:
		var row: Array[Vector3] = []
		for zz in zs:
			row.append(face_point(cid, y, zz))
		grid.append(row)
	var outward := Vector3(-WorldLayout.side_sign(cid), 0.0, 0.0)
	return _grid_mesh(grid, outward)


func _build_plateau(cid: int) -> ArrayMesh:
	var grid: Array = []
	var d := 0.0
	while d <= WorldLayout.TERRAIN_DEPTH + 0.001:
		var row: Array[Vector3] = []
		var z := -WorldLayout.WORLD_HALF_Z
		while z <= WorldLayout.WORLD_HALF_Z + 0.001:
			row.append(plateau_point(cid, d, z))
			z += PLATEAU_Z_STEP
		grid.append(row)
		d += PLATEAU_D_STEP
	return _grid_mesh(grid, Vector3.UP)


func _build_floor() -> ArrayMesh:
	var grid: Array = []
	var x := -FLOOR_HALF_X
	while x <= FLOOR_HALF_X + 0.001:
		var row: Array[Vector3] = []
		var z := -WorldLayout.WORLD_HALF_Z
		while z <= WorldLayout.WORLD_HALF_Z + 0.001:
			row.append(Vector3(x, floor_height(x, z), z))
			z += FLOOR_STEP
		grid.append(row)
		x += FLOOR_STEP
	return _grid_mesh(grid, Vector3.UP)


## A rock wall closing each end of the canyon, rising above the plateaus like a mesa.
func _build_end_wall(end_sign: float) -> ArrayMesh:
	var n := _noise[0]
	var grid: Array = []
	var y := -2.0
	while y <= 38.0 + 0.001:
		var row: Array[Vector3] = []
		var x := -45.0
		while x <= 45.0 + 0.001:
			var bulge := n.get_noise_2d(x * 0.1, y * 0.1 + 300.0 * end_sign) * 2.5
			var z := end_sign * (WorldLayout.WORLD_HALF_Z - 2.0 + bulge)
			row.append(Vector3(x, y, z))
			x += 1.5
		grid.append(row)
		y += 1.0
	return _grid_mesh(grid, Vector3(0.0, 0.0, -end_sign))


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

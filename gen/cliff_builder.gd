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
		prof = -WorldLayout.OVERHANG + 2.5 * (1.0 - clampf(y, 0.0, WorldLayout.UNDERSIDE_BOTTOM) / WorldLayout.UNDERSIDE_BOTTOM)
	elif y < WorldLayout.LIP_BAND_BOTTOM:
		var t := (y - WorldLayout.UNDERSIDE_BOTTOM) / (WorldLayout.LIP_BAND_BOTTOM - WorldLayout.UNDERSIDE_BOTTOM)
		prof = lerpf(-WorldLayout.OVERHANG, 0.0, t)
	var below_lip := 1.0 - smoothstep(WorldLayout.ROUGH_TOP, WorldLayout.UNDERSIDE_BOTTOM + 0.6, y)
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
	return Vector2(WorldLayout.side_sign(cliff_id) * pos.x - WorldLayout.HALF_GAP, pos.z)


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
			_add_visual(parent, "FarPlateau%d%s" % [cid, tag], _build_plateau(cid, span, FAR_STEP, FAR_STEP, 140.0), rock)
			_add_visual(parent, "FarFace%d%s" % [cid, tag], _build_face(cid, span, FAR_STEP, 2.0), rock)
		_add_visual(parent, "FarFloor%s" % tag, _build_floor(span, FAR_STEP), floor_mat)


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
			row.append(Vector3(x, floor_height(x, z), z))
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

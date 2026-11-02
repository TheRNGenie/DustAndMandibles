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
	return edge_offset(cliff_id, z) + prof + rough


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
	hills = maxf(hills, _enclosure(cliff_id, d, z))
	var w := wildness(z)
	if w > 0.0:
		# Out in the wilds: mesas and buttes with flat tops and steep sides,
		# and a rim that rises and falls.
		var m := _wild.get_noise_2d(d * 0.02 + cliff_id * 500.0, z * 0.02)
		var mesa := smoothstep(0.18, 0.3, m) * (14.0 + 10.0 * _wild.get_noise_2d(d * 0.05, z * 0.05 + 70.0))
		var swell := _wild.get_noise_2d(d * 0.01 + 900.0, z * 0.012) * 9.0
		hills += w * (mesa * smoothstep(8.0, 22.0, d) + swell * smoothstep(0.0, 10.0, d))
	return WorldLayout.CLIFF_HEIGHT + flat + hills


## The walls that hem the play area in: a sheer, jagged cliff rising behind
## each homestead, and rock walls closing off both ends of each plateau, all
## topped with broken teeth. Starts outside the fences, so nothing playable moves.
func _enclosure(cliff_id: int, d: float, z: float) -> float:
	var n := _noise[cliff_id]
	var back_rise := smoothstep(44.0, 54.0, d)
	var back_h := 34.0 + 16.0 * (n.get_noise_2d(z * 0.04, 300.0) * 0.5 + 0.5)
	var back_teeth := maxf(n.get_noise_2d(z * 0.18, d * 0.18 + 90.0), 0.0) * 18.0 * smoothstep(50.0, 58.0, d)
	var back := back_rise * back_h + back_teeth
	var side_rise := smoothstep(32.0, 44.0, absf(z)) * smoothstep(4.0, 14.0, d)
	var side_h := 28.0 + 14.0 * (n.get_noise_2d(d * 0.05, z * 0.05 + 400.0) * 0.5 + 0.5)
	var side_teeth := maxf(n.get_noise_2d(d * 0.2 + 70.0, z * 0.2), 0.0) * 12.0 * side_rise
	return maxf(back, side_rise * side_h + side_teeth)


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
	var wild := _floor_noise.get_noise_2d(x, z) * 0.5 + riverbed
	# Through the play area the floor is solid packed ground, nearly flat.
	var flat := 1.0 - smoothstep(WorldLayout.WORLD_HALF_Z, WorldLayout.WORLD_HALF_Z + 30.0, absf(z))
	return lerpf(wild, _floor_noise.get_noise_2d(x * 0.5, z * 0.5) * 0.08, flat)


## Where a bug tunnel opens at the foot of cliff `cliff_id` in lane z (on the floor).
func tunnel_mouth(cliff_id: int, z: float) -> Vector3:
	var p := face_point(cliff_id, 0.0, z)
	return Vector3(p.x, floor_height(p.x, z), z)


## Dark tunnel mouths at the foot of both cliffs, one per lane, with a broken rock
## rim and rubble spilling out: the bugs crawl out of these and across the floor.
func _bug_tunnels() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var st := MeshKit.begin()
	var rim_cols := [Color("#6E3A2C"), Color("#5A3028"), Color("#7E4434")]
	for cid in 2:
		var s := WorldLayout.side_sign(cid)
		var out := Vector3(-s, 0, 0) # from the cliff into the canyon
		for tn: Array in WorldLayout.TUNNELS:
			if int(tn[0]) != cid:
				continue
			var m := tunnel_mouth(cid, float(tn[1]))
			var w := rng.randf_range(4.4, 5.4)
			var h := rng.randf_range(3.6, 4.3)
			# The hole: nested dark arches, blackest at the back, so it reads as deep.
			for k in 4:
				var depth := 0.35 - k * 0.12
				var shrink := 1.0 - k * 0.12
				var col := Color("#160C0A").darkened(k * 0.3)
				var prev := m + out * depth + Vector3(0, 0, -w * 0.5 * shrink)
				var c0 := m + out * depth
				for j in 13:
					var a := PI * float(j) / 12.0
					var pt := m + out * depth + Vector3(0, sin(a) * h * shrink, -cos(a) * w * 0.5 * shrink)
					MeshKit.tri(st, c0, prev, pt, out, out, out, MeshKit.vcol(col), out)
					prev = pt
			# Rough rock rim round the opening.
			var last := Vector3.ZERO
			for j in 15:
				var a := PI * float(j) / 14.0
				var pt := m + out * 0.45 + Vector3(0, sin(a) * (h + 0.35), -cos(a) * (w * 0.5 + 0.35))
				pt += Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
				if j > 0:
					MeshKit.add_limb(st, last, pt, rng.randf_range(0.5, 0.8), rim_cols[rng.randi() % rim_cols.size()], 6)
				last = pt
			# Rubble and claw-scraped dirt spilling out onto the floor.
			for k in 7:
				var r := m + out * rng.randf_range(0.8, 3.5) + Vector3(0, 0.1, rng.randf_range(-w * 0.6, w * 0.6))
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), r), Vector3(rng.randf_range(0.25, 0.6), rng.randf_range(0.15, 0.35), rng.randf_range(0.25, 0.6)),
						4, 7, rim_cols[rng.randi() % rim_cols.size()].darkened(0.1), 0.25, rng)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), m + out * 2.0 + Vector3(0, 0.02, 0)), Vector3(2.4, 0.04, w * 0.55), 3, 12, Color("#7A5038"))
	return MeshKit.finish(st)


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
	_add_visual(parent, "HostileRidges", _hostile_ridges(), rock)
	_add_visual(parent, "Bones", _carcasses(), Materials.toon(0.03))
	_add_visual(parent, "BugTunnels", _bug_tunnels(), Materials.toon(0.03))
	_add_hinterland(parent, rock)


# ---------------------------------------------------------------- hinterland
## How far the desert runs out past the plateaus in every direction (visual only).
const HINTER := 1800.0


## Rolling high desert all round the canyon, out to the horizon, with mesas,
## buttes and a ring of far mountains, so the view from the airship (or a
## grapple swing) never ends at a hard edge. Visual only, no collision.
func _add_hinterland(parent: Node3D, rock: Material) -> void:
	var hills := FastNoiseLite.new()
	hills.seed = 777
	hills.frequency = 0.004
	hills.fractal_octaves = 3
	var top := WorldLayout.CLIFF_HEIGHT
	var land := func(x: float, z: float) -> float:
		# About as high as the wild plateaus out past the play area, so they meet.
		return top + 40.0 + hills.get_noise_2d(x, z) * 16.0
	# Rows of growing spacing: fine near the plateau edge, coarse at the horizon.
	var ds: Array[float] = []
	var step := 6.0
	var dd := 0.0
	while dd < HINTER:
		ds.append(dd)
		dd += step
		step = minf(step * 1.12, 90.0)
	ds.append(HINTER)
	var zs := _zs(Vector2(-HINTER, HINTER), 24.0)
	for cid in 2:
		var s := WorldLayout.side_sign(cid)
		var grid: Array = []
		for d in ds:
			var row: Array[Vector3] = []
			for z: float in zs:
				# Starts just inside the plateau's back edge (which is deeper outside the play area).
				var d0 := WorldLayout.TERRAIN_DEPTH - 3.0 if absf(z) < WorldLayout.WORLD_HALF_Z else 137.0
				if absf(z) > FAR_Z:
					d0 = -WorldLayout.HALF_GAP # past the canyon's end: run right to the middle
				var seam := plateau_point(cid, maxf(d0, 0.0), clampf(z, -FAR_Z, FAR_Z))
				var x0 := seam.x if d0 >= 0.0 else 0.0
				var p := Vector3(x0 + s * d, 0.0, z)
				var p_end := absf(z) - FAR_Z
				if d0 >= 0.0:
					p.y = lerpf(seam.y - 0.6, land.call(p.x, z), smoothstep(0.0, 140.0, d))
				else:
					# Past the canyon's end: level with the plateaus there, easing into the hills.
					var ref := plateau_point(cid, 60.0, signf(z) * FAR_Z).y - 0.6
					p.y = lerpf(ref, land.call(p.x, z), maxf(smoothstep(0.0, 300.0, p_end), smoothstep(160.0, 300.0, d)))
				row.append(p)
			grid.append(row)
		var mi := MeshInstance3D.new()
		mi.name = "Hinterland%d" % cid
		mi.mesh = _grid_mesh(grid, Vector3.UP)
		mi.material_override = rock
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	# Mesas and buttes out on the flats, and the mountains at the rim.
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var st := MeshKit.begin()
	var cols := [Palette.ROCK_A, Palette.ROCK_B, Palette.ROCK_C, Color("#B85A3A"), Color("#D99A62")]
	var placed := 0
	while placed < 70:
		var x := rng.randf_range(-HINTER * 0.85, HINTER * 0.85)
		var z := rng.randf_range(-HINTER * 0.85, HINTER * 0.85)
		# Keep clear of the canyon and its plateaus.
		if absf(x) < 240.0 and absf(z) < FAR_Z + 60.0:
			continue
		if absf(x) < 120.0:
			continue
		placed += 1
		var base := Vector3(x, land.call(x, z) - 3.0, z)
		var butte := rng.randf() < 0.4
		var r := rng.randf_range(10.0, 22.0) if butte else rng.randf_range(30.0, 90.0)
		var h := rng.randf_range(35.0, 90.0) if butte else rng.randf_range(20.0, 55.0)
		var col: Color = cols[rng.randi() % cols.size()]
		var segs := rng.randi_range(7, 11)
		# Talus skirt, then the cliff-sided body with a flat cap.
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), base + Vector3(0, h * 0.12, 0)), r * 1.45, r * 1.05, h * 0.25, segs, col.darkened(0.1))
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), base + Vector3(0, h * 0.6, 0)), r * 1.05, r * 0.92, h * 0.8, segs, col)
	for i in 34:
		var a := TAU * float(i) / 34.0 + rng.randf_range(-0.05, 0.05)
		var dist := rng.randf_range(HINTER * 0.88, HINTER * 0.98)
		var base := Vector3(cos(a) * dist, top + 20.0, sin(a) * dist)
		var h := rng.randf_range(160.0, 360.0)
		var r := rng.randf_range(160.0, 300.0)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), base + Vector3(0, h * 0.5, 0)), r, r * rng.randf_range(0.05, 0.25), h, rng.randi_range(5, 8), Color("#C98A5E").darkened(rng.randf_range(0.0, 0.25)))
	var far := MeshInstance3D.new()
	far.name = "Mesas"
	far.mesh = MeshKit.finish(st)
	far.material_override = rock
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(far)


## Hostile dressing on the walls around the play area: leaning rock spikes
## along the ridges, and huge curved rock claws that hook out over the plateaus.
func _hostile_ridges() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	var st := MeshKit.begin()
	var dark := [Color("#6E3A2C"), Color("#5A3028"), Color("#7E4434"), Palette.ROCK_C.darkened(0.3)]
	for cid in 2:
		var s := WorldLayout.side_sign(cid)
		# Spikes on the back wall and the side walls.
		for i in 46:
			var d := rng.randf_range(50.0, 60.0)
			var z := rng.randf_range(-80.0, 80.0)
			if i % 3 == 0:
				d = rng.randf_range(12.0, 56.0)
				z = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(42.0, 80.0)
			var base := plateau_point(cid, d, z) - Vector3(0, 1.0, 0)
			var h := rng.randf_range(7.0, 20.0)
			var r := rng.randf_range(1.0, 2.6)
			var lean := Vector3(-s * rng.randf_range(0.0, 0.35), 1.0, rng.randf_range(-0.25, 0.25)).normalized()
			var c: Color = dark[rng.randi() % dark.size()]
			MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(lean), base + lean * h * 0.5), r, 0.0, h, 7, c)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), base), Vector3(r * 1.6, r * 0.8, r * 1.6), 4, 8, c.darkened(0.15), 0.25, rng)
		# Rock claws: thick curved talons arching out from the back wall toward the house.
		for k in 4:
			var z := rng.randf_range(-40.0, 40.0)
			var root := plateau_point(cid, 56.0, z)
			var prev := root
			var r := 3.2
			for j in 9:
				var t := float(j + 1) / 9.0
				var p := root + Vector3(-s * t * 16.0, sin(t * PI * 0.8) * 16.0 + t * 2.0, rng.randf_range(-0.5, 0.5))
				MeshKit.add_limb(st, prev, p, r * (1.0 - t * 0.85), (dark[k % dark.size()] as Color).lerp(Color("#8A4A32"), t * 0.4), 7)
				prev = p
	return MeshKit.finish(st)


## The bleached remains of enormous bugs half sunk into the ridges: a curving
## spine, a ribcage, a horned skull with mandibles. Warning signs, basically.
func _carcasses() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7272
	var st := MeshKit.begin()
	var bone := Palette.BONE.darkened(0.08)
	for spec: Array in [[0, 47.0, 12.0], [1, 48.0, -14.0], [0, 30.0, -50.0]]:
		var cid: int = spec[0]
		var s := WorldLayout.side_sign(cid)
		var base := plateau_point(cid, spec[1], spec[2]) + Vector3(0, -2.0, 0)
		var along := Vector3(0, 0, 1)
		# Spine: a row of vertebrae curving along the slope.
		var spine: Array[Vector3] = []
		for i in 12:
			var t := float(i) / 11.0
			var p := base + along * (t * 22.0 - 11.0) + Vector3(-s * sin(t * PI) * 2.0, sin(t * PI) * 5.0, 0)
			spine.append(p)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), p), Vector3(1.0, 0.8, 0.9), 4, 8, bone.darkened(rng.randf() * 0.1), 0.15, rng)
		# Ribs: big arcs over the spine.
		for i in range(2, 10):
			var p := spine[i]
			for side: float in [-1.0, 1.0]:
				var prev := p
				for j in 6:
					var t := float(j + 1) / 6.0
					var q := p + Vector3(side * sin(t * PI * 0.9) * 6.0, sin(t * PI * 0.6) * 7.0 - t * t * 4.0, 0)
					MeshKit.add_limb(st, prev, q, 0.45 * (1.0 - t * 0.6), bone, 5)
					prev = q
		# Skull with two horns and open mandibles.
		var head := spine[11] + along * 4.0 + Vector3(0, 1.0, 0)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), head), Vector3(4.0, 3.0, 4.5), 5, 10, bone, 0.15, rng)
		for side: float in [-1.0, 1.0]:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), head + Vector3(side * 1.8, 0.6, 3.6)), Vector3(0.9, 0.9, 0.5), 3, 8, Palette.OUTLINE)
			var m0 := head + Vector3(side * 1.4, -1.6, 3.8)
			MeshKit.add_limb(st, m0, m0 + Vector3(side * 3.0, -0.6, 3.5), 0.6, bone.darkened(0.1), 6)
			MeshKit.add_limb(st, m0 + Vector3(side * 3.0, -0.6, 3.5), m0 + Vector3(side * 1.0, -0.8, 6.5), 0.35, bone.darkened(0.15), 6)
			var h0 := head + Vector3(side * 1.6, 2.4, 1.0)
			MeshKit.add_limb(st, h0, h0 + Vector3(side * 2.5, 6.0, -1.5), 0.7, bone, 6)
	return MeshKit.finish(st)


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

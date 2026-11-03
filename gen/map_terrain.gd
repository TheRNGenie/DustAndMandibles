class_name MapTerrain
extends RefCounted
## Terrain for the maps other than the canyon (the canyon is CliffBuilder.build):
##   Three-Cliff Mesa: three plateaus round a sunken basin, rock walls between
##     them with bug tunnels in their feet, high desert all round.
##   Pinwheel Buttes: four lone buttes round a cracked dry lake. Every butte has
##     the same V-shaped climbing face and the same height; their outer walls,
##     colours and a landmark each tell them apart (red sandstone ledges and a
##     toppled windmill, pale layers and a natural arch, dark basalt columns and
##     a mine, striped ochre buttresses and an old water tower).
## Cliff faces and plateaus come from the CliffBuilder queries (so bugs, build
## grids and collisions all agree); this only adds what sits between them.

var cb: CliffBuilder
var map: MapDef

## Buttes: how far back from the lip the butte top runs, and how far either side.
const BUTTE_BACK := 46.0
## Width of the butte's falling edge (metres from the rim to the lakebed).
const BUTTE_EDGE := 8.0
## Mesa: plateau mesh depth behind the lip.
const MESA_DEPTH := 64.0
## Lakebed / basin floor collision reaches this far from the middle.
const FLOOR_HALF := 150.0
## The dry lake's edge (where the pale lakebed meets the desert).
const LAKE_R := 118.0


func _init(builder: CliffBuilder) -> void:
	cb = builder
	map = builder.map


# ------------------------------------------------------------------ height queries

## Floor height (basin or lakebed) at a world position.
static func floor_at(b: CliffBuilder, x: float, z: float) -> float:
	var n := b._floor_noise
	var r := Vector2(x - b.map.center.x, z - b.map.center.z).length()
	if b.map.id == MapDef.BUTTES:
		# Dead-flat lakebed; the desert past the buttes swells a little.
		return n.get_noise_2d(x * 0.5, z * 0.5) * 0.05 + smoothstep(80.0, 300.0, r) * (6.0 + 5.0 * n.get_noise_2d(x * 0.02, z * 0.02))
	# Mesa basin: packed dirt in a shallow dish.
	return n.get_noise_2d(x, z) * 0.35 - 1.0 * (1.0 - smoothstep(0.0, 30.0, r))


## A butte's ground height at plateau coordinates (d back from the lip, z along it).
## The flat top is the same on all four; only the falling edge differs per butte.
static func butte_height(b: CliffBuilder, cid: int, d: float, z: float) -> float:
	var n := b._noise[0]
	var flat := n.get_noise_2d(d * 0.08, z * 0.08) * 0.35 * smoothstep(0.0, 3.0, d)
	# Rocky rim outside the fences.
	var outside := minf(maxf(d - 31.0, 0.0) + maxf(absf(z) - 21.5, 0.0), 4.0)
	var rim := (n.get_noise_2d(d * 0.15 + 200.0, z * 0.15) * 0.5 + 0.5) * outside * 0.7
	var top := WorldLayout.CLIFF_HEIGHT + flat + rim
	var side := b.map.span_v
	var edge := minf(side - absf(z), BUTTE_BACK - d)
	var keep := _edge_profile(b.map.cliffs[cid].style, edge, n.get_noise_2d(d * 0.3 + 40.0, z * 0.3))
	if keep >= 1.0:
		return top
	var p := b.map.to_world(cid, b.map.prow_u(cid, z) - d, z)
	return lerpf(floor_at(b, p.x, p.z) - 0.6, top, keep)


## 0 at the butte's foot, 1 on its top, for `edge` metres in from the outer rim.
static func _edge_profile(style: StringName, edge: float, wobble: float) -> float:
	var t := clampf((edge + wobble * 0.8) / BUTTE_EDGE, 0.0, 1.0)
	match style:
		&"ledges":
			# Deep flat ledges with short risers between them.
			var k := t * 3.0
			return minf((floorf(k) + smoothstep(0.55, 1.0, k - floorf(k))) / 3.0, 1.0)
		&"layers":
			return pow(t, 0.55)
		&"basalt":
			return smoothstep(0.0, 0.35, t)
		_:
			return smoothstep(0.0, 1.0, t)


# ------------------------------------------------------------------ build

func build(parent: Node3D) -> void:
	match map.id:
		MapDef.MESA:
			_build_mesa(parent)
		MapDef.BUTTES:
			_build_buttes(parent)


## Rock material for a cliff: the canyon strata in that cliff's colours.
func rock_material(cid: int) -> ShaderMaterial:
	var c := map.cliffs[cid]
	var key := "map_rock_%s_%s" % [c.style, c.rock.to_html()]
	if Materials._cache.has(key):
		return Materials._cache[key]
	var mat := Materials.strata(c.rock).duplicate() as ShaderMaterial
	var bands: Array = []
	var band_h := 2.6
	match c.style:
		&"ledges":
			bands = ["#B8452C", "#8E3424", "#C9603A", "#B04E34", "#6E2A22", "#C9603A", "#E0A27A"]
			band_h = 3.2
		&"layers":
			bands = ["#F6EBD8", "#E6D2B0", "#FFF8EA", "#D9C09A", "#F0E0C4", "#CDB490", "#FFFFFF"]
			mat.set_shader_parameter("varnish", Color("#8A7058"))
			band_h = 1.3
		&"basalt":
			bands = ["#4A474A", "#3A383C", "#5A5658", "#454246", "#2E2C30", "#555052", "#6A625C"]
			band_h = 7.0
			mat.set_shader_parameter("varnish", Color("#1E1C20"))
			mat.set_shader_parameter("scrub_color", Color("#7A7058"))
		&"buttress":
			bands = ["#D99A3E", "#B8742A", "#E8B860", "#C88438", "#9E5E22", "#E8B860", "#F0C878"]
			band_h = 1.9
	if not bands.is_empty():
		var names := ["band_a", "band_b", "band_c", "band_f", "band_e", "band_c", "band_d"]
		for i in names.size():
			mat.set_shader_parameter(names[i], Color(bands[i]))
		mat.set_shader_parameter("band_height", band_h)
	Materials._cache[key] = mat
	return mat


func _floor_mesh(half: float, step: float) -> ArrayMesh:
	var grid: Array = []
	var x := -half
	var zs := CliffBuilder._zs(Vector2(-half, half), step)
	while x <= half + 0.001:
		var row: Array[Vector3] = []
		for z: float in zs:
			row.append(Vector3(x, floor_at(cb, x, z), z))
		grid.append(row)
		x += step
	return cb._grid_mesh(grid, Vector3.UP)


## A polar ring of ground from radius r0 out to r1 (visual only), height from `h`.
func _ring_mesh(r0: float, r1: float, h: Callable, first_step: float = 6.0) -> ArrayMesh:
	var rs: Array[float] = []
	var step := first_step
	var r := r0
	while r < r1:
		rs.append(r)
		r += step
		step = minf(step * 1.12, 90.0)
	rs.append(r1)
	var grid: Array = []
	for rr in rs:
		var row: Array[Vector3] = []
		for i in 97:
			var a := TAU * float(i) / 96.0
			var x := map.center.x + cos(a) * rr
			var z := map.center.z + sin(a) * rr
			row.append(Vector3(x, float(h.call(x, z, rr)), z))
		grid.append(row)
	return cb._grid_mesh(grid, Vector3.UP)


## Distant mesas, buttes and a ring of mountains at the horizon (visual only).
func _far_scenery(parent: Node3D, ground: Callable, keep_clear: float, rock: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var st := MeshKit.begin()
	var cols := [Palette.ROCK_A, Palette.ROCK_B, Palette.ROCK_C, Color("#B85A3A"), Color("#D99A62")]
	var placed := 0
	var hinter := CliffBuilder.HINTER
	while placed < 60:
		var x := rng.randf_range(-hinter * 0.85, hinter * 0.85)
		var z := rng.randf_range(-hinter * 0.85, hinter * 0.85)
		if Vector2(x, z).length() < keep_clear:
			continue
		placed += 1
		var base := Vector3(x, float(ground.call(x, z, Vector2(x, z).length())) - 3.0, z)
		var butte := rng.randf() < 0.4
		var r := rng.randf_range(10.0, 22.0) if butte else rng.randf_range(30.0, 90.0)
		var h := rng.randf_range(35.0, 90.0) if butte else rng.randf_range(20.0, 55.0)
		var col: Color = cols[rng.randi() % cols.size()]
		var segs := rng.randi_range(7, 11)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), base + Vector3(0, h * 0.12, 0)), r * 1.45, r * 1.05, h * 0.25, segs, col.darkened(0.1))
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), base + Vector3(0, h * 0.6, 0)), r * 1.05, r * 0.92, h * 0.8, segs, col)
	for i in 34:
		var a := TAU * float(i) / 34.0 + rng.randf_range(-0.05, 0.05)
		var dist := rng.randf_range(hinter * 0.88, hinter * 0.98)
		var x := cos(a) * dist
		var z := sin(a) * dist
		var base := Vector3(x, float(ground.call(x, z, dist)) - 20.0, z)
		var h := rng.randf_range(160.0, 360.0)
		var r := rng.randf_range(160.0, 300.0)
		var top := r * rng.randf_range(0.05, 0.25)
		var segs := rng.randi_range(5, 8)
		if map.id == MapDef.BUTTES:
			# Seen from low down: broad flat-topped mesas rather than peaks.
			h *= 0.45
			top = r * rng.randf_range(0.45, 0.7)
			segs += 4
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), base + Vector3(0, h * 0.5, 0)), r, top, h, segs, Color("#C98A5E").darkened(rng.randf_range(0.0, 0.25)))
	var far := MeshInstance3D.new()
	far.name = "Mesas"
	far.mesh = MeshKit.finish(st)
	far.material_override = rock
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(far)


func _add_visual(parent: Node3D, node_name: String, mesh: ArrayMesh, mat: Material, shadows: bool = true) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ------------------------------------------------------------------ Three-Cliff Mesa

func _build_mesa(parent: Node3D) -> void:
	var span := Vector2(-map.span_v, map.span_v)
	var floor_mat := Materials.strata(Color("#D9A35E"))
	for cid in map.count():
		var rock := rock_material(cid)
		cb._add_static(parent, "Plateau%d" % cid, cb._build_plateau(cid, span, CliffBuilder.PLATEAU_Z_STEP, CliffBuilder.PLATEAU_D_STEP, MESA_DEPTH), rock)
		cb._add_static(parent, "CliffFace%d" % cid, cb._build_face(cid, span, CliffBuilder.FACE_Z_STEP, CliffBuilder.FACE_Y_STEP), rock)
	cb._add_static(parent, "BasinFloor", _floor_mesh(58.0, 1.5), floor_mat)
	var wall_rock := Materials.strata(Palette.SAND)
	for i in map.count():
		cb._add_static(parent, "BasinWall%d" % i, _mesa_wall(i), wall_rock)
	_add_visual(parent, "BugTunnels", cb._bug_tunnels(), Materials.toon(0.03))
	# High desert all round, level with the walls behind the homesteads.
	var hills := FastNoiseLite.new()
	hills.seed = 777
	hills.frequency = 0.004
	hills.fractal_octaves = 3
	var top := WorldLayout.CLIFF_HEIGHT
	var land := func(x: float, z: float, r: float) -> float:
		return lerpf(top + 30.0, top + 40.0 + hills.get_noise_2d(x, z) * 16.0, smoothstep(90.0, 220.0, r))
	_add_visual(parent, "Hinterland", _ring_mesh(84.0, CliffBuilder.HINTER, land), wall_rock, false)
	_far_scenery(parent, land, 300.0, wall_rock)


## The rock wall between mesa cliff i and the next one round: a ridge that
## rises from the basin floor (a near-sheer wall with tunnels in its foot) and
## fills the wedge between the two plateaus, higher than both.
func _mesa_wall(i: int) -> ArrayMesh:
	var a := i
	var b := (i + 1) % map.count()
	var ca := map.cliffs[a]
	var cbl := map.cliffs[b]
	var side_a := signf((cbl.origin - ca.origin).dot(ca.along))
	var side_b := signf((ca.origin - cbl.origin).dot(cbl.along))
	var va := side_a * (map.span_v - 2.0)
	var vb := side_b * (map.span_v - 2.0)
	var n := cb._noise[3]
	var c := map.center
	var rs: Array[float] = [-4.5, -3.4, -2.9, -2.4, -1.9, -1.4, -0.9, -0.4, 0.3, 1.2, 2.5, 4.0, 6.0, 9.0, 13.0, 18.0, 24.0, 31.0, 40.0, 50.0, 62.0]
	var grid: Array = []
	var top := WorldLayout.CLIFF_HEIGHT
	for r in rs:
		var pa := map.to_world(a, -r, va)
		var pb := map.to_world(b, -r, vb)
		var a0 := atan2(pa.z - c.z, pa.x - c.x)
		var a1 := atan2(pb.z - c.z, pb.x - c.x)
		var da := wrapf(a1 - a0, -PI, PI)
		var r0 := Vector2(pa.x - c.x, pa.z - c.z).length()
		var r1 := Vector2(pb.x - c.x, pb.z - c.z).length()
		var row: Array[Vector3] = []
		for k in 29:
			var s := lerpf(-0.14, 1.14, float(k) / 28.0)
			var ang := a0 + da * s
			var rad := lerpf(r0, r1, s)
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			var p := c + dir * rad
			var wob := n.get_noise_2d(ang * 40.0, r * 0.3)
			# A little in-and-out on the wall so it never reads as a sheet.
			p += dir * wob * 1.4 * (1.0 - smoothstep(0.0, 4.0, r))
			var crest := pow(sin(clampf(s, 0.0, 1.0) * PI), 0.6) * (22.0 + 10.0 * n.get_noise_2d(s * 6.0, 9.0)) + r * 0.25
			var rise := smoothstep(-0.13, 0.06, s) * smoothstep(1.13, 0.94, s)
			var peak := lerpf(top - 3.0, top + 3.0 + crest + wob * 3.0, rise)
			var face := smoothstep(-3.6, -0.3, r)
			var fy := floor_at(cb, p.x, p.z) - 0.4
			p.y = lerpf(fy, peak, face)
			row.append(p)
		grid.append(row)
	var mid_dir := (map.to_world(a, 0.0, va) + map.to_world(b, 0.0, vb)) * 0.5 - c
	mid_dir.y = 0.0
	return cb._grid_mesh(grid, (Vector3.UP - mid_dir.normalized()).normalized())


# ------------------------------------------------------------------ Pinwheel Buttes

func _build_buttes(parent: Node3D) -> void:
	var span := Vector2(-map.span_v, map.span_v)
	var lake_mat := _lake_material()
	# A round lakebed (collidable), the open desert beyond it.
	var lake := func(x: float, z: float, _r: float) -> float: return floor_at(cb, x, z)
	cb._add_static(parent, "Lakebed", _ring_mesh(0.3, LAKE_R, lake, 4.0), lake_mat)
	for cid in map.count():
		var rock := rock_material(cid)
		cb._add_static(parent, "Plateau%d" % cid, cb._build_plateau(cid, span, 1.0, 1.0, BUTTE_BACK + 0.5), rock)
		cb._add_static(parent, "CliffFace%d" % cid, cb._build_face(cid, span, CliffBuilder.FACE_Z_STEP, CliffBuilder.FACE_Y_STEP), rock)
		_butte_dressing(parent, cid, rock)
	_add_visual(parent, "LakeCracks", _cracks(), Materials.toon(0.0), false)
	_add_visual(parent, "BugFissures", _fissures(), Materials.toon(0.02))
	var desert := func(x: float, z: float, _r: float) -> float: return floor_at(cb, x, z) - 0.05
	_add_visual(parent, "Desert", _ring_mesh(LAKE_R, CliffBuilder.HINTER, desert), Materials.strata(Color("#D9A35E")), false)
	_far_scenery(parent, desert, 260.0, Materials.strata(Palette.SAND))


func _lake_material() -> ShaderMaterial:
	var mat := Materials.strata(Color("#E6CFA6")).duplicate() as ShaderMaterial
	mat.set_shader_parameter("scrub_color", Color("#CDB28A"))
	return mat


## Mud cracks across the lakebed: thin dark seams in a rough polygon net.
func _cracks() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	var st := MeshKit.begin()
	var col := MeshKit.vcol(Color("#8A6E50"))
	for i in 520:
		var p := Vector3(rng.randf_range(-95.0, 95.0), 0.0, rng.randf_range(-95.0, 95.0))
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var seg_len := rng.randf_range(1.5, 4.5)
		for k in rng.randi_range(2, 4):
			dir = dir.rotated(rng.randf_range(-0.6, 0.6))
			var q := p + Vector3(dir.x, 0.0, dir.y) * seg_len
			_seam(st, p, q, rng.randf_range(0.05, 0.12), col)
			p = q
	return MeshKit.finish(st)


func _seam(st: SurfaceTool, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var dir := b - a
	dir.y = 0.0
	var side := Vector3(-dir.z, 0.0, dir.x).normalized() * w
	var ya := floor_at(cb, a.x, a.z) + 0.04
	var yb := floor_at(cb, b.x, b.z) + 0.04
	var pa := Vector3(a.x, ya, a.z)
	var pb := Vector3(b.x, yb, b.z)
	MeshKit.quad(st, pa - side, pb - side, pb + side, pa + side, Vector3.UP, col)


## The fissures bugs crawl out of: long dark rifts in the lakebed with broken,
## heaved-up lips of dried mud along both sides.
func _fissures() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var st := MeshKit.begin()
	var lip_cols := [Color("#B89870"), Color("#A88660"), Color("#C9A87E")]
	for i in map.tunnels.size():
		var t: Array = cb.tunnel(i)
		var m: Vector3 = t[0]
		var along: Vector3 = t[1]
		var side := along.cross(Vector3.UP).normalized()
		var length := rng.randf_range(9.0, 12.0)
		# The dark rift: a jagged strip, widest in the middle.
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for k in 13:
			var u := float(k) / 12.0
			var w := sin(u * PI) * rng.randf_range(1.0, 1.5) + 0.05
			var c := m + along * (u - 0.5) * length + side * rng.randf_range(-0.25, 0.25)
			var l := c - side * w + Vector3(0, 0.05, 0)
			var r := c + side * w + Vector3(0, 0.05, 0)
			if k > 0:
				MeshKit.quad(st, prev_l, l, r, prev_r, Vector3.UP, MeshKit.vcol(Color("#120A08")))
			prev_l = l
			prev_r = r
		# Heaved-up slabs of mud along both lips.
		for k in 14:
			var u := rng.randf_range(0.05, 0.95)
			var sgn := -1.0 if k % 2 == 0 else 1.0
			var w := sin(u * PI) * 1.4 + 0.4
			var at := m + along * (u - 0.5) * length + side * sgn * w
			var tilt := Basis(along, sgn * rng.randf_range(0.25, 0.6))
			MeshKit.add_box(st, Transform3D(tilt, at + Vector3(0, 0.15, 0)), Vector3(rng.randf_range(0.9, 1.8), 0.28, rng.randf_range(0.9, 1.6)) * Vector3(1, 1, 1),
					lip_cols[rng.randi() % lip_cols.size()], 0.08, rng)
		# Dust-pale scatter round it.
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, atan2(along.x, along.z)), m + Vector3(0, 0.01, 0)), Vector3(3.2, 0.03, length * 0.6), 3, 12, Color("#D8C09A"))
	return MeshKit.finish(st)


## What makes each butte look like itself, on its outer walls and its top
## (never on the climbing face or the build area).
func _butte_dressing(parent: Node3D, cid: int, rock: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6100 + cid * 17
	var st := MeshKit.begin()
	var props := MeshKit.begin()
	var c := map.cliffs[cid]
	match c.style:
		&"ledges":
			# Deep sandstone shelves jutting from the outer walls.
			for k in 26:
				var p := _rim_point(cid, rng, 2.0)
				var y := rng.randf_range(12.0, 50.0)
				var out := _rim_out(cid, p)
				var at := Vector3(p.x, y, p.z) + out * 1.5
				var basis := Basis(Vector3.UP, atan2(out.x, out.z))
				MeshKit.add_box(st, Transform3D(basis, at), Vector3(rng.randf_range(6.0, 12.0), rng.randf_range(1.2, 2.2), rng.randf_range(3.0, 5.5)), Color.WHITE, 0.4, rng)
			# A toppled windmill lying on the rim behind the fence.
			var base := cb.plateau_point(cid, 37.0, 9.0)
			var fallen := Basis(Vector3.UP, map.facing_yaw(cid) + 0.6) * Basis(Vector3.BACK, PI * 0.5 - 0.12)
			_add_prop(parent, BuildingBuilder.windmill_tower(900 + cid), Transform3D(fallen, base + Vector3(0, 1.0, 0)), "ToppledWindmill")
			var fan := BuildingBuilder.windmill_fan()
			_add_prop(parent, fan, Transform3D(Basis(Vector3.RIGHT, -1.35) * Basis(Vector3.UP, 0.4), cb.plateau_point(cid, 37.5, 17.5) + Vector3(0, 0.25, 0)), "FallenFan")
		&"layers":
			# Thin pale lips where hard layers stand proud of the walls.
			for k in 60:
				var p := _rim_point(cid, rng, 0.6)
				var out := _rim_out(cid, p)
				var y := floorf(rng.randf_range(4.0, 56.0) / 4.0) * 4.0 + 0.5
				var basis := Basis(Vector3.UP, atan2(out.x, out.z))
				MeshKit.add_box(st, Transform3D(basis, Vector3(p.x, y, p.z) + out * 0.6), Vector3(rng.randf_range(5.0, 10.0), 0.5, 1.6), Color.WHITE, 0.2, rng)
			# A natural arch off the right-hand edge: one foot against the butte's
			# side, the other out on the lakebed.
			var foot_a := map.to_world(cid, map.prow_u(cid, map.span_v) - 6.0, map.span_v + 1.5)
			var foot_b := foot_a + c.along * 22.0 + c.inward * 6.0
			foot_a.y = floor_at(cb, foot_a.x, foot_a.z) - 1.0
			foot_b.y = floor_at(cb, foot_b.x, foot_b.z) - 1.0
			var arch := MeshKit.begin()
			ArchBuilder.arch(arch, rng, foot_a, foot_b, 44.0, 6.0, 2.8)
			cb._add_static(parent, "NaturalArch%d" % cid, MeshKit.finish(arch), rock)
			# The arch's far foot stands on a little pillar of the same pale rock.
			MeshKit.add_cylinder(st, Transform3D(Basis(), foot_b + Vector3(0, 6.0, 0)), 5.5, 4.2, 12.0, 9, Color.WHITE)
		&"basalt":
			# Organ-pipe columns: tight clusters of hexagonal pillars against the walls.
			for k in 70:
				var p := _rim_point(cid, rng, -1.5)
				var out := _rim_out(cid, p)
				var h := rng.randf_range(30.0, 62.0)
				var r := rng.randf_range(0.9, 1.6)
				var at := Vector3(p.x, floor_at(cb, p.x, p.z) + h * 0.5 - 1.0, p.z) + out * rng.randf_range(0.0, 2.5)
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), r, r * 0.95, h, 6, Color.WHITE)
			# A mine dug into a rock knoll behind the fence: timber portal over a black hole.
			var knoll := cb.plateau_point(cid, 37.5, -12.0)
			var yaw := map.facing_yaw(cid) + PI
			var b := Basis(Vector3.UP, yaw)
			MeshKit.add_ellipsoid(st, Transform3D(b, knoll + Vector3(0, 1.0, 1.8)), Vector3(6.0, 4.8, 4.5), 5, 10, Color.WHITE, 0.3, rng)
			var front := knoll + b * Vector3(0, 0, -2.2)
			MeshKit.add_box(props, Transform3D(b, front + Vector3(0, 1.5, -0.1)), Vector3(2.6, 3.0, 0.4), Color("#0E0A08"))
			for sx: float in [-1.0, 1.0]:
				MeshKit.add_box(props, Transform3D(b, front + b * Vector3(sx * 1.45, 1.6, -0.35)), Vector3(0.35, 3.3, 0.35), Palette.WOOD_DARK, 0.03, rng)
			MeshKit.add_box(props, Transform3D(b, front + b * Vector3(0, 3.3, -0.35)), Vector3(3.6, 0.4, 0.45), Palette.WOOD_DARK, 0.03, rng)
			MeshKit.add_box(props, Transform3D(b, front + b * Vector3(0, 3.75, -0.5)), Vector3(1.8, 0.45, 0.08), Palette.WOOD)
			# Rails out of the mouth and a tipped-over ore cart.
			for k in 6:
				var t := front + b * Vector3(0, 0.08, -0.8 - k * 1.1)
				MeshKit.add_box(props, Transform3D(b, t), Vector3(1.4, 0.1, 0.18), Palette.WOOD_DARK)
			for sx: float in [-0.5, 0.5]:
				MeshKit.add_box(props, Transform3D(b, front + b * Vector3(sx, 0.16, -3.6)), Vector3(0.08, 0.08, 6.6), Palette.METAL)
			MeshKit.add_box(props, Transform3D(b * Basis(Vector3.BACK, 1.2), front + b * Vector3(1.6, 0.6, -6.5)), Vector3(1.2, 0.9, 1.6), Palette.METAL.darkened(0.3), 0.03, rng)
		&"buttress":
			# Buttresses: big stepped fins of rock braced against the outer walls.
			for k in 16:
				var p := _rim_point(cid, rng, -0.5)
				var out := _rim_out(cid, p)
				var basis := Basis(Vector3.UP, atan2(out.x, out.z))
				var fy := floor_at(cb, p.x, p.z)
				for tier in 3:
					var h := 54.0 - tier * 16.0
					var depth := 4.0 + tier * 3.5
					MeshKit.add_box(st, Transform3D(basis, Vector3(p.x, fy + h * 0.5 - 1.0, p.z) + out * (depth * 0.5)), Vector3(rng.randf_range(3.0, 4.5), h, depth), Color.WHITE, 0.5, rng)
			# An old water tower leaning on the rim behind the fence.
			var at := cb.plateau_point(cid, 38.0, 12.0)
			var lean := Basis(Vector3.UP, map.facing_yaw(cid)) * Basis(Vector3.BACK, 0.16)
			_add_prop(parent, BuildingBuilder.water_tower(990 + cid), Transform3D(lean, at), "OldWaterTower")
	_add_visual(parent, "ButteRock%d" % cid, MeshKit.finish(st), rock)
	var pm := MeshKit.finish(props)
	if pm.get_surface_count() > 0:
		_add_visual(parent, "ButteProps%d" % cid, pm, Materials.toon(0.03))


func _add_prop(parent: Node3D, mesh: ArrayMesh, xf: Transform3D, node_name: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = Materials.toon(0.03)
	mi.transform = xf
	parent.add_child(mi)


## A random point (y 0) round a butte's outer walls (sides and back, never the
## climbing face), `out` metres outside the top's edge.
func _rim_point(cid: int, rng: RandomNumberGenerator, out: float) -> Vector3:
	var side := map.span_v
	var span_back := 2.0 * side
	var span_side := BUTTE_BACK - 8.0
	var pick := rng.randf() * (span_back + 2.0 * span_side)
	var d: float
	var z: float
	if pick < span_back:
		d = BUTTE_BACK - BUTTE_EDGE * 0.5 + out
		z = pick - side
	else:
		pick -= span_back
		var sgn := -1.0 if pick < span_side else 1.0
		d = 8.0 + fmod(pick, span_side)
		z = sgn * (side - BUTTE_EDGE * 0.5 + out)
	return map.to_world(cid, map.prow_u(cid, z) - d, z)


## The outward direction (away from the butte) at a rim point.
func _rim_out(cid: int, p: Vector3) -> Vector3:
	var uv := map.local_uv(cid, p)
	var d := map.prow_u(cid, uv.y) - uv.x
	var c := map.cliffs[cid]
	if BUTTE_BACK - d < map.span_v - absf(uv.y):
		return -c.inward
	return c.along * signf(uv.y)

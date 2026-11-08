class_name FarLands
extends RefCounted
## The land past every map's own ground, out to the horizon (Logan: "a cohesive
## and visually interesting terrain ... inspired by badlands terrain in real life,
## as well as giant rolling sand dunes, and other hot, dry, post apocalyptic
## imagery", as far as the player can see, up to 2 km).
##
## One field laid over each map's own ground (the canyon's badlands, the mesa's
## rolling desert, the buttes' flats), taking over a couple of hundred metres
## past it:
##   - dune seas: great transverse dunes (gentle windward backs, sharp crests,
##     steep slip faces) with smaller dunes crossing them, piled in some
##     directions and not others, burying the badlands where they roll in;
##   - salt pans: flat white lakebeds in the lows;
##   - an escarpment: a broken, terraced wall of mesas 1.5-1.8 km out that closes
##     the horizon, with gaps where the land runs on into the haze.
## The landmarks (colossal bug skeletons, derelicts) are ColossusBuilder's.
## field() gives the rise and the paint masks; the maps add the rise to their own
## height and paint with BadlandsTerrain's ground shader.

## Where the field reaches (and the far ground pieces stop).
const REACH := 2100.0
## The escarpment: its mean distance from the middle, and how much it wanders.
const ESCARP_R := 1640.0
const ESCARP_WANDER := 170.0
## The prevailing wind (the dunes' crests lie across it; their slip faces lee).
const WIND := Vector2(0.88, 0.47)

var center := Vector2.ZERO
## (x, z) -> metres out past the map's own ground (0 or less inside it).
var out_of: Callable

var _region := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _size := FastNoiseLite.new()
var _pan := FastNoiseLite.new()
var _escarp := FastNoiseLite.new()
var _gap := FastNoiseLite.new()
var _fine := FastNoiseLite.new()


func _init(seed_value: int, center_xz: Vector2, distance_out: Callable) -> void:
	center = center_xz
	out_of = distance_out
	var noises: Array[FastNoiseLite] = [_region, _warp, _size, _pan, _escarp, _gap, _fine]
	var freqs: Array[float] = [0.0011, 0.0024, 0.0016, 0.0019, 1.3, 2.1, 0.012]
	var octs: Array[int] = [2, 3, 2, 2, 3, 2, 3]
	for i in noises.size():
		noises[i].seed = seed_value + 101 * i
		noises[i].frequency = freqs[i]
		noises[i].fractal_octaves = octs[i]


## At (x, z): (rise above the map's own ground, sand 0-1, salt 0-1, bury 0-1).
## `bury`: how much of the map's own relief the field flattens (dunes and pans
## lie over it).
func field(x: float, z: float) -> Vector4:
	var d: float = out_of.call(x, z)
	if d <= 0.0:
		return Vector4.ZERO
	var rel := Vector2(x, z) - center
	var r := rel.length()
	var esc := escarpment(rel, r)
	var under_wall := smoothstep(ESCARP_R - ESCARP_WANDER - 260.0, ESCARP_R - ESCARP_WANDER - 60.0, r)
	# Dune seas: piled up in some directions, starting a few hundred metres out.
	var reg := _region.get_noise_2d(x, z)
	var sea := smoothstep(-0.12, 0.2, reg) * smoothstep(160.0, 520.0, d) * (1.0 - under_wall * 0.85)
	var dune := dunes(x, z) * sea
	# Salt pans in the lows where there's no sand.
	var pan := smoothstep(0.32, 0.5, _pan.get_noise_2d(x, z)) * (1.0 - smoothstep(0.0, 0.3, sea)) * smoothstep(260.0, 480.0, d) * (1.0 - under_wall)
	var rise := dune - pan * 6.0 + esc + _fine.get_noise_2d(x, z) * 1.5 * (1.0 - pan)
	var come := smoothstep(0.0, 200.0, d)
	return Vector4(rise * come, sea * come, pan * come, maxf(sea, pan) * come)


## The dunes' height (0 in the troughs) at (x, z), before the sea weight.
func dunes(x: float, z: float) -> float:
	var w := WIND.normalized()
	var u := x * w.x + z * w.y
	var v := -x * w.y + z * w.x
	var lam := 230.0 + 80.0 * _size.get_noise_2d(x, z)
	var ph := (u + _warp.get_noise_2d(x, z) * 170.0 + 40.0 * sin(v / 300.0)) / lam
	var s := ph - floorf(ph)
	# Long gentle windward back, then a short steep slip face over a sharp brink.
	var prof := s / 0.74 if s < 0.74 else (1.0 - s) / 0.26
	prof = prof * prof * (3.0 - 2.0 * prof)
	# A smaller set of dunes crossing the first: linked crests and star peaks.
	var u2 := x * 0.32 + z * -0.95
	var ph2 := (u2 + _warp.get_noise_2d(z + 700.0, x) * 90.0) / (lam * 0.45)
	var s2 := ph2 - floorf(ph2)
	var prof2 := s2 / 0.7 if s2 < 0.7 else (1.0 - s2) / 0.3
	prof2 = prof2 * prof2 * (3.0 - 2.0 * prof2)
	var amp := 20.0 + 26.0 * (_size.get_noise_2d(x * 0.6 + 400.0, z * 0.6) * 0.5 + 0.5)
	return amp * prof + amp * 0.28 * prof2 * prof


## The escarpment's rise at (rel, r) from the middle: a terraced wall of mesas
## rising over ~70 m to 120-240 m, the plateau top behind it, broken by gaps.
func escarpment(rel: Vector2, r: float) -> float:
	var dir := rel / maxf(r, 1.0)
	var at := ESCARP_R + ESCARP_WANDER * _escarp.get_noise_2d(dir.x, dir.y)
	var gap := smoothstep(-0.32, -0.12, _gap.get_noise_2d(dir.x, dir.y)) # 0 in a gap
	var height := 120.0 + 120.0 * (_escarp.get_noise_2d(dir.x * 3.0 + 9.0, dir.y * 3.0) * 0.5 + 0.5)
	var k := smoothstep(at - 70.0, at, r)
	# Three harder layers stand out as ledges up the face.
	var t := k * 3.0
	var terr := (floorf(t) + smoothstep(0.62, 1.0, t - floorf(t))) / 3.0
	return height * lerpf(k, terr, 0.75) * gap


## How far out the escarpment's foot stands in direction `dir` (unit, from the middle).
func escarp_r(dir: Vector2) -> float:
	return ESCARP_R + ESCARP_WANDER * _escarp.get_noise_2d(dir.x, dir.y)


## Vertex colour for the ground shader (masks on): (wash, mesa top, caliche,
## 1 - sand); the far field adds sand and salt to the map's own masks.
static func mask(own: Color, f: Vector4) -> Color:
	var keep := 1.0 - f.w
	return Color(own.r * keep, own.g * keep, maxf(own.b * keep, f.z), 1.0 - f.y)


## A polar ring of ground through the radii `rs` (round `center`), `cols` steps
## round: height from `ground` ((x, z, r) -> height, the field already in it),
## the paint masks from the field. Visual only. Shares CliffBuilder's grid builder.
func ring(cb: CliffBuilder, rs: Array[float], cols: int, ground: Callable) -> ArrayMesh:
	var grid: Array = []
	var colors := PackedColorArray()
	for rr in rs:
		var row: Array[Vector3] = []
		for i in cols + 1:
			var a := TAU * float(i) / float(cols)
			var x := center.x + cos(a) * rr
			var z := center.y + sin(a) * rr
			row.append(Vector3(x, float(ground.call(x, z, rr)), z))
			colors.append(mask(Color(0, 0, 0, 1), field(x, z)))
		grid.append(row)
	return cb._grid_mesh(grid, Vector3.UP, colors)


## The ground material for a map's far rings (BadlandsTerrain's shader, painting
## the dunes and salt), with its sand-drift and crest heights at `base_y`.
static func material(base_y: float) -> ShaderMaterial:
	var mat := BadlandsTerrain.material(true)
	mat.set_shader_parameter("base_y", base_y)
	return mat


## A far mesa or butte at `base` (radius r, height h): a talus apron, the body in
## tiers that twist and narrow with a harder ledge at each step, an overhanging
## caprock, an irregular plan (squashed and turned), and fallen blocks round the
## foot. Buttes are narrow stacks of grooved drums under a wide cap.
static func formation(st: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, r: float, h: float, col: Color, butte: bool) -> void:
	var yaw := Basis(Vector3.UP, rng.randf() * TAU)
	var b := yaw.scaled(Vector3(1.0, 1.0, rng.randf_range(0.6, 1.0)))
	var segs := rng.randi_range(9, 13)
	var shade := func(k: float) -> Color: return col.darkened(k).lerp(Color("#E8C9A0"), rng.randf() * 0.08)
	MeshKit.add_cylinder(st, Transform3D(b, base + Vector3(0, h * 0.07, 0)), r * (2.0 if butte else 1.5), r * 1.1, h * 0.14, segs, shade.call(0.12))
	var y := h * 0.14
	var rr := r * 1.05
	var tiers := rng.randi_range(4, 6) if butte else rng.randi_range(2, 4)
	for k in tiers:
		var th := h * (0.76 if butte else 0.72) / tiers
		var r1 := rr * (rng.randf_range(0.9, 1.0) if butte else rng.randf_range(0.84, 0.95))
		var turn := b.rotated(Vector3.UP, rng.randf_range(-0.25, 0.25))
		MeshKit.add_cylinder(st, Transform3D(turn, base + Vector3(rng.randf_range(-0.4, 0.4), y + th * 0.5, rng.randf_range(-0.4, 0.4))), rr, r1, th, segs, shade.call(0.0 if k % 2 == 0 else 0.1))
		if not butte:
			MeshKit.add_cylinder(st, Transform3D(b, base + Vector3(0, y + th, 0)), r1 * 1.05, r1 * 1.05, 1.0, segs, shade.call(0.22))
		y += th
		rr = r1 * 0.97
	# The caprock: darker, wider than the top of the body.
	MeshKit.add_cylinder(st, Transform3D(b, base + Vector3(0, y + h * 0.05, 0)), rr * (1.16 if butte else 1.07), rr * (1.1 if butte else 1.1), h * 0.1, segs, shade.call(0.3))
	# Fallen blocks round the foot.
	for i in rng.randi_range(4, 8):
		var a := rng.randf() * TAU
		var p := base + Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(1.4, 2.0)
		var s := r * rng.randf_range(0.08, 0.18)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p + Vector3(0, s * 0.3, 0)), Vector3(s * 1.2, s * 0.7, s), 3, 6, shade.call(0.15), 0.2, rng)


## Radii for a ring, finer near r0 and growing out to `cap` metres apart.
static func radii(r0: float, r1: float, first: float, cap: float) -> Array[float]:
	var rs: Array[float] = []
	var step := first
	var r := r0
	while r < r1:
		rs.append(r)
		r += step
		step = minf(step * 1.08, cap)
	rs.append(r1)
	return rs

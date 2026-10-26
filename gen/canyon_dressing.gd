class_name CanyonDressing
extends RefCounted
## Breaks up the canyon: rock shelves and jutting slabs on the walls (kept clear
## of the climbing lanes), fallen boulders piled at the foot of each wall,
## hoodoo spires, dead trees, bleached cattle skulls and dry-wash cracked mud on
## the floor, rolling tumbleweeds, and buttes and mesas on the horizon. All
## visual only (no collision), batched into a few meshes.

const LANE_CLEAR := 3.2


static func build(parent: Node3D, cliffs: CliffBuilder, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rock_st := MeshKit.begin()
	var dry_st := MeshKit.begin()
	for cid in 2:
		_wall_shelves(rock_st, rng, cliffs, cid)
		_wall_base(rock_st, rng, cliffs, cid)
	_floor(rock_st, dry_st, rng, cliffs)
	_horizon(rock_st, rng)
	_add(parent, "CanyonRocks", MeshKit.finish(rock_st), Materials.toon(0.03))
	_add(parent, "CanyonDryStuff", MeshKit.finish(dry_st), Materials.toon(0.015))
	for i in 7:
		var tw := Tumbleweed.new()
		tw.cliffs = cliffs
		tw.seed_value = seed_value + i
		parent.add_child(tw)


static func _add(parent: Node3D, node_name: String, mesh: ArrayMesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)


static func _in_lane(z: float) -> bool:
	for lz in WorldLayout.LANE_Z:
		if absf(z - lz) < LANE_CLEAR:
			return true
	return false


static func _rock_color(rng: RandomNumberGenerator) -> Color:
	var c: Color = [Palette.ROCK_A, Palette.ROCK_B, Palette.ROCK_C, Color("#B85A3A"), Color("#D99A62")][rng.randi() % 5]
	return c.darkened(rng.randf_range(0.0, 0.15))


## Flat sandstone shelves and jutting slabs stuck to the walls.
static func _wall_shelves(st: SurfaceTool, rng: RandomNumberGenerator, cliffs: CliffBuilder, cid: int) -> void:
	var placed := 0
	var tries := 0
	while placed < 46 and tries < 400:
		tries += 1
		var z := rng.randf_range(-170.0, 170.0)
		if absf(z) < WorldLayout.WORLD_HALF_Z and _in_lane(z):
			continue
		var y := rng.randf_range(4.0, WorldLayout.CLIFF_HEIGHT - 6.0)
		var p := cliffs.face_point(cid, y, z)
		var out := Vector3(-WorldLayout.side_sign(cid), 0, 0)
		var w := rng.randf_range(2.0, 6.5)
		var d := rng.randf_range(0.8, 2.2)
		var h := rng.randf_range(0.4, 1.2)
		var basis := Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)).rotated(Vector3.BACK, rng.randf_range(-0.08, 0.08))
		var col := _rock_color(rng)
		# A lumpy ledge half buried in the wall, with sand drifted on top.
		MeshKit.add_ellipsoid(st, Transform3D(basis, p + out * (d * 0.35 - 0.6)), Vector3(d * 1.1, h * 1.4, w * 0.6), 5, 9, col, 0.25, rng)
		MeshKit.add_ellipsoid(st, Transform3D(basis, p + out * (d * 0.3 - 0.6) + Vector3.UP * h * 0.75), Vector3(d * 0.9, h * 0.35, w * 0.5), 4, 9, Palette.SAND.darkened(0.08), 0.1, rng)
		if rng.randf() < 0.5:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), p + out * d * 0.6 + Vector3(0, h + 0.3, rng.randf_range(-w, w) * 0.3)), Vector3(0.4, 0.3, 0.4), 4, 6, col.lightened(0.1), 0.2, rng)
		placed += 1


## Fallen boulders and scree slopes at the foot of each wall.
static func _wall_base(st: SurfaceTool, rng: RandomNumberGenerator, cliffs: CliffBuilder, cid: int) -> void:
	var z := -200.0
	while z < 200.0:
		z += rng.randf_range(3.0, 9.0)
		var y := cliffs.floor_height(cliffs.face_point(cid, 1.0, z).x, z)
		var base := cliffs.face_point(cid, 1.0, z)
		var out := Vector3(-WorldLayout.side_sign(cid), 0, 0)
		var n := rng.randi_range(1, 4)
		for i in n:
			var s := rng.randf_range(0.7, 2.6)
			var at := Vector3(base.x, y, z) + out * rng.randf_range(0.5, 4.0) + Vector3(0, s * 0.35, rng.randf_range(-1.5, 1.5))
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), Vector3(s, s * 0.7, s * 1.1), 5, 8, _rock_color(rng), 0.22, rng)
		# Scree: a low slope of rubble against the wall.
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(base.x, y, z) + out * 1.2), Vector3(2.5, 1.2, 3.5), 4, 8, Palette.ROCK_C.darkened(0.1), 0.25, rng)


## The canyon floor: hoodoos, dead trees, skulls and a cracked dry wash.
static func _floor(rock: SurfaceTool, dry: SurfaceTool, rng: RandomNumberGenerator, cliffs: CliffBuilder) -> void:
	# Hoodoos: stacked, weathered pillars with a cap stone.
	for i in 14:
		var z := rng.randf_range(-190.0, 190.0)
		if absf(z - OasisBuilder.CENTER_Z) < 16.0:
			continue
		var x := rng.randf_range(-13.0, 13.0)
		var y := cliffs.floor_height(x, z)
		var h := rng.randf_range(4.0, 11.0)
		var segs := rng.randi_range(3, 5)
		var r := rng.randf_range(0.8, 1.6)
		var at := Vector3(x, y, z)
		for k in segs:
			var seg_h := h / segs
			var rr := r * rng.randf_range(0.7, 1.15)
			MeshKit.add_cylinder(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, seg_h * 0.5, 0)), rr * 1.05, rr * 0.85, seg_h, 9, _rock_color(rng))
			at += Vector3(rng.randf_range(-0.15, 0.15), seg_h, rng.randf_range(-0.15, 0.15))
		MeshKit.add_ellipsoid(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, r * 0.3, 0)), Vector3(r * 1.5, r * 0.55, r * 1.3), 5, 9, Color("#8A4A32"), 0.15, rng)
	# Dead trees: twisted grey trunks with forked branches.
	for i in 12:
		var x := rng.randf_range(-15.0, 15.0)
		var z := rng.randf_range(-190.0, 190.0)
		var y := cliffs.floor_height(x, z)
		var base := Vector3(x, y, z)
		var top := base + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(2.5, 4.5), rng.randf_range(-0.6, 0.6))
		var bark := Color("#8C8378").darkened(rng.randf_range(0.0, 0.2))
		MeshKit.add_limb(dry, base, top, 0.16, bark, 6)
		for b in rng.randi_range(2, 4):
			var from := base.lerp(top, rng.randf_range(0.45, 1.0))
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.3, 1.0), rng.randf_range(-1, 1)).normalized()
			var tip := from + dir * rng.randf_range(0.8, 1.8)
			MeshKit.add_limb(dry, from, tip, 0.07, bark, 5)
			MeshKit.add_limb(dry, tip, tip + (dir + Vector3(rng.randf_range(-0.6, 0.6), 0.3, rng.randf_range(-0.6, 0.6))).normalized() * 0.6, 0.035, bark, 4)
	# Bleached cattle skulls with horns.
	for i in 10:
		var x := rng.randf_range(-14.0, 14.0)
		var z := rng.randf_range(-85.0, 85.0)
		var at := Vector3(x, cliffs.floor_height(x, z) + 0.2, z)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
		MeshKit.add_ellipsoid(dry, Transform3D(basis, at), Vector3(0.28, 0.22, 0.4), 5, 8, Palette.BONE)
		MeshKit.add_ellipsoid(dry, Transform3D(basis, at + basis * Vector3(0, -0.05, -0.35)), Vector3(0.16, 0.13, 0.22), 4, 8, Palette.BONE.darkened(0.05))
		for s: float in [-1.0, 1.0]:
			MeshKit.add_ellipsoid(dry, Transform3D(basis, at + basis * Vector3(s * 0.1, 0.05, -0.12)), Vector3(0.06, 0.05, 0.03), 3, 6, Palette.OUTLINE)
			var h0 := at + basis * Vector3(s * 0.22, 0.12, 0.1)
			var h1 := at + basis * Vector3(s * 0.55, 0.3, 0.05)
			MeshKit.add_limb(dry, h0, h1, 0.05, Palette.BONE.darkened(0.1), 5)
			MeshKit.add_limb(dry, h1, h1 + basis * Vector3(s * 0.12, 0.25, -0.05), 0.035, Palette.BONE.darkened(0.15), 4)
	# Cracked mud in the dry wash: dark polygons along the meander.
	for i in 140:
		var z := rng.randf_range(-190.0, 190.0)
		var x := 6.0 * sin(z * 0.035) + rng.randf_range(-2.5, 2.5)
		var at := Vector3(x, cliffs.floor_height(x, z) + 0.05, z)
		var s := rng.randf_range(0.5, 1.2)
		var pts: Array[Vector3] = []
		var k := rng.randi_range(5, 7)
		for j in k:
			var a := TAU * j / k + rng.randf_range(-0.2, 0.2)
			pts.append(at + Vector3(cos(a), 0, sin(a)) * s * rng.randf_range(0.7, 1.0))
		var c := Color("#A86A42").lerp(Color("#C08250"), rng.randf())
		for j in k:
			MeshKit.tri(dry, at, pts[(j + 1) % k], pts[j], Vector3.UP, Vector3.UP, Vector3.UP, MeshKit.vcol(c), Vector3.UP)


## Buttes and mesas on the far horizon, beyond the plateaus.
static func _horizon(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for i in 22:
		var a := TAU * i / 22.0 + rng.randf_range(-0.1, 0.1)
		var dist := rng.randf_range(260.0, 420.0)
		var at := Vector3(cos(a) * dist, WorldLayout.CLIFF_HEIGHT - 4.0, sin(a) * dist)
		var w := rng.randf_range(25.0, 70.0)
		var h := rng.randf_range(18.0, 55.0)
		var col := Color("#C0704A").lerp(Color("#D89A6A"), rng.randf())
		# Tapering body with a flat cap and a talus skirt.
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, h * 0.5, 0)), w * 0.62, w * 0.5, h, 8, col)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, h + 1.0, 0)), w * 0.52, w * 0.5, 2.0, 8, col.darkened(0.2))
		MeshKit.add_cylinder(st, Transform3D(Basis(), at + Vector3(0, 3.0, 0)), w * 0.9, w * 0.62, 6.0, 8, col.lightened(0.08))


## A tumbleweed bowling along the canyon floor, bouncing and spinning.
class Tumbleweed extends MeshInstance3D:
	var cliffs: CliffBuilder
	var seed_value := 0
	var _vel := Vector3.ZERO
	var _bounce := 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var st := MeshKit.begin()
		var c := Color("#B8955A")
		for i in 22:
			var a := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * 0.55
			var b := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * 0.55
			MeshKit.add_limb(st, a, b, 0.025, c.darkened(rng.randf() * 0.25), 3)
		mesh = MeshKit.finish(st)
		material_override = Materials.toon(0.006)
		position = Vector3(rng.randf_range(-12, 12), 1.0, rng.randf_range(-90, 90))
		_vel = Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(2.0, 4.0) * (1.0 if rng.randf() < 0.5 else -1.0))

	func _process(delta: float) -> void:
		var wind := 1.0
		if GameState.weather == Weather.Kind.WINDY:
			wind = 3.0
			_vel.z = WeatherFx.wind_sign() * absf(_vel.z)
		position += _vel * wind * delta
		position.x = clampf(position.x, -14.0, 14.0)
		if position.z > 200.0:
			position.z = -200.0
		elif position.z < -200.0:
			position.z = 200.0
		_bounce += delta * (3.0 + wind)
		var floor_y := cliffs.floor_height(position.x, position.z) if cliffs != null else 0.0
		position.y = floor_y + 0.55 + absf(sin(_bounce)) * 0.6 * wind * 0.5
		rotate(Vector3(1, 0, 0), _vel.z * wind * delta * 1.8)

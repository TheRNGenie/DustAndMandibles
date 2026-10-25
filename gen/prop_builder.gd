class_name PropBuilder
extends RefCounted
## Small seeded prop generators: cactus, rock, barrel, crate, nest mound, tin can.
## Local space: origin on the ground.

static func cactus(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var h := rng.randf_range(3.0, 5.0)
	var r := rng.randf_range(0.35, 0.5)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, h * 0.5, 0)), r, r * 0.95, h, 10, Palette.CACTUS)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, h, 0)), Vector3(r * 0.95, r * 0.8, r * 0.95), 5, 10, Palette.CACTUS)
	var arms := rng.randi_range(1, 2)
	for i in arms:
		var side := -1.0 if i == 0 else 1.0
		var ay := rng.randf_range(h * 0.35, h * 0.6)
		var ar := r * 0.65
		var out := Vector3(side * rng.randf_range(0.9, 1.2), ay, 0)
		MeshKit.add_limb(st, Vector3(0, ay, 0), out, ar, Palette.CACTUS_DARK, 8)
		var up_len := rng.randf_range(0.8, 1.6)
		MeshKit.add_limb(st, out, out + Vector3(0, up_len, 0), ar, Palette.CACTUS_DARK, 8)
	# A few flowers.
	if rng.randf() < 0.6:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.1, h + r * 0.7, 0)), Vector3.ONE * 0.12, 3, 6, Palette.TEAM_WEST.lightened(0.2))
	return MeshKit.finish(st)


static func rock(seed_value: int, size: float = 1.0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var radii := Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.5, 0.9), rng.randf_range(0.8, 1.3)) * size
	var color := [Palette.ROCK_A, Palette.ROCK_B, Palette.ROCK_C][rng.randi_range(0, 2)] as Color
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, radii.y * 0.5, 0)), radii, 5, 7, color, 0.18, rng)
	return MeshKit.finish(st)


static func barrel(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.25, 0)), 0.36, 0.42, 0.5, 12, Palette.WOOD)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.75, 0)), 0.42, 0.36, 0.5, 12, Palette.WOOD)
	for band_y: float in [0.12, 0.5, 0.88]:
		var br := 0.37 + 0.06 * (1.0 - absf(band_y - 0.5) * 2.0)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, band_y, 0)), br + 0.015, br + 0.015, 0.06, 12, Palette.METAL, false)
	return MeshKit.finish(st)


static func crate(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(0.9, 0.9, 0.9), Palette.WOOD, 0.03, rng)
	for side: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, side * 0.78), Vector3(0, 0.45, -0.46)),
				Vector3(1.15, 0.1, 0.04), Palette.WOOD_DARK)
	return MeshKit.finish(st)


## Bug nest on the canyon floor: a dirt mound with a dark, faintly glowing hole.
static func nest_mound(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3.ZERO), Vector3(4.0, 1.8, 4.0), 6, 12, Palette.DIRT_DARK, 0.12, rng)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 1.55, 0)), Vector3(1.3, 0.35, 1.3), 4, 10, Palette.ACID_GREEN.darkened(0.6), 0.0, null, 0.35)
	for i in 6:
		var a := TAU * float(i) / 6.0 + rng.randf_range(-0.3, 0.3)
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(4.0, 6.0)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), p), Vector3(0.6, 0.35, 0.6), 3, 6, Palette.BONE, 0.2, rng)
	return MeshKit.finish(st)


## A tin can for target practice (centred).
static func tin_can() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(), 0.06, 0.06, 0.16, 10, Palette.METAL.lightened(0.15))
	MeshKit.add_cylinder(st, Transform3D(), 0.062, 0.062, 0.09, 10, Palette.TEAM_WEST, false)
	return MeshKit.finish(st)

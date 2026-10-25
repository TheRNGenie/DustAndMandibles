class_name BuildingBuilder
extends RefCounted
## Procedural homestead buildings made of wobbly planks, boxes and cylinders.
## Every builder returns an ArrayMesh with vertex colours (use Materials.toon()).
## Local space: origin on the ground, forward (-Z) is the front of the building.

## The Homestead: a small cabin with porch, pitched roof, glowing windows and a team-colour flag.
static func homestead(seed_value: int, team: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var w := 7.0
	var dpt := 5.5
	var h := 3.2
	# Plank walls: stacked logs with slight random offsets.
	var log_h := 0.4
	var y := 0.0
	var i := 0
	while y < h:
		var shade := Palette.WOOD if i % 2 == 0 else Palette.WOOD.darkened(0.08)
		var off := rng.randf_range(-0.05, 0.05)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(off, y + log_h * 0.5, -dpt * 0.5)),
				Vector3(w + 0.3, log_h, 0.3), shade, 0.03, rng)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(off, y + log_h * 0.5, dpt * 0.5)),
				Vector3(w + 0.3, log_h, 0.3), shade, 0.03, rng)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-w * 0.5, y + log_h * 0.5, off)),
				Vector3(0.3, log_h, dpt), shade, 0.03, rng)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(w * 0.5, y + log_h * 0.5, off)),
				Vector3(0.3, log_h, dpt), shade, 0.03, rng)
		y += log_h
		i += 1
	# Door and glowing windows on the front.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.05, -dpt * 0.5 - 0.17)),
			Vector3(1.1, 2.1, 0.06), Palette.WOOD_DARK)
	for wx: float in [-2.2, 2.2]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(wx, 1.8, -dpt * 0.5 - 0.17)),
				Vector3(1.0, 0.8, 0.05), Palette.GLOW_YELLOW, 0.0, null, 0.6)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(wx, 1.8, -dpt * 0.5 - 0.2)),
				Vector3(1.2, 0.12, 0.08), Palette.WOOD_DARK)
	# Pitched roof: two slabs.
	var roof_angle := deg_to_rad(28.0)
	var half_span := w * 0.5 + 0.6
	var slab_len := half_span / cos(roof_angle)
	for side: float in [-1.0, 1.0]:
		var b := Basis(Vector3.BACK, -side * roof_angle)
		var center := Vector3(side * half_span * 0.5, h + tan(roof_angle) * half_span * 0.5 + 0.1, 0)
		MeshKit.add_box(st, Transform3D(b, center), Vector3(slab_len, 0.25, dpt + 1.6), Palette.ROOF, 0.04, rng)
	# Gable ends.
	for gz: float in [-dpt * 0.5, dpt * 0.5]:
		var peak := Vector3(0, h + tan(roof_angle) * (w * 0.5), gz)
		var n := Vector3(0, 0, signf(gz))
		MeshKit.tri(st, Vector3(-w * 0.5, h, gz), Vector3(w * 0.5, h, gz), peak, n, n, n,
				MeshKit.vcol(Palette.WOOD.lightened(0.05)), n)
	# Porch: floor, posts and a little awning.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.15, -dpt * 0.5 - 1.2)),
			Vector3(w, 0.3, 2.2), Palette.WOOD_DARK, 0.03, rng)
	for px: float in [-w * 0.5 + 0.2, -1.0, 1.0, w * 0.5 - 0.2]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(px, 1.3, -dpt * 0.5 - 2.1)),
				Vector3(0.18, 2.3, 0.18), Palette.WOOD, 0.02, rng)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12.0)), Vector3(0, 2.55, -dpt * 0.5 - 1.2)),
			Vector3(w + 0.4, 0.15, 2.6), Palette.ROOF.darkened(0.1), 0.03, rng)
	# Chimney.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(w * 0.3, h + 1.8, dpt * 0.15)),
			Vector3(0.7, 2.2, 0.7), Palette.ROCK_B, 0.04, rng)
	# Flag pole with team colour.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-w * 0.5 - 0.8, 3.0, -dpt * 0.5 - 1.8)),
			0.06, 0.05, 6.0, 6, Palette.METAL)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(-w * 0.5 - 0.15, 5.4, -dpt * 0.5 - 1.8)),
			Vector3(1.3, 0.8, 0.04), team)
	return MeshKit.finish(st)


## A water tower: four legs, a barrel tank and a conical roof.
static func water_tower(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var leg_h := 5.0
	for lx: float in [-1.2, 1.2]:
		for lz: float in [-1.2, 1.2]:
			MeshKit.add_limb(st, Vector3(lx * 1.25, 0, lz * 1.25), Vector3(lx, leg_h, lz), 0.14, Palette.WOOD)
	# Cross braces.
	for side: float in [-1.2, 1.2]:
		MeshKit.add_limb(st, Vector3(side * 1.2, 0.8, -1.4), Vector3(side * 1.05, 4.0, 1.1), 0.07, Palette.WOOD_DARK)
		MeshKit.add_limb(st, Vector3(-1.4, 0.8, side * 1.2), Vector3(1.1, 4.0, side * 1.05), 0.07, Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, leg_h, 0)), Vector3(3.2, 0.25, 3.2), Palette.WOOD_DARK, 0.03, rng)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, leg_h + 1.5, 0)), 1.5, 1.4, 2.8, 14, Palette.WOOD)
	for band_y: float in [0.5, 1.5, 2.5]:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, leg_h + band_y, 0)), 1.53, 1.53, 0.12, 14, Palette.METAL)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, leg_h + 3.5, 0)), 1.75, 0.0, 1.3, 14, Palette.ROOF)
	return MeshKit.finish(st)


## Windmill tower (the fan is built separately so it can spin).
static func windmill_tower(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var top := 8.0
	for lx: float in [-1.0, 1.0]:
		for lz: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(lx * 1.4, 0, lz * 1.4), Vector3(lx * 0.3, top, lz * 0.3), 0.09, Palette.WOOD)
	for t: float in [0.25, 0.5, 0.75]:
		var r := lerpf(1.4, 0.3, t)
		var yy := top * t
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, yy, -r)), Vector3(r * 2.0, 0.1, 0.1), Palette.WOOD_DARK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, yy, r)), Vector3(r * 2.0, 0.1, 0.1), Palette.WOOD_DARK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-r, yy, 0)), Vector3(0.1, 0.1, r * 2.0), Palette.WOOD_DARK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(r, yy, 0)), Vector3(0.1, 0.1, r * 2.0), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, top + 0.3, 0.2)), Vector3(0.6, 0.6, 1.4), Palette.METAL, 0.02, rng)
	# Tail vane.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, top + 0.5, 1.6)), Vector3(0.05, 0.9, 1.4), Palette.TEAM_WEST.lerp(Palette.ROOF, 0.6))
	# Trough at the base (the well, later filled with water).
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(2.0, 0.35, 0)), Vector3(1.0, 0.7, 2.4), Palette.WOOD_DARK, 0.03, rng)
	return MeshKit.finish(st)


## Windmill fan, centred on its hub, spinning around local Z.
static func windmill_fan() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.2, 0.2, 0.3, 8, Palette.METAL)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var b := Basis(Vector3.BACK, a)
		MeshKit.add_box(st, Transform3D(b, b * Vector3(0, 1.1, 0)), Vector3(0.35, 1.6, 0.04), Palette.BONE)
	return MeshKit.finish(st)


## A run of fence posts with two rails between `from` and `to` (local space, y = ground offset).
static func fence(points: Array[Vector3], seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	for i in points.size():
		var p := points[i]
		var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06)) * Basis(Vector3.BACK, rng.randf_range(-0.06, 0.06))
		MeshKit.add_box(st, Transform3D(tilt, p + Vector3(0, 0.6, 0)), Vector3(0.18, 1.3, 0.18), Palette.WOOD, 0.03, rng)
		if i + 1 < points.size():
			var q := points[i + 1]
			for rail_y: float in [0.5, 1.0]:
				var a := p + Vector3(0, rail_y + rng.randf_range(-0.04, 0.04), 0)
				var b := q + Vector3(0, rail_y + rng.randf_range(-0.04, 0.04), 0)
				var mid := (a + b) * 0.5
				var dir := b - a
				var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
				MeshKit.add_box(st, Transform3D(basis, mid), Vector3(0.08, 0.14, dir.length()), Palette.WOOD_DARK)
	return MeshKit.finish(st)

class_name ArchBuilder
extends RefCounted
## Natural sandstone arches. An arch is a thick, lumpy band of rock that rises
## from one foot, bows up through an apex and comes down on the other foot: a
## chain of tilted rock blocks along a curve, fattest at the feet and thinnest
## at the crown, banded like the canyon walls, with loose boulders and drips of
## rock hanging under the span. Used over the play area as grapple points.


## Adds an arch from foot `a` to foot `b` (feet a little below ground), whose
## crown rises `rise` metres above the higher foot.
static func arch(st: SurfaceTool, rng: RandomNumberGenerator, a: Vector3, b: Vector3, rise: float,
		foot_r: float, crown_r: float) -> void:
	var segs := 30
	var span := b - a
	var top := maxf(a.y, b.y) + rise
	var side := span.cross(Vector3.UP).normalized()
	var cols := [Palette.ROCK_A, Palette.ROCK_B, Color("#B85A3A"), Color("#D99A62"), Color("#C4703E")]
	var prev := _point(a, b, top, 0.0)
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var p0 := _point(a, b, top, t0)
		var p1 := _point(a, b, top, t1)
		var mid := (p0 + p1) * 0.5
		var tm := (t0 + t1) * 0.5
		var fat := lerpf(crown_r, foot_r, pow(absf(tm - 0.5) * 2.0, 1.6))
		var dir := (p1 - p0).normalized()
		var basis := Basis(side, dir.cross(side).normalized(), -dir).orthonormalized()
		basis = basis * Basis(Vector3.BACK, rng.randf_range(-0.08, 0.08))
		var col: Color = cols[(i / 3) % cols.size()]
		MeshKit.add_box(st, Transform3D(basis, mid), Vector3(fat * 2.2, fat * 1.4, p0.distance_to(p1) * 1.25), col.darkened(rng.randf() * 0.08), fat * 0.18, rng)
		# Lumps and ledges on the sides so the band never reads as a tube.
		for k in 2:
			var off := side * rng.randf_range(-fat, fat) + basis.y * rng.randf_range(-fat * 0.6, fat * 0.6)
			MeshKit.add_ellipsoid(st, Transform3D(basis, mid + off), Vector3(fat * 0.7, fat * 0.5, fat * 0.8), 4, 8, col.lightened(0.05), 0.25, rng)
		# Rock drips and a hanging boulder or two under the crown.
		if tm > 0.2 and tm < 0.8 and rng.randf() < 0.35:
			var under := mid - basis.y * fat * 0.7
			MeshKit.add_cylinder(st, Transform3D(Basis(), under - Vector3(0, fat * 0.6, 0)), fat * 0.35, 0.05, fat * 1.4, 6, col.darkened(0.15))
		prev = p1
	# Rubble heaped round both feet.
	for foot: Vector3 in [a, b]:
		for k in 6:
			var s := rng.randf_range(foot_r * 0.3, foot_r * 0.7)
			var at := foot + Vector3(rng.randf_range(-foot_r, foot_r) * 1.4, s * 0.3, rng.randf_range(-foot_r, foot_r) * 1.4)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), Vector3(s, s * 0.7, s * 1.1), 4, 8,
					(cols[rng.randi() % cols.size()] as Color).darkened(0.1), 0.25, rng)


## A point on the arch's centre line: feet at t = 0 and 1, crown at t = 0.5.
static func _point(a: Vector3, b: Vector3, top: float, t: float) -> Vector3:
	var base := a.lerp(b, t)
	# Steep sides near the feet, a flatter crown (a squashed half-sine).
	var lift := pow(sin(t * PI), 0.7)
	return Vector3(base.x, lerpf(base.y, top, lift), base.z)

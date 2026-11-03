class_name StoryFloorProps
extends RefCounted
## Story set dressing on the canyon floor, round a fetch item (StoryDirector):
## Dry Season's wrecked supply wagon (the pump valve lies in its spilled load)
## and The Survey Map's Queen Spider carcass, flat on her back with her legs
## curled (the gland glows in her split abdomen). Visual only; the item itself
## is a StoryCargo the director puts at item_spot().


## A Node3D with the dressing's mesh (`kind` "wagon" or "carcass").
static func dressing(kind: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = carcass_mesh() if kind == "carcass" else wagon_mesh()
	mi.material_override = Materials.toon(0.03)
	root.add_child(mi)
	return root


## Where the item lies, in the dressing's own frame.
static func item_spot(kind: String) -> Vector3:
	return Vector3(-0.4, 0.0, 2.2) if kind == "carcass" else Vector3(1.9, 0.0, -0.4)


## A supply wagon gone over the edge: the bed on its side, a wheel off and
## lying flat, the bonnet hoops snapped with the canvas torn, crates and
## sacks spilled, the shaft broken off.
static func wagon_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1889
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DARK
	var iron := Palette.METAL.darkened(0.3)
	var canvas := Color("#E6D6B0")
	# The bed, tipped onto its long side (its floor faces +x), sunk a little.
	var bed := Basis(Vector3.FORWARD, deg_to_rad(78.0))
	var bed_at := Vector3(-0.4, 0.62, 0.0)
	MeshKit.add_box(st, Transform3D(bed, bed_at), Vector3(1.4, 0.1, 3.6), wood, 0.03, rng) # floor
	for side: float in [-0.68, 0.68]:
		MeshKit.add_box(st, Transform3D(bed, bed_at + bed * Vector3(side, 0.32, 0)), Vector3(0.06, 0.62, 3.6), wood.lightened(0.05), 0.03, rng)
		for k in 3: # plank seams
			MeshKit.add_box(st, Transform3D(bed, bed_at + bed * Vector3(side * 1.03, 0.12 + k * 0.2, 0)), Vector3(0.02, 0.03, 3.6), dark)
	MeshKit.add_box(st, Transform3D(bed, bed_at + bed * Vector3(0, 0.32, 1.78)), Vector3(1.4, 0.62, 0.06), wood, 0.03, rng)
	# Axles and the one wheel still on (sticking up off the bed's underside).
	for z: float in [-1.2, 1.2]:
		MeshKit.add_limb(st, bed_at + bed * Vector3(-0.85, -0.15, z), bed_at + bed * Vector3(0.85, -0.15, z), 0.05, iron, 6)
	_wheel(st, bed_at + bed * Vector3(-0.95, -0.15, 1.2), bed * Basis(Vector3.FORWARD, PI * 0.5), wood, iron, 0.62, 3)
	_wheel(st, bed_at + bed * Vector3(-0.95, -0.15, -1.2), bed * Basis(Vector3.FORWARD, PI * 0.5), wood, iron, 0.62, 12)
	# A wheel off, lying flat, spokes broken.
	_wheel(st, Vector3(1.6, 0.06, 2.4), Basis(), wood, iron, 0.62, 5)
	# Bonnet hoops, two snapped, and the torn canvas.
	for i in 4:
		var z := -1.5 + i * 1.0
		var r := 0.85
		var top := bed_at + bed * Vector3(0, 0.62, z)
		var segs := 7 if i % 2 == 0 else 4
		var last := top + bed * Vector3(-r, 0, 0)
		for k in segs:
			var a := PI * float(k + 1) / 8.0
			var p := top + bed * Vector3(-cos(a) * r, sin(a) * r * 1.1, 0)
			MeshKit.add_limb(st, last, p, 0.035, dark, 5)
			last = p
	var c0 := bed_at + bed * Vector3(-0.85, 0.7, -1.5)
	var c1 := bed_at + bed * Vector3(-0.85, 0.7, 1.4)
	var c2 := bed_at + bed * Vector3(0.0, 1.55, 0.9)
	var c3 := bed_at + bed * Vector3(0.0, 1.5, -1.5)
	MeshKit.quad(st, c0, c1, c2, c3, Vector3.UP, MeshKit.vcol(canvas))
	MeshKit.quad(st, c0, c1, c2, c3, Vector3.DOWN, MeshKit.vcol(canvas.darkened(0.15)))
	MeshKit.tri(st, c2, c1, c1 + Vector3(0.9, -0.5, 0.6), Vector3.UP, Vector3.UP, Vector3.UP, MeshKit.vcol(canvas), Vector3.UP)
	# The broken shaft and a singletree.
	MeshKit.add_limb(st, Vector3(-0.2, 0.15, -1.9), Vector3(0.1, 0.08, -3.4), 0.06, wood, 5)
	MeshKit.add_limb(st, Vector3(0.6, 0.06, -2.9), Vector3(1.4, 0.06, -3.6), 0.05, wood, 5)
	# The spilled load: crates (one split), sacks, a barrel on its side.
	for c: Array in [[Vector3(1.0, 0.3, 0.9), 0.6, 0.3], [Vector3(2.5, 0.25, 1.4), 0.5, -0.4], [Vector3(0.8, 0.28, -1.6), 0.55, 0.9]]:
		var b := Basis(Vector3.UP, float(c[2]))
		var sz := float(c[1])
		MeshKit.add_box(st, Transform3D(b, c[0]), Vector3(sz, sz, sz), wood.lightened(0.1), 0.04, rng)
		MeshKit.add_box(st, Transform3D(b, (c[0] as Vector3) + Vector3(0, sz * 0.3, 0)), Vector3(sz * 1.04, 0.05, sz * 1.04), dark)
	for k in 6: # planks from the split crate
		var a := rng.randf() * TAU
		var p := Vector3(2.9 + cos(a) * 0.8, 0.03, -0.9 + sin(a) * 0.8)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, a), p), Vector3(0.12, 0.03, 0.7), wood.lightened(0.12), 0.02, rng)
	for k in 3:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(-0.2 + k * 0.55, 0.2, 2.2 + k * 0.15)), Vector3(0.32, 0.22, 0.26), 4, 8, Color("#B08850"), 0.15, rng)
	var barrel := Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, 0.3), Vector3(-1.6, 0.36, 1.9))
	MeshKit.add_cylinder(st, barrel, 0.36, 0.36, 0.9, 12, wood.darkened(0.05))
	for y: float in [-0.3, 0.3]:
		MeshKit.add_cylinder(st, barrel * Transform3D(Basis(), Vector3(0, y, 0)), 0.37, 0.37, 0.06, 12, iron)
	# Wheel ruts and scraped dirt where it came down.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.3, 0.0, 0.0)), Vector3(3.2, 0.03, 4.2), 3, 12, Palette.DIRT_DARK)
	return MeshKit.finish(st)


static func _wheel(st: SurfaceTool, at: Vector3, b: Basis, wood: Color, iron: Color, r: float, broken: int) -> void:
	var last := at + b * Vector3(r, 0, 0)
	for k in 16:
		var a := TAU * float(k + 1) / 16.0
		var p := at + b * Vector3(cos(a) * r, 0, sin(a) * r)
		MeshKit.add_limb(st, last, p, 0.045, iron, 5)
		last = p
	for k in 10:
		if k == broken or k == (broken + 4) % 10:
			continue
		var a := TAU * float(k) / 10.0
		MeshKit.add_limb(st, at, at + b * Vector3(cos(a) * r * 0.95, 0, sin(a) * r * 0.95), 0.03, wood, 4)
	MeshKit.add_cylinder(st, Transform3D(b, at), 0.12, 0.12, 0.2, 10, wood.darkened(0.2))


## The Queen Spider on her back: a big plum abdomen with pale chevrons split
## open (acid-green glow inside), the head, eight legs folded up into the air,
## silk trailing, a splash of ichor round her.
static func carcass_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	var shell := Color(0.2, 0.13, 0.2)
	var plum := Palette.SPIDER_PLUM.darkened(0.25)
	var pale := Palette.BONE.darkened(0.1)
	# Ichor pool first (under everything).
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.6, 0.0, 0.1)), Vector3(3.6, 0.03, 2.8), 3, 14, Palette.ACID_GREEN.darkened(0.45))
	# Abdomen (belly up) and the thorax, lying along x.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.FORWARD, 0.1), Vector3(-1.3, 1.0, 0)), Vector3(1.9, 1.05, 1.5), 8, 14, plum, 0.04, rng)
	for k in 4: # chevrons on the underside, now on top
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(-2.3 + k * 0.55, 1.9 - absf(k - 1.5) * 0.12, 0)), Vector3(0.18, 0.08, 0.7 - absf(k - 1.5) * 0.12), 3, 8, pale)
	# The slit where the gland came loose: a dark gash with a green glow.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, 0.2), Vector3(-0.3, 1.45, 0.55)), Vector3(0.7, 0.18, 0.28), 4, 10, Color("#2A0F22"))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, 0.2), Vector3(-0.3, 1.5, 0.55)), Vector3(0.45, 0.1, 0.16), 3, 8, Palette.ACID_GREEN, 0.0, null, 0.7)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.75, 0.7, 0)), Vector3(0.95, 0.7, 0.85), 6, 12, shell, 0.03, rng)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(1.55, 0.55, 0)), Vector3(0.5, 0.42, 0.55), 5, 10, shell.lightened(0.05), 0.03, rng)
	# Fangs, pointing up.
	for s: float in [-0.2, 0.2]:
		MeshKit.add_limb(st, Vector3(1.95, 0.55, s), Vector3(2.2, 0.95, s * 0.6), 0.07, Color("#1A1014"), 5)
	# Eight legs, folded up and in like a dead spider's.
	for i in 8:
		var side := -1.0 if i < 4 else 1.0
		var k := i % 4
		var root := Vector3(0.45 + k * 0.32, 0.9, side * 0.6)
		var knee := root + Vector3((k - 1.5) * 0.7, 1.7 + rng.randf() * 0.4, side * (1.0 + rng.randf() * 0.3))
		var foot := knee + Vector3((k - 1.5) * 0.3, -0.9, -side * (1.1 + rng.randf() * 0.4))
		MeshKit.add_limb(st, root, knee, 0.13, shell, 6)
		MeshKit.add_limb(st, knee, foot, 0.09, shell.lightened(0.04), 6)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), knee), Vector3.ONE * 0.17, 4, 6, plum.lightened(0.1))
	# Silk trailing off her spinnerets and stuck to the ground.
	for k in 6:
		var a := rng.randf_range(-1.0, 1.0)
		MeshKit.add_limb(st, Vector3(-3.1, 0.9, a * 0.4), Vector3(-4.3 - rng.randf(), 0.02, a * 2.2), 0.018, pale, 3)
	# Rock chips she knocked off on the way down.
	for k in 7:
		var p := Vector3(rng.randf_range(-3.5, 3.0), 0.12, rng.randf_range(-3.0, 3.0))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), p), Vector3(0.3, 0.18, 0.26) * rng.randf_range(0.6, 1.3), 3, 6, Palette.ROCK_B, 0.2, rng)
	return MeshKit.finish(st)

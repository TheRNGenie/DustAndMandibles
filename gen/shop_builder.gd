class_name ShopBuilder
extends RefCounted
## Meshes for the vendor cart and the gun shop stall, plus their price signs.
## Local space: origin on the ground, the counter faces -Z.

static func vendor_cart() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	var st := MeshKit.begin()
	# Wagon bed on two big wheels, canopy on poles.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.9, 0)), Vector3(2.6, 0.35, 1.5), Palette.WOOD, 0.03, rng)
	for x: float in [-0.9, 0.9]:
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0.5, -0.8)), 0.5, 0.5, 0.08, 12, Palette.WOOD_DARK)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0.5, 0.8)), 0.5, 0.5, 0.08, 12, Palette.WOOD_DARK)
	for x: float in [-1.2, 1.2]:
		for z: float in [-0.65, 0.65]:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(x, 1.75, z)), 0.05, 0.05, 1.4, 6, Palette.WOOD_DARK)
	for i in 5:
		var c := Palette.TEAM_WEST if i % 2 == 0 else Palette.BONE
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(-1.04 + i * 0.52, 2.5, 0)), Vector3(0.52, 0.05, 1.6), c)
	# Crates of produce.
	var produce := [Color("#F5D140"), Color("#D94C8C"), Color("#E3361F"), Color("#8CC66E")]
	for i in 4:
		var x := -0.9 + i * 0.6
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 1.22, -0.25)), Vector3(0.5, 0.28, 0.5), Palette.WOOD_DARK, 0.02, rng)
		for k in 4:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(x + rng.randf_range(-0.15, 0.15), 1.4, -0.25 + rng.randf_range(-0.15, 0.15))),
					Vector3.ONE * 0.09, 3, 6, produce[i] as Color)
	return MeshKit.finish(st)


static func gun_stall() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var st := MeshKit.begin()
	# Counter, back wall, slanted roof, and a rack of rifles on the wall.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.55, -0.6)), Vector3(2.8, 1.1, 0.5), Palette.WOOD, 0.03, rng)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.4, 0.7)), Vector3(3.0, 2.8, 0.15), Palette.WOOD_DARK, 0.03, rng)
	for x: float in [-1.4, 1.4]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 1.4, 0.0)), Vector3(0.15, 2.8, 1.5), Palette.WOOD_DARK, 0.02, rng)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 2.95, -0.05)), Vector3(3.3, 0.12, 2.0), Palette.ROOF, 0.03, rng)
	for i in 4:
		var x := -0.9 + i * 0.6
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.15), Vector3(x, 1.7, 0.6)), Vector3(0.06, 1.3, 0.05), Palette.METAL)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.15), Vector3(x - 0.07, 1.15, 0.6)), Vector3(0.08, 0.45, 0.06), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.12, -0.6)), Vector3(0.6, 0.04, 0.3), Palette.GLOW_YELLOW.darkened(0.3))
	return MeshKit.finish(st)


## A standing wooden sign board for prices. The text is a Label3D added by the shop.
static func sign_board() -> ArrayMesh:
	var st := MeshKit.begin()
	for x: float in [-0.75, 0.75]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 0.8, 0.05)), Vector3(0.1, 1.6, 0.1), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.55, 0)), Vector3(1.8, 1.25, 0.06), Palette.BONE.darkened(0.08))
	return MeshKit.finish(st)


## The text label that sits on a sign board (faces -Z, like the shop counter).
static func sign_label() -> Label3D:
	var l := Label3D.new()
	l.position = Vector3(0, 1.55, -0.04)
	l.rotation.y = PI
	l.pixel_size = 0.0035
	l.font_size = 48
	l.modulate = Palette.OUTLINE
	l.outline_size = 0
	l.width = 480.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.double_sided = false
	return l

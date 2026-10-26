class_name OasisBuilder
extends RefCounted
## The Oasis: a stone spire rising from the middle of the canyon, off to one side
## of the play area, with a little green market on its flat top: a spring-fed pond,
## palm trees, grass and shrubs, the vendor cart, the gunsmith and a big "OASIS"
## sign. Both drawbridges land here, so the players meet in the middle to trade.

const CENTER_Z := -30.0
const TOP_RADIUS := 8.0
const RING := 40
const STEP_Y := 1.5


## Distance from the canyon centre line to the spire's top edge along x (bridge landing).
static func landing_x() -> float:
	return TOP_RADIUS - 0.4


static func build(parent: Node3D, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.15
	var spire := StaticBody3D.new()
	spire.name = "OasisSpire"
	parent.add_child(spire)
	var mesh := _spire_mesh(noise)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Materials.strata(Color("#C9B06A"))
	spire.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	col.shape = shape
	spire.add_child(col)
	var top := Vector3(0, WorldLayout.CLIFF_HEIGHT, CENTER_Z)
	_greenery(parent, top, rng)
	_sign(parent, top)
	_market(parent, top)


## Radius of the spire at height y and angle a: wider at the base, a bulge below the top.
static func _radius(noise: FastNoiseLite, y: float, a: float) -> float:
	var h := WorldLayout.CLIFF_HEIGHT
	var t := clampf(y / h, 0.0, 1.0)
	var r := lerpf(TOP_RADIUS * 1.35, TOP_RADIUS * 0.92, t)
	if t > 0.94:
		r = lerpf(TOP_RADIUS * 0.92, TOP_RADIUS, (t - 0.94) / 0.06) # small lip at the top
	return r + noise.get_noise_2d(cos(a) * 6.0, y * 0.4 + sin(a) * 6.0) * 1.1 * (1.0 - smoothstep(0.9, 1.0, t))


static func _spire_mesh(noise: FastNoiseLite) -> ArrayMesh:
	var h := WorldLayout.CLIFF_HEIGHT
	var rows: Array = []
	var y := -2.0
	while y <= h + 0.001:
		var row: Array[Vector3] = []
		for i in RING + 1:
			var a := TAU * float(i % RING) / RING
			var r := _radius(noise, y, a)
			row.append(Vector3(cos(a) * r, y, CENTER_Z + sin(a) * r))
		rows.append(row)
		y = minf(y + STEP_Y, h) if y < h else h + 1.0
	var st := MeshKit.begin()
	var white := Color(1, 1, 1, 1)
	for r in rows.size() - 1:
		var a_row: Array[Vector3] = rows[r]
		var b_row: Array[Vector3] = rows[r + 1]
		for i in RING:
			var p0 := a_row[i]
			var p1 := a_row[i + 1]
			var p2 := b_row[i + 1]
			var p3 := b_row[i]
			var mid := (p0 + p1 + p2 + p3) * 0.25
			var outward := Vector3(mid.x, 0, mid.z - CENTER_Z).normalized()
			MeshKit.quad(st, p0, p1, p2, p3, outward, white)
	# Flat top cap.
	var top_row: Array[Vector3] = rows[rows.size() - 1]
	var c := Vector3(0, h, CENTER_Z)
	for i in RING:
		MeshKit.tri(st, c, top_row[i], top_row[i + 1], Vector3.UP, Vector3.UP, Vector3.UP, white, Vector3.UP)
	return MeshKit.finish(st)


static func _greenery(parent: Node3D, top: Vector3, rng: RandomNumberGenerator) -> void:
	var st := MeshKit.begin()
	# Grass patch over most of the top.
	MeshKit.add_cylinder(st, Transform3D(Basis(), top + Vector3(0, 0.04, 0)), TOP_RADIUS - 0.6, TOP_RADIUS - 0.8, 0.08, RING, Color("#7FBF5A"), true)
	# Spring-fed pond with a sandy rim, slightly off-centre toward the canyon end.
	var pond := top + Vector3(0, 0.06, -2.2)
	MeshKit.add_cylinder(st, Transform3D(Basis(), pond), 2.4, 2.4, 0.1, 24, Palette.SAND.lightened(0.1), true)
	MeshKit.add_cylinder(st, Transform3D(Basis(), pond + Vector3(0, 0.04, 0)), 2.0, 2.0, 0.08, 24, Color("#3FA8C9"), true, 0.25)
	# Palms around the pond.
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.6
		var base := pond + Vector3(cos(a) * 3.2, 0.0, sin(a) * 3.2)
		_palm(st, base, rng)
	# Shrubs and grass tufts.
	for k in 16:
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.8, TOP_RADIUS - 1.2)
		var p := top + Vector3(cos(a) * r, 0.1, sin(a) * r)
		if rng.randf() < 0.5:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), p + Vector3(0, 0.3, 0)), Vector3(0.5, 0.4, 0.5), 4, 8, Palette.CACTUS.lightened(rng.randf() * 0.15), 0.15, rng)
		else:
			for b in 3:
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.4, 0.4)), p + Vector3(rng.randf_range(-0.15, 0.15), 0.25, 0)), 0.04, 0.0, 0.5, 4, Color("#9CD46A"))
	# Flowers.
	for k in 10:
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.0, TOP_RADIUS - 1.0)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), top + Vector3(cos(a) * r, 0.2, sin(a) * r)), Vector3.ONE * 0.1, 3, 6,
				[Palette.TEAM_WEST, Palette.GLOW_YELLOW, Palette.BONE][k % 3] as Color)
	var mi := MeshInstance3D.new()
	mi.name = "OasisGreenery"
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.02)
	parent.add_child(mi)


static func _palm(st: SurfaceTool, base: Vector3, rng: RandomNumberGenerator) -> void:
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	var prev := base
	var segs := 7
	var height := rng.randf_range(4.0, 5.5)
	for i in segs:
		var t := float(i + 1) / segs
		var p := base + Vector3(0, t * height, 0) + lean * t * t * 1.5
		MeshKit.add_limb(st, prev, p, lerpf(0.2, 0.13, t), Palette.WOOD.lightened(0.1) if i % 2 == 0 else Palette.WOOD, 6)
		prev = p
	for f in 7:
		var a := TAU * float(f) / 7.0 + rng.randf() * 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		var tip := prev + dir * 2.0 + Vector3(0, -0.9, 0)
		var mid := prev + dir * 1.1 + Vector3(0, 0.25, 0)
		MeshKit.add_ellipsoid(st, Transform3D(Basis.looking_at((tip - prev).normalized(), Vector3.UP), (prev + tip) * 0.5 + Vector3(0, 0.15, 0)),
				Vector3(0.35, 0.05, 1.15), 3, 8, Palette.CACTUS.lightened(0.1))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), mid), Vector3.ONE * 0.01, 2, 3, Palette.CACTUS)
	for k in 3:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), prev + Vector3(rng.randf_range(-0.2, 0.2), -0.2, rng.randf_range(-0.2, 0.2))), Vector3.ONE * 0.13, 3, 6, Palette.WOOD_DARK)


static func _sign(parent: Node3D, top: Vector3) -> void:
	# A tall wooden archway sign at the canyon end of the Oasis, readable from both cliffs.
	var root := Node3D.new()
	root.name = "OasisSign"
	root.position = top + Vector3(0, 0, -TOP_RADIUS + 1.6)
	parent.add_child(root)
	var st := MeshKit.begin()
	# A bigger board so both lines of lettering sit well inside it.
	for x: float in [-4.1, 4.1]:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(x, 3.3, 0)), 0.24, 0.22, 6.6, 8, Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 5.3, 0)), Vector3(8.6, 2.6, 0.25), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 5.3, 0)), Vector3(8.0, 2.1, 0.3), Palette.BONE)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 6.9, 0)), 0.35, 0.0, 0.6, 6, Palette.GLOW_YELLOW, true, 0.6)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.03)
	root.add_child(mi)
	for side: float in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = "OASIS"
		l.font_size = 160
		l.pixel_size = 0.0075
		l.outline_size = 0
		l.modulate = Palette.ROCK_B
		l.position = Vector3(0, 5.55, side * 0.17)
		l.rotation.y = 0.0 if side > 0.0 else PI
		l.double_sided = false
		root.add_child(l)
		var sub := Label3D.new()
		sub.text = "trading post"
		sub.font_size = 64
		sub.pixel_size = 0.0065
		sub.outline_size = 0
		sub.modulate = Palette.WOOD_DARK
		sub.position = Vector3(0, 4.62, side * 0.17)
		sub.rotation.y = l.rotation.y
		sub.double_sided = false
		root.add_child(sub)


static func _market(parent: Node3D, top: Vector3) -> void:
	# Vendor cart and gunsmith side by side at the far end, facing the pond.
	var vendor := VendorCart.new()
	vendor.name = "Vendor"
	vendor.setup(WorldLayout.WEST)
	vendor.position = top + Vector3(-3.0, 0, 4.0)
	parent.add_child(vendor)
	var shop := GunShop.new()
	shop.name = "GunShop"
	shop.setup(WorldLayout.WEST)
	shop.position = top + Vector3(3.0, 0, 4.0)
	parent.add_child(shop)

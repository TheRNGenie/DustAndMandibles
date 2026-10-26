class_name CropBuilder
extends RefCounted
## Plant meshes for a farm plot, one model per growth stage, plus seed packets.
## Stages: 0 seeded (a little mound), 1 sprout, 2 young plant, 3 mature,
## 4 ripe (with the harvest showing). A plot holds a 3 x 3 patch of plants
## spread over its bed; origin is the soil surface at the plot's centre.

const STAGES := 5
const SPACING := 0.95

const SOIL := Color("#6A3E26")
const STEM := Color("#5E9B4A")
const LEAF := Color("#6FAE52")
const LEAF_DARK := Color("#4C8A3C")
const HUSK := Color("#A9C26A")
const TASSEL := Color("#E8C877")
const CORN := Color("#F5D140")
const PAD := Color("#5FA05A")
const PAD_DARK := Color("#4B8746")
const SPINE := Color("#F2E3C2")
const PEAR := Color("#D94C8C")
const BLOOM := Color("#F6C83A")
const CHILI := Color("#E3361F")
const CHILI_GREEN := Color("#5E9B3A")
const SAGE := Color("#9DB89A")
const SAGE_DARK := Color("#7F9C80")
const SAGE_FLOWER := Color("#9C7AC8")

static var _cache: Dictionary = {}


## Stage index (0-4) for a growth fraction and whether it is ripe.
static func stage_for(fraction: float, ripe: bool) -> int:
	if ripe:
		return 4
	if fraction < 0.12:
		return 0
	if fraction < 0.4:
		return 1
	if fraction < 0.75:
		return 2
	return 3


## The whole patch of plants for `crop` at `stage`.
static func patch(crop: StringName, stage: int) -> ArrayMesh:
	var key := "%s:%d" % [crop, stage]
	if _cache.has(key):
		return _cache[key]
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	for gx in 3:
		for gz in 3:
			var at := Vector3((gx - 1) * SPACING, 0.0, (gz - 1) * SPACING) + Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))
			var turn := rng.randf() * TAU
			var size := rng.randf_range(0.85, 1.1)
			_plant(st, crop, stage, at, turn, size, rng)
	var mesh := MeshKit.finish(st)
	_cache[key] = mesh
	return mesh


static func _plant(st: SurfaceTool, crop: StringName, stage: int, at: Vector3, turn: float, size: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, turn)
	if stage == 0:
		# Freshly sown: a mound of turned soil with the seed showing.
		MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0, 0.02, 0)), Vector3(0.18, 0.06, 0.14), 4, 8, SOIL.lightened(0.1))
		MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0.03, 0.07, 0)), Vector3(0.025, 0.018, 0.02), 3, 6, Color("#E8D29A"))
		return
	if stage == 1:
		# Sprout: a short stem and two seed leaves, the same for every crop but tinted.
		var tint := SAGE if crop == &"herbs" else (PAD if crop == &"prickly_pear" else LEAF)
		if crop == &"prickly_pear":
			MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0, 0.1, 0)), Vector3(0.06, 0.1, 0.025), 4, 8, PAD)
			return
		MeshKit.add_cylinder(st, Transform3D(b, at + Vector3(0, 0.07, 0)), 0.012, 0.01, 0.14, 5, STEM)
		for s: float in [-1.0, 1.0]:
			MeshKit.add_ellipsoid(st, Transform3D(b * Basis(Vector3.BACK, s * 0.5), at + b * Vector3(s * 0.05, 0.15, 0)), Vector3(0.06, 0.012, 0.035), 3, 6, tint)
		return
	match crop:
		&"corn":
			_corn(st, b, at, stage, size)
		&"prickly_pear":
			_pear(st, b, at, stage, size, rng)
		&"firecracker_chili":
			_chili(st, b, at, stage, size, rng)
		_:
			_sage(st, b, at, stage, size, rng)


## Corn: a stalk that shoots up, long arching blades, tassels, then husked ears.
static func _corn(st: SurfaceTool, b: Basis, at: Vector3, stage: int, size: float) -> void:
	var h: float = [0.0, 0.0, 0.55, 1.15, 1.25][stage] * size
	MeshKit.add_cylinder(st, Transform3D(b, at + Vector3(0, h * 0.5, 0)), 0.035, 0.02, h, 6, STEM)
	var leaves: int = [0, 0, 4, 6, 6][stage]
	for i in leaves:
		var y := h * (0.2 + 0.7 * float(i) / maxf(leaves, 1))
		var a := float(i) * 2.4
		var dir := b * Vector3(cos(a), 0, sin(a))
		# Long, arching blade: two flattened segments, the outer one drooping.
		var col := LEAF if i % 2 == 0 else LEAF_DARK
		var side := dir.cross(Vector3.UP).normalized()
		var root := at + Vector3(0, y, 0)
		var mid := root + dir * 0.17 + Vector3.UP * 0.07
		var tip := root + dir * 0.34 - Vector3.UP * 0.03
		for seg: Array in [[root, mid, 0.045], [mid, tip, 0.032]]:
			var a0: Vector3 = seg[0]
			var a1: Vector3 = seg[1]
			var axis := (a1 - a0).normalized()
			var bb := Basis(side, axis, side.cross(axis).normalized())
			MeshKit.add_ellipsoid(st, Transform3D(bb, (a0 + a1) * 0.5), Vector3(float(seg[2]), (a1 - a0).length() * 0.6, 0.008), 3, 8, col)
	if stage >= 3:
		# Tassel at the top.
		for k in 4:
			var a := float(k) * 1.57
			MeshKit.add_limb(st, at + Vector3(0, h, 0), at + Vector3(0, h + 0.12, 0) + b * Vector3(cos(a), 0, sin(a)) * 0.07, 0.008, TASSEL, 3)
	if stage >= 3:
		# Ears on the stalk: green husks, then golden kernels peeking out when ripe.
		for s: float in [-1.0, 1.0]:
			var y := h * (0.5 if s < 0 else 0.62)
			var ear_at := at + Vector3(0, y, 0) + b * Vector3(s * 0.07, 0, 0)
			var tilt := b * Basis(Vector3.BACK, s * 0.35)
			MeshKit.add_ellipsoid(st, Transform3D(tilt, ear_at), Vector3(0.045, 0.12, 0.045), 4, 8, HUSK)
			if stage == 4:
				MeshKit.add_ellipsoid(st, Transform3D(tilt, ear_at + tilt * Vector3(0, 0.05, 0)), Vector3(0.036, 0.09, 0.036), 4, 8, CORN, 0.0, null, 0.15)
				MeshKit.add_limb(st, ear_at + tilt * Vector3(0, 0.12, 0), ear_at + tilt * Vector3(0, 0.19, 0.02), 0.008, Color("#B07A3A"), 3)


## Prickly pear: stacked paddle pads that multiply, flower buds, then magenta fruit.
static func _pear(st: SurfaceTool, b: Basis, at: Vector3, stage: int, size: float, rng: RandomNumberGenerator) -> void:
	var pads: Array = [[Vector3(0, 0.17, 0), 0.0]]
	if stage >= 2:
		pads.append([Vector3(0.1, 0.38, 0), 0.4])
		pads.append([Vector3(-0.11, 0.36, 0.02), -0.45])
	if stage >= 3:
		pads.append([Vector3(0.2, 0.56, 0), 0.7])
		pads.append([Vector3(-0.02, 0.6, -0.03), -0.1])
	for p: Array in pads:
		var pb := b * Basis(Vector3.BACK, float(p[1]))
		var c: Vector3 = at + b * (p[0] as Vector3) * size
		MeshKit.add_ellipsoid(st, Transform3D(pb, c), Vector3(0.11, 0.15, 0.035) * size, 5, 10, PAD if rng.randf() < 0.5 else PAD_DARK)
		for k in 4:
			MeshKit.add_ellipsoid(st, Transform3D(pb, c + pb * Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.08, 0.08), 0.036)), Vector3.ONE * 0.008, 2, 4, SPINE)
	if stage >= 3:
		# Fruit (or buds) around the rims of the top pads.
		for p: Array in pads.slice(maxi(pads.size() - 3, 0)):
			var pb := b * Basis(Vector3.BACK, float(p[1]))
			var top: Vector3 = at + b * (p[0] as Vector3) * size + pb * Vector3(0, 0.15, 0) * size
			for k in 2:
				var off := pb * Vector3(-0.05 + k * 0.1, 0.02, 0)
				if stage == 4:
					MeshKit.add_ellipsoid(st, Transform3D(pb, top + off), Vector3(0.04, 0.055, 0.04), 4, 8, PEAR, 0.0, null, 0.15)
				else:
					MeshKit.add_ellipsoid(st, Transform3D(pb, top + off), Vector3(0.025, 0.035, 0.025), 3, 6, PAD_DARK)
					MeshKit.add_ellipsoid(st, Transform3D(pb, top + off + Vector3(0, 0.03, 0)), Vector3(0.03, 0.015, 0.03), 3, 6, BLOOM)


## Chili: a bushy pepper plant, white flowers, green pods that turn red when ripe.
static func _chili(st: SurfaceTool, b: Basis, at: Vector3, stage: int, size: float, rng: RandomNumberGenerator) -> void:
	var h: float = [0.0, 0.0, 0.32, 0.55, 0.58][stage] * size
	MeshKit.add_cylinder(st, Transform3D(b, at + Vector3(0, h * 0.5, 0)), 0.02, 0.014, h, 5, STEM.darkened(0.1))
	var branches: int = [0, 0, 3, 5, 5][stage]
	for i in branches:
		var a := float(i) * TAU / branches + rng.randf_range(-0.3, 0.3)
		var dir := b * Vector3(cos(a), 0, sin(a))
		var from := at + Vector3(0, h * rng.randf_range(0.4, 0.8), 0)
		var to := from + dir * 0.14 * size + Vector3.UP * 0.1 * size
		MeshKit.add_limb(st, from, to, 0.01, STEM.darkened(0.1), 3)
		MeshKit.add_ellipsoid(st, Transform3D(b, to), Vector3(0.09, 0.06, 0.09) * size, 4, 8, LEAF_DARK if i % 2 else LEAF)
		if stage == 3:
			MeshKit.add_ellipsoid(st, Transform3D(b, to + Vector3(0, 0.06, 0)), Vector3.ONE * 0.018, 3, 6, Color("#F7F2E4"))
		if stage >= 3:
			var pod_top := to - Vector3(0, 0.02, 0) + dir * 0.03
			var col := CHILI if stage == 4 else CHILI_GREEN
			var pod := Basis(dir.cross(Vector3.UP).normalized(), 0.3)
			MeshKit.add_cylinder(st, Transform3D(pod, pod_top - Vector3(0, 0.07, 0)), 0.0, 0.022, 0.13, 6, col, true, 0.15 if stage == 4 else 0.0)
	MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0, h, 0)), Vector3(0.1, 0.07, 0.1) * size, 4, 8, LEAF)


## Sage: a mound of soft grey-green leaves, taller sprigs, purple flower spikes when ripe.
static func _sage(st: SurfaceTool, b: Basis, at: Vector3, stage: int, size: float, rng: RandomNumberGenerator) -> void:
	var r: float = [0.0, 0.0, 0.17, 0.28, 0.3][stage] * size
	var leaves: int = [0, 0, 8, 14, 14][stage]
	for i in leaves:
		var a := rng.randf() * TAU
		var up := rng.randf_range(0.2, 1.0)
		var dir := (b * Vector3(cos(a), up, sin(a))).normalized()
		var c := at + Vector3(0, r * 0.4, 0) + dir * r * 0.8
		MeshKit.add_ellipsoid(st, Transform3D(MeshKit.basis_from_y(dir), c), Vector3(0.05, 0.095, 0.02) * size, 3, 6, SAGE if i % 3 else SAGE_DARK)
	if stage >= 3:
		for k in 3:
			var a := float(k) * 2.1 + rng.randf()
			var base := at + Vector3(0, r * 0.6, 0) + b * Vector3(cos(a), 0, sin(a)) * r * 0.4
			var tip := base + Vector3(0, 0.22 * size, 0) + b * Vector3(cos(a), 0, sin(a)) * 0.04
			MeshKit.add_limb(st, base, tip, 0.008, SAGE_DARK.darkened(0.2), 3)
			if stage == 4:
				for j in 4:
					MeshKit.add_ellipsoid(st, Transform3D(Basis(), base.lerp(tip, 0.55 + j * 0.13)), Vector3.ONE * 0.02, 3, 6, SAGE_FLOWER, 0.0, null, 0.15)


# ------------------------------------------------------------------ seed packets

const PACKET_COLORS: Dictionary = {&"corn": Color("#E9C24A"), &"prickly_pear": Color("#C24A86"),
	&"firecracker_chili": Color("#D2442A"), &"herbs": Color("#7FA07A")}


## A paper seed packet (about 9 x 13 cm) with a coloured band, a little
## illustration of the crop on the front, and a folded top. Front faces -Z.
static func packet(crop: StringName) -> ArrayMesh:
	var key := "packet:%s" % crop
	if _cache.has(key):
		return _cache[key]
	var st := MeshKit.begin()
	var paper := Color("#F2E3C2")
	var band: Color = PACKET_COLORS.get(crop, paper)
	var w := 0.09
	var h := 0.13
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, h * 0.5, 0)), Vector3(w, h, 0.012), paper)
	# Crimped, folded top flap.
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, h + 0.008, 0.002)), Vector3(w, 0.02, 0.006), paper.darkened(0.08))
	for i in 7:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-w * 0.45 + i * w * 0.15, h + 0.019, 0.002)), Vector3(0.006, 0.006, 0.008), paper.darkened(0.12))
	# Coloured band with a darker stripe, then the picture window.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, h * 0.82, -0.0062)), Vector3(w, h * 0.22, 0.001), band)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, h * 0.7, -0.0063)), Vector3(w, 0.004, 0.001), band.darkened(0.3))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, h * 0.38, -0.0062)), Vector3(w * 0.78, h * 0.5, 0.001), Color("#FFF8E8"))
	var pic := Vector3(0, h * 0.38, -0.0075)
	match crop:
		&"corn":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, 0.4), pic), Vector3(0.012, 0.028, 0.002), 3, 8, CORN)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, 0.9), pic + Vector3(0.012, -0.012, 0)), Vector3(0.006, 0.022, 0.002), 3, 6, LEAF)
		&"prickly_pear":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), pic + Vector3(0, -0.006, 0)), Vector3(0.018, 0.024, 0.002), 3, 8, PAD)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), pic + Vector3(0.01, 0.018, -0.0005)), Vector3(0.009, 0.011, 0.002), 3, 6, PEAR)
		&"firecracker_chili":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, -0.6), pic), Vector3(0.008, 0.028, 0.002), 3, 8, CHILI)
			MeshKit.add_box(st, Transform3D(Basis(), pic + Vector3(-0.012, 0.024, 0)), Vector3(0.004, 0.012, 0.002), CHILI_GREEN)
		_:
			for k in 3:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, -0.5 + k * 0.5), pic + Vector3(-0.012 + k * 0.012, 0.004 * (k % 2), 0)), Vector3(0.007, 0.018, 0.002), 3, 6, SAGE_DARK)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), pic + Vector3(0, 0.022, 0)), Vector3(0.006, 0.006, 0.002), 3, 6, SAGE_FLOWER)
	# Text lines suggested by thin ink bars.
	for i in 2:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, h * 0.08 + i * 0.009, -0.0063)), Vector3(w * (0.7 - i * 0.2), 0.003, 0.001), Color("#3A2416"))
	var mesh := MeshKit.finish(st)
	_cache[key] = mesh
	return mesh


## A little display rack of packets for each crop (for the vendor's cart).
static func packet_rack() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.07, 0.02)), Vector3(0.48, 0.16, 0.02), Palette.WOOD)
	var crops: Array[StringName] = [&"corn", &"prickly_pear", &"firecracker_chili", &"herbs"]
	for i in crops.size():
		var tilt := Basis(Vector3.RIGHT, -0.35)
		st.append_from(packet(crops[i]), 0, Transform3D(tilt, Vector3(-0.18 + i * 0.12, 0.02, -0.005) + tilt * Vector3(0, 0, -0.012)))
	return MeshKit.finish(st)

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
const SARSA_VINE := Color("#4E7A3A")
const SARSA_LEAF := Color("#3F8A48")
const SARSA_LEAF_DARK := Color("#2F6C3A")
const SARSA_ROOT := Color("#8A5432")
const SARSA_BERRY := Color("#2E2440")
const STAKE := Color("#9A7A52")
# Turret ammo crops (farming redesign).
const COTTON_LEAF := Color("#5C8F45")
const COTTON_BOLL := Color("#7FA54E")
const COTTON := Color("#F5F5DC")
const SULFUR := Color("#DAA520")
const SULFUR_SHOOT := Color("#A7B347")
const SULFUR_CRYSTAL := Color("#F4D03F")
const CACTUS := Color("#228B22")
const CACTUS_RIB := Color("#1A6E1A")
const CACTUS_FLOWER := Color("#D9302A")
const TUMBLE := Color("#8B7355")
const TUMBLE_DRY := Color("#B49A6E")
const TUMBLE_GREEN := Color("#6E8A4A")

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
		var tint := SAGE if crop == &"herbs" else (PAD if crop == &"prickly_pear" else (SARSA_LEAF if crop == &"sarsaparilla" else LEAF))
		if crop == &"sulfur_root":
			# A curling yellow-green shoot out of yellow-tinged soil.
			MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0, 0.015, 0)), Vector3(0.12, 0.02, 0.1), 3, 8, SULFUR.darkened(0.35))
			MeshKit.add_limb(st, at, at + Vector3(0, 0.1, 0), 0.012, SULFUR_SHOOT, 4)
			MeshKit.add_limb(st, at + Vector3(0, 0.1, 0), at + b * Vector3(0.04, 0.13, 0), 0.01, SULFUR_SHOOT, 4)
			return
		if crop == &"barrel_cactus":
			MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0, 0.045, 0)), Vector3(0.05, 0.045, 0.05), 4, 8, CACTUS)
			return
		if crop == &"tumbleweed_vine":
			for k in 3:
				var a := float(k) * 2.1
				MeshKit.add_limb(st, at, at + b * Vector3(cos(a) * 0.07, 0.06 + k * 0.02, sin(a) * 0.07), 0.006, TUMBLE, 3)
			return
		if crop == &"cotton":
			tint = COTTON_LEAF
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
		&"sarsaparilla":
			_sarsaparilla(st, b, at, stage, size, rng)
		&"cotton":
			_cotton(st, b, at, stage, size, rng)
		&"sulfur_root":
			_sulfur_root(st, b, at, stage, size, rng)
		&"barrel_cactus":
			_barrel_cactus(st, b, at, stage, size, rng)
		&"tumbleweed_vine":
			_tumbleweed(st, b, at, stage, size, rng)
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


## Sarsaparilla: a twining vine up a whittled stake, glossy heart-shaped leaves,
## clusters of near-black berries, and the knobbly brown root pushing out of the
## soil when ripe (that's the harvest: tonic root).
static func _sarsaparilla(st: SurfaceTool, b: Basis, at: Vector3, stage: int, size: float, rng: RandomNumberGenerator) -> void:
	var h: float = [0.0, 0.0, 0.42, 0.78, 0.82][stage] * size
	# The stake, a touch taller than the vine, with a split top.
	var stake_h := maxf(h + 0.08, 0.3)
	MeshKit.add_cylinder(st, Transform3D(b, at + b * Vector3(0.05, stake_h * 0.5, 0)), 0.014, 0.018, stake_h, 5, STAKE)
	MeshKit.add_cylinder(st, Transform3D(b, at + b * Vector3(0.05, stake_h + 0.01, 0)), 0.0, 0.014, 0.03, 5, STAKE.darkened(0.15))
	# The vine twines up round the stake in a spiral of short limbs.
	var turns := 2.2 * h / 0.8
	var steps := int(6 + 10 * h)
	var prev := at + b * Vector3(0.05 + 0.04, 0.0, 0.0)
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var a := t * turns * TAU
		var p := at + b * Vector3(0.05 + cos(a) * 0.04, t * h, sin(a) * 0.04)
		MeshKit.add_limb(st, prev, p, 0.007, SARSA_VINE, 3)
		prev = p
		# A heart-shaped leaf every other step, on a short stalk pointing outwards.
		if i % 2 == 0:
			var out := (b * Vector3(cos(a), 0.25, sin(a))).normalized()
			var leaf_at := p + out * 0.07 * size
			MeshKit.add_limb(st, p, leaf_at, 0.004, SARSA_VINE, 3)
			var lb := MeshKit.basis_from_y(out) * Basis(Vector3.UP, rng.randf_range(-0.4, 0.4))
			var col := SARSA_LEAF if (i / 2) % 2 == 0 else SARSA_LEAF_DARK
			var leaf := 0.85 + 0.3 * t
			# Two lobes and a tip make the heart.
			for s: float in [-1.0, 1.0]:
				MeshKit.add_ellipsoid(st, Transform3D(lb, leaf_at + lb * Vector3(s * 0.022, 0.012, 0) * leaf), Vector3(0.03, 0.035, 0.006) * leaf * size, 3, 7, col)
			MeshKit.add_ellipsoid(st, Transform3D(lb, leaf_at + lb * Vector3(0, 0.045, 0) * leaf), Vector3(0.02, 0.03, 0.006) * leaf * size, 3, 6, col)
			if stage >= 3 and i % 4 == 0:
				# A hanging cluster of berries: green while growing, near-black when ripe.
				var berry := SARSA_BERRY if stage == 4 else Color("#6E8A4A")
				var hang := p + out * 0.035 - Vector3(0, 0.03, 0)
				MeshKit.add_limb(st, p, hang, 0.003, SARSA_VINE, 3)
				for k in 5:
					var ka := float(k) * 1.3
					MeshKit.add_ellipsoid(st, Transform3D(Basis(), hang + Vector3(cos(ka) * 0.014, -0.012 * (k % 3), sin(ka) * 0.014)), Vector3.ONE * 0.011, 3, 6, berry, 0.0, null, 0.2 if stage == 4 else 0.0)
	if stage == 4:
		# Ripe: the thick, knobbly roots break the soil at the foot of the vine.
		for k in 3:
			var a := float(k) * 2.1 + rng.randf()
			var from := at + b * Vector3(0.0, 0.03, 0.0)
			var to := at + b * Vector3(cos(a) * 0.16, 0.015, sin(a) * 0.16)
			MeshKit.add_limb(st, from, to, 0.024, SARSA_ROOT, 5)
			MeshKit.add_ellipsoid(st, Transform3D(b, to), Vector3(0.03, 0.025, 0.03), 3, 6, SARSA_ROOT.darkened(0.15))
		MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0, 0.03, 0)), Vector3(0.05, 0.035, 0.05), 4, 8, SARSA_ROOT)


## Cotton: a bushy plant with broad leaves, green bolls, then bolls burst open
## into white fluff when ripe.
static func _cotton(st: SurfaceTool, b: Basis, at: Vector3, stage: int, size: float, rng: RandomNumberGenerator) -> void:
	var h: float = [0.0, 0.0, 0.34, 0.6, 0.62][stage] * size
	MeshKit.add_cylinder(st, Transform3D(b, at + Vector3(0, h * 0.5, 0)), 0.018, 0.012, h, 5, STEM.darkened(0.2))
	var branches: int = [0, 0, 4, 6, 6][stage]
	for i in branches:
		var a := float(i) * TAU / branches + rng.randf_range(-0.3, 0.3)
		var dir := b * Vector3(cos(a), 0, sin(a))
		var from := at + Vector3(0, h * rng.randf_range(0.35, 0.85), 0)
		var to := from + dir * 0.13 * size + Vector3.UP * 0.08 * size
		MeshKit.add_limb(st, from, to, 0.008, STEM.darkened(0.2), 3)
		# Broad three-lobed leaf.
		var lb := MeshKit.basis_from_y((dir + Vector3.UP * 0.4).normalized())
		MeshKit.add_ellipsoid(st, Transform3D(lb, to), Vector3(0.07, 0.05, 0.012) * size, 3, 7, COTTON_LEAF if i % 2 else COTTON_LEAF.darkened(0.15))
		if stage >= 3:
			var boll := to + Vector3(0, 0.06, 0) + dir * 0.02
			if stage == 4:
				# Burst boll: brown calyx with a fluffy white puff.
				MeshKit.add_ellipsoid(st, Transform3D(b, boll - Vector3(0, 0.02, 0)), Vector3(0.025, 0.02, 0.025), 3, 6, TUMBLE)
				for k in 4:
					var ka := float(k) * 1.57 + rng.randf()
					MeshKit.add_ellipsoid(st, Transform3D(b, boll + Vector3(cos(ka) * 0.018, 0.01, sin(ka) * 0.018)), Vector3.ONE * 0.026, 3, 6, COTTON, 0.0, null, 0.1)
			else:
				MeshKit.add_ellipsoid(st, Transform3D(b, boll), Vector3(0.025, 0.032, 0.025), 3, 6, COTTON_BOLL)


## Sulfur root: a gnarly root that heaves out of cracked soil, sprouting yellow
## crystals, bright and smoking faintly when ripe.
static func _sulfur_root(st: SurfaceTool, b: Basis, at: Vector3, stage: int, size: float, rng: RandomNumberGenerator) -> void:
	MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0, 0.015, 0)), Vector3(0.2, 0.025, 0.17), 3, 8, SULFUR.darkened(0.4))
	var knots: int = [0, 0, 3, 5, 6][stage]
	var prev := at + Vector3(0, 0.02, 0)
	for i in knots:
		var a := float(i) * 1.9 + rng.randf()
		var p := at + b * Vector3(cos(a) * 0.09, 0.04 + 0.03 * float(i % 2), sin(a) * 0.09) * size
		MeshKit.add_limb(st, prev, p, 0.028 * size, SULFUR.darkened(0.25 if stage < 4 else 0.0), 5)
		MeshKit.add_ellipsoid(st, Transform3D(b, p), Vector3(0.035, 0.03, 0.035) * size, 3, 6, SULFUR.darkened(0.15 if stage < 4 else 0.0))
		prev = p
		if stage >= 3:
			# Crystals: pointed yellow shards on the knots.
			var c_dir := (b * Vector3(cos(a), 1.2, sin(a))).normalized()
			var cb := MeshKit.basis_from_y(c_dir)
			MeshKit.add_cylinder(st, Transform3D(cb, p + c_dir * 0.04), 0.018, 0.0, 0.07 * (1.3 if stage == 4 else 0.8), 4, SULFUR_CRYSTAL, true, 0.35 if stage == 4 else 0.0)
	# A curl of yellow-green leaf on top.
	MeshKit.add_limb(st, at + Vector3(0, 0.04, 0), at + Vector3(0, 0.16 * size, 0), 0.01, SULFUR_SHOOT, 4)
	MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0, 0.17 * size, 0)), Vector3(0.04, 0.02, 0.03), 3, 6, SULFUR_SHOOT)
	if stage == 4:
		# Faint sulfur wisps.
		for k in 2:
			MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0.03 * k, 0.26 + 0.08 * k, 0.0)), Vector3(0.05, 0.035, 0.05) * (1.0 + k * 0.4), 3, 6, Color(0.95, 0.9, 0.6, 1.0), 0.0, null, 0.1)


## Barrel cactus: a squat ribbed ball that swells into a barrel, spines along the
## ribs, and a crown of red flowers when ripe (the harvest tell).
static func _barrel_cactus(st: SurfaceTool, b: Basis, at: Vector3, stage: int, size: float, _rng: RandomNumberGenerator) -> void:
	var r: float = [0.0, 0.0, 0.1, 0.17, 0.19][stage] * size
	var h: float = [0.0, 0.0, 0.16, 0.3, 0.34][stage] * size
	MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0, h * 0.5, 0)), Vector3(r, h * 0.55, r), 6, 12, CACTUS)
	var ribs := 10
	for i in ribs:
		var a := float(i) * TAU / ribs
		var dir := b * Vector3(cos(a), 0, sin(a))
		var rb := Basis(dir.cross(Vector3.UP).normalized(), Vector3.UP, dir)
		MeshKit.add_ellipsoid(st, Transform3D(rb, at + Vector3(0, h * 0.5, 0) + dir * r * 0.82), Vector3(0.018, h * 0.5, 0.03) * Vector3(1, 1, size), 4, 6, CACTUS_RIB)
		for k in 3:
			var y := h * (0.25 + 0.25 * k)
			var spine_at := at + Vector3(0, y, 0) + dir * r * 1.02
			MeshKit.add_limb(st, spine_at, spine_at + dir * 0.03 + Vector3.UP * 0.01, 0.003, SPINE, 3)
	if stage == 4:
		for k in 6:
			var a := float(k) * TAU / 6.0
			MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0, h * 1.02, 0) + b * Vector3(cos(a), 0, sin(a)) * r * 0.35), Vector3(0.028, 0.02, 0.028), 3, 6, CACTUS_FLOWER, 0.0, null, 0.2)
		MeshKit.add_ellipsoid(st, Transform3D(b, at + Vector3(0, h * 1.05, 0)), Vector3.ONE * 0.02, 3, 6, BLOOM)


## Tumbleweed vine: tendrils that spread into a thorny mat, then a dry round
## tumbleweed ball forms over the vines, ready to break off.
static func _tumbleweed(st: SurfaceTool, b: Basis, at: Vector3, stage: int, size: float, rng: RandomNumberGenerator) -> void:
	var spread: float = [0.0, 0.0, 0.16, 0.26, 0.26][stage] * size
	var vines: int = [0, 0, 5, 8, 8][stage]
	for i in vines:
		var a := float(i) * TAU / vines + rng.randf_range(-0.2, 0.2)
		var mid := at + b * Vector3(cos(a) * spread * 0.5, 0.05, sin(a) * spread * 0.5)
		var tip := at + b * Vector3(cos(a + 0.4) * spread, 0.02, sin(a + 0.4) * spread)
		MeshKit.add_limb(st, at + Vector3(0, 0.02, 0), mid, 0.007, TUMBLE_GREEN if stage < 4 else TUMBLE, 3)
		MeshKit.add_limb(st, mid, tip, 0.005, TUMBLE_GREEN if stage < 4 else TUMBLE, 3)
		if stage >= 3:
			for k in 2:
				var tp := mid.lerp(tip, 0.3 + k * 0.4)
				MeshKit.add_limb(st, tp, tp + Vector3.UP * 0.025 + b * Vector3(cos(a), 0, sin(a)) * 0.01, 0.002, SPINE, 3)
	if stage == 4:
		# The ball: a tangle of dry twigs round a hollow centre.
		var c := at + Vector3(0, 0.2 * size, 0)
		var br := 0.16 * size
		for k in 18:
			var u := rng.randf() * TAU
			var v := rng.randf_range(-1.0, 1.0)
			var d := Vector3(cos(u) * sqrt(1.0 - v * v), v, sin(u) * sqrt(1.0 - v * v))
			var e := d.rotated(Vector3.UP, 1.3).rotated(Vector3.RIGHT, 0.7)
			MeshKit.add_limb(st, c + d * br, c + e * br, 0.006, TUMBLE_DRY if k % 2 else TUMBLE, 3)
		MeshKit.add_ellipsoid(st, Transform3D(b, c), Vector3.ONE * br * 0.7, 3, 7, TUMBLE.darkened(0.2))


# ------------------------------------------------------------------ seed packets

const PACKET_COLORS: Dictionary = {&"corn": Color("#E9C24A"), &"prickly_pear": Color("#C24A86"),
	&"firecracker_chili": Color("#D2442A"), &"herbs": Color("#7FA07A"), &"sarsaparilla": Color("#7A4A2E"),
	&"cotton": Color("#E4DFC4"), &"sulfur_root": Color("#DAA520"), &"barrel_cactus": Color("#2E8B3A"), &"tumbleweed_vine": Color("#8B7355")}


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
	_picture(st, crop, pic)
	# Text lines suggested by thin ink bars.
	for i in 2:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, h * 0.08 + i * 0.009, -0.0063)), Vector3(w * (0.7 - i * 0.2), 0.003, 0.001), Color("#3A2416"))
	var mesh := MeshKit.finish(st)
	_cache[key] = mesh
	return mesh


## The little picture of a crop on its seed packet (and on its ammo sack's
## patch): about 5 cm across, centred on `pic`, facing -Z.
static func _picture(st: SurfaceTool, crop: StringName, pic: Vector3) -> void:
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
		&"sarsaparilla":
			# A heart leaf over a knobbly root.
			for s: float in [-1.0, 1.0]:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), pic + Vector3(s * 0.008, 0.018, 0)), Vector3(0.01, 0.011, 0.002), 3, 6, SARSA_LEAF)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), pic + Vector3(0, 0.01, 0)), Vector3(0.007, 0.01, 0.002), 3, 6, SARSA_LEAF)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, 0.5), pic + Vector3(0, -0.016, 0)), Vector3(0.007, 0.02, 0.002), 3, 6, SARSA_ROOT)
		&"cotton":
			for k in 3:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), pic + Vector3(-0.009 + k * 0.009, 0.006 * (k % 2), 0)), Vector3(0.009, 0.009, 0.002), 3, 6, COTTON.darkened(0.05))
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), pic + Vector3(0, -0.014, 0)), Vector3(0.012, 0.006, 0.002), 3, 6, COTTON_LEAF)
		&"sulfur_root":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, 0.6), pic), Vector3(0.01, 0.024, 0.002), 3, 6, SULFUR)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.3), pic + Vector3(0.01, 0.016, 0)), Vector3(0.005, 0.012, 0.002), SULFUR_CRYSTAL)
		&"barrel_cactus":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), pic + Vector3(0, -0.004, 0)), Vector3(0.018, 0.02, 0.002), 3, 8, CACTUS)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), pic + Vector3(0, 0.018, -0.0005)), Vector3(0.008, 0.005, 0.002), 3, 6, CACTUS_FLOWER)
		&"tumbleweed_vine":
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), pic + Vector3(0, 0.004, 0)), Vector3(0.019, 0.019, 0.002), 3, 8, TUMBLE_DRY)
			MeshKit.add_box(st, Transform3D(Basis(), pic + Vector3(0, -0.02, 0)), Vector3(0.03, 0.003, 0.002), TUMBLE_GREEN)
		_:
			for k in 3:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, -0.5 + k * 0.5), pic + Vector3(-0.012 + k * 0.012, 0.004 * (k % 2), 0)), Vector3(0.007, 0.018, 0.002), 3, 6, SAGE_DARK)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), pic + Vector3(0, 0.022, 0)), Vector3(0.006, 0.006, 0.002), 3, 6, SAGE_FLOWER)


## The crop picture alone as a mesh at the origin, facing -Z (AmmoSackBuilder).
static func picture(crop: StringName) -> ArrayMesh:
	var key := "picture:%s" % crop
	if _cache.has(key):
		return _cache[key]
	var st := MeshKit.begin()
	_picture(st, crop, Vector3.ZERO)
	var mesh := MeshKit.finish(st)
	_cache[key] = mesh
	return mesh


## A little display rack of packets for each crop (for the vendor's cart).
static func packet_rack() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.07, 0.02)), Vector3(0.48, 0.16, 0.02), Palette.WOOD)
	var crops: Array[StringName] = [&"corn", &"prickly_pear", &"firecracker_chili", &"herbs", &"sarsaparilla",
		&"cotton", &"sulfur_root", &"barrel_cactus", &"tumbleweed_vine"]
	for i in crops.size():
		var tilt := Basis(Vector3.RIGHT, -0.35)
		# Two rows: the first five on the bottom, the turret-ammo crops above.
		var row := 0 if i < 5 else 1
		var col := i if i < 5 else i - 5
		st.append_from(packet(crops[i]), 0, Transform3D(tilt, Vector3(-0.2 + col * 0.1 + row * 0.05, 0.02 + row * 0.07, -0.005 + row * 0.03) + tilt * Vector3(0, 0, -0.012)))
	return MeshKit.finish(st)

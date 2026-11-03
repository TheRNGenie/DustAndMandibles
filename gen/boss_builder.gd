class_name BossBuilder
extends RefCounted
## Procedural bodies for the bosses (and the small bugs they let loose), in the
## same style and spec format as BugBuilder (which hands boss ids over to build()).
## Local space: forward is -Z (head), up is +Y (the back). Each boss is built
## around one shape you can read from across the canyon: the Queen's crown and
## hourglass, the Burrower's shovel, the Titan's sun-rake head, the Lord's crown
## and folded jumping legs, the Matriarch's brood and giant acid bulb, the
## Mantis's raised claws, the Wagon's wheels and hive, the Strider's stilts,
## the Cicada's hammer head and tent wings, the Collector's cattle skull, the
## Hive Queen's crown and her banded, plated abdomen.

const GOLD := Color("#E8C55A")
const IVORY := Color("#F2E3C2")


## The spec for `def` (unscaled; BugBuilder scales it), or {} if not a boss part.
static func build(def: BugDef) -> Dictionary:
	match def.base_id():
		&"queen_spider":
			return _queen(def.shell_color)
		&"burrow_beetle":
			return _burrower(def.shell_color)
		&"tumble_titan":
			return _titan(def.shell_color)
		&"locust_lord":
			return _locust_lord(def.shell_color)
		&"acid_matriarch":
			return _matriarch(def.shell_color)
		&"mirage_mantis":
			return _mantis(def.shell_color)
		&"hive_wagon":
			return _wagon(def.shell_color)
		&"stilt_strider":
			return _strider(def.shell_color)
		&"thunder_cicada":
			return _cicada(def.shell_color)
		&"bone_collector":
			return _collector(def.shell_color)
		&"hive_queen":
			return _hive_queen(def.shell_color)
		&"hive_mother":
			return _hive_mother(def.shell_color)
		&"locust":
			return _locust(def.shell_color)
		&"hive_drone":
			return _drone(def.shell_color)
	return {}


# ------------------------------------------------------------------ helpers

static func _e(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, rings: int = 6, segs: int = 12, glow: float = 0.0, b: Basis = Basis()) -> void:
	MeshKit.add_ellipsoid(st, Transform3D(b, c), r, rings, segs, col, 0.0, null, glow)


## A cone (spike, tooth, horn) from `base` pointing along `dir`.
static func _spike(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, r: float, col: Color, segs: int = 6) -> void:
	var d := dir.normalized()
	MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(d), base + d * length * 0.5), r, 0.0, length, segs, col)


## A curved horn or fang through points with a tapering radius.
static func _horn(st: SurfaceTool, pts: Array, r0: float, col: Color, segs: int = 7) -> void:
	var radii: Array = []
	for i in pts.size():
		radii.append(r0 * (1.0 - float(i) / float(pts.size()) * 0.85))
	MeshKit.tube(st, pts, radii, segs, col)


## Legs splayed in a fan round the body (`angles` in degrees from straight ahead).
static func _fan_legs(angles: Array, hip_r: float, hip_y: float, reach: float, foot_y: float, z_off: float = 0.0) -> Array:
	var legs: Array = []
	for a: float in angles:
		for side: float in [-1.0, 1.0]:
			var r := deg_to_rad(a)
			var dir := Vector3(side * sin(r), 0.0, -cos(r))
			legs.append({"hip": Vector3(0, hip_y, z_off) + dir * hip_r, "rest": Vector3(0, foot_y, z_off) + dir * (hip_r + reach)})
	return legs


static func _spec(st: SurfaceTool, legs: Array, upper: float, lower: float, thick: float, leg_color: Color,
		weak: Vector3, weak_r: float, body_r: float, clearance: float, face: Dictionary, ik: bool = true) -> Dictionary:
	return {
		"body": MeshKit.finish(st), "legs": legs, "upper": upper, "lower": lower, "thick": thick,
		"leg_color": leg_color, "ik": ik, "weak_spot": weak, "weak_radius": weak_r,
		"body_radius": body_r, "clearance": clearance, "face": face,
	}


# ------------------------------------------------------------------ the Queen Spider

## A black widow queen: a glossy plum-black abdomen with a glowing red
## hourglass, an ivory crown of spikes, big fangs, spinnerets at the back.
static func _queen(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2101
	var st := MeshKit.begin()
	var red := Color("#C0283A")
	var sheen := shell.lightened(0.22)
	# Cephalothorax with a pale crown.
	_e(st, Vector3(0, 0.18, -0.32), Vector3(0.44, 0.28, 0.48), shell, 7, 14)
	_e(st, Vector3(0, 0.34, -0.3), Vector3(0.26, 0.1, 0.34), sheen, 4, 10)
	for k in 5:
		var a := lerpf(-0.9, 0.9, float(k) / 4.0)
		var base := Vector3(sin(a) * 0.28, 0.4, -0.42 - cos(a) * 0.06)
		var tall := 0.34 if k == 2 else (0.26 if k % 2 == 1 else 0.2)
		_spike(st, base, Vector3(sin(a) * 0.35, 1.0, -0.15), tall, 0.065, IVORY)
		_e(st, base + Vector3(sin(a) * 0.35, 1.0, -0.15).normalized() * tall, Vector3.ONE * 0.035, GOLD, 3, 6, 0.3)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.39, -0.42)), 0.3, 0.3, 0.06, 14, GOLD)
	# The huge abdomen, glossy, with banded sheen and the red hourglass on top.
	BugBuilder._segmented(st, Vector3(0, 0.48, 0.66), Vector3(0.78, 0.66, 0.9), 5, shell, shell.lightened(0.1))
	_e(st, Vector3(0.22, 0.86, 0.48), Vector3(0.2, 0.12, 0.3), sheen.lightened(0.2), 4, 8)
	_e(st, Vector3(0, 1.13, 0.5), Vector3(0.17, 0.05, 0.17), red, 4, 10, 0.8)
	_e(st, Vector3(0, 1.1, 0.86), Vector3(0.17, 0.05, 0.17), red, 4, 10, 0.8)
	_e(st, Vector3(0, 1.13, 0.68), Vector3(0.06, 0.04, 0.12), red, 3, 8, 0.8)
	# Red flecks down the sides.
	for s: float in [-1.0, 1.0]:
		for k in 3:
			_e(st, Vector3(s * (0.66 - k * 0.04), 0.5 + k * 0.08, 0.5 + k * 0.25), Vector3(0.05, 0.08, 0.1), red.darkened(0.15), 3, 6)
	# Spinnerets.
	for k in 3:
		var x := (k - 1) * 0.1
		_spike(st, Vector3(x, 0.42, 1.48), Vector3(x * 2.0, -0.2, 1.0), 0.2, 0.06, IVORY.darkened(0.1))
	# Chelicerae and big curved fangs.
	for s: float in [-1.0, 1.0]:
		_e(st, Vector3(s * 0.13, 0.04, -0.78), Vector3(0.12, 0.16, 0.12), shell.lightened(0.05), 5, 8)
		_horn(st, [Vector3(s * 0.13, -0.08, -0.84), Vector3(s * 0.1, -0.24, -0.9), Vector3(s * 0.04, -0.32, -0.82)], 0.05, red.darkened(0.3))
		# Pedipalps.
		MeshKit.add_limb(st, Vector3(s * 0.24, 0.06, -0.7), Vector3(s * 0.32, -0.04, -0.98), 0.05, shell, 6)
		_e(st, Vector3(s * 0.33, -0.06, -1.02), Vector3.ONE * 0.07, red.darkened(0.2), 4, 8)
	BugBuilder._hairs(st, rng, Vector3(0, 0.18, -0.32), Vector3(0.44, 0.28, 0.48), 16, 0.07, sheen)
	BugBuilder._eyes(st, Vector3(0, 0.3, -0.74), 0.11, 0.07, 6)
	var spec := _spec(st, _fan_legs([30.0, 65.0, 105.0, 145.0], 0.36, 0.12, 1.7, -0.5, -0.2),
			1.15, 1.3, 0.065, shell.lightened(0.04), Vector3(0, 1.13, 0.68), 0.32, 1.0, 0.5,
			{"mouth": Vector3(0, 0.0, -0.82), "mandible": 0.0, "antenna": 0.0, "color": shell.darkened(0.3)})
	return spec


# ------------------------------------------------------------------ the Burrowing Beetle

## A digger: a shovel of a head with teeth, two great spade claws, an earthy
## banded body crusted with dirt clods and pebbles.
static func _burrower(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2202
	var st := MeshKit.begin()
	var ochre := Color("#C99A5B")
	var dark := shell.darkened(0.35)
	BugBuilder._segmented(st, Vector3(0, 0.26, 0.32), Vector3(0.64, 0.44, 0.92), 6, shell, ochre.darkened(0.15))
	# The pronotum: a heavy round shield with a ridge.
	_e(st, Vector3(0, 0.34, -0.42), Vector3(0.7, 0.48, 0.46), shell.lightened(0.06), 7, 14)
	_e(st, Vector3(0, 0.78, -0.42), Vector3(0.08, 0.06, 0.36), dark, 4, 8)
	# The shovel: a flat wide scoop with a row of teeth and a dark rim.
	_e(st, Vector3(0, 0.06, -0.98), Vector3(0.66, 0.11, 0.36), dark, 5, 14)
	_e(st, Vector3(0, 0.12, -0.92), Vector3(0.54, 0.1, 0.28), shell.lightened(0.12), 4, 12)
	for k in 7:
		var x := lerpf(-0.54, 0.54, float(k) / 6.0)
		var z := -1.26 + absf(x) * 0.42
		_spike(st, Vector3(x, 0.04, z + 0.06), Vector3(x * 0.3, -0.05, -1.0), 0.24, 0.07, IVORY.darkened(0.15))
	# Spade claws out to each side, each with three digging teeth.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_limb(st, Vector3(s * 0.48, 0.12, -0.6), Vector3(s * 0.82, 0.02, -0.84), 0.11, dark, 8)
		_e(st, Vector3(s * 0.88, 0.0, -0.92), Vector3(0.26, 0.09, 0.22), shell.lightened(0.05), 5, 10, 0.0, Basis(Vector3.UP, s * 0.5))
		for k in 3:
			var a := s * (0.2 + k * 0.35)
			_spike(st, Vector3(s * 0.9, -0.02, -0.92) + Vector3(sin(a), 0, -cos(a)) * 0.2, Vector3(sin(a), -0.1, -cos(a)), 0.2, 0.05, IVORY.darkened(0.2))
	# Dirt clods and pebbles riding on its back.
	for k in 14:
		var a := rng.randf_range(-1.0, 1.0)
		var z := rng.randf_range(-0.2, 1.0)
		var p := Vector3(a * 0.5, 0.26 + 0.44 * sqrt(maxf(1.0 - a * a * 0.6 - pow((z - 0.32) / 0.92, 2.0), 0.05)), z)
		var col := Palette.DIRT_DARK if k % 3 != 0 else Palette.ROCK_C
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(rng.randf_range(0.07, 0.14), rng.randf_range(0.05, 0.1), rng.randf_range(0.07, 0.14)), 3, 6, col, 0.15, rng)
	BugBuilder._weak(st, Vector3(0, 0.74, 0.0), Vector3(0.16, 0.06, 0.16), Color("#FFB347"))
	BugBuilder._eyes(st, Vector3(0, 0.3, -0.84), 0.34, 0.07)
	return _spec(st, BugBuilder._legs(3, -0.25, 0.85, 0.5, 0.0, 0.62, -0.32),
			0.55, 0.6, 0.11, dark, Vector3(0, 0.74, 0.0), 0.24, 1.0, 0.42,
			{"mouth": Vector3(0, -0.02, -1.0), "mandible": 0.0, "antenna": 0.22, "color": dark, "antenna_at": Vector3(0, 0.3, -0.82)})


# ------------------------------------------------------------------ the Tumble Titan

## A giant scarab: emerald domed wing cases rimmed in gold, and the famous
## sun-rake head, a flat fan of teeth for shoving its boulder up the wall.
static func _titan(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2303
	var st := MeshKit.begin()
	var shine := shell.lightened(0.35)
	var dark := shell.darkened(0.45)
	for s: float in [-1.0, 1.0]:
		_e(st, Vector3(s * 0.33, 0.32, 0.3), Vector3(0.38, 0.5, 0.84), shell, 8, 14, 0.0, Basis(Vector3.BACK, s * 0.08))
		_e(st, Vector3(s * 0.34, 0.29, 0.3), Vector3(0.4, 0.44, 0.86), GOLD.darkened(0.1), 4, 14, 0.0, Basis(Vector3.BACK, s * 0.08))
		_e(st, Vector3(s * 0.36, 0.7, 0.12), Vector3(0.12, 0.07, 0.38), shine, 4, 8)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.82, 0.32)), Vector3(0.04, 0.05, 1.5), dark)
	# Pronotum.
	_e(st, Vector3(0, 0.34, -0.48), Vector3(0.7, 0.44, 0.42), shell.lightened(0.08), 7, 14)
	_e(st, Vector3(0.22, 0.62, -0.52), Vector3(0.16, 0.07, 0.16), shine, 4, 8)
	# The sun rake: a half-disc head plate with radiating teeth, gold edged.
	_e(st, Vector3(0, 0.14, -0.9), Vector3(0.62, 0.1, 0.36), dark, 5, 14)
	_e(st, Vector3(0, 0.2, -0.88), Vector3(0.52, 0.09, 0.3), shell, 4, 14)
	for k in 9:
		var a := lerpf(-1.3, 1.3, float(k) / 8.0)
		var base := Vector3(sin(a) * 0.55, 0.16, -0.9 - cos(a) * 0.3)
		_spike(st, base, Vector3(sin(a), 0.08, -cos(a)), 0.26 if k % 2 == 0 else 0.18, 0.06, GOLD)
	_e(st, Vector3(0, 0.3, -0.86), Vector3(0.1, 0.08, 0.14), GOLD, 3, 8, 0.4)
	BugBuilder._spots(st, rng, Vector3(0, 0.34, -0.48), Vector3(0.7, 0.44, 0.42), 6, 0.04, shine)
	BugBuilder._weak(st, Vector3(0, 0.3, 1.1), Vector3(0.24, 0.12, 0.1), Color("#FFD23F"))
	BugBuilder._eyes(st, Vector3(0, 0.3, -0.78), 0.3, 0.07)
	return _spec(st, BugBuilder._legs(3, -0.4, 0.75, 0.56, 0.0, 0.8, -0.38),
			0.7, 0.78, 0.1, dark, Vector3(0, 0.3, 1.1), 0.28, 1.0, 0.46,
			{"mouth": Vector3(0, 0.04, -0.96), "mandible": 0.12, "antenna": 0.2, "color": dark, "antenna_at": Vector3(0, 0.3, -0.78)})


## The Titan's boulder (radius 1 before scaling): sandstone, lumpy, with straw and dung.
static func boulder_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2304
	var st := MeshKit.begin()
	# Dark packed dung-and-earth, so it stands out against the red rock, with pale stones in it.
	MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE, 9, 16, Color("#5E4128"), 0.1, rng)
	for k in 16:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		MeshKit.add_ellipsoid(st, Transform3D(MeshKit.basis_from_y(d), d * 0.92), Vector3(0.28, 0.12, 0.24) * rng.randf_range(0.6, 1.2), 3, 7,
				Color("#D9C9A3") if k % 3 == 0 else Color("#7A5636"), 0.1, rng)
	for k in 30:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var e := (d + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))).normalized()
		MeshKit.add_limb(st, d * 1.0, e * 1.05, 0.02, Color("#D9B25E"), 3)
	return MeshKit.finish(st)


# ------------------------------------------------------------------ the Locust Swarm Lord

## A winged king locust: a gold crown, huge compound eyes, a long striped
## abdomen with a glowing swarm sac under it, and big folded jumping legs.
static func _locust_lord(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2404
	var st := MeshKit.begin()
	var brown := Color("#7A5A2E")
	var pale := shell.lightened(0.3)
	# Thorax with a brown saddle.
	_e(st, Vector3(0, 0.12, -0.18), Vector3(0.3, 0.3, 0.44), shell, 6, 12)
	_e(st, Vector3(0, 0.36, -0.18), Vector3(0.24, 0.1, 0.38), brown, 4, 10)
	# Long abdomen, striped, tapering.
	for i in 7:
		var r := 0.25 - i * 0.022
		_e(st, Vector3(0, 0.08 - i * 0.01, 0.3 + i * 0.17), Vector3(r, r * 0.9, 0.12), shell if i % 2 == 0 else brown, 4, 10)
	# The swarm sac, swollen and glowing under the abdomen.
	_e(st, Vector3(0, -0.12, 0.55), Vector3(0.2, 0.15, 0.32), Color("#F2B33D"), 5, 10, 0.6)
	# Head, blunt, with a crown.
	_e(st, Vector3(0, 0.12, -0.72), Vector3(0.26, 0.3, 0.24), shell.lightened(0.05), 6, 12)
	_e(st, Vector3(0, -0.12, -0.84), Vector3(0.14, 0.1, 0.08), brown, 4, 8)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.44, -0.72)), 0.17, 0.19, 0.1, 12, GOLD)
	for k in 5:
		var a := TAU * float(k) / 5.0
		_spike(st, Vector3(cos(a) * 0.17, 0.48, -0.72 + sin(a) * 0.17), Vector3(cos(a) * 0.25, 1.0, sin(a) * 0.25), 0.16, 0.05, GOLD)
		_e(st, Vector3(cos(a) * 0.17, 0.46, -0.72 + sin(a) * 0.17), Vector3.ONE * 0.03, Color("#C0283A"), 3, 6, 0.4)
	# Folded jumping legs: a fat thigh up and back, the shin folded down along it.
	for s: float in [-1.0, 1.0]:
		var hip := Vector3(s * 0.24, 0.06, 0.0)
		var knee := Vector3(s * 0.36, 0.42, 0.78)
		var foot := Vector3(s * 0.32, -0.12, 0.66)
		MeshKit.tube(st, [hip, hip.lerp(knee, 0.4) + Vector3(s * 0.04, 0.05, 0), knee], [0.13, 0.12, 0.06], 8, pale)
		MeshKit.add_limb(st, knee, foot, 0.04, brown, 6)
		for k in 4:
			var p := knee.lerp(foot, 0.2 + k * 0.2)
			_spike(st, p, Vector3(0, -0.2, 1.0), 0.07, 0.015, Color("#C0283A"))
		# Stripes on the thigh.
		for k in 3:
			_e(st, hip.lerp(knee, 0.3 + k * 0.2) + Vector3(s * 0.08, 0.02, 0), Vector3(0.04, 0.1, 0.04), brown, 3, 6)
	BugBuilder._eyes(st, Vector3(0, 0.2, -0.8), 0.2, 0.12)
	return _spec(st, BugBuilder._legs(2, -0.38, -0.08, 0.2, -0.08, 0.22, -0.35),
			0.2, 0.22, 0.04, brown, Vector3(0, -0.12, 0.55), 0.3, 0.65, 0.0,
			{"mouth": Vector3(0, -0.14, -0.88), "mandible": 0.1, "antenna": 0.5, "color": brown,
				"antenna_at": Vector3(0, 0.3, -0.86), "wings": true}, false)


# ------------------------------------------------------------------ the Acid Matriarch

## A scorpion queen: banded armour with acid-green markings, a spiny crest,
## giant claws, her brood riding on her back and a huge glowing acid bulb.
static func _matriarch(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2505
	var st := MeshKit.begin()
	var acid := Palette.ACID_GREEN
	var dark := shell.darkened(0.4)
	for i in 6:
		var w := 0.5 - absf(i - 2.0) * 0.04
		var z := -0.4 + i * 0.22
		_e(st, Vector3(0, 0.13, z), Vector3(w, 0.22, 0.17), shell if i % 2 == 0 else shell.darkened(0.12), 5, 12)
		_e(st, Vector3(0, 0.26, z), Vector3(w * 0.62, 0.12, 0.13), shell.lightened(0.15), 4, 10)
		for s: float in [-1.0, 1.0]:
			_e(st, Vector3(s * w * 0.55, 0.3, z), Vector3(0.05, 0.03, 0.08), acid, 3, 6, 0.6)
	# A crest of spines on the head shield.
	for k in 5:
		var x := (k - 2) * 0.1
		_spike(st, Vector3(x, 0.34, -0.5), Vector3(x, 1.0, 0.2), 0.16 + (0.08 if k == 2 else 0.0), 0.04, IVORY.darkened(0.1))
	# The brood on her back: little pale scorpions with curled tails.
	for k in 6:
		var p := Vector3(rng.randf_range(-0.3, 0.3), 0.4, -0.2 + k * 0.17)
		var yaw := rng.randf() * TAU
		_e(st, p, Vector3(0.08, 0.05, 0.11), IVORY.darkened(0.05), 3, 8, 0.0, Basis(Vector3.UP, yaw))
		var tail := Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.1)
		MeshKit.add_limb(st, p + tail, p + tail * 1.6 + Vector3(0, 0.08, 0), 0.02, IVORY.darkened(0.15), 4)
	# Giant claws.
	for side: float in [-1.0, 1.0]:
		var a := Vector3(side * 0.3, 0.1, -0.5)
		var b := Vector3(side * 0.66, 0.18, -0.86)
		MeshKit.add_limb(st, a, b, 0.1, shell.darkened(0.1), 8)
		var c := b + Vector3(side * 0.06, 0.03, -0.3)
		_e(st, c, Vector3(0.24, 0.17, 0.3), shell.darkened(0.2), 6, 12)
		_e(st, c + Vector3(0, 0.1, 0), Vector3(0.14, 0.06, 0.2), acid.darkened(0.25), 3, 8)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, side * 0.25), c + Vector3(side * 0.06, 0.05, -0.34)), 0.09, 0.0, 0.42, 7, dark)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, -side * 0.15), c + Vector3(-side * 0.07, -0.03, -0.3)), 0.07, 0.0, 0.32, 7, dark)
		BugBuilder._spots(st, rng, c, Vector3(0.24, 0.17, 0.3), 4, 0.03, acid)
	# The tail, curling high over her back to a huge acid bulb.
	var prev := Vector3(0, 0.15, 0.82)
	for i in 7:
		var t := float(i + 1) / 7.0
		var p := Vector3(0, 0.15 + sin(t * PI * 0.88) * 1.25, 0.82 + cos(t * PI * 0.95) * 0.42 + t * 0.1 - 0.42)
		MeshKit.add_limb(st, prev, p, 0.13 - i * 0.01, shell if i % 2 == 0 else shell.darkened(0.12), 8)
		_e(st, (prev + p) * 0.5 + Vector3(0, 0.08, 0), Vector3(0.04, 0.03, 0.05), acid, 3, 6, 0.6)
		prev = p
	var bulb := prev + Vector3(0, 0.08, -0.12)
	_e(st, bulb, Vector3(0.24, 0.22, 0.26), acid, 6, 12, 0.7)
	_e(st, bulb + Vector3(0.08, 0.1, -0.06), Vector3(0.07, 0.05, 0.07), Color.WHITE, 3, 6, 0.4)
	_spike(st, bulb + Vector3(0, -0.12, -0.18), Vector3(0, -0.8, -0.6), 0.3, 0.06, IVORY)
	BugBuilder._eyes(st, Vector3(0, 0.33, -0.5), 0.1, 0.07)
	var spec := _spec(st, BugBuilder._legs(4, -0.3, 0.5, 0.36, 0.0, 0.7, -0.28),
			0.55, 0.6, 0.065, dark, bulb, 0.3, 0.8, 0.36,
			{"mouth": Vector3(0, 0.05, -0.6), "mandible": 0.1, "antenna": 0.0, "color": dark})
	spec["bulb"] = bulb
	return spec


# ------------------------------------------------------------------ the Mirage Mantis

## A praying mantis the colour of hot sand: a tall neck, a triangle head with big
## eyes, raptorial claws held up ready, leaf-flapped abdomen. Drawn on her own
## (solo) so her heat-haze shimmer can fade her in and out.
static func _mantis(shell: Color) -> Dictionary:
	var st := MeshKit.begin()
	var pearl := shell.lightened(0.35)
	var green := Color("#9BAE5A")
	# Abdomen with leafy side flaps and folded wings over it.
	_e(st, Vector3(0, 0.16, 0.6), Vector3(0.3, 0.2, 0.74), shell, 6, 12)
	for s: float in [-1.0, 1.0]:
		for k in 3:
			_e(st, Vector3(s * 0.3, 0.12, 0.35 + k * 0.28), Vector3(0.1, 0.03, 0.12), shell.darkened(0.1), 3, 8)
	for s: float in [-1.0, 1.0]:
		_e(st, Vector3(s * 0.1, 0.32, 0.62), Vector3(0.17, 0.05, 0.72), pearl, 4, 10, 0.0, Basis(Vector3.BACK, s * 0.12))
		MeshKit.add_limb(st, Vector3(s * 0.1, 0.37, 0.1), Vector3(s * 0.12, 0.37, 1.2), 0.012, green, 3)
	# Mid body, then the long neck rising forward.
	_e(st, Vector3(0, 0.22, -0.05), Vector3(0.18, 0.17, 0.3), shell.darkened(0.06), 5, 10)
	MeshKit.tube(st, [Vector3(0, 0.25, -0.2), Vector3(0, 0.48, -0.42), Vector3(0, 0.74, -0.6)], [0.12, 0.1, 0.09], 8, shell)
	# The triangle head with huge eyes at its corners.
	_e(st, Vector3(0, 0.86, -0.7), Vector3(0.26, 0.16, 0.14), shell.lightened(0.08), 5, 12)
	_e(st, Vector3(0, 0.74, -0.78), Vector3(0.09, 0.1, 0.07), shell.darkened(0.1), 4, 8)
	# Raptorial forelegs: up from the neck, down to the elbow, and the spiked
	# claw folded back up, held ready.
	for s: float in [-1.0, 1.0]:
		var shoulder := Vector3(s * 0.08, 0.6, -0.5)
		var elbow := Vector3(s * 0.18, 0.2, -0.9)
		var tip := Vector3(s * 0.15, 0.68, -0.98)
		MeshKit.tube(st, [shoulder, shoulder.lerp(elbow, 0.5) + Vector3(s * 0.05, 0, -0.04), elbow], [0.06, 0.07, 0.05], 7, shell)
		MeshKit.tube(st, [elbow, elbow.lerp(tip, 0.5) + Vector3(s * 0.03, 0, -0.06), tip], [0.05, 0.045, 0.02], 7, pearl)
		for k in 4:
			var p := elbow.lerp(tip, 0.15 + k * 0.2)
			_spike(st, p, Vector3(-s * 0.4, 0.2, 1.0), 0.09, 0.018, Color("#5A3A2A"))
	# Antennae.
	for s: float in [-1.0, 1.0]:
		MeshKit.tube(st, [Vector3(s * 0.05, 0.95, -0.78), Vector3(s * 0.2, 1.25, -0.9), Vector3(s * 0.38, 1.38, -0.86)], [0.015, 0.012, 0.008], 4, shell.darkened(0.2))
	BugBuilder._eyes(st, Vector3(0, 0.9, -0.76), 0.21, 0.09)
	var spec := _spec(st, BugBuilder._legs(2, -0.02, 0.32, 0.16, 0.12, 0.85, -0.42),
			0.7, 0.85, 0.04, shell.darkened(0.15), Vector3(0, 0.86, -0.7), 0.26, 0.85, 0.48,
			{"mouth": Vector3(0, 0.72, -0.8), "mandible": 0.05, "antenna": 0.0, "color": shell.darkened(0.3)})
	spec["solo"] = true
	return spec


## The Mirage Mantis's shimmer: an unlit body coloured from its vertices that
## ripples the background through it; `solid` 1 = plain sight, ~0.1 = a ripple.
static func mirage_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, specular_disabled, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float solid = 1.0;
uniform float haze = 0.5;
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float t = TIME;
	vec2 wob = vec2(sin(wpos.y * 7.0 + t * 6.0) + sin(wpos.x * 5.0 - t * 4.0),
			cos(wpos.z * 6.0 + t * 5.0) + sin(wpos.y * 4.0 + t * 3.0)) * 0.006 * (0.4 + haze);
	vec3 bg = textureLod(screen_tex, SCREEN_UV + wob, 0.0).rgb;
	float ndl = clamp(dot(wnrm, normalize(sun_dir)), 0.0, 1.0);
	float band = ndl > 0.45 ? 1.0 : (ndl > 0.1 ? 0.78 : 0.6);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 body = COLOR.rgb * band + vec3(1.0, 0.92, 0.75) * fres * 0.35;
	float shimmer = 0.5 + 0.5 * sin(wpos.y * 9.0 - t * 8.0 + wpos.x * 3.0);
	float k = clamp(solid - haze * 0.18 * shimmer, 0.0, 1.0);
	ALBEDO = mix(bg + vec3(0.06, 0.05, 0.02) * fres, body, k);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


# ------------------------------------------------------------------ the Hive Wagon

## Stagecoach sized: a long plated isopod on spoked wheel-discs, carrying a huge
## papery wasp hive strapped on with rope, honey glowing in its holes.
static func _wagon(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2606
	var st := MeshKit.begin()
	var plank := shell.lightened(0.15)
	var iron := Color("#3E3A38")
	var paper := Color("#D9C9A3")
	var honey := Color("#F2A93B")
	# The plated body, like a wagon bed of overlapping planks.
	for i in 8:
		var z := -0.82 + i * 0.25
		var k := 1.0 - pow(absf(i - 3.5) / 4.2, 2.0) * 0.35
		_e(st, Vector3(0, 0.28, z), Vector3(0.66 * k, 0.4 * k, 0.2), shell if i % 2 == 0 else shell.darkened(0.1), 5, 14)
		_e(st, Vector3(0, 0.3, z + 0.1), Vector3(0.67 * k, 0.36 * k, 0.04), plank, 3, 14)
	# Wheel-discs: iron rims, wooden spokes and a hub, two each side.
	for s: float in [-1.0, 1.0]:
		for zc: float in [-0.5, 0.55]:
			var c := Vector3(s * 0.68, 0.12, zc)
			var b := Basis(Vector3.BACK, PI * 0.5)
			MeshKit.add_cylinder(st, Transform3D(b, c), 0.4, 0.4, 0.06, 18, iron)
			MeshKit.add_cylinder(st, Transform3D(b, c + Vector3(s * 0.01, 0, 0)), 0.34, 0.34, 0.07, 18, plank.darkened(0.2))
			for k in 8:
				var a := TAU * float(k) / 8.0
				MeshKit.add_limb(st, c + Vector3(s * 0.04, 0, 0), c + Vector3(s * 0.04, sin(a) * 0.33, cos(a) * 0.33), 0.025, Palette.WOOD, 4)
			_e(st, c + Vector3(s * 0.05, 0, 0), Vector3(0.07, 0.09, 0.09), iron, 4, 8)
	# The hive: stacked paper bands, a dome, holes glowing with honey.
	var hc := Vector3(0, 0.62, 0.12)
	MeshKit.lathe(st, Transform3D(Basis(), hc), [Vector2(0.38, 0.0), Vector2(0.56, 0.18), Vector2(0.6, 0.4), Vector2(0.54, 0.62),
			Vector2(0.4, 0.82), Vector2(0.18, 0.95), Vector2(0.0, 0.98)], 16, paper)
	for k in 5:
		var y := 0.12 + k * 0.16
		var r := [0.52, 0.59, 0.6, 0.55, 0.45][k] as float
		MeshKit.add_cylinder(st, Transform3D(Basis(), hc + Vector3(0, y, 0)), r + 0.02, r + 0.02, 0.05, 16, paper.darkened(0.15 + 0.05 * float(k % 2)))
	for k in 7:
		var a := rng.randf_range(-2.4, 2.4)
		var y := rng.randf_range(0.2, 0.7)
		var r := 0.6 - absf(y - 0.4) * 0.3
		var p := hc + Vector3(sin(a) * r, y, -cos(a) * r)
		_e(st, p, Vector3(0.07, 0.06, 0.07), Color("#3A2614"), 3, 8)
		_e(st, p + Vector3(sin(a), 0, -cos(a)) * 0.01, Vector3(0.045, 0.04, 0.045), honey, 3, 8, 0.7)
		MeshKit.add_limb(st, p + Vector3(0, -0.04, 0), p + Vector3(0, -0.16, 0), 0.02, honey, 4)
	# The main entrance at the front (its weak spot), and rope straps.
	var door := hc + Vector3(0, 0.36, -0.56)
	_e(st, door, Vector3(0.16, 0.12, 0.08), honey, 4, 10, 0.8)
	for zr: float in [-0.25, 0.4]:
		var pts: Array = []
		for k in 9:
			var a := lerpf(-PI * 0.5, PI * 0.5, float(k) / 8.0)
			pts.append(hc + Vector3(sin(a) * 0.63, 0.45 + cos(a) * 0.45, zr))
		MeshKit.tube(st, pts, [0.03], 5, Color("#C9A66B"))
	# A small blunt head with feelers.
	_e(st, Vector3(0, 0.2, -1.04), Vector3(0.36, 0.24, 0.2), shell.darkened(0.2), 5, 12)
	BugBuilder._eyes(st, Vector3(0, 0.26, -1.16), 0.2, 0.07)
	return _spec(st, BugBuilder._legs(5, -0.72, 0.8, 0.5, 0.0, 0.48, -0.3),
			0.42, 0.45, 0.07, shell.darkened(0.3), door, 0.26, 1.05, 0.38,
			{"mouth": Vector3(0, 0.08, -1.2), "mandible": 0.1, "antenna": 0.35, "color": shell.darkened(0.4),
				"antenna_at": Vector3(0, 0.36, -1.12)})


# ------------------------------------------------------------------ the Stilt Strider

## A harvestman on stilts: a small round body with a dark saddle and a turret of
## eyes on top, slung between eight impossibly long thin legs.
static func _strider(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2707
	var st := MeshKit.begin()
	var saddle := Color("#4A2E1E")
	_e(st, Vector3(0, 0.0, 0.05), Vector3(0.5, 0.34, 0.58), shell, 7, 14)
	_e(st, Vector3(0, 0.22, 0.05), Vector3(0.36, 0.14, 0.46), saddle, 5, 12)
	for i in 4:
		_e(st, Vector3(0, 0.3, -0.18 + i * 0.16), Vector3(0.26 - i * 0.03, 0.03, 0.04), shell.lightened(0.25), 3, 10)
	BugBuilder._spots(st, rng, Vector3(0, 0.0, 0.05), Vector3(0.5, 0.34, 0.58), 12, 0.04, shell.lightened(0.3))
	# The eye turret on top, with a ring of little spines.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.36, -0.22)), 0.12, 0.09, 0.2, 10, shell.darkened(0.15))
	for k in 6:
		var a := TAU * float(k) / 6.0
		_spike(st, Vector3(cos(a) * 0.09, 0.46, -0.22 + sin(a) * 0.09), Vector3(cos(a) * 0.5, 1.0, sin(a) * 0.5), 0.08, 0.02, saddle)
	# Little jaws and palps under the front.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_limb(st, Vector3(s * 0.12, -0.1, -0.5), Vector3(s * 0.18, -0.25, -0.66), 0.04, shell.darkened(0.2), 5)
	BugBuilder._weak(st, Vector3(0, 0.38, 0.32), Vector3(0.12, 0.05, 0.14), Color("#FFD23F"))
	BugBuilder._eyes(st, Vector3(0, 0.44, -0.24), 0.08, 0.06)
	var legs := _fan_legs([35.0, 70.0, 110.0, 145.0], 0.36, 0.05, 2.7, -2.3, 0.05)
	var spec := _spec(st, legs, 2.1, 2.5, 0.05, shell.darkened(0.4), Vector3(0, 0.38, 0.32), 0.22, 0.6, 2.3,
			{"mouth": Vector3(0, -0.12, -0.56), "mandible": 0.06, "antenna": 0.0, "color": saddle})
	spec["hit_lift"] = 0.0
	return spec


# ------------------------------------------------------------------ the Thunder Cicada

## A thunderhead of a cicada: a hammer-wide head with red eyes at the ends, ribbed
## amber drums (tymbals) on its sides, and great veined wings folded like a tent.
static func _cicada(shell: Color) -> Dictionary:
	var st := MeshKit.begin()
	var amber := Color("#F2B33D")
	var wing := Color("#BFE3D8")
	var vein := Color("#2E3B2A")
	var mark := Color("#8FBF6A")
	# Thorax with the pale "M" marking, and the abdomen.
	_e(st, Vector3(0, 0.3, -0.25), Vector3(0.6, 0.44, 0.44), shell, 7, 14)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_limb(st, Vector3(s * 0.28, 0.66, -0.42), Vector3(s * 0.1, 0.72, -0.18), 0.04, mark, 5)
		MeshKit.add_limb(st, Vector3(s * 0.1, 0.72, -0.18), Vector3(0, 0.72, -0.34), 0.04, mark, 5)
	BugBuilder._segmented(st, Vector3(0, 0.22, 0.42), Vector3(0.52, 0.36, 0.56), 5, shell.darkened(0.08), shell.lightened(0.12))
	# The hammer head and its eyes.
	_e(st, Vector3(0, 0.24, -0.72), Vector3(0.62, 0.22, 0.2), shell.darkened(0.1), 6, 14)
	_e(st, Vector3(0, 0.1, -0.86), Vector3(0.16, 0.14, 0.1), shell.lightened(0.1), 4, 8)
	for k in 4:
		_e(st, Vector3(0, 0.03 + k * 0.05, -0.93), Vector3(0.12, 0.012, 0.03), vein, 2, 8)
	# Tymbals: ribbed drums on the sides.
	for s: float in [-1.0, 1.0]:
		var c := Vector3(s * 0.48, 0.3, 0.06)
		_e(st, c, Vector3(0.12, 0.22, 0.2), amber.darkened(0.2), 5, 10)
		for k in 5:
			_e(st, c + Vector3(s * 0.02, -0.16 + k * 0.08, 0), Vector3(0.11, 0.02, 0.17), amber, 2, 10, 0.35)
	# Tent wings over the back, with dark veins.
	for s: float in [-1.0, 1.0]:
		var b := Basis(Vector3.BACK, s * 0.55)
		var c := Vector3(s * 0.3, 0.62, 0.52)
		_e(st, c, Vector3(0.36, 0.035, 0.95), wing, 4, 12, 0.0, b)
		for k in 4:
			var off := lerpf(-0.25, 0.25, float(k) / 3.0)
			MeshKit.add_limb(st, c + b * Vector3(off * 0.5, 0.04, -0.85), c + b * Vector3(off, 0.04, 0.8), 0.012, vein, 3)
		MeshKit.add_limb(st, c + b * Vector3(0.33, 0.03, -0.8), c + b * Vector3(0.3, 0.03, 0.85), 0.02, vein, 3)
	BugBuilder._weak(st, Vector3(0, 0.74, -0.28), Vector3(0.14, 0.05, 0.12), amber)
	BugBuilder._eyes(st, Vector3(0, 0.3, -0.76), 0.52, 0.12)
	var spec := _spec(st, BugBuilder._legs(3, -0.4, 0.35, 0.46, 0.0, 0.62, -0.34),
			0.55, 0.6, 0.075, shell.darkened(0.3), Vector3(0, 0.74, -0.28), 0.24, 0.95, 0.42,
			{"mouth": Vector3(0, 0.0, -0.94), "mandible": 0.0, "antenna": 0.16, "color": vein, "antenna_at": Vector3(0, 0.36, -0.86)})
	spec["tymbals"] = [Vector3(-0.5, 0.3, 0.06), Vector3(0.5, 0.3, 0.06)]
	return spec


# ------------------------------------------------------------------ the Bone Collector

## A burying beetle: flat black armour with two bold orange bands, orange-tipped
## club feelers, curved jaws, and a cattle skull and bones heaped on its back.
static func _collector(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2808
	var st := MeshKit.begin()
	var orange := Color("#E07A2E")
	var bone := Palette.BONE
	# Wing cases and the two scalloped orange bands.
	_e(st, Vector3(0, 0.22, 0.3), Vector3(0.64, 0.32, 0.76), shell, 7, 14)
	for zb: float in [0.05, 0.62]:
		for k in 5:
			var x := lerpf(-0.48, 0.48, float(k) / 4.0)
			var top := 0.22 + 0.32 * sqrt(maxf(1.0 - pow(x / 0.64, 2.0) - pow((zb - 0.3) / 0.76, 2.0), 0.0))
			_e(st, Vector3(x, top - 0.02, zb + (0.04 if k % 2 == 0 else -0.04)), Vector3(0.15, 0.05, 0.12), orange, 3, 8)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.53, 0.3)), Vector3(0.04, 0.03, 1.3), shell.lightened(0.15))
	# Pronotum with a flared rim, and the head.
	_e(st, Vector3(0, 0.24, -0.5), Vector3(0.56, 0.28, 0.36), shell.lightened(0.04), 6, 14)
	_e(st, Vector3(0, 0.2, -0.5), Vector3(0.6, 0.12, 0.38), shell.lightened(0.12), 3, 14)
	_e(st, Vector3(0, 0.14, -0.88), Vector3(0.3, 0.2, 0.24), shell, 5, 12)
	for s: float in [-1.0, 1.0]:
		_horn(st, [Vector3(s * 0.14, 0.04, -1.04), Vector3(s * 0.22, 0.02, -1.2), Vector3(s * 0.1, 0.0, -1.32)], 0.05, shell.lightened(0.2))
		# Club feelers with orange tips.
		MeshKit.tube(st, [Vector3(s * 0.14, 0.26, -1.0), Vector3(s * 0.3, 0.44, -1.18), Vector3(s * 0.38, 0.5, -1.3)], [0.025, 0.02, 0.02], 5, shell.lightened(0.1))
		_e(st, Vector3(s * 0.4, 0.52, -1.34), Vector3(0.07, 0.06, 0.09), orange, 4, 8)
	# A cattle skull on its back, horns and all, and loose bones.
	var sk := Vector3(0, 0.66, 0.2)
	_e(st, sk, Vector3(0.2, 0.15, 0.24), bone, 5, 10)
	_e(st, sk + Vector3(0, -0.05, -0.28), Vector3(0.12, 0.09, 0.18), bone, 4, 10)
	for s: float in [-1.0, 1.0]:
		_e(st, sk + Vector3(s * 0.09, 0.03, -0.12), Vector3(0.06, 0.05, 0.05), Color("#2A1A12"), 3, 6)
		_horn(st, [sk + Vector3(s * 0.16, 0.06, 0.08), sk + Vector3(s * 0.42, 0.1, 0.02), sk + Vector3(s * 0.56, 0.3, -0.06), sk + Vector3(s * 0.54, 0.44, -0.12)], 0.06, bone.darkened(0.08))
	for k in 4:
		var a := Vector3(rng.randf_range(-0.4, 0.4), 0.52, rng.randf_range(0.4, 0.95))
		var b := a + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.02, 0.08), rng.randf_range(-0.25, 0.25))
		MeshKit.add_limb(st, a, b, 0.035, bone.darkened(0.05), 5)
		_e(st, a, Vector3.ONE * 0.06, bone, 3, 6)
		_e(st, b, Vector3.ONE * 0.06, bone, 3, 6)
	# A rib cage at the back.
	for k in 4:
		var z := 0.55 + k * 0.1
		var pts: Array = []
		for j in 7:
			var a := lerpf(-1.2, 1.2, float(j) / 6.0)
			pts.append(Vector3(sin(a) * 0.28, 0.5 + cos(a) * 0.2, z))
		MeshKit.tube(st, pts, [0.022], 4, bone.darkened(0.1))
	BugBuilder._weak(st, Vector3(0, 0.48, -0.42), Vector3(0.14, 0.05, 0.12), orange)
	BugBuilder._eyes(st, Vector3(0, 0.22, -0.98), 0.17, 0.065)
	return _spec(st, BugBuilder._legs(3, -0.4, 0.6, 0.52, 0.0, 0.66, -0.34),
			0.55, 0.62, 0.08, shell.lightened(0.05), Vector3(0, 0.48, -0.42), 0.24, 0.95, 0.4,
			{"mouth": Vector3(0, 0.02, -1.08), "mandible": 0.12, "antenna": 0.0, "color": shell.lightened(0.1)})


# ------------------------------------------------------------------ the Hive Queen

## The mother of the Hive (Story, chapter 8): a termite-queen abdomen the size
## of a boxcar, banded with mahogany armour plates edged in gold over a pale,
## faintly glowing brood membrane; an ant's thorax under gilded pauldrons, a
## ruff of golden bristles, long folded wings lying down her back like a cape;
## a heart-shaped head with sickle mandibles, elbowed antennae and a crown of
## ivory spikes set with amber gems round a glowing jewel (her weak spot).
static func _hive_queen(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2808
	var st := MeshKit.begin()
	var plate := shell.darkened(0.08)
	var sheen := shell.lightened(0.32)
	var membrane := Color("#F1DDB0")
	var amber := Color("#FFB238")
	var wine := Color("#7A1E2C")
	var wing := Color("#EADBB0")
	var vein := Color("#9A6A34")
	var gold_dark := GOLD.darkened(0.35)

	# --- The abdomen: a long pale brood sac, banded with armour plates.
	var ab_c := Vector3(0, 0.4, 1.2)
	var ab_r := Vector3(0.86, 0.72, 1.16)
	_e(st, ab_c, ab_r, membrane, 9, 18)
	# Glowing brood showing through the membrane between the plates.
	for k in 7:
		var t := lerpf(-0.75, 0.8, float(k) / 6.0)
		var ring_k := sqrt(maxf(1.0 - t * t, 0.0))
		for sd: float in [-1.0, 1.0]:
			var a := rng.randf_range(0.5, 1.1)
			var p := ab_c + Vector3(sd * sin(a) * ab_r.x * ring_k, -cos(a) * ab_r.y * ring_k * 0.6, t * ab_r.z) * 0.985
			_e(st, p, Vector3(0.09, 0.07, 0.07) * (0.7 + ring_k * 0.5), amber.lightened(0.15), 3, 8, 0.55)
	# The dorsal plates (tergites): shell bands over the back and upper flanks
	# only, so the pale brood membrane shows between them and all down the
	# belly; each with a gold rim on its trailing edge, a sheen and a spine.
	var bands := 7
	for i in bands:
		var t := lerpf(-0.8, 0.84, float(i) / float(bands - 1))
		var k := sqrt(maxf(1.0 - t * t, 0.0))
		var z := ab_c.z + t * ab_r.z
		var w := ab_r.x * k * 1.0 + 0.1
		var h := ab_r.y * k * 0.92 + 0.1
		var b := Basis(Vector3.RIGHT, -0.15 + t * 0.12)
		var c := Vector3(0, ab_c.y + ab_r.y * k * 0.14, z)
		_e(st, c, Vector3(w, h, 0.2), plate if i % 2 == 0 else plate.darkened(0.12), 6, 18, 0.0, b)
		_e(st, c + b * Vector3(0, 0.0, 0.15), Vector3(w * 1.015, h * 1.015, 0.035), GOLD.darkened(0.08) if i % 2 == 0 else gold_dark, 3, 18, 0.0, b)
		_e(st, c + b * Vector3(w * 0.3, h * 0.86, -0.02), Vector3(w * 0.2, 0.03, 0.07), sheen, 3, 8, 0.0, b)
		_spike(st, c + b * Vector3(0, h * 0.97, 0.0), Vector3(0, 1.0, 0.5), 0.12 + 0.1 * k, 0.05, GOLD.darkened(0.1), 6)
		if k > 0.6:
			for sd: float in [-1.0, 1.0]:
				_e(st, c + b * Vector3(sd * w * 0.9, h * 0.1, 0.03), Vector3.ONE * 0.05, GOLD, 3, 6, 0.15)
	# The tail end: a stubby gold-capped tip.
	_e(st, ab_c + Vector3(0, -0.08, ab_r.z * 0.98), Vector3(0.26, 0.22, 0.18), plate, 5, 10)
	_spike(st, ab_c + Vector3(0, -0.1, ab_r.z * 1.08), Vector3(0, -0.35, 1.0), 0.3, 0.1, GOLD.darkened(0.1), 8)

	# --- The waist and thorax under gilded pauldrons.
	_e(st, Vector3(0, 0.36, 0.02), Vector3(0.22, 0.2, 0.18), plate, 5, 10)
	var th := Vector3(0, 0.48, -0.4)
	_e(st, th, Vector3(0.48, 0.38, 0.4), shell, 7, 14)
	_e(st, th + Vector3(0, 0.24, 0.02), Vector3(0.34, 0.16, 0.32), sheen.darkened(0.08), 4, 10)
	for sd: float in [-1.0, 1.0]:
		var pb := Basis(Vector3.BACK, sd * 0.55) * Basis(Vector3.RIGHT, 0.1)
		var pc := th + Vector3(sd * 0.36, 0.2, -0.04)
		_e(st, pc, Vector3(0.3, 0.09, 0.36), plate, 5, 12, 0.0, pb)
		_e(st, pc + pb * Vector3(0.0, -0.035, 0.0), Vector3(0.315, 0.06, 0.375), GOLD.darkened(0.12), 3, 12, 0.0, pb)
		_e(st, pc + pb * Vector3(0.03, 0.08, -0.04), Vector3(0.12, 0.03, 0.14), sheen, 3, 8, 0.0, pb)
		for k in 3:
			_e(st, pc + pb * Vector3(-0.05 + k * 0.1, 0.07, 0.22), Vector3.ONE * 0.035, GOLD, 3, 6, 0.2)
	# A ruff of golden bristles round the neck, like an ermine collar.
	for k in 22:
		var a := lerpf(-2.4, 2.4, float(k) / 21.0)
		var dir := Vector3(sin(a), cos(a) * 0.75 + 0.35, -0.25).normalized()
		var base := Vector3(0, 0.6, -0.74) + Vector3(sin(a) * 0.32, cos(a) * 0.22, 0.0)
		MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(dir), base + dir * 0.11), 0.05, 0.0, 0.22 + rng.randf_range(-0.03, 0.05), 5,
				GOLD.lightened(0.1) if k % 3 == 0 else Color("#C99B45"))

	# --- Short royal wings over the shoulders like a cape, spread a little so
	# the plated abdomen shows behind them.
	for sd: float in [-1.0, 1.0]:
		var wb := Basis(Vector3.UP, -sd * 0.38) * Basis(Vector3.BACK, sd * 0.42)
		var wc := Vector3(sd * 0.5, 0.86, 0.12)
		_e(st, wc, Vector3(0.3, 0.03, 0.72), wing, 4, 14, 0.0, wb)
		_e(st, wc + wb * Vector3(0.0, -0.014, 0.0), Vector3(0.32, 0.026, 0.75), vein, 3, 14, 0.0, wb)
		MeshKit.add_limb(st, wc + wb * Vector3(-sd * 0.26, 0.035, -0.62), wc + wb * Vector3(-sd * 0.2, 0.035, 0.66), 0.02, vein, 4)
		for k in 4:
			var z0 := lerpf(-0.55, 0.45, float(k) / 3.0)
			MeshKit.add_limb(st, wc + wb * Vector3(-sd * 0.24, 0.036, z0), wc + wb * Vector3(sd * 0.2, 0.036, z0 + 0.22), 0.01, vein, 3)
		_e(st, wc + wb * Vector3(-sd * 0.18, 0.04, 0.42), Vector3(0.05, 0.012, 0.12), wine, 3, 8, 0.0, wb)

	# --- The head: heart-shaped, with sickle mandibles and elbowed antennae.
	var hd := Vector3(0, 0.74, -0.98)
	_e(st, hd, Vector3(0.4, 0.3, 0.3), shell.lightened(0.04), 7, 14)
	for sd: float in [-1.0, 1.0]:
		_e(st, hd + Vector3(sd * 0.17, 0.12, 0.04), Vector3(0.22, 0.2, 0.22), shell.lightened(0.04), 5, 10)
		_e(st, hd + Vector3(sd * 0.2, 0.26, 0.0), Vector3(0.1, 0.05, 0.12), sheen, 3, 8)
	_e(st, hd + Vector3(0, -0.1, -0.24), Vector3(0.2, 0.1, 0.1), plate, 4, 10)
	_e(st, hd + Vector3(0, -0.18, -0.26), Vector3(0.13, 0.05, 0.07), wine, 3, 8)
	for sd: float in [-1.0, 1.0]:
		var m0 := hd + Vector3(sd * 0.2, -0.14, -0.2)
		var pts := [m0, m0 + Vector3(sd * 0.1, -0.06, -0.18), m0 + Vector3(sd * 0.05, -0.1, -0.36), m0 + Vector3(-sd * 0.1, -0.1, -0.46)]
		_horn(st, pts, 0.055, plate.darkened(0.2), 8)
		_e(st, pts[3], Vector3.ONE * 0.035, GOLD, 3, 6, 0.2)
		for k in 3:
			var p: Vector3 = (pts[1] as Vector3).lerp(pts[2], 0.25 + k * 0.3)
			_spike(st, p, Vector3(-sd, -0.1, -0.3), 0.07, 0.022, IVORY.darkened(0.1), 5)
	for sd: float in [-1.0, 1.0]:
		var a0 := hd + Vector3(sd * 0.12, 0.08, -0.26)
		var elbow := a0 + Vector3(sd * 0.32, 0.4, -0.14)
		var tip := elbow + Vector3(sd * 0.3, 0.06, -0.5)
		MeshKit.tube(st, [a0, a0.lerp(elbow, 0.5) + Vector3(0, 0.03, 0), elbow], [0.026, 0.022, 0.02], 6, plate)
		var flag: Array = []
		var radii: Array = []
		for k in 7:
			var t := float(k) / 6.0
			flag.append(elbow.lerp(tip, t) + Vector3(0, sin(t * PI) * 0.08, 0))
			radii.append(0.018 + t * t * 0.026)
		MeshKit.tube(st, flag, radii, 6, plate.lightened(0.08))
		_e(st, tip, Vector3(0.055, 0.05, 0.08), GOLD.darkened(0.05), 3, 8, 0.15)

	# --- The crown: a gold circlet on the brow and a crest of ivory spikes set
	# with amber gems, the tall middle one over the glowing crown jewel.
	var cr := hd + Vector3(0, 0.3, 0.06)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -0.25), cr), 0.29, 0.33, 0.09, 18, GOLD)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -0.25), cr + Vector3(0, 0.05, -0.01)), 0.335, 0.335, 0.025, 18, gold_dark)
	for k in 7:
		var a := lerpf(-1.15, 1.15, float(k) / 6.0)
		var mid := absi(k - 3)
		var tall: float = [0.6, 0.4, 0.33, 0.24][mid]
		var base := cr + Vector3(sin(a) * 0.3, 0.05, -cos(a) * 0.12)
		var dir := Vector3(sin(a) * 0.5, 1.0, 0.16 - cos(a) * 0.06).normalized()
		_spike(st, base, dir, tall, 0.07 - mid * 0.006, GOLD, 7)
		_spike(st, base, dir, tall * 0.45, 0.085 - mid * 0.006, gold_dark, 7)
		_e(st, base + dir * tall, Vector3.ONE * (0.05 - mid * 0.005), IVORY, 4, 8, 0.15)
		if k % 2 == 1:
			_e(st, base + dir * 0.05 + Vector3(0, 0, -0.06), Vector3(0.025, 0.03, 0.016), wine.lightened(0.25), 3, 6, 0.4)
	# The crown jewel at the front of the circlet: small, bright, the target.
	var jewel := cr + Vector3(0, 0.1, -0.34)
	_e(st, jewel + Vector3(0, 0, 0.02), Vector3(0.105, 0.12, 0.04), GOLD, 4, 10, 0.1)
	BugBuilder._weak(st, jewel, Vector3(0.07, 0.085, 0.05), amber)
	BugBuilder._eyes(st, hd + Vector3(0, 0.06, -0.26), 0.25, 0.1)

	# Legs: shorter and stout for her weight, gold greaves on the shins (LegRig bands).
	var legs := BugBuilder._legs(3, -0.6, -0.16, 0.4, 0.36, 1.0, -0.55)
	var spec := _spec(st, legs, 0.82, 0.92, 0.13, plate.darkened(0.15), jewel, 0.3, 1.25, 0.62,
			{"mouth": hd + Vector3(0, -0.16, -0.3), "mandible": 0.18, "antenna": 0.0, "color": plate})
	spec["crown"] = jewel
	spec["belly"] = ab_c + Vector3(0, 0.5, 0.15) # on her back, where it shows from across the canyon
	spec["mouth_at"] = hd + Vector3(0, -0.16, -0.32)
	return spec


# ------------------------------------------------------------------ the Hive Mother

## The Queen's mother (Story, chapter 10: The Reckoning), sealed in the lower
## hive since before the railroad: built like her daughter but older and
## bigger, and worn. Her plates are bleached ash-ivory, cracked and scarred,
## some broken off; her flanks and back are crusted with glowing hive amber
## (nodules and crystal clusters, the board's whole fortune); her wings are
## tattered strips; her head hangs low and heavy, with huge milky blind eyes
## (no pupils), one antenna snapped to a stump and chipped sickle mandibles;
## her crown is a broken ring of fused grey spikes round a big amber geode on
## her brow (her weak spot).
static func _hive_mother(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1868
	var st := MeshKit.begin()
	var plate := shell.darkened(0.1)
	var old := shell.darkened(0.24)
	var scar := Color("#3A2E26")
	var membrane := Color("#C9BFA2")
	var amber := Color("#FFA62B")
	var amber_deep := Color("#C66A12")
	var milk := Color("#E4EEF0")
	var wing := Color("#BDB49A")

	# --- The abdomen: longer, lower and lumpier than her daughter's.
	var ab_c := Vector3(0, 0.42, 1.32)
	var ab_r := Vector3(0.98, 0.78, 1.36)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), ab_c), ab_r, 9, 18, membrane, 0.06, rng)
	# Old plates over the back: cracked, a few broken off, scar lines across.
	var bands := 8
	for i in bands:
		var t := lerpf(-0.82, 0.86, float(i) / float(bands - 1))
		var k := sqrt(maxf(1.0 - t * t, 0.0))
		var z := ab_c.z + t * ab_r.z
		var w := ab_r.x * k + 0.08
		var h := ab_r.y * k * 0.9 + 0.1
		var b := Basis(Vector3.RIGHT, -0.12 + t * 0.12)
		var c := Vector3(0, ab_c.y + ab_r.y * k * 0.14, z)
		if i == 3 or i == 6:
			# A broken plate: only one side left, the membrane raw beside it.
			_e(st, c + b * Vector3(w * 0.45, h * 0.3, 0), Vector3(w * 0.6, h * 0.75, 0.19), old, 5, 12, 0.0, b)
		else:
			_e(st, c, Vector3(w, h, 0.21), plate if i % 2 == 0 else old, 6, 18, 0.0, b)
		# Scars: dark gouges across the plate.
		for j in 2:
			var a := rng.randf_range(-0.9, 0.9)
			var p := c + b * Vector3(sin(a) * w * 0.8, cos(a) * h * 0.95, 0.08)
			MeshKit.add_box(st, Transform3D(b * Basis(Vector3.BACK, rng.randf_range(-0.6, 0.6)), p), Vector3(w * 0.55, 0.035, 0.05), scar)
	# Amber crust: nodules and crystal clusters all over the back and flanks.
	for n in 26:
		var t := rng.randf_range(-0.8, 0.85)
		var ring_k := sqrt(maxf(1.0 - t * t, 0.0))
		var a := rng.randf_range(-1.6, 1.6)
		var dir := Vector3(sin(a), cos(a) * 0.9, 0.0).normalized()
		var p := ab_c + Vector3(dir.x * ab_r.x * ring_k, dir.y * ab_r.y * ring_k, t * ab_r.z)
		var s := rng.randf_range(0.07, 0.17)
		_e(st, p, Vector3(s, s * 0.8, s * 1.1), amber if n % 3 != 0 else amber_deep, 3, 8, 0.55 if n % 3 != 0 else 0.25)
		if n % 4 == 0:
			for q in 3:
				var cd := (dir + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, 0.6), rng.randf_range(-0.5, 0.5))).normalized()
				_spike(st, p, cd, rng.randf_range(0.18, 0.34), 0.05, amber.lightened(0.1), 5)
	# The tail end: a heavy, scarred tip dragging low.
	_e(st, ab_c + Vector3(0, -0.12, ab_r.z * 0.98), Vector3(0.3, 0.25, 0.22), old, 5, 10)

	# --- Waist and a hunched thorax, plates worn smooth, amber barnacles on it.
	_e(st, Vector3(0, 0.38, 0.0), Vector3(0.26, 0.22, 0.2), old, 5, 10)
	var th := Vector3(0, 0.52, -0.44)
	_e(st, th, Vector3(0.56, 0.44, 0.46), shell, 7, 14)
	_e(st, th + Vector3(0, 0.28, 0.06), Vector3(0.42, 0.18, 0.36), plate, 5, 12)
	for sd: float in [-1.0, 1.0]:
		var pb := Basis(Vector3.BACK, sd * 0.5)
		_e(st, th + Vector3(sd * 0.4, 0.22, -0.02), Vector3(0.32, 0.1, 0.38), old, 5, 12, 0.0, pb)
		MeshKit.add_box(st, Transform3D(pb, th + Vector3(sd * 0.42, 0.3, 0.05)), Vector3(0.36, 0.03, 0.04), scar)
	for n in 7:
		var p := th + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.2, 0.42), rng.randf_range(-0.25, 0.3))
		_e(st, p, Vector3.ONE * rng.randf_range(0.05, 0.1), amber, 3, 6, 0.5)

	# --- Tattered wings: strips of old membrane, torn short, hanging off her shoulders.
	for sd: float in [-1.0, 1.0]:
		for k in 4:
			var wb := Basis(Vector3.UP, -sd * (0.25 + k * 0.12)) * Basis(Vector3.BACK, sd * (0.55 + k * 0.06))
			var wc := Vector3(sd * (0.5 + k * 0.05), 0.92 - k * 0.04, 0.05 + k * 0.18)
			var strip := rng.randf_range(0.35, 0.7)
			_e(st, wc, Vector3(0.07, 0.02, strip), wing.darkened(k * 0.06), 3, 8, 0.0, wb)

	# --- The head: long and heavy, hanging low, with blind milky eyes.
	var hd := Vector3(0, 0.58, -1.08)
	_e(st, hd, Vector3(0.44, 0.32, 0.38), shell.lightened(0.03), 7, 14)
	_e(st, hd + Vector3(0, 0.2, 0.05), Vector3(0.36, 0.14, 0.3), plate, 5, 12)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.4), hd + Vector3(0.15, 0.28, -0.1)), Vector3(0.3, 0.035, 0.04), scar)
	for sd: float in [-1.0, 1.0]:
		# Big, pale, pupil-less eyes with a faint cold sheen.
		var ep := hd + Vector3(sd * 0.3, 0.06, -0.22)
		_e(st, ep + Vector3(0, 0.02, 0.04), Vector3(0.24, 0.21, 0.14), old.darkened(0.35), 4, 10)
		_e(st, ep, Vector3(0.22, 0.19, 0.17), milk, 5, 12, 0.35)
		_e(st, ep + Vector3(sd * 0.04, 0.06, -0.12), Vector3(0.07, 0.05, 0.03), Color.WHITE, 3, 6, 0.6)
	_e(st, hd + Vector3(0, -0.14, -0.3), Vector3(0.22, 0.11, 0.12), old, 4, 10)
	# Mandibles: huge sickles, chipped (the left one snapped short).
	for sd: float in [-1.0, 1.0]:
		var m0 := hd + Vector3(sd * 0.22, -0.18, -0.26)
		var pts := [m0, m0 + Vector3(sd * 0.12, -0.08, -0.22), m0 + Vector3(sd * 0.06, -0.13, -0.44), m0 + Vector3(-sd * 0.12, -0.13, -0.58)]
		if sd < 0.0:
			pts.resize(3)
		_horn(st, pts, 0.07, old.darkened(0.25), 8)
		for k in 2:
			var p: Vector3 = (pts[1] as Vector3).lerp(pts[2], 0.3 + k * 0.4)
			_spike(st, p, Vector3(-sd, -0.1, -0.3), 0.08, 0.026, IVORY.darkened(0.25), 5)
	# Antennae: one long and drooping, the other snapped to a stump.
	var a0 := hd + Vector3(0.14, 0.12, -0.3)
	MeshKit.tube(st, [a0, a0 + Vector3(0.3, 0.3, -0.1), a0 + Vector3(0.6, 0.2, -0.45), a0 + Vector3(0.85, -0.25, -0.7)], [0.03, 0.025, 0.02, 0.012], 6, old)
	var b0 := hd + Vector3(-0.14, 0.12, -0.3)
	MeshKit.tube(st, [b0, b0 + Vector3(-0.12, 0.16, -0.05)], [0.032, 0.03], 6, old)
	_e(st, b0 + Vector3(-0.12, 0.16, -0.05), Vector3.ONE * 0.04, scar, 3, 6)

	# --- The broken crown: a ring of fused grey spikes, several snapped short,
	# round a big amber geode on her brow (the weak spot).
	var cr := hd + Vector3(0, 0.3, 0.04)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -0.25), cr), 0.31, 0.36, 0.1, 16, old.darkened(0.1))
	for k in 9:
		var a := lerpf(-1.25, 1.25, float(k) / 8.0)
		var mid := absi(k - 4)
		var tall: float = [0.62, 0.48, 0.4, 0.3, 0.24][mid]
		if k == 2 or k == 5 or k == 7:
			tall *= 0.35 # snapped
		var base := cr + Vector3(sin(a) * 0.32, 0.05, -cos(a) * 0.12)
		var dir := Vector3(sin(a) * 0.55, 1.0, 0.12).normalized()
		_spike(st, base, dir, tall, 0.075 - mid * 0.005, shell.darkened(0.2), 6)
		if k % 3 == 1:
			_e(st, base + dir * tall * 0.4, Vector3(0.045, 0.06, 0.045), amber, 3, 6, 0.5)
	var geode := cr + Vector3(0, 0.08, -0.36)
	_e(st, geode + Vector3(0, 0, 0.03), Vector3(0.19, 0.18, 0.07), old.darkened(0.3), 4, 10)
	for k in 5:
		var a := TAU * float(k) / 5.0
		_spike(st, geode + Vector3(cos(a) * 0.06, sin(a) * 0.06, -0.02), Vector3(cos(a) * 0.6, sin(a) * 0.6, -1.0), 0.12, 0.035, amber.lightened(0.15), 5)
	BugBuilder._weak(st, geode, Vector3(0.13, 0.14, 0.08), amber)

	# Legs: long and gnarled, set wide for her weight.
	var legs := BugBuilder._legs(3, -0.7, -0.1, 0.46, 0.4, 1.15, -0.6)
	var spec := _spec(st, legs, 0.95, 1.05, 0.15, old.darkened(0.12), geode, 0.32, 1.45, 0.66,
			{"mouth": hd + Vector3(0, -0.2, -0.36), "mandible": 0.0, "antenna": 0.0, "color": old})
	spec["eyes"] = {} # blind: no pupils or brows (her milky eyes are in the mesh)
	spec["crown"] = geode
	spec["belly"] = ab_c + Vector3(0, 0.55, 0.2)
	spec["mouth_at"] = hd + Vector3(0, -0.2, -0.4)
	return spec


# ------------------------------------------------------------------ the small ones

## A locust from the Lord's swarm: green, striped, big eyes, folded jumping legs.
static func _locust(shell: Color) -> Dictionary:
	var st := MeshKit.begin()
	var brown := Color("#7A5A2E")
	_e(st, Vector3(0, 0.05, -0.2), Vector3(0.18, 0.2, 0.3), shell, 5, 10)
	for i in 5:
		_e(st, Vector3(0, 0.02, 0.15 + i * 0.13), Vector3(0.14 - i * 0.015, 0.13 - i * 0.012, 0.09), shell if i % 2 == 0 else brown, 4, 8)
	_e(st, Vector3(0, 0.08, -0.55), Vector3(0.16, 0.18, 0.15), shell.lightened(0.05), 5, 10)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_limb(st, Vector3(s * 0.15, 0.0, -0.05), Vector3(s * 0.22, 0.3, 0.45), 0.07, shell.lightened(0.25), 5)
		MeshKit.add_limb(st, Vector3(s * 0.22, 0.3, 0.45), Vector3(s * 0.2, -0.1, 0.4), 0.03, brown, 4)
	BugBuilder._eyes(st, Vector3(0, 0.14, -0.6), 0.13, 0.08)
	return _spec(st, [], 0.1, 0.1, 0.02, brown, Vector3(0, 0.15, -0.2), 0.2, 0.45, 0.0,
			{"mouth": Vector3(0, -0.06, -0.68), "mandible": 0.05, "antenna": 0.3, "color": brown,
				"antenna_at": Vector3(0, 0.2, -0.64), "wings": true}, false)


## A hive drone: a stubby wasp with a striped abdomen, a stinger and little wings.
static func _drone(shell: Color) -> Dictionary:
	var st := MeshKit.begin()
	var black := Color("#2A1E14")
	_e(st, Vector3(0, 0.12, -0.12), Vector3(0.2, 0.18, 0.22), black, 5, 10)
	for i in 4:
		_e(st, Vector3(0, 0.14 + i * 0.01, 0.2 + i * 0.13), Vector3(0.22 - i * 0.03, 0.2 - i * 0.025, 0.08), shell if i % 2 == 0 else black, 4, 10)
	_spike(st, Vector3(0, 0.18, 0.66), Vector3(0, 0.1, 1.0), 0.16, 0.04, black)
	_e(st, Vector3(0, 0.12, -0.42), Vector3(0.16, 0.14, 0.12), shell.darkened(0.1), 4, 10)
	for s: float in [-1.0, 1.0]:
		_e(st, Vector3(s * 0.2, 0.3, 0.02), Vector3(0.24, 0.02, 0.09), Color(0.88, 0.95, 1.0), 2, 8, 0.0, Basis(Vector3.UP, s * 0.5))
	BugBuilder._weak(st, Vector3(0, 0.36, 0.25), Vector3(0.08, 0.04, 0.1), Color("#FFB347"))
	BugBuilder._eyes(st, Vector3(0, 0.18, -0.5), 0.08, 0.06)
	return _spec(st, BugBuilder._legs(3, -0.2, 0.1, 0.16, 0.0, 0.26, -0.18),
			0.2, 0.22, 0.03, black, Vector3(0, 0.36, 0.25), 0.14, 0.4, 0.2,
			{"mouth": Vector3(0, 0.04, -0.52), "mandible": 0.06, "antenna": 0.2, "color": black,
				"antenna_at": Vector3(0, 0.2, -0.5)}, false)

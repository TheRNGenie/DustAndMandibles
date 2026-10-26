class_name BugBuilder
extends RefCounted
## Procedural bug bodies built from ellipsoids, capsules and cones.
## Local space: forward is -Z (head), up is +Y (the back, facing away from the surface).
## Returns a spec Dictionary:
##   body: ArrayMesh, legs: Array of {hip: Vector3, rest: Vector3}, upper/lower: leg segment
##   lengths, thick: leg radius, leg_color, ik: bool, weak_spot: Vector3, weak_radius,
##   body_radius, clearance (height of the body above the surface),
##   eyes: {center, spread, r, count} for the face (pupils, brows, blinks),
##   face: {mouth: Vector3, mandible: float size, antenna: float length, color}.
## Style: chunky cartoon proportions, big glossy eyes (pupils are added by
## BugFace so they can look at you), segment ridges, spots and stripes, little
## spines and hairs, and one glowing weak spot per bug.

static var _last_eyes: Dictionary = {}

const EYE_WHITE := Color("#FFF6D8")


static func build(def: BugDef) -> Dictionary:
	_last_eyes = {}
	var spec: Dictionary
	match def.id:
		&"dust_mite":
			spec = _mite(def.shell_color)
		&"wolf_spider":
			spec = _spider(def.shell_color)
		&"rattler_beetle":
			spec = _beetle(def.shell_color)
		&"spitter_scorpion":
			spec = _scorpion(def.shell_color)
		&"brood_mother":
			spec = _brood(def.shell_color)
		&"spiderling":
			spec = _spider(def.shell_color, true)
		&"burrow_tick":
			spec = _tick(def.shell_color)
		&"dragonfly_bandit":
			spec = _dragonfly(def.shell_color)
		&"crop_weevil":
			spec = _weevil(def.shell_color)
		&"iron_tumble":
			spec = _boss(def.shell_color)
		_:
			spec = _mite(def.shell_color)
	if not spec.has("eyes"):
		spec["eyes"] = _last_eyes.duplicate()
	return _scaled(spec, def.size)


## Scales every length in the spec (the mesh is scaled by the node instead).
static func _scaled(spec: Dictionary, s: float) -> Dictionary:
	var legs: Array = []
	for leg: Dictionary in spec["legs"]:
		legs.append({"hip": (leg["hip"] as Vector3) * s, "rest": (leg["rest"] as Vector3) * s})
	spec["legs"] = legs
	for key: String in ["upper", "lower", "thick", "weak_radius", "body_radius", "clearance"]:
		spec[key] = float(spec[key]) * s
	spec["weak_spot"] = (spec["weak_spot"] as Vector3) * s
	var eyes: Dictionary = spec.get("eyes", {})
	if not eyes.is_empty():
		spec["eyes"] = {"center": (eyes["center"] as Vector3) * s, "spread": float(eyes["spread"]) * s,
				"r": float(eyes["r"]) * s, "count": int(eyes.get("count", 2))}
	var face: Dictionary = spec.get("face", {})
	if not face.is_empty():
		spec["face"] = {"mouth": (face["mouth"] as Vector3) * s, "mandible": float(face["mandible"]) * s,
				"antenna": float(face.get("antenna", 0.0)) * s, "color": face["color"],
				"antenna_at": (face.get("antenna_at", face["mouth"]) as Vector3) * s}
	spec["scale"] = s
	return spec


## Symmetric legs: `pairs` hips along Z on each side, feet spread outward.
static func _legs(pairs: int, z_front: float, z_back: float, hip_x: float, hip_y: float,
		reach: float, foot_y: float) -> Array:
	var legs: Array = []
	for i in pairs:
		var t := float(i) / maxf(pairs - 1, 1)
		var z := lerpf(z_front, z_back, t)
		var splay := lerpf(-0.6, 0.6, t) # front legs reach forward, back legs back
		for side: float in [-1.0, 1.0]:
			legs.append({
				"hip": Vector3(side * hip_x, hip_y, z),
				"rest": Vector3(side * (hip_x + reach), foot_y, z + splay * reach),
			})
	return legs


# ------------------------------------------------------------------ helpers

## Big glossy cartoon eyes (whites only; BugFace adds pupils that track you).
static func _eyes(st: SurfaceTool, center: Vector3, spread: float, r: float, count: int = 2) -> void:
	_last_eyes = {"center": center, "spread": spread, "r": r, "count": count}
	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := float(i / 2)
		var p := center + Vector3(side * spread * (1.0 + row * 0.6), row * r * 1.5, row * r * 0.4)
		var rr := r * (1.0 - row * 0.35)
		# A dark socket rim, then the white.
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), p + Vector3(0, 0, rr * 0.2)), Vector3.ONE * rr * 1.18, 4, 10, Color("#1E1612"))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), p), Vector3(rr, rr * 1.05, rr), 5, 10, EYE_WHITE, 0.0, null, 0.25)


## An ellipsoid body part with raised ridges (segments), for shells and abdomens.
static func _segmented(st: SurfaceTool, c: Vector3, radii: Vector3, bands: int, col: Color, ridge: Color,
		rng: RandomNumberGenerator = null, bump: float = 0.0) -> void:
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), c), radii, 7, 14, col, bump, rng)
	for i in bands:
		var t := lerpf(-0.65, 0.75, float(i) / maxf(bands - 1, 1))
		var z := c.z + t * radii.z
		var k := sqrt(maxf(1.0 - t * t, 0.0))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(c.x, c.y + radii.y * 0.04, z)), Vector3(radii.x * k * 1.02, radii.y * k * 1.02, radii.z * 0.055),
				3, 14, ridge)


## Little spines or hairs over a body part's top.
static func _hairs(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, radii: Vector3, n: int, len: float, col: Color) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var up := rng.randf_range(0.25, 1.0)
		var dir := Vector3(cos(a) * sqrt(1.0 - up * up), up, sin(a) * sqrt(1.0 - up * up))
		var base := c + Vector3(dir.x * radii.x, dir.y * radii.y, dir.z * radii.z)
		MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(dir), base + dir * len * 0.5), len * 0.12, 0.0, len, 4, col)


## Round spots scattered over a body part's top.
static func _spots(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, radii: Vector3, n: int, size: float, col: Color) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var up := rng.randf_range(0.45, 0.95)
		var dir := Vector3(cos(a) * sqrt(1.0 - up * up), up, sin(a) * sqrt(1.0 - up * up))
		var p := c + Vector3(dir.x * radii.x, dir.y * radii.y, dir.z * radii.z) * 0.985
		MeshKit.add_ellipsoid(st, Transform3D(MeshKit.basis_from_y(dir), p), Vector3(size, size * 0.25, size), 3, 8, col)


## A glowing weak spot, with a darker rim so it reads as a target.
static func _weak(st: SurfaceTool, p: Vector3, radii: Vector3, col: Color = Palette.GLOW_YELLOW) -> void:
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), p - Vector3(0, radii.y * 0.25, 0)), radii * 1.18, 4, 10, col.darkened(0.55))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), p), radii, 4, 10, col, 0.0, null, 0.8)


# ------------------------------------------------------------------ bugs

## Dust mite: a round rusty pill with a fuzzy back, stubby face, big eyes.
static func _mite(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var st := MeshKit.begin()
	_segmented(st, Vector3(0, 0.08, 0.08), Vector3(0.42, 0.32, 0.5), 4, shell, shell.darkened(0.18))
	_hairs(st, rng, Vector3(0, 0.08, 0.08), Vector3(0.42, 0.32, 0.5), 22, 0.12, shell.lightened(0.25))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.06, -0.4)), Vector3(0.26, 0.22, 0.22), 5, 10, shell.darkened(0.2))
	_weak(st, Vector3(0, 0.36, 0.14), Vector3(0.13, 0.05, 0.15))
	_eyes(st, Vector3(0, 0.16, -0.56), 0.11, 0.075)
	return {
		"body": MeshKit.finish(st), "legs": _legs(3, -0.25, 0.3, 0.3, 0.0, 0.35, -0.2),
		"upper": 0.3, "lower": 0.3, "thick": 0.05, "leg_color": shell.darkened(0.4), "ik": false,
		"weak_spot": Vector3(0, 0.36, 0.14), "weak_radius": 0.18, "body_radius": 0.5, "clearance": 0.22,
		"face": {"mouth": Vector3(0, 0.0, -0.6), "mandible": 0.09, "antenna": 0.0, "color": shell.darkened(0.45)},
	}


## Wolf spider: hairy, striped, a big abdomen with a chevron pattern, eight eyes.
static func _spider(shell: Color, baby: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 22 if not baby else 23
	var st := MeshKit.begin()
	# Cephalothorax with a pale racing stripe, and a big striped abdomen.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.12, -0.25)), Vector3(0.36, 0.25, 0.42), 6, 12, shell)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.33, -0.22)), Vector3(0.1, 0.06, 0.36), 4, 8, shell.lightened(0.3))
	_segmented(st, Vector3(0, 0.27, 0.55), Vector3(0.5, 0.42, 0.62), 5, shell.darkened(0.12), shell.darkened(0.35))
	for i in 4:
		var z := 0.25 + i * 0.16
		for s: float in [-1.0, 1.0]:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, s * 0.6), Vector3(s * 0.12, 0.66 - i * 0.03, z)), Vector3(0.13, 0.03, 0.04), 3, 6, shell.lightened(0.25))
	_hairs(st, rng, Vector3(0, 0.27, 0.55), Vector3(0.5, 0.42, 0.62), 40 if not baby else 14, 0.1, shell.lightened(0.15))
	_hairs(st, rng, Vector3(0, 0.12, -0.25), Vector3(0.36, 0.25, 0.42), 18 if not baby else 6, 0.07, shell.lightened(0.15))
	_weak(st, Vector3(0, 0.64, 0.6), Vector3(0.14, 0.06, 0.32))
	# Fuzzy pedipalps at the front.
	for side: float in [-1.0, 1.0]:
		MeshKit.add_limb(st, Vector3(side * 0.12, 0.02, -0.6), Vector3(side * 0.16, -0.08, -0.8), 0.055, shell.darkened(0.3), 6)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(side * 0.16, -0.09, -0.84)), Vector3.ONE * 0.07, 4, 8, shell.darkened(0.45))
	_eyes(st, Vector3(0, 0.27, -0.6), 0.1, 0.07, 4)
	return {
		"body": MeshKit.finish(st), "legs": _legs(4, -0.45, 0.05, 0.25, 0.08, 0.95, -0.25),
		"upper": 0.75, "lower": 0.85, "thick": 0.055, "leg_color": shell.darkened(0.3), "ik": true,
		"weak_spot": Vector3(0, 0.64, 0.6), "weak_radius": 0.3, "body_radius": 0.75, "clearance": 0.45,
		"face": {"mouth": Vector3(0, 0.08, -0.66), "mandible": 0.12, "antenna": 0.0, "color": Color("#2A1A1E")},
	}


## Rattler beetle: a gleaming armoured dome with gold trim, a big horn, a rattle tail.
static func _beetle(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var st := MeshKit.begin()
	# Two wing cases split down the middle, with a gold rim and dimples.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, s * 0.08), Vector3(s * 0.3, 0.17, 0.12)), Vector3(0.34, 0.46, 0.74), 7, 14, shell)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, s * 0.08), Vector3(s * 0.31, 0.14, 0.12)), Vector3(0.355, 0.4, 0.76), 4, 14, Color("#D6A74A"))
		_spots(st, rng, Vector3(s * 0.3, 0.17, 0.12), Vector3(0.34, 0.46, 0.74), 6, 0.05, shell.darkened(0.25))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.6, 0.12)), Vector3(0.05, 0.06, 1.35), shell.darkened(0.45))
	# Thorax shield and head with a curved horn.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.22, -0.55)), Vector3(0.48, 0.3, 0.26), 6, 12, shell.lightened(0.1))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.08, -0.74)), Vector3(0.3, 0.22, 0.22), 5, 10, shell.darkened(0.3))
	var prev := Vector3(0, 0.22, -0.86)
	for i in 4:
		var t := float(i + 1) / 4.0
		var p := Vector3(0, 0.22 + t * 0.32 - t * t * 0.08, -0.86 - t * 0.38)
		MeshKit.add_limb(st, prev, p, 0.075 * (1.0 - t * 0.7), Palette.BONE.darkened(t * 0.1), 6)
		prev = p
	_eyes(st, Vector3(0, 0.17, -0.88), 0.15, 0.07)
	# Rattle tail: bone rings ending in the glowing weak spot.
	for i in 3:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.2, 0.86 + i * 0.15)), Vector3(0.15 - i * 0.025, 0.11, 0.08), 4, 10, Palette.BONE.darkened(i * 0.08))
	_weak(st, Vector3(0, 0.2, 1.3), Vector3(0.09, 0.08, 0.08))
	return {
		"body": MeshKit.finish(st), "legs": _legs(3, -0.4, 0.5, 0.45, 0.0, 0.6, -0.3),
		"upper": 0.55, "lower": 0.55, "thick": 0.085, "leg_color": shell.darkened(0.5), "ik": true,
		"weak_spot": Vector3(0, 0.2, 1.3), "weak_radius": 0.2, "body_radius": 0.85, "clearance": 0.4,
		"face": {"mouth": Vector3(0, -0.02, -0.9), "mandible": 0.14, "antenna": 0.3, "color": shell.darkened(0.55),
			"antenna_at": Vector3(0, 0.2, -0.84)},
	}


## Spitter scorpion: banded armour, big lumpy claws, a curling tail with an acid bulb.
static func _scorpion(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	var st := MeshKit.begin()
	for i in 5:
		var w := 0.4 - absf(i - 1.5) * 0.04
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.11, -0.36 + i * 0.22)), Vector3(w, 0.2, 0.16), 5, 12, shell if i % 2 == 0 else shell.darkened(0.12))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.22, -0.36 + i * 0.22)), Vector3(w * 0.6, 0.12, 0.13), 4, 10, shell.lightened(0.18))
	# Claws: arm, then a fat pincer with an upper and lower jaw.
	for side: float in [-1.0, 1.0]:
		var a := Vector3(side * 0.25, 0.1, -0.45)
		var b := Vector3(side * 0.5, 0.15, -0.72)
		MeshKit.add_limb(st, a, b, 0.075, shell.darkened(0.15), 8)
		var c := b + Vector3(side * 0.05, 0.02, -0.2)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), c), Vector3(0.16, 0.11, 0.2), 5, 10, shell.darkened(0.25))
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, side * 0.25), c + Vector3(side * 0.04, 0.04, -0.22)), 0.06, 0.0, 0.26, 6, shell.darkened(0.35))
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, -side * 0.15), c + Vector3(-side * 0.05, -0.02, -0.2)), 0.045, 0.0, 0.2, 6, shell.darkened(0.35))
		_spots(st, rng, c, Vector3(0.16, 0.11, 0.2), 3, 0.025, shell.lightened(0.3))
	# Tail curling up over the back, segment by segment, to a glowing acid bulb.
	var prev := Vector3(0, 0.15, 0.55)
	for i in 6:
		var t := float(i + 1) / 6.0
		var p := Vector3(0, 0.15 + sin(t * PI * 0.85) * 0.95, 0.55 + cos(t * PI * 0.95) * 0.35 + t * 0.12 - 0.35)
		MeshKit.add_limb(st, prev, p, 0.1 - i * 0.01, shell if i % 2 == 0 else shell.darkened(0.12), 8)
		prev = p
	_weak(st, prev + Vector3(0, 0.05, -0.08), Vector3.ONE * 0.15, Palette.ACID_GREEN)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -2.4), prev + Vector3(0, -0.04, -0.22)), 0.04, 0.0, 0.2, 6, Palette.BONE)
	_eyes(st, Vector3(0, 0.27, -0.42), 0.08, 0.06)
	return {
		"body": MeshKit.finish(st), "legs": _legs(4, -0.25, 0.45, 0.3, 0.0, 0.6, -0.25),
		"upper": 0.45, "lower": 0.5, "thick": 0.055, "leg_color": shell.darkened(0.35), "ik": true,
		"weak_spot": prev + Vector3(0, 0.05, -0.08), "weak_radius": 0.22, "body_radius": 0.6, "clearance": 0.32,
		"face": {"mouth": Vector3(0, 0.05, -0.52), "mandible": 0.08, "antenna": 0.0, "color": shell.darkened(0.5)},
	}


## Brood mother: a bloated spider whose huge back is crusted with egg sacs.
static func _brood(shell: Color) -> Dictionary:
	var spec := _spider(shell)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.12, -0.3)), Vector3(0.42, 0.29, 0.46), 6, 12, shell)
	_segmented(st, Vector3(0, 0.37, 0.7), Vector3(0.72, 0.56, 0.86), 6, shell.darkened(0.2), shell.darkened(0.4))
	_hairs(st, rng, Vector3(0, 0.37, 0.7), Vector3(0.72, 0.56, 0.86), 36, 0.1, shell.lightened(0.1))
	for i in 14:
		var a := rng.randf() * TAU
		var up := rng.randf_range(0.35, 0.95)
		var d := Vector3(cos(a) * sqrt(1.0 - up * up), up, sin(a) * sqrt(1.0 - up * up))
		var p := Vector3(0, 0.37, 0.7) + Vector3(d.x * 0.72, d.y * 0.56, d.z * 0.86)
		var r := rng.randf_range(0.08, 0.15)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), p), Vector3.ONE * r, 4, 8, Color("#F2EAD0"), 0.0, null, 0.3)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), p + d * r * 0.6), Vector3.ONE * r * 0.35, 3, 6, Color("#C7B98E"))
	_weak(st, Vector3(0, 0.93, 0.7), Vector3(0.2, 0.08, 0.3))
	for side: float in [-1.0, 1.0]:
		MeshKit.add_limb(st, Vector3(side * 0.12, 0.02, -0.66), Vector3(side * 0.16, -0.08, -0.86), 0.06, shell.darkened(0.3), 6)
	_eyes(st, Vector3(0, 0.3, -0.7), 0.11, 0.075, 6)
	spec["body"] = MeshKit.finish(st)
	spec["eyes"] = _last_eyes.duplicate()
	spec["weak_spot"] = Vector3(0, 0.93, 0.7)
	spec["body_radius"] = 0.95
	return spec


## Burrow tick: a fat leathery balloon with a hard head plate and a glowing bite.
static func _tick(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.14, 0.12)), Vector3(0.52, 0.3, 0.58), 7, 14, shell, 0.06, rng)
	_spots(st, rng, Vector3(0, 0.14, 0.12), Vector3(0.52, 0.3, 0.58), 10, 0.06, shell.darkened(0.25))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.38, 0.1)), Vector3(0.24, 0.08, 0.3), 4, 10, shell.darkened(0.3))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.18, -0.38)), Vector3(0.24, 0.12, 0.16), 5, 10, shell.darkened(0.45))
	_weak(st, Vector3(0, 0.05, -0.52), Vector3(0.13, 0.08, 0.11))
	_eyes(st, Vector3(0, 0.28, -0.42), 0.12, 0.055)
	return {
		"body": MeshKit.finish(st), "legs": _legs(4, -0.25, 0.4, 0.35, 0.0, 0.3, -0.18),
		"upper": 0.25, "lower": 0.25, "thick": 0.05, "leg_color": shell.darkened(0.4), "ik": false,
		"weak_spot": Vector3(0, 0.05, -0.52), "weak_radius": 0.18, "body_radius": 0.55, "clearance": 0.2,
		"face": {"mouth": Vector3(0, 0.08, -0.52), "mandible": 0.06, "antenna": 0.0, "color": shell.darkened(0.5)},
	}


## Dragonfly bandit: a sleek body wearing a bandana, huge goggle eyes. Wings are
## added separately by BugFace so they can buzz.
static func _dragonfly(shell: Color) -> Dictionary:
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, -0.2)), Vector3(0.22, 0.2, 0.35), 6, 12, shell)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.12, -0.18)), Vector3(0.12, 0.08, 0.3), 4, 8, shell.lightened(0.25))
	for i in 7:
		var r := 0.1 - i * 0.008
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, 0.25 + i * 0.2)), Vector3(r, r, 0.12), 4, 10, shell if i % 2 == 0 else Palette.GLOW_YELLOW.darkened(0.25))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, 1.68)), Vector3(0.05, 0.05, 0.1), 4, 8, Palette.GLOW_YELLOW, 0.0, null, 0.5)
	# The bandit's bandana over the lower face.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -0.05, -0.5)), Vector3(0.2, 0.12, 0.15), 5, 10, Palette.TEAM_WEST.darkened(0.15))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.8), Vector3(0, -0.12, -0.4)), 0.07, 0.0, 0.14, 4, Palette.TEAM_WEST.darkened(0.25))
	_eyes(st, Vector3(0, 0.08, -0.56), 0.13, 0.12)
	return {
		"body": MeshKit.finish(st), "legs": [],
		"upper": 0.1, "lower": 0.1, "thick": 0.02, "leg_color": shell, "ik": false,
		"weak_spot": Vector3(0, 0.05, -0.55), "weak_radius": 0.22, "body_radius": 0.45, "clearance": 0.0,
		"face": {"mouth": Vector3(0, -0.12, -0.62), "mandible": 0.0, "antenna": 0.18, "color": shell.darkened(0.4),
			"antenna_at": Vector3(0, 0.2, -0.56), "wings": true},
	}


## Crop weevil: a round speckled beetle with a long curved snout and elbowed antennae.
static func _weevil(shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var st := MeshKit.begin()
	_segmented(st, Vector3(0, 0.14, 0.15), Vector3(0.34, 0.28, 0.46), 5, shell, shell.darkened(0.15))
	_spots(st, rng, Vector3(0, 0.14, 0.15), Vector3(0.34, 0.28, 0.46), 14, 0.035, shell.lightened(0.35))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.12, -0.34)), Vector3(0.18, 0.17, 0.17), 5, 10, shell.darkened(0.2))
	var prev := Vector3(0, 0.08, -0.46)
	for i in 4:
		var t := float(i + 1) / 4.0
		var p := Vector3(0, 0.08 - t * t * 0.22, -0.46 - t * 0.4)
		MeshKit.add_limb(st, prev, p, 0.055 * (1.0 - t * 0.4), shell.darkened(0.35), 6)
		prev = p
	_weak(st, Vector3(0, 0.4, 0.22), Vector3(0.11, 0.05, 0.18))
	_eyes(st, Vector3(0, 0.2, -0.44), 0.09, 0.055)
	return {
		"body": MeshKit.finish(st), "legs": _legs(3, -0.15, 0.4, 0.25, 0.0, 0.3, -0.2),
		"upper": 0.25, "lower": 0.28, "thick": 0.04, "leg_color": shell.darkened(0.4), "ik": false,
		"weak_spot": Vector3(0, 0.4, 0.22), "weak_radius": 0.16, "body_radius": 0.45, "clearance": 0.22,
		"face": {"mouth": prev, "mandible": 0.05, "antenna": 0.24, "color": shell.darkened(0.45),
			"antenna_at": Vector3(0, 0.12, -0.62)},
	}


## The Iron Tumbleweed: a giant silver rhinoceros beetle. A towering curved horn
## on its head, a second horn jutting off its thorax, a polished domed back that
## shrugs off shots from across the canyon, and a glowing seam under its rear
## exposed to the cliff's owner shooting down from the lip.
static func _boss(_shell: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1010
	var st := MeshKit.begin()
	var silver := Color("#AEB6BF")
	var shine := Color("#EEF3F8")
	var dark := Color("#5E6874")
	# Wing cases: two polished domes split down the middle, with a bright rim.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, s * 0.06), Vector3(s * 0.25, 0.3, 0.38)), Vector3(0.42, 0.42, 0.82), 8, 14, silver, 0.0, rng)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(s * 0.3, 0.62, 0.25)), Vector3(0.14, 0.08, 0.4), 4, 8, shine)
		# Engraved stripes down each case.
		for k in 3:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.0), Vector3(s * (0.12 + k * 0.12), 0.78 - k * 0.06, 0.4)), Vector3(0.03, 0.03, 1.1 - k * 0.15), dark)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.82, 0.38)), Vector3(0.05, 0.04, 1.5), dark)
	# Belly plates under the domes.
	_segmented(st, Vector3(0, 0.12, 0.38), Vector3(0.6, 0.28, 0.85), 5, dark, dark.lightened(0.2))
	# Pronotum: the shield behind the head, with the thoracic horn jutting forward.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.38, -0.5)), Vector3(0.62, 0.48, 0.42), 8, 14, silver.lightened(0.05), 0.0, rng)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.18, 0.66, -0.55)), Vector3(0.16, 0.08, 0.14), 4, 8, shine)
	var prev := Vector3(0, 0.7, -0.62)
	for i in 4:
		var t := float(i + 1) / 4.0
		var p := Vector3(0, 0.7 + t * 0.12 - t * t * 0.08, -0.62 - t * 0.55)
		MeshKit.add_limb(st, prev, p, 0.11 * (1.0 - t * 0.75), silver.darkened(0.1 + t * 0.15), 7)
		prev = p
	# Rivets around the shield rim (it is the IRON Tumbleweed).
	for k in 11:
		var a := lerpf(-1.3, 1.3, float(k) / 10.0)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(sin(a) * 0.6, 0.28 + cos(a) * 0.12, -0.5 - cos(a) * 0.3)), Vector3.ONE * 0.03, 3, 6, shine)
	# Head, low and wide, with the big rhino horn sweeping up and back.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.12, -0.92)), Vector3(0.34, 0.24, 0.26), 6, 12, dark)
	prev = Vector3(0, 0.18, -1.12)
	for i in 7:
		var t := float(i + 1) / 7.0
		var p := Vector3(0, 0.12 + t * t * 0.85, -1.12 - t * 0.85 + t * t * t * 0.45)
		MeshKit.add_limb(st, prev, p, 0.19 * (1.0 - t * 0.8), silver.darkened(t * 0.25), 8)
		prev = p
	# A notched fork at the horn tip.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_limb(st, prev, prev + Vector3(s * 0.09, 0.1, 0.05), 0.025, dark, 5)
	_eyes(st, Vector3(0, 0.2, -1.12), 0.24, 0.08)
	# A scuffed tumbleweed snagged on its back, for the name.
	var tw := Vector3(-0.25, 0.86, 0.75)
	for k in 26:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		var e := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		MeshKit.add_limb(st, tw + d * 0.18, tw + e * 0.2, 0.012, Color("#B08A4E"), 3)
	_weak(st, Vector3(0, -0.05, 1.12), Vector3(0.35, 0.12, 0.18))
	return {
		"body": MeshKit.finish(st), "legs": _legs(3, -0.45, 0.75, 0.55, 0.0, 0.75, -0.35),
		"upper": 0.62, "lower": 0.7, "thick": 0.1, "leg_color": dark, "ik": true,
		"weak_spot": Vector3(0, -0.05, 1.12), "weak_radius": 0.3, "body_radius": 0.95, "clearance": 0.45,
		"face": {"mouth": Vector3(0, -0.02, -1.12), "mandible": 0.18, "antenna": 0.14, "color": dark,
			"antenna_at": Vector3(0, 0.2, -1.05)},
	}

class_name BugBuilder
extends RefCounted
## Procedural bug bodies built from ellipsoids, capsules and cones.
## Local space: forward is -Z (head), up is +Y (the back, facing away from the surface).
## Returns a spec Dictionary:
##   body: ArrayMesh, legs: Array of {hip: Vector3, rest: Vector3}, upper/lower: leg segment
##   lengths, thick: leg radius, leg_color, ik: bool, weak_spot: Vector3, weak_radius,
##   body_radius, clearance (height of the body above the surface).

static func build(def: BugDef) -> Dictionary:
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
		_:
			spec = _mite(def.shell_color)
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


static func _eyes(st: SurfaceTool, center: Vector3, spread: float, r: float, count: int = 2) -> void:
	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := float(i / 2)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), center + Vector3(side * spread * (1.0 + row * 0.6), row * r * 1.5, 0)),
				Vector3.ONE * r, 3, 6, Palette.GLOW_YELLOW, 0.0, null, 0.8)


static func _mite(shell: Color) -> Dictionary:
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.05, 0.08)), Vector3(0.42, 0.3, 0.5), 6, 10, shell)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.05, -0.42)), Vector3(0.22, 0.18, 0.2), 5, 8, shell.darkened(0.25))
	# Glowing spot on the back: the weak spot.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.3, 0.12)), Vector3(0.14, 0.06, 0.16), 4, 8, Palette.GLOW_YELLOW, 0.0, null, 0.7)
	_eyes(st, Vector3(0, 0.12, -0.6), 0.08, 0.045)
	return {
		"body": MeshKit.finish(st), "legs": _legs(3, -0.25, 0.3, 0.3, 0.0, 0.35, -0.2),
		"upper": 0.3, "lower": 0.3, "thick": 0.05, "leg_color": shell.darkened(0.4), "ik": false,
		"weak_spot": Vector3(0, 0.3, 0.12), "weak_radius": 0.18, "body_radius": 0.5, "clearance": 0.22,
	}


static func _spider(shell: Color) -> Dictionary:
	var st := MeshKit.begin()
	# Cephalothorax and big abdomen with a glowing stripe (weak spot).
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.1, -0.25)), Vector3(0.36, 0.25, 0.42), 6, 12, shell)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.25, 0.55)), Vector3(0.5, 0.42, 0.62), 7, 12, shell.darkened(0.15))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.62, 0.55)), Vector3(0.16, 0.08, 0.42), 4, 8, Palette.GLOW_YELLOW, 0.0, null, 0.7)
	for side: float in [-1.0, 1.0]:
		MeshKit.add_limb(st, Vector3(side * 0.1, 0.0, -0.62), Vector3(side * 0.07, -0.12, -0.82), 0.05, shell.darkened(0.45), 6)
	_eyes(st, Vector3(0, 0.25, -0.62), 0.09, 0.05, 4)
	return {
		"body": MeshKit.finish(st), "legs": _legs(4, -0.45, 0.05, 0.25, 0.08, 0.95, -0.25),
		"upper": 0.75, "lower": 0.85, "thick": 0.05, "leg_color": shell.darkened(0.3), "ik": true,
		"weak_spot": Vector3(0, 0.62, 0.55), "weak_radius": 0.3, "body_radius": 0.75, "clearance": 0.45,
	}


static func _beetle(shell: Color) -> Dictionary:
	var st := MeshKit.begin()
	# Domed shell = the armour plate facing away from the cliff.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.15, 0.1)), Vector3(0.6, 0.45, 0.75), 7, 14, shell)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.58, 0.1)), Vector3(0.06, 0.05, 1.3), shell.darkened(0.35))
	for i in 3:
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.3 - i * 0.02, -0.3 + i * 0.35)), 0.62, 0.62, 0.05, 14, shell.lightened(0.15), false)
	# Head with horn.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.08, -0.68)), Vector3(0.32, 0.24, 0.26), 5, 10, shell.darkened(0.3))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, -1.1), Vector3(0, 0.22, -0.9)), 0.08, 0.0, 0.45, 6, Palette.BONE)
	_eyes(st, Vector3(0, 0.15, -0.88), 0.14, 0.05)
	# Rattle tail: glowing weak spot at the back.
	for i in 3:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.2, 0.85 + i * 0.16)), Vector3(0.14 - i * 0.025, 0.1, 0.09), 4, 8, Palette.GLOW_YELLOW if i == 2 else Palette.BONE, 0.0, null, 0.75 if i == 2 else 0.0)
	return {
		"body": MeshKit.finish(st), "legs": _legs(3, -0.4, 0.5, 0.45, 0.0, 0.6, -0.3),
		"upper": 0.55, "lower": 0.55, "thick": 0.08, "leg_color": shell.darkened(0.5), "ik": true,
		"weak_spot": Vector3(0, 0.2, 1.17), "weak_radius": 0.2, "body_radius": 0.85, "clearance": 0.4,
	}


static func _scorpion(shell: Color) -> Dictionary:
	var st := MeshKit.begin()
	for i in 4:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.1, -0.3 + i * 0.28)), Vector3(0.38 - i * 0.04, 0.2, 0.2), 5, 10, shell if i % 2 == 0 else shell.darkened(0.12))
	# Pincers.
	for side: float in [-1.0, 1.0]:
		var a := Vector3(side * 0.25, 0.1, -0.45)
		var b := Vector3(side * 0.55, 0.15, -0.8)
		MeshKit.add_limb(st, a, b, 0.07, shell.darkened(0.2), 6)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), b + Vector3(0, 0, -0.18)), Vector3(0.14, 0.09, 0.22), 4, 8, shell.darkened(0.3))
	# Tail curling up over the back, ending in a glowing acid bulb (weak spot).
	var prev := Vector3(0, 0.15, 0.55)
	for i in 5:
		var t := float(i + 1) / 5.0
		var p := Vector3(0, 0.15 + sin(t * PI * 0.8) * 0.9, 0.55 + cos(t * PI * 0.9) * 0.35 + t * 0.1 - 0.35)
		MeshKit.add_limb(st, prev, p, 0.09 - i * 0.01, shell, 6)
		prev = p
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), prev + Vector3(0, 0.05, -0.08)), Vector3.ONE * 0.16, 5, 8, Palette.ACID_GREEN, 0.0, null, 0.8)
	_eyes(st, Vector3(0, 0.22, -0.42), 0.07, 0.04)
	return {
		"body": MeshKit.finish(st), "legs": _legs(4, -0.25, 0.45, 0.3, 0.0, 0.6, -0.25),
		"upper": 0.45, "lower": 0.5, "thick": 0.05, "leg_color": shell.darkened(0.35), "ik": true,
		"weak_spot": prev + Vector3(0, 0.05, -0.08), "weak_radius": 0.22, "body_radius": 0.6, "clearance": 0.32,
	}

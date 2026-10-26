class_name WeaponBuilder
extends RefCounted
## First-person weapon meshes built from primitives. Barrel points along -Z.

## Revolver body (without the cylinder drum, which spins on its own).
static func revolver_body() -> ArrayMesh:
	var st := MeshKit.begin()
	var along_z := Basis(Vector3.RIGHT, PI * 0.5)
	# Barrel and the rod under it.
	MeshKit.add_cylinder(st, Transform3D(along_z, Vector3(0, 0.02, -0.15)), 0.016, 0.016, 0.2, 10, Palette.METAL)
	MeshKit.add_cylinder(st, Transform3D(along_z, Vector3(0, -0.005, -0.12)), 0.008, 0.008, 0.14, 6, Palette.METAL.darkened(0.2))
	# Frame.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.01, 0.0)), Vector3(0.035, 0.07, 0.1), Palette.METAL.darkened(0.15))
	# Front sight and hammer.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.042, -0.24)), Vector3(0.006, 0.014, 0.01), Palette.METAL)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.05, 0.06)), Vector3(0.012, 0.035, 0.015), Palette.METAL.darkened(0.3))
	# Trigger guard.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.04, 0.015)), Vector3(0.012, 0.008, 0.05), Palette.METAL.darkened(0.2))
	# Wooden grip, angled back.
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, -0.07, 0.075)), Vector3(0.032, 0.11, 0.045), Palette.WOOD)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -0.12, 0.095)), Vector3(0.018, 0.012, 0.026), 3, 8, Palette.WOOD_DARK)
	return MeshKit.finish(st)


## The six-shot cylinder drum, centred, rotating around Z.
static func revolver_drum() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.03, 0.03, 0.055, 12, Palette.METAL.lightened(0.1))
	for i in 6:
		var a := TAU * float(i) / 6.0
		var p := Vector3(cos(a), sin(a), 0) * 0.019
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(0, 0, -0.026)), 0.006, 0.006, 0.006, 6, Palette.GLOW_YELLOW.darkened(0.3), true)
	return MeshKit.finish(st)


## The crash-test-dummy hand and forearm holding the revolver grip (first person).
static func dummy_hand() -> ArrayMesh:
	var st := MeshKit.begin()
	var yellow := Color("#E8C547")
	var joint := Color("#3A3A40")
	# Fist around the grip.
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0.0, -0.075, 0.08)), Vector3(0.05, 0.08, 0.06), yellow)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(-0.022, -0.06, 0.055)), Vector3(0.02, 0.05, 0.03), yellow.darkened(0.1))
	# Wrist joint and forearm reaching back and down out of view.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.0, -0.11, 0.13)), Vector3.ONE * 0.03, 4, 8, joint)
	MeshKit.add_limb(st, Vector3(0.0, -0.11, 0.13), Vector3(0.04, -0.3, 0.45), 0.03, yellow, 8)
	return MeshKit.finish(st)

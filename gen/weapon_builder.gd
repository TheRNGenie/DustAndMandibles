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

class_name CharacterBuilder
extends RefCounted
## Third-person body for the other player: a chunky cowboy with a team-colour bandana.
## Origin at the feet, facing -Z, about 1.8 m tall.

const SKIN := Color("#E0A57A")
const SHIRT := Color("#D9C7A0")
const VEST := Color("#5A3A2B")
const JEANS := Color("#3E5A7A")
const BOOTS := Color("#3B2418")
const HAT := Color("#7A5232")


static func cowboy(team: Color) -> ArrayMesh:
	var st := MeshKit.begin()
	# Boots and legs.
	for side: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(side * 0.13, 0.08, -0.04)), Vector3(0.16, 0.16, 0.3), BOOTS)
		MeshKit.add_limb(st, Vector3(side * 0.13, 0.2, 0), Vector3(side * 0.12, 0.85, 0), 0.085, JEANS)
	# Belt with a shiny buckle.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.9, 0)), 0.2, 0.2, 0.08, 10, BOOTS)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.9, -0.2)), Vector3(0.09, 0.06, 0.02), Palette.GLOW_YELLOW)
	# Torso and vest.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.17, 0)), Vector3(0.4, 0.48, 0.24), SHIRT)
	for side: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(side * 0.12, 1.17, -0.005)), Vector3(0.15, 0.46, 0.25), VEST)
	# Arms.
	for side: float in [-1.0, 1.0]:
		MeshKit.add_limb(st, Vector3(side * 0.25, 1.36, 0), Vector3(side * 0.3, 1.02, -0.06), 0.065, SHIRT)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(side * 0.31, 0.96, -0.08)), Vector3.ONE * 0.06, 4, 6, SKIN)
	# Bandana (team colour) and head.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 1.45, 0)), 0.13, 0.11, 0.1, 10, team)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, 1.38, -0.11)), 0.07, 0.0, 0.16, 4, team)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 1.58, 0)), Vector3(0.13, 0.15, 0.14), 6, 10, SKIN)
	# Eyes, so you can tell which way they face.
	for side: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(side * 0.05, 1.6, -0.13)), Vector3(0.03, 0.04, 0.02), Palette.OUTLINE)
	# Hat: wide brim and crown.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 1.69, 0)), 0.32, 0.3, 0.03, 14, HAT)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 1.79, 0)), 0.15, 0.13, 0.18, 12, HAT)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 1.72, 0)), 0.155, 0.155, 0.04, 12, team.darkened(0.3))
	return MeshKit.finish(st)

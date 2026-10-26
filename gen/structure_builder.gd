class_name StructureBuilder
extends RefCounted
## Meshes for traps and survival structures. Origin on the ground.

static func build(kind: StructureDef.Kind) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 60 + int(kind)
	var st := MeshKit.begin()
	match kind:
		StructureDef.Kind.BARBED_WIRE:
			for x: float in [-0.9, 0.9]:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 0.35, 0)), Vector3(0.1, 0.7, 0.1), Palette.WOOD, 0.02, rng)
			for i in 9:
				var a := float(i) / 8.0
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(lerpf(-0.9, 0.9, a), 0.35 + sin(a * TAU * 2.0) * 0.12, cos(a * TAU * 2.0) * 0.12)),
						Vector3(0.12, 0.12, 0.12), 3, 6, Palette.METAL.lightened(0.2))
		StructureDef.Kind.BEAR_TRAP:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.04, 0)), 0.45, 0.45, 0.06, 12, Palette.METAL.darkened(0.2))
			for i in 8:
				var a := TAU * float(i) / 8.0
				MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(cos(a) * 0.4, 0.12, sin(a) * 0.4)), 0.04, 0.0, 0.15, 4, Palette.METAL.lightened(0.3))
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.08, 0)), 0.12, 0.12, 0.03, 8, Palette.GLOW_YELLOW.darkened(0.4))
		StructureDef.Kind.DYNAMITE_CRATE:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.35, 0)), Vector3(0.8, 0.7, 0.6), Palette.WOOD, 0.03, rng)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.4, -0.31)), Vector3(0.5, 0.25, 0.02), Palette.TEAM_WEST)
			for i in 4:
				MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-0.24 + i * 0.16, 0.8, 0)), 0.06, 0.06, 0.25, 6, Palette.TEAM_WEST.darkened(0.1))
		StructureDef.Kind.PALISADE:
			for i in 5:
				var h := rng.randf_range(1.8, 2.3)
				MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-0.8 + i * 0.4, h * 0.5, 0)), 0.18, 0.17, h, 7, Palette.WOOD)
				MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-0.8 + i * 0.4, h + 0.15, 0)), 0.17, 0.0, 0.3, 7, Palette.WOOD_DARK)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.2, -0.2)), Vector3(2.0, 0.15, 0.08), Palette.WOOD_DARK)
		StructureDef.Kind.LANTERN:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 1.1, 0)), 0.08, 0.07, 2.2, 6, Palette.WOOD)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.25, 2.15, 0)), Vector3(0.6, 0.06, 0.06), Palette.WOOD_DARK)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.5, 1.85, 0)), Vector3(0.2, 0.28, 0.2), Palette.GLOW_YELLOW, 0.0, null, 0.85)
		StructureDef.Kind.FARM_PLOT:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(1.7, 0.18, 1.7), Palette.DIRT_DARK)
		StructureDef.Kind.RAIN_CATCHER:
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.45, 0)), 0.5, 0.55, 0.9, 12, Palette.WOOD)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.92, 0)), 0.45, 0.45, 0.03, 12, Palette.SKY_TOP, false, 0.35)
			for a: float in [0.0, PI * 0.5, PI, PI * 1.5]:
				MeshKit.add_limb(st, Vector3(cos(a) * 0.5, 0.9, sin(a) * 0.5), Vector3(cos(a) * 1.0, 1.8, sin(a) * 1.0), 0.04, Palette.WOOD_DARK, 5)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 1.5, 0)), 0.3, 1.05, 0.6, 12, Palette.BONE, false)
	return MeshKit.finish(st)

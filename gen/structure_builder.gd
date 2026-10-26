class_name StructureBuilder
extends RefCounted
## Meshes for traps and survival structures. Origin on the ground.

const IRON := Color("#4A4E58")
const BRASS := Color("#D6A74A")


static func build(kind: StructureDef.Kind) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 60 + int(kind)
	var st := MeshKit.begin()
	match kind:
		StructureDef.Kind.BARBED_WIRE:
			# Crossed X posts with coils of wire strung between, barbs along it.
			for x: float in [-0.9, 0.9]:
				for s: float in [-1.0, 1.0]:
					MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, s * 0.45), Vector3(x, 0.38, 0)), Vector3(0.08, 0.85, 0.08), Palette.WOOD, 0.02, rng)
			var prev := Vector3(-0.9, 0.35, 0.12)
			for i in 49:
				var a := float(i) / 48.0
				var p := Vector3(lerpf(-0.9, 0.9, a), 0.38 + sin(a * TAU * 5.0) * 0.18, cos(a * TAU * 5.0) * 0.18)
				MeshKit.add_limb(st, prev, p, 0.012, IRON.lightened(0.3), 4)
				if i % 3 == 0:
					MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, rng.randf() * TAU), p), 0.012, 0.0, 0.09, 3, IRON.lightened(0.4))
				prev = p
			# A scrap of cloth snagged on it.
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.4), Vector3(0.3, 0.45, 0.15)), Vector3(0.18, 0.12, 0.01), Color("#C8A878"))
		StructureDef.Kind.BEAR_TRAP:
			# Iron jaws open wide around a pressure plate, chained to a stake.
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.03, 0)), 0.47, 0.47, 0.05, 14, IRON)
			for side: float in [-1.0, 1.0]:
				for i in 7:
					var a := lerpf(-1.2, 1.2, float(i) / 6.0)
					var p := Vector3(sin(a) * 0.42, 0.06, side * cos(a) * 0.42)
					MeshKit.add_cylinder(st, Transform3D(Basis(Vector3(side, 0, 0).cross(Vector3.UP).normalized(), side * 0.5), p + Vector3(0, 0.08, 0)), 0.035, 0.0, 0.18, 4, Palette.METAL.lightened(0.35))
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.05, side * 0.43)), Vector3(0.85, 0.06, 0.05), IRON.darkened(0.1))
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.07, 0)), 0.14, 0.14, 0.03, 10, BRASS.darkened(0.2))
			for i in 4:
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.55 + i * 0.08, 0.03, 0)), 0.025, 0.025, 0.06, 6, IRON)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0.9, 0.12, 0)), 0.04, 0.0, 0.3, 5, IRON)
		StructureDef.Kind.DYNAMITE_CRATE:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.35, 0)), Vector3(0.8, 0.7, 0.6), Palette.WOOD, 0.03, rng)
			for y: float in [0.1, 0.6]:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, 0)), Vector3(0.82, 0.08, 0.62), Palette.WOOD_DARK)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.36, -0.31)), Vector3(0.5, 0.25, 0.02), Palette.BONE)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.36, -0.322)), Vector3(0.4, 0.06, 0.01), Color("#B8352A"))
			# Bundled sticks poking out the top with curling fuses.
			for i in 5:
				var x := -0.24 + i * 0.12
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, (i - 2) * 0.08), Vector3(x, 0.8, 0)), 0.055, 0.055, 0.3, 8, Color("#C8352A"))
				MeshKit.add_limb(st, Vector3(x, 0.95, 0), Vector3(x + 0.04, 1.05, 0.03), 0.008, Palette.BONE, 3)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.82, 0)), Vector3(0.65, 0.04, 0.12), Color("#3A2416"))
		StructureDef.Kind.PALISADE:
			# Sharpened logs lashed with rope, with a cross brace and a warning skull.
			for i in 5:
				var h := rng.randf_range(1.8, 2.3)
				var x := -0.8 + i * 0.4
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.04, 0.04)), Vector3(x, h * 0.5, 0)), 0.18, 0.17, h, 8, Palette.WOOD.darkened(rng.randf() * 0.12))
				MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(x, h + 0.15, 0)), 0.17, 0.0, 0.3, 8, Palette.WOOD_DARK.lightened(0.15))
				for y: float in [0.6, 1.5]:
					MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(x, y, 0)), 0.185, 0.185, 0.05, 8, Color("#B8955A"))
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.35), Vector3(0, 1.0, -0.2)), Vector3(2.0, 0.14, 0.08), Palette.WOOD_DARK)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 1.7, -0.24)), Vector3(0.14, 0.12, 0.1), 4, 8, Palette.BONE)
			for s: float in [-1.0, 1.0]:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(s * 0.05, 1.72, -0.33)), Vector3(0.035, 0.03, 0.01), 3, 6, Palette.OUTLINE)
		StructureDef.Kind.LANTERN:
			# A crooked post with a hook arm; the lantern itself swings (StructureNode).
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, 0.03), Vector3(0, 1.1, 0)), 0.08, 0.06, 2.2, 7, Palette.WOOD)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.25, 2.15, 0)), Vector3(0.6, 0.06, 0.06), Palette.WOOD_DARK)
			MeshKit.add_limb(st, Vector3(0.05, 1.8, 0), Vector3(0.35, 2.12, 0), 0.025, Palette.WOOD_DARK, 4)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.1, 0)), 0.2, 0.25, 0.2, 8, Palette.ROCK_B, true)
		StructureDef.Kind.SCAFFOLD:
			return ScaffoldNode.mesh_for(1)
		StructureDef.Kind.FARM_PLOT:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(1.7, 0.18, 1.7), Palette.DIRT_DARK)
		StructureDef.Kind.RAIN_CATCHER:
			# A hooped barrel under a canvas funnel on four legs, with a tap.
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.45, 0)), 0.5, 0.55, 0.9, 14, Palette.WOOD)
			for y: float in [0.15, 0.45, 0.78]:
				MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, y, 0)), 0.56 - y * 0.06, 0.56 - y * 0.06, 0.04, 14, IRON)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.92, 0)), 0.45, 0.45, 0.03, 14, Palette.SKY_TOP, false, 0.35)
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.2, -0.55)), 0.03, 0.03, 0.12, 6, BRASS)
			for a: float in [0.0, PI * 0.5, PI, PI * 1.5]:
				MeshKit.add_limb(st, Vector3(cos(a) * 0.5, 0.9, sin(a) * 0.5), Vector3(cos(a) * 1.0, 1.8, sin(a) * 1.0), 0.04, Palette.WOOD_DARK, 5)
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 1.5, 0)), 0.3, 1.05, 0.6, 14, Palette.BONE, false)
			for a in 8:
				var ang := TAU * a / 8.0
				MeshKit.add_limb(st, Vector3(cos(ang) * 0.3, 1.21, sin(ang) * 0.3), Vector3(cos(ang) * 1.04, 1.79, sin(ang) * 1.04), 0.01, Palette.BONE.darkened(0.2), 3)
	return MeshKit.finish(st)


## The swinging lantern for a lantern post: a brass cage around a glowing glass.
static func lantern() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_limb(st, Vector3(0, 0, 0), Vector3(0, -0.12, 0), 0.01, IRON, 3)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.15, 0)), 0.05, 0.13, 0.08, 8, IRON)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.32, 0)), 0.1, 0.1, 0.26, 8, Palette.GLOW_YELLOW, true, 0.85)
	for i in 4:
		var a := TAU * i / 4.0
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(cos(a) * 0.11, -0.32, sin(a) * 0.11)), Vector3(0.02, 0.28, 0.02), BRASS)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.48, 0)), 0.13, 0.13, 0.05, 8, IRON)
	return MeshKit.finish(st)

class_name AmberBuilder
extends RefCounted
## Meshes for the three hive amber turrets (AmberRules / AmberTurret), in the
## parts TurretBuilder uses (base / head / gun, barrels along -Z toward the
## canyon). They're meant to look like nothing else on the cliff: glowing amber
## (vertex glow), gold and polished brass on blackened iron, with the team's
## pennant like every turret.
##   Amber Kiln      a squat round brick furnace, firebox glowing, a gold-banded
##                   crucible mortar set in its crown full of molten amber.
##   Queen's Bell    a great bell of cast amber hung in a gilded iron frame on a
##                   stone plinth, a boiler and a steam hammer beside it.
##   Mandible Lance  a brass carriage on a short rail, an amber fuel tank, and a
##                   long finned lance ending in a pair of queen's mandibles with
##                   a glowing amber crystal between them.

const BRASS := Color("#D6A74A")
const GOLD := Color("#D4A23A")
const IRON := Color("#34373E")
const BRICK := Color("#8E4A30")
const BRICK_DARK := Color("#6A3424")
const STONE := Color("#A39686")
const SOOT := Color("#2A2522")
const CHITIN := Color("#3A2A1E")
const OUT := Basis(Vector3.RIGHT, -PI * 0.5) # lathe profiles (along +Y) turned to run out along -Z
const ALONG := Basis(Vector3.RIGHT, PI * 0.5)
const ACROSS := Basis(Vector3.BACK, PI * 0.5)


static func has(id: StringName) -> bool:
	return AmberRules.is_amber(id)


static func build(id: StringName, team: Color) -> Dictionary:
	match id:
		AmberRules.BELL:
			return _bell(team)
		AmberRules.LANCE:
			return _lance(team)
	return _kiln(team)


static func _rivets(st: SurfaceTool, c: Vector3, r: float, y: float, n: int, color: Color = BRASS) -> void:
	for i in n:
		var a := TAU * float(i) / n
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), c + Vector3(cos(a) * r, y, sin(a) * r)), Vector3.ONE * 0.022, 3, 5, color)


## A few drips and lumps of amber stuck on something.
static func _amber_drips(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, r: float, y: float, n: int) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var p := c + Vector3(cos(a) * r, y, sin(a) * r)
		var drip := rng.randf_range(0.08, 0.22)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), p), Vector3(0.05, 0.04, 0.05), 4, 7, AmberRules.COLOR, 0.0, null, 0.7)
		MeshKit.add_cylinder(st, Transform3D(Basis(), p - Vector3(0, drip * 0.5, 0)), 0.035, 0.012, drip, 6, AmberRules.COLOR, true, 0.7)


# ------------------------------------------------------------------ Amber Kiln

static func _kiln(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var base := MeshKit.begin()
	# Flagstone pad and a ring of stacked bricks: a squat round furnace, wider at the foot.
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.06, 0)), 0.98, 1.0, 0.12, 20, STONE.darkened(0.15))
	var rows := 9
	for r in rows:
		var y := 0.16 + r * 0.115
		var rad := lerpf(0.86, 0.66, float(r) / rows)
		var n := 16
		for i in n:
			var a := TAU * (float(i) + (0.5 if r % 2 == 1 else 0.0)) / n
			# The firebox mouth faces the back (+Z): leave a gap there for the lowest rows.
			if r < 4 and absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.42:
				continue
			var p := Vector3(cos(a) * rad, y, sin(a) * rad)
			MeshKit.add_box(base, Transform3D(Basis(Vector3.UP, -a), p), Vector3(0.12, 0.1, rad * TAU / n * 0.92), BRICK.lerp(BRICK_DARK, rng.randf() * 0.6), 0.008, rng)
	# Inner wall (so the gaps don't show daylight) and the glowing firebox.
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 0.66, 0)), 0.8, 0.6, 1.05, 16, SOOT)
	MeshKit.add_ellipsoid(base, Transform3D(Basis(), Vector3(0, 0.38, 0.62)), Vector3(0.3, 0.22, 0.18), 5, 10, Color("#FF9A2A"), 0.0, null, 1.0)
	for i in 5:
		MeshKit.add_ellipsoid(base, Transform3D(Basis(), Vector3(-0.2 + i * 0.1, 0.24, 0.66 + rng.randf() * 0.05)), Vector3(0.07, 0.05, 0.06), 3, 6, AmberRules.GLOW, 0.2, rng, 0.9)
	# Iron firebox door hanging open, brass hinge.
	MeshKit.add_box(base, Transform3D(Basis(Vector3.UP, 1.1), Vector3(0.42, 0.4, 0.9)), Vector3(0.36, 0.38, 0.04), IRON)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0.3, 0.4, 0.82)), 0.025, 0.025, 0.42, 6, BRASS)
	# Gold bands round the furnace, riveted.
	for y: float in [0.3, 0.78, 1.12]:
		var rad := lerpf(0.88, 0.68, (y - 0.16) / (rows * 0.115))
		MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, y, 0)), rad + 0.02, rad + 0.02, 0.05, 20, GOLD, false)
		_rivets(base, Vector3.ZERO, rad + 0.03, y, 14)
	# A crown ring of amber-streaked brick the turntable sits in, dripping resin.
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(0, 1.2, 0)), 0.7, 0.66, 0.1, 18, BRICK_DARK)
	_amber_drips(base, rng, Vector3.ZERO, 0.7, 1.12, 9)
	# A little chimney stack at the back, smouldering, and a coal scuttle of amber.
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(-0.55, 1.35, 0.45)), 0.11, 0.09, 0.7, 10, BRICK_DARK)
	MeshKit.add_cylinder(base, Transform3D(Basis(), Vector3(-0.55, 1.72, 0.45)), 0.12, 0.12, 0.05, 10, GOLD)
	MeshKit.add_ellipsoid(base, Transform3D(Basis(), Vector3(-0.55, 1.73, 0.45)), Vector3(0.07, 0.02, 0.07), 3, 8, Color("#FF7A1E"), 0.0, null, 1.0)
	var scuttle := Vector3(0.78, 0.2, 0.55)
	MeshKit.add_cylinder(base, Transform3D(Basis(), scuttle), 0.17, 0.2, 0.28, 10, IRON)
	for i in 6:
		MeshKit.add_ellipsoid(base, Transform3D(Basis(), scuttle + Vector3(rng.randf_range(-0.1, 0.1), 0.15 + rng.randf() * 0.05, rng.randf_range(-0.1, 0.1))), Vector3.ONE * 0.065, 4, 7, AmberRules.COLOR.lerp(AmberRules.DEEP, rng.randf() * 0.4), 0.15, rng, 0.6)
	TurretBuilder._pennant(base, Vector3(-0.9, 0.12, -0.2), 1.6, team)
	# Head: a gold turntable ring with two trunnion cheeks.
	var head := MeshKit.begin()
	MeshKit.add_cylinder(head, Transform3D(), 0.58, 0.58, 0.1, 20, IRON)
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.06, 0)), 0.6, 0.6, 0.03, 20, GOLD)
	_rivets(head, Vector3.ZERO, 0.57, 0.08, 16)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.48, 0.22, 0)), Vector3(0.08, 0.36, 0.38), IRON)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(s * 0.53, 0.3, 0)), 0.08, 0.08, 0.04, 12, GOLD)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.08, 0.44)), Vector3(0.4, 0.14, 0.04), team)
	# Gun: a fat bronze crucible mortar, gold bands, molten amber in the mouth.
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.07, 0.07, 1.0, 10, IRON)
	MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(0, 0, 0.12)), Vector3(0.36, 0.34, 0.34), 6, 14, Color("#9A6A30"))
	MeshKit.lathe(gun, Transform3D(OUT, Vector3(0, 0, 0.12)), [Vector2(0.34, 0.0), Vector2(0.36, 0.15), Vector2(0.32, 0.42),
			Vector2(0.3, 0.62), Vector2(0.36, 0.68), Vector2(0.36, 0.76), Vector2(0.27, 0.78)], 16, Color("#A8763A"))
	for z: float in [-0.08, -0.32, -0.6]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.36 + z * 0.03, 0.36 + z * 0.03, 0.05, 16, GOLD)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.62)), 0.26, 0.26, 0.02, 16, AmberRules.GLOW, true, 1.0)
	# Molten amber slopping over the lip and dripping down the barrel.
	for i in 5:
		var a := -0.9 + i * 0.45
		var p := Vector3(cos(a) * 0.3, sin(a) * 0.3, -0.62)
		MeshKit.tube(gun, [p, p + Vector3(0, -0.06, 0.12), p + Vector3(0, -0.14, 0.22)], [0.05, 0.04, 0.015], 6, AmberRules.COLOR, 0.8)
	# Embossed hive-hexes on the barrel, glowing.
	for i in 6:
		var a := TAU * float(i) / 6.0
		MeshKit.add_cylinder(gun, Transform3D(Basis(Vector3.FORWARD, a) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(cos(a) * 0.335, sin(a) * 0.335, -0.2).normalized() * 0.335 + Vector3(0, 0, -0.2)), 0.06, 0.06, 0.02, 6, AmberRules.COLOR, true, 0.6)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.18, "head_y": 1.25, "gun_y": 0.32, "muzzle": Vector3(0, 0, -0.78)}


# ------------------------------------------------------------------ Queen's Bell

## The bell hangs at the frame's middle; the steam hammer (the "gun") swings
## into it (+Z in gun space) when it tolls. Head and gun don't turn (AmberTurret).
static func _bell(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2209
	var base := MeshKit.begin()
	# Stepped stone plinth.
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(1.9, 0.2, 1.7), STONE.darkened(0.1), 0.01, rng)
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.27, 0)), Vector3(1.6, 0.14, 1.4), STONE, 0.01, rng)
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.355, 0)), Vector3(1.64, 0.03, 1.44), GOLD)
	# Gilded iron frame: two uprights with diagonal braces and a crossbeam.
	for s: float in [-1.0, 1.0]:
		var x := s * 0.72
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(x, 1.65, 0)), Vector3(0.14, 2.6, 0.18), IRON)
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(x, 1.65, 0)), Vector3(0.16, 0.06, 0.2), GOLD)
		for k: float in [-1.0, 1.0]:
			MeshKit.add_limb(base, Vector3(x, 0.4, k * 0.6), Vector3(x, 1.4, 0.0), 0.04, IRON, 6)
		MeshKit.add_ellipsoid(base, Transform3D(Basis(), Vector3(x, 3.0, 0)), Vector3(0.12, 0.12, 0.12), 5, 8, GOLD)
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 2.92, 0)), Vector3(1.62, 0.16, 0.22), IRON)
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 3.0, 0)), Vector3(1.64, 0.03, 0.24), GOLD)
	# Hive scrollwork along the crossbeam.
	for i in 7:
		MeshKit.add_cylinder(base, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.6 + i * 0.2, 2.92, 0.115)), 0.045, 0.045, 0.02, 6, GOLD)
	# The yoke and the great bell of cast amber.
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 2.76, 0)), Vector3(0.34, 0.16, 0.26), IRON)
	var bell_c := Vector3(0, 1.62, 0)
	MeshKit.lathe(base, Transform3D(Basis(), bell_c), [Vector2(0.0, 1.08), Vector2(0.22, 1.06), Vector2(0.36, 0.98), Vector2(0.42, 0.8),
			Vector2(0.44, 0.5), Vector2(0.5, 0.2), Vector2(0.62, -0.05), Vector2(0.7, -0.12), Vector2(0.66, -0.16), Vector2(0.56, -0.1)], 24, AmberRules.COLOR.darkened(0.08), Vector2.ONE, 0.22)
	# Gold lip band, waist band and crown loops.
	MeshKit.add_cylinder(base, Transform3D(Basis(), bell_c + Vector3(0, -0.1, 0)), 0.705, 0.69, 0.06, 24, GOLD, false)
	MeshKit.add_cylinder(base, Transform3D(Basis(), bell_c + Vector3(0, 0.62, 0)), 0.445, 0.445, 0.05, 24, GOLD, false)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_limb(base, bell_c + Vector3(s * 0.12, 1.06, 0), bell_c + Vector3(s * 0.08, 1.22, 0), 0.035, GOLD, 6)
	# The bug inside: a dark queen-ish silhouette set in the amber.
	MeshKit.add_ellipsoid(base, Transform3D(Basis(), bell_c + Vector3(0, 0.45, 0)), Vector3(0.16, 0.24, 0.16), 5, 10, CHITIN)
	# Clapper.
	MeshKit.add_limb(base, bell_c + Vector3(0, 1.0, 0), bell_c + Vector3(0, 0.0, 0), 0.03, IRON, 6)
	MeshKit.add_ellipsoid(base, Transform3D(Basis(), bell_c + Vector3(0, -0.05, 0)), Vector3.ONE * 0.11, 5, 8, GOLD)
	# The boiler beside it (the hammer's steam), brass pipes, a pressure gauge.
	var boil := Vector3(0.0, 0.85, 0.62)
	MeshKit.add_cylinder(base, Transform3D(ACROSS, boil), 0.26, 0.26, 1.1, 14, IRON.lightened(0.1))
	for x: float in [-0.5, 0.0, 0.5]:
		MeshKit.add_cylinder(base, Transform3D(ACROSS, boil + Vector3(x, 0, 0)), 0.275, 0.275, 0.04, 14, BRASS)
	MeshKit.add_cylinder(base, Transform3D(Basis(), boil + Vector3(0.38, 0.38, 0)), 0.04, 0.04, 0.5, 8, BRASS)
	MeshKit.add_cylinder(base, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), boil + Vector3(-0.3, 0.2, 0.26)), 0.09, 0.09, 0.03, 12, GOLD)
	MeshKit.add_cylinder(base, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), boil + Vector3(-0.3, 0.2, 0.275)), 0.075, 0.075, 0.01, 12, Palette.BONE)
	MeshKit.add_box(base, Transform3D(Basis(Vector3.BACK, 0.7), boil + Vector3(-0.3, 0.22, 0.285)), Vector3(0.008, 0.06, 0.004), Color("#C8362B"))
	MeshKit.add_ellipsoid(base, Transform3D(Basis(), boil + Vector3(0, -0.02, 0.28)), Vector3(0.18, 0.12, 0.04), 4, 8, Color("#FF8A2A"), 0.0, null, 0.9)
	TurretBuilder._pennant(base, Vector3(0.72, 3.05, 0), 0.9, team)
	_amber_drips(base, rng, bell_c + Vector3(0, -0.1, 0), 0.66, 0.0, 6)
	# Head: the hammer's pivot block on the boiler (it never turns).
	var head := MeshKit.begin()
	MeshKit.add_box(head, Transform3D(), Vector3(0.24, 0.2, 0.24), IRON)
	MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(0, 0.02, 0)), 0.07, 0.07, 0.32, 10, GOLD)
	# Gun: the steam hammer, a piston and a fat gold-capped head aimed at the bell (+Z here).
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.32)), 0.11, 0.11, 0.5, 12, IRON.lightened(0.15))
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.07)), 0.125, 0.125, 0.04, 12, BRASS)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, 0.05)), 0.045, 0.045, 0.3, 8, Color("#C9CED6"))
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, 0.24)), 0.13, 0.13, 0.16, 14, IRON)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, 0.33)), 0.14, 0.14, 0.03, 14, GOLD)
	# Head at 1.62 + 0.45 over the plinth, just off the bell's shoulder (0.55 from its axis at rest).
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.22, "head_y": 2.07, "gun_y": 0.0, "muzzle": Vector3(0, 0, 0.34), "bell": true}


# ------------------------------------------------------------------ Mandible Lance

static func _lance(team: Color) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5531
	var base := MeshKit.begin()
	# Stone pad, sleepers and two short gold-capped rails across the lip (the carriage runs on them).
	MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(1.9, 0.16, 1.4), STONE.darkened(0.12), 0.01, rng)
	for i in 5:
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(-0.8 + i * 0.4, 0.2, 0)), Vector3(0.16, 0.08, 1.1), Palette.WOOD_DARK.darkened(rng.randf() * 0.2), 0.01, rng)
	for z: float in [-0.32, 0.32]:
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.28, z)), Vector3(1.86, 0.08, 0.07), IRON.lightened(0.2))
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(0, 0.33, z)), Vector3(1.86, 0.02, 0.09), BRASS)
		for x: float in [-0.95, 0.95]:
			MeshKit.add_box(base, Transform3D(Basis(), Vector3(x, 0.34, z)), Vector3(0.06, 0.12, 0.12), GOLD)
	# Glass fuel tank of glowing amber in a brass cage at the back, piped forward.
	var tank := Vector3(0.0, 0.62, 0.62)
	MeshKit.add_cylinder(base, Transform3D(ACROSS, tank), 0.26, 0.26, 1.2, 16, AmberRules.COLOR, true, 0.35)
	for x: float in [-0.58, -0.2, 0.2, 0.58]:
		MeshKit.add_cylinder(base, Transform3D(ACROSS, tank + Vector3(x, 0, 0)), 0.28, 0.28, 0.04, 16, BRASS)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		MeshKit.add_box(base, Transform3D(Basis(), tank + Vector3(0, sin(a) * 0.27, cos(a) * 0.27)), Vector3(1.18, 0.03, 0.03), BRASS)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(base, Transform3D(Basis(), Vector3(s * 0.62, 0.38, 0.62)), Vector3(0.06, 0.4, 0.06), IRON)
	MeshKit.tube(base, [tank + Vector3(0.3, 0.2, -0.1), tank + Vector3(0.3, 0.45, -0.35), Vector3(0.3, 0.9, -0.05)], [0.035, 0.035, 0.035], 6, BRASS)
	TurretBuilder._pennant(base, Vector3(-0.85, 0.16, 0.55), 1.7, team)
	# Head: the carriage, a bogie with four wheels and a gold-banded housing.
	var head := MeshKit.begin()
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, -0.12, 0)), Vector3(0.7, 0.1, 0.8), IRON)
	for x: float in [-0.25, 0.25]:
		for z: float in [-0.32, 0.32]:
			MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(x, -0.2, z)), 0.1, 0.1, 0.06, 12, IRON.lightened(0.2))
			MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(x, -0.2, z)), 0.04, 0.04, 0.08, 8, GOLD)
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.05, 0)), 0.36, 0.42, 0.26, 16, IRON.lightened(0.08))
	MeshKit.add_cylinder(head, Transform3D(Basis(), Vector3(0, 0.19, 0)), 0.37, 0.37, 0.04, 16, GOLD)
	_rivets(head, Vector3.ZERO, 0.4, 0.06, 14)
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(head, Transform3D(Basis(), Vector3(s * 0.3, 0.38, 0)), Vector3(0.07, 0.36, 0.34), IRON)
		MeshKit.add_cylinder(head, Transform3D(ACROSS, Vector3(s * 0.34, 0.42, 0)), 0.07, 0.07, 0.04, 12, GOLD)
	MeshKit.add_box(head, Transform3D(Basis(), Vector3(0, 0.12, 0.38)), Vector3(0.4, 0.12, 0.04), team)
	# Gun: the lance. Breech chamber with heat fins, a long brass-ringed barrel, and
	# the mandible emitter: two curved chitin prongs round a glowing amber crystal.
	var gun := MeshKit.begin()
	MeshKit.add_cylinder(gun, Transform3D(ACROSS, Vector3.ZERO), 0.06, 0.06, 0.62, 10, IRON)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, 0.2)), 0.2, 0.2, 0.5, 14, IRON.lightened(0.1))
	for i in 7:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, 0.0 + i * 0.065)), 0.27, 0.27, 0.02, 14, BRASS.darkened(0.1 * (i % 2)))
	MeshKit.add_ellipsoid(gun, Transform3D(Basis(), Vector3(0, 0.0, 0.47)), Vector3(0.19, 0.19, 0.08), 5, 12, GOLD)
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -0.55)), 0.09, 0.075, 1.2, 12, IRON.lightened(0.2))
	for z: float in [-0.15, -0.5, -0.85]:
		MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, z)), 0.11, 0.11, 0.05, 12, GOLD)
	# A glowing amber line inlaid along the top of the barrel.
	MeshKit.add_box(gun, Transform3D(Basis(), Vector3(0, 0.085, -0.55)), Vector3(0.03, 0.02, 1.1), AmberRules.GLOW, 0.0, null, 0.9)
	# Emitter collar and the two mandibles.
	MeshKit.add_cylinder(gun, Transform3D(ALONG, Vector3(0, 0, -1.2)), 0.15, 0.12, 0.14, 14, GOLD)
	for s: float in [-1.0, 1.0]:
		var pts: Array = []
		var radii: Array = []
		for k in 6:
			var t := float(k) / 5.0
			pts.append(Vector3(s * (0.13 + sin(t * PI * 0.8) * 0.14 - t * t * 0.18), 0.0, -1.25 - t * 0.5))
			radii.append(lerpf(0.06, 0.012, t))
		MeshKit.tube(gun, pts, radii, 8, CHITIN)
		# Serrations on the inner edge.
		for k in 3:
			var t := 0.3 + k * 0.2
			MeshKit.add_cylinder(gun, Transform3D(Basis(Vector3.FORWARD, -s * PI * 0.5), Vector3(s * (0.13 + sin(t * PI * 0.8) * 0.14 - t * t * 0.18 - 0.04), 0, -1.25 - t * 0.5)), 0.018, 0.0, 0.06, 5, CHITIN.lightened(0.15))
	MeshKit.add_ellipsoid(gun, Transform3D(Basis(Vector3.FORWARD, 0.6), Vector3(0, 0, -1.42)), Vector3(0.08, 0.08, 0.13), 5, 8, AmberRules.GLOW, 0.0, null, 1.0)
	return {"base": MeshKit.finish(base), "head": MeshKit.finish(head), "gun": MeshKit.finish(gun),
			"recoil": 0.02, "head_y": 0.62, "gun_y": 0.42, "muzzle": Vector3(0, 0, -1.5)}

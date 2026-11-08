class_name ArmoryHeavies
extends RefCounted
## The Weapon Slots heavy that stayed, built in code: the Swivel Gun (a primary
## now; the heavy slot holds the universal crop-loaded heavies, UniHeavies). The
## seven other old heavies' builders are archived in
## D:/DustAndMandibles-archive/retired/weapons/gen/armory_heavies.gd. See ArmoryGuns
## for the conventions; helpers and colours are FrontierGuns' (F) and WeaponBuilder's (W).

const F := preload("res://gen/frontier_guns.gd")
const W := preload("res://gen/weapon_builder.gd")

const NAMES: Dictionary = {
	&"swivel_gun": "Swivel Gun",
}
const PIVOTS: Dictionary = {
}
const MUZZLE: Dictionary = {
	&"swivel_gun": Vector3(0.0, 0.04, -0.875),
}
## [right fist centre, right grip axis, left support fist centre]. Every heavy has
## the same pistol grip under its origin (see _grip).
const HANDS: Dictionary = {
	&"swivel_gun": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.125, -0.34)],
}

## Lathe profiles run toward the muzzle with this basis (local +Y = gun -Z).
const LZ := Basis(Vector3.RIGHT, -PI * 0.5)

const CHILI := Color("#B3261C")
const CHILI_DARK := Color("#7E1A14")
const CHILI_STEM := Color("#4E7A2A")
const GLASS := Color("#A9CFC4")
const GLASS_DARK := Color("#3C4D4A")
const BAMBOO := Color("#C4AC62")
const BAMBOO_DARK := Color("#8E7440")
const BRONZE := Color("#A97A3E")
const BRONZE_DARK := Color("#74522A")
const ACID := Color("#86FF3C")
const ACID_LIGHT := Color("#D4FF9A")
const RUBBER := Color("#2B2420")
const LABEL := Color("#D9B23A")
const CABLE := Color("#5A5F66")
const ASH := Color("#C9A878")
const EMBER := Color("#FF6A1A")
const EMBER_CORE := Color("#FFD36A")


static func build(id: StringName) -> Dictionary:
	match id:
		&"swivel_gun":
			return _swivel()
	return {}


# ------------------------------------------------------------------ shared bits

## A dark disc just inside a muzzle.
static func _bore(k: F.Kit, c: Vector3, r: float) -> void:
	F.cz(k.x(), c, r, r, 0.0012, F.BORE, 16)


## Rivet heads round a band about the Z axis.
static func _studs(st: SurfaceTool, c: Vector3, r: float, n: int, size: float, col: Color, phase: float = 0.0) -> void:
	for i in n:
		var a := TAU * float(i) / n + phase
		F.ball(st, c + Vector3(cos(a) * r, sin(a) * r, 0.0), Vector3.ONE * size, col, 3, 6)


## The common heavy grip: a fat walnut pistol grip under the origin, its trigger and guard.
static func _grip(k: F.Kit, panel: Color, strap: Color) -> void:
	F.trigger_and_guard(k, Vector3(0, -0.018, 0.022), 0.027, strap)
	F.pistol_grip(k, Vector3(0, -0.008, 0.05), Vector3(0, -0.105, 0.092), panel, strap, 1.15)


## A coil about Z (springs, wound cord).
static func _helix(st: SurfaceTool, c: Vector3, radius: float, z0: float, z1: float, turns: float, wire: float, col: Color) -> void:
	var pts: Array = []
	var radii: Array = []
	var n := int(turns * 14.0)
	for i in n + 1:
		var t := float(i) / n
		var a := TAU * turns * t
		pts.append(c + Vector3(cos(a) * radius, sin(a) * radius, lerpf(z0, z1, t)))
		radii.append(wire)
	MeshKit.tube(st, pts, radii, 6, col)


## A rope lashing: `turns` loops of an ellipse (rx, ry) about Z at c.
static func _lash(st: SurfaceTool, c: Vector3, rx: float, ry: float, turns: int, col: Color) -> void:
	for t in turns:
		var pts: Array = []
		var radii: Array = []
		var z := c.z + (float(t) - (turns - 1) * 0.5) * 0.0055
		for i in 17:
			var a := TAU * float(i) / 16.0
			pts.append(Vector3(c.x + cos(a) * rx, c.y + sin(a) * ry, z))
			radii.append(0.0026)
		MeshKit.tube(st, pts, radii, 5, col.darkened(0.12 * (t % 2)))


## A triangle seen from both sides.
static func _tri2(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	MeshKit.tri(st, a, b, c, n, n, n, col, n)
	MeshKit.tri(st, a, b, c, -n, -n, -n, col, -n)


## Pleated bellows leather in a wedge hinged at `hinge` (about X), opening from
## 0 to `angle` below it, `length` long toward +Z: zig-zag sides and back.
static func _pleats(st: SurfaceTool, hinge: Vector3, length: float, angle: float, half_w: float, folds: int, col: Color) -> void:
	var pts: Array[Vector3] = []
	var ws: Array[float] = []
	for i in folds + 1:
		pts.append(hinge + Basis(Vector3.RIGHT, angle * float(i) / folds) * Vector3(0, 0, length * (1.0 if i % 2 == 0 else 0.93)))
		ws.append(half_w if i % 2 == 0 else half_w - 0.009)
	for i in folds:
		var c := col.darkened(0.14 * (i % 2))
		for s: float in [-1.0, 1.0]:
			_tri2(st, hinge + Vector3(s * half_w * 0.8, 0, 0), pts[i] + Vector3(s * ws[i], 0, 0), pts[i + 1] + Vector3(s * ws[i + 1], 0, 0), c)
		_tri2(st, pts[i] + Vector3(-ws[i], 0, 0), pts[i] + Vector3(ws[i], 0, 0), pts[i + 1] + Vector3(ws[i + 1], 0, 0), c)
		_tri2(st, pts[i] + Vector3(-ws[i], 0, 0), pts[i + 1] + Vector3(ws[i + 1], 0, 0), pts[i + 1] + Vector3(-ws[i + 1], 0, 0), c)


# ------------------------------------------------------------------ swivel gun

## A bronze swivel cannon: a turned barrel with reinforcing rings, a muzzle
## swell, a touch-hole in a vent field, a cascabel knob, trunnions in an iron
## Y-yoke on its spiked swivel pin, and a walnut tiller strapped to the breech.
static func _swivel() -> Dictionary:
	var k := F.Kit.new()
	var y := 0.04
	var ax := Vector3(0, y, 0)
	# --- barrel, turned toward the muzzle from the breech at z -0.035
	MeshKit.lathe(k.m(), Transform3D(LZ, ax + Vector3(0, 0, -0.07)), [Vector2(0.0, -0.035), Vector2(0.03, -0.033),
			Vector2(0.05, -0.022), Vector2(0.058, -0.006), Vector2(0.0605, 0.0), Vector2(0.0595, 0.2), Vector2(0.053, 0.35),
			Vector2(0.047, 0.6), Vector2(0.045, 0.715), Vector2(0.05, 0.755), Vector2(0.0545, 0.785), Vector2(0.0545, 0.8),
			Vector2(0.048, 0.803), Vector2(0.03, 0.804)], 22, BRONZE)
	_bore(k, ax + Vector3(0, 0, -0.8745), 0.031)
	for r: Array in [[-0.075, 0.0645, 0.016, BRONZE_DARK], [-0.125, 0.0628, 0.006, BRONZE], [-0.27, 0.0628, 0.016, BRONZE_DARK],
			[-0.292, 0.0618, 0.005, BRONZE], [-0.45, 0.0565, 0.012, BRONZE_DARK], [-0.63, 0.0518, 0.016, BRONZE_DARK],
			[-0.65, 0.0505, 0.005, BRONZE], [-0.835, 0.0585, 0.012, BRONZE_DARK]]:
		F.cz(k.m(), ax + Vector3(0, 0, float(r[0])), float(r[1]), float(r[1]), float(r[2]), r[3], 22)
	# Crest on the chase and a dispart sight at the muzzle.
	W.scroll(k.m(), ax + Vector3(0, 0.0575, -0.2), Vector3(0, 1, 0), 0.05, BRONZE.lightened(0.15))
	F.box(k.m(), ax + Vector3(0, 0.066, -0.835), Vector3(0.004, 0.012, 0.01), BRONZE_DARK)
	F.box(k.m(), ax + Vector3(0, 0.065, -0.075), Vector3(0.012, 0.006, 0.01), BRONZE_DARK)
	# Verdigris blooms over the top and left, where the sea got at it.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 11:
		var z := rng.randf_range(-0.8, -0.14)
		var a := rng.randf_range(0.5, 2.9)
		var d := -z - 0.07
		var rad := lerpf(0.0598, 0.046, clampf(d / 0.715, 0.0, 1.0)) + 0.0002
		var n := Vector3(cos(a), sin(a), 0.0)
		MeshKit.add_ellipsoid(k.x(), Transform3D(MeshKit.basis_from_y(n), ax + n * rad + Vector3(0, 0, z)),
				Vector3(rng.randf_range(0.004, 0.008), 0.0012, rng.randf_range(0.02, 0.045)), 3, 10, Color("#6F8A5E").darkened(rng.randf_range(0.1, 0.35)))
	F.box(k.m(), ax + Vector3(0, 0.0695, -0.075), Vector3(0.004, 0.004, 0.01), F.BORE)
	# Touch-hole in its vent field, a priming pan, and the snaphance cock on the right.
	F.box(k.m(), ax + Vector3(0, 0.061, -0.1), Vector3(0.022, 0.006, 0.028), BRONZE_DARK)
	MeshKit.add_cylinder(k.x(), Transform3D(Basis(), ax + Vector3(0, 0.0642, -0.1)), 0.0038, 0.0038, 0.001, 10, F.BORE)
	F.box(k.m(), ax + Vector3(0.016, 0.058, -0.1), Vector3(0.012, 0.004, 0.018), F.IRON_DARK)
	F.box(k.m(), ax + Vector3(0.024, 0.066, -0.1), Vector3(0.003, 0.018, 0.016), F.STEEL)
	W.bent(k.m(), [ax + Vector3(0.05, 0.012, -0.05), ax + Vector3(0.05, 0.04, -0.058), ax + Vector3(0.042, 0.064, -0.072),
			ax + Vector3(0.03, 0.072, -0.088)], 0.0045, F.IRON)
	F.box(k.m(), ax + Vector3(0.028, 0.074, -0.092), Vector3(0.01, 0.01, 0.014), F.IRON_DARK)
	F.box(k.x(), ax + Vector3(0.026, 0.074, -0.1), Vector3(0.008, 0.006, 0.006), Color("#5A4A3A"))
	F.box(k.m(), ax + Vector3(0.05, 0.01, -0.045), Vector3(0.008, 0.03, 0.04), F.IRON_DARK)
	W.rod(k.m(), Vector3(0.014, -0.004, 0.022), ax + Vector3(0.05, -0.01, -0.04), 0.0025, 0.0025, 6, F.IRON)
	# --- cascabel: a neck and a knob, strapped to the tiller
	F.cz(k.m(), ax + Vector3(0, 0, -0.022), 0.018, 0.022, 0.03, BRONZE_DARK, 16)
	F.ball(k.m(), ax + Vector3(0, 0, 0.012), Vector3.ONE * 0.024, BRONZE, 7, 16)
	F.cz(k.m(), ax + Vector3(0, 0, -0.008), 0.0195, 0.0195, 0.006, BRONZE.lightened(0.1), 16)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), ax + Vector3(side * 0.025, -0.002, 0.04), Vector3(0.005, 0.04, 0.1), F.IRON_DARK)
		for z: float in [0.012, 0.062]:
			F.cx(k.m(), ax + Vector3(side * 0.029, -0.002, z), 0.005, 0.004, F.STEEL, 8)
	# --- tiller
	var tiller := [[ax + Vector3(0, -0.002, 0.03), 0.021, 0.02], [ax + Vector3(0, -0.006, 0.09), 0.024, 0.021],
		[ax + Vector3(0, -0.024, 0.2), 0.034, 0.022], [ax + Vector3(0, -0.062, 0.38), 0.05, 0.024],
		[ax + Vector3(0, -0.07, 0.43), 0.054, 0.025], [ax + Vector3(0, -0.071, 0.442), 0.0545, 0.0255]]
	W.loft(k.w(), tiller, F.WALNUT, 16)
	W.buttplate(k.m(), tiller, F.IRON_DARK)
	for z: float in [0.11, 0.16]:
		F.cz(k.m(), ax + Vector3(0, -0.01 - (z - 0.11) * 0.15, z), 0.0262, 0.0262, 0.008, F.IRON_DARK, 16)
	F.box(k.w(), Vector3(0, 0.004, 0.055), Vector3(0.026, 0.03, 0.05), F.WALNUT)
	_grip(k, F.WALNUT_DARK, F.IRON)
	# --- trunnions and the Y-yoke on its swivel pin
	var tz := -0.34
	F.cx(k.m(), ax + Vector3(0, 0, tz), 0.016, 0.15, BRONZE_DARK, 14)
	for s: float in [-1.0, 1.0]:
		F.cx(k.m(), ax + Vector3(s * 0.073, 0, tz), 0.021, 0.016, F.IRON_DARK, 14)
		F.cx(k.m(), ax + Vector3(s * 0.0815, 0, tz), 0.012, 0.004, BRONZE.lightened(0.1), 12)
		F.box(k.m(), ax + Vector3(s * 0.073, 0.022, tz), Vector3(0.018, 0.008, 0.03), F.IRON)
		W.bent(k.m(), [ax + Vector3(s * 0.073, -0.01, tz), ax + Vector3(s * 0.073, -0.04, tz), ax + Vector3(s * 0.064, -0.072, tz),
				ax + Vector3(s * 0.032, -0.092, tz), ax + Vector3(0, -0.096, tz)], 0.0115, F.IRON)
	var hub := ax + Vector3(0, -0.1, tz)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), hub), 0.022, 0.024, 0.026, 16, F.IRON_DARK)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), hub + Vector3(0, -0.07, 0)), 0.013, 0.016, 0.12, 14, F.IRON)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), hub + Vector3(0, -0.022, 0)), 0.02, 0.02, 0.008, 16, F.STEEL)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), hub + Vector3(0, -0.16, 0)), 0.0, 0.013, 0.06, 14, F.IRON_DARK)
	for i in 5:
		MeshKit.add_cylinder(k.x(), Transform3D(Basis(), hub + Vector3(0, -0.04 - i * 0.015, 0)), 0.0165, 0.0165, 0.014, 14, F.LEATHER.darkened(0.08 * (i % 2)))
	return {"body": k.commit()}


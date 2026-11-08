class_name ArmoryHeavies
extends RefCounted
## The eight new heavies (Weapon Slots Redesign, section 4), built in code. See
## ArmoryGuns for the conventions; helpers and colours are FrontierGuns' (F) and
## WeaponBuilder's (W). Moving parts, each hung on its pivot:
##   mortar_tube:        "shell" (chili shell resting in the muzzle)
##   fire_lance:         "bellows" (lower board, hinged at its front edge, about X)
##   organ_gun:          "crank" (ratchet wheel and handle, turns about X)
##   harpoon_ballista:   "bolt" (the loaded bolt and its line), "crank" (windlass, turns about X)
##   acid_drencher:      "pump" (plunger and T-handle, slides along Z)
##   congreve_rocket:    "rocket" (head out of the muzzle, guide stick out the back)
##   bear_trap_launcher: "trap" (open trap and its chain), "lever" (cocking lever, swings about X)

const F := preload("res://gen/frontier_guns.gd")
const W := preload("res://gen/weapon_builder.gd")

const NAMES: Dictionary = {
	&"mortar_tube": "Mortar Tube", &"fire_lance": "Fire Lance", &"organ_gun": "Organ Gun",
	&"harpoon_ballista": "Harpoon Ballista", &"acid_drencher": "Acid Drencher", &"swivel_gun": "Swivel Gun",
	&"congreve_rocket": "Congreve Rocket", &"bear_trap_launcher": "Bear Trap Launcher",
}
const PIVOTS: Dictionary = {
	"mortar_tube_shell": Vector3(0.0, 0.085, -0.445),
	"fire_lance_bellows": Vector3(0.0, -0.004, -0.57),
	"organ_gun_crank": Vector3(0.066, 0.056, -0.035),
	"harpoon_ballista_bolt": Vector3(0.0, 0.036, -0.5),
	"harpoon_ballista_crank": Vector3(0.0, -0.004, 0.19),
	"acid_drencher_pump": Vector3(0.0, -0.075, -0.5),
	"congreve_rocket_rocket": Vector3(0.0, 0.085, -0.72),
	"bear_trap_launcher_trap": Vector3(0.0, 0.06, -0.465),
	"bear_trap_launcher_lever": Vector3(0.078, 0.035, 0.0),
}
const MUZZLE: Dictionary = {
	&"mortar_tube": Vector3(0.0, 0.085, -0.45), &"fire_lance": Vector3(0.0, 0.05, -0.72),
	&"organ_gun": Vector3(0.0, 0.056, -0.785), &"harpoon_ballista": Vector3(0.0, 0.036, -0.98),
	&"acid_drencher": Vector3(0.0, 0.03, -0.858), &"swivel_gun": Vector3(0.0, 0.04, -0.875),
	&"congreve_rocket": Vector3(0.0, 0.085, -0.95), &"bear_trap_launcher": Vector3(0.0, 0.06, -0.5),
}
## [right fist centre, right grip axis, left support fist centre]. Every heavy has
## the same pistol grip under its origin (see _grip).
const HANDS: Dictionary = {
	&"mortar_tube": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, 0.005, -0.27)],
	&"fire_lance": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.067, -0.46)],
	&"organ_gun": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.07, -0.39)],
	&"harpoon_ballista": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.048, -0.36)],
	&"acid_drencher": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(-0.03, -0.075, -0.575)],
	&"swivel_gun": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.125, -0.34)],
	&"congreve_rocket": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.03, -0.29)],
	&"bear_trap_launcher": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.05, -0.262)],
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
		&"mortar_tube":
			return _mortar()
		&"fire_lance":
			return _fire_lance()
		&"organ_gun":
			return _organ()
		&"harpoon_ballista":
			return _ballista()
		&"acid_drencher":
			return _drencher()
		&"swivel_gun":
			return _swivel()
		&"congreve_rocket":
			return _congreve()
		&"bear_trap_launcher":
			return _bear_trap()
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


# ------------------------------------------------------------------ mortar tube

## A short, fat portable brass mortar: ringed tube, a spirit level on a bracket,
## a plumb-bob elevation quadrant, a spade base plate at the breech, a carry
## handle on top, and a chili-red shell sitting in its mouth.
static func _mortar() -> Dictionary:
	var k := F.Kit.new()
	var s := F.Kit.new()
	var y := 0.085
	var ax := Vector3(0, y, 0)
	# --- tube, a touch fatter at the breech, a flared lip at the mouth
	F.cz(k.m(), ax + Vector3(0, 0, -0.1), 0.062, 0.068, 0.68, F.BRASS, 22)
	F.cz(k.m(), ax + Vector3(0, 0, -0.43), 0.074, 0.066, 0.024, F.BRASS_LIGHT, 22)
	F.cz(k.m(), ax + Vector3(0, 0, -0.444), 0.07, 0.074, 0.004, F.BRASS_DARK, 22)
	_bore(k, ax + Vector3(0, 0, -0.4465), 0.058)
	for z: float in [0.205, 0.02, -0.17, -0.36]:
		F.cz(k.m(), ax + Vector3(0, 0, z), 0.0748, 0.0748, 0.028, F.BRASS_DARK, 22)
		F.cz(k.m(), ax + Vector3(0, 0, z), 0.0762, 0.0762, 0.005, F.BRASS, 22)
		_studs(k.m(), ax + Vector3(0, 0, z + 0.009), 0.075, 12, 0.0034, F.BRASS_LIGHT)
	for z: float in [-0.075, -0.27]:
		F.cz(k.m(), ax + Vector3(0, 0, z), 0.0675, 0.0675, 0.004, F.BRASS_LIGHT, 22)
	# Engraved crest on the left flank.
	W.scroll(k.m(), ax + Vector3(-0.066, 0.0, -0.08), Vector3(-1, 0, 0), 0.06, F.BRASS_DARK)
	# Leather wrap where the left hand holds the tube.
	for i in 6:
		F.cz(k.x(), ax + Vector3(0, 0, -0.197 - i * 0.025), 0.0675, 0.0675, 0.024, F.LEATHER.darkened(0.08 * (i % 2)), 22)
	# --- breech: a domed iron end, a ball joint, the base plate and its spade
	MeshKit.lathe(k.m(), Transform3D(F.Z, ax + Vector3(0, 0, 0.24)), [Vector2(0.0685, 0.0), Vector2(0.066, 0.014),
			Vector2(0.055, 0.03), Vector2(0.033, 0.042), Vector2(0.0, 0.047)], 22, F.IRON)
	F.ball(k.m(), ax + Vector3(0, -0.01, 0.292), Vector3.ONE * 0.026, F.IRON_DARK, 6, 14)
	var plate := Vector3(0, y - 0.03, 0.318)
	F.box(k.m(), plate, Vector3(0.22, 0.18, 0.014), F.IRON_DARK)
	F.box(k.m(), plate + Vector3(0, 0, 0.009), Vector3(0.2, 0.014, 0.006), F.IRON)
	F.box(k.m(), plate + Vector3(0, 0, 0.009), Vector3(0.014, 0.16, 0.006), F.IRON)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			F.ball(k.m(), plate + Vector3(sx * 0.098, sy * 0.078, -0.008), Vector3.ONE * 0.0048, F.BRASS, 3, 6)
			W.rod(k.m(), ax + Vector3(sx * 0.048, sy * 0.048, 0.21), plate + Vector3(sx * 0.08, sy * 0.065, -0.007), 0.0055, 0.0055, 6, F.IRON)
	# The spade: a flat pointed blade under the plate.
	MeshKit.add_cylinder(k.m(), Transform3D(Basis().scaled(Vector3(1, 1, 0.16)), plate + Vector3(0, -0.135, 0.0)), 0.0, 0.085, 0.1, 4, F.IRON.darkened(0.1))
	# --- frame from the tube down to the grip
	F.box(k.m(), Vector3(0, 0.008, 0.035), Vector3(0.03, 0.05, 0.09), F.IRON_DARK)
	for side: float in [-1.0, 1.0]:
		F.screw(k.m(), Vector3(side * 0.015, 0.008, 0.01), side, F.BRASS)
		F.screw(k.m(), Vector3(side * 0.015, 0.008, 0.06), side, F.BRASS)
	_grip(k, F.WALNUT, F.BRASS_DARK)
	# --- carry handle on top
	var hy := y + 0.07
	W.bent(k.m(), [Vector3(0, hy - 0.004, 0.005), Vector3(0, hy + 0.035, -0.015), Vector3(0, hy + 0.05, -0.08),
			Vector3(0, hy + 0.035, -0.145), Vector3(0, hy - 0.004, -0.165)], 0.0058, F.IRON)
	W.rod(k.w(), Vector3(0, hy + 0.045, -0.045), Vector3(0, hy + 0.045, -0.115), 0.011, 0.011, 12, F.WALNUT_DARK)
	for z: float in [0.005, -0.165]:
		F.box(k.m(), Vector3(0, hy - 0.002, z), Vector3(0.018, 0.008, 0.018), F.IRON_DARK)
	# --- spirit level on a bracket (upper left, where the eye can find it)
	var lv := Vector3(-0.066, y + 0.054, -0.09)
	F.box(k.m(), Vector3(-0.054, y + 0.044, -0.09), Vector3(0.02, 0.012, 0.03), F.BRASS_DARK, Basis(Vector3.BACK, 0.6))
	F.box(k.m(), lv + Vector3(0, -0.009, 0), Vector3(0.026, 0.008, 0.1), F.BRASS)
	F.cz(k.x(), lv, 0.0115, 0.0115, 0.088, GLASS, 16)
	for z: float in [-0.047, 0.047]:
		F.cz(k.m(), lv + Vector3(0, 0, z), 0.0138, 0.0138, 0.009, F.BRASS_LIGHT, 16)
	for z: float in [-0.015, 0.015]:
		F.cz(k.m(), lv + Vector3(0, 0, z), 0.0119, 0.0119, 0.0016, F.IRON_DARK, 16)
	F.ball(k.g(), lv + Vector3(0, 0.0085, 0.002), Vector3(0.0075, 0.0042, 0.012), Color("#F6FFE6"), 4, 12)
	# --- elevation quadrant (left side, by the breech): ticks and a plumb bob
	var q := Vector3(-0.071, y, 0.112)
	F.cx(k.m(), q, 0.05, 0.003, F.BRASS_LIGHT, 22)
	F.cx(k.m(), q + Vector3(0.002, 0, 0), 0.053, 0.002, F.BRASS_DARK, 22)
	F.cx(k.m(), q + Vector3(-0.0015, 0, 0), 0.006, 0.003, F.IRON_DARK, 10)
	for i in 13:
		var t := lerpf(-PI * 0.5, PI * 0.5, float(i) / 12.0)
		var big := i % 3 == 0
		var rr := 0.04 if big else 0.044
		F.box(k.m(), q + Vector3(-0.0018, -cos(t) * rr, sin(t) * rr), Vector3(0.0012, 0.008 if big else 0.004, 0.0025), F.IRON_DARK, Basis(Vector3.RIGHT, t))
	W.rod(k.m(), q + Vector3(-0.003, 0, 0), q + Vector3(-0.003, -0.037, -0.011), 0.0011, 0.0011, 5, F.IRON_DARK)
	F.ball(k.m(), q + Vector3(-0.0035, -0.04, -0.012), Vector3(0.004, 0.0055, 0.004), F.BRASS_DARK, 4, 8)
	# --- the shell, nose out of the mouth
	var sc := ax + Vector3(0, 0, -0.47)
	MeshKit.add_ellipsoid(s.m(), Transform3D(Basis(), sc), Vector3(0.055, 0.055, 0.085), 8, 20, CHILI)
	F.cz(s.m(), sc + Vector3(0, 0, -0.025), 0.0552, 0.0556, 0.009, CHILI_DARK, 20)
	F.cz(s.m(), sc + Vector3(0, 0, -0.085), 0.014, 0.023, 0.02, F.BRASS, 16)
	F.cz(s.m(), sc + Vector3(0, 0, -0.096), 0.01, 0.0125, 0.006, F.BRASS_DARK, 16)
	F.cz(s.x(), sc + Vector3(0, 0, -0.103), 0.007, 0.01, 0.01, CHILI_STEM, 12)
	W.bent(s.x(), [sc + Vector3(0, 0, -0.106), sc + Vector3(0, 0.007, -0.117), sc + Vector3(0, 0.019, -0.12)], 0.003, CHILI_STEM)
	return {"body": k.commit(), "shell": s.commit()}


# ------------------------------------------------------------------ fire lance

## A shoulder-braced bamboo lance: segmented bamboo with nodes and rope
## lashings, an iron muzzle ferrule, a copper alcohol tank slung under it with a
## valve wheel and gauge, a pipe running to a pilot flame under the muzzle, and
## a pair of hinged bellows boards for the left hand.
static func _fire_lance() -> Dictionary:
	var k := F.Kit.new()
	var b := F.Kit.new()
	var y := 0.05
	# --- the bamboo
	var nodes: Array[float] = [0.44, 0.22, -0.02, -0.26, -0.49, -0.665]
	for i in nodes.size() - 1:
		var z0 := nodes[i]
		var z1 := nodes[i + 1]
		F.cz(k.w(), Vector3(0, y, (z0 + z1) * 0.5), 0.0335, 0.0348, z0 - z1, BAMBOO.darkened(0.05 * (i % 2)), 18)
		# Faint lengthwise streaks.
		for j in 3:
			var a := 1.1 + j * 2.0 + i
			F.box(k.w(), Vector3(cos(a) * 0.0344, y + sin(a) * 0.0344, (z0 + z1) * 0.5), Vector3(0.0015, 0.0015, (z0 - z1) * 0.8), BAMBOO_DARK.lightened(0.15))
	for z: float in nodes.slice(0, nodes.size() - 1):
		F.cz(k.w(), Vector3(0, y, z + 0.008), 0.0378, 0.0352, 0.016, BAMBOO.darkened(0.12), 18)
		F.cz(k.w(), Vector3(0, y, z - 0.008), 0.0352, 0.0378, 0.016, BAMBOO.darkened(0.12), 18)
		F.cz(k.w(), Vector3(0, y, z), 0.0392, 0.0392, 0.0045, BAMBOO_DARK.darkened(0.15), 18)
	F.cz(k.w(), Vector3(0, y, 0.447), 0.03, 0.03, 0.002, BAMBOO_DARK.darkened(0.2), 16)
	# Scorched bamboo and the iron ferrule at the muzzle.
	F.cz(k.x(), Vector3(0, y, -0.645), 0.0358, 0.0352, 0.04, F.SOOT.lightened(0.12), 18)
	F.cz(k.m(), Vector3(0, y, -0.69), 0.0395, 0.0385, 0.05, F.IRON_DARK, 18)
	F.cz(k.m(), Vector3(0, y, -0.713), 0.0415, 0.0415, 0.008, F.IRON, 18)
	_bore(k, Vector3(0, y, -0.7175), 0.025)
	_studs(k.m(), Vector3(0, y, -0.68), 0.0395, 8, 0.003, F.IRON.lightened(0.2))
	# --- shoulder brace: a walnut cheek lashed under the back end, leather pad
	var stock := [[Vector3(0, y - 0.022, 0.16), 0.016, 0.026], [Vector3(0, y - 0.04, 0.3), 0.034, 0.03],
		[Vector3(0, y - 0.052, 0.43), 0.05, 0.033], [Vector3(0, y - 0.053, 0.445), 0.051, 0.0335]]
	W.loft(k.w(), stock, F.WALNUT_DARK, 16)
	W.buttplate(k.x(), stock, F.LEATHER.darkened(0.1))
	for z: float in [0.2, 0.37]:
		_lash(k.x(), Vector3(0, y - 0.022, z), 0.04, 0.058, 4, F.ROPE)
	# --- grip clamp and grip
	F.cz(k.m(), Vector3(0, y, 0.045), 0.0385, 0.0385, 0.036, F.IRON, 18)
	F.box(k.m(), Vector3(0, 0.0, 0.045), Vector3(0.026, 0.04, 0.06), F.IRON_DARK)
	for side: float in [-1.0, 1.0]:
		F.screw(k.m(), Vector3(side * 0.013, 0.002, 0.03), side, F.BRASS)
	_grip(k, F.WALNUT, F.IRON)
	# --- the alcohol tank slung under the bamboo
	var tc := Vector3(0, -0.045, -0.2)
	F.cz(k.m(), tc, 0.042, 0.042, 0.2, F.COPPER, 20)
	for e: float in [-1.0, 1.0]:
		F.ball(k.m(), tc + Vector3(0, 0, e * 0.1), Vector3(0.042, 0.042, 0.024), F.COPPER.darkened(0.1), 5, 20)
	for z: float in [-0.14, -0.26]:
		F.cz(k.m(), Vector3(0, tc.y, z), 0.0448, 0.0448, 0.014, F.BRASS, 20)
		_studs(k.m(), Vector3(0, tc.y, z), 0.0448, 8, 0.0028, F.BRASS_LIGHT)
		F.box(k.m(), Vector3(0, 0.006, z), Vector3(0.012, 0.024, 0.014), F.BRASS_DARK)
		_lash(k.x(), Vector3(0, y - 0.004, z), 0.038, 0.04, 3, F.ROPE)
	# Seam rivets along the tank's belly.
	for i in 7:
		F.ball(k.m(), tc + Vector3(0, -0.042, -0.075 + i * 0.025), Vector3.ONE * 0.003, F.COPPER.lightened(0.2), 3, 6)
	# Valve and its red handwheel on the left.
	var vw := tc + Vector3(-0.066, 0.004, -0.07)
	F.cx(k.m(), tc + Vector3(-0.05, 0.004, -0.07), 0.006, 0.03, F.BRASS_DARK, 10)
	F.cx(k.m(), tc + Vector3(-0.044, 0.004, -0.07), 0.01, 0.01, F.BRASS, 12)
	F.hoop(k.m(), vw, Vector3(1, 0, 0), 0.016, 0.0028, F.SIGNAL_RED, 14)
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		W.rod(k.m(), vw, vw + Vector3(0, cos(a) * 0.016, sin(a) * 0.016), 0.0018, 0.0018, 5, F.SIGNAL_RED)
	F.cx(k.m(), vw, 0.0045, 0.008, F.BRASS_LIGHT, 10)
	# Pressure gauge on the tank's upper left.
	var gc := tc + Vector3(-0.05, 0.02, 0.05)
	F.cx(k.m(), tc + Vector3(-0.04, 0.02, 0.05), 0.0045, 0.012, F.BRASS_DARK, 8)
	F.cx(k.m(), gc, 0.016, 0.012, F.BRASS, 16)
	F.cx(k.x(), gc + Vector3(-0.0062, 0, 0), 0.0132, 0.001, F.IVORY, 16)
	F.box(k.m(), gc + Vector3(-0.0072, 0.004, -0.003), Vector3(0.001, 0.01, 0.0015), F.IRON_DARK, Basis(Vector3.RIGHT, 0.6))
	F.box(k.x(), gc + Vector3(-0.0068, -0.006, 0.006), Vector3(0.0008, 0.003, 0.005), F.SIGNAL_RED)
	# Feed from the tank up into the bamboo, and the pilot line to the muzzle.
	W.rod(k.m(), tc + Vector3(0, 0.036, -0.078), Vector3(0, y - 0.03, -0.262), 0.006, 0.006, 8, F.BRASS)
	F.cz(k.m(), Vector3(0, y - 0.03, -0.262), 0.0095, 0.0095, 0.012, F.BRASS_DARK, 10)
	var pipe := [tc + Vector3(0.012, 0.02, -0.112), Vector3(0.026, 0.0, -0.34), Vector3(0.034, 0.018, -0.39),
		Vector3(0.037, 0.026, -0.52), Vector3(0.034, 0.022, -0.64), Vector3(0.016, 0.006, -0.71), Vector3(0.012, 0.004, -0.73)]
	MeshKit.tube(k.m(), pipe, [0.0042], 8, F.COPPER.darkened(0.15))
	for z: float in [-0.49, -0.6]:
		F.box(k.m(), Vector3(0.033, 0.028, z), Vector3(0.008, 0.012, 0.008), F.IRON_DARK)
	# The pilot burner and its flame under the muzzle.
	F.cz(k.m(), Vector3(0.012, 0.004, -0.74), 0.0052, 0.0068, 0.022, F.BRASS, 12)
	F.cz(k.x(), Vector3(0.012, 0.004, -0.7515), 0.0032, 0.0032, 0.001, F.BORE, 8)
	F.ball(k.g(), Vector3(0.012, 0.016, -0.758), Vector3(0.0072, 0.016, 0.0072), Color("#FF8A2A"), 5, 10)
	MeshKit.add_cylinder(k.g(), Transform3D(Basis(), Vector3(0.012, 0.037, -0.758)), 0.005, 0.0, 0.02, 8, Color("#FF6A1A"))
	F.ball(k.g(), Vector3(0.012, 0.012, -0.758), Vector3(0.004, 0.009, 0.004), Color("#FFE07A"), 4, 8)
	F.ball(k.g(), Vector3(0.012, 0.003, -0.755), Vector3(0.0045, 0.0025, 0.0045), Color("#6FA8FF"), 3, 8)
	# --- bellows: fixed top board under the bamboo, leather pleats, hinge, nozzle
	var hinge: Vector3 = PIVOTS["fire_lance_bellows"]
	var th := 0.3
	var rot := Basis(Vector3.RIGHT, th)
	var dir := rot * Vector3(0, 0, 1)
	F.box(k.w(), hinge + Vector3(0, 0.008, 0.1), Vector3(0.076, 0.008, 0.2), F.WALNUT_LIGHT)
	for z: float in [0.04, 0.16]:
		_lash(k.x(), Vector3(0, y - 0.012, hinge.z + z), 0.04, 0.05, 3, F.ROPE)
	F.cx(k.m(), hinge, 0.004, 0.08, F.IRON_DARK, 8)
	_pleats(k.x(), hinge + Vector3(0, 0.003, 0), 0.19, th, 0.036, 6, F.LEATHER.darkened(0.35))
	W.bent(k.m(), [hinge + Vector3(0, 0.004, 0.03), hinge + rot * Vector3(0, -0.004, 0.06) + Vector3(0, 0.008, 0), hinge + Vector3(0, 0.0, 0.09)], 0.0022, F.BRASS)
	W.rod(k.m(), hinge + Vector3(0, 0.0, 0.19), Vector3(0, -0.02, -0.318), 0.0055, 0.0055, 8, F.BRASS)
	# --- lower board (the part): handle and a leather strap for the left hand
	F.box(b.w(), hinge + rot * Vector3(0, -0.006, 0.1), Vector3(0.076, 0.008, 0.2), F.WALNUT_LIGHT, rot)
	var down := rot * Vector3(0, -1, 0)
	for z: float in [0.055, 0.175]:
		W.rod(b.m(), hinge + dir * z + down * 0.01, hinge + dir * z + down * 0.03, 0.004, 0.004, 6, F.IRON)
	W.rod(b.w(), hinge + dir * 0.045 + down * 0.033, hinge + dir * 0.185 + down * 0.033, 0.0125, 0.0125, 12, F.WALNUT_DARK)
	for z: float in [0.07, 0.115, 0.16]:
		F.box(b.x(), hinge + dir * z + down * 0.033, Vector3(0.028, 0.03, 0.006), F.LEATHER.darkened(0.15), rot)
	F.ball(b.m(), hinge + rot * Vector3(0, -0.0105, 0.13), Vector3(0.012, 0.0015, 0.012), F.BRASS, 3, 8)
	return {"body": k.commit(), "bellows": b.commit()}


# ------------------------------------------------------------------ organ gun

## Twelve iron barrels, three rows of four, in iron bands on a walnut carriage
## with side cheeks; a breech block with a copper-nippled firing plate and a
## striker bar across its back, and a side crank with a ratchet wheel.
static func _organ() -> Dictionary:
	var k := F.Kit.new()
	var c := F.Kit.new()
	var cy := 0.056
	var xs: Array[float] = [-0.039, -0.013, 0.013, 0.039]
	var ys: Array[float] = [-0.026, 0.0, 0.026]
	for j in ys.size():
		for i in xs.size():
			var p := Vector3(xs[i], cy + ys[j], 0)
			F.cz(k.m(), p + Vector3(0, 0, -0.425), 0.0108, 0.0118, 0.71, F.IRON.darkened(0.06 * ((i + j) % 3)), 12)
			F.cz(k.m(), p + Vector3(0, 0, -0.779), 0.0121, 0.0121, 0.008, F.IRON.lightened(0.22), 12)
			F.cz(k.x(), p + Vector3(0, 0, -0.7836), 0.0068, 0.0068, 0.0012, F.BORE, 10)
			# Copper caps on the firing plate behind each barrel.
			F.cz(k.m(), p + Vector3(0, 0, 0.0115), 0.0038, 0.0045, 0.007, F.COPPER, 8)
	# --- bands round the block
	for b: Array in [[-0.12, F.IRON_DARK], [-0.44, F.BRASS_DARK], [-0.745, F.IRON_DARK]]:
		var z: float = b[0]
		var col: Color = b[1]
		F.box(k.m(), Vector3(0, cy + 0.043, z), Vector3(0.116, 0.007, 0.026), col)
		F.box(k.m(), Vector3(0, cy - 0.043, z), Vector3(0.116, 0.007, 0.026), col)
		for side: float in [-1.0, 1.0]:
			F.box(k.m(), Vector3(side * 0.0545, cy, z), Vector3(0.007, 0.093, 0.026), col)
			for yy: float in [-0.028, 0.0, 0.028]:
				F.ball(k.m(), Vector3(side * 0.0582, cy + yy, z), Vector3.ONE * 0.0032, F.BRASS_LIGHT, 3, 6)
	# Front sight on the last band, notch on the breech.
	F.box(k.m(), Vector3(0, cy + 0.052, -0.745), Vector3(0.004, 0.012, 0.012), F.IRON)
	# --- breech block and firing plate
	F.box(k.m(), Vector3(0, cy, -0.04), Vector3(0.112, 0.094, 0.07), F.IRON_DARK)
	F.box(k.m(), Vector3(0, cy + 0.049, -0.04), Vector3(0.1, 0.006, 0.06), F.IRON)
	F.box(k.m(), Vector3(-0.0565, cy - 0.008, -0.045), Vector3(0.002, 0.034, 0.05), F.BRASS)
	F.box(k.m(), Vector3(-0.0575, cy - 0.008, -0.045), Vector3(0.001, 0.026, 0.042), F.BRASS_DARK)
	for i in 3:
		F.box(k.m(), Vector3(-0.0582, cy - 0.016 + i * 0.008, -0.045), Vector3(0.001, 0.002, 0.03 - i * 0.006), F.BRASS_LIGHT)
	for z: float in [-0.012, -0.068]:
		for yy: float in [-0.038, 0.038]:
			F.screw(k.m(), Vector3(-0.0565, cy + yy, z), -1.0, F.STEEL)
	F.box(k.m(), Vector3(0, cy, 0.0025), Vector3(0.102, 0.086, 0.007), F.STEEL)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			F.ball(k.m(), Vector3(sx * 0.046, cy + sy * 0.038, 0.006), Vector3.ONE * 0.003, F.BRASS, 3, 6)
	F.box(k.m(), Vector3(-0.012, cy + 0.054, 0.004), Vector3(0.006, 0.01, 0.01), F.IRON)
	F.box(k.m(), Vector3(0.012, cy + 0.054, 0.004), Vector3(0.006, 0.01, 0.01), F.IRON)
	# Striker bar across the back on two arms, hanging from a pin on top.
	F.cx(k.m(), Vector3(0, cy + 0.055, -0.012), 0.005, 0.116, F.STEEL, 10)
	for side: float in [-1.0, 1.0]:
		W.rod(k.m(), Vector3(side * 0.056, cy + 0.055, -0.012), Vector3(side * 0.056, cy + 0.048, 0.022), 0.004, 0.004, 6, F.IRON)
	F.box(k.m(), Vector3(0, cy + 0.046, 0.024), Vector3(0.118, 0.012, 0.01), F.IRON, Basis(Vector3.RIGHT, -0.3))
	# Pawl and spring over the ratchet on the right.
	var piv: Vector3 = PIVOTS["organ_gun_crank"]
	F.cx(k.m(), piv + Vector3(-0.004, 0, 0), 0.016, 0.01, F.BRASS, 14)
	F.box(k.m(), piv + Vector3(0.008, 0.038, -0.012), Vector3(0.006, 0.006, 0.026), F.IRON, Basis(Vector3.RIGHT, 0.5))
	W.bent(k.m(), [piv + Vector3(0.008, 0.044, 0.004), piv + Vector3(0.008, 0.05, 0.02), piv + Vector3(0.006, 0.04, 0.03)], 0.0018, F.STEEL)
	# --- carriage: a walnut bed under the barrels, side cheeks, iron nose cap
	var bed := [[Vector3(0, cy - 0.06, -0.77), 0.016, 0.055], [Vector3(0, cy - 0.064, -0.6), 0.02, 0.062],
		[Vector3(0, cy - 0.067, -0.1), 0.024, 0.066], [Vector3(0, cy - 0.066, -0.005), 0.024, 0.066]]
	W.loft(k.w(), bed, F.WALNUT, 16)
	F.box(k.m(), Vector3(0, cy - 0.06, -0.775), Vector3(0.112, 0.036, 0.012), F.IRON_DARK)
	for side: float in [-1.0, 1.0]:
		F.box(k.w(), Vector3(side * 0.063, cy - 0.012, -0.25), Vector3(0.011, 0.07, 0.23), F.WALNUT_DARK)
		for z: float in [-0.16, -0.34]:
			F.box(k.m(), Vector3(side * 0.069, cy - 0.012, z), Vector3(0.002, 0.074, 0.012), F.IRON_DARK)
			F.screw(k.m(), Vector3(side * 0.069, cy + 0.012, z), side, F.BRASS)
			F.screw(k.m(), Vector3(side * 0.069, cy - 0.036, z), side, F.BRASS)
	# --- stock and grip
	var stock := [[Vector3(0, -0.002, 0.004), 0.025, 0.045], [Vector3(0, -0.006, 0.06), 0.024, 0.03],
		[Vector3(0, -0.014, 0.12), 0.026, 0.022], [Vector3(0, -0.03, 0.25), 0.045, 0.024],
		[Vector3(0, -0.045, 0.36), 0.056, 0.026], [Vector3(0, -0.047, 0.375), 0.057, 0.027]]
	W.loft(k.w(), stock, F.WALNUT, 16)
	W.buttplate(k.m(), stock, F.IRON_DARK)
	_grip(k, F.WALNUT_DARK, F.IRON)
	# Forward handle under the bed.
	W.rod(k.m(), Vector3(0, cy - 0.078, -0.4), Vector3(0, cy - 0.09, -0.398), 0.02, 0.02, 12, F.IRON_DARK)
	W.rod(k.w(), Vector3(0, cy - 0.088, -0.398), Vector3(0, -0.13, -0.38), 0.016, 0.019, 12, F.WALNUT)
	F.ball(k.w(), Vector3(0, -0.133, -0.38), Vector3(0.021, 0.01, 0.021), F.WALNUT_DARK, 4, 12)
	# --- crank: ratchet wheel, axle, arm and handle
	F.cx(c.m(), piv + Vector3(0.006, 0, 0), 0.029, 0.008, F.STEEL, 20)
	for i in 16:
		var a := TAU * float(i) / 16.0
		F.box(c.m(), piv + Vector3(0.006, sin(a) * 0.031, cos(a) * 0.031), Vector3(0.008, 0.006, 0.005), F.STEEL.darkened(0.1), Basis(Vector3.RIGHT, -a + 0.4))
	F.cx(c.m(), piv + Vector3(0.006, 0, 0), 0.012, 0.01, F.IRON_DARK, 12)
	F.cx(c.m(), piv + Vector3(0.018, 0, 0), 0.006, 0.02, F.IRON, 10)
	W.rod(c.m(), piv + Vector3(0.027, 0, 0), piv + Vector3(0.027, -0.065, 0.028), 0.0055, 0.0045, 8, F.IRON)
	F.box(c.m(), piv + Vector3(0.027, 0, 0), Vector3(0.008, 0.016, 0.016), F.IRON_DARK)
	F.cx(c.w(), piv + Vector3(0.046, -0.065, 0.028), 0.0095, 0.036, F.WALNUT_DARK, 12)
	F.ball(c.m(), piv + Vector3(0.066, -0.065, 0.028), Vector3(0.004, 0.0085, 0.0085), F.BRASS, 3, 8)
	return {"body": k.commit(), "crank": c.commit()}


# ------------------------------------------------------------------ harpoon ballista

## A heavy crossbow: laminated steel prod in an iron bow block, a thick cable
## string drawn back to a brass nut, a foot stirrup, a walnut tiller, a windlass
## at the butt, and an arm-and-a-half iron bolt with a barbed head and a line.
static func _ballista() -> Dictionary:
	var k := F.Kit.new()
	var bo := F.Kit.new()
	var cr := F.Kit.new()
	var by := 0.036
	# --- tiller
	var tiller := [[Vector3(0, 0.0, -0.66), 0.024, 0.03], [Vector3(0, 0.0, -0.4), 0.027, 0.03],
		[Vector3(0, -0.004, -0.12), 0.03, 0.031], [Vector3(0, -0.01, 0.06), 0.032, 0.029],
		[Vector3(0, -0.03, 0.24), 0.046, 0.025], [Vector3(0, -0.045, 0.36), 0.056, 0.027],
		[Vector3(0, -0.047, 0.375), 0.057, 0.0275]]
	W.loft(k.w(), tiller, F.WALNUT, 16)
	W.buttplate(k.m(), tiller, F.IRON_DARK)
	# The bolt groove and its iron rails along the top.
	F.box(k.x(), Vector3(0, 0.0262, -0.38), Vector3(0.012, 0.002, 0.52), F.BORE)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.0115, 0.0275, -0.38), Vector3(0.006, 0.006, 0.52), F.STEEL.darkened(0.1))
		for z: float in [-0.2, -0.38, -0.56]:
			F.screw(k.m(), Vector3(side * 0.0115, 0.0306, z), side, F.BRASS)
	# The nut the string sits on, and its cheek plates.
	F.cx(k.m(), Vector3(0, 0.03, -0.1), 0.014, 0.03, F.BRASS, 14)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.031, 0.012, -0.1), Vector3(0.003, 0.036, 0.046), F.IRON_DARK)
		F.screw(k.m(), Vector3(side * 0.0325, 0.03, -0.1), side, F.BRASS)
		F.screw(k.m(), Vector3(side * 0.0325, 0.0, -0.112), side, F.BRASS)
	# --- bow block and the laminated steel prod
	F.box(k.m(), Vector3(0, 0.0, -0.6), Vector3(0.09, 0.066, 0.07), F.IRON_DARK)
	F.box(k.m(), Vector3(0, 0.034, -0.6), Vector3(0.06, 0.006, 0.05), F.IRON)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			F.ball(k.m(), Vector3(sx * 0.03, sy * 0.034, -0.6), Vector3.ONE * 0.0045, F.BRASS, 3, 6)
	for s: float in [-1.0, 1.0]:
		var limb: Array = []
		var leaf: Array = []
		for i in 9:
			var t := float(i) / 8.0
			var x := lerpf(0.04, 0.4, t)
			var z := -0.6 + 0.085 * t * t
			limb.append([Vector3(s * x, 0.0, z), lerpf(0.026, 0.012, t), lerpf(0.0105, 0.0065, t)])
			if t <= 0.7:
				leaf.append([Vector3(s * x * 0.98, 0.0, z + 0.0115), lerpf(0.022, 0.014, t / 0.7), 0.0045])
		W.loft(k.m(), limb, F.STEEL, 10)
		W.loft(k.m(), leaf, F.STEEL.darkened(0.2), 10)
		for x: float in [0.1, 0.2]:
			F.box(k.m(), Vector3(s * x, 0.0, -0.6 + 0.085 * pow(x / 0.4, 2) + 0.004), Vector3(0.008, 0.03, 0.026), F.IRON_DARK)
		# Nocks at the tips.
		var tip := Vector3(s * 0.4, 0.0, -0.515)
		F.box(k.m(), tip + Vector3(s * 0.006, 0, 0.0), Vector3(0.012, 0.018, 0.014), F.BRASS)
		# --- the cable string, served near the tips and at the nut
		var nut := Vector3(s * 0.012, 0.033, -0.112)
		W.rod(k.m(), tip, nut, 0.0045, 0.0045, 8, CABLE)
		W.rod(k.x(), tip.lerp(nut, 0.03), tip.lerp(nut, 0.12), 0.0058, 0.0058, 8, F.ROPE.darkened(0.15))
		W.rod(k.x(), tip.lerp(nut, 0.9), nut, 0.0058, 0.0058, 8, F.ROPE.darkened(0.15))
	# Foot stirrup in front of the bow block.
	W.bent(k.m(), [Vector3(-0.034, 0.0, -0.634), Vector3(-0.055, 0.0, -0.67), Vector3(-0.05, 0.0, -0.71),
			Vector3(-0.02, 0.0, -0.73), Vector3(0.02, 0.0, -0.73), Vector3(0.05, 0.0, -0.71), Vector3(0.055, 0.0, -0.67),
			Vector3(0.034, 0.0, -0.634)], 0.006, F.IRON)
	# --- windlass housing at the butt; cords forward to claws on the string
	var wp: Vector3 = PIVOTS["harpoon_ballista_crank"]
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(side * 0.03, wp.y, wp.z), Vector3(0.006, 0.05, 0.05), F.IRON_DARK)
		F.screw(k.m(), Vector3(side * 0.033, wp.y + 0.016, wp.z - 0.016), side, F.BRASS)
		F.screw(k.m(), Vector3(side * 0.033, wp.y - 0.016, wp.z + 0.016), side, F.BRASS)
		var claw := Vector3(side * 0.038, 0.036, -0.09)
		W.rod(k.x(), wp + Vector3(side * 0.048, 0.02, 0.0), claw + Vector3(0, 0, 0.012), 0.0024, 0.0024, 5, F.ROPE)
		W.bent(k.m(), [claw + Vector3(0, 0, 0.014), claw, claw + Vector3(-side * 0.012, 0.004, -0.012), claw + Vector3(-side * 0.02, -0.004, -0.014)], 0.003, F.IRON)
	# Line basket on the right of the tiller.
	var lb := Vector3(0.05, -0.03, -0.3)
	F.cx(k.x(), lb, 0.03, 0.03, F.LEATHER.darkened(0.1), 16)
	F.cx(k.m(), lb + Vector3(0.016, 0, 0), 0.031, 0.003, F.BRASS_DARK, 16)
	for i in 4:
		F.hoop(k.x(), lb + Vector3(0.018 + i * 0.0001, 0, 0), Vector3(1, 0, 0), 0.008 + i * 0.006, 0.0024, F.ROPE.darkened(0.05 * i), 14)
	F.box(k.m(), Vector3(0.034, -0.012, -0.3), Vector3(0.008, 0.02, 0.03), F.IRON_DARK)
	_grip(k, F.WALNUT_DARK, F.IRON)
	# --- the bolt: an iron shaft, a socketed barbed head, iron vanes, an eye and its line
	W.rod(bo.m(), Vector3(0, by, -0.085), Vector3(0, by, -0.88), 0.0075, 0.0075, 10, F.IRON)
	F.cz(bo.m(), Vector3(0, by, -0.888), 0.0105, 0.0085, 0.024, F.IRON_DARK, 12)
	F.cz(bo.m(), Vector3(0, by, -0.935), 0.0, 0.018, 0.07, F.STEEL.lightened(0.15), 4)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var out := Vector3(cos(a), sin(a), 0.0)
		W.rod(bo.m(), Vector3(0, by, -0.92) + out * 0.008, Vector3(0, by, -0.876) + out * 0.03, 0.0048, 0.0008, 6, F.STEEL)
	for a: float in [PI * 0.5, 0.15, PI - 0.15]:
		F.box(bo.m(), Vector3(cos(a) * 0.016, by + sin(a) * 0.016, -0.15), Vector3(0.018, 0.0018, 0.07), F.IRON.lightened(0.1), Basis(Vector3.BACK, a))
	for z: float in [-0.25, -0.5, -0.75]:
		F.cz(bo.m(), Vector3(0, by, z), 0.0085, 0.0085, 0.006, F.BRASS_DARK, 10)
	F.hoop(bo.m(), Vector3(0, by, -0.072), Vector3(1, 0, 0), 0.008, 0.0022, F.IRON, 10)
	MeshKit.tube(bo.x(), [Vector3(0, by, -0.065), Vector3(0.03, by - 0.01, -0.09), Vector3(0.05, 0.0, -0.18),
			Vector3(0.054, -0.012, -0.27), Vector3(0.068, -0.03, -0.3)], [0.0022], 5, F.ROPE)
	# --- windlass: axle, two rope spools, two cranks
	F.cx(cr.m(), wp, 0.008, 0.16, F.IRON, 10)
	for side: float in [-1.0, 1.0]:
		F.cx(cr.x(), wp + Vector3(side * 0.048, 0, 0), 0.019, 0.02, F.ROPE, 16)
		for e: float in [-1.0, 1.0]:
			F.cx(cr.m(), wp + Vector3(side * 0.048 + e * 0.011, 0, 0), 0.025, 0.003, F.IRON_DARK, 16)
		var arm_dir := Vector3(0, -0.07, 0.018) if side > 0.0 else Vector3(0, -0.06, -0.035)
		var a0 := wp + Vector3(side * 0.08, 0, 0)
		W.rod(cr.m(), a0, a0 + arm_dir, 0.0055, 0.0045, 8, F.IRON)
		F.box(cr.m(), a0, Vector3(0.008, 0.018, 0.018), F.IRON_DARK)
		F.cx(cr.w(), a0 + arm_dir + Vector3(side * 0.02, 0, 0), 0.0095, 0.036, F.WALNUT_DARK, 12)
	return {"body": k.commit(), "bolt": bo.commit(), "crank": cr.commit()}


# ------------------------------------------------------------------ acid drencher

## A garden sprayer gone to war: a copper tank slung under a long brass wand,
## a glowing green sight glass, a skull-and-bones warning label, a pressure
## gauge, a rubber hose up to the valve, a red valve wheel, a flared nozzle
## crusted with acid, and a pump with a T-handle on the tank's nose.
static func _drencher() -> Dictionary:
	var k := F.Kit.new()
	var p := F.Kit.new()
	var wy := 0.03
	# --- the wand
	F.cz(k.m(), Vector3(0, wy, -0.4), 0.0105, 0.0105, 0.78, F.BRASS, 14)
	for z: float in [-0.2, -0.5, -0.71]:
		F.cz(k.m(), Vector3(0, wy, z), 0.0135, 0.0135, 0.012, F.BRASS_DARK, 14)
		F.cz(k.m(), Vector3(0, wy, z), 0.0142, 0.0142, 0.003, F.BRASS_LIGHT, 14)
	MeshKit.lathe(k.m(), Transform3D(LZ, Vector3(0, wy, -0.79)), [Vector2(0.0115, 0.0), Vector2(0.013, 0.01),
			Vector2(0.016, 0.03), Vector2(0.022, 0.056), Vector2(0.024, 0.063), Vector2(0.02, 0.066)], 16, F.BRASS_LIGHT)
	F.cz(k.x(), Vector3(0, wy, -0.8555), 0.019, 0.019, 0.0012, Color("#14200E"), 14)
	F.box(k.m(), Vector3(0, wy, -0.857), Vector3(0.03, 0.0035, 0.002), F.BRASS_DARK)
	# Acid crust and a drip at the nozzle.
	for i in 5:
		var a := 3.6 + i * 0.5
		F.ball(k.g(), Vector3(cos(a) * 0.022, wy + sin(a) * 0.022, -0.852), Vector3(0.004, 0.003, 0.004), ACID.darkened(0.25), 3, 6)
	F.ball(k.g(), Vector3(0.004, wy - 0.027, -0.85), Vector3(0.0035, 0.006, 0.0035), ACID, 3, 8)
	F.ball(k.g(), Vector3(0.004, wy - 0.036, -0.85), Vector3(0.0025, 0.003, 0.0025), ACID_LIGHT, 3, 6)
	# --- valve block, thumb lever, red valve wheel, frame to the grip
	F.box(k.m(), Vector3(0, wy, -0.025), Vector3(0.032, 0.036, 0.05), F.BRASS_DARK)
	F.cz(k.m(), Vector3(0, wy, -0.054), 0.0135, 0.0135, 0.01, F.BRASS, 14)
	F.box(k.m(), Vector3(0, 0.002, 0.03), Vector3(0.026, 0.03, 0.07), F.BRASS_DARK)
	for side: float in [-1.0, 1.0]:
		F.screw(k.m(), Vector3(side * 0.016, wy, -0.01), side, F.BRASS_LIGHT)
		F.screw(k.m(), Vector3(side * 0.013, 0.002, 0.05), side, F.BRASS_LIGHT)
	W.bent(k.m(), [Vector3(0, wy + 0.018, -0.03), Vector3(0, wy + 0.03, -0.01), Vector3(0, wy + 0.036, 0.016)], 0.003, F.STEEL)
	F.box(k.m(), Vector3(0, wy + 0.037, 0.02), Vector3(0.014, 0.004, 0.01), F.STEEL.darkened(0.2))
	var vw := Vector3(-0.026, wy, -0.03)
	F.cx(k.m(), vw + Vector3(0.006, 0, 0), 0.004, 0.012, F.STEEL, 8)
	F.hoop(k.m(), vw, Vector3(1, 0, 0), 0.014, 0.0026, F.SIGNAL_RED, 14)
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.3
		W.rod(k.m(), vw, vw + Vector3(0, cos(a) * 0.014, sin(a) * 0.014), 0.0017, 0.0017, 5, F.SIGNAL_RED)
	_grip(k, F.WALNUT, F.BRASS_DARK)
	# --- the tank
	var tc := Vector3(0, -0.075, -0.24)
	F.cz(k.m(), tc, 0.06, 0.06, 0.26, F.COPPER, 22)
	for e: float in [-1.0, 1.0]:
		F.ball(k.m(), tc + Vector3(0, 0, e * 0.13), Vector3(0.06, 0.06, 0.03), F.COPPER.darkened(0.08), 6, 22)
	for z: float in [-0.15, -0.335]:
		F.cz(k.m(), Vector3(0, tc.y, z), 0.0628, 0.0628, 0.014, F.BRASS, 22)
		_studs(k.m(), Vector3(0, tc.y, z), 0.0628, 12, 0.003, F.BRASS_LIGHT)
		# Straps up to the wand.
		F.box(k.m(), Vector3(0, -0.002, z), Vector3(0.012, 0.03, 0.012), F.BRASS_DARK)
		F.cz(k.m(), Vector3(0, wy, z), 0.0138, 0.0138, 0.014, F.BRASS_DARK, 14)
	for i in 9:
		F.ball(k.m(), tc + Vector3(0, -0.06, -0.12 + i * 0.03), Vector3.ONE * 0.0032, F.COPPER.lightened(0.2), 3, 6)
	# Filler cap on top, right of the wand.
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(Vector3.BACK, -0.4), tc + Vector3(0.027, 0.054, 0.04)), 0.015, 0.014, 0.014, 14, F.BRASS)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(Vector3.BACK, -0.4), tc + Vector3(0.03, 0.061, 0.04)), 0.008, 0.008, 0.008, 6, F.BRASS_DARK)
	# Sight glass on the left: acid glowing in the lower part.
	var sg := Vector3(-0.068, tc.y, -0.24)
	for dz: float in [-0.011, 0.011]:
		F.box(k.m(), sg + Vector3(0, 0, dz), Vector3(0.006, 0.09, 0.005), F.BRASS)
	for dy: float in [-0.047, 0.047]:
		F.box(k.m(), sg + Vector3(0.004, dy, 0), Vector3(0.014, 0.008, 0.03), F.BRASS_DARK)
	MeshKit.add_cylinder(k.g(), Transform3D(Basis(), sg + Vector3(0, -0.019, 0)), 0.0075, 0.0075, 0.05, 12, ACID)
	MeshKit.add_cylinder(k.x(), Transform3D(Basis(), sg + Vector3(0, 0.025, 0)), 0.0075, 0.0075, 0.038, 12, GLASS_DARK)
	MeshKit.add_cylinder(k.g(), Transform3D(Basis(), sg + Vector3(0, 0.0065, 0)), 0.0078, 0.0078, 0.003, 12, ACID_LIGHT)
	F.ball(k.g(), sg + Vector3(-0.006, -0.03, 0.002), Vector3.ONE * 0.0018, ACID_LIGHT, 3, 6)
	F.ball(k.g(), sg + Vector3(-0.006, -0.012, -0.002), Vector3.ONE * 0.0014, ACID_LIGHT, 3, 6)
	# Warning label on the upper left of the tank: hazard edges, skull and bones.
	var la := 2.62
	var lb := Basis(Vector3.BACK, la)
	var lc := Vector3(tc.x, tc.y, -0.29) + Vector3(cos(la), sin(la), 0) * 0.0606
	F.box(k.x(), lc, Vector3(0.002, 0.046, 0.062), LABEL, lb)
	for e: float in [-1.0, 1.0]:
		for i in 5:
			F.box(k.x(), lc + lb * Vector3(0.0012, e * 0.019, -0.024 + i * 0.012), Vector3(0.001, 0.006, 0.005), F.SOOT, lb * Basis(Vector3.RIGHT, 0.7))
	MeshKit.add_ellipsoid(k.x(), Transform3D(lb, lc + lb * Vector3(0.0014, 0.002, 0.0)), Vector3(0.001, 0.0085, 0.0075), 3, 10, F.IVORY)
	for e: float in [-1.0, 1.0]:
		F.box(k.x(), lc + lb * Vector3(0.0016, 0.0, 0.0), Vector3(0.001, 0.0028, 0.03), F.IVORY, lb * Basis(Vector3.RIGHT, e * 0.6))
		F.ball(k.x(), lc + lb * Vector3(0.0024, 0.003, e * 0.003), Vector3(0.001, 0.0018, 0.0018), F.SOOT, 3, 6)
	F.box(k.x(), lc + lb * Vector3(0.0024, -0.003, 0.0), Vector3(0.001, 0.0016, 0.006), F.SOOT)
	# Pressure gauge at the back of the tank, tilted up toward the eye.
	var gd := MeshKit.basis_from_y(Vector3(-0.35, 0.6, 0.72))
	var gc := tc + Vector3(-0.03, 0.05, 0.142)
	W.rod(k.m(), tc + Vector3(-0.018, 0.035, 0.12), gc, 0.0045, 0.0045, 8, F.BRASS_DARK)
	MeshKit.add_cylinder(k.m(), Transform3D(gd, gc), 0.019, 0.019, 0.012, 18, F.BRASS)
	MeshKit.add_cylinder(k.x(), Transform3D(gd, gc + gd.y * 0.0062), 0.0158, 0.0158, 0.001, 18, F.IVORY)
	F.box(k.m(), gc + gd.y * 0.0072 + gd.x * 0.004, Vector3(0.012, 0.0012, 0.0015), F.IRON_DARK, gd)
	F.box(k.x(), gc + gd.y * 0.0068 - gd.x * 0.008 + gd.z * 0.006, Vector3(0.006, 0.0008, 0.003), F.SIGNAL_RED, gd)
	# Rubber hose from the tank's back up to the valve block, brass ferrules.
	var hose := [tc + Vector3(-0.02, -0.02, 0.152), tc + Vector3(-0.03, -0.024, 0.18), Vector3(-0.05, -0.08, -0.04),
		Vector3(-0.058, -0.04, -0.02), Vector3(-0.05, -0.004, -0.028), Vector3(-0.034, 0.016, -0.03), Vector3(-0.018, 0.022, -0.03)]
	MeshKit.tube(k.x(), hose, [0.0072], 10, RUBBER)
	F.cz(k.m(), tc + Vector3(-0.02, -0.02, 0.15), 0.0095, 0.0095, 0.014, F.BRASS, 12)
	F.cx(k.m(), Vector3(-0.019, 0.022, -0.03), 0.0095, 0.008, F.BRASS, 12)
	# --- pump barrel on the tank's nose
	F.cz(k.m(), tc + Vector3(0, 0, -0.2), 0.02, 0.022, 0.08, F.BRASS, 16)
	F.cz(k.m(), tc + Vector3(0, 0, -0.243), 0.0235, 0.0235, 0.012, F.BRASS_DARK, 16)
	# --- the pump: plunger rod and walnut T-handle (slides along Z)
	var pp: Vector3 = PIVOTS["acid_drencher_pump"]
	F.cz(p.m(), pp + Vector3(0, 0, -0.03), 0.0068, 0.0068, 0.09, F.STEEL, 10)
	F.cz(p.m(), pp + Vector3(0, 0, -0.072), 0.012, 0.01, 0.01, F.BRASS_DARK, 12)
	F.cx(p.w(), pp + Vector3(0, 0, -0.077), 0.0135, 0.12, F.WALNUT, 14)
	for e: float in [-1.0, 1.0]:
		F.cx(p.m(), pp + Vector3(e * 0.061, 0, -0.077), 0.0145, 0.005, F.BRASS, 14)
	return {"body": k.commit(), "pump": p.commit()}


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


# ------------------------------------------------------------------ congreve rocket

## An iron launch tube in brass bands with a flared back end, a padded shoulder
## cradle, leaf and blade sights, a serpentine holding a smouldering slow match
## over the fuse port, and a painted rocket nosing out with its guide stick
## trailing out the back.
static func _congreve() -> Dictionary:
	var k := F.Kit.new()
	var r := F.Kit.new()
	var y := 0.085
	var ax := Vector3(0, y, 0)
	# --- tube
	F.cz(k.m(), ax + Vector3(0, 0, -0.21), 0.046, 0.048, 1.02, F.IRON, 20)
	MeshKit.lathe(k.m(), Transform3D(F.Z, ax + Vector3(0, 0, 0.3)), [Vector2(0.048, 0.0), Vector2(0.052, 0.02),
			Vector2(0.06, 0.042), Vector2(0.063, 0.05), Vector2(0.058, 0.052)], 20, F.IRON_DARK)
	F.cz(k.x(), ax + Vector3(0, 0, 0.32), 0.056, 0.05, 0.04, F.SOOT, 20)
	_bore(k, ax + Vector3(0, 0, 0.3), 0.046)
	var bands: Array[float] = [0.27, 0.12, -0.08, -0.3, -0.52, -0.69]
	for i in bands.size():
		F.cz(k.m(), ax + Vector3(0, 0, bands[i]), 0.0515, 0.0515, 0.022, F.BRASS if i % 2 == 0 else F.BRASS_DARK, 20)
		_studs(k.m(), ax + Vector3(0, 0, bands[i]), 0.0518, 8, 0.003, F.BRASS_LIGHT, 0.2)
	# Rolled seam along the top-right, and the muzzle ring.
	F.box(k.m(), ax + Vector3(0.024, 0.041, -0.21), Vector3(0.006, 0.004, 0.98), F.IRON_DARK, Basis(Vector3.BACK, -0.52))
	F.cz(k.m(), ax + Vector3(0, 0, -0.714), 0.052, 0.05, 0.012, F.IRON.lightened(0.2), 20)
	_bore(k, ax + Vector3(0, 0, -0.7205), 0.04)
	# Sights: rear leaf with a notch, front blade and bead.
	F.box(k.m(), ax + Vector3(0, 0.054, 0.16), Vector3(0.022, 0.008, 0.03), F.IRON_DARK)
	F.box(k.m(), ax + Vector3(0, 0.068, 0.165), Vector3(0.006, 0.026, 0.008), F.IRON_DARK)
	for side: float in [-1.0, 1.0]:
		F.box(k.m(), ax + Vector3(side * 0.01, 0.084, 0.165), Vector3(0.012, 0.014, 0.004), F.IRON)
	F.box(k.m(), ax + Vector3(0, 0.054, -0.69), Vector3(0.014, 0.008, 0.02), F.IRON_DARK)
	F.box(k.m(), ax + Vector3(0, 0.07, -0.69), Vector3(0.004, 0.03, 0.012), F.IRON_DARK)
	F.ball(k.m(), ax + Vector3(0, 0.086, -0.69), Vector3.ONE * 0.0038, F.BRASS_LIGHT, 3, 8)
	# --- shoulder cradle: walnut under the back end, leather pad, iron straps
	var cradle := [[ax + Vector3(0, -0.055, 0.06), 0.01, 0.03], [ax + Vector3(0, -0.066, 0.13), 0.018, 0.05],
		[ax + Vector3(0, -0.066, 0.24), 0.018, 0.05], [ax + Vector3(0, -0.058, 0.3), 0.012, 0.04]]
	W.loft(k.w(), cradle, F.WALNUT_DARK, 16)
	var pad: Array = []
	for st: Array in cradle:
		pad.append([(st[0] as Vector3) + Vector3(0, -0.012, 0), float(st[1]) * 0.6, float(st[2]) * 0.92])
	W.loft(k.x(), pad, F.LEATHER, 16)
	for z: float in [0.12, 0.27]:
		W.rod(k.m(), ax + Vector3(0, -0.044, z), ax + Vector3(0, -0.06, z), 0.008, 0.008, 8, F.IRON_DARK)
	# --- grip clamp and grip
	F.box(k.m(), Vector3(0, 0.012, 0.03), Vector3(0.024, 0.056, 0.05), F.IRON_DARK)
	F.cz(k.m(), ax + Vector3(0, 0, 0.03), 0.051, 0.051, 0.03, F.IRON_DARK, 20)
	_grip(k, F.WALNUT, F.IRON)
	# Forward handle on the band at -0.3.
	W.rod(k.w(), ax + Vector3(0, -0.05, -0.3), Vector3(0, -0.085, -0.285), 0.016, 0.018, 12, F.WALNUT)
	F.ball(k.w(), Vector3(0, -0.088, -0.285), Vector3(0.02, 0.01, 0.02), F.WALNUT_DARK, 4, 12)
	F.box(k.m(), ax + Vector3(0, -0.054, -0.3), Vector3(0.02, 0.014, 0.024), F.BRASS_DARK)
	# --- fuse port and the serpentine with its slow match (left side)
	var port := ax + Vector3(-0.028, 0.04, 0.215)
	F.ball(k.m(), port, Vector3(0.008, 0.006, 0.01), F.BRASS, 4, 10)
	F.ball(k.x(), port + Vector3(-0.002, 0.005, 0), Vector3(0.004, 0.0015, 0.004), F.BORE, 3, 8)
	F.box(k.m(), ax + Vector3(-0.05, -0.004, 0.2), Vector3(0.008, 0.022, 0.03), F.IRON_DARK)
	F.cx(k.m(), ax + Vector3(-0.055, -0.004, 0.2), 0.005, 0.006, F.STEEL, 8)
	W.bent(k.m(), [ax + Vector3(-0.057, -0.004, 0.2), ax + Vector3(-0.064, 0.024, 0.218), ax + Vector3(-0.058, 0.052, 0.232),
			ax + Vector3(-0.044, 0.068, 0.228)], 0.0055, F.IRON)
	var jaw := ax + Vector3(-0.042, 0.07, 0.224)
	F.box(k.m(), jaw, Vector3(0.016, 0.016, 0.02), F.BRASS)
	F.box(k.m(), jaw + Vector3(0, 0.0, -0.012), Vector3(0.014, 0.004, 0.008), F.BRASS_DARK)
	F.screw(k.m(), jaw + Vector3(-0.006, 0.002, 0), -1.0, F.STEEL)
	# The match: from the jaw down toward the port, its tip a glowing ember.
	W.rod(k.x(), jaw + Vector3(0.002, 0.0, 0.012), port + Vector3(-0.002, 0.016, -0.012), 0.0034, 0.0034, 6, F.ROPE.darkened(0.25))
	F.ball(k.g(), port + Vector3(-0.002, 0.014, -0.014), Vector3.ONE * 0.0068, EMBER, 4, 8)
	F.ball(k.g(), port + Vector3(-0.003, 0.0135, -0.017), Vector3.ONE * 0.0038, EMBER_CORE, 3, 6)
	F.ball(k.x(), port + Vector3(-0.002, 0.016, -0.008), Vector3(0.0038, 0.0038, 0.004), F.SOOT, 3, 6)
	# The rest of the slow match: a coil round the tube and its tail up into the jaw.
	_helix(k.x(), ax, 0.0505, 0.148, 0.192, 3.0, 0.0028, F.ROPE.darkened(0.2))
	W.bent(k.x(), [ax + Vector3(-0.05, 0.0, 0.19), ax + Vector3(-0.054, 0.03, 0.205), ax + Vector3(-0.046, 0.068, 0.216)], 0.0028, F.ROPE.darkened(0.2))
	# --- the rocket: painted case, iron cone, brass tip, guide stick out the back
	F.cz(r.m(), ax + Vector3(0, 0, -0.79), 0.038, 0.038, 0.14, F.SIGNAL_RED, 18)
	for z: float in [-0.748, -0.828]:
		F.cz(r.m(), ax + Vector3(0, 0, z), 0.0386, 0.0386, 0.014, F.IVORY, 18)
	_studs(r.m(), ax + Vector3(0, 0, -0.857), 0.038, 10, 0.0025, F.IRON_DARK)
	F.cz(r.m(), ax + Vector3(0, 0, -0.905), 0.006, 0.039, 0.09, F.IRON_DARK, 18)
	F.ball(r.m(), ax + Vector3(0, 0, -0.951), Vector3.ONE * 0.0075, F.BRASS_LIGHT, 4, 10)
	W.rod(r.w(), ax + Vector3(0, 0, -0.72), ax + Vector3(0, 0, 0.48), 0.009, 0.009, 8, ASH)
	F.cz(r.m(), ax + Vector3(0, 0, 0.476), 0.0105, 0.0105, 0.012, F.IRON, 10)
	for z: float in [0.36, 0.42]:
		F.cz(r.x(), ax + Vector3(0, 0, z), 0.0098, 0.0098, 0.006, F.ROPE.darkened(0.2), 10)
	return {"body": k.commit(), "rocket": r.commit()}


# ------------------------------------------------------------------ bear trap launcher

## An iron cage with a great coil spring down its middle, a pusher plate and
## sabot, a cocking lever along the right rail, a walnut stock, and an open bear
## trap seated on the front: toothed jaws laid flat round the pan, leaf springs
## each side and a chain back to the frame.
static func _bear_trap() -> Dictionary:
	var k := F.Kit.new()
	var t := F.Kit.new()
	var lv := F.Kit.new()
	var cy := 0.06
	var ax := Vector3(0, cy, 0)
	# --- frame: side rails, top rail, belly rod, guide rings, back plate
	for s: float in [-1.0, 1.0]:
		F.box(k.m(), ax + Vector3(s * 0.065, 0, -0.215), Vector3(0.008, 0.034, 0.47), F.IRON_DARK)
		for z: float in [-0.05, -0.18, -0.31, -0.42]:
			F.ball(k.m(), ax + Vector3(s * 0.0695, 0.01, z), Vector3.ONE * 0.0035, F.BRASS, 3, 6)
			F.ball(k.m(), ax + Vector3(s * 0.0695, -0.01, z), Vector3.ONE * 0.0035, F.BRASS, 3, 6)
	F.box(k.m(), ax + Vector3(0, 0.055, -0.215), Vector3(0.018, 0.009, 0.47), F.IRON)
	F.box(k.m(), ax + Vector3(0, 0.061, -0.215), Vector3(0.006, 0.003, 0.44), F.IRON_DARK)
	W.rod(k.m(), ax + Vector3(0, -0.055, 0.0), ax + Vector3(0, -0.055, -0.45), 0.006, 0.006, 8, F.IRON)
	for z: float in [-0.12, -0.27]:
		F.hoop(k.m(), ax + Vector3(0, 0, z), Vector3(0, 0, 1), 0.058, 0.0045, F.IRON_DARK, 20)
	F.hoop(k.m(), ax + Vector3(0, 0, -0.445), Vector3(0, 0, 1), 0.062, 0.0065, F.IRON, 20)
	# Back frame: an open square (the eye sights through it down the spring), a cross bar and hub.
	for e: float in [-1.0, 1.0]:
		F.box(k.m(), ax + Vector3(0, e * 0.055, 0.018), Vector3(0.142, 0.012, 0.012), F.IRON_DARK)
		F.box(k.m(), ax + Vector3(e * 0.065, 0, 0.018), Vector3(0.012, 0.122, 0.012), F.IRON_DARK)
	F.box(k.m(), ax + Vector3(0, -0.03, 0.018), Vector3(0.12, 0.01, 0.01), F.IRON)
	F.cz(k.m(), ax + Vector3(0, 0, 0.016), 0.016, 0.016, 0.012, F.IRON, 14)
	F.box(k.m(), ax + Vector3(0, -0.015, 0.018), Vector3(0.01, 0.03, 0.01), F.IRON)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			F.ball(k.m(), ax + Vector3(sx * 0.065, sy * 0.055, 0.025), Vector3.ONE * 0.0042, F.BRASS, 3, 6)
	# Front sight on the top rail.
	F.box(k.m(), ax + Vector3(0, 0.068, -0.43), Vector3(0.004, 0.014, 0.01), F.IRON)
	# --- the spring, its guide rod, the pusher plate and sabot
	_helix(k.m(), ax, 0.042, 0.005, -0.355, 8.0, 0.0072, F.STEEL)
	F.cz(k.m(), ax + Vector3(0, 0, -0.2), 0.008, 0.008, 0.42, F.STEEL.darkened(0.2), 10)
	F.cz(k.m(), ax + Vector3(0, 0, -0.362), 0.05, 0.05, 0.012, F.IRON, 20)
	F.cz(k.m(), ax + Vector3(0, 0, -0.372), 0.02, 0.026, 0.008, F.IRON_DARK, 14)
	F.cz(k.m(), ax + Vector3(0, 0, -0.415), 0.013, 0.013, 0.08, F.IRON_DARK, 12)
	for s: float in [-1.0, 1.0]:
		F.box(k.m(), ax + Vector3(s * 0.054, 0, -0.362), Vector3(0.016, 0.014, 0.01), F.IRON_DARK)
	# Chain anchor ring on the right rail.
	F.hoop(k.m(), ax + Vector3(0.074, -0.03, -0.24), Vector3(0, 0, 1), 0.008, 0.0025, F.IRON, 10)
	# --- stock and grip, a forward handle under the frame
	var stock := [[Vector3(0, 0.042, 0.024), 0.03, 0.03], [Vector3(0, 0.028, 0.08), 0.025, 0.022],
		[Vector3(0, 0.0, 0.16), 0.03, 0.02], [Vector3(0, -0.03, 0.3), 0.048, 0.023],
		[Vector3(0, -0.042, 0.38), 0.055, 0.025], [Vector3(0, -0.043, 0.392), 0.056, 0.0255]]
	W.loft(k.w(), stock, F.WALNUT, 16)
	W.buttplate(k.m(), stock, F.IRON_DARK)
	F.box(k.w(), Vector3(0, 0.006, 0.05), Vector3(0.026, 0.034, 0.05), F.WALNUT)
	_grip(k, F.WALNUT_DARK, F.IRON)
	F.box(k.m(), ax + Vector3(0, -0.06, -0.27), Vector3(0.02, 0.014, 0.03), F.IRON_DARK)
	W.rod(k.w(), ax + Vector3(0, -0.066, -0.27), Vector3(0, -0.1, -0.255), 0.016, 0.018, 12, F.WALNUT)
	F.ball(k.w(), Vector3(0, -0.103, -0.255), Vector3(0.02, 0.01, 0.02), F.WALNUT_DARK, 4, 12)
	# --- cocking lever: a flat bar along the right rail, hooked handle at the front
	var lp: Vector3 = PIVOTS["bear_trap_launcher_lever"]
	F.cx(k.m(), lp + Vector3(-0.006, 0, 0), 0.01, 0.006, F.IRON_DARK, 12)
	F.cx(lv.m(), lp, 0.008, 0.008, F.STEEL, 12)
	F.box(lv.m(), lp + Vector3(0.002, 0, -0.14), Vector3(0.006, 0.014, 0.28), F.STEEL.darkened(0.1))
	W.bent(lv.m(), [lp + Vector3(0.002, 0, -0.278), lp + Vector3(0.008, -0.016, -0.3), lp + Vector3(0.014, -0.048, -0.31)], 0.0055, F.STEEL)
	W.rod(lv.w(), lp + Vector3(0.014, -0.05, -0.31), lp + Vector3(0.016, -0.095, -0.312), 0.011, 0.012, 12, F.WALNUT_DARK)
	F.screw(lv.m(), lp + Vector3(0.004, 0, -0.12), 1.0, F.BRASS)
	# --- the trap, seated open on the front, facing out
	var tc: Vector3 = PIVOTS["bear_trap_launcher_trap"]
	var jr := 0.1
	F.box(t.m(), tc + Vector3(0, 0, 0.006), Vector3(0.22, 0.016, 0.008), F.IRON_DARK)
	F.box(t.m(), tc + Vector3(0, 0, 0.006), Vector3(0.016, 0.07, 0.008), F.IRON_DARK)
	F.cz(t.m(), tc + Vector3(0, 0, -0.002), 0.036, 0.036, 0.006, F.IRON, 18)
	F.hoop(t.m(), tc + Vector3(0, 0, -0.005), Vector3(0, 0, 1), 0.035, 0.0025, F.IRON_DARK, 18)
	F.box(t.m(), tc + Vector3(0.012, 0.01, -0.007), Vector3(0.024, 0.006, 0.004), F.STEEL, Basis(Vector3.BACK, 0.3))
	for half: int in 2:
		var pts: Array = []
		for i in 15:
			var a := PI * float(half) + PI * float(i) / 14.0
			pts.append(tc + Vector3(cos(a) * jr, sin(a) * jr, -0.004))
		MeshKit.tube(t.m(), pts, [0.0068], 8, F.IRON)
		for i in 9:
			var a := PI * float(half) + lerpf(0.22, PI - 0.22, float(i) / 8.0)
			var rad := Vector3(cos(a), sin(a), 0.0)
			W.rod(t.m(), tc + rad * (jr - 0.005) + Vector3(0, 0, -0.006), tc + rad * (jr - 0.011) + Vector3(0, 0, -0.032), 0.0062, 0.0, 6, F.STEEL.lightened(0.1))
	for s: float in [-1.0, 1.0]:
		# Hinge posts, and a leaf spring folded out past each.
		F.box(t.m(), tc + Vector3(s * jr, 0, 0.0), Vector3(0.016, 0.022, 0.014), F.IRON_DARK)
		W.bent(t.m(), [tc + Vector3(s * (jr + 0.006), 0.011, 0.004), tc + Vector3(s * 0.165, 0.011, 0.004),
				tc + Vector3(s * 0.18, 0.004, 0.004), tc + Vector3(s * 0.18, -0.004, 0.004), tc + Vector3(s * 0.165, -0.011, 0.004),
				tc + Vector3(s * (jr + 0.006), -0.011, 0.004)], 0.0045, F.STEEL.darkened(0.1))
		F.hoop(t.m(), tc + Vector3(s * 0.125, 0, 0.004), Vector3(1, 0, 0), 0.014, 0.0028, F.IRON, 12)
	# Chain from the trap back to the anchor ring, sagging.
	var ca := tc + Vector3(0.06, -0.01, 0.01)
	var cb := Vector3(0.074, cy - 0.03, -0.25)
	for i in 15:
		var f := (float(i) + 0.5) / 15.0
		var cp := ca.lerp(cb, f) + Vector3(0.012 * sin(f * PI), -0.035 * sin(f * PI), 0)
		F.hoop(t.m(), cp, Vector3(1, 0, 0) if i % 2 == 0 else Vector3(0, 1, 0), 0.0085, 0.0022, F.IRON.darkened(0.1 * (i % 2)), 8)
	return {"body": k.commit(), "trap": t.commit(), "lever": lv.commit()}

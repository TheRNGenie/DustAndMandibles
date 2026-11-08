class_name UniHeavies
extends RefCounted
## The ten universal crop-loaded heavies (heavy weapons handoff, Part 4), built
## in code. Same conventions as ArmoryGuns (which routes these ids here): real
## size in gun space, barrel along -Z, +Y up, origin just above the trigger;
## four material surfaces (FrontierGuns.Kit); every moving part its own mesh on
## a pivot (PIVOTS). Every gun has:
##   "ring"  the crop indicator ring, a brass-collared glow band (tint())
##   "glow"  where the crop shows inside: chamber, window, hopper, magazine (tint())
## and, by gun (UniHeavyVM works them):
##   crop_mortar          "door" top breach door (hinged at its back edge, about X)
##   hand_cannon          "door" breech door (hinged at its foot, swings down)
##   crop_sprayer         "pump" hand pump (slides along Z)
##   spike_driver         "rack" spike magazine (slides out to the right)
##   drum_launcher        "cylinder" six tubes (turns a sixth a shot), "door" feed port cover
##   harvest_gatling      "spinner" four barrels, "crank" the handle, "door" hopper lid
##   crop_crossbow        "limb_l"/"limb_r" bow arms, "string", "bolt" (the loaded bolt), "lever" draw lever
##   bola_launcher        "cylinder" bola drum (turns a quarter a shot), "door" feed tube cap
##   powder_keg_launcher  "shell" the kegs in the rack (shown loaded), "door" the rack's top bar
##   crop_blunderbuss     "door" breech door, "rod" the ramrod (slides back to tamp)

const F := preload("res://gen/frontier_guns.gd")
const W := preload("res://gen/weapon_builder.gd")

const NAMES: Dictionary = {
	&"crop_mortar": "Crop Mortar", &"hand_cannon": "Hand Cannon", &"crop_sprayer": "Crop Sprayer",
	&"spike_driver": "Spike Driver", &"drum_launcher": "Drum Launcher", &"harvest_gatling": "Harvest Gatling",
	&"crop_crossbow": "Crop Crossbow", &"bola_launcher": "Bola Launcher", &"powder_keg_launcher": "Powder Keg Launcher",
	&"crop_blunderbuss": "Crop Blunderbuss",
}

## The older gun each handles like in Gun (shot cycle, how the support hand reaches).
## UniHeavyVM poses them itself, so posture comes from here only as a fallback.
const ACTS_LIKE: Dictionary = {
	&"crop_mortar": &"blunderbuss", &"hand_cannon": &"punt_gun", &"crop_sprayer": &"salt_shotgun",
	&"spike_driver": &"punt_gun", &"drum_launcher": &"pepperbox", &"harvest_gatling": &"crank_gatling",
	&"crop_crossbow": &"lever_rifle", &"bola_launcher": &"pepperbox", &"powder_keg_launcher": &"blunderbuss",
	&"crop_blunderbuss": &"blunderbuss",
}

const PIVOTS: Dictionary = {
	"crop_mortar_door": Vector3(0.0, 0.158, -0.07),
	"hand_cannon_door": Vector3(0.0, 0.012, 0.07),
	"crop_sprayer_pump": Vector3(0.0, -0.035, -0.2),
	"spike_driver_rack": Vector3(0.066, 0.105, -0.1),
	"drum_launcher_cylinder": Vector3(0.0, 0.075, -0.2),
	"drum_launcher_door": Vector3(0.0, 0.135, -0.02),
	"harvest_gatling_spinner": Vector3(0.0, 0.05, -0.45),
	"harvest_gatling_crank": Vector3(0.075, 0.05, -0.12),
	"harvest_gatling_door": Vector3(0.0, 0.155, -0.15),
	"crop_crossbow_limb_l": Vector3(-0.03, 0.055, -0.5),
	"crop_crossbow_limb_r": Vector3(0.03, 0.055, -0.5),
	"crop_crossbow_string": Vector3(0.0, 0.07, -0.5),
	"crop_crossbow_bolt": Vector3(0.0, 0.078, -0.3),
	"crop_crossbow_lever": Vector3(0.04, 0.03, -0.02),
	"bola_launcher_cylinder": Vector3(0.0, 0.07, -0.08),
	"bola_launcher_door": Vector3(0.075, 0.11, -0.2),
	"powder_keg_launcher_shell": Vector3(0.0, 0.17, -0.2),
	"powder_keg_launcher_door": Vector3(0.0, 0.215, -0.05),
	"crop_blunderbuss_door": Vector3(0.0, 0.1, 0.0),
	"crop_blunderbuss_rod": Vector3(0.0, 0.015, -0.35),
}
const MUZZLE: Dictionary = {
	&"crop_mortar": Vector3(0.0, 0.11, -0.53), &"hand_cannon": Vector3(0.0, 0.07, -0.78),
	&"crop_sprayer": Vector3(0.0, 0.035, -0.62), &"spike_driver": Vector3(0.0, 0.06, -0.64),
	&"drum_launcher": Vector3(0.0, 0.125, -0.38), &"harvest_gatling": Vector3(0.0, 0.08, -0.8),
	&"crop_crossbow": Vector3(0.0, 0.078, -0.58), &"bola_launcher": Vector3(0.0, 0.07, -0.47),
	&"powder_keg_launcher": Vector3(0.0, 0.08, -0.48), &"crop_blunderbuss": Vector3(0.0, 0.06, -0.74),
}
## [right fist centre, right grip axis, left support fist centre]. Every one has a
## fat pistol grip under its origin; the left hand holds the forend or a handle.
const HANDS: Dictionary = {
	&"crop_mortar": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, 0.03, -0.3)],
	&"hand_cannon": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.035, -0.36)],
	&"crop_sprayer": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.06, -0.2)],
	&"spike_driver": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.04, -0.33)],
	&"drum_launcher": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, 0.0, -0.28)],
	&"harvest_gatling": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.12, 0.05, -0.12)],
	&"crop_crossbow": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, 0.0, -0.3)],
	&"bola_launcher": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.01, -0.3)],
	&"powder_keg_launcher": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.005, -0.3)],
	&"crop_blunderbuss": [Vector3(0.0, -0.052, 0.07), Vector3(0, 0.92, -0.4), Vector3(0.0, -0.01, -0.36)],
}

## Lathe profiles run toward the muzzle with this basis (local +Y = gun -Z).
const LZ := Basis(Vector3.RIGHT, -PI * 0.5)
const GLOW := Color("#FFFFFF") # tinted per crop at run time (tint())
const IRON_RIVET := Color("#6E6458")
const RUBBER := Color("#2B2420")
const GLASS := Color("#A9CFC4")
const BURLAP := Color("#B08A55")
const BURLAP_DARK := Color("#8A6A3E")
const KEG := Color("#8A5A30")


static func has(id: StringName) -> bool:
	return NAMES.has(id)


static func build(id: StringName) -> Dictionary:
	var out := _build(id)
	if not out.is_empty():
		out.merge(_trims(id))
	return out


static func _build(id: StringName) -> Dictionary:
	match id:
		&"crop_mortar":
			return _mortar()
		&"hand_cannon":
			return _cannon()
		&"crop_sprayer":
			return _sprayer()
		&"spike_driver":
			return _spike()
		&"drum_launcher":
			return _drum()
		&"harvest_gatling":
			return _gatling()
		&"crop_crossbow":
			return _crossbow()
		&"bola_launcher":
			return _bola()
		&"powder_keg_launcher":
			return _keg()
		&"crop_blunderbuss":
			return _blunderbuss()
	return {}


# ------------------------------------------------------------------ upgrade trim

## The barrel's radius where the upgrade trim wraps it (Part 5, Tier Upgrade Visuals).
const TRIM_R: Dictionary = {&"crop_mortar": 0.074, &"hand_cannon": 0.064, &"crop_sprayer": 0.02, &"spike_driver": 0.068,
	&"drum_launcher": 0.073, &"harvest_gatling": 0.066, &"crop_crossbow": 0.03, &"bola_launcher": 0.07,
	&"powder_keg_launcher": 0.074, &"crop_blunderbuss": 0.04}
## Whole-gun scale at each upgrade (Common, Uncommon = Level 1, Rare = Level 2 and up).
const TRIM_SCALE: Array[float] = [1.0, 1.05, 1.1, 1.1, 1.1]


## "trim1" (Level 1: brass bands and a leather-wrapped grip) and "trim2" (Level 2:
## riveted reinforcement plates and thin glow lines along the top).
static func _trims(id: StringName) -> Dictionary:
	var m: Vector3 = MUZZLE[id]
	var r: float = TRIM_R[id]
	var ax := Vector3(0, m.y, 0)
	var t1 := F.Kit.new()
	for f: float in [0.3, 0.62]:
		var c := ax + Vector3(0, 0, m.z * f)
		F.cz(t1.m(), c, r + 0.004, r + 0.004, 0.014, F.BRASS_LIGHT, 22)
		F.hoop(t1.m(), c, Vector3.BACK, r + 0.005, 0.0022, F.BRASS_DARK, 22)
	for i in 4:
		F.cz(t1.x(), Vector3(0, -0.03 - i * 0.017, 0.06 + i * 0.008), 0.024, 0.024, 0.014, F.LEATHER.darkened(0.1 * (i % 2)), 12)
	var t2 := F.Kit.new()
	for sx: float in [-1.0, 1.0]:
		var c := ax + Vector3(sx * (r + 0.003), 0, m.z * 0.46)
		F.box(t2.m(), c, Vector3(0.004, r * 0.9, absf(m.z) * 0.22), F.IRON_DARK)
		for k in 3:
			F.ball(t2.m(), c + Vector3(sx * 0.003, (k - 1) * r * 0.3, 0), Vector3.ONE * 0.0035, F.BRASS_LIGHT, 3, 6)
	F.box(t2.g(), ax + Vector3(0, r + 0.002, m.z * 0.5), Vector3(0.003, 0.003, absf(m.z) * 0.6), GLOW)
	for sx: float in [-1.0, 1.0]:
		F.box(t2.g(), ax + Vector3(sx * r * 0.72, r * 0.72, m.z * 0.5), Vector3(0.0025, 0.0025, absf(m.z) * 0.5), GLOW)
	return {"trim1": t1.commit(), "trim2": t2.commit()}


## Shows the trim for an upgrade (rarity 0-4) on a gun's node tree.
static func show_trim(root: Node, rarity: int) -> void:
	if root == null:
		return
	for nm: String in ["Trim1", "Trim2"]:
		for n: Node in root.find_children(nm, "", true, false):
			(n as Node3D).visible = rarity >= (1 if nm == "Trim1" else 2)


# ------------------------------------------------------------------ the crop's glow

static var _ring_mats: Dictionary = {}


## The material on a ring or glow part: lit in the crop's colour (`boost` for the
## load pulse), or dark brass when empty (&"").
static func ring_mat(crop: StringName, boost: float = 1.0) -> StandardMaterial3D:
	var key := "%s_%d" % [crop, roundi(boost * 10.0)]
	if _ring_mats.has(key):
		return _ring_mats[key]
	var m := StandardMaterial3D.new()
	if crop == &"":
		m.albedo_color = HeavyRules.EMPTY_RING
		m.metallic = 0.6
		m.roughness = 0.45
	else:
		var c := HeavyRules.color_of(crop)
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.3 * boost
	_ring_mats[key] = m
	return m


## Lights every crop-glow surface under `root` (the ring, the glow parts, the
## spike tips, grenades, kegs' fuses, the string) with `crop` (&"" = dark).
static func tint(root: Node, crop: StringName, boost: float = 1.0) -> void:
	if root == null:
		return
	var m := ring_mat(crop, boost)
	var glow_mat := F.material(3)
	var all: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		all.append(root)
	for n: Node in all:
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_material(si) == glow_mat:
				mi.set_surface_override_material(si, m)


## The burlap sack the support hand fetches while loading: matte burlap, a cord
## at the neck, and a patch (surface 1, tinted to the crop).
static func sack() -> ArrayMesh:
	var k := F.Kit.new()
	F.ball(k.x(), Vector3(0, -0.003, 0), Vector3(0.026, 0.029, 0.024), BURLAP, 6, 12)
	F.cz(k.x(), Vector3(0, 0.026, 0), 0.008, 0.011, 0.011, BURLAP_DARK, 10)
	F.ball(k.x(), Vector3(0, 0.035, 0), Vector3(0.011, 0.007, 0.011), BURLAP, 4, 8)
	F.hoop(k.x(), Vector3(0, 0.024, 0), Vector3.UP, 0.0105, 0.0018, F.ROPE, 12)
	F.box(k.g(), Vector3(0, -0.003, -0.0245), Vector3(0.024, 0.021, 0.003), GLOW)
	return k.commit()


# ------------------------------------------------------------------ shared bits

## The common heavy grip under the origin: trigger, guard and a fat walnut grip.
static func _grip(k: F.Kit) -> void:
	F.trigger_and_guard(k, Vector3(0, -0.018, 0.022), 0.027, F.BRASS_DARK)
	F.pistol_grip(k, Vector3(0, -0.008, 0.05), Vector3(0, -0.105, 0.092), F.WALNUT, F.BRASS, 1.15)


## The indicator ring part: a glow band round the gun at `c` facing `n`.
static func _ring(c: Vector3, n: Vector3, r: float, thick: float = 0.007) -> ArrayMesh:
	var k := F.Kit.new()
	F.hoop(k.g(), c, n, r, thick, GLOW, 28)
	return k.commit()


## A brass collar under the ring on the body (so the ring sits in a fitting).
static func _collar(k: F.Kit, c: Vector3, r: float, length: float = 0.022) -> void:
	F.cz(k.m(), c, r, r, length, F.BRASS_DARK, 24)
	F.cz(k.m(), c + Vector3(0, 0, length * 0.5), r + 0.003, r + 0.003, 0.004, F.BRASS_LIGHT, 24)
	F.cz(k.m(), c - Vector3(0, 0, length * 0.5), r + 0.003, r + 0.003, 0.004, F.BRASS_LIGHT, 24)


static func _studs(st: SurfaceTool, c: Vector3, r: float, n: int, size: float, col: Color) -> void:
	for i in n:
		var a := TAU * float(i) / n
		F.ball(st, c + Vector3(cos(a) * r, sin(a) * r, 0.0), Vector3.ONE * size, col, 3, 6)


static func _bore(k: F.Kit, c: Vector3, r: float) -> void:
	F.cz(k.x(), c, r, r, 0.0015, F.BORE, 16)


## A walnut shoulder stock running back from `front` to a butt at `back_z`.
static func _stock(k: F.Kit, front: Vector3, back_z: float, drop: float, w: float, h: float) -> void:
	var stations := [[front, w * 0.6, h * 0.5], [Vector3(0, front.y - drop * 0.4, lerpf(front.z, back_z, 0.45)), w * 0.8, h * 0.8],
		[Vector3(0, front.y - drop, back_z - 0.01), w, h], [Vector3(0, front.y - drop, back_z), w * 0.95, h * 0.95]]
	W.loft(k.w(), stations, F.WALNUT, 14)
	F.box(k.x(), Vector3(0, front.y - drop, back_z + 0.006), Vector3(w * 1.9, h * 1.9, 0.012), F.LEATHER)


# ------------------------------------------------------------------ 1. crop mortar

## A short, wide brass tube on a carved stock with a shoulder pad, a hinged
## top-loading breach door over a glowing crop chamber.
static func _mortar() -> Dictionary:
	var k := F.Kit.new()
	var y := 0.11
	var ax := Vector3(0, y, 0)
	_grip(k)
	# Tube, fat and short, a flared lip.
	F.cz(k.m(), ax + Vector3(0, 0, -0.24), 0.066, 0.072, 0.56, F.BRASS, 24)
	F.cz(k.m(), ax + Vector3(0, 0, -0.515), 0.078, 0.07, 0.03, F.BRASS_LIGHT, 24)
	_bore(k, ax + Vector3(0, 0, -0.531), 0.06)
	for z: float in [0.0, -0.16, -0.46]:
		F.cz(k.m(), ax + Vector3(0, 0, z), 0.075, 0.075, 0.022, F.BRASS_DARK, 24)
		_studs(k.m(), ax + Vector3(0, 0, z + 0.006), 0.075, 10, 0.0032, F.BRASS_LIGHT)
	_collar(k, ax + Vector3(0, 0, -0.36), 0.074)
	# Breech end: a domed iron cap and the frame down to the grip.
	MeshKit.lathe(k.m(), Transform3D(F.Z, ax + Vector3(0, 0, 0.04)), [Vector2(0.072, 0.0), Vector2(0.066, 0.02),
			Vector2(0.045, 0.04), Vector2(0.0, 0.05)], 22, F.IRON)
	F.box(k.m(), Vector3(0, 0.03, 0.02), Vector3(0.05, 0.08, 0.1), F.IRON_DARK)
	# The chamber opening on top (the door covers it) and its iron frame.
	F.box(k.m(), ax + Vector3(0, 0.068, -0.16), Vector3(0.075, 0.012, 0.18), F.IRON_DARK)
	# Stock with shoulder pad, back from the frame.
	_stock(k, Vector3(0, 0.03, 0.08), 0.2, 0.04, 0.03, 0.055)
	# A leather wrap where the left hand cradles the tube.
	for i in 4:
		F.cz(k.x(), ax + Vector3(0, 0, -0.27 - i * 0.022), 0.0735, 0.0735, 0.02, F.LEATHER.darkened(0.08 * (i % 2)), 24)
	var door := F.Kit.new()
	F.box(door.m(), ax + Vector3(0, 0.077, -0.16), Vector3(0.068, 0.008, 0.17), F.BRASS)
	F.box(door.m(), ax + Vector3(0, 0.085, -0.22), Vector3(0.02, 0.012, 0.03), F.BRASS_LIGHT)
	for zz: float in [-0.09, -0.23]:
		F.ball(door.m(), ax + Vector3(0, 0.083, zz), Vector3.ONE * 0.005, F.BRASS_DARK, 3, 6)
	var glow := F.Kit.new()
	F.box(glow.g(), ax + Vector3(0, 0.06, -0.16), Vector3(0.05, 0.004, 0.15), GLOW)
	return {"body": k.commit(), "door": door.commit(), "glow": glow.commit(),
		"ring": _ring(ax + Vector3(0, 0, -0.36), Vector3.BACK, 0.079)}


# ------------------------------------------------------------------ 2. hand cannon

## An oversized thick-walled iron barrel with brass bands, a heavy wooden
## shoulder brace, a pistol grip and a rear breech door hinged at its foot.
static func _cannon() -> Dictionary:
	var k := F.Kit.new()
	var y := 0.07
	var ax := Vector3(0, y, 0)
	_grip(k)
	MeshKit.lathe(k.m(), Transform3D(LZ, ax + Vector3(0, 0, 0.05)), [Vector2(0.066, 0.0), Vector2(0.07, 0.05),
			Vector2(0.062, 0.2), Vector2(0.056, 0.6), Vector2(0.06, 0.78), Vector2(0.066, 0.8), Vector2(0.066, 0.83)], 24, F.IRON)
	_bore(k, ax + Vector3(0, 0, -0.781), 0.03)
	for z: float in [-0.05, -0.22, -0.56, -0.72]:
		F.cz(k.m(), ax + Vector3(0, 0, z), 0.069, 0.069, 0.026, F.BRASS, 24)
	_collar(k, ax + Vector3(0, 0, -0.4), 0.063)
	# Trunnion lugs and a sight blade.
	for sx: float in [-1.0, 1.0]:
		F.cx(k.m(), ax + Vector3(sx * 0.072, 0, -0.12), 0.014, 0.02, F.IRON_DARK)
	F.box(k.m(), ax + Vector3(0, 0.068, -0.7), Vector3(0.006, 0.016, 0.03), F.BRASS_LIGHT)
	# The iron frame into the grip and the breech's rim.
	F.box(k.m(), Vector3(0, 0.02, 0.03), Vector3(0.06, 0.08, 0.1), F.IRON_DARK)
	F.cz(k.m(), ax + Vector3(0, 0, 0.07), 0.07, 0.07, 0.012, F.IRON_DARK, 24)
	# Shoulder brace: a thick walnut stock.
	_stock(k, Vector3(0, 0.03, 0.09), 0.22, 0.03, 0.036, 0.065)
	# A forward grip under the barrel for the left hand.
	F.cz(k.w(), Vector3(0, -0.005, -0.36), 0.028, 0.028, 0.12, F.WALNUT_DARK, 14)
	F.box(k.m(), Vector3(0, 0.025, -0.36), Vector3(0.03, 0.03, 0.06), F.BRASS_DARK)
	var door := F.Kit.new()
	F.cz(door.m(), ax + Vector3(0, 0, 0.082), 0.06, 0.06, 0.016, F.IRON, 22)
	F.ball(door.m(), ax + Vector3(0, 0, 0.092), Vector3(0.022, 0.022, 0.008), F.BRASS, 4, 10)
	F.box(door.m(), ax + Vector3(0, -0.055, 0.082), Vector3(0.03, 0.02, 0.02), F.IRON_DARK)
	var glow := F.Kit.new()
	F.cz(glow.g(), ax + Vector3(0, 0, 0.075), 0.03, 0.03, 0.003, GLOW, 16)
	return {"body": k.commit(), "door": door.commit(), "glow": glow.commit(),
		"ring": _ring(ax + Vector3(0, 0, -0.4), Vector3.BACK, 0.068)}


# ------------------------------------------------------------------ 3. crop sprayer

## A farm pump sprayer turned weapon: a brass lance with a wide fan nozzle, a
## wooden front grip, a hand pump underneath, a glass sight tube showing the
## liquid, and the rubber hose curling back to the tank on your back.
static func _sprayer() -> Dictionary:
	var k := F.Kit.new()
	var y := 0.035
	var ax := Vector3(0, y, 0)
	_grip(k)
	# Valve body over the grip, the lance forward.
	F.box(k.m(), Vector3(0, 0.03, 0.01), Vector3(0.05, 0.05, 0.12), F.BRASS_DARK)
	F.cz(k.m(), ax + Vector3(0, 0, -0.28), 0.016, 0.018, 0.52, F.BRASS, 14)
	for z: float in [-0.08, -0.42]:
		F.cz(k.m(), ax + Vector3(0, 0, z), 0.024, 0.024, 0.018, F.BRASS_LIGHT, 14)
	# Fan nozzle: a flattened flare.
	MeshKit.lathe(k.m(), Transform3D(LZ, ax + Vector3(0, 0, -0.54)), [Vector2(0.018, 0.0), Vector2(0.03, 0.04),
			Vector2(0.06, 0.08), Vector2(0.064, 0.085)], 18, F.BRASS, Vector2(1.0, 0.35))
	F.box(k.x(), ax + Vector3(0, 0, -0.627), Vector3(0.11, 0.012, 0.003), F.BORE)
	# Pump cylinder under the lance (the handle slides along it).
	F.cz(k.m(), Vector3(0, -0.035, -0.2), 0.016, 0.016, 0.24, F.TIN, 14)
	# Glass sight tube on the left: shows the liquid (the glow part inside).
	F.cz(k.m(), Vector3(-0.04, 0.045, -0.1), 0.014, 0.014, 0.16, F.BRASS_DARK, 12)
	F.cz(k.x(), Vector3(-0.04, 0.045, -0.1), 0.0125, 0.0125, 0.13, GLASS, 12)
	_collar(k, ax + Vector3(0, 0, -0.47), 0.02, 0.016)
	# The hose: out of the valve, down and back over your shoulder to the tank.
	MeshKit.tube(k.x(), [Vector3(0.0, 0.05, 0.06), Vector3(0.03, 0.06, 0.14), Vector3(0.09, 0.02, 0.24), Vector3(0.14, -0.08, 0.34)],
			[0.013, 0.013, 0.013, 0.013], 8, RUBBER)
	var pump := F.Kit.new()
	F.cz(pump.w(), Vector3(0, -0.06, -0.2), 0.022, 0.022, 0.09, F.WALNUT, 14)
	F.cz(pump.m(), Vector3(0, -0.06, -0.2), 0.024, 0.024, 0.012, F.BRASS, 14)
	F.box(pump.m(), Vector3(0, -0.047, -0.2), Vector3(0.012, 0.02, 0.05), F.BRASS_DARK)
	var glow := F.Kit.new()
	F.cz(glow.g(), Vector3(-0.04, 0.045, -0.1), 0.009, 0.009, 0.12, GLOW, 10)
	return {"body": k.commit(), "pump": pump.commit(), "glow": glow.commit(),
		"ring": _ring(ax + Vector3(0, 0, -0.47), Vector3.BACK, 0.025, 0.006)}


# ------------------------------------------------------------------ 4. spike driver

## A railroad spike driver: a heavy riveted iron housing, a pneumatic chamber on
## top, side exhaust vents, and a five-spike rack at the back right.
static func _spike() -> Dictionary:
	var k := F.Kit.new()
	_grip(k)
	var c := Vector3(0, 0.06, -0.25)
	F.box(k.m(), c, Vector3(0.11, 0.1, 0.66), F.IRON)
	F.box(k.m(), c + Vector3(0, -0.055, 0.0), Vector3(0.1, 0.012, 0.6), F.IRON_DARK)
	for z: float in [-0.5, -0.3, -0.1, 0.05]:
		for sx: float in [-1.0, 1.0]:
			F.ball(k.m(), Vector3(sx * 0.056, 0.09, z), Vector3.ONE * 0.005, IRON_RIVET, 3, 6)
			F.ball(k.m(), Vector3(sx * 0.056, 0.03, z), Vector3.ONE * 0.005, IRON_RIVET, 3, 6)
	# Square muzzle and its bore.
	F.box(k.m(), Vector3(0, 0.06, -0.6), Vector3(0.13, 0.12, 0.04), F.IRON_DARK)
	F.box(k.x(), Vector3(0, 0.06, -0.621), Vector3(0.035, 0.035, 0.002), F.BORE)
	# Pneumatic chamber on top: a brass tank in iron straps (its window is the glow part).
	F.cz(k.m(), Vector3(0, 0.14, -0.22), 0.036, 0.036, 0.34, F.BRASS, 18)
	MeshKit.lathe(k.m(), Transform3D(LZ, Vector3(0, 0.14, -0.39)), [Vector2(0.036, 0.0), Vector2(0.03, 0.02), Vector2(0.0, 0.03)], 18, F.BRASS_DARK)
	for z: float in [-0.1, -0.34]:
		F.cz(k.m(), Vector3(0, 0.14, z), 0.039, 0.039, 0.016, F.IRON_DARK, 18)
	F.cx(k.m(), Vector3(0, 0.14, -0.05), 0.012, 0.03, F.BRASS_LIGHT) # pressure gauge stub
	# Exhaust vents, one each side.
	for sx: float in [-1.0, 1.0]:
		F.box(k.m(), Vector3(sx * 0.062, 0.07, -0.44), Vector3(0.014, 0.05, 0.09), F.IRON_DARK)
		for i in 3:
			F.box(k.x(), Vector3(sx * 0.07, 0.055 + i * 0.016, -0.44), Vector3(0.002, 0.006, 0.07), F.SOOT)
	_collar(k, Vector3(0, 0.06, -0.52), 0.07)
	# The rack slot at the back right.
	F.box(k.m(), Vector3(0.062, 0.1, -0.1), Vector3(0.022, 0.04, 0.12), F.IRON_DARK)
	var rack := F.Kit.new()
	F.box(rack.m(), Vector3(0.066, 0.105, -0.1), Vector3(0.022, 0.035, 0.12), F.IRON)
	for i in 5:
		var z := -0.15 + i * 0.024
		F.box(rack.m(), Vector3(0.08, 0.105, z), Vector3(0.01, 0.01, 0.014), F.IRON_DARK)
		F.ball(rack.g(), Vector3(0.088, 0.105, z), Vector3(0.006, 0.006, 0.006), GLOW, 3, 6) # crop tips (lit by the crop)
	var glow := F.Kit.new()
	F.box(glow.g(), Vector3(0, 0.177, -0.22), Vector3(0.02, 0.003, 0.2), GLOW)
	var ring := _ring(Vector3(0, 0.06, -0.52), Vector3.BACK, 0.078)
	# (the rack's spike tips glow too: its node is named "Rack", so tint them with the ring)
	return {"body": k.commit(), "rack": rack.commit(), "glow": glow.commit(), "ring": ring}


# ------------------------------------------------------------------ 5. drum launcher

## Six brass tubes on a turning drum over a wooden pistol grip, a short forearm
## brace, a face plate with the ring, and a feed port cover at the back.
static func _drum() -> Dictionary:
	var k := F.Kit.new()
	_grip(k)
	var axis := Vector3(0, 0.075, 0)
	# The frame: a top strap from the breech plate to the front axle.
	F.cz(k.m(), axis + Vector3(0, 0, -0.02), 0.07, 0.07, 0.03, F.IRON_DARK, 24)
	F.box(k.m(), Vector3(0, 0.03, 0.0), Vector3(0.05, 0.06, 0.08), F.IRON_DARK)
	F.cz(k.m(), axis + Vector3(0, 0, -0.2), 0.012, 0.012, 0.38, F.STEEL, 10)
	F.cz(k.m(), axis + Vector3(0, 0, -0.375), 0.072, 0.072, 0.012, F.BRASS_DARK, 24) # face plate
	_bore(k, axis + Vector3(0, 0.05, -0.382), 0.02)
	# Forearm brace: a short stock back along the forearm.
	_stock(k, Vector3(0, 0.03, 0.08), 0.17, 0.02, 0.024, 0.045)
	var cyl := F.Kit.new()
	for i in 6:
		var a := TAU * i / 6.0 + PI * 0.5
		var p := axis + Vector3(cos(a) * 0.048, sin(a) * 0.048, -0.2)
		F.cz(cyl.m(), p, 0.021, 0.021, 0.32, F.BRASS if i % 2 == 0 else F.BRASS_LIGHT, 14)
		_bore(cyl, p + Vector3(0, 0, -0.161), 0.016)
		F.ball(cyl.g(), p + Vector3(0, 0, -0.15), Vector3.ONE * 0.012, GLOW, 3, 6) # a grenade in each tube
	F.cz(cyl.m(), axis + Vector3(0, 0, -0.2), 0.03, 0.03, 0.3, F.BRASS_DARK, 14)
	for z: float in [-0.08, -0.32]:
		F.cz(cyl.m(), axis + Vector3(0, 0, z), 0.073, 0.073, 0.014, F.IRON_DARK, 24)
	var door := F.Kit.new()
	F.box(door.m(), Vector3(0, 0.137, -0.04), Vector3(0.05, 0.008, 0.05), F.BRASS)
	var glow := F.Kit.new()
	F.box(glow.g(), Vector3(0, 0.13, -0.04), Vector3(0.04, 0.003, 0.04), GLOW)
	return {"body": k.commit(), "cylinder": cyl.commit(), "door": door.commit(), "glow": glow.commit(),
		"ring": _ring(axis + Vector3(0, 0, -0.383), Vector3.BACK, 0.064, 0.006)}


# ------------------------------------------------------------------ 6. harvest gatling

## A hand-cranked four-barrel gatling: brass housing, an open-top crop hopper with
## a belt down to the breech, a crank on the right, a front carry handle.
static func _gatling() -> Dictionary:
	var k := F.Kit.new()
	_grip(k)
	var axis := Vector3(0, 0.05, 0)
	F.cz(k.m(), axis + Vector3(0, 0, -0.16), 0.06, 0.064, 0.3, F.BRASS, 24)
	F.cz(k.m(), axis + Vector3(0, 0, -0.01), 0.066, 0.066, 0.02, F.BRASS_DARK, 24)
	F.cz(k.m(), axis + Vector3(0, 0, -0.32), 0.066, 0.066, 0.02, F.BRASS_DARK, 24)
	F.box(k.m(), Vector3(0, 0.0, 0.02), Vector3(0.05, 0.06, 0.08), F.IRON_DARK)
	# Front muzzle ring holding the barrels.
	F.cz(k.m(), axis + Vector3(0, 0, -0.74), 0.054, 0.054, 0.018, F.IRON_DARK, 22)
	# Hopper: an open-top tin box on top, its belt down into the housing.
	var hop := Vector3(0, 0.13, -0.2)
	for sx: float in [-1.0, 1.0]:
		F.box(k.m(), hop + Vector3(sx * 0.03, 0, 0), Vector3(0.005, 0.045, 0.1), F.TIN)
	for sz: float in [-1.0, 1.0]:
		F.box(k.m(), hop + Vector3(0, 0, sz * 0.049), Vector3(0.065, 0.045, 0.005), F.TIN)
	F.box(k.m(), hop + Vector3(0, -0.022, 0), Vector3(0.065, 0.005, 0.1), F.TIN.darkened(0.2))
	for i in 4:
		F.box(k.x(), Vector3(0.0, 0.1 - i * 0.008, -0.15 - i * 0.01), Vector3(0.024, 0.004, 0.01), F.LEATHER)
	# Front carry handle on top of the housing.
	W.bent(k.m(), [Vector3(0, 0.11, -0.26), Vector3(0, 0.17, -0.3), Vector3(0, 0.17, -0.4), Vector3(0, 0.11, -0.44)], 0.008, F.IRON)
	_collar(k, axis + Vector3(0, 0, -0.33), 0.066, 0.016)
	# Crank boss on the right.
	F.cx(k.m(), Vector3(0.066, 0.05, -0.12), 0.02, 0.02, F.IRON_DARK)
	var spin := F.Kit.new()
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var p := axis + Vector3(cos(a) * 0.028, sin(a) * 0.028, -0.52)
		F.cz(spin.m(), p, 0.012, 0.013, 0.42, F.IRON, 12)
		_bore(spin, p + Vector3(0, 0, -0.211), 0.006)
		F.cz(spin.m(), p + Vector3(0, 0, -0.15), 0.015, 0.015, 0.012, F.BRASS, 12)
	F.cz(spin.m(), axis + Vector3(0, 0, -0.52), 0.016, 0.016, 0.42, F.STEEL, 10)
	var crank := F.Kit.new()
	F.box(crank.m(), Vector3(0.08, 0.05, -0.12) + Vector3(0, -0.03, 0), Vector3(0.012, 0.07, 0.016), F.IRON)
	F.cx(crank.w(), Vector3(0.1, 0.0, -0.12), 0.012, 0.05, F.WALNUT)
	var door := F.Kit.new()
	F.box(door.m(), hop + Vector3(0, 0.025, 0), Vector3(0.068, 0.005, 0.104), F.TIN.lightened(0.1))
	var glow := F.Kit.new()
	F.box(glow.g(), hop + Vector3(0, 0.004, 0), Vector3(0.055, 0.028, 0.09), GLOW)
	return {"body": k.commit(), "spinner": spin.commit(), "crank": crank.commit(), "door": door.commit(),
		"glow": glow.commit(), "ring": _ring(axis + Vector3(0, 0, -0.33), Vector3.BACK, 0.07)}


# ------------------------------------------------------------------ 7. crop crossbow

## A heavy repeating crossbow: wood-and-iron stock, steel limbs on crop-fibre
## string, a bolt track, a brass magazine on top and a draw lever.
static func _crossbow() -> Dictionary:
	var k := F.Kit.new()
	_grip(k)
	# The tiller: one long walnut beam from the butt to the bow.
	W.loft(k.w(), [[Vector3(0, 0.05, -0.5), 0.022, 0.024], [Vector3(0, 0.045, -0.2), 0.024, 0.03],
		[Vector3(0, 0.03, 0.05), 0.026, 0.04], [Vector3(0, 0.0, 0.2), 0.028, 0.052], [Vector3(0, 0.0, 0.21), 0.027, 0.05]], F.WALNUT, 14)
	F.box(k.x(), Vector3(0, 0.0, 0.217), Vector3(0.052, 0.098, 0.012), F.LEATHER)
	F.box(k.m(), Vector3(0, 0.072, -0.26), Vector3(0.012, 0.006, 0.5), F.STEEL) # the bolt track
	# The bow's iron head where the limbs seat.
	F.box(k.m(), Vector3(0, 0.055, -0.5), Vector3(0.07, 0.04, 0.05), F.IRON)
	F.box(k.m(), Vector3(0, 0.08, -0.56), Vector3(0.03, 0.01, 0.07), F.IRON_DARK) # stirrup
	# Brass magazine on top with a slot window (the glow part).
	F.box(k.m(), Vector3(0, 0.11, -0.18), Vector3(0.04, 0.05, 0.2), F.BRASS)
	F.box(k.m(), Vector3(0, 0.138, -0.18), Vector3(0.044, 0.006, 0.21), F.BRASS_DARK)
	_collar(k, Vector3(0, 0.035, -0.08), 0.03, 0.018)
	var limb_l := F.Kit.new()
	var limb_r := F.Kit.new()
	for side in [[limb_l, -1.0], [limb_r, 1.0]]:
		var kk: F.Kit = side[0]
		var s: float = side[1]
		W.bent(kk.m(), [Vector3(s * 0.03, 0.055, -0.5), Vector3(s * 0.13, 0.055, -0.515), Vector3(s * 0.23, 0.055, -0.49),
				Vector3(s * 0.29, 0.055, -0.46)], 0.008, F.STEEL)
		F.ball(kk.m(), Vector3(s * 0.292, 0.055, -0.458), Vector3.ONE * 0.008, F.BRASS, 3, 6)
	var string := F.Kit.new()
	# Drawn: tips to the nock 0.28 m back (UniHeavyVM squashes it flat when released).
	W.bent(string.g(), [Vector3(-0.29, 0.07, -0.5), Vector3(0, 0.07, -0.22)], 0.0022, GLOW)
	W.bent(string.g(), [Vector3(0.29, 0.07, -0.5), Vector3(0, 0.07, -0.22)], 0.0022, GLOW)
	var bolt := F.Kit.new()
	F.cz(bolt.w(), Vector3(0, 0.078, -0.37), 0.005, 0.005, 0.3, F.WALNUT_LIGHT, 8)
	F.cz(bolt.g(), Vector3(0, 0.078, -0.535), 0.0, 0.01, 0.04, GLOW, 8)
	for s: float in [-1.0, 1.0]:
		F.box(bolt.x(), Vector3(s * 0.008, 0.08, -0.24), Vector3(0.012, 0.002, 0.03), F.IVORY)
	var lever := F.Kit.new()
	W.bent(lever.m(), [Vector3(0.04, 0.03, -0.02), Vector3(0.045, 0.0, 0.08), Vector3(0.04, -0.02, 0.16)], 0.006, F.IRON)
	F.ball(lever.m(), Vector3(0.04, -0.02, 0.165), Vector3.ONE * 0.012, F.BRASS, 3, 8)
	var glow := F.Kit.new()
	F.box(glow.g(), Vector3(0.0215, 0.11, -0.18), Vector3(0.002, 0.016, 0.14), GLOW)
	F.box(glow.g(), Vector3(-0.0215, 0.11, -0.18), Vector3(0.002, 0.016, 0.14), GLOW)
	return {"body": k.commit(), "limb_l": limb_l.commit(), "limb_r": limb_r.commit(), "string": string.commit(),
		"bolt": bolt.commit(), "lever": lever.commit(), "glow": glow.commit(),
		"ring": _ring(Vector3(0, 0.035, -0.08), Vector3.BACK, 0.034, 0.006)}


# ------------------------------------------------------------------ 8. bola launcher

## A wide brass barrel over a turning bola drum, a crop feed tube on the side
## and a wooden pistol grip.
static func _bola() -> Dictionary:
	var k := F.Kit.new()
	_grip(k)
	var ax := Vector3(0, 0.07, 0)
	F.box(k.m(), Vector3(0, 0.03, 0.01), Vector3(0.05, 0.07, 0.08), F.IRON_DARK)
	F.cz(k.m(), ax + Vector3(0, 0, -0.3), 0.068, 0.062, 0.3, F.BRASS, 24)
	F.cz(k.m(), ax + Vector3(0, 0, -0.455), 0.074, 0.068, 0.02, F.BRASS_LIGHT, 24)
	_bore(k, ax + Vector3(0, 0, -0.466), 0.058)
	F.cz(k.m(), ax + Vector3(0, 0, -0.16), 0.072, 0.072, 0.02, F.IRON_DARK, 24)
	F.cz(k.m(), ax + Vector3(0, 0, 0.0), 0.072, 0.072, 0.02, F.IRON_DARK, 24)
	F.cz(k.m(), ax + Vector3(0, 0, -0.08), 0.014, 0.014, 0.18, F.STEEL, 10)
	# Feed tube up the right side, with its cap (the door) at the front.
	F.cz(k.m(), Vector3(0.075, 0.11, -0.1), 0.014, 0.014, 0.2, F.COPPER, 12)
	F.box(k.m(), Vector3(0.06, 0.1, -0.01), Vector3(0.03, 0.02, 0.02), F.BRASS_DARK)
	_collar(k, ax + Vector3(0, 0, -0.43), 0.066, 0.016)
	# A forward grip strap under the barrel.
	F.box(k.w(), Vector3(0, 0.0, -0.3), Vector3(0.04, 0.04, 0.12), F.WALNUT_DARK)
	var cyl := F.Kit.new()
	F.cz(cyl.m(), ax + Vector3(0, 0, -0.08), 0.068, 0.068, 0.14, F.BRASS_DARK, 24)
	for i in 4:
		var a := TAU * i / 4.0
		var p := ax + Vector3(cos(a) * 0.069, sin(a) * 0.069, -0.08)
		F.box(cyl.x(), p, Vector3(0.022, 0.022, 0.11), F.BORE, Basis(Vector3.BACK, a))
		F.ball(cyl.g(), p * Vector3(1.0, 1.0, 1.0) + Vector3(0, 0, -0.02), Vector3.ONE * 0.01, GLOW, 3, 6)
		F.ball(cyl.g(), p + Vector3(0, 0, 0.02), Vector3.ONE * 0.01, GLOW, 3, 6)
	var door := F.Kit.new()
	F.cz(door.m(), Vector3(0.075, 0.11, -0.205), 0.017, 0.017, 0.014, F.BRASS, 12)
	var glow := F.Kit.new()
	F.cz(glow.g(), Vector3(0.075, 0.11, -0.1), 0.006, 0.006, 0.18, GLOW, 8)
	F.box(glow.g(), Vector3(0.0815, 0.11, -0.1), Vector3(0.002, 0.008, 0.16), GLOW)
	return {"body": k.commit(), "cylinder": cyl.commit(), "door": door.commit(), "glow": glow.commit(),
		"ring": _ring(ax + Vector3(0, 0, -0.43), Vector3.BACK, 0.071)}


# ------------------------------------------------------------------ 9. powder keg launcher

## A stubby flared brass tube on a curved wooden stock, an open iron rack of
## little kegs on top, and the crop infuser chamber at its base.
static func _keg() -> Dictionary:
	var k := F.Kit.new()
	_grip(k)
	var ax := Vector3(0, 0.08, 0)
	MeshKit.lathe(k.m(), Transform3D(LZ, ax + Vector3(0, 0, -0.04)), [Vector2(0.072, 0.0), Vector2(0.07, 0.3),
			Vector2(0.08, 0.39), Vector2(0.095, 0.43), Vector2(0.098, 0.44)], 24, F.BRASS)
	_bore(k, ax + Vector3(0, 0, -0.481), 0.07)
	F.cz(k.m(), ax + Vector3(0, 0, -0.2), 0.075, 0.075, 0.02, F.BRASS_DARK, 24)
	# Infuser chamber: an iron drum at the base with a glass port (glow).
	F.cz(k.m(), ax + Vector3(0, 0, 0.0), 0.082, 0.082, 0.08, F.IRON, 24)
	F.box(k.m(), Vector3(0, 0.025, 0.04), Vector3(0.05, 0.06, 0.08), F.IRON_DARK)
	_collar(k, ax + Vector3(0, 0, -0.08), 0.074)
	# Curved stock.
	_stock(k, Vector3(0, 0.04, 0.07), 0.2, 0.045, 0.028, 0.055)
	# Lever trigger in front of the guard.
	W.bent(k.m(), [Vector3(0, -0.005, 0.0), Vector3(0, -0.05, -0.02), Vector3(0, -0.07, 0.0)], 0.005, F.IRON)
	# The open rack frame on top.
	for sx: float in [-1.0, 1.0]:
		for z: float in [-0.32, -0.06]:
			F.box(k.m(), Vector3(sx * 0.045, 0.19, z), Vector3(0.006, 0.07, 0.006), F.IRON_DARK)
		F.box(k.m(), Vector3(sx * 0.045, 0.157, -0.19), Vector3(0.006, 0.006, 0.27), F.IRON_DARK)
	var kegs := F.Kit.new()
	for i in 3:
		var c := Vector3(0, 0.19, -0.27 + i * 0.09)
		F.cz(kegs.w(), c, 0.032, 0.032, 0.07, KEG, 12)
		for dz: float in [-0.024, 0.024]:
			F.cz(kegs.m(), c + Vector3(0, 0, dz), 0.034, 0.034, 0.006, F.IRON_DARK, 12)
		F.ball(kegs.g(), c + Vector3(0, 0.034, 0), Vector3.ONE * 0.006, GLOW, 3, 6)
	var door := F.Kit.new()
	F.box(door.m(), Vector3(0, 0.226, -0.19), Vector3(0.096, 0.008, 0.008), F.IRON)
	F.box(door.m(), Vector3(0, 0.226, -0.19), Vector3(0.008, 0.008, 0.27), F.IRON)
	var glow := F.Kit.new()
	F.cz(glow.g(), ax + Vector3(0, 0, 0.0), 0.084, 0.084, 0.012, GLOW, 24)
	return {"body": k.commit(), "shell": kegs.commit(), "door": door.commit(), "glow": glow.commit(),
		"ring": _ring(ax + Vector3(0, 0, -0.08), Vector3.BACK, 0.08)}


# ------------------------------------------------------------------ 10. crop blunderbuss

## A massive bell-mouthed brass blunderbuss: heavy walnut stock with a brass butt
## plate, a rear breech door, a pellet hopper and the ramrod under the barrel.
static func _blunderbuss() -> Dictionary:
	var k := F.Kit.new()
	_grip(k)
	var ax := Vector3(0, 0.06, 0)
	MeshKit.lathe(k.m(), Transform3D(LZ, ax + Vector3(0, 0, 0.02)), [Vector2(0.04, 0.0), Vector2(0.038, 0.1),
			Vector2(0.033, 0.3), Vector2(0.03, 0.5), Vector2(0.034, 0.56), Vector2(0.06, 0.66), Vector2(0.1, 0.735),
			Vector2(0.112, 0.755), Vector2(0.112, 0.765)], 28, F.BRASS)
	_bore(k, ax + Vector3(0, 0, -0.742), 0.098)
	for z: float in [-0.08, -0.3]:
		F.cz(k.m(), ax + Vector3(0, 0, z), 0.041, 0.041, 0.016, F.BRASS_DARK, 22)
	_collar(k, ax + Vector3(0, 0, -0.5), 0.032, 0.016)
	# Breech block, the hopper on top of it.
	F.box(k.m(), Vector3(0, 0.04, 0.03), Vector3(0.06, 0.07, 0.1), F.IRON_DARK)
	F.box(k.m(), Vector3(0, 0.115, -0.04), Vector3(0.04, 0.03, 0.05), F.BRASS_DARK)
	# The stock: heavy walnut under the barrel to a brass butt plate.
	W.loft(k.w(), [[Vector3(0, 0.02, -0.42), 0.03, 0.03], [Vector3(0, 0.02, -0.1), 0.033, 0.038],
		[Vector3(0, 0.0, 0.1), 0.034, 0.05], [Vector3(0, -0.02, 0.21), 0.038, 0.068], [Vector3(0, -0.02, 0.22), 0.037, 0.066]], F.WALNUT, 14)
	F.box(k.m(), Vector3(0, -0.02, 0.227), Vector3(0.066, 0.128, 0.01), F.BRASS)
	# Ramrod pipes.
	for z: float in [-0.2, -0.4]:
		F.cz(k.m(), Vector3(0, 0.015, z), 0.009, 0.009, 0.03, F.BRASS, 10)
	var rod := F.Kit.new()
	F.cz(rod.w(), Vector3(0, 0.015, -0.3), 0.006, 0.006, 0.5, F.WALNUT_DARK, 8)
	F.cz(rod.m(), Vector3(0, 0.015, -0.55), 0.008, 0.008, 0.02, F.BRASS, 8)
	var door := F.Kit.new()
	F.box(door.m(), Vector3(0, 0.1, 0.03), Vector3(0.05, 0.008, 0.07), F.BRASS)
	F.box(door.m(), Vector3(0, 0.106, 0.06), Vector3(0.02, 0.01, 0.015), F.BRASS_LIGHT)
	var glow := F.Kit.new()
	F.box(glow.g(), Vector3(0, 0.131, -0.04), Vector3(0.032, 0.003, 0.042), GLOW)
	F.cz(glow.g(), ax + Vector3(0, 0, -0.738), 0.06, 0.06, 0.002, GLOW, 22) # the bell's glow inside
	return {"body": k.commit(), "door": door.commit(), "rod": rod.commit(), "glow": glow.commit(),
		"ring": _ring(ax + Vector3(0, 0, -0.5), Vector3.BACK, 0.037, 0.0065)}

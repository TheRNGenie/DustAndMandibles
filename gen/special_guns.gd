class_name SpecialGuns
extends RefCounted
## The ten special weapons (slot 2, Nov 2026 special weapons handoff, Part 4),
## built in code from the handoff's parts lists and prompts. Same conventions as
## ArmoryGuns, which serves these through its secondary tables: real size in gun
## space (barrel along -Z, +Y up, origin just above the trigger), the four
## FrontierGuns surfaces (metal, varnished wood, matte, glow), moving parts on
## pivots. Every one has the handoff's two shared parts:
##   grip_wrap   the leather wrap, built white: paint_grip() dyes it the crop's
##               colour (plain brown leather with no crop)
##   mark        the maker's mark stamped on the frame, shown in the crop's
##               colour only while a crop is fitted
## Moving parts the viewmodel works (by the gun each one handles like, ACTS_LIKE
## in ArmoryGuns): "pump" (Crop Duster), "barrels" (Signal Flare's break-action,
## Spore Launcher's tube), "bellows"/"pleats" (Smoke Bellows), "shell" (the
## loaded needle or anchor, shown only while loaded).

const F := preload("res://gen/frontier_guns.gd")
const W := preload("res://gen/weapon_builder.gd")

const NAMES: Dictionary = {
	&"crop_duster": "Crop Duster", &"barb_sling": "Barb Sling", &"signal_flare": "Signal Flare",
	&"crop_syringe": "Crop Syringe", &"smoke_bellows": "Smoke Bellows", &"bramble_pistol": "Bramble Pistol",
	&"spore_launcher": "Spore Launcher", &"venom_needle": "Venom Needle", &"trip_wire_gun": "Trip Wire Gun",
	&"spark_pistol": "Spark Pistol",
}
## The older gun each handles like in first person (posture, reload rhythm).
const ACTS_LIKE: Dictionary = {
	&"crop_duster": &"salt_shotgun", &"barb_sling": &"flare_gun", &"signal_flare": &"flare_gun",
	&"crop_syringe": &"harpoon_pistol", &"smoke_bellows": &"bee_smoker", &"bramble_pistol": &"pepperbox",
	&"spore_launcher": &"flare_gun", &"venom_needle": &"flare_gun", &"trip_wire_gun": &"harpoon_pistol",
	&"spark_pistol": &"pepperbox",
}
const PIVOTS: Dictionary = {
	"crop_duster_pump": Vector3(0.0, -0.012, -0.09),
	"signal_flare_barrels": Vector3(0.0, 0.0, -0.036),
	"spore_launcher_barrels": Vector3(0.0, 0.0, -0.03),
	"smoke_bellows_bellows": Vector3(0.0, 0.012, -0.05),
	"smoke_bellows_pleats": Vector3(0.0, 0.012, -0.05),
	"crop_syringe_shell": Vector3(0.0, 0.03, -0.25),
	"trip_wire_gun_shell": Vector3(0.0, 0.03, -0.17),
}
const BELLOWS_OPEN := 0.25
const MUZZLE: Dictionary = {
	&"crop_duster": Vector3(0.0, 0.026, -0.2),
	&"barb_sling": Vector3(0.0, 0.02, -0.12),
	&"signal_flare": Vector3(0.0, 0.03, -0.19),
	&"crop_syringe": Vector3(0.0, 0.03, -0.31),
	&"smoke_bellows": Vector3(0.0, 0.11, -0.16),
	&"bramble_pistol": Vector3(0.0, 0.028, -0.16),
	&"spore_launcher": Vector3(0.0, 0.04, -0.24),
	&"venom_needle": Vector3(0.0, 0.03, -0.44),
	&"trip_wire_gun": Vector3(0.0, 0.03, -0.19),
	&"spark_pistol": Vector3(0.0, 0.028, -0.17),
}
## [right fist centre, right grip axis, left fist centre] (one-handed: left fist close by).
const _PISTOL := [Vector3(0.0, -0.052, 0.068), Vector3(0, 0.917, -0.4), Vector3(-0.018, -0.082, 0.05)]
const HANDS: Dictionary = {
	&"crop_duster": _PISTOL, &"barb_sling": _PISTOL, &"signal_flare": _PISTOL, &"crop_syringe": _PISTOL,
	&"smoke_bellows": [Vector3(0.0, -0.048, 0.072), Vector3(0, 0.96, -0.27), Vector3(0.0, 0.07, 0.088)],
	&"bramble_pistol": _PISTOL, &"spore_launcher": _PISTOL, &"venom_needle": _PISTOL, &"trip_wire_gun": _PISTOL,
	&"spark_pistol": _PISTOL,
}

## Plain (no crop) wrap: brown leather.
const PLAIN_WRAP := Color("#6B4A2E")
const GLASS := Color("#9FC7C0")
const THORN := Color("#5A3E22")
const POD := Color("#8FA070")
const COIL := Color("#B86A34")
const RUBBER := Color("#2E2622")

## Grip top and bottom for the standard pistol hand.
const GT := Vector3(0, -0.008, 0.048)
const GB := Vector3(0, -0.1, 0.088)


static func has(id: StringName) -> bool:
	return NAMES.has(id)


static func build(id: StringName) -> Dictionary:
	match id:
		&"crop_duster":
			return _duster()
		&"barb_sling":
			return _sling()
		&"signal_flare":
			return _flare()
		&"crop_syringe":
			return _syringe()
		&"smoke_bellows":
			return _bellows()
		&"bramble_pistol":
			return _bramble()
		&"spore_launcher":
			return _spore()
		&"venom_needle":
			return _needle()
		&"trip_wire_gun":
			return _wire_gun()
		&"spark_pistol":
			return _spark()
	return {}


# ------------------------------------------------------------------ crop paint

## Dye a built gun's grip wrap and maker's mark for `crop` (&"" = plain). `root`
## is any node holding the gun's part nodes (a ViewModel, ArmoryGuns.whole()).
static func paint_grip(root: Node, crop: StringName) -> void:
	if root == null:
		return
	var wrap := root.find_child("Grip Wrap", true, false)
	var mark := root.find_child("Mark", true, false)
	var col := SpecialCrop.color_of(crop) if crop != &"" else PLAIN_WRAP
	if wrap != null:
		for mi in wrap.find_children("*", "MeshInstance3D", true, false):
			var m := (F.material(2) as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.albedo_color = col
			(mi as MeshInstance3D).material_override = m
	if mark != null:
		(mark as Node3D).visible = crop != &""
		for mi in mark.find_children("*", "MeshInstance3D", true, false):
			var g := StandardMaterial3D.new()
			g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			g.vertex_color_use_as_albedo = true
			g.albedo_color = col * 1.3
			(mi as MeshInstance3D).material_override = g


# ------------------------------------------------------------------ shared bits

## Wrap bands round a pistol grip (white, dyed later), between top and bottom.
static func _wrap(k: F.Kit, top: Vector3, bottom: Vector3, fat: float = 1.0) -> void:
	var axis := (top - bottom).normalized()
	var b := MeshKit.basis_from_y(axis)
	for i in 6:
		var t := 0.12 + i * 0.15
		var c := bottom.lerp(top, t) + Vector3(0, 0, -0.001)
		MeshKit.add_box(k.x(), Transform3D(b, c), Vector3(0.036 * fat, 0.011, 0.028 * fat), Color.WHITE)


## The maker's mark: a little round stamp on the frame's right side at `p`.
static func _mark(k: F.Kit, p: Vector3) -> void:
	MeshKit.add_cylinder(k.x(), Transform3D(Basis(Vector3.BACK, PI * 0.5), p), 0.007, 0.007, 0.0015, 12, Color.WHITE)
	MeshKit.add_cylinder(k.x(), Transform3D(Basis(Vector3.BACK, PI * 0.5), p + Vector3(0.0004, 0, 0)), 0.0042, 0.0042, 0.0016, 10, Color(0.75, 0.75, 0.75))


## Grip, trigger and guard, and the two shared parts. Returns {"grip_wrap", "mark"}.
static func _hand_bits(k: F.Kit, mark_at: Vector3, panel: Color = F.WALNUT, strap: Color = F.BRASS) -> Dictionary:
	F.trigger_and_guard(k, Vector3(0, -0.019, 0.02), 0.028, F.BRASS)
	F.pistol_grip(k, GT, GB, panel, strap, 1.05)
	var gw := F.Kit.new()
	_wrap(gw, GT, GB, 1.05)
	var mk := F.Kit.new()
	_mark(mk, mark_at)
	return {"grip_wrap": gw.commit(), "mark": mk.commit()}


static func _frame(k: F.Kit, c: Vector3, size: Vector3, col: Color = F.BRASS) -> void:
	F.box(k.m(), c, size, col)
	for side: float in [-1.0, 1.0]:
		F.screw(k.m(), c + Vector3(side * size.x * 0.5, size.y * 0.2, 0.0), side, F.BRASS_LIGHT)


# ------------------------------------------------------------------ 1 Crop Duster

## Small brass pump-action pistol: short wide barrel, fan nozzle, dust canister
## on top, pump slide underneath.
static func _duster() -> Dictionary:
	var k := F.Kit.new()
	_frame(k, Vector3(0, 0.012, 0.0), Vector3(0.032, 0.05, 0.07))
	F.cz(k.m(), Vector3(0, 0.026, -0.09), 0.019, 0.02, 0.13, F.BRASS, 16)
	F.cz(k.m(), Vector3(0, 0.026, -0.03), 0.022, 0.022, 0.006, F.BRASS_DARK, 16)
	# Fan nozzle: a flattened flaring box at the muzzle.
	for i in 4:
		var z := -0.16 - i * 0.01
		F.box(k.m(), Vector3(0, 0.026, z), Vector3(0.04 + i * 0.012, 0.024 - i * 0.003, 0.012), F.BRASS_LIGHT if i == 3 else F.BRASS)
	F.box(k.x(), Vector3(0, 0.026, -0.2), Vector3(0.07, 0.006, 0.002), F.BORE)
	# Dust canister on top, with a twist-lock band.
	F.cz(k.m(), Vector3(0, 0.068, -0.06), 0.017, 0.017, 0.1, F.TIN, 14)
	F.hoop(k.m(), Vector3(0, 0.068, -0.012), Vector3(0, 0, 1), 0.0175, 0.002, F.BRASS_DARK, 14)
	F.cz(k.m(), Vector3(0, 0.068, -0.112), 0.012, 0.017, 0.008, F.BRASS_DARK, 14)
	for z: float in [-0.03, -0.09]:
		F.box(k.m(), Vector3(0, 0.048, z), Vector3(0.008, 0.012, 0.008), F.BRASS_DARK)
	var pump := F.Kit.new()
	F.cz(pump.m(), Vector3(0, -0.012, -0.09), 0.013, 0.013, 0.07, F.IRON, 12)
	for i in 5:
		F.hoop(pump.m(), Vector3(0, -0.012, -0.066 - i * 0.012), Vector3(0, 0, 1), 0.0135, 0.0018, F.IRON_DARK, 12)
	var out := _hand_bits(k, Vector3(0.0165, 0.02, -0.005))
	out["body"] = k.commit()
	out["pump"] = pump.commit()
	return out


# ------------------------------------------------------------------ 2 Barb Sling

## A leather sling on a brass handle, its brass cup holding a cluster of barbs.
static func _sling() -> Dictionary:
	var k := F.Kit.new()
	# Brass handle frame the sling straps run from.
	F.cz(k.m(), Vector3(0, 0.02, -0.02), 0.012, 0.012, 0.06, F.BRASS, 12)
	F.hoop(k.m(), Vector3(0, 0.02, -0.052), Vector3(0, 0, 1), 0.014, 0.003, F.BRASS_DARK, 12)
	# Two leather straps forward to the cup.
	for side: float in [-1.0, 1.0]:
		W.bent(k.x(), [Vector3(side * 0.008, 0.02, -0.05), Vector3(side * 0.024, 0.01, -0.08), Vector3(side * 0.022, 0.016, -0.11)], 0.0035, F.LEATHER)
	# The brass cup and the barbs sitting in it.
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), Vector3(0, 0.012, -0.115)), 0.026, 0.018, 0.016, 14, F.BRASS)
	F.hoop(k.m(), Vector3(0, 0.02, -0.115), Vector3(0, 1, 0), 0.026, 0.002, F.BRASS_LIGHT, 14)
	for i in 5:
		var a := TAU * i / 5.0
		var p := Vector3(cos(a) * 0.011, 0.026, -0.115 + sin(a) * 0.011)
		MeshKit.add_cylinder(k.m(), Transform3D(Basis(Vector3.RIGHT, -0.3), p), 0.0005, 0.003, 0.022, 6, F.IRON)
		F.ball(k.g(), p + Vector3(0, 0.012, -0.004), Vector3.ONE * 0.0022, Color("#D9D2C4"), 3, 6)
	# The belt pouch, carried at the front of the grip.
	F.box(k.x(), Vector3(0.0, -0.035, -0.035), Vector3(0.03, 0.03, 0.034), F.LEATHER.darkened(0.15))
	F.box(k.m(), Vector3(0.0, -0.02, -0.018), Vector3(0.01, 0.006, 0.004), F.BRASS)
	var out := _hand_bits(k, Vector3(0.0125, 0.02, -0.02), F.WALNUT_DARK)
	out["body"] = k.commit()
	return out


# ------------------------------------------------------------------ 3 Signal Flare

## A fat brass single-shot break-action flare pistol.
static func _flare() -> Dictionary:
	var k := F.Kit.new()
	var b := F.Kit.new()
	_frame(k, Vector3(0, 0.012, 0.004), Vector3(0.036, 0.052, 0.06))
	F.cx(k.m(), PIVOTS["signal_flare_barrels"], 0.006, 0.04, F.IRON, 10)
	F.cz(b.m(), Vector3(0, 0.03, -0.1), 0.026, 0.028, 0.13, F.BRASS, 18)
	_cone(b, Vector3(0, 0.03, -0.175), 0.028, 0.034, 0.03, F.BRASS_LIGHT)
	F.hoop(b.m(), Vector3(0, 0.03, -0.045), Vector3(0, 0, 1), 0.029, 0.0025, F.BRASS_DARK, 18)
	F.cz(b.x(), Vector3(0, 0.03, -0.19), 0.022, 0.022, 0.002, F.BORE, 16)
	F.box(b.m(), Vector3(0, 0.004, -0.04), Vector3(0.02, 0.02, 0.02), F.BRASS_DARK)
	F.box(k.m(), Vector3(0, 0.045, 0.03), Vector3(0.01, 0.014, 0.012), F.IRON_DARK)
	var out := _hand_bits(k, Vector3(0.0185, 0.018, 0.0))
	out["body"] = k.commit()
	out["barrels"] = b.commit()
	return out


static func _cone(k: F.Kit, c: Vector3, r0: float, r1: float, length: float, col: Color) -> void:
	F.cz(k.m(), c, r1, r0, length, col, 18)


# ------------------------------------------------------------------ 4 Crop Syringe

## A pneumatic brass injector: long needle barrel, pressure chamber on top,
## rear needle cassette, a glass crop vial on the side.
static func _syringe() -> Dictionary:
	var k := F.Kit.new()
	_frame(k, Vector3(0, 0.014, 0.005), Vector3(0.034, 0.054, 0.07))
	F.cz(k.m(), Vector3(0, 0.03, -0.09), 0.016, 0.018, 0.12, F.BRASS, 16)
	F.cz(k.m(), Vector3(0, 0.03, -0.17), 0.007, 0.014, 0.04, F.BRASS_DARK, 12)
	# Pressure chamber with a gauge.
	F.cz(k.m(), Vector3(0, 0.064, -0.06), 0.013, 0.013, 0.1, F.COPPER, 14)
	F.cz(k.m(), Vector3(0, 0.064, -0.112), 0.009, 0.013, 0.006, F.BRASS_DARK, 12)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(), Vector3(0, 0.082, -0.03)), 0.009, 0.009, 0.006, 12, F.BRASS_LIGHT)
	F.ball(k.x(), Vector3(0, 0.0855, -0.03), Vector3(0.007, 0.001, 0.007), F.IVORY, 2, 10)
	# Needle cassette at the rear.
	F.box(k.m(), Vector3(0, 0.05, 0.04), Vector3(0.03, 0.022, 0.03), F.IRON)
	for i in 4:
		F.cz(k.m(), Vector3(-0.009 + i * 0.006, 0.062, 0.04), 0.0018, 0.0018, 0.028, F.STEEL, 6)
	# Glass vial on the left side.
	MeshKit.add_cylinder(k.g(), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.022, 0.03, -0.06)), 0.007, 0.007, 0.05, 10, GLASS)
	F.hoop(k.m(), Vector3(-0.022, 0.03, -0.035), Vector3(0, 0, 1), 0.0075, 0.0015, F.BRASS_DARK, 10)
	var needle := F.Kit.new()
	F.cz(needle.m(), Vector3(0, 0.03, -0.25), 0.0015, 0.004, 0.13, F.STEEL, 8)
	F.cz(needle.g(), Vector3(0, 0.03, -0.318), 0.0004, 0.0015, 0.008, Color("#E8E0D4"), 6)
	var out := _hand_bits(k, Vector3(0.0175, 0.02, -0.002), RUBBER, F.BRASS_DARK)
	out["body"] = k.commit()
	out["shell"] = needle.commit()
	return out


# ------------------------------------------------------------------ 5 Smoke Bellows

## An oversized beekeeper's smoker: brass can, conical lid with a wide spout,
## leather bellows on the side, a fuel chamber with a window at the base.
static func _bellows() -> Dictionary:
	var k := F.Kit.new()
	var bel := F.Kit.new()
	var pl := F.Kit.new()
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, 0.05, -0.08)), 0.042, 0.042, 0.11, 18, F.BRASS)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, 0.1, -0.1)), 0.016, 0.042, 0.04, 18, F.BRASS_LIGHT)
	MeshKit.add_cylinder(k.m(), Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(0, 0.115, -0.14)), 0.02, 0.014, 0.04, 14, F.BRASS_DARK)
	# Fuel chamber window with embers.
	F.box(k.g(), Vector3(0.0, 0.02, -0.11), Vector3(0.03, 0.02, 0.004), Color("#E07A2A"), Basis(Vector3.RIGHT, -0.4))
	F.hoop(k.m(), Vector3(0, 0.02, -0.11), Vector3(0, 0.37, 0.93), 0.043, 0.002, F.IRON_DARK, 18)
	# Leather bellows: two boards hinged at the back, pleats between.
	F.box(bel.w(), Vector3(0, 0.05, 0.0), Vector3(0.05, 0.006, 0.1), F.WALNUT)
	F.box(k.w(), Vector3(0, 0.0, 0.0), Vector3(0.05, 0.006, 0.1), F.WALNUT)
	F.box(pl.x(), Vector3(0, 0.025, 0.0), Vector3(0.046, 0.045, 0.09), F.LEATHER)
	F.cz(k.m(), Vector3(0, 0.02, -0.055), 0.006, 0.006, 0.02, F.IRON, 8)
	var out := _hand_bits(k, Vector3(0.042, 0.06, -0.06))
	out["body"] = k.commit()
	out["bellows"] = bel.commit()
	out["pleats"] = pl.commit()
	return out


# ------------------------------------------------------------------ 6 Bramble Pistol

## A stubby wide-bore brass revolver with a six-shot cylinder of bramble balls.
static func _bramble() -> Dictionary:
	var k := F.Kit.new()
	_frame(k, Vector3(0, 0.012, 0.01), Vector3(0.032, 0.05, 0.05))
	F.cz(k.m(), Vector3(0, 0.03, -0.1), 0.02, 0.021, 0.09, F.BRASS, 16)
	F.hoop(k.m(), Vector3(0, 0.03, -0.146), Vector3(0, 0, 1), 0.021, 0.003, F.BRASS_DARK, 16)
	F.cz(k.x(), Vector3(0, 0.03, -0.147), 0.015, 0.015, 0.002, F.BORE, 14)
	# Cylinder with six balls peeking from the chambers.
	F.cz(k.m(), Vector3(0, 0.03, -0.03), 0.028, 0.028, 0.045, F.BRASS_DARK, 18)
	for i in 6:
		var a := TAU * i / 6.0
		var p := Vector3(cos(a) * 0.017, 0.03 + sin(a) * 0.017, -0.053)
		F.ball(k.x(), p, Vector3.ONE * 0.0075, THORN, 3, 7)
	_spur(k, Vector3(0, 0.05, 0.03))
	var out := _hand_bits(k, Vector3(0.0165, 0.015, 0.012))
	out["body"] = k.commit()
	return out


static func _spur(k: F.Kit, base: Vector3) -> void:
	W.bent(k.m(), [base, base + Vector3(0, 0.012, 0.004), base + Vector3(0, 0.016, 0.014)], 0.004, F.IRON)


# ------------------------------------------------------------------ 7 Spore Launcher

## A short brass lobbing tube with a 3-pod rack on the side, an air chamber
## behind and a pull-lever trigger.
static func _spore() -> Dictionary:
	var k := F.Kit.new()
	var b := F.Kit.new()
	_frame(k, Vector3(0, 0.014, 0.01), Vector3(0.034, 0.05, 0.06))
	F.cz(k.m(), Vector3(0, 0.04, 0.02), 0.02, 0.02, 0.05, F.COPPER, 14)
	F.cz(b.m(), Vector3(0, 0.04, -0.13), 0.032, 0.03, 0.2, F.BRASS, 18)
	F.hoop(b.m(), Vector3(0, 0.04, -0.23), Vector3(0, 0, 1), 0.033, 0.003, F.BRASS_LIGHT, 18)
	F.cz(b.x(), Vector3(0, 0.04, -0.231), 0.026, 0.026, 0.002, F.BORE, 16)
	for z: float in [-0.08, -0.18]:
		F.hoop(b.x(), Vector3(0, 0.04, z), Vector3(0, 0, 1), 0.032, 0.0035, F.LEATHER, 18)
	# Pod rack on the right side.
	F.box(k.m(), Vector3(0.03, 0.03, -0.04), Vector3(0.008, 0.02, 0.09), F.IRON)
	for i in 3:
		F.ball(k.g(), Vector3(0.038, 0.03, -0.01 - i * 0.03), Vector3.ONE * 0.012, POD, 4, 8)
	F.box(k.m(), Vector3(0, -0.012, -0.03), Vector3(0.006, 0.02, 0.012), F.IRON_DARK, Basis(Vector3.RIGHT, 0.3))
	var out := _hand_bits(k, Vector3(0.0175, 0.012, 0.02))
	out["body"] = k.commit()
	out["barrels"] = b.commit()
	return out


# ------------------------------------------------------------------ 8 Venom Needle

## A thin long brass blowgun: mouthpiece at the rear, a slot showing the needle,
## a little iron scope rail, a leather wrap mid-tube.
static func _needle() -> Dictionary:
	var k := F.Kit.new()
	F.cz(k.m(), Vector3(0, 0.03, -0.2), 0.008, 0.009, 0.48, F.BRASS, 12)
	F.cz(k.m(), Vector3(0, 0.03, 0.05), 0.012, 0.009, 0.03, F.BRASS_DARK, 12)
	F.cz(k.m(), Vector3(0, 0.03, -0.44), 0.01, 0.008, 0.012, F.BRASS_LIGHT, 12)
	F.box(k.x(), Vector3(0.0085, 0.03, -0.12), Vector3(0.001, 0.004, 0.05), F.BORE)
	F.box(k.g(), Vector3(0.0086, 0.03, -0.12), Vector3(0.0008, 0.0012, 0.04), Color("#D8DCE0"))
	F.box(k.m(), Vector3(0, 0.041, -0.2), Vector3(0.006, 0.004, 0.08), F.IRON_DARK)
	F.box(k.m(), Vector3(0, 0.012, 0.0), Vector3(0.012, 0.03, 0.02), F.BRASS_DARK)
	var out := _hand_bits(k, Vector3(0.0092, 0.03, -0.3), F.WALNUT_LIGHT)
	# The mid-tube wrap belongs with the grip wrap (dyed the same).
	var gw := F.Kit.new()
	_wrap(gw, GT, GB, 1.05)
	for i in 5:
		F.hoop(gw.x(), Vector3(0, 0.03, -0.17 - i * 0.012), Vector3(0, 0, 1), 0.0095, 0.0025, Color.WHITE, 10)
	out["grip_wrap"] = gw.commit()
	out["body"] = k.commit()
	return out


# ------------------------------------------------------------------ 9 Trip Wire Gun

## A brass and iron anchor gun like a staple gun: anchor magazine on top, a
## wire spool behind a side window, a dual-stage trigger.
static func _wire_gun() -> Dictionary:
	var k := F.Kit.new()
	F.box(k.m(), Vector3(0, 0.02, -0.06), Vector3(0.036, 0.05, 0.17), F.BRASS)
	F.box(k.m(), Vector3(0, 0.05, -0.06), Vector3(0.022, 0.014, 0.15), F.IRON)
	for i in 6:
		F.box(k.m(), Vector3(0, 0.06, -0.12 + i * 0.022), Vector3(0.014, 0.008, 0.006), F.STEEL)
	# Side window showing the spool.
	F.box(k.x(), Vector3(0.0185, 0.02, -0.05), Vector3(0.001, 0.03, 0.05), F.BORE)
	F.cx(k.m(), Vector3(0.012, 0.02, -0.05), 0.013, 0.012, F.COPPER, 14)
	F.cx(k.g(), Vector3(0.0185, 0.02, -0.05), 0.009, 0.001, Color("#C8CCD2"), 12)
	F.box(k.m(), Vector3(0, 0.03, -0.15), Vector3(0.02, 0.02, 0.02), F.IRON_DARK)
	var anchor := F.Kit.new()
	F.cz(anchor.m(), Vector3(0, 0.03, -0.17), 0.0015, 0.005, 0.04, F.IRON, 8)
	var out := _hand_bits(k, Vector3(0.0185, 0.03, -0.02))
	out["body"] = k.commit()
	out["shell"] = anchor.commit()
	return out


# ------------------------------------------------------------------ 10 Spark Pistol

## A compact brass pistol with a copper capacitor coil over the barrel, a copper
## tip, a power cell magazine behind.
static func _spark() -> Dictionary:
	var k := F.Kit.new()
	_frame(k, Vector3(0, 0.012, 0.01), Vector3(0.032, 0.05, 0.06))
	F.cz(k.m(), Vector3(0, 0.026, -0.09), 0.012, 0.014, 0.13, F.BRASS, 14)
	F.cz(k.m(), Vector3(0, 0.026, -0.16), 0.008, 0.012, 0.02, F.COPPER, 12)
	# Coil: copper loops over the barrel.
	for i in 9:
		F.hoop(k.m(), Vector3(0, 0.05, -0.04 - i * 0.011), Vector3(0, 0, 1), 0.012, 0.0022, COIL, 12)
	F.cz(k.g(), Vector3(0, 0.05, -0.084), 0.005, 0.005, 0.1, Color("#BFE2FF"), 8)
	for z: float in [-0.03, -0.14]:
		F.box(k.m(), Vector3(0, 0.038, z), Vector3(0.008, 0.016, 0.006), F.BRASS_DARK)
	# Power cells at the rear.
	F.box(k.m(), Vector3(0, 0.035, 0.035), Vector3(0.026, 0.024, 0.03), F.IRON)
	for i in 3:
		F.cz(k.g(), Vector3(-0.008 + i * 0.008, 0.048, 0.035), 0.003, 0.003, 0.024, Color("#8FD0FF"), 8)
	var out := _hand_bits(k, Vector3(0.0165, 0.015, 0.012), RUBBER, F.BRASS_DARK)
	out["body"] = k.commit()
	return out

class_name ArmoryGuns
extends RefCounted
## The new weapons from the Weapon Slots Redesign (11 primaries, 10 secondaries,
## 8 heavies), built in code from the doc's model prompts instead of fal.ai.
## Models only for now: no WeaponDefs or stats yet (the dev thread wires them).
##
## Same conventions as FrontierGuns, whose kit and helpers they share: real size
## in gun space (barrel along -Z, +Y up, origin in the frame just above the
## trigger, where the trigger hand's fist sits), four material surfaces (metal,
## varnished wood, matte, glow), and every moving part its own mesh hung on a
## pivot so the viewmodel can work it. The builders live in one file per slot:
## ArmoryPrimaries, ArmorySecondaries, ArmoryHeavies, each with
##   static func build(id) -> {"body": mesh, part: mesh, ...}
##   const PIVOTS {"<id>_<part>": Vector3}   where each part turns or slides
##   const MUZZLE {id: Vector3}              where the shot leaves
##   const HANDS {id: [right fist, right grip axis, left fist]}  for the viewmodel later
##   const NAMES {id: "Display Name"}

const PRIMARY := 0
const SECONDARY := 1
const HEAVY := 2


static func ids(slot: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _names(slot):
		out.append(id)
	return out


static func all_ids() -> Array[StringName]:
	return ids(PRIMARY) + ids(SECONDARY) + ids(HEAVY)


static func has(id: StringName) -> bool:
	return slot_of(id) >= 0


## Which slot `id` belongs to (-1: not one of these).
static func slot_of(id: StringName) -> int:
	for s in 3:
		if _names(s).has(id):
			return s
	return -1


static func display_name(id: StringName) -> String:
	return str(_names(slot_of(id)).get(id, String(id).capitalize())) if has(id) else String(id).capitalize()


static func _names(slot: int) -> Dictionary:
	match slot:
		PRIMARY:
			return ArmoryPrimaries.NAMES
		SECONDARY:
			return ArmorySecondaries.NAMES
		HEAVY:
			return ArmoryHeavies.NAMES
	return {}


static func _table(id: StringName, which: String) -> Dictionary:
	match slot_of(id):
		PRIMARY:
			return _const(ArmoryPrimaries, which)
		SECONDARY:
			return _const(ArmorySecondaries, which)
		HEAVY:
			return _const(ArmoryHeavies, which)
	return {}


static func _const(script: Script, which: String) -> Dictionary:
	var c := script.get_script_constant_map()
	return c.get(which, {})


static func muzzle(id: StringName) -> Vector3:
	return _table(id, "MUZZLE").get(id, Vector3(0, 0.02, -0.3))


## [right fist centre, right grip axis, left (support) fist centre] in gun space.
static func hands(id: StringName) -> Array:
	return _table(id, "HANDS").get(id, [])


static func pivot(id: StringName, part: String) -> Vector3:
	return _table(id, "PIVOTS").get("%s_%s" % [id, part], Vector3.ZERO)


# ------------------------------------------------------------------ in the hand

## The gun each new one handles like in first person (Gun and ViewModel: reload
## rhythm, posture, which part cycles, how rounds go in), so every new gun moves
## like a real one without a routine of its own.
const ACTS_LIKE: Dictionary = {
	&"volcanic_repeater": &"lever_rifle", &"mares_leg": &"lever_rifle", &"double_rifle": &"elephant_gun",
	&"trench_broom": &"salt_shotgun", &"ricochet_rifle": &"lever_rifle", &"howdah_pistol": &"flare_gun",
	&"sharps_carbine": &"lever_rifle", &"trapdoor_springfield": &"telescope_rifle",
	&"screamer_pistol": &"flare_gun", &"tar_sprayer": &"bee_smoker", &"flashbang_pistol": &"flare_gun",
	&"pepper_bomb_pistol": &"flare_gun", &"concussion_pistol": &"pepperbox", &"chain_binder": &"harpoon_pistol",
	&"rust_duster": &"bee_smoker", &"glow_worm_launcher": &"flare_gun", &"caltrops_launcher": &"flare_gun",
	&"phosphor_grenade": &"flare_gun",
	&"mortar_tube": &"blunderbuss", &"fire_lance": &"bee_smoker", &"organ_gun": &"crank_gatling",
	&"harpoon_ballista": &"harpoon_pistol", &"acid_drencher": &"bee_smoker", &"swivel_gun": &"punt_gun",
	&"congreve_rocket": &"harpoon_pistol", &"bear_trap_launcher": &"harpoon_pistol",
}
## Parts that are the loaded round (shown only while loaded, like the harpoon's dart).
const LOADED_PARTS: Array[String] = ["shell", "rocket", "trap", "anchor"]


## The older gun `id` handles like (itself when it isn't one of these).
static func acts_like(id: StringName) -> StringName:
	return ACTS_LIKE.get(id, id)


## Held in both hands (the support hand on the gun, not off at the pouch)?
## Long guns and heavies are; pistols cup the right hand.
static func two_handed(id: StringName) -> bool:
	var h := hands(id)
	if h.size() < 3:
		return slot_of(id) == HEAVY
	return slot_of(id) == HEAVY or ((h[2] as Vector3) - (h[0] as Vector3)).length() > 0.13


## Right-click aim: where the gun sits so its sights line up with your eye.
static func aim_pos(id: StringName) -> Vector3:
	var m := muzzle(id)
	if slot_of(id) == HEAVY:
		# Heavies stay braced at the hip and only come in a little (their bulk
		# would fill the view on the eye line).
		return Vector3(0.13, -0.2, -0.46) + rest_offset(id)
	return Vector3(0.0, -(m.y + 0.03), -0.45)


## How the gun sits at rest relative to the standard spot (heavies ride lower and closer).
static func rest_offset(id: StringName) -> Vector3:
	if slot_of(id) == HEAVY:
		return Vector3(0.02, -0.05, 0.08)
	return Vector3.ZERO


## Where rounds go in (gun space): the breech just ahead of the hand for most,
## the muzzle for the mortar.
static func load_point(id: StringName) -> Vector3:
	if id == &"mortar_tube":
		return muzzle(id)
	var m := muzzle(id)
	return Vector3(0.0, m.y, clampf(m.z * 0.18, -0.12, -0.02))


# ------------------------------------------------------------------ meshes

static var _cache: Dictionary = {}


## The meshes of gun `id`: {"body": mesh, part name: mesh, ...}, all in gun space.
static func parts(id: StringName) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var out: Dictionary = {}
	match slot_of(id):
		PRIMARY:
			out = ArmoryPrimaries.build(id)
		SECONDARY:
			out = ArmorySecondaries.build(id)
		HEAVY:
			out = ArmoryHeavies.build(id)
	_cache[id] = out
	return out


## A part mesh hung on a pivot node at its hinge (so turning the node turns it right).
static func part_node(id: StringName, part: String, shadows: bool = false) -> Node3D:
	var mesh: ArrayMesh = parts(id).get(part)
	if mesh == null:
		return null
	var piv := Node3D.new()
	piv.name = part.capitalize()
	piv.position = pivot(id, part)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = -piv.position
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piv.add_child(mi)
	return piv


## The whole gun at rest in one node (hands, the ground, icons, previews).
static func whole(id: StringName, shadows: bool = true) -> Node3D:
	var p := parts(id)
	if p.is_empty():
		return null
	var root := Node3D.new()
	root.name = String(id)
	for part: String in p:
		if part == "body":
			var mi := MeshInstance3D.new()
			mi.mesh = p[part]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
		else:
			root.add_child(part_node(id, part, shadows))
	return root

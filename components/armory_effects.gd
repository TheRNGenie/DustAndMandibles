class_name ArmoryEffects
extends RefCounted
## The new weapons' specials (WeaponDef.special; Weapon Slots Redesign), routed
## to their rules: the secondaries' crowd control (ArmorySecondaryRules) and the
## heavies' (and two primaries') firepower (ArmoryHeavyRules). PlayerNet calls
## these on the host; visuals come back to every peer through PlayerNet.armory_fx.
##   spray   a continuous cone (one puff per shot, like the Bee Smoker): replaces the hitscan
##   impact  once per shot, after the ordinary hitscan, where the first ray stopped
## Impact-only specials (projectiles that burst, lures, traps) deal no direct hit
## damage: the hitscan only finds where they land.

## (The Weapon Slots secondaries are retired and archived, Nov 2026: none left here.)
const SECONDARY: Array[StringName] = []
const HEAVY: Array[StringName] = [&"mortar", &"fire", &"ballista", &"acid", &"rocket", &"beartrap", &"ricochet", &"pierce_line"]
## Continuous cone sprays (each shot is one puff).
const SPRAYS: Array[StringName] = [&"tar", &"rust", &"fire", &"acid"]
## Shots whose hitscan only finds where they land (no direct hit damage).
const NO_DIRECT: Array[StringName] = [&"scream", &"flash", &"pepper", &"lure", &"caltrops", &"phosphor", &"mortar",
	&"rocket", &"beartrap"]


static func handles(special: StringName) -> bool:
	return SECONDARY.has(special) or HEAVY.has(special)


static func is_spray(special: StringName) -> bool:
	return SPRAYS.has(special)


static func skips_direct(special: StringName) -> bool:
	return NO_DIRECT.has(special)


## Host: one puff of a spray gun from `origin` along `dir` (normalised).
static func spray(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, level: int) -> void:
	ArmoryHeavyRules.spray(net, def, origin, dir, level)


## Host: once per shot, after the ordinary hitscan: what happens where the first
## ray stopped. `hit` is that ray's result (empty: it flew to full range and
## `point` is the end of the ray, `normal` zero); `dir` the ray's direction.
static func impact(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, point: Vector3, normal: Vector3,
		hit: Dictionary, level: int) -> void:
	ArmoryHeavyRules.impact(net, def, origin, dir, point, normal, hit, level)


## Every peer: a visual (PlayerNet.armory_fx). `kind` names it; a, b, x are its
## points and number (each kind says what they mean).
static func play_fx(kind: StringName, a: Vector3, b: Vector3, x: float) -> void:
	ArmoryHeavyFx.play(kind, a, b, x)

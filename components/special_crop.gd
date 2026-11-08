class_name SpecialCrop
extends RefCounted
## Special weapons (slot 2, the Nov 2026 special weapons handoff): the one
## permanent crop upgrade a special weapon carries, fitted at the workbench
## behind the homestead (CropBench). It lives in the gun's code (bits 11-14),
## so a dropped, stored or saved gun keeps it. Every shot carries the crop's
## effect on top of the weapon's base effect, at about 70% of turret strength:
##
##   Corn              Ricochet      bounces to a 2nd bug at 35% damage
##   Firecracker Chili Explosive     a small splash, 1.5 m
##   Prickly Pear      Armor Pierce  ignores 35% of a bug's armour
##   Cotton            Slow          -18% speed for 2 s, stacks to -36%
##   Herbs             Poison        damage over 2 s, stacks 2 times
##   Sulfur Root       Volatile      a bug killed goes up: 20% of its max HP
##   Barrel Cactus     Stagger       stops it 0.2 s
##   Tumbleweed Vine   Entangle      10% a hit: rooted 0.7 s
##   Sarsaparilla      Mark          +15% damage from everything for 2 s
##
## The weapon's rarity scales all of it (LEVEL_K). Host-side rules; the names,
## colours and text are for every peer. Reuses the universal turrets' bug
## statuses and tags (CropEffects, BugStatus).

## The crop's place in the code: 0 = none, 1..9 = CropEffects.IDS[n - 1].
const SHIFT := 11
const MASK := 0xF << SHIFT

## The handoff's crop colours (grip wrap, projectile tint, impacts).
const COLORS: Dictionary = {&"corn": Color("#FFD23F"), &"firecracker_chili": Color("#FF5533"),
	&"prickly_pear": Color("#5DAA3E"), &"cotton": Color("#E8E0D4"), &"herbs": Color("#7FAD71"),
	&"sulfur_root": Color("#C4B014"), &"barrel_cactus": Color("#2E8B7A"), &"tumbleweed_vine": Color("#B8965A"),
	&"sarsaparilla": Color("#D4920B")}
## No crop: plain brown leather.
const PLAIN_COLOR := Color("#6B4A2E")

## Crop strength by rarity (WeaponMods.level). The handoff gives Base x1,
## Level 1 x1.15, Level 2 x1.3; Epic and Legendary keep climbing a little but
## stay under turret strength.
const LEVEL_K: Array[float] = [1.0, 1.15, 1.3, 1.35, 1.4]

const RICOCHET_SHARE := 0.35
const RICOCHET_RANGE := 6.0
const SPLASH_RADIUS := 1.5
## Share of the hit's damage the chili splash deals (turrets: 0.35).
const SPLASH_SHARE := 0.25
const PIERCE_SHARE := 0.35
const SLOW_STEP := 0.18
const SLOW_MAX := 0.36
const SLOW_TIME := 2.0
const POISON_TIME := 2.0
const POISON_STACKS := 2
## Each poison stack deals this share of the hit's damage over POISON_TIME (turrets: 0.4).
const POISON_SHARE := 0.28
## Sulfur: 20% of max HP (CropEffects.VOLATILE_SHARE is 30%, so k = 2/3).
const VOLATILE_K := 0.2 / 0.3
const VOLATILE_TIME := 4.0
const STAGGER := 0.2
const ENTANGLE_CHANCE := 0.1
const ENTANGLE_TIME := 0.7
const MARK_BONUS := 0.15
const MARK_TIME := 2.0


static func crop_of(code: int) -> StringName:
	var n := (code & MASK) >> SHIFT
	return CropEffects.IDS[n - 1] if n >= 1 and n <= CropEffects.IDS.size() else &""


## `code` with its crop set to `crop` (&"" removes it), everything else kept.
static func with_crop(code: int, crop: StringName) -> int:
	var n := CropEffects.IDS.find(crop) + 1
	return (code & ~MASK) | ((n & 0xF) << SHIFT)


static func color_of(crop: StringName) -> Color:
	return COLORS.get(crop, PLAIN_COLOR)


## A projectile's tint: a hint of the crop over `base`, lighter than a heavy's.
static func tint(base: Color, crop: StringName) -> Color:
	return base if crop == &"" else base.lerp(color_of(crop), 0.45)


## Crop strength for a gun of this code (its rarity).
static func level_k(code: int) -> float:
	return LEVEL_K[clampi(WeaponMods.level(code), 0, LEVEL_K.size() - 1)]


## Share of armour a hit ignores (Prickly Pear), 0 otherwise.
static func armour_ignored(crop: StringName, k: float) -> float:
	return minf(PIERCE_SHARE * k, 0.9) if crop == &"prickly_pear" else 0.0


## "Corn - Ricochet: bounces to a second bug at 35% damage." at strength `k`.
static func preview(crop: StringName, k: float = 1.0) -> String:
	if crop == &"":
		return "No crop: plain shots."
	return "%s - %s: %s" % [CropEffects.short_name(crop), CropEffects.effect_name(crop), effect_text(crop, k)]


static func effect_text(crop: StringName, k: float = 1.0) -> String:
	match crop:
		&"corn":
			return "bounces to a second bug at %d%% damage." % roundi(RICOCHET_SHARE * k * 100.0)
		&"firecracker_chili":
			return "a small splash round each hit (%s m)." % String.num(SPLASH_RADIUS * sqrt(k), 1)
		&"prickly_pear":
			return "ignores %d%% of a bug's armour." % roundi(minf(PIERCE_SHARE * k, 0.9) * 100.0)
		&"cotton":
			return "-%d%% speed for %d s, stacking to -%d%%." % [roundi(SLOW_STEP * k * 100.0), int(SLOW_TIME), roundi(minf(SLOW_MAX * k, 0.8) * 100.0)]
		&"herbs":
			return "poison over %d s, stacking %d times." % [int(POISON_TIME), POISON_STACKS]
		&"sulfur_root":
			return "a bug it hits blows up when it dies (%d%% of its health)." % roundi(0.2 * k * 100.0)
		&"barrel_cactus":
			return "staggers the bug for %s s." % String.num(STAGGER * k, 2)
		&"tumbleweed_vine":
			return "%d%% chance a hit to root it for %s s." % [roundi(ENTANGLE_CHANCE * k * 100.0), String.num(ENTANGLE_TIME * k, 1)]
		&"sarsaparilla":
			return "marked bugs take +%d%% damage from everything for %d s." % [roundi(MARK_BONUS * k * 100.0), int(MARK_TIME)]
	return ""


## Host: what a special weapon's hit does on top of its damage, by crop. `k` is
## the strength (level_k, times any weapon's own boost: the Venom Needle's 2x).
## `damage` is the hit's damage (shares are taken of it). Returns the
## ricochet's end point (Vector3.INF if none) for the caller to draw.
static func on_hit(crop: StringName, target: Bug, damage: float, point: Vector3, k: float, source: String, cliff: int, t: float = 1.0) -> Vector3:
	if crop == &"" or target == null or not is_instance_valid(target):
		return Vector3.INF
	match crop:
		&"corn":
			var other := nearest_other(target, point, RICOCHET_RANGE)
			if other != null:
				other.receive_hit(damage * RICOCHET_SHARE * k, other.global_position, (other.global_position - point).normalized(),
						false, 1.0, source, cliff)
				return other.global_position
		&"firecracker_chili":
			var r := SPLASH_RADIUS * sqrt(k)
			for b: Bug in bugs_near(target, point, r):
				var d := b.global_position.distance_to(point)
				b.receive_hit(damage * SPLASH_SHARE * k * lerpf(1.0, 0.5, d / maxf(r, 0.01)), b.global_position,
						(b.global_position - point).normalized(), true, 1.0, source, cliff)
			if Turret.bug_manager != null:
				Turret.bug_manager.crop_burst.rpc(point, r, COLORS[crop])
		_:
			apply_status(crop, target, damage, k, source, cliff, t)
	return Vector3.INF


## Host: the crops that only change the bug itself (no damage of their own to
## other bugs), for effects that tick or spread without a hit: clouds, wires,
## the Syringe's carrier. Corn and Chili do nothing here.
## `t` stretches the effect's duration (the "linger" mods).
static func apply_status(crop: StringName, target: Bug, damage: float, k: float, source: String, cliff: int, t: float = 1.0) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	match crop:
		&"cotton":
			target.status.crop_slow(SLOW_STEP * k, minf(SLOW_MAX * k, 0.8), SLOW_TIME * t)
			target.crop_tag_once(CropEffects.TAG_THREAD, SLOW_TIME * t)
		&"herbs":
			target.status.poison(maxf(damage, 1.0) * POISON_SHARE * k / POISON_TIME, POISON_TIME * t, POISON_STACKS, source, cliff)
			target.crop_tag_once(CropEffects.TAG_POISON, POISON_TIME * t)
		&"sulfur_root":
			target.status.volatile(VOLATILE_TIME * t, VOLATILE_K * k, source, cliff)
		&"barrel_cactus":
			target.status.stun(STAGGER * k * t)
			target.crop_tag_once(CropEffects.TAG_STAGGER, STAGGER * k * t)
		&"tumbleweed_vine":
			if randf() < ENTANGLE_CHANCE * k:
				target.status.root(ENTANGLE_TIME * k * t)
				target.crop_tag_once(CropEffects.TAG_VINES, ENTANGLE_TIME * k * t)
		&"sarsaparilla":
			target.status.crop_mark(MARK_TIME * t, MARK_BONUS * k)
			target.crop_tag_once(CropEffects.TAG_MARK, MARK_TIME * t)


## The live bugs within `r` of `at` on the same side as `near` (the same cliff,
## and climbing or not alike), `near` itself left out.
static func bugs_near(near: Bug, at: Vector3, r: float) -> Array[Bug]:
	var out: Array[Bug] = []
	if near == null or not is_instance_valid(near) or near.get_tree() == null:
		return out
	var climbing := near.is_climbing()
	for n: Node in near.get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or b == near or not b.is_alive() or b.is_hidden() or b.cliff_id != near.cliff_id:
			continue
		if climbing != b.is_climbing() and b.state != Bug.State.FLYING:
			continue
		if b.global_position.distance_to(at) <= r:
			out.append(b)
	return out


static func nearest_other(near: Bug, at: Vector3, r: float) -> Bug:
	var best: Bug = null
	var best_d := r
	for b: Bug in bugs_near(near, at, r):
		var d := b.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = b
	return best

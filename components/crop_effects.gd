class_name CropEffects
extends RefCounted
## The nine crops a universal crop-fed turret can be loaded with (the Nov 2026
## turret handoff), and what each does on every hit. One burlap sack (the crop's
## CropDef.load_item) loads a turret for one wave. Host-side rules; the colours
## and names are for every peer.
##
##   Corn              Ricochet      the shot bounces to a 2nd bug at 50% damage
##   Firecracker Chili Explosive     a small splash round each hit (1.5-3 m by gun)
##   Prickly Pear      Armor Pierce  ignores half a bug's armour
##   Cotton            Slow          -25% speed for 2 s, stacks to -50%
##   Herbs             Poison        damage over 3 s, stacks 3 times
##   Sulfur Root       Volatile      a bug killed goes up: 30% of its max HP within 2 m
##   Barrel Cactus     Stagger       stops it 0.3 s (heavy guns 0.5 s)
##   Tumbleweed Vine   Entangle      15% a hit: rooted 1 s
##   Sarsaparilla      Mark          +20% damage from everything for 3 s
##
## Upgrade tiers scale the strength of each effect (TurretDef.UNI_EFFECT: x1,
## x1.25, x1.5): shares, durations and chances.

const IDS: Array[StringName] = [&"corn", &"firecracker_chili", &"prickly_pear", &"cotton", &"herbs",
	&"sulfur_root", &"barrel_cactus", &"tumbleweed_vine", &"sarsaparilla"]

const EFFECTS: Dictionary = {&"corn": "Ricochet", &"firecracker_chili": "Explosive", &"prickly_pear": "Armor Pierce",
	&"cotton": "Slow", &"herbs": "Poison", &"sulfur_root": "Volatile", &"barrel_cactus": "Stagger",
	&"tumbleweed_vine": "Entangle", &"sarsaparilla": "Mark"}

## Each crop's colour on a loaded turret: barrel glow, base ring, shots, impacts.
const COLORS: Dictionary = {&"corn": Color("#FFD700"), &"firecracker_chili": Color("#FF4500"),
	&"prickly_pear": Color("#008B8B"), &"cotton": Color("#FFFDD0"), &"herbs": Color("#228B22"),
	&"sulfur_root": Color("#CCCC00"), &"barrel_cactus": Color("#556B2F"), &"tumbleweed_vine": Color("#D2B48C"),
	&"sarsaparilla": Color("#FFBF00")}
## An empty turret's base ring.
const EMPTY_COLOR := Color("#808080")

## Short names for the card and the wheel ("Chili" not "Firecracker Chili").
const SHORT: Dictionary = {&"corn": "Corn", &"firecracker_chili": "Chili", &"prickly_pear": "Prickly Pear",
	&"cotton": "Cotton", &"herbs": "Herbs", &"sulfur_root": "Sulfur Root", &"barrel_cactus": "Barrel Cactus",
	&"tumbleweed_vine": "Tumbleweed", &"sarsaparilla": "Sarsaparilla"}

const RICOCHET_SHARE := 0.5
const RICOCHET_RANGE := 6.0
const EXPLOSIVE_SHARE := 0.35
const PIERCE_SHARE := 0.5
const SLOW_STEP := 0.25
const SLOW_MAX := 0.5
const SLOW_TIME := 2.0
const POISON_TIME := 3.0
const POISON_STACKS := 3
## Each poison stack deals this share of the hit's damage over POISON_TIME.
const POISON_SHARE := 0.4
const VOLATILE_SHARE := 0.3
const VOLATILE_RADIUS := 2.0
## A sulfur-hit bug stays volatile this long after the hit.
const VOLATILE_TIME := 4.0
const STAGGER := 0.3
const STAGGER_HEAVY := 0.5
const ENTANGLE_CHANCE := 0.15
const ENTANGLE_TIME := 1.0
const MARK_BONUS := 0.2
const MARK_TIME := 3.0

## Bug.crop_tag kinds (every peer draws them).
const TAG_MARK := 0
const TAG_VINES := 1
const TAG_POISON := 2
const TAG_THREAD := 3
const TAG_STAGGER := 4


static func is_crop(id: StringName) -> bool:
	return IDS.has(id)


## The sack that loads a turret with `crop` (&"corn_load").
static func sack_of(crop: StringName) -> StringName:
	var c := Defs.crop(crop) if Defs.CROPS.has(crop) else null
	return c.load_item if c != null else &""


static func effect_name(crop: StringName) -> String:
	return str(EFFECTS.get(crop, ""))


static func short_name(crop: StringName) -> String:
	return str(SHORT.get(crop, String(crop).capitalize()))


static func color_of(crop: StringName) -> Color:
	return COLORS.get(crop, EMPTY_COLOR)


## Effect strength at a universal upgrade tier (0-2).
static func strength(tier: int) -> float:
	return TurretDef.UNI_EFFECT[clampi(tier, 0, 2)]


## Share of a bug's armour a hit ignores (Prickly Pear), 0 otherwise.
static func armour_ignored(crop: StringName, tier: int) -> float:
	return minf(PIERCE_SHARE * strength(tier), 0.9) if crop == &"prickly_pear" else 0.0


## Entangle's chance a hit (Tumbleweed Vine).
static func entangle_chance(tier: int) -> float:
	return ENTANGLE_CHANCE * strength(tier)


## Stagger time for a gun (Barrel Cactus).
static func stagger_time(heavy_gun: bool, tier: int) -> float:
	return (STAGGER_HEAVY if heavy_gun else STAGGER) * strength(tier)


## Cotton: the speed taken off per hit, and the most it stacks to.
static func slow_step(tier: int) -> float:
	return SLOW_STEP * strength(tier)


static func slow_max(tier: int) -> float:
	return minf(SLOW_MAX * strength(tier), 0.8)


## Herbs: poison damage per second for one stack from a hit of `damage`.
static func poison_dps(damage: float, tier: int) -> float:
	return damage * POISON_SHARE * strength(tier) / POISON_TIME


## Sarsaparilla: the extra damage a marked bug takes.
static func mark_bonus(tier: int) -> float:
	return MARK_BONUS * strength(tier)


## Sulfur: the blast from a volatile bug's death (a share of its max HP).
static func volatile_damage(max_hp: float, k: float) -> float:
	return max_hp * VOLATILE_SHARE * k


## Host: what a universal turret's hit does on top of its damage, by crop.
## `t` is the turret (for its def, tier, owner and cliff); `point` where it hit.
## Returns the ricochet's end point (Vector3.INF if none) for the turret to draw.
static func on_hit(crop: StringName, t: Turret, target: Bug, damage: float, point: Vector3, source: String) -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.INF
	var tier := t.tier
	var k := strength(tier)
	match crop:
		&"corn":
			var other := _nearest_other(t, target, point, RICOCHET_RANGE)
			if other != null:
				other.receive_hit(damage * RICOCHET_SHARE * k, other.global_position, (other.global_position - point).normalized(),
						t.def.armor_pierce, 1.0, source, t.cliff_id)
				return other.global_position
		&"firecracker_chili":
			var r := t.def.crop_splash
			for b: Bug in _bugs_near(t, point, r, target):
				var d := b.global_position.distance_to(point)
				b.receive_hit(damage * EXPLOSIVE_SHARE * k * lerpf(1.0, 0.5, d / maxf(r, 0.01)), b.global_position,
						(b.global_position - point).normalized(), true, 1.0, source, t.cliff_id)
		&"cotton":
			if target.is_alive():
				target.status.crop_slow(slow_step(tier), slow_max(tier), SLOW_TIME)
				target.crop_tag_once(TAG_THREAD, SLOW_TIME)
		&"herbs":
			if target.is_alive():
				target.status.poison(poison_dps(damage, tier), POISON_TIME, POISON_STACKS, source, t.cliff_id)
				target.crop_tag_once(TAG_POISON, POISON_TIME)
		&"sulfur_root":
			if target.is_alive():
				target.status.volatile(VOLATILE_TIME, k, source, t.cliff_id)
		&"barrel_cactus":
			if target.is_alive():
				var s := stagger_time(t.def.heavy_gun, tier)
				target.status.stun(s)
				target.crop_tag_once(TAG_STAGGER, s)
		&"tumbleweed_vine":
			if target.is_alive() and randf() < entangle_chance(tier):
				target.status.root(ENTANGLE_TIME * k)
				target.crop_tag_once(TAG_VINES, ENTANGLE_TIME * k)
		&"sarsaparilla":
			if target.is_alive():
				target.status.crop_mark(MARK_TIME, mark_bonus(tier))
				target.crop_tag_once(TAG_MARK, MARK_TIME)
	return Vector3.INF


## Host: a volatile bug (Sulfur Root) died: it goes up, hurting bugs near it.
static func volatile_burst(b: Bug) -> void:
	var st := b.status
	var dmg := volatile_damage(b.def.max_hp, st.volatile_k())
	var at := b.global_position
	for n: Node in b.get_tree().get_nodes_in_group("bugs"):
		var o := n as Bug
		if o == null or o == b or not o.is_alive() or o.is_hidden():
			continue
		var d := o.global_position.distance_to(at)
		if d <= VOLATILE_RADIUS:
			o.receive_hit(dmg * lerpf(1.0, 0.6, d / VOLATILE_RADIUS), o.global_position, (o.global_position - at).normalized(),
					true, 1.0, st.volatile_source(), st.volatile_cliff())
	if Turret.bug_manager != null:
		Turret.bug_manager.crop_burst.rpc(at, VOLATILE_RADIUS, COLORS[&"sulfur_root"])


## The live bugs within `r` of `at` (not `skip`) that a turret on `t`'s side may hit:
## climbers on the same wall as the target, or bugs on the same ground.
static func _bugs_near(t: Turret, at: Vector3, r: float, skip: Bug) -> Array[Bug]:
	var out: Array[Bug] = []
	if t.get_tree() == null:
		return out
	var climbing := skip != null and is_instance_valid(skip) and skip.is_climbing()
	var cliff := skip.cliff_id if skip != null and is_instance_valid(skip) else -1
	for n: Node in t.get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or b == skip or not b.is_alive() or b.is_hidden():
			continue
		if cliff >= 0 and b.cliff_id != cliff:
			continue
		if climbing != b.is_climbing() and not (b.state == Bug.State.FLYING and t.def.anti_air):
			continue
		if b.global_position.distance_to(at) <= r:
			out.append(b)
	return out


static func _nearest_other(t: Turret, target: Bug, at: Vector3, r: float) -> Bug:
	var best: Bug = null
	var best_d := r
	for b: Bug in _bugs_near(t, at, r, target):
		var d := b.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = b
	return best

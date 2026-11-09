class_name TurretDef
extends Resource
## One turret type. Turrets sit on your own cliff edge and only fire at the far cliff.

enum Effect { HITSCAN, KNOCKBACK, BURN, SPLASH, PIN }

## Upgrade tiers 0 (as built), 1 (brass fittings) and 2 (big bore).
const MAX_TIER := 2
## Per tier: damage, range and hit-point multipliers, and the fire-interval multiplier.
const TIER_DAMAGE: Array[float] = [1.0, 1.3, 1.7]
const TIER_RANGE: Array[float] = [1.0, 1.1, 1.2]
const TIER_HP: Array[float] = [1.0, 1.2, 1.4]
const TIER_INTERVAL: Array[float] = [1.0, 0.9, 0.8]
## Names shown for each upgrade tier.
const TIER_NAMES: Array[String] = ["Stock", "Brass fittings", "Big bore"]
## Extra range per scaffold level the turret stands on (5% each).
const RANGE_PER_LEVEL := 0.05
## Bugs with this much HP (or any armour plate) count as heavy.
const HEAVY_HP := 100.0

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
## The one job this turret is for, a few words for the build catalog.
@export var role: String = ""
## What it is bad at, a few words for the build catalog.
@export var weakness: String = ""
@export var cost_scrap: int = 40
@export var max_hp: float = 150.0
@export var range: float = 80.0
## Seconds between shots.
@export var fire_interval: float = 0.15
@export var damage: float = 6.0
@export var armor_pierce: bool = false
## Damage multiplier against heavy bugs (armour-plated, or 100+ HP): below 1 for
## swarm guns, above 1 for big-game guns.
@export var heavy_mult: float = 1.0
## Furthest the barrel can aim below horizontal, in degrees.
@export var pitch_limit_deg: float = 30.0
## Degrees per second.
@export var turn_speed: float = 180.0
## Random aim error in degrees (cosmetic tracer spread; hits are rolled with hit_chance).
@export var spread_deg: float = 1.5
@export var hit_chance: float = 0.85
## What a hit does: plain damage, knock off the cliff, burning patch, splash, or pin in place.
@export var effect: Effect = Effect.HITSCAN
## Lobbed shots (mortar, dynamite) travel this long; 0 = instant hitscan.
@export var flight_time: float = 0.0
## Radius of splash / burning patch, or pin duration in seconds for PIN.
@export var effect_size: float = 0.0
## Last-line turret: shoots only bugs that made it onto YOUR plateau (breachers,
## surfaced ticks, bandits overhead), never anything on a cliff face.
@export var guards_plateau: bool = false
## House turret: mounts on the Homestead (porch, balcony, roof deck) and only shoots
## bugs on your plateau within Homestead.GUARD_RADIUS of the house.
@export var guards_house: bool = false
## Upkeep: resources spent per shot from the owner's stockpile, e.g. {&"chili": 1}.
## Only special turrets have any; the basic ones never need ammo.
@export var ammo_cost: Dictionary = {}
## Air defence: sits in the second row from the lip and only shoots flying bugs,
## over either plateau or the canyon.
@export var anti_air: bool = false
## An anti-air turret with this above 0 also shoots climbers on the cliff it
## covers, at this share of its damage (fliers still come first).
@export var ground_mult: float = 0.0
## Shot sound (audio/sfx name). "gatling" picks one of three variants.
@export var sound: StringName = &"gatling"
# Crewed: a 2 x 2 crewed gun (scenes/turrets/crewed_turret.gd): E takes the seat
# and you aim and fire it yourself; left alone it fires at half rate and damage.
@export var crewed: bool = false
## Crewed: how far the gun traverses either side of straight across, in degrees.
@export var crew_yaw_arc_deg: float = 75.0
## Crewed: how far the barrel may lift above horizontal while manned, in degrees.
@export var crew_pitch_up_deg: float = 35.0
## Special shot for the newer control / area / pin turrets (TurretEffects):
## &"steam" a scalding cone that knocks the highest few climbers off and slows the
## rest, &"flood" a flood down a lane-wide band of the far wall, &"twin" a fire
## shell and a blast shell together, &"bola" bolas that tangle several bugs.
## Empty: the shot does just what `effect` says. (Field shared with the tier
## specials below: chain / pierce / spike.)

# ---- Tech tiers: Early / Mid / Late (see UNLOCK_WAVES) ----
## Tech tier: 0 Early (from the start), 1 Mid, 2 Late. Mid and Late turrets stay
## locked in the build menu until the wave in UNLOCK_WAVES. Not the upgrade tier
## (Stock / Brass Fittings / Big Bore), which every turret still has on top.
@export_range(0, 2) var tier: int = 0
## Extra on-hit behaviour on top of `effect` (see TurretEffects): &"" none,
## SPECIAL_CHAIN ricochets between bugs close together, SPECIAL_PIERCE carries
## on through bugs in the line of fire, SPECIAL_SPIKE skewers every climber in
## a line down the wall and pins the last one.
@export var special: StringName = &""
## Chain: bounces after the first hit. Pierce: bugs it carries on into after the target.
## Steam: most climbers one blast knocks off. Bola: bugs one throw tangles.
@export var special_count: int = 0
## Chain: hop reach in metres. Pierce / spike: how close to the line a bug must be.
@export var special_radius: float = 0.0
## Damage kept on each bounce or each bug passed through (0.6 = 60%).
@export var special_falloff: float = 1.0
## Spike: seconds the last bug skewered is pinned to the rock.
@export var special_pin: float = 0.0
## House turret that covers the whole yard (your plateau), not just near the house.
@export var yard_wide: bool = false
## Turret ammo (farming redesign): the crop that feeds it (a CropDef id, e.g.
## &"corn"). Empty: self-powered, always fires. Set: crop-fed, fires only while
## loaded, and one load (that crop's CropDef.load_item) lasts one wave.
@export var crop_type: StringName = &""

# ---- Universal crop-fed turrets (Nov 2026 handoff, UniversalTurret) ----
## Universal crop-fed: takes any of the nine crop sacks (CropEffects), and the
## crop sets what every hit does. One sack lasts one wave. Uses its own upgrade
## tiers (UNI_*), bought at waves 5 and 10.
@export var universal: bool = false
## Cliff turrets: the whole width of the aiming cone in degrees (15 precise,
## 30 balanced, 45 wide). 0 = the standard cone (Targeting.AIM_HALF_DEG each side).
@export var cone_deg: float = 0.0
## Universal: its job on the turret card: "H" horde, "ST" single target,
## "CC" crowd control, "Hybrid".
@export var job: String = ""
## Universal: Firecracker Chili's splash radius on this gun's hits (1.5 to 3 m).
@export var crop_splash: float = 2.0
## Universal: a heavy gun (Barrel Cactus staggers for 0.5 s instead of 0.3).
@export var heavy_gun: bool = false
## Universal: shots in a burst and the pause after it (Thresher Post); 0 = steady.
@export var burst: int = 0
@export var burst_pause: float = 0.0
## Universal hybrids: the heavy mode's damage and interval (Frontier Sentinel,
## Skyward Battery): it switches when the target is heavy. 0 = one mode.
@export var heavy_damage: float = 0.0
@export var heavy_interval: float = 0.0
## Universal obstruction: placed on the ground, inert until loaded, goes off once
## and is gone (UniversalObstruction). Not repaired or reloaded.
@export var obstruction: bool = false
const SPECIAL_CHAIN := &"chain"
const SPECIAL_PIERCE := &"pierce"
const SPECIAL_SPIKE := &"spike"
## Hive amber turrets (AmberTurret, AmberRules).
const SPECIAL_KILN := &"kiln"
const SPECIAL_BELL := &"bell"
const SPECIAL_LANCE := &"lance"
## Universal upgrade tiers (Tier 1 as built, Tier 2 from wave 5, Tier 3 from
## wave 10): damage and fire-rate multipliers, crop-effect strength, the build
## price multiplier, and the share of the next tier's price an upgrade costs.
const UNI_DAMAGE: Array[float] = [1.0, 1.4, 2.0]
const UNI_RATE: Array[float] = [1.0, 1.15, 1.3]
const UNI_EFFECT: Array[float] = [1.0, 1.25, 1.5]
const UNI_COST: Array[float] = [1.0, 1.8, 3.0]
const UNI_UPGRADE_SHARE := 0.85
const UNI_TIER_WAVES: Array[int] = [1, 5, 10]
const UNI_TIER_NAMES: Array[String] = ["Tier 1", "Tier 2", "Tier 3"]
## Tech tier names, for the build menu's tag chips.
const ERA_NAMES: Array[String] = ["Early", "Mid", "Late"]
## The wave each tech tier unlocks at (Early from the start). The one place to change it.
const UNLOCK_WAVES: Array[int] = [1, 5, 10]


## The wave this turret unlocks at.
func unlock_wave() -> int:
	return UNLOCK_WAVES[clampi(tier, 0, UNLOCK_WAVES.size() - 1)]


## Can it be built on `wave`?
func unlocked_on(wave: int) -> bool:
	return wave >= unlock_wave()


## "Early", "Mid" or "Late".
func era_name() -> String:
	return ERA_NAMES[clampi(tier, 0, ERA_NAMES.size() - 1)]


## Armour-plated or 100+ HP: the bugs big-game guns are for and swarm guns struggle with.
static func is_heavy(bd: BugDef) -> bool:
	return bd.front_armor > 0.0 or bd.max_hp >= HEAVY_HP


## Crop-fed: needs a load of its crop each wave to fire (universal: any crop).
func is_crop_fed() -> bool:
	return crop_type != &"" or universal


## Universal: the scrap an upgrade to tier `to` (1 or 2) costs: 85% of what a
## turret of that tier costs to build.
func uni_upgrade_cost(to: int) -> int:
	return int(roundf(cost_scrap * UNI_COST[clampi(to, 0, 2)] * UNI_UPGRADE_SHARE))


## The standard aiming cone's half-width (Targeting.AIM_HALF_DEG: not named
## here, because Targeting -> Defs -> the turret .tres files -> this script would
## be a load cycle).
const STANDARD_HALF_DEG := 15.0


## Universal: half the aiming cone, in degrees (the standard cone when unset).
func aim_half_deg() -> float:
	return cone_deg * 0.5 if cone_deg > 0.0 else STANDARD_HALF_DEG


## The load item that arms it (&"corn_load"), or &"" for self-powered turrets.
func load_item() -> StringName:
	if crop_type == &"":
		return &""
	var c := crop_def()
	return c.load_item if c != null else &""


## "Corn": the crop that loads it, for prompts and the build menu.
func crop_name() -> String:
	var c := crop_def()
	return c.display_name if c != null else ""


## The crop that feeds it. (Loaded by path, not through Defs: Defs preloads every
## turret, so naming it here would be a load cycle.)
func crop_def() -> CropDef:
	if crop_type == &"":
		return null
	var path := "res://data/crops/%s.tres" % crop_type
	return load(path) as CropDef if ResourceLoader.exists(path) else null


## Needs upkeep (ammo) to keep firing.
func has_upkeep() -> bool:
	return not ammo_cost.is_empty()


## "1 chili" / "1 chitin" (the team pot, ResNames) per shot, for prompts and the catalog.
func upkeep_text() -> String:
	var parts: PackedStringArray = []
	for k: Variant in ammo_cost.keys():
		parts.append("%d %s" % [int(ammo_cost[k]), ResNames.of(StringName(k))])
	return ", ".join(parts)


## Damage of one shot at an upgrade tier, against a heavy bug or not.
func damage_at(upgrade: int, heavy: bool = false) -> float:
	if universal:
		return damage * UNI_DAMAGE[clampi(upgrade, 0, 2)] * (heavy_mult if heavy else 1.0)
	return damage * TIER_DAMAGE[clampi(upgrade, 0, MAX_TIER)] * (heavy_mult if heavy else 1.0)


## Range at an upgrade tier, standing on `level` scaffold levels.
func range_at(upgrade: int, level: int = 0) -> float:
	return range * range_mult(upgrade, level)


static func range_mult(upgrade: int, level: int) -> float:
	return TIER_RANGE[clampi(upgrade, 0, MAX_TIER)] + RANGE_PER_LEVEL * maxi(level - 1, 0) # (the bottom deck gets no scaffold bonus, Logan)


func interval_at(upgrade: int) -> float:
	if universal:
		return fire_interval / UNI_RATE[clampi(upgrade, 0, 2)]
	return fire_interval * TIER_INTERVAL[clampi(upgrade, 0, MAX_TIER)]


func hp_at(upgrade: int) -> float:
	return max_hp * TIER_HP[clampi(upgrade, 0, MAX_TIER)]


## One line for the build catalog's detail strip: job, weakness and any upkeep.
func role_line() -> String:
	var parts: PackedStringArray = []
	if role != "":
		parts.append("Job: %s" % role)
	if weakness != "":
		parts.append("Weak: %s" % weakness)
	if has_upkeep():
		parts.append("Upkeep: %s a shot" % upkeep_text())
	if universal and obstruction:
		parts.append("Any crop: 1 sack, goes off once")
	elif universal:
		parts.append("Any crop: 1 sack a wave")
	elif is_crop_fed():
		parts.append("Crop-fed: 1 %s load a wave" % crop_name().to_lower())
	return "   ·   ".join(parts)


## The key numbers in one line, like a gun's (build menu, workshop, field guide):
## "Damage 6  ·  6.7 Shots/s  ·  Range 80 m  ·  Splash 3 m".
func stat_line(upgrade: int = 0) -> String:
	var dmg := damage_at(upgrade)
	var parts: PackedStringArray = ["Damage %s" % _num(dmg)]
	var every := interval_at(upgrade)
	if special == SPECIAL_LANCE: # Hive amber: one continuous beam
		parts[0] = "Beam %s Damage/s" % _num(dmg)
	elif special == SPECIAL_BELL:
		parts.append("Tolls Every %s s" % _num(every))
	else:
		parts.append(rate_text(upgrade))
	parts.append("Range %d m" % int(roundf(range_at(upgrade))))
	parts.append_array(special_parts(upgrade))
	return "  ·  ".join(parts)


## "9.1 Shots/s", or "1 Shot / 1.6 s" for the slow ones.
func rate_text(upgrade: int = 0) -> String:
	var every := interval_at(upgrade)
	return ("%s Shots/s" % _num(1.0 / every)) if every < 1.0 else ("1 Shot / %s s" % _num(every))


## Everything past damage, rate and range: what it does besides hitting (the
## stat chart's Special Characteristics). `with_cone` false leaves out the
## aiming cone, for when the chart shows it on its own.
func special_parts(_upgrade: int = 0, with_cone: bool = true) -> PackedStringArray:
	var parts: PackedStringArray = []
	match special:
		SPECIAL_KILN: parts.append("Entombs Bugs Below Half HP")
		SPECIAL_BELL: parts.append("Bugs Turn on Each Other %s s, Fliers Drop" % _num(effect_size))
		SPECIAL_LANCE: parts.append("Pierces Everything, Burning Trail, Overheats in 8 s")
	match special:
		&"steam": parts.append("Steam Cone: Knocks %d Off, Slows the Rest" % special_count)
		&"flood": parts.append("Floods a %s m Lane" % _num(effect_size))
		&"twin": parts.append("Fire + Blast %s m" % _num(effect_size))
		&"bola": parts.append("Tangles %d Bugs %s s" % [special_count, _num(effect_size)])
	match effect if not special in [&"steam", &"flood", &"twin", &"bola", SPECIAL_BELL, SPECIAL_LANCE] else -1:
		Effect.KNOCKBACK: parts.append("Knocks Bugs Off")
		Effect.BURN: parts.append("Burning Patch %s m" % _num(effect_size))
		Effect.SPLASH: parts.append("Splash %s m" % _num(effect_size))
		Effect.PIN: parts.append("Pins %s s" % _num(effect_size))
	match special:
		SPECIAL_CHAIN: parts.append("Ricochets to %d More" % special_count)
		SPECIAL_PIERCE: parts.append("Pierces %d Bugs" % special_count)
		SPECIAL_SPIKE: parts.append("Skewers a Line, Pins %s s" % _num(special_pin))
	if armor_pierce:
		parts.append("Pierces Armour")
	if not is_equal_approx(heavy_mult, 1.0):
		parts.append("x%s vs Heavy" % _num(heavy_mult))
	if anti_air and ground_mult > 0.0:
		parts.append("Fliers First, Climbers x%s" % _num(ground_mult))
	elif anti_air:
		parts.append("Fliers Only")
	if yard_wide:
		parts.append("Whole Yard")
	if with_cone and cone_deg > 0.0 and not anti_air:
		parts.append("%d° Cone" % int(cone_deg))
	return parts


## 6, 6.5, 0.3: whole numbers plain, the rest to one decimal.
static func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return ("%.2f" % v).trim_suffix("0") if v < 1.0 else "%.1f" % v

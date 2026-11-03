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
## Empty: the shot does just what `effect` says.
@export var special: StringName = &""
## Steam: most climbers one blast knocks off; Bola: bugs one throw tangles.
@export var special_count: int = 0


## Armour-plated or 100+ HP: the bugs big-game guns are for and swarm guns struggle with.
static func is_heavy(bd: BugDef) -> bool:
	return bd.front_armor > 0.0 or bd.max_hp >= HEAVY_HP


## Needs upkeep (ammo) to keep firing.
func has_upkeep() -> bool:
	return not ammo_cost.is_empty()


## "1 chili" / "1 scrap" per shot, for prompts and the catalog.
func upkeep_text() -> String:
	var parts: PackedStringArray = []
	for k: Variant in ammo_cost.keys():
		parts.append("%d %s" % [int(ammo_cost[k]), String(k).replace("_", " ")])
	return ", ".join(parts)


## Damage of one shot at an upgrade tier, against a heavy bug or not.
func damage_at(tier: int, heavy: bool = false) -> float:
	return damage * TIER_DAMAGE[clampi(tier, 0, MAX_TIER)] * (heavy_mult if heavy else 1.0)


## Range at an upgrade tier, standing on `level` scaffold levels.
func range_at(tier: int, level: int = 0) -> float:
	return range * range_mult(tier, level)


static func range_mult(tier: int, level: int) -> float:
	return TIER_RANGE[clampi(tier, 0, MAX_TIER)] + RANGE_PER_LEVEL * maxi(level, 0)


func interval_at(tier: int) -> float:
	return fire_interval * TIER_INTERVAL[clampi(tier, 0, MAX_TIER)]


func hp_at(tier: int) -> float:
	return max_hp * TIER_HP[clampi(tier, 0, MAX_TIER)]


## One line for the build catalog's detail strip: job, weakness and any upkeep.
func role_line() -> String:
	var parts: PackedStringArray = []
	if role != "":
		parts.append("Job: %s" % role)
	if weakness != "":
		parts.append("Weak: %s" % weakness)
	if has_upkeep():
		parts.append("Upkeep: %s a shot" % upkeep_text())
	return "   ·   ".join(parts)


## The key numbers in one line, like a gun's (build menu, workshop, field guide):
## "Damage 6  ·  6.7 Shots/s  ·  Range 80 m  ·  Splash 3 m".
func stat_line(tier: int = 0) -> String:
	var dmg := damage_at(tier)
	var parts: PackedStringArray = ["Damage %s" % _num(dmg)]
	var every := interval_at(tier)
	parts.append(("%s Shots/s" % _num(1.0 / every)) if every < 1.0 else ("1 Shot / %s s" % _num(every)))
	parts.append("Range %d m" % int(roundf(range_at(tier))))
	match special:
		&"steam": parts.append("Steam Cone: Knocks %d Off, Slows the Rest" % special_count)
		&"flood": parts.append("Floods a %s m Lane" % _num(effect_size))
		&"twin": parts.append("Fire + Blast %s m" % _num(effect_size))
		&"bola": parts.append("Tangles %d Bugs %s s" % [special_count, _num(effect_size)])
	match effect if special == &"" else -1:
		Effect.KNOCKBACK: parts.append("Knocks Bugs Off")
		Effect.BURN: parts.append("Burning Patch %s m" % _num(effect_size))
		Effect.SPLASH: parts.append("Splash %s m" % _num(effect_size))
		Effect.PIN: parts.append("Pins %s s" % _num(effect_size))
	if armor_pierce:
		parts.append("Pierces Armour")
	if not is_equal_approx(heavy_mult, 1.0):
		parts.append("x%s vs Heavy" % _num(heavy_mult))
	if anti_air:
		parts.append("Fliers Only")
	return "  ·  ".join(parts)


## 6, 6.5, 0.3: whole numbers plain, the rest to one decimal.
static func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return ("%.2f" % v).trim_suffix("0") if v < 1.0 else "%.1f" % v

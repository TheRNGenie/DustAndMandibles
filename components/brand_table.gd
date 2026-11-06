class_name BrandTable
extends RefCounted
## The brands a rider takes at the start of each run (pure data and rules, unit
## tested; the Brand autoload keeps who chose what and applies them).
##   The Sheaf          - farming: bigger harvests, faster growth, fuller buckets, cheaper seeds
##   The Crossed Irons  - combat: faster reloads, more team chitin per kill, richer bug loot
##   The Snake Eyes     - gambling: harder hits on bosses, and casino cheats (with a risk of a ban)
##   Attack on Mandibles- mobility: quicker combos, harder slingshots, a faster
##                        grapple, cheaper zipline anchors (it replaced No Brand on the
##                        pick screen; "none" is still a rider who hasn't picked)
## Numbers stay modest (10-25%). Each brand also re-themes the local player's UI
## (UiStyle set of the same id).

const NONE := &"none"
const SHEAF := &"sheaf"
const IRONS := &"irons"
const SNAKE := &"snake"
const MANDIBLES := &"mandibles"
## In the order the branding irons stand on the pick screen.
const IDS: Array[StringName] = [SHEAF, IRONS, SNAKE, MANDIBLES]
# --- Attack on Mandibles (movement plan)
const COMBO_GAIN := 0.25 # each combo action counts 25% more
const SLING_DAMAGE := 0.20 # slingshot hits 20% harder
const GRAPPLE_SPEED := 0.15 # swing and reel 15% faster
const ZIP_DISCOUNT := 0.20 # zipline anchors cost 20% less scrap

# --- The Sheaf
const CROP_YIELD := 0.20 # +20% harvest (the fraction rounds up by chance)
const CROP_GROWTH := 0.15 # crops on your plateau grow 15% faster
const WATER_FILL := 0.25 # +25% water per bucket fill (at least +1)
const SEED_DISCOUNT := 0.20 # seeds cost 20% less scrap
# --- The Crossed Irons
const RELOAD := 0.15 # reloads take 15% less time
const KILL_LOOT := 0.20 # +20% team-pot pay from bugs you (or your turrets) kill
const HEAP_LOOT := 0.25 # +25% from bug shell heaps you pick over...
const HEAP_SCRAP := 3 # ...and a little more pried off the shell
# --- The Snake Eyes
const BOSS_DAMAGE := 0.20 # +20% gun and whip damage on bosses
## Chance the pit boss catches a cheat (Logan): CHEAT_RISK at first, HEAT more
## for each cheat that got past him, up to certain; being caught starts it over.
const CHEAT_RISK := 0.70
const HEAT := 0.05
const MAX_RISK := 1.0
## Waves a caught cheat is barred from the airship's tables.
const BAN_WAVES := 1

const BRANDS: Dictionary = {
	SHEAF: {"name": "The Sheaf", "short": "Sheaf", "motto": "Feed the posse.",
		"lines": ["+20% crop harvest", "Crops grow 15% faster", "+25% water per bucket fill", "Seeds cost 20% less"]},
	IRONS: {"name": "The Crossed Irons", "short": "Crossed Irons", "motto": "Shoot first, loot after.",
		"lines": ["Reload 15% faster", "+20% team chitin per kill", "+25% team chitin from bug shell heaps, plus 3"]},
	SNAKE: {"name": "The Snake Eyes", "short": "Snake Eyes", "motto": "The house always loses.",
		"lines": ["+20% damage to bosses", "Cheat at the airship casino: peek, nudge, load the ball, palm an ace, dope a beetle",
			"Get caught and you're barred from the tables for a wave"]},
	MANDIBLES: {"name": "Attack on Mandibles", "short": "Mandibles", "motto": "You are the weapon.",
		"lines": ["Style combo climbs 25% faster", "Grapple slingshot hits 20% harder", "Grapple swings and reels 15% faster", "Zipline anchors cost 20% less scrap"]},
	NONE: {"name": "No Brand", "short": "Unbranded", "motto": "Ride clean.",
		"lines": ["No bonuses", "The plain Frontier look"]},
}


static func valid(id: Variant) -> StringName:
	var s := StringName(str(id))
	return s if BRANDS.has(s) else NONE


static func name_of(id: StringName) -> String:
	return str(BRANDS[valid(id)]["name"])


static func short_of(id: StringName) -> String:
	return str(BRANDS[valid(id)]["short"])


## The UI theme set a brand wears (UiStyle.SETS).
static func theme_of(id: StringName) -> StringName:
	var v := valid(id)
	return &"base" if v == NONE else v


# ------------------------------------------------------------------ farming

## Growth-rate multiplier for crops on a plateau of this brand.
static func growth_mult(id: StringName) -> float:
	return 1.0 + CROP_GROWTH if valid(id) == SHEAF else 1.0


## A harvest {res: n} with The Sheaf's extra: +20% of the main crop, the
## fraction paid when `roll` (0..1) lands under it.
static func scale_yield(harvest: Dictionary, id: StringName, roll: float) -> Dictionary:
	if valid(id) != SHEAF or harvest.is_empty():
		return harvest
	var out := harvest.duplicate()
	var main: Variant = out.keys()[0]
	var extra := float(out[main]) * CROP_YIELD
	out[main] = int(out[main]) + int(floor(extra)) + (1 if roll < extra - floor(extra) else 0)
	return out


## Extra water on a bucket fill of `take`.
static func water_bonus(take: int, id: StringName) -> int:
	if valid(id) != SHEAF or take <= 0:
		return 0
	return maxi(1, roundi(take * WATER_FILL))


static func seed_cost(cost: int, id: StringName) -> int:
	if valid(id) != SHEAF:
		return cost
	return maxi(1, roundi(cost * (1.0 - SEED_DISCOUNT)))


# ------------------------------------------------------------------ combat

## Reload-time multiplier.
static func reload_mult(id: StringName) -> float:
	return 1.0 - RELOAD if valid(id) == IRONS else 1.0


## A kill's loot (team pot) when the killer wears the Crossed Irons.
static func kill_loot(loot: Dictionary, killer: StringName) -> Dictionary:
	if valid(killer) != IRONS:
		return loot
	var out := loot.duplicate()
	for k: Variant in out:
		if typeof(out[k]) == TYPE_FLOAT:
			out[k] = float(out[k]) * (1.0 + KILL_LOOT)
		else:
			out[k] = roundi(int(out[k]) * (1.0 + KILL_LOOT))
	return out


## What looting a bug's shell heap of `shells` pays: all into the team pot
## (internal &"scrap", shown as chitin: bug pieces, see ResNames).
static func heap_loot(shells: int, id: StringName) -> Dictionary:
	if valid(id) != IRONS:
		return {&"scrap": shells}
	return {&"scrap": int(ceil(shells * (1.0 + HEAP_LOOT))) + HEAP_SCRAP}


# ------------------------------------------------------------------ gambling

static func boss_mult(id: StringName) -> float:
	return 1.0 + BOSS_DAMAGE if valid(id) == SNAKE else 1.0


static func can_cheat(id: StringName) -> bool:
	return valid(id) == SNAKE


## Chance of being caught cheating at `game` after `heat` earlier cheats this wave.
## `heat`: cheats that got past the pit boss since he last caught this rider.
static func catch_chance(_game: String, heat: int) -> float:
	return minf(CHEAT_RISK + HEAT * maxi(heat, 0), MAX_RISK)


## Zipline anchors' scrap price multiplier for a brand.
static func zip_cost_mult(brand: StringName) -> float:
	return 1.0 - ZIP_DISCOUNT if valid(brand) == MANDIBLES else 1.0


## Style combo gained per action.
static func combo_gain(brand: StringName) -> float:
	return 1.0 + COMBO_GAIN if valid(brand) == MANDIBLES else 1.0


static func sling_mult(brand: StringName) -> float:
	return 1.0 + SLING_DAMAGE if valid(brand) == MANDIBLES else 1.0


static func grapple_speed(brand: StringName) -> float:
	return 1.0 + GRAPPLE_SPEED if valid(brand) == MANDIBLES else 1.0


## Barred from the tables while the wave number is below the returned wave.
static func ban_until(wave: int) -> int:
	return wave + BAN_WAVES + 1


## Slots nudge: move one reel one step along the symbol strip to the best prize.
## `reels` are symbol indices; `value` scores a reel set (CasinoRules.slot_payout).
static func nudge_reels(reels: Array, symbols: int, value: Callable) -> Array:
	var best: Array = reels.duplicate()
	var best_v: int = value.call(reels)
	for i in reels.size():
		for step: int in [-1, 1]:
			var r: Array = reels.duplicate()
			r[i] = posmod(int(r[i]) + step, symbols)
			var v: int = value.call(r)
			if v > best_v:
				best_v = v
				best = r
	return best


## The CPU partner's brand: one of the three, picked from a seed.
static func cpu_pick(seed_value: int) -> StringName:
	return [SHEAF, IRONS, SNAKE][posmod(seed_value, 3)]

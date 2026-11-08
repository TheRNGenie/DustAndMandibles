class_name GunRarity
extends RefCounted
## Gun rarity, the gunsmith's Upgrades tab. Every gun starts Common (white) and is
## upgraded through Uncommon (green), Rare (blue) and Epic (purple). Legendary
## (gold) also takes a piece of Meteor Iron, the rare drop from bosses. A gun's
## rarity is its WeaponMods.level (0-4), so a dropped or stored gun keeps it.
## Pure rules, no autoloads, so the tests can load it.

const COMMON := 0
const UNCOMMON := 1
const RARE := 2
const EPIC := 3
const LEGENDARY := 4
const MAX := LEGENDARY

const NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const COLOR_NAMES: Array[String] = ["White", "Green", "Blue", "Purple", "Gold"]
const COLORS: Array[Color] = [Color("#E8E4DA"), Color("#5FC25A"), Color("#4A8FE0"), Color("#A45FE0"), Color("#F2B233")]
## Damage multiplier at each rarity.
const DAMAGE: Array[float] = [1.0, 1.2, 1.4, 1.65, 2.0]
## Reload time multiplier at each rarity (lower is faster).
const RELOAD: Array[float] = [1.0, 0.88, 0.78, 0.7, 0.6]
## The rare drop Legendary takes, on top of the scrap.
const ITEM := &"meteor_iron"
const ITEM_NAME := "Meteor Iron"
## Upgrade prices (scrap) from each rarity to the next, scaled from a gun's two
## listed costs (WeaponDef.upgrade_costs: to Uncommon, to Rare).
const EPIC_SCALE := 2.0
const LEGENDARY_SCALE := 3.5
## Drops: every boss leaves one piece; any heavy bug has this chance.
const HEAVY_CHANCE := 0.01


static func name_of(r: int) -> String:
	return NAMES[clampi(r, 0, MAX)]


static func color_of(r: int) -> Color:
	return COLORS[clampi(r, 0, MAX)]


## "Rare (Blue)".
static func label(r: int) -> String:
	return "%s (%s)" % [NAMES[clampi(r, 0, MAX)], COLOR_NAMES[clampi(r, 0, MAX)]]


static func damage_mult(r: int) -> float:
	return DAMAGE[clampi(r, 0, MAX)]


static func reload_mult(r: int) -> float:
	return RELOAD[clampi(r, 0, MAX)]


## Scrap to take a gun from rarity `r` to the next one, or -1 at Legendary.
static func cost(base: PackedInt32Array, r: int) -> int:
	if r >= MAX or r < 0:
		return -1
	var a := int(base[0]) if base.size() > 0 else 10
	var b := int(base[1]) if base.size() > 1 else a * 2
	match r:
		0:
			return a
		1:
			return b
		2:
			return roundi(b * EPIC_SCALE)
		_:
			return roundi(b * LEGENDARY_SCALE)


## Does going up from `r` take Meteor Iron too?
static func needs_item(r: int) -> bool:
	return r == EPIC


## Everything the next step costs, e.g. {&"chitin": 88, &"meteor_iron": 1}.
static func price(base: PackedInt32Array, r: int) -> Dictionary:
	var c := cost(base, r)
	if c < 0:
		return {}
	var out := {&"chitin": c}
	if needs_item(r):
		out[ITEM] = 1
	return out


## What the next rarity does, for the shop row.
static func step_text(r: int) -> String:
	if r >= MAX:
		return "Legendary: the gunsmith can't take it any further."
	var dmg := roundi((DAMAGE[r + 1] - 1.0) * 100.0)
	var rel := roundi((1.0 - RELOAD[r + 1]) * 100.0)
	return "To %s: +%d%% damage and %d%% faster reloads over Common." % [label(r + 1), dmg, rel]

class_name PerkTable
extends RefCounted
## The Rancher's Ledger: every perk in one table (pure data, unit-tested).
## Perks are bought with Brands between runs (PerkProfile) and a player takes up
## to MAX_LOADOUT of their unlocked perks into each run. Each perk is modest on
## its own (5-25%); a full loadout is strong but not broken.
##
## Fields: id, tree, name, glyph (PerkGlyph shape or "item:<hotbar icon>"),
## desc (with {v} for the value at a rank), per_rank (value added per rank),
## fmt ("pct" shows per_rank * rank as a percent, "int" as a number, "" none),
## costs (Brands for rank 1, 2, 3...; its size is the max rank), owner ("local":
## the player's own game applies it; "host": the host applies it).

const MAX_LOADOUT := 12

const TREES: Array[StringName] = [&"gun", &"home", &"eng"]
const TREE_NAMES: Dictionary = {&"gun": "Gunslinger", &"home": "Homesteader", &"eng": "Engineer"}
const TREE_BLURBS: Dictionary = {
	&"gun": "Irons, aim and the gunsmith.",
	&"home": "Crops, water, the house and your hide.",
	&"eng": "Turrets, scaffolds and scrap.",
}

const PERKS: Array[Dictionary] = [
	# ---------------------------------------------------------------- Gunslinger
	{"id": &"quick_hands", "tree": &"gun", "name": "Quick Hands", "glyph": "hourglass",
		"desc": "Reload {v} faster.", "per_rank": 0.08, "fmt": "pct", "costs": [15, 30, 50], "owner": "local"},
	{"id": &"steady_hand", "tree": &"gun", "name": "Steady Hand", "glyph": "crosshair",
		"desc": "{v} less kick from every shot.", "per_rank": 0.15, "fmt": "pct", "costs": [15, 35], "owner": "local"},
	{"id": &"hair_trigger", "tree": &"gun", "name": "Hair Trigger", "glyph": "bolt",
		"desc": "Guns fire {v} faster.", "per_rank": 0.04, "fmt": "pct", "costs": [25, 50], "owner": "local"},
	{"id": &"bandolier", "tree": &"gun", "name": "Bandolier", "glyph": "bullets",
		"desc": "+{v} round per magazine (+10% a rank on the Gatling). Not the shotguns.", "per_rank": 1.0, "fmt": "int",
		"costs": [20, 40], "owner": "local"},
	{"id": &"heavy_slugs", "tree": &"gun", "name": "Heavy Slugs", "glyph": "item:revolver",
		"desc": "Your guns hit {v} harder.", "per_rank": 0.05, "fmt": "pct", "costs": [20, 40, 65], "owner": "host"},
	{"id": &"marksman", "tree": &"gun", "name": "Marksman", "glyph": "eye",
		"desc": "Weak-spot hits do {v} more damage.", "per_rank": 0.10, "fmt": "pct", "costs": [25, 45], "owner": "host"},
	{"id": &"dead_eye", "tree": &"gun", "name": "Dead-Eye Refund", "glyph": "refund",
		"desc": "Weak-spot hits have a {v} chance to put the round back.", "per_rank": 0.20, "fmt": "pct",
		"costs": [25, 45], "owner": "local"},
	{"id": &"whip_hand", "tree": &"gun", "name": "Whip Hand", "glyph": "whip",
		"desc": "Bullwhip lashes do {v} more damage.", "per_rank": 0.15, "fmt": "pct", "costs": [15, 30], "owner": "host"},
	{"id": &"gunsmiths_friend", "tree": &"gun", "name": "Gunsmith's Friend", "glyph": "tag",
		"desc": "Everything at the gunsmith costs {v} less chitin.", "per_rank": 0.10, "fmt": "pct",
		"costs": [20, 40], "owner": "host"},
	{"id": &"starting_iron", "tree": &"gun", "name": "Starting Iron", "glyph": "item:lever_rifle",
		"desc": "Start every run with a lever-action rifle.", "per_rank": 1.0, "fmt": "", "costs": [30], "owner": "host"},
	{"id": &"lucky_shot", "tree": &"gun", "name": "Lucky Shot", "glyph": "horseshoe",
		"desc": "Your gun hits have a {v} chance to do double damage.", "per_rank": 0.05, "fmt": "pct",
		"costs": [20, 40], "owner": "host"},
	{"id": &"point_blank", "tree": &"gun", "name": "Point Blank", "glyph": "item:coach_shotgun",
		"desc": "Gun hits within 8 m do {v} more damage.", "per_rank": 0.12, "fmt": "pct", "costs": [15, 30], "owner": "host"},
	# ---------------------------------------------------------------- Homesteader
	{"id": &"green_thumb", "tree": &"home", "name": "Green Thumb", "glyph": "sprout",
		"desc": "Crops on your plateau grow {v} faster.", "per_rank": 0.07, "fmt": "pct", "costs": [15, 30, 50], "owner": "host"},
	{"id": &"bumper_crop", "tree": &"home", "name": "Bumper Crop", "glyph": "item:corn",
		"desc": "{v} chance of an extra crop at each harvest.", "per_rank": 0.15, "fmt": "pct", "costs": [20, 40], "owner": "host"},
	{"id": &"deep_well", "tree": &"home", "name": "Deep Well", "glyph": "drop",
		"desc": "+{v} water each time you fill your bucket.", "per_rank": 1.0, "fmt": "int", "costs": [20, 40], "owner": "host"},
	{"id": &"homestead_plot", "tree": &"home", "name": "Homestead Plot", "glyph": "plot",
		"desc": "Start every run with a farm plot dug and 2 corn seeds.", "per_rank": 1.0, "fmt": "", "costs": [40], "owner": "host"},
	{"id": &"full_pantry", "tree": &"home", "name": "Full Pantry", "glyph": "sack",
		"desc": "Start every run with 4 more water and a bundle of herbs.", "per_rank": 1.0, "fmt": "", "costs": [25], "owner": "host"},
	{"id": &"carpenter", "tree": &"home", "name": "Carpenter", "glyph": "house",
		"desc": "Homestead upgrades cost {v} less.", "per_rank": 0.10, "fmt": "pct", "costs": [20, 40], "owner": "host"},
	{"id": &"stout_timbers", "tree": &"home", "name": "Stout Timbers", "glyph": "shield",
		"desc": "Your Homestead starts with {v} more HP.", "per_rank": 0.08, "fmt": "pct", "costs": [25, 45], "owner": "host"},
	# Was Trail Rations (hunger/thirst are off); the id stays so saved profiles keep their ranks.
	{"id": &"trail_rations", "tree": &"home", "name": "Second Wind", "glyph": "heart",
		"desc": "Health regenerates {v} faster.", "per_rank": 0.15, "fmt": "pct", "costs": [10, 25], "owner": "local"},
	{"id": &"herbalist", "tree": &"home", "name": "Herbalist", "glyph": "item:herbs",
		"desc": "Medicine heals {v} more.", "per_rank": 0.25, "fmt": "pct", "costs": [10, 25], "owner": "local"},
	{"id": &"tough_hide", "tree": &"home", "name": "Tough Hide", "glyph": "heart",
		"desc": "Take {v} less damage.", "per_rank": 0.07, "fmt": "pct", "costs": [25, 45], "owner": "local"},
	{"id": &"back_in_saddle", "tree": &"home", "name": "Back in the Saddle", "glyph": "spur",
		"desc": "Get back up {v} sooner when you're downed.", "per_rank": 0.20, "fmt": "pct", "costs": [15, 30], "owner": "local"},
	{"id": &"fleet_foot", "tree": &"home", "name": "Fleet Foot", "glyph": "boot",
		"desc": "Sprint {v} faster.", "per_rank": 0.04, "fmt": "pct", "costs": [15, 30], "owner": "local"},
	# ---------------------------------------------------------------- Engineer
	{"id": &"barn_raising", "tree": &"eng", "name": "Barn Raising", "glyph": "star",
		"desc": "The first turret you build each run is free.", "per_rank": 1.0, "fmt": "", "costs": [40], "owner": "host"},
	{"id": &"bulk_lumber", "tree": &"eng", "name": "Bulk Lumber", "glyph": "planks",
		"desc": "Turrets and structures cost {v} less scrap.", "per_rank": 0.05, "fmt": "pct", "costs": [20, 40, 65], "owner": "host"},
	{"id": &"chitin_smith", "tree": &"eng", "name": "Chitin Smith", "glyph": "chevrons",
		"desc": "Turret upgrades cost {v} less chitin.", "per_rank": 0.10, "fmt": "pct", "costs": [20, 40], "owner": "host"},
	{"id": &"old_scaffolds", "tree": &"eng", "name": "Old Scaffolds", "glyph": "scaffold",
		"desc": "Start every run with 2 scaffolds standing on your cliff line.", "per_rank": 1.0, "fmt": "",
		"costs": [35], "owner": "host"},
	{"id": &"long_sights", "tree": &"eng", "name": "Long Sights", "glyph": "spyglass",
		"desc": "Turrets you build reach {v} further.", "per_rank": 0.05, "fmt": "pct", "costs": [25, 50], "owner": "host"},
	{"id": &"well_oiled", "tree": &"eng", "name": "Well Oiled", "glyph": "gear",
		"desc": "Turrets you build fire {v} faster.", "per_rank": 0.05, "fmt": "pct", "costs": [30, 55], "owner": "host"},
	{"id": &"reinforced_frames", "tree": &"eng", "name": "Reinforced Frames", "glyph": "bolts",
		"desc": "Turrets you build have {v} more HP.", "per_rank": 0.10, "fmt": "pct", "costs": [20, 40], "owner": "host"},
	{"id": &"tinker", "tree": &"eng", "name": "Tinker", "glyph": "wrench",
		"desc": "Each repair patches {v} more HP for the same scrap.", "per_rank": 0.20, "fmt": "pct",
		"costs": [15, 30], "owner": "host"},
	{"id": &"salvager", "tree": &"eng", "name": "Salvager", "glyph": "hammer",
		"desc": "Tearing down gives back {v} more scrap.", "per_rank": 0.15, "fmt": "pct", "costs": [10, 25], "owner": "host"},
	{"id": &"overtime", "tree": &"eng", "name": "Overtime", "glyph": "moon",
		"desc": "When a wave ends, turrets you built patch {v} of their HP.", "per_rank": 0.15, "fmt": "pct",
		"costs": [20, 40], "owner": "host"},
	{"id": &"scrap_scavenger", "tree": &"eng", "name": "Scrap Scavenger", "glyph": "magnet",
		"desc": "Kills by turrets you built drop {v} more scrap.", "per_rank": 0.15, "fmt": "pct",
		"costs": [20, 40], "owner": "host"},
	{"id": &"scrap_stash", "tree": &"eng", "name": "Scrap Stash", "glyph": "crate",
		"desc": "Start every run with {v} extra scrap.", "per_rank": 20.0, "fmt": "int", "costs": [15, 30], "owner": "host"},
]

## Wardrobe items bought with Brands: slot -> {option id: price}. Options not
## listed here are free from the start.
const COSMETICS: Dictionary = {
	"hat": {"ten_gallon": 25, "bowler": 20, "sombrero": 40},
	"outfit": {"duster": 45, "poncho": 35, "lawman": 60},
	"hair": {"mohawk": 15, "long": 10},
	"facial": {"walrus": 10, "chops": 10},
	"neck": {"bolo": 15},
	"paint": {"orange": 20, "white": 20},
}

static var _by_id: Dictionary = {}


static func get_perk(id: StringName) -> Dictionary:
	if _by_id.is_empty():
		for p: Dictionary in PERKS:
			_by_id[p["id"]] = p
	return _by_id.get(id, {})


static func has(id: StringName) -> bool:
	return not get_perk(id).is_empty()


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in PERKS:
		out.append(p["id"])
	return out


static func in_tree(tree: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in PERKS:
		if p["tree"] == tree:
			out.append(p)
	return out


static func max_rank(id: StringName) -> int:
	return (get_perk(id).get("costs", []) as Array).size()


## Brands to buy `rank` (1-based), or -1 past the top rank.
static func cost_of_rank(id: StringName, rank: int) -> int:
	var costs: Array = get_perk(id).get("costs", [])
	return int(costs[rank - 1]) if rank >= 1 and rank <= costs.size() else -1


## Brands spent on a perk up to `rank`.
static func spent_to(id: StringName, rank: int) -> int:
	var total := 0
	for r in range(1, mini(rank, max_rank(id)) + 1):
		total += cost_of_rank(id, r)
	return total


## The perk's raw value at a rank (per_rank * rank), 0 if unknown.
static func amount(id: StringName, rank: int) -> float:
	var p := get_perk(id)
	if p.is_empty() or rank <= 0:
		return 0.0
	return float(p["per_rank"]) * clampi(rank, 0, max_rank(id))


## Amount for a perk taken in `loadout` ({id: rank}).
static func amount_in(loadout: Dictionary, id: StringName) -> float:
	return amount(id, int(loadout.get(id, 0)))


## 1 + amount (for "more" perks).
static func more(loadout: Dictionary, id: StringName) -> float:
	return 1.0 + amount_in(loadout, id)


## 1 - amount, never below 0.1 (for "less" perks).
static func less(loadout: Dictionary, id: StringName) -> float:
	return maxf(1.0 - amount_in(loadout, id), 0.1)


## The value text at a rank: "16%", "+2", or "" for on/off perks.
static func value_text(id: StringName, rank: int) -> String:
	var p := get_perk(id)
	match str(p.get("fmt", "")):
		"pct":
			return "%d%%" % roundi(amount(id, rank) * 100.0)
		"int":
			return "%d" % roundi(amount(id, rank))
	return ""


## The description with the value at `rank` filled in (rank 1 when not owned yet).
static func describe(id: StringName, rank: int) -> String:
	var p := get_perk(id)
	return str(p.get("desc", "")).replace("{v}", value_text(id, maxi(rank, 1)))


## Scales every amount of a cost ({res: n}) by `mult`, rounding to the nearest
## whole unit and never below 1 (a free item stays free).
static func scale_cost(cost: Dictionary, mult: float) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in cost:
		var n := int(cost[k])
		out[k] = 0 if n <= 0 else maxi(roundi(float(n) * mult), 1)
	return out


## Extra rounds the Bandolier gives a gun with this magazine size.
static func bandolier_bonus(mag: int, rank: int) -> int:
	if rank <= 0 or mag < 5:
		return 0
	return maxi(rank, roundi(float(mag) * 0.1 * rank))


## Brand price of a wardrobe option (0 = free from the start).
static func cosmetic_price(slot: String, option: String) -> int:
	return int((COSMETICS.get(slot, {}) as Dictionary).get(option, 0))


static func cosmetic_key(slot: String, option: String) -> String:
	return "%s:%s" % [slot, option]

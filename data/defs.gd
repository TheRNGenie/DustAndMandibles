class_name Defs
extends RefCounted
## Registry of every data definition, looked up by id.

## Bugs taken out of the game for now (still defined, never spawned or listed).
const DISABLED_BUGS: Array[StringName] = [&"burrow_tick"]


## The bugs that are in play.
static func active_bug_ids() -> Array:
	return BUGS.keys().filter(func(id: StringName) -> bool: return not DISABLED_BUGS.has(id))


const BUGS: Dictionary = {
	&"dust_mite": preload("res://data/bugs/dust_mite.tres"),
	&"wolf_spider": preload("res://data/bugs/wolf_spider.tres"),
	&"rattler_beetle": preload("res://data/bugs/rattler_beetle.tres"),
	&"spitter_scorpion": preload("res://data/bugs/spitter_scorpion.tres"),
	&"brood_mother": preload("res://data/bugs/brood_mother.tres"),
	&"spiderling": preload("res://data/bugs/spiderling.tres"),
	&"burrow_tick": preload("res://data/bugs/burrow_tick.tres"),
	&"dragonfly_bandit": preload("res://data/bugs/dragonfly_bandit.tres"),
	&"crop_weevil": preload("res://data/bugs/crop_weevil.tres"),
	&"iron_tumble": preload("res://data/bugs/iron_tumble.tres"),
	# Bosses (one comes every boss wave; see BossRotation) and the small bugs they let loose.
	&"queen_spider": preload("res://data/bugs/queen_spider.tres"),
	&"burrow_beetle": preload("res://data/bugs/burrow_beetle.tres"),
	&"tumble_titan": preload("res://data/bugs/tumble_titan.tres"),
	&"locust_lord": preload("res://data/bugs/locust_lord.tres"),
	&"acid_matriarch": preload("res://data/bugs/acid_matriarch.tres"),
	&"mirage_mantis": preload("res://data/bugs/mirage_mantis.tres"),
	&"hive_wagon": preload("res://data/bugs/hive_wagon.tres"),
	&"stilt_strider": preload("res://data/bugs/stilt_strider.tres"),
	&"thunder_cicada": preload("res://data/bugs/thunder_cicada.tres"),
	&"bone_collector": preload("res://data/bugs/bone_collector.tres"),
	&"hive_queen": preload("res://data/bugs/hive_queen.tres"), # Story only (chapter 8)
	&"hive_mother": preload("res://data/bugs/hive_mother.tres"), # Story only (chapter 10)
	&"locust": preload("res://data/bugs/locust.tres"),
	&"hive_drone": preload("res://data/bugs/hive_drone.tres"),
}

const TURRETS: Dictionary = {
	&"duck_gun": preload("res://data/turrets/duck_gun.tres"),
	&"sky_sweeper": preload("res://data/turrets/sky_sweeper.tres"),
	&"powder_flak": preload("res://data/turrets/powder_flak.tres"),
	&"net_thrower": preload("res://data/turrets/net_thrower.tres"),
	&"firework_battery": preload("res://data/turrets/firework_battery.tres"),
	&"gatling_post": preload("res://data/turrets/gatling_post.tres"),
	&"buffalo_rifle": preload("res://data/turrets/buffalo_rifle.tres"),
	&"water_cannon": preload("res://data/turrets/water_cannon.tres"),
	&"chili_mortar": preload("res://data/turrets/chili_mortar.tres"),
	&"dynamite_lobber": preload("res://data/turrets/dynamite_lobber.tres"),
	&"lasso_harpoon": preload("res://data/turrets/lasso_harpoon.tres"),
	&"scattergun_post": preload("res://data/turrets/scattergun_post.tres"),
	&"sharpshooter_tower": preload("res://data/turrets/sharpshooter_tower.tres"),
	&"porch_repeater": preload("res://data/turrets/porch_repeater.tres"),
	&"rooftop_cannon": preload("res://data/turrets/rooftop_cannon.tres"),
	# Tiers: Mid and Late turrets (TurretDef.tier, unlocked at TurretDef.UNLOCK_WAVES).
	&"twin_gatling": preload("res://data/turrets/twin_gatling.tres"),
	&"hornets_nest": preload("res://data/turrets/hornets_nest.tres"),
	&"elephant_battery": preload("res://data/turrets/elephant_battery.tres"),
	&"rail_spike_driver": preload("res://data/turrets/rail_spike_driver.tres"),
	&"gatling_porch": preload("res://data/turrets/gatling_porch.tres"),
	# Crewed: 2 x 2 guns you sit in and fire yourself (CrewedTurret).
	&"big_bertha": preload("res://data/turrets/big_bertha.tres"),
	&"whaler": preload("res://data/turrets/whaler.tres"),
	&"thunder_mule": preload("res://data/turrets/thunder_mule.tres"),
	&"sky_hound": preload("res://data/turrets/sky_hound.tres"),
	# Control / area / pin additions (special shots in TurretEffects).
	&"steam_cannon": preload("res://data/turrets/steam_cannon.tres"),
	&"flood_gate": preload("res://data/turrets/flood_gate.tres"),
	&"twin_mortar": preload("res://data/turrets/twin_mortar.tres"),
	&"bola_launcher": preload("res://data/turrets/bola_launcher.tres"),
	# Turret ammo (farming redesign): self-powered lines.
	&"repeater_post": preload("res://data/turrets/repeater_post.tres"),
	&"brass_gatling": preload("res://data/turrets/brass_gatling.tres"),
	&"long_tom_rifle": preload("res://data/turrets/long_tom_rifle.tres"),
	&"buck_blaster": preload("res://data/turrets/buck_blaster.tres"),
	&"grapeshot_turret": preload("res://data/turrets/grapeshot_turret.tres"),
	&"skeet_post": preload("res://data/turrets/skeet_post.tres"),
	&"flak_porch": preload("res://data/turrets/flak_porch.tres"),
	# Turret ammo: crop-fed lines (TurretDef.crop_type).
	&"corn_hopper": preload("res://data/turrets/corn_hopper.tres"),
	&"twin_hopper": preload("res://data/turrets/twin_hopper.tres"),
	&"pepper_sprayer": preload("res://data/turrets/pepper_sprayer.tres"),
	&"sulfur_fume_vent": preload("res://data/turrets/sulfur_fume_vent.tres"),
	&"herb_rifle": preload("res://data/turrets/herb_rifle.tres"),
	&"tripwire_fence": preload("res://data/turrets/tripwire_fence.tres"),
	&"bramble_bomb": preload("res://data/turrets/bramble_bomb.tres"),
	&"dust_devil_trap": preload("res://data/turrets/dust_devil_trap.tres"),
	&"siege_mortar": preload("res://data/turrets/siege_mortar.tres"),
	# Lines keep their kind: the Mid cliff rifle and the Late sulfur and cotton
	# cliff guns that close the Buffalo, Dynamite and Lasso lines.
	&"big_fifty": preload("res://data/turrets/big_fifty.tres"),
	&"brimstone_bellows": preload("res://data/turrets/brimstone_bellows.tres"),
	&"cotton_bale_cannon": preload("res://data/turrets/cotton_bale_cannon.tres"),
}

## Hive amber turrets (AmberRules): crafted at the Workshop from amber and rare
## parts once their blueprint is known, placed from the Crafted tab like any
## crafted turret, one of each per team. Not in TURRETS (no scrap price, not in
## the build tabs); Defs.turret() finds them here.
const AMBER_TURRETS: Dictionary = {
	&"amber_kiln": preload("res://data/turrets/amber/amber_kiln.tres"),
	&"queens_bell": preload("res://data/turrets/amber/queens_bell.tres"),
	&"mandible_lance": preload("res://data/turrets/amber/mandible_lance.tres"),
}

const STRUCTURES: Dictionary = {
	&"barbed_wire": preload("res://data/structures/barbed_wire.tres"),
	&"bear_trap": preload("res://data/structures/bear_trap.tres"),
	&"dynamite_crate": preload("res://data/structures/dynamite_crate.tres"),
	&"palisade": preload("res://data/structures/palisade.tres"),
	&"lantern_post": preload("res://data/structures/lantern_post.tres"),
	&"rain_catcher": preload("res://data/structures/rain_catcher.tres"),
	&"farm_plot": preload("res://data/structures/farm_plot.tres"),
	&"scaffold": preload("res://data/structures/scaffold.tres"),
}

const CROPS: Dictionary = {
	&"corn": preload("res://data/crops/corn.tres"),
	&"prickly_pear": preload("res://data/crops/prickly_pear.tres"),
	&"firecracker_chili": preload("res://data/crops/firecracker_chili.tres"),
	&"herbs": preload("res://data/crops/herbs.tres"),
	&"sarsaparilla": preload("res://data/crops/sarsaparilla.tres"), # grown for your partner (PartnerTonic); loads the crewed guns
	# Turret ammo (farming redesign): crops grown only as turret loads.
	&"cotton": preload("res://data/crops/cotton.tres"),
	&"sulfur_root": preload("res://data/crops/sulfur_root.tres"),
	&"barrel_cactus": preload("res://data/crops/barrel_cactus.tres"),
	&"tumbleweed_vine": preload("res://data/crops/tumbleweed_vine.tres"),
}

## Player guns (the gun shop sells them; Gun.WEAPONS points here).
const WEAPONS: Dictionary = {
	&"revolver": preload("res://data/weapons/revolver.tres"),
	&"lever_rifle": preload("res://data/weapons/lever_rifle.tres"),
	&"coach_shotgun": preload("res://data/weapons/coach_shotgun.tres"),
	&"elephant_gun": preload("res://data/weapons/elephant_gun.tres"),
	&"dino_rifle": preload("res://data/weapons/dino_rifle.tres"), # secret: unlocked with a code
	&"blunderbuss": preload("res://data/weapons/blunderbuss.tres"),
	&"crank_gatling": preload("res://data/weapons/crank_gatling.tres"),
	# Frontier guns (gen/frontier_guns.gd models, GunRules specials).
	&"derringer_pair": preload("res://data/weapons/derringer_pair.tres"),
	&"pepperbox": preload("res://data/weapons/pepperbox.tres"),
	&"salt_shotgun": preload("res://data/weapons/salt_shotgun.tres"),
	&"harpoon_pistol": preload("res://data/weapons/harpoon_pistol.tres"),
	&"bee_smoker": preload("res://data/weapons/bee_smoker.tres"),
	&"flare_gun": preload("res://data/weapons/flare_gun.tres"),
	&"punt_gun": preload("res://data/weapons/punt_gun.tres"),
	&"telescope_rifle": preload("res://data/weapons/telescope_rifle.tres"),
	# Weapon Slots Redesign (Nov 2026): models built in code (gen/armory_*.gd),
	# specials in ArmoryEffects. Primaries:
	&"volcanic_repeater": preload("res://data/weapons/volcanic_repeater.tres"),
	&"mares_leg": preload("res://data/weapons/mares_leg.tres"),
	&"double_rifle": preload("res://data/weapons/double_rifle.tres"),
	&"trench_broom": preload("res://data/weapons/trench_broom.tres"),
	&"ricochet_rifle": preload("res://data/weapons/ricochet_rifle.tres"),
	&"howdah_pistol": preload("res://data/weapons/howdah_pistol.tres"),
	&"sharps_carbine": preload("res://data/weapons/sharps_carbine.tres"),
	&"trapdoor_springfield": preload("res://data/weapons/trapdoor_springfield.tres"),
	# Secondaries:
	&"swivel_gun": preload("res://data/weapons/swivel_gun.tres"),
	# Universal crop-loaded heavies (HeavyRules; Nov 2026 heavy weapons handoff):
	&"crop_mortar": preload("res://data/weapons/crop_mortar.tres"),
	&"hand_cannon": preload("res://data/weapons/hand_cannon.tres"),
	&"crop_sprayer": preload("res://data/weapons/crop_sprayer.tres"),
	&"spike_driver": preload("res://data/weapons/spike_driver.tres"),
	&"drum_launcher": preload("res://data/weapons/drum_launcher.tres"),
	&"harvest_gatling": preload("res://data/weapons/harvest_gatling.tres"),
	&"crop_crossbow": preload("res://data/weapons/crop_crossbow.tres"),
	&"bola_launcher": preload("res://data/weapons/bola_launcher.tres"),
	&"powder_keg_launcher": preload("res://data/weapons/powder_keg_launcher.tres"),
	&"crop_blunderbuss": preload("res://data/weapons/crop_blunderbuss.tres"),
}

## Retired for now (Logan, 2026-11-08): still registered so the code and saves
## keep working, but not sold, not unlockable and not in the field guide. The
## Dino Rifle's models and notes are archived in D:\DustAndMandibles-archive\dino_rifle.
const RETIRED: Array[StringName] = [&"dino_rifle"]


static func is_retired(id: StringName) -> bool:
	return RETIRED.has(id)


## Every registry, by kind (the content test walks these: ids unique, files load).
const REGISTRIES: Dictionary = {"bugs": BUGS, "turrets": TURRETS, "structures": STRUCTURES, "crops": CROPS, "weapons": WEAPONS}

## Build menu order: number keys 1-9 and 0, mouse wheel cycles through all.
const BUILD_ORDER: Array[StringName] = [&"gatling_post", &"buffalo_rifle", &"water_cannon",
	&"chili_mortar", &"dynamite_lobber", &"lasso_harpoon", &"scaffold", &"scattergun_post", &"sharpshooter_tower", &"barbed_wire", &"bear_trap",
	&"dynamite_crate", &"palisade", &"lantern_post", &"rain_catcher", &"farm_plot", &"porch_repeater", &"rooftop_cannon",
	&"duck_gun", &"sky_sweeper", &"net_thrower", &"powder_flak", &"firework_battery",
	&"steam_cannon", &"bola_launcher", &"twin_mortar", &"flood_gate",
	&"big_bertha", &"whaler", &"thunder_mule", &"sky_hound", # Crewed
	&"twin_gatling", &"hornets_nest", &"elephant_battery", &"rail_spike_driver", &"gatling_porch", # Tiers
	# Special weapons (slot 2; SpecialRules, Nov 2026 special weapons handoff):
	&"crop_duster": preload("res://data/weapons/special/crop_duster.tres"),
	&"barb_sling": preload("res://data/weapons/special/barb_sling.tres"),
	&"signal_flare": preload("res://data/weapons/special/signal_flare.tres"),
	&"crop_syringe": preload("res://data/weapons/special/crop_syringe.tres"),
	&"smoke_bellows": preload("res://data/weapons/special/smoke_bellows.tres"),
	&"bramble_pistol": preload("res://data/weapons/special/bramble_pistol.tres"),
	&"spore_launcher": preload("res://data/weapons/special/spore_launcher.tres"),
	&"venom_needle": preload("res://data/weapons/special/venom_needle.tres"),
	&"trip_wire_gun": preload("res://data/weapons/special/trip_wire_gun.tres"),
	&"spark_pistol": preload("res://data/weapons/special/spark_pistol.tres"),
	&"repeater_post", &"brass_gatling", &"long_tom_rifle", &"buck_blaster", &"grapeshot_turret", &"skeet_post", &"flak_porch", # Turret ammo: self-powered
	&"corn_hopper", &"twin_hopper", &"pepper_sprayer", &"sulfur_fume_vent", &"herb_rifle", &"tripwire_fence",
	&"bramble_bomb", &"dust_devil_trap", &"siege_mortar", # Turret ammo: crop-fed
	&"big_fifty", &"brimstone_bellows", &"cotton_bale_cannon"] # Lines keep their kind

## Build menu (B) categories, in tab order.
const BUILD_CATEGORIES: Array[Dictionary] = [
	{"name": "Farming", "items": [&"farm_plot", &"rain_catcher"]},
	# Turret ammo: Cliff Turrets are the self-powered ones (always fire), Crop-Fed
	# ones need a load of their crop each wave. Tabs show sorted by tier.
	{"name": "Cliff Turrets", "items": [&"gatling_post", &"buffalo_rifle", &"scaffold",
		&"repeater_post", &"twin_gatling", &"big_fifty", &"brass_gatling", &"long_tom_rifle"]},
	{"name": "Crewed Guns", "items": [&"big_bertha", &"whaler", &"thunder_mule", &"sky_hound"]}, # Crewed (sarsaparilla loads)
	{"name": "Crop-Fed", "items": [&"corn_hopper", &"herb_rifle", &"chili_mortar", &"dynamite_lobber", &"water_cannon", &"lasso_harpoon",
		&"twin_hopper", &"pepper_sprayer", &"sulfur_fume_vent", &"steam_cannon", &"bola_launcher", &"elephant_battery",
		&"hornets_nest", &"twin_mortar", &"flood_gate", &"rail_spike_driver", &"siege_mortar", &"brimstone_bellows", &"cotton_bale_cannon"]},
	{"name": "Tactical", "items": [&"barbed_wire", &"bear_trap", &"dynamite_crate", &"palisade", &"lantern_post"]},
	{"name": "Air Defense", "items": [&"duck_gun", &"sky_sweeper", &"skeet_post", &"powder_flak", &"flak_porch", &"net_thrower", &"firework_battery"]},
	{"name": "Last Resorts", "items": [&"scattergun_post", &"porch_repeater", &"tripwire_fence", &"buck_blaster", &"sharpshooter_tower", &"rooftop_cannon",
		&"bramble_bomb", &"grapeshot_turret", &"gatling_porch", &"dust_devil_trap"]},
	# Crafted: filled at runtime with the crafted turret items your cliff holds (BuildMode.category_items).
	{"name": "Crafted", "items": []},
]

## The build menu's tabs (Logan, Nov 2026): the categories above, except that the
## Crop-Fed turrets sit in the Cliff Turrets tab with the self-powered ones; the
## menu's Standard / Crop-Fed selector sorts the two kinds in every tab. (The
## categories themselves stay as they are: the CPU builds from "Cliff Turrets".)
const MENU_MERGE: Dictionary = {"Crop-Fed": "Cliff Turrets"}
static var _tabs: Array[Dictionary] = []


static func build_tabs() -> Array[Dictionary]:
	if _tabs.is_empty():
		for cat: Dictionary in BUILD_CATEGORIES:
			if MENU_MERGE.has(cat["name"]):
				continue
			var items: Array = (cat["items"] as Array).duplicate()
			for from: String in MENU_MERGE:
				if MENU_MERGE[from] == cat["name"]:
					items.append_array(category_items(from))
			_tabs.append({"name": cat["name"], "items": items})
	return _tabs


## The build menu's kinds: 0 all, 1 standard (always fires: every turret that
## needs no crop load, and everything that isn't a turret), 2 crop-fed.
const KIND_ALL := 0
const KIND_STANDARD := 1
const KIND_CROP_FED := 2
const KIND_NAMES: Array[String] = ["All", "Standard", "Crop-Fed"]


static func is_crop_fed(id: StringName) -> bool:
	return is_turret(id) and turret(id).crop_type != &""


static func of_kind(id: StringName, kind: int) -> bool:
	match kind:
		KIND_STANDARD: return not is_crop_fed(id)
		KIND_CROP_FED: return is_crop_fed(id)
	return true


## Tiers: the tech tier of a build item (0 Early, 1 Mid, 2 Late; anything that
## isn't a turret, and crafted turrets, count as Early).
static func tier_of(id: StringName) -> int:
	return turret(id).tier if is_turret(id) else 0


## Tiers: the wave a build item unlocks at (1 = from the start).
static func unlock_wave(id: StringName) -> int:
	return turret(id).unlock_wave() if is_turret(id) else 1


## Tiers: can `id` be built on `wave`? (Callers pass GameState.tier_wave().)
static func is_unlocked(id: StringName, wave: int) -> bool:
	return tier_of(id) == 0 or wave >= unlock_wave(id)


## Tiers: why a locked item can't be built yet ("" when it can).
static func lock_reason(id: StringName, wave: int) -> String:
	if is_unlocked(id, wave):
		return ""
	return "Unlocks at Wave %d" % unlock_wave(id)


## Tiers: a category's items sorted by tech tier (Early, Mid, Late), keeping the
## listed order within a tier. Scaffolds and structures sort with the Early ones.
static func by_tier(items: Array) -> Array:
	var out: Array = []
	for t in TurretDef.ERA_NAMES.size():
		for id: StringName in items:
			if tier_of(id) == t:
				out.append(id)
	return out


## Turrets that come standing on a free scaffold (every turret except the last
## resorts and the house turrets).
static func gets_scaffold(id: StringName) -> bool:
	if not is_turret(id) or is_house_turret(id) or is_crewed(id) or AMBER_TURRETS.has(id): # Crewed / amber: never on scaffolding
		return false
	for cat: Dictionary in BUILD_CATEGORIES:
		if cat["name"] == "Last Resorts" and (cat["items"] as Array).has(id):
			return false
	return true


## Chitin cost of turret upgrade tiers 1 and 2 (a casino upgrade token pays for either).
const UPGRADE_COSTS: Array[int] = [12, 30]

const WAVE_CONFIG: WaveConfig = preload("res://data/wave_config.tres")


static func bug(id: StringName) -> BugDef:
	var d := BUGS.get(id) as BugDef
	if d == null and String(id).ends_with("@slow"):
		return _slow_bug(StringName(String(id).trim_suffix("@slow")))
	if d == null and String(id).contains("@"):
		# Kill-method variants ("rattler_beetle@bullet"), made from the base bug.
		d = (load("res://scenes/bugs/bug_variants.gd") as GDScript).call("get_def", id) as BugDef
	return d


## Tutorial: "dust_mite@slow" is a Dust Mite that climbs and walks at 60% speed
## (same look and name), so the scripted tutorial wave stays gentle.
static var _slow: Dictionary = {}
static func _slow_bug(base: StringName) -> BugDef:
	if _slow.has(base):
		return _slow[base]
	var src := BUGS.get(base) as BugDef
	if src == null:
		return null
	var d := src.duplicate() as BugDef
	d.id = StringName("%s@slow" % base)
	d.variant_of = base
	d.climb_speed *= 0.6
	d.walk_speed *= 0.6
	d.scrap_drop = 0
	_slow[base] = d
	return d


static func turret(id: StringName) -> TurretDef:
	if CraftTable.is_craft(id): # Crafted at the Workshop: built from its parts
		return CraftTable.def_for(id)
	if AMBER_TURRETS.has(id): # Hive amber turrets
		return AMBER_TURRETS[id] as TurretDef
	return TURRETS.get(id) as TurretDef


static func structure(id: StringName) -> StructureDef:
	return STRUCTURES.get(id) as StructureDef


static func crop(id: StringName) -> CropDef:
	return CROPS.get(id) as CropDef


static func weapon(id: StringName) -> WeaponDef:
	return WEAPONS.get(id) as WeaponDef


## The seed item a crop is planted from ({} id -> &"" if unknown).
static func seed_of(crop_id: StringName) -> StringName:
	var c := crop(crop_id)
	return c.seed_item if c != null else &""


static func is_turret(id: StringName) -> bool:
	return TURRETS.has(id) or AMBER_TURRETS.has(id) or not CraftTable.parse(id).is_empty()


# Crewed: a 2 x 2 gun with a seat (ground level only, nothing stacks on it).
static func is_crewed(id: StringName) -> bool:
	return is_turret(id) and turret(id).crewed


## The items of a build category by its name ([] if there's no such category).
static func category_items(cat_name: String) -> Array:
	for cat: Dictionary in BUILD_CATEGORIES:
		if cat["name"] == cat_name:
			return cat["items"]
	return []


## Mounted on the house rather than placed on the grid.
static func is_house_turret(id: StringName) -> bool:
	return is_turret(id) and turret(id).guards_house


static func cost_of(id: StringName) -> int:
	if is_turret(id):
		return turret(id).cost_scrap
	if STRUCTURES.has(id):
		return structure(id).cost_scrap
	return 0


static func name_of(id: StringName) -> String:
	if is_turret(id):
		return turret(id).display_name
	if STRUCTURES.has(id):
		return structure(id).display_name
	return String(id)


# ------------------------------------------------------------------ tier step-up

## Each turret's next tech tier (Early -> Mid -> Late in the same role). A built
## turret can be swapped for it in place (Y in build mode) for TIER_UP_RATE of the
## new turret's price, keeping its upgrade tier, scaffold level and health.
## Turret ammo: lines never cross tracks, a self-powered turret steps up to a
## self-powered one and a crop-fed one to one fed by the same crop.
## Lines never change kind either (Logan): a cliff turret steps up to a cliff
## turret, a last resort to a last resort, anti-air to anti-air, a house gun to a
## house gun (kind_of). The Sharpshooter Tower, Firework Battery and Net Thrower
## stand on their own.
const TIER_UP: Dictionary = {
	# Self-powered.
	&"gatling_post": &"repeater_post", &"repeater_post": &"brass_gatling",
	&"buffalo_rifle": &"big_fifty", &"big_fifty": &"long_tom_rifle",
	&"scattergun_post": &"buck_blaster", &"buck_blaster": &"grapeshot_turret",
	&"porch_repeater": &"rooftop_cannon", &"rooftop_cannon": &"gatling_porch",
	&"duck_gun": &"skeet_post", &"skeet_post": &"flak_porch",
	&"sky_sweeper": &"powder_flak", &"twin_gatling": &"brass_gatling",
	# Crop-fed.
	&"corn_hopper": &"twin_hopper", &"twin_hopper": &"hornets_nest",
	&"chili_mortar": &"pepper_sprayer", &"pepper_sprayer": &"twin_mortar",
	&"dynamite_lobber": &"sulfur_fume_vent", &"sulfur_fume_vent": &"brimstone_bellows",
	&"water_cannon": &"steam_cannon", &"steam_cannon": &"flood_gate",
	&"lasso_harpoon": &"bola_launcher", &"bola_launcher": &"cotton_bale_cannon",
	&"herb_rifle": &"elephant_battery", &"elephant_battery": &"rail_spike_driver",
	&"tripwire_fence": &"bramble_bomb", &"bramble_bomb": &"dust_devil_trap",
}
## Stepping up costs this share of building the higher tier outright.
const TIER_UP_RATE := 0.85


## What a turret is for, which a step-up never changes: &"cliff" (shoots the
## far wall), &"last_resort" (guards your own plateau), &"air" or &"house".
static func kind_of(id: StringName) -> StringName:
	var d := turret(id)
	if d == null:
		return &""
	if d.anti_air:
		return &"air"
	if d.guards_house:
		return &"house"
	if d.guards_plateau:
		return &"last_resort"
	return &"cliff"


## The turret `id` steps up to, or &"".
static func tier_up_of(id: StringName) -> StringName:
	var next: StringName = TIER_UP.get(id, &"")
	return next if next != &"" and TURRETS.has(next) else &""


## Scrap to step `id` up to its next tier (a bit under building that tier new).
static func tier_up_cost(id: StringName) -> int:
	var next := tier_up_of(id)
	return int(ceil(cost_of(next) * TIER_UP_RATE)) if next != &"" else -1

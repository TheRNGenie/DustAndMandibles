class_name FieldGuide
extends RefCounted
## The in-game wiki: guns, bugs, turrets and crops, shown on the MenuScreen. Stats come
## straight from the game's data files; the words come from data/field_guide.json,
## so both stay up to date and easy to edit. Open with J or from the pause menu.

const TEXT_PATH := "res://data/field_guide.json"
const BugVariantsText := preload("res://scenes/bugs/bug_variants.gd")
const BEHAVIORS := ["Swarm", "Tank", "Leaper", "Spitter", "Brood", "Burrower", "Flier", "Crop eater", "Boss"]

static var _text: Dictionary = {}


static func open() -> void:
	if MenuScreen.instance != null:
		MenuScreen.instance.open(FieldGuide.new())


static func text() -> Dictionary:
	if _text.is_empty():
		var f := FileAccess.open(TEXT_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_text = parsed
	return _text


static func entry(section: String, id: StringName) -> Dictionary:
	var sec: Dictionary = text().get(section, {})
	return sec.get(String(id), {})


func menu_title() -> String:
	return "Field Guide"


func menu_tagline() -> String:
	return "Everything a rancher should know about their irons, their defences, and what climbs the canyon."


func menu_tabs() -> Array:
	return ["Guns", "Bugs", "Turrets", "Crops", "Basics", "Journal", "Canyon Floor"] # Story: Doc Whitlow's journal pages; Expeditions: the raid sites


func menu_items(tab: int) -> Array:
	var out: Array = []
	match tab:
		0:
			for id: StringName in Gun.ORDER:
				var w := Gun.weapon(id)
				var e := FieldGuide.entry("guns", id)
				var price := "Starter" if w.price_chitin == 0 else UiStyle.cost(w.price_chitin, "chitin")
				# Its numbers in the stat chart on the right (Logan), the same chart as the gunsmith's.
				var gd := _item(id, w.display_name, id, str(e.get("lore", w.description)), "", e.get("tips", []), price)
				gd["chart"] = StatChart.weapon(w)
				out.append(gd)
		1:
			var bugs: Array = Defs.active_bug_ids()
			bugs.sort_custom(func(a: StringName, b: StringName) -> bool: return Defs.bug(a).first_wave < Defs.bug(b).first_wave)
			for id: StringName in bugs:
				var b := Defs.bug(id)
				var e := FieldGuide.entry("bugs", id)
				var stats := "%s  ·  %d HP  ·  Climbs %.1f m/s  ·  %s%s  ·  Drops %s%s" % [
						UiStyle.tc(str(BEHAVIORS[b.behavior])), int(b.max_hp), b.climb_speed,
						("Front Armour %d%%  ·  " % int(b.front_armor * 100.0)) if b.front_armor > 0.0 else "",
						"Story Only" if b.story_only else "From Wave %d" % b.first_wave, UiStyle.cost(int(EconomyLedger.kill_pay(b.scrap_drop, b.chitin_drop)[&"scrap"]), "scrap"), " (Team Pot)"]
				var icon: Variant = IconStudio.bug(MenuScreen.instance, id) if MenuScreen.instance != null else null
				if UiStyle.plate(id) != null:
					icon = UiStyle.plate(id) # the painted plate
				# (Bugs helper) The counter, and the variants overusing one method brings.
				var tips: Array = []
				if b.counter != "":
					tips.append("Counter: " + b.counter)
				tips.append_array(e.get("tips", []))
				if BugVariantsText.can_vary(id, &"bullet"):
					tips.append(BugVariantsText.summary())
				out.append(_item(id, b.display_name, icon, str(e.get("lore", "")), stats, tips, ""))
		2:
			for id: StringName in Defs.BUILD_ORDER:
				if not Defs.is_turret(id) or Defs.RETIRED_TURRETS.has(id): # (the old crop-specific turrets are gone)
					continue
				var t := Defs.turret(id)
				var e := FieldGuide.entry("turrets", id)
				var icon: Variant = IconStudio.turret(MenuScreen.instance, id) if MenuScreen.instance != null else null
				var tips: Array = (e.get("tips", []) as Array).duplicate()
				if t.universal: # Universal crop-fed: any crop, and what each does
					tips.append("Takes any crop sack: Q on it picks one, E reloads the last. One sack lasts a wave%s." % (
							" (an obstruction keeps its sack until it goes off)" if t.obstruction else ""))
					tips.append("Tier 2 from wave 5, Tier 3 from wave 10 (U on it): more damage, faster, stronger crop.")
				var td := _item(id, t.display_name, icon, str(e.get("lore", t.description)), "", tips, UiStyle.cost(t.cost_scrap, "scrap"))
				td["chart"] = StatChart.turret(t) # the same chart as the build menu's
				out.append(td)
			# Hive amber turrets: crafted from amber and parts once the blueprint is known, one of each per team.
			for id: StringName in AmberRules.IDS:
				var t := Defs.turret(id)
				var e := FieldGuide.entry("turrets", id)
				var icon: Variant = IconStudio.turret(MenuScreen.instance, id) if MenuScreen.instance != null else null
				var ad := _item(id, t.display_name, icon, str(e.get("lore", t.description)), "", e.get("tips", []), UiStyle.cost(AmberRules.amber_cost(id), "amber") + " + Parts")
				ad["chart"] = StatChart.amber(t)
				out.append(ad)
		3:
			# (Gameplay helper) Each crop has a job; the numbers come from the crop data.
			for id: StringName in CROP_ORDER:
				var c := Defs.crop(id)
				var e := FieldGuide.entry("crops", id)
				var yields: PackedStringArray = []
				for r: StringName in c.harvest:
					yields.append(UiStyle.cost(int(c.harvest[r]), String(r)))
				var sells: PackedStringArray = []
				for r: StringName in c.harvest:
					if MarketPrices.BASE.has(r):
						sells.append(UiStyle.cost(MarketPrices.BASE[r], String(MarketPrices.currency(r))) + " Each")
				var stats := "Ripe in %s  ·  %d Water  ·  Harvest %s  ·  %s" % [
						_minutes(c.grow_time), c.water_cost, ", ".join(yields),
						("Sells for " + ", ".join(sells)) if not sells.is_empty() else "Not Sold: Grown for Your Partner"]
				var tips: Array = [c.role] if c.role != "" else []
				tips.append_array(e.get("tips", []))
				var crop_icon: Variant = c.harvest.keys()[0] if not c.harvest.is_empty() else null
				if UiStyle.plate(id) != null:
					crop_icon = UiStyle.plate(id) # the painted plate
				out.append(_item(id, c.display_name, crop_icon, str(e.get("lore", "")), stats, tips, UiStyle.cost(MarketPrices.seed_price(c), "scrap") + " a Seed"))
		4:
			# Plain-words help: how the team's money works, and the other basics.
			var basics: Dictionary = text().get("basics", {})
			for key: Variant in basics:
				var e: Dictionary = basics[key]
				var stats := str(e.get("stats", ""))
				if str(key) == "grapple_dynamite": # the numbers from the rules, not the text
					stats = "%s at the gunsmith (Upgrades)  ·  %d damage in %s m, less at the edge  ·  %d bundles, one back every %d s up top" % [
							UiStyle.cost(DynamiteRules.SATCHEL_COST, "chitin"), int(DynamiteRules.DAMAGE), str(DynamiteRules.RADIUS), DynamiteRules.MAX_BUNDLES, int(DynamiteRules.RESTOCK_SECS)]
				out.append(_item(StringName(str(key)), str(e.get("title", key)), StringName(str(e["icon"])) if e.has("icon") else null, str(e.get("lore", "")), stats, e.get("tips", []), ""))
		5:
			# Story: one page per chapter won (StoryScreen.journal_pages), the rest torn out.
			for v: Array in StoryScreen.journal_pages():
				var n := int(v[3])
				var doc: Variant = StoryPortrait.face_texture(MenuScreen.instance, "doc") if MenuScreen.instance != null and bool(v[2]) else null
				out.append({"id": "journal_%d" % n, "name": str(v[0]), "icon": doc, "desc": str(v[1]),
						"price": "Chapter %d" % n if bool(v[2]) else "Not Yet", "price_ok": bool(v[2])})
		6:
			out.append_array(_floor_items())
	return out


## Canyon Expeditions: the raid sites and what you bring up from them.
const SITE_ICONS: Array[StringName] = [&"chitin", &"trophy", &"blueprint", &"egg", &"scrap"]


func _floor_items() -> Array:
	var out: Array = []
	for kind in SitePlan.KIND_IDS.size():
		var id := SitePlan.KIND_IDS[kind]
		var e := FieldGuide.entry("sites", id)
		var loot := SitePlan.totals(SitePlan.loot_for(kind, 1, 1))
		var finds: PackedStringArray = []
		for k: StringName in loot:
			var n := SitePlan.item_name(k) if k != &"scrap" and k != &"chitin" else ResNames.of(k).capitalize()
			if not finds.has(n) and not CraftTable.is_part(k):
				finds.append(n)
			elif CraftTable.is_part(k) and not finds.has("Turret Parts"):
				finds.append("Turret Parts")
		var sleepers: PackedStringArray = []
		for sl: Array in SitePlan.sleepers_for(kind, 1, 1):
			var bn := Defs.bug(StringName(sl[0])).display_name
			if not sleepers.has(bn):
				sleepers.append(bn)
		var stats := "Finds: %s  ·  Sleeping: %s  ·  Refills Every Build Phase" % [", ".join(finds), ", ".join(sleepers)]
		var icon: Variant = IconStudio.site_loot(MenuScreen.instance, SITE_ICONS[kind]) if MenuScreen.instance != null else null
		out.append(_item(id, SitePlan.NAMES[kind], icon, str(e.get("lore", "")), stats, e.get("tips", []), ""))
	# Hive amber (AmberRules): the floor's rarest find.
	var ae := FieldGuide.entry("sites", AmberRules.ITEM)
	var amber_icon: Variant = IconStudio.site_loot(MenuScreen.instance, &"amber") if MenuScreen.instance != null else null
	out.append(_item(AmberRules.ITEM, AmberRules.NAME, amber_icon, str(ae.get("lore", "")), "Backpack Weight %d a Chip  ·  Yours Alone" % AmberRules.WEIGHT, ae.get("tips", []), ""))
	for k: StringName in [SitePlan.NEST_EGG, SitePlan.SPECIMEN, SitePlan.JOURNAL_PAGE]:
		var e := FieldGuide.entry("sites", k)
		var look: StringName = {SitePlan.NEST_EGG: &"egg", SitePlan.SPECIMEN: &"specimen", SitePlan.JOURNAL_PAGE: &"page"}[k]
		var icon: Variant = IconStudio.site_loot(MenuScreen.instance, look) if MenuScreen.instance != null else null
		var price := UiStyle.cost(MarketPrices.BASE[k], String(MarketPrices.currency(k))) + " Each" if MarketPrices.BASE.has(k) else ""
		out.append(_item(k, SitePlan.item_name(k), icon, str(e.get("lore", "")), "", e.get("tips", []), price))
	return out


const CROP_ORDER: Array[StringName] = [&"corn", &"prickly_pear", &"firecracker_chili", &"herbs", &"sarsaparilla"]


static func _minutes(secs: float) -> String:
	var m := int(secs) / 60
	var s := int(secs) % 60
	return "%d min" % m if s == 0 else "%d min %d s" % [m, s]


func _item(id: StringName, title: String, icon: Variant, lore: String, stats: String, tips: Array, price: String) -> Dictionary:
	var lines: PackedStringArray = []
	if lore != "":
		lines.append(lore)
	if stats != "":
		lines.append(UiStyle.keep_together(stats)) # wraps only between stat chunks
	for t: Variant in tips:
		lines.append("•  " + str(t))
	var d := {"id": id, "name": title, "icon": icon, "desc": "\n".join(lines), "price": price, "price_ok": true}
	if icon is Texture2D and (icon as Texture2D).resource_path.begins_with("res://assets/plates/"):
		d["icon_px"] = 150.0 # the painted plate, big enough to see
	return d


func menu_press(_id: Variant, _action: StringName) -> void:
	pass

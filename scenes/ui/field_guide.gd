class_name FieldGuide
extends RefCounted
## The in-game wiki: guns, bugs and turrets, shown on the MenuScreen. Stats come
## straight from the game's data files; the words come from data/field_guide.json,
## so both stay up to date and easy to edit. Open with J or from the pause menu.

const TEXT_PATH := "res://data/field_guide.json"
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
	return ["Guns", "Bugs", "Turrets"]


func menu_items(tab: int) -> Array:
	var out: Array = []
	match tab:
		0:
			for id: StringName in Gun.ORDER:
				var w := Gun.weapon(id)
				var e := FieldGuide.entry("guns", id)
				var stats := "Damage %d%s   |   %d rounds   |   %.1f s reload   |   %s" % [int(w.damage),
						(" x%d pellets" % w.pellets) if w.pellets > 1 else "", w.mag_size, w.reload_time,
						"pierces armour" if w.pierce_armor else "stopped by armour"]
				var price := "starter" if w.price_chitin == 0 else "%d chitin" % w.price_chitin
				out.append(_item(id, w.display_name, id, str(e.get("lore", w.description)), stats, e.get("tips", []), price))
		1:
			var bugs: Array = Defs.BUGS.keys()
			bugs.sort_custom(func(a: StringName, b: StringName) -> bool: return Defs.bug(a).first_wave < Defs.bug(b).first_wave)
			for id: StringName in bugs:
				var b := Defs.bug(id)
				var e := FieldGuide.entry("bugs", id)
				var stats := "%s   |   %d HP   |   climbs %.1f m/s   |   %sfrom wave %d   |   drops %d scrap%s" % [
						BEHAVIORS[b.behavior], int(b.max_hp), b.climb_speed,
						("front armour %d%%   |   " % int(b.front_armor * 100.0)) if b.front_armor > 0.0 else "",
						b.first_wave, b.scrap_drop, (", %d chitin" % b.chitin_drop) if b.chitin_drop > 0 else ""]
				var icon: Variant = IconStudio.bug(MenuScreen.instance, id) if MenuScreen.instance != null else null
				out.append(_item(id, b.display_name, icon, str(e.get("lore", "")), stats, e.get("tips", []), ""))
		2:
			for id: StringName in Defs.BUILD_ORDER:
				if not Defs.is_turret(id):
					continue
				var t := Defs.turret(id)
				var e := FieldGuide.entry("turrets", id)
				var stats := "%d damage every %.2f s   |   range %d m   |   %d HP%s" % [int(t.damage), t.fire_interval, int(t.range), int(t.max_hp),
						"   |   pierces armour" if t.armor_pierce else ""]
				var icon: Variant = IconStudio.turret(MenuScreen.instance, id) if MenuScreen.instance != null else null
				out.append(_item(id, t.display_name, icon, str(e.get("lore", t.description)), stats, e.get("tips", []), "%d scrap" % t.cost_scrap))
	return out


func _item(id: StringName, title: String, icon: Variant, lore: String, stats: String, tips: Array, price: String) -> Dictionary:
	var lines: PackedStringArray = []
	if lore != "":
		lines.append(lore)
	lines.append(stats)
	for t: Variant in tips:
		lines.append("- " + str(t))
	return {"id": id, "name": title, "icon": icon, "desc": "\n".join(lines), "price": price, "price_ok": true}


func menu_press(_id: Variant, _action: StringName) -> void:
	pass

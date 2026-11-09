class_name StatChart
extends RefCounted
## The stat chart (Logan, Nov 2026): a weapon's or turret's numbers as a ledger,
## one row a stat with the figure on the right and a bar that compares it with
## the rest of its kind, then "Special Characteristics" at the bottom: what it
## does besides hitting. The same chart on the gunsmith, the build menu, the
## workshop, Lucky's stall and the Field Guide, so every gun and turret reads
## the same way.
##
## Data: {"title": String, "kind": String, "rows": [[label, value, bar]], "special": [String]}
## where bar is 0-1 (how it compares) or -1 for no bar. A value may carry the
## next step after an arrow ("30 › 36") for an upgrade.

const NO_BAR := -1.0
## The chart column's width on the menu screens.
const WIDTH := 330.0
const ARROW := "  ›  "
## The stat names' column.
const LABEL_W := 92.0


# ------------------------------------------------------------------ weapons

## A gun's chart. `code` is your copy's level and mods (-1 = off the shelf);
## `next_level` shows an upgrade's step on the numbers it changes.
static func weapon(w: WeaponDef, code: int = -1, next_level: int = -1) -> Dictionary:
	var id := w.id
	var level := WeaponMods.level(code) if code >= 0 else 0
	var have := maxi(code, 0)
	var top := _weapon_tops(Gun.slot_of(id) if Gun.weapon(id) != null else int(w.slot))
	var rows: Array = []
	rows.append(["Slot", Gun.SLOT_NAMES[clampi(int(w.slot), 0, 2)], NO_BAR])
	if w.role != "":
		rows.append(["Role", UiStyle.tc(w.role), NO_BAR])
	var dmg_k := WeaponMods.mult(id, have, "damage")
	var pellets := w.pellets + WeaponMods.add(id, have, "pellets")
	var dmg := w.damage * GunRarity.damage_mult(level) * dmg_k
	if w.damage <= 0.0:
		rows.append(["Damage", "None", 0.0])
	else:
		var dv := _dmg_text(w, dmg, pellets)
		if next_level > level:
			dv += ARROW + _dmg_text(w, w.damage * GunRarity.damage_mult(next_level) * dmg_k, pellets)
		rows.append(["Damage", dv, dmg * pellets / maxf(top["damage"], 0.01)])
	var every := w.fire_interval * WeaponMods.mult(id, have, "fire_interval")
	if w.damage > 0.0 and every > 0.0:
		rows.append(["Fire Rate", _rate_text(every), (1.0 / every) / maxf(top["rate"], 0.01)])
	var mag := w.mag_size + WeaponMods.add(id, have, "mag")
	rows.append([_mag_label(w), _mag_text(w, mag), NO_BAR])
	var reload := w.reload_time * GunRarity.reload_mult(level) * WeaponMods.mult(id, have, "reload")
	if w.special == &"smoke" or (w.automatic and w.damage <= 0.0 and w.reload_time <= 0.0):
		rows.append(["Reload", "Refills Itself", NO_BAR])
	elif reload > 0.0:
		var rv := "%s s" % _f1(reload)
		if next_level > level:
			rv += ARROW + "%s s" % _f1(w.reload_time * GunRarity.reload_mult(next_level) * WeaponMods.mult(id, have, "reload"))
		rows.append(["Reload", rv, NO_BAR])
	var reach := w.range * WeaponMods.mult(id, have, "range")
	rows.append(["Range", "%d m" % int(reach), reach / maxf(top["range"], 0.01)])
	return {"title": w.display_name, "kind": "%s Weapon" % Gun.SLOT_NAMES[clampi(int(w.slot), 0, 2)],
		"rows": rows, "special": weapon_specials(w, code)}


## What a gun does besides its numbers, for the chart's bottom.
static func weapon_specials(w: WeaponDef, code: int = -1) -> PackedStringArray:
	var out: PackedStringArray = []
	var id := w.id
	if SpecialRules.BASE.has(id): # the special weapons' base effect
		out.append("%s: %s" % [SpecialRules.BASE[id], SpecialRules.BASE_TEXT.get(id, "")])
	if GUN_SPECIALS.has(w.special):
		out.append(GUN_SPECIALS[w.special])
	if w.damage > 0.0:
		out.append("Pierces Armour" if w.pierce_armor else "Stopped by Armour")
	if w.crop_ammo:
		out.append("Loads Any Crop Sack: %d Shots a Sack, Kept Between Waves" % w.mag_size)
	elif w.crop != &"":
		var c := Defs.crop(w.crop)
		out.append("Fed with %s Loads: %d Rounds a Load" % [c.display_name if c != null else String(w.crop), w.shots_per_harvest])
	if w.falloff_start < w.range:
		out.append("Weaker Past %d m" % int(w.falloff_start))
	if w.weak_bonus > 1.0:
		out.append("Weak Spots x%s" % String.num(WeakSpot.MULTIPLIER * w.weak_bonus, 1).trim_suffix(".0"))
	if w.automatic and w.damage > 0.0:
		out.append("Hold to Fire" + (", Spins Up in %s s" % _f1(w.spin_up) if w.spin_up > 0.0 else ""))
	if w.suppress_slow < 1.0 and w.suppress_time > 0.0:
		out.append("Slows Bugs It Hits for %s s" % _f1(w.suppress_time))
	if w.kickback > 0.0:
		out.append("Kicks You Back on Every Shot")
	if w.draw_speed > 1.05:
		out.append("Quick to Draw")
	if code >= 0:
		var fitted := WeaponMods.names(id, code)
		if fitted != "":
			out.append("Fitted: %s" % fitted)
	return out


## The old frontier guns' specials (GunRules), one line each.
const GUN_SPECIALS: Dictionary = {&"harpoon": "Reels Small Bugs In, Pulls You to Big Ones and Walls",
	&"flare": "Marks a Bug for Every Turret", &"salt": "Climbers Lose Their Grip",
	&"smoke": "Makes Fliers and Spiders Drowsy"}


static func _dmg_text(w: WeaponDef, dmg: float, pellets: int) -> String:
	var t := TurretDef._num(snappedf(dmg, 0.1))
	if pellets > 1:
		t += " x%d" % pellets
	if w.special in [&"mortar", &"rocket", &"uh_mortar", &"uh_drum", &"uh_keg"]:
		t += " Splash"
	elif w.special == &"uh_spray":
		t += " a Pump"
	elif w.automatic and w.crop != &"":
		t += " a Puff"
	return t


static func _mag_label(w: WeaponDef) -> String:
	if _endless(w):
		return "Ammo"
	if w.special == &"smoke" or (w.automatic and (w.damage <= 0.0 or w.crop != &"")):
		return "Lasts"
	return "Magazine"


## Primaries and specials never run dry: a magazine, then reloads for ever
## (Logan: "Mag Size / Infinite"). Heavies feed on crop sacks.
static func _endless(w: WeaponDef) -> bool:
	return int(w.slot) != int(WeaponDef.Slot.HEAVY) and w.crop == &"" and not w.crop_ammo


static func _mag_text(w: WeaponDef, mag: int) -> String:
	if _endless(w):
		var size := "%d s" % roundi(mag * w.fire_interval) if w.special == &"smoke" or (w.automatic and w.damage <= 0.0) else str(mag)
		return "%s / Infinite" % size
	if w.special == &"smoke":
		return "%d s of Smoke" % roundi(mag * w.fire_interval)
	if w.automatic and w.damage <= 0.0:
		return "%d s of Spray" % roundi(mag * w.fire_interval)
	if w.automatic and w.crop != &"":
		return "%d s a Load" % roundi(w.shots_per_harvest * w.fire_interval)
	if w.crop_ammo:
		return "%d a Sack" % mag
	return "%d Round%s" % [mag, "" if mag == 1 else "s"]


## The best damage (a whole shot), fire rate and range among the guns sold for
## one slot: the bars' full length.
static var _tops: Dictionary = {}


static func _weapon_tops(slot: int) -> Dictionary:
	if _tops.has(slot):
		return _tops[slot]
	var t := {"damage": 1.0, "rate": 1.0, "range": 1.0}
	for gid: StringName in Gun.ORDER:
		var w := Gun.weapon(gid)
		if w == null or Gun.slot_of(w.id) != slot or Defs.is_retired(w.id):
			continue
		t["damage"] = maxf(t["damage"], w.damage * maxi(w.pellets, 1))
		if w.fire_interval > 0.0 and w.damage > 0.0:
			t["rate"] = maxf(t["rate"], 1.0 / w.fire_interval)
		t["range"] = maxf(t["range"], w.range)
	_tops[slot] = t
	return t


# ------------------------------------------------------------------ turrets

## A turret's chart at an upgrade tier.
static func turret(d: TurretDef, upgrade: int = 0) -> Dictionary:
	var top := _turret_tops(d.id)
	var rows: Array = []
	var dmg := d.damage_at(upgrade)
	if d.special == TurretDef.SPECIAL_LANCE:
		rows.append(["Beam", "%s Damage/s" % TurretDef._num(dmg), dmg / maxf(top["damage"], 0.01)])
	else:
		rows.append(["Damage", TurretDef._num(dmg), dmg / maxf(top["damage"], 0.01)])
	var every := d.interval_at(upgrade)
	if d.special == TurretDef.SPECIAL_BELL:
		rows.append(["Tolls", "Every %s s" % TurretDef._num(every), NO_BAR])
	elif d.special != TurretDef.SPECIAL_LANCE and every > 0.0:
		rows.append(["Fire Rate", d.rate_text(upgrade), (1.0 / every) / maxf(top["rate"], 0.01)])
	var reach := d.range_at(upgrade)
	rows.append(["Range", "%d m" % int(roundf(reach)), reach / maxf(top["range"], 0.01)])
	rows.append(["Health", "%d HP" % int(d.max_hp), d.max_hp / maxf(top["hp"], 0.01)])
	if d.cone_deg > 0.0 and not d.anti_air:
		rows.append(["Aim", "%d° Cone" % int(d.cone_deg), NO_BAR])
	rows.append(["Ammo", _ammo_text(d), NO_BAR])
	rows.append(["Tier", d.era_name() + ("" if d.tier == 0 else " (Wave %d)" % d.unlock_wave()), NO_BAR])
	if d.role != "":
		rows.append(["Best Against", _sentence(d.role), NO_BAR])
	if d.weakness != "":
		rows.append(["Weak Against", _sentence(d.weakness), NO_BAR])
	var kind := "Turret"
	if d.crewed:
		kind = "Crewed Gun"
	elif d.anti_air:
		kind = "Air Defense"
	elif d.obstruction:
		kind = "Crop-Fed Trap"
	elif d.universal:
		kind = "Crop-Fed Turret"
	return {"title": d.display_name, "kind": kind, "rows": rows, "special": turret_specials(d, upgrade)}


## Walls, traps and the like (the build menu): their toughness, and reach for
## traps and lights. No Special Characteristics: they don't shoot.
static func structure(d: StructureDef) -> Dictionary:
	if d == null:
		return {}
	var rows: Array = [["Health", "%s HP" % TurretDef._num(d.max_hp), NO_BAR]]
	match d.kind:
		StructureDef.Kind.BARBED_WIRE, StructureDef.Kind.BEAR_TRAP, StructureDef.Kind.DYNAMITE_CRATE:
			rows.append(["Reach", "%s m" % TurretDef._num(d.radius), NO_BAR])
		StructureDef.Kind.LANTERN:
			rows.append(["Lights", "%s m" % TurretDef._num(d.radius), NO_BAR])
	return {"title": d.display_name, "rows": rows, "special": [], "plain": true}


## A hive amber turret's chart: a turret's, plus where its blueprint turns up.
static func amber(d: TurretDef) -> Dictionary:
	var data := turret(d)
	data["kind"] = "Hive Amber Turret"
	var sp: PackedStringArray = data["special"]
	sp.append("Blueprint Found in %s" % str(AmberRules.FOUND_IN.get(d.id, "the Canyon")))
	sp.append("Crafted at the Workshop: the Team Fields One")
	data["special"] = sp
	return data


## What a turret does besides hitting, for the chart's bottom.
static func turret_specials(d: TurretDef, upgrade: int = 0) -> PackedStringArray:
	var out := d.special_parts(upgrade, false)
	if d.universal and not d.obstruction:
		out.append("Hits with the Loaded Crop's Effect")
	elif d.obstruction:
		out.append("Goes Off Once with the Loaded Crop's Effect")
	if d.universal and d.heavy_gun:
		out.append("Heavy Gun: Ignores the Light Bugs' Dodge")
	if d.burst > 1:
		out.append("Fires in Bursts of %d" % d.burst)
	return out


static func _ammo_text(d: TurretDef) -> String:
	if d.universal and d.obstruction:
		return "1 Crop Sack, Once"
	if d.universal:
		return "1 Crop Sack a Wave"
	if d.crop_type != &"":
		return "1 %s Load a Wave" % d.crop_name()
	if d.has_upkeep():
		return "%s a Shot" % d.upkeep_text().capitalize()
	return "None: Always Fires"


## The best damage, fire rate, range and health among the turrets of its build
## tab (every turret for the ones that sit in none): the bars' full length.
static func _turret_tops(id: StringName) -> Dictionary:
	var pool: Array = []
	for tab: Dictionary in Defs.build_tabs():
		if (tab["items"] as Array).has(id):
			pool = tab["items"]
			break
	if pool.is_empty():
		pool = Defs.TURRETS.keys()
	var key := "t:%s" % str(pool.hash())
	if _tops.has(key):
		return _tops[key]
	var t := {"damage": 1.0, "rate": 1.0, "range": 1.0, "hp": 1.0}
	for tid: Variant in pool:
		if not Defs.is_turret(StringName(tid)):
			continue
		var d := Defs.turret(StringName(tid))
		if d.special != TurretDef.SPECIAL_LANCE:
			t["damage"] = maxf(t["damage"], d.damage)
		if d.fire_interval > 0.0 and d.special != TurretDef.SPECIAL_BELL:
			t["rate"] = maxf(t["rate"], 1.0 / d.fire_interval)
		t["range"] = maxf(t["range"], d.range)
		t["hp"] = maxf(t["hp"], d.max_hp)
	_tops[key] = t
	return t


# ------------------------------------------------------------------ the chart

## The chart as a control. `with_title` puts the name and kind on top (the menu
## screens' side column; the build menu's card has its own).
static func build(data: Dictionary, with_title: bool = true) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if with_title and str(data.get("title", "")) != "":
		var kind := str(data.get("kind", ""))
		if kind != "":
			box.add_child(UiStyle.eyebrow(kind, 12))
		var t := UiStyle.label(UiStyle.tc(str(data["title"])), 22)
		t.add_theme_font_override("font", UiStyle.font("bold"))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(t)
		box.add_child(_gap(8))
	var rows: Array = data.get("rows", [])
	if not rows.is_empty():
		box.add_child(UiStyle.section("Stats"))
		for i in rows.size():
			box.add_child(_row(rows[i] as Array, i % 2 == 0))
		box.add_child(_gap(12))
	var special: Array = Array(data.get("special", []))
	if not bool(data.get("plain", false)): # (plain: a row with no numbers, just its words)
		box.add_child(UiStyle.section("Special Characteristics"))
		if special.is_empty():
			var none := UiStyle.note("None: it just shoots.", 14)
			none.theme_type_variation = "FaintLabel"
			box.add_child(none)
		for s: Variant in special:
			box.add_child(_trait(str(s)))
	if str(data.get("note", "")) != "":
		if not bool(data.get("plain", false)):
			box.add_child(_gap(10))
		box.add_child(UiStyle.note(str(data["note"]), 14))
	return box


## One ledger line on a single line: the stat on the left, its bar in the
## middle, the figure on the right. Rows without a bar give the figure the room.
static func _row(r: Array, shaded: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiStyle.c("ink"), 0.06) if shaded else Color(0, 0, 0, 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var l := UiStyle.label(str(r[0]), 14)
	l.theme_type_variation = "SoftInkLabel"
	l.add_theme_font_override("font", UiStyle.font("label"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = LABEL_W
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(l)
	var frac := float(r[2]) if r.size() > 2 else NO_BAR
	var val := str(r[1])
	var numeric := val.substr(0, 1).is_valid_int()
	var vl := UiStyle.label(val, 16 if numeric else 14)
	vl.add_theme_font_override("font", UiStyle.font("number" if numeric else "bold"))
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if frac >= 0.0:
		# How it compares: the square root of its share of the best, so the small
		# ones still show and the order holds.
		var m := Meter.new()
		m.frac = sqrt(clampf(frac, 0.0, 1.0))
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(m)
		vl.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(vl)
	return p


## A Special Characteristics line: a small diamond, then the words.
static func _trait(text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d := Diamond.new()
	h.add_child(d)
	var l := UiStyle.label(text, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h


static func _gap(px: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size.y = px
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


static func _rate_text(every: float) -> String:
	return ("%s Shots/s" % TurretDef._num(snappedf(1.0 / every, 0.1))) if every < 1.0 else ("1 Shot / %s s" % TurretDef._num(snappedf(every, 0.1)))


## "swarms of small bugs" -> "Swarms of small bugs".
static func _sentence(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1) if t != "" else t


static func _f1(v: float) -> String:
	return String.num(v, 1).trim_suffix(".0") if v >= 1.0 else String.num(v, 2)


## A thin comparison bar: a dark trough, filled in the set's accent.
class Meter extends Control:
	var frac := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(36, 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		var w := maxf(size.x * frac, 3.0)
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, size.y)), UiStyle.c("accent"))
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, 1.0)), Color(1, 1, 1, 0.25))


## The bullet before a Special Characteristics line.
class Diamond extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(8, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(4, 10)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]),
				UiStyle.c("accent"))

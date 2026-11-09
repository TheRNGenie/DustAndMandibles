class_name KeyHints
extends RefCounted
## Keycap chips ("[E] Plant") and the clean prompt card layout shared by the
## build bar, the build menu and every interaction prompt. Key names come from
## the live input map, so rebinding a key updates the hints.

const CHIP_FONT := 14
const TEXT_FONT := 15

## Matches "E: ", "LMB: ", "Hold E: ", "Right click: " inside prompt text.
static var _key_re: RegEx


## The current key (or mouse button) bound to an input action, short form.
static func key_for(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for ev: InputEvent in InputMap.action_get_events(action):
		var mb := ev as InputEventMouseButton
		if mb != null:
			match mb.button_index:
				MOUSE_BUTTON_LEFT: return "LMB"
				MOUSE_BUTTON_RIGHT: return "RMB"
				MOUSE_BUTTON_MIDDLE: return "MMB"
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN: return "Wheel"
		var k := ev as InputEventKey
		if k != null:
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return OS.get_keycode_string(code)
	return "?"


## A keycap: a dark key with a lit top edge and a deep bottom lip, the key's
## name in the kit's bold condensed face. Follows the UI set live.
static func chip(key: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", kit_box("key"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = key
	l.theme_type_variation = "InkLabel"
	# (The number face's Q reads as a 0 on a keycap: Q gets the bold face.)
	l.add_theme_font_override("font", UiStyle.font("bold" if key.begins_with("Q") else "number"))
	l.add_theme_font_size_override("font_size", UiStyle.ts(CHIP_FONT))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(16, 18)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	p.custom_minimum_size = Vector2(28, 0)
	return p


# ------------------------------------------------------------------ the HUD kit
# Shared KitBoxes for the HUD (one instance per kind, refilled in place when the
# UI set swaps, so every control using one follows along with no per-node hooks):
#   key       a keycap
#   plate     the HUD plate (see-through grained dark, the set's metal hairline)
#   ticket    the phase plaque: a ticket with notched corners and a stitched rule
#   slot / slot_empty / slot_selected   hotbar slots
#   pill      a small count badge
#   well      a recessed icon well
#   feed      a kill-feed line (a metal bar on its left edge)
#   ribbon    the event title card

static var _kit: Dictionary = {}


static func kit_box(kind: String) -> KitBox:
	if not UiStyle.notifier.changed.is_connected(_refill_kit):
		UiStyle.notifier.changed.connect(_refill_kit)
	if not _kit.has(kind):
		_kit[kind] = KitBox.make(kit_spec(kind))
	return _kit[kind]


static func _refill_kit() -> void:
	for k: String in _kit:
		(_kit[k] as KitBox).copy_from(KitBox.make(kit_spec(k)))


## The settings of one HUD kit part in the current set.
static func kit_spec(kind: String) -> Dictionary:
	var k := UiStyle.kit()
	var round_set := int(k["corner"]) == 1
	var cut: int = KitBox.Corner.ROUND if round_set else KitBox.Corner.CUT
	var cb: float = k["cs_btn"]
	var acc := UiStyle.kc("accent")
	var hi := UiStyle.kc("accent_hi")
	var rim := UiStyle.kc("rim")
	var surf0 := UiStyle.kc("surface", UiStyle.current, 0)
	var surf1 := UiStyle.kc("surface", UiStyle.current, 1)
	var rai0 := UiStyle.kc("raised", UiStyle.current, 0)
	var rai1 := UiStyle.kc("raised", UiStyle.current, 1)
	var well := UiStyle.kc("well")
	var studs := Color(acc.darkened(0.05), 0.9) if bool(k["studs"]) else Color(0, 0, 0, 0)
	match kind:
		"key", "key_small":
			if kind == "key_small":
				return {"corner": cut, "corner_size": 3.0, "fill_top": rai0.lightened(0.04), "fill_bottom": rai1.darkened(0.3),
					"rim": rim, "rim_width": 1.2, "lip": Color(hi, 0.8), "bar_side": 2, "bar": Color(0, 0, 0, 0.55), "bar_width": 2.0, "margin": [4, 0, 4, 2]}
			return {"corner": cut, "corner_size": 5.0 if round_set else 4.0, "fill_top": rai0.lightened(0.04), "fill_bottom": rai1.darkened(0.3),
				"rim": rim, "rim_width": 1.5, "lip": Color(hi, 0.85), "bar_side": 2, "bar": Color(0, 0, 0, 0.6), "bar_width": 3.0, "margin": [7, 2, 7, 5]}
		"solid":
			var so := UiStyle.spec_for(UiStyle.current, "hud")
			so["fill_top"] = Color(surf0.darkened(0.1), 0.97)
			so["fill_bottom"] = Color(surf1.darkened(0.2), 0.98)
			so["corner_size"] = float(k["cs"])
			so["rule"] = Color(acc, 0.5)
			so["rule_inset"] = 5.0
			so["rule_dash"] = 4.0 if bool(k["stitch"]) else 0.0
			so["studs"] = studs
			so["stud_radius"] = 2.4
			so["shadow"] = Color(0, 0, 0, 0.5)
			so["shadow_offset"] = Vector2(0, 8)
			so["shadow_size"] = 16.0
			so["margin"] = [18, 14]
			return so
		"plate", "plate_tight":
			var sp := UiStyle.spec_for(UiStyle.current, "hud")
			sp["fill_top"] = Color(surf0.darkened(0.1), 0.9)
			sp["fill_bottom"] = Color(surf1.darkened(0.2), 0.94)
			sp["rule"] = Color(acc, 0.38)
			sp["shadow"] = Color(0, 0, 0, 0.35)
			sp["shadow_offset"] = Vector2(0, 3)
			sp["shadow_size"] = 6.0
			sp["margin"] = [14, 10] if kind == "plate" else [12, 6, 12, 8]
			return sp
		"ticket":
			return {"corner": KitBox.Corner.NOTCH, "corner_size": 11.0, "fill_top": Color(surf0.darkened(0.08), 0.92), "fill_bottom": Color(surf1.darkened(0.25), 0.95),
				"rim": Color(rim, 0.85), "rim_width": 1.5,
				"rule": Color(acc, 0.75), "rule_inset": 4.0, "rule_width": 1.2, "rule_dash": 5.0, "lip": Color(1, 1, 1, 0.07),
				"margin": [22, 6, 22, 7]}
		"slot", "slot_empty", "slot_selected":
			var s := {"corner": cut, "corner_size": cb, "fill_top": Color(surf0.darkened(0.12), 0.86), "fill_bottom": Color(surf1.darkened(0.3), 0.92),
				"rim": Color(rim, 0.75), "rim_width": 1.2,
				"rule": Color(acc, 0.22), "rule_inset": 3.0, "lip": Color(1, 1, 1, 0.06),
				"shadow": Color(0, 0, 0, 0.3), "shadow_offset": Vector2(0, 3), "shadow_size": 5.0, "margin": [4, 4]} # (no edge burn: ten slots, kept cheap)
			if kind == "slot_empty":
				s["fill_top"] = Color(surf0.darkened(0.2), 0.5)
				s["fill_bottom"] = Color(surf1.darkened(0.35), 0.6)
				s["rule"] = Color(acc, 0.08)
				s["lip"] = Color(1, 1, 1, 0.02)
				s["shadow"] = Color(0, 0, 0, 0.12)
			elif kind == "slot_selected":
				s["fill_top"] = Color(rai0.lightened(0.04), 0.94)
				s["fill_bottom"] = Color(rai1.darkened(0.1), 0.96)
				s["rim"] = hi
				s["rim_width"] = 2.0
				s["rule"] = Color(hi, 0.55)
				s["glow"] = Color(hi, 0.45)
				s["glow_size"] = 7.0
				s["lip"] = Color(1, 1, 1, 0.16)
				s["bar_side"] = 2
				s["bar"] = hi
				s["bar_width"] = 3.0
				s["bar_inset"] = 0.2
				s["studs"] = studs
				s["stud_radius"] = 2.0
			return s
		"pill", "pill_on":
			if kind == "pill_on":
				return {"corner": KitBox.Corner.ROUND, "corner_size": 9.0, "fill_top": Color(UiStyle.kc("deep", UiStyle.current, 0), 0.97),
					"fill_bottom": Color(UiStyle.kc("deep", UiStyle.current, 1), 0.98), "rim": hi, "rim_width": 1.5, "glow": Color(hi, 0.3), "glow_size": 4.0, "margin": [6, 0, 6, 1]}
			return {"corner": KitBox.Corner.ROUND, "corner_size": 9.0, "fill_top": Color(UiStyle.kc("deep", UiStyle.current, 0), 0.95),
				"fill_bottom": Color(UiStyle.kc("deep", UiStyle.current, 1), 0.97), "rim": Color(acc, 0.7), "rim_width": 1.0, "margin": [6, 0, 6, 1]}
		"well":
			return {"corner": cut, "corner_size": cb * 0.7, "fill_top": Color(well, 0.75), "fill_bottom": Color(well.lightened(0.05), 0.75),
				"burn": Color(0, 0, 0, 0.45), "burn_size": 4.0, "rim": Color(acc, 0.28), "rim_width": 1.0, "margin": [3, 3]}
		"feed":
			return {"corner": cut, "corner_size": 4.0, "fill_top": Color(surf0.darkened(0.15), 0.86), "fill_bottom": Color(surf1.darkened(0.3), 0.9),
				"rim": Color(rim, 0.6), "rim_width": 1.0, "bar_side": 1, "bar": acc, "bar_width": 3.0, "margin": [11, 2, 9, 3]}
		"band":
			return {"corner": KitBox.Corner.ROUND, "corner_size": 12.0, "fill_top": Color(UiStyle.kc("deep", UiStyle.current, 0), 0.62),
				"fill_bottom": Color(UiStyle.kc("deep", UiStyle.current, 1), 0.72), "margin": [22, 8, 22, 10]}
		"ribbon":
			var r := UiStyle.spec_for(UiStyle.current, "hud")
			r["fill_top"] = Color(UiStyle.kc("deep", UiStyle.current, 0), 0.9)
			r["fill_bottom"] = Color(UiStyle.kc("deep", UiStyle.current, 1), 0.94)
			r["corner_size"] = float(k["cs"])
			r["rule"] = Color(acc, 0.7)
			r["rule_inset"] = 5.0
			r["rule_width"] = 1.3
			r["rule_dash"] = 4.0 if bool(k["stitch"]) else 0.0
			r["rim"] = rim
			r["rim_width"] = 2.0
			r["studs"] = studs
			r["stud_radius"] = 2.6
			r["shadow"] = Color(0, 0, 0, 0.45)
			r["shadow_offset"] = Vector2(0, 8)
			r["shadow_size"] = 16.0
			r["margin"] = [44, 14, 44, 16]
			return r
	return {}


## A HUD plate panel (shared kit box; follows the UI set).
static func plate(kind: String = "plate") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", kit_box(kind))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Condensed capitals in the set's metal (follows the set), for the HUD.
static func eyebrow(s: String, size: int = 13) -> Label:
	var l := UiStyle.eyebrow(s, size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## A big HUD figure in the kit's condensed bold, the set's light ink.
static func number(s: String, size: int = 30) -> Label:
	var l := UiStyle.number(s, size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## HUD body text in a follow-the-set colour: light ink, or the muted one.
static func ink(s: String, size: int = 15, soft: bool = false) -> Label:
	var l := Label.new()
	l.text = s
	l.theme_type_variation = "SoftInkLabel" if soft else "InkLabel"
	l.add_theme_font_size_override("font_size", UiStyle.ts(size))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## "[key] action" as one unit.
static func hint(key: String, action: String, color: Color = Color(0, 0, 0, 0)) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# "Hold E" reads as a word and a key.
	if key.begins_with("Hold "):
		var hold := ink("Hold", TEXT_FONT, true)
		hold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(hold)
		key = key.substr(5)
	var c := chip(key)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(c)
	var t := ink(UiStyle.tc(action), TEXT_FONT) if color.a == 0.0 else text(UiStyle.tc(action), TEXT_FONT, color)
	t.add_theme_font_override("font", UiStyle.font("bold"))
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	return h


## A row of hints, centred: pairs of [key, action].
static func row(pairs: Array) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", 18)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p: Array in pairs:
		r.add_child(hint(str(p[0]), str(p[1])))
	return r


static func text(s: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", UiStyle.ts(size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The card's frame: the theme set's HUD card (UiStyle.hud_flat).
static func card_style() -> StyleBoxFlat:
	var sb := UiStyle.hud_flat() # Theme
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 9
	return sb


## Splits a prompt like "Corn seedling - E: water it (1 water)   F: change seed"
## into {"title": [lines without keys], "keys": [[key, action], ...]}.
static func parse(prompt: String) -> Dictionary:
	if _key_re == null:
		_key_re = RegEx.new()
		_key_re.compile("(?:^|\\s)((?:Hold )?(?:[A-Z0-9]|LMB|RMB|MMB|Wheel|Space|Shift|Tab|Left click|Right click)):\\s")
	var titles: Array[String] = []
	var keys: Array = []
	for line: String in prompt.split("\n"):
		line = line.strip_edges()
		if line == "":
			continue
		var found := _key_re.search_all(line)
		if found.is_empty():
			titles.append(_title_head(line))
			continue
		var head := line.substr(0, found[0].get_start()).strip_edges().trim_suffix("-").trim_suffix(":").strip_edges()
		if head != "":
			titles.append(_title_head(head))
		for i in found.size():
			var m: RegExMatch = found[i]
			var end := found[i + 1].get_start() if i + 1 < found.size() else line.length()
			var action := line.substr(m.get_end(), end - m.get_end()).strip_edges().trim_suffix("-").strip_edges()
			var key := m.get_string(1).replace("Left click", "LMB").replace("Right click", "RMB")
			keys.append([key, UiStyle.tc(action)])
	return {"title": titles, "keys": keys}


## A prompt title's name in Title Case ("Corn seeds: 3" -> "Corn Seeds: 3"); the
## words after its colon (a count or a state) stay as written.
static func _title_head(line: String) -> String:
	var i := line.find(":")
	if i <= 0 or i > 32:
		return line
	return UiStyle.tc(line.substr(0, i)) + line.substr(i)


# ------------------------------------------------------------------ radial wheels
# The ping wheel and the emote wheel draw the same way: a dark disc in the set's
# deep colour ringed in its metal, slots as recessed wells (the picked one lit),
# and each label on a small plate. Drawn only while a wheel is open.

## The wheel's disc, its metal ring and the pointer from the centre.
static func draw_wheel_disc(ci: CanvasItem, c: Vector2, r: float, aim: Vector2) -> void:
	var acc := UiStyle.kc("accent")
	ci.draw_circle(c, r + 14.0, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, r + 10.0, Color(UiStyle.kc("deep", UiStyle.current, 1), 0.86))
	ci.draw_arc(c, r + 10.0, 0, TAU, 72, UiStyle.kc("rim"), 3.0, true)
	ci.draw_arc(c, r + 8.0, 0, TAU, 72, Color(acc, 0.85), 1.5, true)
	ci.draw_arc(c, r * 0.36, 0, TAU, 48, Color(acc, 0.35), 1.0, true)
	ci.draw_line(c, c + aim.limit_length(r * 0.5), UiStyle.kc("accent_hi"), 3.0, true)
	ci.draw_circle(c, 5.0, UiStyle.kc("accent_hi"))


## One slot: a well (lit and larger when picked) with a coloured core.
static func draw_wheel_slot(ci: CanvasItem, at: Vector2, on: bool, core: Color) -> float:
	var r := 30.0 if on else 24.0
	if on:
		ci.draw_circle(at, r + 6.0, Color(UiStyle.kc("accent_hi"), 0.22))
	ci.draw_circle(at, r, UiStyle.kc("well"))
	ci.draw_circle(at, r - 4.0, Color(core, 1.0 if on else 0.6))
	ci.draw_arc(at, r, 0, TAU, 40, UiStyle.kc("accent_hi") if on else Color(UiStyle.kc("accent"), 0.6), 2.5 if on else 1.5, true)
	return r


## A slot's label on a small plate: i = 0 top, 1 right, 2 bottom, 3 left of the slot.
static func draw_wheel_label(ci: CanvasItem, at: Vector2, i: int, label: String, on: bool) -> void:
	var font := UiStyle.font("bold")
	var fs := UiStyle.ts(15)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Vector2(w + 18.0, fs + 10.0)
	var offs: Array[Vector2] = [Vector2(0, -56), Vector2(48 + box.x * 0.5, 0), Vector2(0, 58), Vector2(-48 - box.x * 0.5, 0)]
	var ctr: Vector2 = at + offs[i]
	var rect := Rect2(ctr - box * 0.5, box)
	ci.draw_style_box(kit_box("pill_on" if on else "pill"), rect)
	ci.draw_string(font, Vector2(rect.position.x + 9.0, ctr.y + fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			UiStyle.kc("accent_hi") if on else UiStyle.kc("text"))

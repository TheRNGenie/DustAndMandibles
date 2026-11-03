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


## A keycap: a small light key with the key's name on it.
static func chip(key: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.BONE
	sb.border_color = Palette.OUTLINE
	sb.set_border_width_all(2)
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = key
	l.add_theme_font_size_override("font_size", CHIP_FONT)
	l.add_theme_color_override("font_color", Palette.OUTLINE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 14
	p.add_child(l)
	return p


## "[key] action" as one unit.
static func hint(key: String, action: String, color: Color = Palette.BONE) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := chip(key)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(c)
	h.add_child(text(UiStyle.tc(action), TEXT_FONT, color))
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

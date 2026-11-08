class_name UiStyle
extends RefCounted
## The game's UI look, in one place. Four theme sets drawn by
## tools/ui/make_theme.py (assets/ui/theme/<set>/*.png):
##   base  - "Frontier": wanted-poster paper, tooled leather, brass, rope, a beetle
##           (the look before a brand is chosen, and for riders with No Brand)
##   sheaf - The Sheaf: burlap, twine, kraft seed-packet paper, green paint, wheat gold
##   irons - The Crossed Irons: gunmetal, brass rivets, manila ordnance paper, cartridges
##   snake - The Snake Eyes: mahogany rail, green felt, ivory card stock, suits and dice
##
## install() writes the set into Godot's default Theme, so every Button,
## CheckBox, slider, LineEdit, scrollbar, TabContainer, popup and tooltip in the
## game (CanvasLayers included) picks it up with no per-screen code. Screens
## that want a specific surface use a theme type variation ("PaperPanel",
## "FramePanel", "HeaderPanel", "CardPanel", "TabButton", "InkLabel", "TitleLabel"
## ... see _variations) or the helpers below. apply(set) swaps the whole look
## live (the local player's brand calls it): the shared StyleBoxTextures are
## changed in place, so overrides handed out earlier follow along too.

## Fires after apply() swaps the set (screens with hand-coloured labels rebuild).
static var notifier := Notifier.new()
## The set on screen now.
static var current: StringName = &""

const SET_IDS: Array[StringName] = [&"base", &"sheaf", &"irons", &"snake", &"mandibles"]
const DIR := "res://assets/ui/theme/%s/%s.png"

## Per set: text colours for each surface, the display font and its treatment.
## ink/ink_soft: text on paper and cards; title/outline: display titles on the
## header strap; btn*: button text; tab/tab_sel: tab text; hud: text on HUD panels.
const SETS: Dictionary = {
	&"base": {
		"name": "Frontier", "ink": "#2E1D10", "ink_soft": "#6B5034", "title": "#F2C14E", "outline": "#1A0F07",
		"warn": "#8A5800", "good_hud": "#9BD77E", "bad_hud": "#FF8A73", "warn_hud": "#FFC857", "focus": "#F2C14E",
		"btn": "#F8EBCF", "btn_hover": "#FFFFFF", "btn_off": "#C9BCA6", "btn_outline": "#2A170B",
		"tab": "#2E1D10", "tab_sel": "#F2C14E", "accent": "#3E8E7E", "gold": "#E8B53A", "good": "#3F6B2A",
		"bad": "#9B3B2E", "dim": "#140B0599", "hud": "#F2E3C2", "bg": "#3B2A1E",
		"hud_bg": "#2A1A0FE6", "hud_rim": "#9C7440", "radius": 6,
		"file": "res://assets/fonts/Rye-Regular.ttf", "fonts": ["Georgia", "Cambria", "Times New Roman"], "weight": 700, "italic": false, "spacing": 1, "wdth": 0,
	},
	&"sheaf": {
		"name": "The Sheaf", "ink": "#2F2A12", "ink_soft": "#5E5532", "title": "#F1D27A", "outline": "#14200A",
		"warn": "#7F5500", "good_hud": "#B5DE7F", "bad_hud": "#FF8A73", "warn_hud": "#FFD166", "focus": "#F1D27A",
		"btn": "#F6EFD6", "btn_hover": "#FFFFFF", "btn_off": "#C8C8B4", "btn_outline": "#1A2A0E",
		"tab": "#2F2A12", "tab_sel": "#F1D27A", "accent": "#5E8C31", "gold": "#D9A928", "good": "#3F6B2A",
		"bad": "#9B3B2E", "dim": "#16140899", "hud": "#F3E7C4", "bg": "#4A3A22",
		"hud_bg": "#22341AE6", "hud_rim": "#C9A04A", "radius": 4,
		"file": "res://assets/fonts/Sancreek-Regular.ttf", "fonts": ["Constantia", "Palatino Linotype", "Georgia"], "weight": 700, "italic": false, "spacing": 1, "wdth": 0,
	},
	&"irons": {
		"name": "The Crossed Irons", "ink": "#1E1A16", "ink_soft": "#4E463C", "title": "#E8C06A", "outline": "#0A0D12",
		"warn": "#7A5000", "good_hud": "#A8D98A", "bad_hud": "#FF8F7A", "warn_hud": "#FFC857", "focus": "#E8C06A",
		"btn": "#E6ECF2", "btn_hover": "#FFFFFF", "btn_off": "#A9AEB3", "btn_outline": "#05080C",
		"tab": "#1E1A16", "tab_sel": "#E8C06A", "accent": "#B8862E", "gold": "#E3B55B", "good": "#4B6B2A",
		"bad": "#A33A2A", "dim": "#0B0E1199", "hud": "#E6EAEE", "bg": "#22140C",
		"hud_bg": "#141C26E6", "hud_rim": "#B8862E", "radius": 3,
		"file": "res://assets/fonts/SpecialElite-Regular.ttf", "fonts": ["Bahnschrift", "Arial Narrow", "Impact"], "weight": 700, "italic": false, "spacing": 2, "wdth": 75,
	},
	&"snake": {
		"name": "The Snake Eyes", "ink": "#17120F", "ink_soft": "#5A4A44", "title": "#E9C46A", "outline": "#0A1F10",
		"warn": "#7F5000", "good_hud": "#8FD694", "bad_hud": "#FF8A80", "warn_hud": "#FFD166", "focus": "#E9C46A",
		"btn": "#FFF5E6", "btn_hover": "#FFFFFF", "btn_off": "#D8D0C8", "btn_outline": "#3A0806",
		"tab": "#17120F", "tab_sel": "#FFF5E6", "accent": "#B3261E", "gold": "#E9C46A", "good": "#2E7D32",
		"bad": "#B3261E", "dim": "#06140A99", "hud": "#F4ECDA", "bg": "#123B1E",
		"hud_bg": "#123A20E6", "hud_rim": "#E9C46A", "radius": 10,
		"decorative": true, "file": "res://assets/fonts/Ewert-Regular.ttf", "fonts": ["Palatino Linotype", "Book Antiqua", "Georgia"], "weight": 700, "italic": true, "spacing": 1, "wdth": 0,
	},
	# Attack on Mandibles: the Frontier parts re-dyed as beetle shell (tools/ui/make_theme.py mandibles).
	&"mandibles": {
		"name": "Attack on Mandibles", "ink": "#0F2623", "ink_soft": "#3E5E58", "title": "#B9F06E", "outline": "#06140F",
		"warn": "#7F5500", "good_hud": "#B9F06E", "bad_hud": "#FF8A73", "warn_hud": "#FFC857", "focus": "#E8A13A",
		"btn": "#EAF7E0", "btn_hover": "#FFFFFF", "btn_off": "#A9BFB8", "btn_outline": "#06140F",
		"tab": "#0F2623", "tab_sel": "#B9F06E", "accent": "#2E8C7E", "gold": "#E8A13A", "good": "#3F7A2A",
		"bad": "#A33A2A", "dim": "#06140F99", "hud": "#E6F4EC", "bg": "#123A34",
		"hud_bg": "#0F2A26E6", "hud_rim": "#E8A13A", "radius": 6,
		"file": "res://assets/fonts/Rye-Regular.ttf", "fonts": ["Georgia", "Cambria", "Times New Roman"], "weight": 700, "italic": false, "spacing": 1, "wdth": 0,
	},
}

## Texture margins (left/right, top/bottom) each part was drawn with
## (tools/ui/make_theme.py), and the content padding inside it.
const PARTS: Dictionary = {
	"frame": [48, 48, 26, 24], "paper": [32, 32, 22, 20], "poster": [32, 32, 28, 26], "header": [40, 20, 22, 8],
	"button": [20, 16, 14, 5], "button_hover": [20, 16, 14, 5], "button_pressed": [20, 16, 14, 5],
	"button_disabled": [20, 16, 14, 5], "tab": [20, 16, 12, 4], "tab_hover": [20, 16, 12, 4],
	"tab_selected": [20, 16, 12, 4], "card": [20, 20, 10, 8], "card_hover": [20, 20, 10, 8], "icon": [18, 18, 5, 5],
	"field": [12, 12, 9, 5], "field_focus": [12, 12, 9, 5], "slider": [8, 5, 0, 5], "slider_fill": [8, 5, 0, 5],
	"scroll": [7, 7, 6, 6], "scroll_grab": [7, 7, 6, 6], "scroll_grab_hl": [7, 7, 6, 6], "hud": [20, 20, 12, 8],
	"chip": [14, 12, 10, 3], "chip_bad": [14, 12, 10, 3],
}
## Parts a set draws with other margins.
const PART_OVERRIDES: Dictionary = {
	&"snake": {"button": [24, 16, 18, 5], "button_hover": [24, 16, 18, 5], "button_pressed": [24, 16, 18, 5],
		"button_disabled": [24, 16, 18, 5], "card": [24, 24, 12, 8], "card_hover": [24, 24, 12, 8]},
}
## Parts that stretch rather than tile (small or smooth ones).
const STRETCHED: Array[String] = ["slider", "slider_fill", "scroll", "scroll_grab", "scroll_grab_hl", "chip", "chip_bad"]

## The kit (2026-11 redesign): the shapes and colours every surface is drawn from.
## Dark-first: menus sit on deep, grained plates (leather, burlap, gunmetal, felt,
## chitin) with the set's metal for rules and highlights; text is light. Paper is
## kept for real documents (the Gazette, telegrams, letters). Per set:
##   corner 0 cut ("ticket") / 1 round; cs / cs_btn corner sizes; grain tile and how
##   strong it reads; stitch = the inset rule is a stitched line; studs = corner rivets;
##   deep (windows), surface (content), raised (buttons, cards), well (fields, troughs);
##   accent / accent_hi (rules, focus, fills); text / soft / faint; title; knob motif.
const KIT: Dictionary = {
	&"base": {
		"corner": 0, "cs": 12.0, "cs_btn": 7.0, "grain": "leather", "grain_a": 0.26, "stitch": true, "studs": true,
		"deep": ["#2A1C13", "#160E09"], "surface": ["#30221A", "#21170F"], "raised": ["#4A3424", "#36251A"], "well": "#120B07",
		"rim": "#0A0604", "accent": "#D29E48", "accent_hi": "#F2C46A", "text": "#F4E8D0", "soft": "#C8B293", "faint": "#8C7862",
		"title": "#F2C14E", "knob": "star", "backdrop": ["#2B1B12", "#0C0705"],
	},
	&"sheaf": {
		"corner": 1, "cs": 14.0, "cs_btn": 9.0, "grain": "burlap", "grain_a": 0.2, "stitch": true, "studs": false,
		"deep": ["#25301A", "#141B0D"], "surface": ["#2B3820", "#1C2513"], "raised": ["#3E4E2B", "#2C391E"], "well": "#0E1408",
		"rim": "#080C04", "accent": "#D9B252", "accent_hi": "#F3D27A", "text": "#F4EED6", "soft": "#C9C3A0", "faint": "#8D8B6C",
		"title": "#F1D27A", "knob": "seed", "backdrop": ["#28331B", "#0D1208"],
	},
	&"irons": {
		"corner": 0, "cs": 9.0, "cs_btn": 5.0, "grain": "metal", "grain_a": 0.22, "stitch": false, "studs": true,
		"deep": ["#222932", "#12161B"], "surface": ["#262E37", "#191E24"], "raised": ["#36404B", "#262D35"], "well": "#0A0D10",
		"rim": "#05070A", "accent": "#C29038", "accent_hi": "#E8BE68", "text": "#E9EDF1", "soft": "#AEB7C1", "faint": "#76808A",
		"title": "#E8C06A", "knob": "rivet", "backdrop": ["#232A33", "#0A0D10"],
	},
	&"snake": {
		"corner": 1, "cs": 16.0, "cs_btn": 10.0, "grain": "felt", "grain_a": 0.24, "stitch": false, "studs": false,
		"deep": ["#3A170E", "#1E0A05"], "surface": ["#17452C", "#0E2D1C"], "raised": ["#1F5536", "#153E27"], "well": "#08190F",
		"rim": "#120503", "accent": "#D9B355", "accent_hi": "#F2D07A", "text": "#FFF6E8", "soft": "#D2C6AE", "faint": "#93887A",
		"title": "#E9C46A", "knob": "chip", "backdrop": ["#17472D", "#06180E"],
	},
	&"mandibles": {
		"corner": 0, "cs": 14.0, "cs_btn": 8.0, "grain": "chitin", "grain_a": 0.16, "stitch": false, "studs": true,
		"deep": ["#12302B", "#081A17"], "surface": ["#163833", "#0E2522"], "raised": ["#1E4A43", "#143430"], "well": "#061311",
		"rim": "#030A09", "accent": "#E09A38", "accent_hi": "#B9F06E", "text": "#E8F6EE", "soft": "#A6C6BC", "faint": "#6B8A82",
		"title": "#B9F06E", "knob": "hex", "backdrop": ["#143631", "#040E0C"],
	},
}

## The surfaces the kit draws (shared boxes, filled in place when the set swaps).
const KIT_PARTS: Array[String] = ["frame", "paper", "poster", "header", "button", "button_hover", "button_pressed",
	"button_disabled", "focus", "tab", "tab_hover", "tab_selected", "card", "card_hover", "icon", "field", "field_focus",
	"slider", "slider_fill", "scroll", "scroll_grab", "scroll_grab_hl", "hud", "chip", "chip_bad", "popup", "popup_hover",
	"primary", "primary_hover", "primary_pressed", "ghost", "ghost_hover", "doc", "well"]

const FONT_BODY := "res://assets/fonts/BarlowSemiCondensed-Medium.ttf"
const FONT_BOLD := "res://assets/fonts/BarlowSemiCondensed-SemiBold.ttf"
const FONT_LABEL := "res://assets/fonts/BarlowCondensed-SemiBold.ttf"
const FONT_NUMBER := "res://assets/fonts/BarlowCondensed-Bold.ttf"

static var _boxes: Dictionary = {}
static var _textures: Dictionary = {}
static var _display: FontVariation
static var _sys_fonts: Dictionary = {}
static var _installed := false


class Notifier extends RefCounted:
	signal changed


# ------------------------------------------------------------------ the set

## Puts the base set into the default theme (the Brand autoload calls it first thing).
static func install() -> void:
	if _installed:
		return
	_installed = true
	var tree := Engine.get_main_loop() as SceneTree
	var settings: Node = tree.root.get_node_or_null("Settings") if tree != null and tree.root != null else null
	if settings != null and settings.get("ui_text_scale") != null:
		text_scale = clampf(float(settings.get("ui_text_scale")), 0.9, 1.3)
	apply(&"base")


## Swaps the whole look to a set (live).
static func apply(set_id: StringName) -> void:
	if not SETS.has(set_id):
		set_id = &"base"
	if set_id == current and _installed and not _boxes.is_empty():
		return
	current = set_id
	_icons.clear()
	# Refill the shared boxes quietly. The default theme holds them, so each
	# box's own "changed" re-themed every control in the tree, a few times per
	# box (it froze a running game for about 6 s, then crawled while the queued
	# updates drained). The one theme notification below covers them all.
	for part: String in KIT_PARTS:
		var sb := box(part)
		sb.set_block_signals(true)
		_fill_box(sb, part, set_id)
		sb.set_block_signals(false)
	_fill_font(set_id)
	# Write the theme into a fresh one, then merge it in: merge_with sends a
	# single change instead of one per item.
	var fresh := Theme.new()
	_write_theme(fresh)
	ThemeDB.get_default_theme().merge_with(fresh)
	_sync_static_colors()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)
	notifier.changed.emit()


static func set_name(set_id: StringName = current) -> String:
	return str(SETS.get(set_id, SETS[&"base"])["name"])


## A colour of the current set: ink, ink_soft, title, outline, btn, tab, tab_sel,
## accent, gold, good, bad, dim, hud, bg.
static func c(key: String) -> Color:
	return color_of(current if current != &"" else &"base", key)


static func ink() -> Color:
	return c("ink")


## The shared StyleBoxTexture for a part (frame, paper, poster, header, button,
## tab, card, icon, field, hud, chip...). Changes in place when the set swaps.
static func box(part: String) -> KitBox:
	if not _boxes.has(part):
		_boxes[part] = KitBox.new()
		if _installed and current != &"":
			_fill_box(_boxes[part], part, current)
	return _boxes[part]


static func texture(set_id: StringName, part: String) -> Texture2D:
	var key := "%s/%s" % [set_id, part]
	if not _textures.has(key):
		var path := DIR % [set_id, part]
		_textures[key] = load(path) if ResourceLoader.exists(path) else null
	return _textures[key]


static func _fill_box(sb: KitBox, part: String, set_id: StringName) -> void:
	sb.copy_from(KitBox.make(spec_for(set_id, part)))


# ------------------------------------------------------------------ fonts

## The display face for titles (a FontVariation that follows the set).
static func display_font() -> FontVariation:
	if _display == null:
		_display = FontVariation.new()
		_fill_font(current if current != &"" else &"base")
	return _display


## True when the set's display face is too ornate for a line read mid-fight
## (Snake Eyes' Ewert): live HUD text then uses the plain UI font instead.
static func display_is_decorative() -> bool:
	return bool((SETS.get(current if current != &"" else &"base", SETS[&"base"]) as Dictionary).get("decorative", false))


static func _fill_font(set_id: StringName) -> void:
	var s: Dictionary = SETS[set_id]
	if not _sys_fonts.has(set_id):
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(s["fonts"])
		sf.font_weight = int(s["weight"])
		sf.font_italic = bool(s["italic"])
		sf.allow_system_fallback = true
		_sys_fonts[set_id] = sf
		# A bundled free display font (assets/fonts, OFL/Apache) so every PC sees
		# the same titles; the system font stays as its fallback.
		var path := str(s.get("file", ""))
		if path != "" and ResourceLoader.exists(path):
			var ff := load(path) as FontFile
			if ff != null:
				ff = ff.duplicate() as FontFile
				ff.fallbacks = [sf]
				_sys_fonts[set_id] = ff
	var f := display_font() if _display != null else null
	if f == null:
		return
	f.base_font = _sys_fonts[set_id]
	f.spacing_glyph = int(s["spacing"])
	var ot: Dictionary = {}
	var ts := TextServerManager.get_primary_interface()
	if int(s["wdth"]) > 0 and ts != null:
		ot[ts.name_to_tag("wdth")] = float(s["wdth"])
		ot[ts.name_to_tag("wght")] = float(s["weight"])
	f.variation_opentype = ot


# ------------------------------------------------------------------ the kit

static var _fonts: Dictionary = {}


## The set's kit entry (shapes, surfaces and text colours).
static func kit(set_id: StringName = current) -> Dictionary:
	return KIT.get(set_id if set_id != &"" else &"base", KIT[&"base"])


## A kit colour of a set ("accent", "text", "well"...); surfaces given as
## [top, bottom] answer their `index` end.
static func kc(key: String, set_id: StringName = current, index: int = 0) -> Color:
	var v: Variant = kit(set_id).get(key, "#FF00FF")
	if v is Array:
		return Color(str((v as Array)[index]))
	return Color(str(v))


## Text colours on the kit's dark surfaces, by the old names (the screens ask for
## "ink" on a panel: that's the light text now).
static func _kit_color(key: String, set_id: StringName) -> Variant:
	if set_id == &"":
		set_id = &"base"
	match key:
		"ink", "btn": return kc("text", set_id)
		"ink_soft", "tab": return kc("soft", set_id)
		"tab_sel", "focus": return kc("accent_hi", set_id)
		"btn_hover": return kc("text", set_id).lightened(0.4)
		"btn_off": return kc("faint", set_id)
		"btn_outline", "outline": return kc("rim", set_id)
		"title": return kc("title", set_id)
		"good": return Color(str(SETS[set_id]["good_hud"]))
		"bad": return Color(str(SETS[set_id]["bad_hud"]))
		"warn": return Color(str(SETS[set_id]["warn_hud"]))
		"bg": return kc("deep", set_id, 1)
		"hud_bg": return Color(kc("surface", set_id, 1), 0.86)
		"hud_rim": return Color(kc("accent", set_id), 0.5)
		"faint": return kc("faint", set_id)
		"accent_hi": return kc("accent_hi", set_id)
		"rim": return kc("rim", set_id)
		"well": return kc("well", set_id)
		"accent": return kc("accent", set_id)
	return null


## A colour of any set (brand previews show every set side by side).
static func color_of(set_id: StringName, key: String) -> Color:
	var k: Variant = _kit_color(key, set_id)
	if k is Color:
		return k
	return Color(str((SETS.get(set_id, SETS[&"base"]) as Dictionary).get(key, "#FF00FF")))


static func _grain(name: String) -> Texture2D:
	var path := "res://assets/ui/kit/grain_%s.png" % name
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


## A new box of one kit part for any set (brand previews; screens that tint a copy).
static func box_for(set_id: StringName, part: String) -> KitBox:
	return KitBox.make(spec_for(set_id, part))


## The settings of one kit part for a set.
static func spec_for(set_id: StringName, part: String) -> Dictionary:
	var k := kit(set_id)
	var cut: int = KitBox.Corner.ROUND if int(k["corner"]) == 1 else KitBox.Corner.CUT
	var cs: float = k["cs"]
	var cb: float = k["cs_btn"]
	var acc := kc("accent", set_id)
	var hi := kc("accent_hi", set_id)
	var rim := kc("rim", set_id)
	var well := kc("well", set_id)
	var grain := _grain(str(k["grain"]))
	var ga: float = k["grain_a"]
	var stitch := 4.0 if bool(k["stitch"]) else 0.0
	var studs := acc.darkened(0.05) if bool(k["studs"]) else Color(0, 0, 0, 0)
	var deep0 := kc("deep", set_id, 0)
	var deep1 := kc("deep", set_id, 1)
	var surf0 := kc("surface", set_id, 0)
	var surf1 := kc("surface", set_id, 1)
	var rai0 := kc("raised", set_id, 0)
	var rai1 := kc("raised", set_id, 1)
	var snake := set_id == &"snake"
	match part:
		"frame", "poster":
			# The window around a menu (Snake Eyes: a mahogany rail round the felt).
			return {"corner": cut, "corner_size": cs, "fill_top": deep0, "fill_bottom": deep1, "grain": _grain("wood") if snake else grain,
				"grain_color": Color(0, 0, 0, 0.3 if snake else ga), "burn": Color(0, 0, 0, 0.55), "burn_size": 10.0,
				"rim": rim, "rim_width": 2.0, "rule": Color(acc, 0.6), "rule_inset": 6.0, "rule_width": 1.3, "rule_dash": stitch,
				"studs": studs, "stud_radius": 2.6, "shadow": Color(0, 0, 0, 0.55), "shadow_offset": Vector2(0, 10), "shadow_size": 22.0,
				"lip": Color(1, 1, 1, 0.07), "margin": [24, 20] if part == "frame" else [30, 26]}
		"paper":
			return {"corner": cut, "corner_size": cs * 0.6, "fill_top": surf0, "fill_bottom": surf1, "grain": grain,
				"grain_color": Color(0, 0, 0, ga * 0.75), "burn": Color(0, 0, 0, 0.4), "burn_size": 9.0,
				"rim": Color(0, 0, 0, 0.6), "rim_width": 1.2, "rule": Color(acc, 0.16), "rule_inset": 3.0, "lip": Color(1, 1, 1, 0.05), "margin": [20, 16]}
		"header":
			return {"corner": cut, "corner_size": cs * 0.6, "corner_mask": 15, "fill_top": deep0.darkened(0.25), "fill_bottom": deep1.darkened(0.3),
				"grain": grain, "grain_color": Color(0, 0, 0, ga), "rim": Color(0, 0, 0, 0.5), "rim_width": 1.0,
				"bar_side": 2, "bar": acc, "bar_width": 2.0, "lip": Color(1, 1, 1, 0.06), "margin": [22, 10, 22, 13]}
		"button", "button_hover", "button_pressed", "button_disabled":
			var b := {"corner": cut, "corner_size": cb, "fill_top": rai0, "fill_bottom": rai1, "grain": grain, "grain_color": Color(0, 0, 0, ga * 0.8),
				"rim": rim, "rim_width": 1.5, "rule": Color(acc, 0.3), "rule_inset": 3.0, "lip": Color(1, 1, 1, 0.11),
				"shadow": Color(0, 0, 0, 0.4), "shadow_offset": Vector2(0, 2), "shadow_size": 3.0, "margin": [18, 7]}
			if part == "button_hover":
				b["fill_top"] = rai0.lightened(0.1)
				b["fill_bottom"] = rai1.lightened(0.07)
				b["rule"] = Color(hi, 0.9)
				b["braces"] = hi
				b["glow"] = Color(acc, 0.22)
				b["glow_size"] = 6.0
			elif part == "button_pressed":
				b["fill_top"] = rai1.darkened(0.3)
				b["fill_bottom"] = rai0.darkened(0.1)
				b["rule"] = Color(hi, 0.7)
				b["braces"] = hi
				b["lip"] = Color(0, 0, 0, 0)
				b["burn"] = Color(0, 0, 0, 0.5)
				b["burn_size"] = 4.0
				b["shadow"] = Color(0, 0, 0, 0)
				b["margin"] = [18, 8, 18, 6]
			elif part == "button_disabled":
				b["fill_top"] = rai0.lerp(Color(0.25, 0.25, 0.25), 0.55).darkened(0.25)
				b["fill_bottom"] = rai1.lerp(Color(0.2, 0.2, 0.2), 0.55).darkened(0.25)
				b["rule"] = Color(acc, 0.08)
				b["lip"] = Color(1, 1, 1, 0.04)
				b["shadow"] = Color(0, 0, 0, 0.15)
			return b
		"primary", "primary_hover", "primary_pressed":
			# The one call to action on a screen: the set's metal, dark text.
			var p := {"corner": cut, "corner_size": cb, "fill_top": hi.lightened(0.05), "fill_bottom": acc.darkened(0.12),
				"rim": rim, "rim_width": 1.5, "rule": Color(rim, 0.35), "rule_inset": 3.0, "lip": Color(1, 1, 1, 0.45),
				"shadow": Color(0, 0, 0, 0.45), "shadow_offset": Vector2(0, 2), "shadow_size": 4.0, "margin": [20, 8]}
			if part == "primary_hover":
				p["fill_top"] = hi.lightened(0.22)
				p["fill_bottom"] = acc.lightened(0.05)
				p["braces"] = Color(rim, 0.85)
				p["glow"] = Color(hi, 0.3)
				p["glow_size"] = 8.0
			elif part == "primary_pressed":
				p["fill_top"] = acc.darkened(0.2)
				p["fill_bottom"] = hi.darkened(0.05)
				p["braces"] = Color(rim, 0.85)
				p["lip"] = Color(0, 0, 0, 0)
				p["shadow"] = Color(0, 0, 0, 0)
				p["margin"] = [20, 9, 20, 7]
			return p
		"ghost", "ghost_hover":
			# A quiet text button (Quit, Back links): no plate until hovered.
			if part == "ghost_hover":
				return {"corner": cut, "corner_size": cb, "fill_top": Color(acc, 0.1), "fill_bottom": Color(acc, 0.16),
					"rim": Color(acc, 0.5), "rim_width": 1.0, "braces": hi, "margin": [14, 5]}
			return {"corner": cut, "corner_size": cb, "draw_fill": false, "margin": [14, 5]}
		"focus":
			return {"corner": cut, "corner_size": cb, "draw_fill": false, "rim": Color(hi, 0.95), "rim_width": 1.6, "braces": hi, "expand": 2.0}
		"tab":
			return {"corner": KitBox.Corner.SQUARE, "draw_fill": false, "margin": [14, 7, 14, 9]}
		"tab_hover":
			return {"corner": KitBox.Corner.SQUARE, "fill_top": Color(acc, 0.0), "fill_bottom": Color(acc, 0.12), "bar_side": 2, "bar": Color(acc, 0.55), "bar_width": 2.0, "margin": [14, 7, 14, 9]}
		"tab_selected":
			return {"corner": KitBox.Corner.SQUARE, "fill_top": Color(hi, 0.0), "fill_bottom": Color(hi, 0.18), "bar_side": 2, "bar": hi, "bar_width": 3.0, "margin": [14, 7, 14, 9]}
		"card", "card_hover":
			var cd := {"corner": cut, "corner_size": cb, "fill_top": rai0.darkened(0.12), "fill_bottom": rai1.darkened(0.16), "grain": grain,
				"grain_color": Color(0, 0, 0, ga * 0.7), "rim": Color(0, 0, 0, 0.6), "rim_width": 1.0, "lip": Color(1, 1, 1, 0.07),
				"rule": Color(acc, 0.12), "rule_inset": 3.0, "margin": [14, 10]}
			if part == "card_hover":
				cd["fill_top"] = rai0.darkened(0.02)
				cd["fill_bottom"] = rai1.darkened(0.06)
				cd["rule"] = Color(hi, 0.75)
				cd["glow"] = Color(acc, 0.16)
				cd["glow_size"] = 5.0
				cd["bar_side"] = 1
				cd["bar"] = hi
				cd["bar_width"] = 3.0
				cd["bar_inset"] = 0.18
			return cd
		"icon", "well":
			return {"corner": cut, "corner_size": cb * 0.7, "fill_top": well, "fill_bottom": well.lightened(0.05), "burn": Color(0, 0, 0, 0.55),
				"burn_size": 5.0, "rim": Color(acc, 0.32), "rim_width": 1.0, "margin": [6, 6]}
		"field", "field_focus":
			var f := {"corner": cut, "corner_size": cb * 0.6, "fill_top": well, "fill_bottom": well.lightened(0.04), "burn": Color(0, 0, 0, 0.5),
				"burn_size": 4.0, "rim": Color(0, 0, 0, 0.7), "rim_width": 1.2, "bar_side": 2, "bar": Color(acc, 0.45), "bar_width": 1.5, "margin": [12, 7]}
			if part == "field_focus":
				f["bar"] = hi
				f["bar_width"] = 2.5
				f["rim"] = Color(acc, 0.7)
				f["glow"] = Color(acc, 0.14)
				f["glow_size"] = 4.0
			return f
		"slider":
			return {"corner": cut, "corner_size": 3.0, "fill_top": well, "fill_bottom": well.lightened(0.08), "rim": Color(0, 0, 0, 0.8),
				"rim_width": 1.0, "burn": Color(0, 0, 0, 0.45), "burn_size": 2.0, "margin": [0, 4]}
		"slider_fill":
			return {"corner": cut, "corner_size": 3.0, "fill_top": hi, "fill_bottom": acc.darkened(0.15), "lip": Color(1, 1, 1, 0.35),
				"rim": Color(0, 0, 0, 0.6), "rim_width": 1.0, "margin": [0, 4]}
		"scroll":
			return {"corner": KitBox.Corner.ROUND, "corner_size": 3.0, "fill_top": Color(0, 0, 0, 0.3), "fill_bottom": Color(0, 0, 0, 0.3), "margin": [5, 5]}
		"scroll_grab", "scroll_grab_hl":
			var hl := part == "scroll_grab_hl"
			return {"corner": KitBox.Corner.ROUND, "corner_size": 3.0, "fill_top": Color(hi if hl else acc, 0.85 if hl else 0.55),
				"fill_bottom": Color(acc, 0.75 if hl else 0.45), "margin": [5, 5]}
		"hud":
			# (no grain on the HUD: a textured pass per plate costs a draw call each, and
			# the speckle barely reads through a see-through plate anyway)
			return {"corner": cut, "corner_size": cb, "fill_top": Color(surf0, 0.88), "fill_bottom": Color(surf1, 0.92),
				"rim": Color(0, 0, 0, 0.6), "rim_width": 1.2, "rule": Color(acc, 0.32), "rule_inset": 3.0,
				"lip": Color(1, 1, 1, 0.06), "margin": [14, 8]}
		"chip", "chip_bad":
			return {"corner": cut, "corner_size": 5.0, "fill_top": Color(deep0, 0.94), "fill_bottom": Color(deep1, 0.96),
				"rim": Color(acc, 0.5) if part == "chip" else Color(color_of(set_id, "bad"), 0.85), "rim_width": 1.0, "lip": Color(1, 1, 1, 0.06), "margin": [10, 3]}
		"popup", "popup_hover":
			if part == "popup_hover":
				return {"corner": cut, "corner_size": 4.0, "fill_top": Color(acc, 0.18), "fill_bottom": Color(acc, 0.26), "bar_side": 1, "bar": hi, "bar_width": 3.0, "margin": [10, 4]}
			return {"corner": cut, "corner_size": cb, "fill_top": rai0.darkened(0.2), "fill_bottom": rai1.darkened(0.3), "grain": grain,
				"grain_color": Color(0, 0, 0, ga * 0.6), "rim": Color(acc, 0.55), "rim_width": 1.2, "shadow": Color(0, 0, 0, 0.5),
				"shadow_offset": Vector2(0, 6), "shadow_size": 10.0, "margin": [10, 8]}
		"doc":
			# A real paper document (newspaper, telegram, letters): cream, fibres, a burnt edge.
			return {"corner": KitBox.Corner.SQUARE, "fill_top": Color("#F1E6CB"), "fill_bottom": Color("#E3D2AE"), "grain": _grain("paper"),
				"grain_color": Color(0.36, 0.24, 0.1, 0.2), "burn": Color(0.42, 0.27, 0.1, 0.32), "burn_size": 14.0, "rim": Color(0, 0, 0, 0.35),
				"rim_width": 1.0, "shadow": Color(0, 0, 0, 0.5), "shadow_offset": Vector2(0, 8), "shadow_size": 16.0, "margin": [26, 22]}
	return {}


## The kit's UI faces: body text, its semibold, condensed labels and numbers.
static func font(kind: String = "body") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path := str({"body": FONT_BODY, "bold": FONT_BOLD, "label": FONT_LABEL, "number": FONT_NUMBER}.get(kind, FONT_BODY))
	var f: Font = null
	if ResourceLoader.exists(path):
		var ff := load(path) as FontFile
		if ff != null:
			var v := FontVariation.new()
			v.base_font = ff
			if kind == "label":
				v.spacing_glyph = 1
			f = v
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[kind] = f
	return f


# ------------------------------------------------------------------ the Godot theme

static func _write_theme(t: Theme) -> void:
	var empty := StyleBoxEmpty.new()
	t.default_font = font("body")
	t.default_font_size = ts(16)
	# Buttons (OptionButton, MenuButton and CheckButton fall back to these).
	for type: String in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, box("button"))
		t.set_stylebox("hover", type, box("button_hover"))
		t.set_stylebox("pressed", type, box("button_pressed"))
		t.set_stylebox("hover_pressed", type, box("button_pressed"))
		t.set_stylebox("disabled", type, box("button_disabled"))
		t.set_stylebox("focus", type, focus_ring())
		_button_colors(t, type, c("btn"), c("btn_hover"), c("btn_off"))
		t.set_color("font_outline_color", type, Color(c("btn_outline"), 0.6))
		t.set_constant("outline_size", type, 2)
		t.set_font("font", type, font("bold"))
		t.set_constant("h_separation", type, 8)
	t.set_icon("arrow", "OptionButton", _icon("arrow", 16))
	t.set_constant("arrow_margin", "OptionButton", 10)
	# The call to action, the quiet text button.
	_button_variation(t, "PrimaryButton", "primary", "primary_hover", "primary_pressed", c("rim"), c("rim"), Color(c("rim"), 0.5))
	t.set_constant("outline_size", "PrimaryButton", 0)
	_button_variation(t, "GhostButton", "ghost", "ghost_hover", "ghost_hover", c("ink_soft"), c("accent_hi"), c("faint"))
	t.set_constant("outline_size", "GhostButton", 0)
	# Check boxes and switches: the set's own marks.
	for type: String in ["CheckBox", "CheckButton"]:
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(st, type, empty)
		t.set_stylebox("focus", type, focus_ring())
		t.set_icon("checked", type, _icon("check_on", 24))
		t.set_icon("unchecked", type, _icon("check_off", 24))
		t.set_icon("checked_disabled", type, _icon("check_on", 24))
		t.set_icon("unchecked_disabled", type, _icon("check_off", 24))
		t.set_icon("radio_checked", type, _icon("radio_on", 22))
		t.set_icon("radio_unchecked", type, _icon("radio_off", 22))
		_button_colors(t, type, c("ink"), c("accent_hi"), c("ink_soft"))
		t.set_constant("outline_size", type, 0)
		t.set_constant("h_separation", type, 8)
	# Text fields.
	t.set_stylebox("normal", "LineEdit", box("field"))
	t.set_stylebox("focus", "LineEdit", box("field_focus"))
	t.set_stylebox("read_only", "LineEdit", box("field"))
	t.set_color("font_color", "LineEdit", c("ink"))
	t.set_color("font_placeholder_color", "LineEdit", Color(c("ink_soft"), 0.7))
	t.set_color("caret_color", "LineEdit", c("accent_hi"))
	t.set_color("selection_color", "LineEdit", Color(c("accent"), 0.45))
	t.set_font("font", "LineEdit", font("bold"))
	# Sliders: a dark trough, a metal fill up to the knob, the set's knob.
	for type: String in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, box("slider"))
		t.set_stylebox("grabber_area", type, box("slider_fill"))
		t.set_stylebox("grabber_area_highlight", type, box("slider_fill"))
		t.set_icon("grabber", type, _icon("knob", 24))
		t.set_icon("grabber_highlight", type, _icon("knob_hl", 26))
		t.set_icon("grabber_disabled", type, _icon("knob", 24))
		t.set_constant("center_grabber", type, 1)
	# Scrollbars: slim, the set's metal.
	for type: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, box("scroll"))
		t.set_stylebox("scroll_focus", type, box("scroll"))
		t.set_stylebox("grabber", type, box("scroll_grab"))
		t.set_stylebox("grabber_highlight", type, box("scroll_grab_hl"))
		t.set_stylebox("grabber_pressed", type, box("scroll_grab_hl"))
	# Tabs: words on the surface, the chosen one underlined in the set's metal.
	for type: String in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_unselected", type, box("tab"))
		t.set_stylebox("tab_hovered", type, box("tab_hover"))
		t.set_stylebox("tab_selected", type, box("tab_selected"))
		t.set_stylebox("tab_disabled", type, box("tab"))
		t.set_stylebox("tab_focus", type, focus_ring())
		t.set_color("font_unselected_color", type, c("tab"))
		t.set_color("font_hovered_color", type, c("ink"))
		t.set_color("font_selected_color", type, c("tab_sel"))
		t.set_color("font_outline_color", type, Color(0, 0, 0, 0))
		t.set_constant("tab_separation", type, 2)
		t.set_font("font", type, font("label"))
		t.set_font_size("font_size", type, ts(18))
	t.set_stylebox("panel", "TabContainer", box("card"))
	t.set_stylebox("tabbar_background", "TabContainer", empty)
	# Popups, dropdown lists and tooltips: a raised plate rimmed in the set's metal.
	t.set_stylebox("panel", "PopupMenu", box("popup"))
	t.set_stylebox("hover", "PopupMenu", box("popup_hover"))
	t.set_color("font_color", "PopupMenu", c("ink"))
	t.set_color("font_hover_color", "PopupMenu", c("accent_hi"))
	t.set_color("font_disabled_color", "PopupMenu", c("faint"))
	t.set_color("font_separator_color", "PopupMenu", c("ink_soft"))
	t.set_font("font", "PopupMenu", font("bold"))
	t.set_icon("checked", "PopupMenu", _icon("check_on", 20))
	t.set_icon("unchecked", "PopupMenu", _icon("check_off", 20))
	t.set_icon("radio_checked", "PopupMenu", _icon("radio_on", 18))
	t.set_icon("radio_unchecked", "PopupMenu", _icon("radio_off", 18))
	t.set_constant("v_separation", "PopupMenu", 8)
	t.set_stylebox("panel", "TooltipPanel", box("popup"))
	t.set_color("font_color", "TooltipLabel", c("ink"))
	t.set_font("font", "TooltipLabel", font("body"))
	# Separators: a fine rule with the set's ornament in the middle.
	var rule := Rule.new()
	rule.color = Color(c("accent"), 0.55)
	rule.motif = str(kit()["knob"])
	t.set_stylebox("separator", "HSeparator", rule)
	t.set_constant("separation", "HSeparator", 12)
	var vline := StyleBoxLine.new()
	vline.color = Color(c("accent"), 0.35)
	vline.thickness = 1
	vline.vertical = true
	t.set_stylebox("separator", "VSeparator", vline)
	# Plain labels and rich text read in the set's light ink.
	t.set_color("font_color", "Label", c("ink"))
	t.set_color("default_color", "RichTextLabel", c("ink"))
	t.set_font("normal_font", "RichTextLabel", font("body"))
	t.set_font("bold_font", "RichTextLabel", font("bold"))
	_variations(t)


static func _button_colors(t: Theme, type: String, normal: Color, hover: Color, off: Color) -> void:
	t.set_color("font_color", type, normal)
	t.set_color("font_hover_color", type, hover)
	t.set_color("font_pressed_color", type, hover)
	t.set_color("font_hover_pressed_color", type, hover)
	t.set_color("font_focus_color", type, normal)
	t.set_color("font_disabled_color", type, off)


## A button variation on three kit parts.
static func _button_variation(t: Theme, name: String, normal: String, hover: String, pressed: String, text: Color, text_hover: Color, off: Color) -> void:
	t.set_type_variation(name, "Button")
	t.set_stylebox("normal", name, box(normal))
	t.set_stylebox("hover", name, box(hover))
	t.set_stylebox("pressed", name, box(pressed))
	t.set_stylebox("hover_pressed", name, box(pressed))
	t.set_stylebox("disabled", name, box("button_disabled") if normal != "ghost" else box("ghost"))
	t.set_stylebox("focus", name, focus_ring())
	_button_colors(t, name, text, text_hover, off)


static var _icons: Dictionary = {}


## A vector theme icon in the current set (kept per set, so swaps reuse them).
static func _icon(kind: String, px: float) -> KitIcon:
	var key := "%s/%s/%d" % [current, kind, int(px)]
	if not _icons.has(key):
		_icons[key] = KitIcon.make(kind, px, c("accent"), c("ink"), c("well"), c("rim"), str(kit()["knob"]), int(kit()["corner"]) == 1)
	return _icons[key]


## Named surfaces and text styles screens pick with `theme_type_variation`.
static func _variations(t: Theme) -> void:
	for pair: Array in [["FramePanel", "frame"], ["PaperPanel", "paper"], ["PosterPanel", "poster"],
			["HeaderPanel", "header"], ["CardPanel", "card"], ["CardHoverPanel", "card_hover"], ["IconPanel", "icon"],
			["HudPanel", "hud"], ["ChipPanel", "chip"], ["ChipBadPanel", "chip_bad"], ["WellPanel", "well"], ["DocPanel", "doc"],
			["PopupPlate", "popup"]]:
		t.set_type_variation(pair[0], "PanelContainer")
		t.set_stylebox("panel", pair[0], box(pair[1]))
	# Tab-like toggles made of Buttons (MenuScreen tabs, bet pickers, ledger tabs).
	t.set_type_variation("TabButton", "Button")
	t.set_stylebox("normal", "TabButton", box("tab"))
	t.set_stylebox("hover", "TabButton", box("tab_hover"))
	t.set_stylebox("pressed", "TabButton", box("tab_selected"))
	t.set_stylebox("hover_pressed", "TabButton", box("tab_selected"))
	t.set_stylebox("disabled", "TabButton", box("tab"))
	_button_colors(t, "TabButton", c("tab"), c("ink"), c("faint"))
	t.set_color("font_pressed_color", "TabButton", c("tab_sel"))
	t.set_color("font_hover_pressed_color", "TabButton", c("tab_sel"))
	t.set_constant("outline_size", "TabButton", 0)
	t.set_stylebox("focus", "TabButton", focus_ring())
	t.set_font("font", "TabButton", font("label"))
	t.set_font_size("font_size", "TabButton", ts(17))
	t.set_type_variation("TabButtonSelected", "Button")
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "TabButtonSelected", box("tab_selected"))
	t.set_stylebox("focus", "TabButtonSelected", focus_ring())
	_button_colors(t, "TabButtonSelected", c("tab_sel"), c("tab_sel"), c("tab_sel"))
	t.set_constant("outline_size", "TabButtonSelected", 0)
	t.set_font("font", "TabButtonSelected", font("label"))
	t.set_font_size("font_size", "TabButtonSelected", ts(17))
	# Labels.
	for pair: Array in [["InkLabel", "ink"], ["SoftInkLabel", "ink_soft"], ["HudLabel", "hud"], ["GoldLabel", "accent_hi"],
			["BadLabel", "bad"], ["GoodLabel", "good"], ["WarnLabel", "warn"], ["FaintLabel", "faint"]]:
		t.set_type_variation(pair[0], "Label")
		t.set_color("font_color", pair[0], c(pair[1]))
	# Condensed small caps over a section or a value ("TEAM CHITIN"), and big numbers.
	t.set_type_variation("EyebrowLabel", "Label")
	t.set_font("font", "EyebrowLabel", font("label"))
	t.set_color("font_color", "EyebrowLabel", c("accent"))
	t.set_type_variation("NumberLabel", "Label")
	t.set_font("font", "NumberLabel", font("number"))
	t.set_color("font_color", "NumberLabel", c("ink"))
	t.set_type_variation("DocInkLabel", "Label")
	t.set_color("font_color", "DocInkLabel", Color("#2B1C10"))
	for pair: Array in [["TitleLabel", "ink", false], ["HeaderTitle", "title", true]]:
		t.set_type_variation(pair[0], "Label")
		t.set_font("font", pair[0], display_font())
		t.set_color("font_color", pair[0], c(pair[1]))
		t.set_color("font_outline_color", pair[0], c("outline"))
		t.set_constant("outline_size", pair[0], 6 if pair[2] else 0)
		t.set_color("font_shadow_color", pair[0], Color(0, 0, 0, 0.5))
		t.set_constant("shadow_offset_x", pair[0], 0)
		t.set_constant("shadow_offset_y", pair[0], 3 if pair[2] else 2)


## Older code reads these colours as constants on MenuScreen / LedgerScreen;
## keep them current. (Loaded by path so UiStyle compiles without the autoloads,
## e.g. in the headless unit tests.)
static func _sync_static_colors() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or not tree.root.has_node("Brand"):
		return
	var colors := {"INK": c("ink"), "GOLD": c("title"), "PARCHMENT": c("btn"), "PARCHMENT_DARK": c("hud")}
	for path: String in ["res://scenes/ui/menu_screen.gd", "res://scenes/ui/ledger_screen.gd"]:
		var sc := load(path) as GDScript
		if sc == null:
			continue
		for k: String in colors:
			if k in sc:
				sc.set(k, colors[k])


# ------------------------------------------------------------------ builders

## Big poster-paper panel (pause menu, main menu, end posters).
static func poster() -> StyleBox:
	return box("poster")


## Small dark panel for the HUD (signs, cards over the 3D view): a flat
## StyleBox in the set's colours, new each call so callers may tint it.
static func wood_sign() -> StyleBoxFlat:
	return hud_flat()


## The HUD card: the set's dark surface, see-through, with a hairline of its metal
## and the kit's corners (cut or round). Flat and light so the HUD stays quiet;
## new each call so callers may tint it.
static func hud_flat() -> StyleBoxFlat:
	var k := kit()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(kc("surface", current, 1).darkened(0.1), 0.84)
	sb.border_color = Color(kc("accent"), 0.42)
	sb.set_border_width_all(1)
	var cut := int(k["corner"]) == 0
	sb.set_corner_radius_all(int(k["cs_btn"]) if cut else int(k["cs_btn"]))
	sb.corner_detail = 1 if cut else 6
	sb.shadow_color = Color(0, 0, 0, 0.32)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	sb.anti_aliasing = true
	return sb


## How much the full-screen menus grow on big screens: 1 at 1080p and below,
## 1.33 at 1440p, 2 at 4K (the HUD stays at 1:1 so it keeps out of the way).
static func ui_scale(vp_height: float = -1.0) -> float:
	if vp_height < 0.0:
		var tree := Engine.get_main_loop() as SceneTree
		vp_height = tree.root.get_visible_rect().size.y if tree != null and tree.root != null else 1080.0
	return clampf(vp_height / 1080.0, 1.0, 2.0)


## Scales a full-screen menu root to ui_scale() and keeps it fitted to the window.
static func fit(root: Control) -> void:
	# The root viewport outlives every menu, so the size hook is unplugged when the
	# menu leaves the tree (a static lambda is never auto-disconnected: after the
	# menu was freed, the next window resize called it with root = null and release
	# builds crashed - "Lambda capture at index 0 was freed").
	var ref: WeakRef = weakref(root)
	var refit := func() -> void:
		var r := ref.get_ref() as Control
		if r == null or not r.is_inside_tree():
			return
		var vs := r.get_viewport_rect().size
		var k := ui_scale(vs.y)
		r.set_anchors_preset(Control.PRESET_TOP_LEFT)
		r.position = Vector2.ZERO
		r.scale = Vector2(k, k)
		r.size = vs / k
	var hook := func() -> void:
		var vp := root.get_viewport()
		if vp != null and not vp.size_changed.is_connected(refit):
			vp.size_changed.connect(refit)
		refit.call()
	var unhook := func() -> void:
		var vp := root.get_viewport()
		if vp != null and vp.size_changed.is_connected(refit):
			vp.size_changed.disconnect(refit)
	# Both fire only while root is alive (they hang off root's own signals).
	root.tree_entered.connect(hook)
	root.tree_exiting.connect(unhook)
	if root.is_inside_tree():
		hook.call()


## A panel of one of the named surfaces ("PaperPanel", "FramePanel", ...).
static func panel(variation: String = "PaperPanel") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p


## The one bar style for health, boss, water and progress bars (KitBar): a dark
## trough with quarter ticks, a fill with a lit top edge, and a pale trail that
## lingers a moment where the value just fell from.
static func bar(color: Color, min_size: Vector2 = Vector2(240, 18), max_value: float = 100.0) -> ProgressBar:
	var b := KitBar.new()
	b.custom_minimum_size = min_size
	b.max_value = max_value
	b.value = max_value
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.ticks = 4 if min_size.x >= 120.0 else 0
	b.add_theme_stylebox_override("background", KitBox.make({"corner": KitBox.Corner.CUT, "corner_size": 4.0,
		"fill_top": Color(0.03, 0.02, 0.02, 0.92), "fill_bottom": Color(0.09, 0.07, 0.06, 0.92), "rim": Color(0, 0, 0, 0.9),
		"rim_width": 1.5, "burn": Color(0, 0, 0, 0.5), "burn_size": 2.0}))
	b.add_theme_stylebox_override("fill", bar_fill(color))
	return b


## The fill of a bar(): the colour with a lighter lip on top (call again to recolour).
static func bar_fill(color: Color) -> StyleBox:
	return KitBox.make({"corner": KitBox.Corner.CUT, "corner_size": 3.0, "fill_top": color.lightened(0.22), "fill_bottom": color.darkened(0.18),
		"lip": Color(1, 1, 1, 0.4), "expand": -2.0})


## The type scale: every UI font size snaps to one of these steps (fine print,
## small, body, emphasis, header, title, and three display sizes), so text
## sizes line up across every screen.
const TYPE_SCALE: Array[int] = [12, 14, 16, 18, 22, 30, 40, 54, 64]


## The player's UI text size (Settings > Accessibility, 0.9 - 1.3), applied by ts().
static var text_scale := 1.0


## The nearest step of the type scale (ties go up), times the player's text size.
static func ts(size: int) -> int:
	var best := TYPE_SCALE[0]
	for s in TYPE_SCALE:
		if absi(s - size) <= absi(best - size):
			best = s
	return roundi(best * text_scale * KIT_TEXT_GROW)


## The kit's UI face (Barlow, semi-condensed) sets narrower than the old default
## font, so every step of the type scale reads a little larger to keep the same
## presence (16 -> 18, 22 -> 25, 30 -> 34).
const KIT_TEXT_GROW := 1.12


## Sets the UI text size (0.9 - 1.3) and redraws the screens that follow the set.
static func set_text_scale(v: float) -> void:
	v = clampf(v, 0.9, 1.3)
	if is_equal_approx(v, text_scale):
		return
	text_scale = v
	notifier.changed.emit()


const NBSP := "\u00A0"


## A stat line ("Damage 12  ·  x1.5 vs Heavy  ·  Range 18 m") that only wraps
## between its chunks: spaces inside a chunk become non-breaking.
static func keep_together(stats: String, sep: String = "  ·  ") -> String:
	var chunks := stats.split(sep)
	for i in chunks.size():
		chunks[i] = chunks[i].strip_edges().replace(" ", NBSP)
	return (NBSP + NBSP + "·  ").join(chunks)


## Keyboard / controller tab paging: -1 for PageUp or the left shoulder, +1 for
## PageDown or the right shoulder, else 0.
static func page_step(event: InputEvent) -> int:
	if event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_LEFT_SHOULDER: return -1
			JOY_BUTTON_RIGHT_SHOULDER: return 1
	if event.is_action_pressed("ui_page_up"):
		return -1
	if event.is_action_pressed("ui_page_down"):
		return 1
	return 0


## An arrow / d-pad press.
static func nav_pressed(event: InputEvent) -> bool:
	for a: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		if event.is_action_pressed(a):
			return true
	return false


## The visible controls under `n` that take keyboard focus, in tree order.
static func focusables(n: Node, out: Array[Control] = []) -> Array[Control]:
	for c: Node in n.get_children():
		if c.is_queued_for_deletion() or (c is CanvasItem and not (c as CanvasItem).visible):
			continue
		if c is Control and (c as Control).focus_mode != Control.FOCUS_NONE 				and not (c is BaseButton and (c as BaseButton).disabled):
			out.append(c as Control)
		focusables(c, out)
	return out


## Focuses the first focusable control under `n`; false if there is none.
static func focus_first(n: Node) -> bool:
	var list := focusables(n)
	if list.is_empty():
		return false
	list[0].grab_focus()
	return true


## A label; by default in the set's ink (follows live swaps). Pass a colour to pin it.
static func label(text: String, size: int = 16, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", ts(size))
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	else:
		l.theme_type_variation = "InkLabel"
	return l


## A display title. `on_header` = gold with a dark outline (on header straps and
## over the 3D view); otherwise inked onto paper.
static func title(text: String, size: int = 30, on_header: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.uppercase = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.theme_type_variation = "HeaderTitle" if on_header else "TitleLabel"
	l.add_theme_font_size_override("font_size", ts(size))
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = tc(text)
	b.custom_minimum_size.y = 42
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", ts(17))
	return b


## The screen's one call to action (Start, Ready, Buy...): the set's metal.
static func primary_button(text: String) -> Button:
	var b := button(text)
	b.theme_type_variation = "PrimaryButton"
	return b


## A quiet text-only button (Quit, Back, Cancel): a plate appears on hover.
static func ghost_button(text: String) -> Button:
	var b := button(text)
	b.theme_type_variation = "GhostButton"
	b.custom_minimum_size.y = 34
	return b


## Condensed capitals in the set's metal, over a value or a group ("TEAM CHITIN").
static func eyebrow(text: String, size: int = 13, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	l.uppercase = true
	l.theme_type_variation = "EyebrowLabel"
	l.add_theme_font_size_override("font_size", ts(size))
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


## A big figure in the kit's condensed bold (counters, ammo, prices, timers).
static func number(text: String, size: int = 30, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "NumberLabel"
	l.add_theme_font_size_override("font_size", ts(size))
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


## A private copy of the HUD plate (grained, see-through, the set's corners).
static func hud_box() -> KitBox:
	return box_for(current, "hud")


## A row with a left-aligned caption and a control on the right.
static func row(caption: String, control: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	var l := label(tc(caption), 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size.x = 260
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 260)
	r.add_child(control)
	return r


## A section heading inside a settings tab or list: condensed capitals in the
## set's metal over a fine rule.
static func section(text: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var l := label(tc(text), 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.theme_type_variation = "EyebrowLabel"
	l.uppercase = true
	l.add_theme_constant_override("line_spacing", 0)
	v.add_child(l)
	var line := ColorRect.new()
	line.color = Color(c("accent"), 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	v.add_child(gap)
	return v


## A text block on paper: left-aligned, wrapped, in the soft ink.
static func note(text: String, size: int = 14) -> Label:
	var l := label(text, size)
	l.theme_type_variation = "SoftInkLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


static func _readout(fmt: String, v: float) -> String:
	return "%d%%" % roundi(v * 100.0) if fmt == "pct" else fmt % v


## A slider with a live value readout. `fmt` formats the value for display
## ("pct" shows a 0-1 value as a percentage).
static func slider(min_v: float, max_v: float, step: float, value: float, fmt: String,
		on_change: Callable) -> HBoxContainer:
	var box_ := HBoxContainer.new()
	box_.add_theme_constant_override("separation", 10)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(200, 24)
	var readout := label(_readout(fmt, value), 16)
	readout.custom_minimum_size.x = 60
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v: float) -> void:
		readout.text = _readout(fmt, v)
		on_change.call(v))
	box_.add_child(s)
	box_.add_child(readout)
	return box_


static func check(value: bool, on_change: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.button_pressed = value
	cb.toggled.connect(func(on: bool) -> void: on_change.call(on))
	return cb


## The set's ornament rule (rope and beetle, wheat stalk, bandolier, suits and dice).
static func divider(width: float = 360.0) -> TextureRect:
	var tr := Ornament.new()
	tr.custom_minimum_size = Vector2(width, 20)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return tr


## A full-screen tiled backdrop of the set (barn planks, burlap, diamond plate, baize).
static func backdrop() -> TextureRect:
	var tr := Backdrop.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Title Case for buttons, tabs, titles and item names: "start with CPU partner"
## -> "Start With CPU Partner". Small words stay lower inside the phrase, words
## already holding capitals (CPU, IP, x2) are left alone, text in brackets too.
static func tc(text: String) -> String:
	const SMALL := ["a", "an", "the", "of", "to", "in", "on", "at", "for", "and", "or", "by", "vs", "per", "as", "via", "into"]
	var words := text.split(" ")
	var out: PackedStringArray = []
	var first := true
	for w: String in words:
		if w == "":
			out.append(w)
			continue
		var lead := ""
		var core := w
		while core.length() > 0 and "([\"'".contains(core[0]):
			lead += core[0]
			core = core.substr(1)
		if core == "" or core != core.to_lower() or not core[0].is_valid_identifier():
			out.append(w)
			first = false
			continue
		if not first and SMALL.has(core) and lead == "":
			out.append(w)
		else:
			out.append(lead + core[0].to_upper() + core.substr(1))
		first = false
	return " ".join(out)


## Sentence case: first letter up, the rest as written.
static func sc(text: String) -> String:
	return text if text == "" else text[0].to_upper() + text.substr(1)


# ------------------------------------------------------------------ shared pieces
# Every menu is built from the same parts: scrim() behind it, a FramePanel holding
# strap() (title, tagline, stock chips on the right) over a PaperPanel body, rows on
# CardPanels, a footer of keycap hints (paper_hints) and buttons. Numbers read the
# same way everywhere: cost() "60 Scrap", held() "x2 Held", clock() "0:45".

## Spacing steps: between rows in a list, between groups.
const GAP_ROW := 8
const GAP_GROUP := 12
## Menu open fade (kept short so it never slows input).
const FADE_TIME := 0.12


## The keyboard-focus mark: the set's metal round the control, with the kit's braces.
static func focus_ring() -> StyleBox:
	return box("focus")


## The dimmed backdrop behind every full-screen menu (the set's dim colour).
static func scrim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = c("dim")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return dim


## A quick fade in for a menu that just opened (never blocks input).
static func fade_in(node: CanvasItem) -> void:
	if node == null or not node.is_inside_tree():
		return
	var old: Variant = node.get_meta(&"_fade") if node.has_meta(&"_fade") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	node.remove_meta(&"_closing")
	if node is Control:
		(node as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	node.modulate.a = 0.0
	var tw := node.create_tween().set_ignore_time_scale().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(node, "modulate:a", 1.0, FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	node.set_meta(&"_fade", tw)


## The matching close: the menu counts as closed at once (shown() is false, the
## mouse passes through it) and only its picture fades out, then it hides.
static func fade_out(node: CanvasItem) -> void:
	if node == null:
		return
	var old: Variant = node.get_meta(&"_fade") if node.has_meta(&"_fade") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	if not node.is_inside_tree() or not node.visible:
		node.visible = false
		node.modulate.a = 1.0
		return
	node.set_meta(&"_closing", true)
	if node is Control:
		(node as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		var f := node.get_viewport().gui_get_focus_owner()
		if f != null and (node as Control).is_ancestor_of(f):
			f.release_focus()
	var tw := node.create_tween().set_ignore_time_scale().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(node, "modulate:a", 0.0, FADE_TIME * 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		node.visible = false
		node.modulate.a = 1.0
		node.remove_meta(&"_closing")
		if node is Control:
			(node as Control).mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED)
	node.set_meta(&"_fade", tw)


## Open and not on its way out (a closing menu is still drawn while it fades).
static func shown(node: CanvasItem) -> bool:
	return node != null and node.visible and not node.has_meta(&"_closing")


## "60 Chitin", "1 Part", "5 Scrap": a count and its resource, the same everywhere.
## `resource` is the internal id ("scrap" = the team pot, "chitin" = your own),
## shown under its player-facing name (ResNames: they read swapped).
static func cost(n: float, resource: String) -> String:
	var word := tc(ResNames.word(resource.replace("_", " ")))
	var num := str(int(n)) if is_equal_approx(n, roundf(n)) else ("%.1f" % n)
	return "%s %s" % [num, word]


## "x2 Held": how many of a carried thing you have.
static func held(n: int) -> String:
	return "x%d Held" % n


## "0:45", "2:05": a timer.
static func clock(seconds: float) -> String:
	var s := maxi(int(ceilf(seconds)), 0)
	return "%d:%02d" % [s / 60, s % 60]


## Light status colours for text on the dark HUD cards (good, bad, warn).
static func hud_c(kind: String) -> Color:
	return c(kind + "_hud")


## The header strap of a menu: a display title (and an optional tagline) on the left;
## add stock chips or buttons to strap_row(strap) on the right.
static func strap(title_text: String, tagline: String = "", size: int = 30) -> PanelContainer:
	var head := panel("HeaderPanel")
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", GAP_GROUP)
	head.add_child(row)
	var words := VBoxContainer.new()
	words.name = "Words"
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var t := title(title_text, size, true)
	t.name = "Title"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words.add_child(t)
	var tag := strap_text(tagline, 14)
	tag.name = "Tagline"
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.visible = tagline != ""
	words.add_child(tag)
	return head


static func strap_row(head: PanelContainer) -> HBoxContainer:
	return head.get_node("Row") as HBoxContainer


## Light text on a header strap or a dark chip (follows the set).
static func strap_text(text: String, size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "HudLabel"
	l.add_theme_font_size_override("font_size", ts(size))
	l.add_theme_color_override("font_outline_color", Color(c("outline"), 0.7))
	l.add_theme_constant_override("outline_size", 4)
	return l


## The small dark chip style used for stock counts, price tags on the HUD and
## feed lines: the set's HUD card, slimmer.
static func chip_flat() -> StyleBoxFlat:
	var sb := hud_flat()
	sb.shadow_size = 0
	sb.set_border_width_all(1)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


## The swatch colour of each currency (the HUD counters, stock chips and price tags).
static func resource_color(resource: StringName) -> Color:
	match ResNames.icon_key(resource): # the team pot wears chitin's colour, your own stock scrap's
		&"scrap": return Palette.METAL.lightened(0.2)
		&"chitin": return Palette.BEETLE_TEAL.lightened(0.15)
		&"amber": return AmberRules.COLOR
		&"brands", &"notches": return Color(c("gold"))
	return Palette.BONE


## A painted icon (assets/icons, AI-made with fal.ai) for a resource or item,
## or null if there isn't one.
static func painted_icon(id: StringName) -> Texture2D:
	var key := {&"notches": &"brands", &"medicine": &"herbs"}.get(id, ResNames.icon_key(id)) as StringName
	var path := "res://assets/icons/%s.png" % key
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## A painted Field Guide plate (assets/plates, AI-made with fal.ai) for a bug
## or crop, or null.
static func plate(id: StringName) -> Texture2D:
	var path := "res://assets/plates/%s.png" % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## A currency's painted icon `px` square, or its colour swatch if it has none.
static func resource_chip(resource: StringName, px: float = 16.0) -> Control:
	var tex := painted_icon(resource)
	if tex == null:
		return swatch(resource_color(resource), px)
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px) * 1.5
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Aged paper (assets/paper, AI-made with fal.ai) as a panel: tinted toward
## `tint`, with a thin `border` line. Falls back to a flat panel.
static func aged_paper(tint: Color, border: Color, border_px: int = 2, margin: float = 12.0) -> StyleBox:
	if not ResourceLoader.exists("res://assets/paper/paper.jpg"):
		var flat := StyleBoxFlat.new()
		flat.bg_color = tint
		flat.border_color = border
		flat.set_border_width_all(border_px)
		flat.set_content_margin_all(margin)
		return flat
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/paper/paper.jpg")
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.modulate_color = Color(1, 1, 1).lerp(tint * 1.15, 0.35)
	sb.set_content_margin_all(margin)
	return sb


## A small rounded square in a currency's colour.
static func swatch(color: Color, px: float = 16.0) -> Panel:
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(px, px)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Palette.OUTLINE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	chip.add_theme_stylebox_override("panel", sb)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


## Tiers: the accent colour of a turret's tech tier (Early sage, Mid brass, Late rust).
static func tier_color(tier: int) -> Color:
	match tier:
		1: return Color(c("gold"))
		2: return Color("#E0704A")
	return Color(hud_c("good"))


## Tiers: a small tag chip naming a turret's tech tier ("Early", "Mid", "Late"),
## rimmed in the tier's colour; `locked` adds a padlock and dims it.
static func tier_chip(tier: int, locked: bool = false, size: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := chip_flat()
	var col := tier_color(tier)
	sb.border_color = col.darkened(0.25) if locked else col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	if locked:
		h.add_child(mark("lock", col, ts(size) - 2))
	var l := strap_text(tc(TurretDef.ERA_NAMES[clampi(tier, 0, TurretDef.ERA_NAMES.size() - 1)]), size)
	l.add_theme_color_override("font_color", col.darkened(0.15) if locked else col)
	h.add_child(l)
	return p


## Turret ammo: a small chip naming the crop that loads a crop-fed turret, with
## a dot of the crop's colour ("● Corn").
static func crop_chip(crop: CropDef, size: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", chip_flat())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	if crop == null:
		return p
	var dot := ColorRect.new()
	dot.color = crop.color
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(dot)
	var l := strap_text(tc(crop.display_name.get_slice(" ", 0) if crop.id == &"firecracker_chili" or crop.id == &"sarsaparilla" else crop.display_name), size)
	h.add_child(l)
	return p


## A small dark chip for a stock count on a header strap ("[swatch] 370 Scrap").
static func stock_chip(resource: StringName, amount: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", chip_flat())
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	p.add_child(h)
	h.add_child(resource_chip(resource, 14))
	# The team's shared pot: say so ("150 Team Chitin").
	var l := strap_text(cost(amount, ("team " if EconomyLedger.is_shared(resource) else "") + String(resource)), 16)
	l.name = "Text"
	h.add_child(l)
	return p


## A row of keycap hints for paper ("[E] [Esc] Close"): keys, then inked words.
## A key of "E/Esc" shows both caps.
static func paper_hints(pairs: Array) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 16)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair: Array in pairs:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 5)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k: String in str(pair[0]).split("/"):
			var cap := KeyHints.chip(k.strip_edges())
			cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(cap)
		var l := label(tc(str(pair[1])), 14)
		l.theme_type_variation = "SoftInkLabel"
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(l)
		r.add_child(h)
	return r


## A status line with a shape as well as a colour, so it reads without colour vision:
## kind = good (tick), bad (cross), warn (triangle), lock (padlock), info (dot).
## `on_hud` picks the light colours for dark cards.
static func status(text: String, kind: String = "info", size: int = 14, on_hud: bool = false) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := status_color(kind, on_hud)
	h.add_child(mark(kind, col, ts(size)))
	var l := label(text, size, col)
	l.name = "Text"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if on_hud:
		l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		l.add_theme_constant_override("outline_size", 3)
	h.add_child(l)
	return h


static func mark(kind: String, color: Color, px: float = 14.0) -> Mark:
	var m := Mark.new()
	m.kind = kind
	m.color = color
	m.custom_minimum_size = Vector2(px, px)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return m


static func status_color(kind: String, on_hud: bool = false) -> Color:
	match kind:
		"good": return hud_c("good") if on_hud else c("good")
		"bad": return hud_c("bad") if on_hud else c("bad")
		"warn", "lock": return hud_c("warn") if on_hud else c("warn")
	return c("hud") if on_hud else c("ink_soft")


## A small drawn status shape (tick, cross, warning triangle, padlock, dot).
class Mark extends Control:
	var kind := "info"
	var color := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) * 0.5
		var w := maxf(s * 0.16, 1.5)
		match kind:
			"good":
				draw_polyline(PackedVector2Array([o + Vector2(s * 0.15, s * 0.55), o + Vector2(s * 0.42, s * 0.8), o + Vector2(s * 0.88, s * 0.22)]), color, w, true)
			"bad":
				draw_line(o + Vector2(s * 0.2, s * 0.2), o + Vector2(s * 0.8, s * 0.8), color, w, true)
				draw_line(o + Vector2(s * 0.8, s * 0.2), o + Vector2(s * 0.2, s * 0.8), color, w, true)
			"warn":
				draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.5, s * 0.06), o + Vector2(s * 0.97, s * 0.92), o + Vector2(s * 0.03, s * 0.92)]), color)
				var cut := Color(1, 1, 1, 0.95) if color.get_luminance() < 0.5 else Color(0, 0, 0, 0.85)
				draw_line(o + Vector2(s * 0.5, s * 0.36), o + Vector2(s * 0.5, s * 0.62), cut, w * 0.8)
				draw_circle(o + Vector2(s * 0.5, s * 0.76), w * 0.45, cut)
			"lock":
				draw_rect(Rect2(o + Vector2(s * 0.18, s * 0.45), Vector2(s * 0.64, s * 0.47)), color)
				draw_arc(o + Vector2(s * 0.5, s * 0.45), s * 0.22, PI, TAU, 12, color, w, true)
			_:
				draw_circle(o + Vector2(s, s) * 0.5, s * 0.22, color)


static var _vignette: GradientTexture2D


static func vignette() -> Texture2D:
	if _vignette == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0, 0, 0, 0.6))
		_vignette = GradientTexture2D.new()
		_vignette.gradient = g
		_vignette.fill = GradientTexture2D.FILL_RADIAL
		_vignette.fill_from = Vector2(0.5, 0.5)
		_vignette.fill_to = Vector2(1.1, 1.1)
		_vignette.width = 128
		_vignette.height = 128
	return _vignette


# ------------------------------------------------------------------ live ornaments

## The set's ornament rule: a fine double line that meets a small emblem in the
## middle (Frontier a star, Sheaf a wheat ear, Irons crossed cartridges, Snake
## Eyes the four suits, Mandibles a pair of jaws). Drawn, so it's sharp everywhere.
class Ornament extends TextureRect:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture = null
		UiStyle.notifier.changed.connect(queue_redraw)

	func _exit_tree() -> void:
		if UiStyle.notifier.changed.is_connected(queue_redraw):
			UiStyle.notifier.changed.disconnect(queue_redraw)

	func _enter_tree() -> void:
		if is_node_ready() and not UiStyle.notifier.changed.is_connected(queue_redraw):
			UiStyle.notifier.changed.connect(queue_redraw)
			queue_redraw()

	func _draw() -> void:
		UiStyle.draw_ornament(self, Rect2(Vector2.ZERO, size), UiStyle.c("accent"), str(UiStyle.kit()["knob"]))


## Draws the ornament rule into `ci` across `r` (also used by Rule separators).
static func draw_ornament(ci: CanvasItem, r: Rect2, col: Color, motif: String) -> void:
	var cy := r.get_center().y
	var cx := r.get_center().x
	var gap := 18.0
	var faded := Color(col, 0.0)
	# Two hairlines that fade out toward the ends.
	for side: int in [-1, 1]:
		var a := Vector2(cx + side * gap, cy)
		var b := Vector2(r.position.x + 4.0 if side < 0 else r.end.x - 4.0, cy)
		ci.draw_polyline_colors(PackedVector2Array([a, b]), PackedColorArray([col, faded]), 1.2, true)
		ci.draw_polyline_colors(PackedVector2Array([a + Vector2(side * 4.0, 3.0), b + Vector2(-side * r.size.x * 0.12, 3.0)]), PackedColorArray([Color(col, 0.5), faded]), 1.0, true)
		ci.draw_circle(Vector2(cx + side * (gap - 6.0), cy), 1.6, col, true, -1.0, true)
	var e := Vector2(cx, cy)
	match motif:
		"star":
			ci.draw_colored_polygon(KitIcon._star(e, 7.0, 3.0, 5), col)
		"seed":
			ci.draw_line(e + Vector2(0, 7), e + Vector2(0, -8), col, 1.4, true)
			for i in 3:
				var y := 3.0 - i * 4.0
				for s: int in [-1, 1]:
					var leaf := PackedVector2Array()
					for j in 9:
						var t := j / 8.0
						leaf.append(e + Vector2(s * (sin(t * PI) * 2.4 + t * 2.0), y - t * 4.5))
					ci.draw_colored_polygon(leaf, col)
		"rivet":
			for s: int in [-1, 1]:
				var d := Vector2(s * 0.7, -0.7).normalized()
				var n := Vector2(-d.y, d.x)
				var base := e - d * 7.0
				ci.draw_colored_polygon(PackedVector2Array([base + n * 1.8, base + d * 9.5 + n * 1.8, base + d * 12.5, base + d * 9.5 - n * 1.8, base - n * 1.8]), col)
		"chip":
			var k := 3.6
			ci.draw_colored_polygon(PackedVector2Array([e + Vector2(-k * 2.2, -k), e + Vector2(-k * 1.3, 0), e + Vector2(-k * 2.2, k), e + Vector2(-k * 3.1, 0)]), col) # diamond
			ci.draw_circle(e + Vector2(-k * 0.45, -0.6), k * 0.55, col, true, -1.0, true) # club / spade-ish dots
			ci.draw_circle(e + Vector2(k * 0.45, -0.6), k * 0.55, col, true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([e + Vector2(-k * 0.95, 0), e + Vector2(k * 0.95, 0), e + Vector2(0, k * 1.2)]), col) # heart
			ci.draw_colored_polygon(PackedVector2Array([e + Vector2(k * 2.2, -k), e + Vector2(k * 3.1, k * 0.3), e + Vector2(k * 1.3, k * 0.3)]), col) # spade
			ci.draw_line(e + Vector2(k * 2.2, 0), e + Vector2(k * 2.2, k), col, 1.4)
		"hex":
			for s: int in [-1, 1]:
				var jaw := PackedVector2Array()
				for j in 9:
					var t := j / 8.0
					jaw.append(e + Vector2(s * (7.5 - sin(t * PI * 0.9) * 5.0 - t * 2.0), -6.0 + t * 12.0))
				ci.draw_polyline(jaw, col, 2.0, true)
			ci.draw_circle(e, 2.2, col, true, -1.0, true)
		_:
			ci.draw_colored_polygon(PackedVector2Array([e + Vector2(0, -5), e + Vector2(5, 0), e + Vector2(0, 5), e + Vector2(-5, 0)]), col)


## A separator style that draws the ornament rule.
class Rule extends StyleBox:
	var color := Color.WHITE
	var motif := "star"

	func _get_minimum_size() -> Vector2:
		return Vector2(0, 16)

	func _draw(item: RID, rect: Rect2) -> void:
		# StyleBoxes draw on a canvas item RID; borrow a helper node's drawing calls.
		var cy := rect.get_center().y
		var cx := rect.get_center().x
		var faded := Color(color, 0.0)
		for side: int in [-1, 1]:
			var a := Vector2(cx + side * 12.0, cy)
			var b := Vector2(rect.position.x if side < 0 else rect.end.x, cy)
			RenderingServer.canvas_item_add_polyline(item, PackedVector2Array([a, b]), PackedColorArray([color, faded]), 1.0, true)
		RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([Vector2(cx, cy - 4), Vector2(cx + 4, cy), Vector2(cx, cy + 4), Vector2(cx - 4, cy)]), PackedColorArray([color]))


## The full-screen backdrop of the set: its deep colour falling off to near-black,
## the set's grain, a vignette, and (Snake Eyes) the cards and dice on the table.
class Backdrop extends TextureRect:
	var set_id: StringName = &""

	func _ready() -> void:
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_TILE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		texture = null
		UiStyle.notifier.changed.connect(queue_redraw)

	func _exit_tree() -> void:
		if UiStyle.notifier.changed.is_connected(queue_redraw):
			UiStyle.notifier.changed.disconnect(queue_redraw)

	func _enter_tree() -> void:
		if is_node_ready() and not UiStyle.notifier.changed.is_connected(queue_redraw):
			UiStyle.notifier.changed.connect(queue_redraw)
			queue_redraw()

	func _draw() -> void:
		var sid := set_id if set_id != &"" else UiStyle.current
		var r := Rect2(Vector2.ZERO, size)
		var bd: Array = UiStyle.kit(sid)["backdrop"]
		var top := Color(str(bd[0]))
		var bot := Color(str(bd[1]))
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
			PackedColorArray([top, top.darkened(0.2), bot, bot]))
		var g := UiStyle._grain(str(UiStyle.kit(sid)["grain"]))
		if g != null:
			draw_texture_rect(g, r, true, Color(0, 0, 0, float(UiStyle.kit(sid)["grain_a"]) * 1.2))
		draw_texture_rect(UiStyle.vignette(), r, false)
		# Sets with things lying on the table (Snake Eyes: cards, dice, chips) pin them to the corners.
		var k := clampf(size.y / 1080.0, 0.6, 1.6)
		for corner: String in ["tl", "tr", "bl", "br"]:
			var t := UiStyle.texture(sid, "scatter_" + corner)
			if t == null:
				continue
			var sz := t.get_size() * k
			var pos := Vector2(0.0 if corner[1] == "l" else size.x - sz.x, 0.0 if corner[0] == "t" else size.y - sz.y)
			draw_texture_rect(t, Rect2(pos, sz), false)

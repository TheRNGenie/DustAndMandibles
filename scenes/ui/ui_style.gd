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

const SET_IDS: Array[StringName] = [&"base", &"sheaf", &"irons", &"snake"]
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
	for part: String in PARTS:
		_fill_box(box(part), part, set_id)
	_fill_font(set_id)
	_write_theme(ThemeDB.get_default_theme())
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
	var s: Dictionary = SETS.get(current if current != &"" else &"base", SETS[&"base"])
	return Color(str(s.get(key, "#FF00FF")))


static func ink() -> Color:
	return c("ink")


## The shared StyleBoxTexture for a part (frame, paper, poster, header, button,
## tab, card, icon, field, hud, chip...). Changes in place when the set swaps.
static func box(part: String) -> StyleBoxTexture:
	if not _boxes.has(part):
		_boxes[part] = StyleBoxTexture.new()
		if _installed and current != &"":
			_fill_box(_boxes[part], part, current)
	return _boxes[part]


static func texture(set_id: StringName, part: String) -> Texture2D:
	var key := "%s/%s" % [set_id, part]
	if not _textures.has(key):
		var path := DIR % [set_id, part]
		_textures[key] = load(path) if ResourceLoader.exists(path) else null
	return _textures[key]


static func _fill_box(sb: StyleBoxTexture, part: String, set_id: StringName) -> void:
	var m: Array = (PART_OVERRIDES.get(set_id, {}) as Dictionary).get(part, PARTS.get(part, [8, 8, 4, 4]))
	sb.texture = texture(set_id, part)
	sb.texture_margin_left = m[0]
	sb.texture_margin_right = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_bottom = m[1]
	sb.content_margin_left = m[2]
	sb.content_margin_right = m[2]
	sb.content_margin_top = m[3]
	sb.content_margin_bottom = m[3]
	var mode := StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH if part in STRETCHED else StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_horizontal = mode
	sb.axis_stretch_vertical = mode


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


# ------------------------------------------------------------------ the Godot theme

static func _write_theme(t: Theme) -> void:
	var empty := StyleBoxEmpty.new()
	# Buttons (OptionButton, MenuButton and CheckButton fall back to these).
	for type: String in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, box("button"))
		t.set_stylebox("hover", type, box("button_hover"))
		t.set_stylebox("pressed", type, box("button_pressed"))
		t.set_stylebox("hover_pressed", type, box("button_pressed"))
		t.set_stylebox("disabled", type, box("button_disabled"))
		t.set_stylebox("focus", type, focus_ring())
		_button_colors(t, type, c("btn"), c("btn_hover"), c("btn_off"))
		t.set_color("font_outline_color", type, c("btn_outline"))
		t.set_constant("outline_size", type, 4)
	# Check boxes and switches: the set's own marks.
	for type: String in ["CheckBox", "CheckButton"]:
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			t.set_stylebox(st, type, empty)
		t.set_icon("checked", type, texture(current, "check_on"))
		t.set_icon("unchecked", type, texture(current, "check_off"))
		t.set_icon("checked_disabled", type, texture(current, "check_on"))
		t.set_icon("unchecked_disabled", type, texture(current, "check_off"))
		_button_colors(t, type, c("ink"), c("ink"), c("ink_soft"))
		t.set_constant("outline_size", type, 0)
		t.set_constant("h_separation", type, 8)
	# Text fields.
	t.set_stylebox("normal", "LineEdit", box("field"))
	t.set_stylebox("focus", "LineEdit", box("field_focus"))
	t.set_stylebox("read_only", "LineEdit", box("field"))
	t.set_color("font_color", "LineEdit", c("ink"))
	t.set_color("font_placeholder_color", "LineEdit", c("ink_soft"))
	t.set_color("caret_color", "LineEdit", c("ink"))
	t.set_color("selection_color", "LineEdit", Color(c("accent"), 0.4))
	# Sliders.
	for type: String in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, box("slider"))
		t.set_stylebox("grabber_area", type, box("slider_fill"))
		t.set_stylebox("grabber_area_highlight", type, box("slider_fill"))
		t.set_icon("grabber", type, texture(current, "grabber"))
		t.set_icon("grabber_highlight", type, texture(current, "grabber_hl"))
		t.set_icon("grabber_disabled", type, texture(current, "grabber"))
		t.set_constant("center_grabber", type, 1)
	# Scrollbars (vertical: every list and tab body scrolls that way).
	t.set_stylebox("scroll", "VScrollBar", box("scroll"))
	t.set_stylebox("scroll_focus", "VScrollBar", box("scroll"))
	t.set_stylebox("grabber", "VScrollBar", box("scroll_grab"))
	t.set_stylebox("grabber_highlight", "VScrollBar", box("scroll_grab_hl"))
	t.set_stylebox("grabber_pressed", "VScrollBar", box("scroll_grab_hl"))
	# Tabs.
	for type: String in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_unselected", type, box("tab"))
		t.set_stylebox("tab_hovered", type, box("tab_hover"))
		t.set_stylebox("tab_selected", type, box("tab_selected"))
		t.set_stylebox("tab_disabled", type, box("tab"))
		t.set_stylebox("tab_focus", type, focus_ring())
		t.set_color("font_unselected_color", type, c("tab"))
		t.set_color("font_hovered_color", type, c("tab"))
		t.set_color("font_selected_color", type, c("tab_sel"))
		t.set_color("font_outline_color", type, Color(0, 0, 0, 0))
		t.set_constant("tab_separation", type, 4)
	t.set_stylebox("panel", "TabContainer", box("card"))
	t.set_stylebox("tabbar_background", "TabContainer", empty)
	# Popups, dropdown lists and tooltips: on paper.
	t.set_stylebox("panel", "PopupMenu", box("paper"))
	t.set_stylebox("hover", "PopupMenu", box("card_hover"))
	t.set_color("font_color", "PopupMenu", c("ink"))
	t.set_color("font_hover_color", "PopupMenu", c("ink"))
	t.set_color("font_disabled_color", "PopupMenu", c("ink_soft"))
	t.set_stylebox("panel", "TooltipPanel", box("paper"))
	t.set_color("font_color", "TooltipLabel", c("ink"))
	# Separators: a thin rule in the set's accent.
	var line := StyleBoxLine.new()
	line.color = Color(c("ink_soft"), 0.6)
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 10)
	_variations(t)


static func _button_colors(t: Theme, type: String, normal: Color, hover: Color, off: Color) -> void:
	t.set_color("font_color", type, normal)
	t.set_color("font_hover_color", type, hover)
	t.set_color("font_pressed_color", type, hover)
	t.set_color("font_hover_pressed_color", type, hover)
	t.set_color("font_focus_color", type, normal)
	t.set_color("font_disabled_color", type, off)


## Named surfaces and text styles screens pick with `theme_type_variation`.
static func _variations(t: Theme) -> void:
	for pair: Array in [["FramePanel", "frame"], ["PaperPanel", "paper"], ["PosterPanel", "poster"],
			["HeaderPanel", "header"], ["CardPanel", "card"], ["CardHoverPanel", "card_hover"], ["IconPanel", "icon"],
			["HudPanel", "hud"], ["ChipPanel", "chip"], ["ChipBadPanel", "chip_bad"]]:
		t.set_type_variation(pair[0], "PanelContainer")
		t.set_stylebox("panel", pair[0], box(pair[1]))
	# Tab-like toggles made of Buttons (MenuScreen tabs, bet pickers, ledger tabs).
	t.set_type_variation("TabButton", "Button")
	t.set_stylebox("normal", "TabButton", box("tab"))
	t.set_stylebox("hover", "TabButton", box("tab_hover"))
	t.set_stylebox("pressed", "TabButton", box("tab_selected"))
	t.set_stylebox("hover_pressed", "TabButton", box("tab_selected"))
	t.set_stylebox("disabled", "TabButton", box("button_disabled"))
	_button_colors(t, "TabButton", c("tab"), c("tab"), c("btn_off"))
	t.set_constant("outline_size", "TabButton", 0)
	t.set_stylebox("focus", "TabButton", focus_ring())
	t.set_type_variation("TabButtonSelected", "Button")
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "TabButtonSelected", box("tab_selected"))
	t.set_stylebox("focus", "TabButtonSelected", focus_ring())
	_button_colors(t, "TabButtonSelected", c("tab_sel"), c("tab_sel"), c("tab_sel"))
	t.set_constant("outline_size", "TabButtonSelected", 0)
	# Labels.
	for pair: Array in [["InkLabel", "ink"], ["SoftInkLabel", "ink_soft"], ["HudLabel", "hud"], ["GoldLabel", "gold"],
			["BadLabel", "bad"], ["GoodLabel", "good"], ["WarnLabel", "warn"]]:
		t.set_type_variation(pair[0], "Label")
		t.set_color("font_color", pair[0], c(pair[1]))
	for pair: Array in [["TitleLabel", "ink", false], ["HeaderTitle", "title", true]]:
		t.set_type_variation(pair[0], "Label")
		t.set_font("font", pair[0], display_font())
		t.set_color("font_color", pair[0], c(pair[1]))
		t.set_color("font_outline_color", pair[0], c("outline"))
		t.set_constant("outline_size", pair[0], 8 if pair[2] else 0)
		t.set_color("font_shadow_color", pair[0], Color(0, 0, 0, 0.45) if pair[2] else Color(c("ink"), 0.12))
		t.set_constant("shadow_offset_x", pair[0], 2)
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


## The HUD card: the set's dark ground (leather brown, barn green, gunmetal,
## baize) with its trim (brass, wheat, gold). Flat and light so the HUD stays quiet.
static func hud_flat() -> StyleBoxFlat:
	var s: Dictionary = SETS.get(current if current != &"" else &"base", SETS[&"base"])
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(str(s["hud_bg"]))
	sb.border_color = Color(str(s["hud_rim"]))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(s["radius"]))
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.set_content_margin_all(10)
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


## The one bar style for health, boss, water and progress bars: a dark inked
## trough with an outline, and a fill with a lighter lip along its top edge.
static func bar(color: Color, min_size: Vector2 = Vector2(240, 18), max_value: float = 100.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = min_size
	b.max_value = max_value
	b.value = max_value
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(Palette.OUTLINE, 0.85)
	bg.border_color = Palette.OUTLINE
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	bg.shadow_color = Color(0, 0, 0, 0.25)
	bg.shadow_size = 2
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", bar_fill(color))
	return b


## The fill of a bar(): the colour with a lighter lip on top (call again to recolour).
static func bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = color.lightened(0.35)
	sb.border_width_top = 3
	sb.set_corner_radius_all(3)
	sb.expand_margin_left = -2
	sb.expand_margin_right = -2
	sb.expand_margin_top = -2
	sb.expand_margin_bottom = -2
	return sb


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
	return best if is_equal_approx(text_scale, 1.0) else roundi(best * text_scale)


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
	b.custom_minimum_size.y = 40
	b.focus_mode = Control.FOCUS_NONE
	return b


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


## A section heading inside a settings tab or list: a Title Case caption over a rule.
static func section(text: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var l := label(tc(text), 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not display_is_decorative(): # an ornate face (Snake Eyes) stays on big titles only
		l.add_theme_font_override("font", display_font())
	v.add_child(l)
	v.add_child(HSeparator.new())
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
	tr.custom_minimum_size = Vector2(width, 22)
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


## The keyboard-focus ring: a thin outline in the set's highlight, outside the button.
static func focus_ring() -> StyleBoxFlat:
	if not _boxes.has("_focus"):
		var f := StyleBoxFlat.new()
		f.draw_center = false
		f.set_border_width_all(2)
		f.set_corner_radius_all(6)
		f.set_expand_margin_all(3)
		f.anti_aliasing = true
		_boxes["_focus"] = f
	var sb := _boxes["_focus"] as StyleBoxFlat
	sb.border_color = c("focus")
	return sb


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


## "60 Scrap", "1 Part", "5 Chitin": a count and its resource, the same everywhere.
static func cost(n: float, resource: String) -> String:
	var word := tc(resource.replace("_", " "))
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
	match resource:
		&"scrap": return Palette.METAL.lightened(0.2)
		&"chitin": return Palette.BEETLE_TEAL.lightened(0.15)
		&"brands", &"notches": return Color(c("gold"))
	return Palette.BONE


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


## A small dark chip for a stock count on a header strap ("[swatch] 370 Scrap").
static func stock_chip(resource: StringName, amount: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", chip_flat())
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	p.add_child(h)
	h.add_child(swatch(resource_color(resource), 14))
	# Scrap is the team's shared pot: say so ("150 Team Scrap").
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

class Ornament extends TextureRect:
	func _ready() -> void:
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_refresh()
		UiStyle.notifier.changed.connect(_refresh)

	func _exit_tree() -> void:
		if UiStyle.notifier.changed.is_connected(_refresh):
			UiStyle.notifier.changed.disconnect(_refresh)

	func _enter_tree() -> void:
		if is_node_ready() and not UiStyle.notifier.changed.is_connected(_refresh):
			UiStyle.notifier.changed.connect(_refresh)
			_refresh()

	func _refresh() -> void:
		texture = UiStyle.texture(UiStyle.current, "divider")


class Backdrop extends TextureRect:
	var set_id: StringName = &""

	func _ready() -> void:
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_TILE
		_refresh()
		UiStyle.notifier.changed.connect(_refresh)

	func _exit_tree() -> void:
		if UiStyle.notifier.changed.is_connected(_refresh):
			UiStyle.notifier.changed.disconnect(_refresh)

	func _enter_tree() -> void:
		if is_node_ready() and not UiStyle.notifier.changed.is_connected(_refresh):
			UiStyle.notifier.changed.connect(_refresh)
			_refresh()

	func _refresh() -> void:
		texture = UiStyle.texture(set_id if set_id != &"" else UiStyle.current, "backdrop")
		queue_redraw()

	func _draw() -> void:
		# A soft vignette over the tiles.
		draw_texture_rect(UiStyle.vignette(), Rect2(Vector2.ZERO, size), false)
		# Sets with things lying on the table (Snake Eyes: cards, dice, chips) pin them to the corners.
		var sid := set_id if set_id != &"" else UiStyle.current
		var k := clampf(size.y / 1080.0, 0.6, 1.6)
		for corner: String in ["tl", "tr", "bl", "br"]:
			var t := UiStyle.texture(sid, "scatter_" + corner)
			if t == null:
				continue
			var sz := t.get_size() * k
			var pos := Vector2(0.0 if corner[1] == "l" else size.x - sz.x, 0.0 if corner[0] == "t" else size.y - sz.y)
			draw_texture_rect(t, Rect2(pos, sz), false)

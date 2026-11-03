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
		"btn": "#F8EBCF", "btn_hover": "#FFFFFF", "btn_off": "#C9BCA6", "btn_outline": "#2A170B",
		"tab": "#2E1D10", "tab_sel": "#F2C14E", "accent": "#3E8E7E", "gold": "#E8B53A", "good": "#3F6B2A",
		"bad": "#9B3B2E", "dim": "#140B0599", "hud": "#F2E3C2", "bg": "#3B2A1E",
		"hud_bg": "#2A1A0FE6", "hud_rim": "#9C7440", "radius": 6,
		"file": "res://assets/fonts/Rye-Regular.ttf", "fonts": ["Georgia", "Cambria", "Times New Roman"], "weight": 700, "italic": false, "spacing": 1, "wdth": 0,
	},
	&"sheaf": {
		"name": "The Sheaf", "ink": "#2F2A12", "ink_soft": "#5E5532", "title": "#F1D27A", "outline": "#14200A",
		"btn": "#F6EFD6", "btn_hover": "#FFFFFF", "btn_off": "#C8C8B4", "btn_outline": "#1A2A0E",
		"tab": "#2F2A12", "tab_sel": "#F1D27A", "accent": "#5E8C31", "gold": "#D9A928", "good": "#3F6B2A",
		"bad": "#9B3B2E", "dim": "#16140899", "hud": "#F3E7C4", "bg": "#4A3A22",
		"hud_bg": "#22341AE6", "hud_rim": "#C9A04A", "radius": 4,
		"file": "res://assets/fonts/Sancreek-Regular.ttf", "fonts": ["Constantia", "Palatino Linotype", "Georgia"], "weight": 700, "italic": false, "spacing": 1, "wdth": 0,
	},
	&"irons": {
		"name": "The Crossed Irons", "ink": "#1E1A16", "ink_soft": "#4E463C", "title": "#E8C06A", "outline": "#0A0D12",
		"btn": "#E6ECF2", "btn_hover": "#FFFFFF", "btn_off": "#A9AEB3", "btn_outline": "#05080C",
		"tab": "#1E1A16", "tab_sel": "#E8C06A", "accent": "#B8862E", "gold": "#E3B55B", "good": "#4B6B2A",
		"bad": "#A33A2A", "dim": "#0B0E1199", "hud": "#E6EAEE", "bg": "#22140C",
		"hud_bg": "#141C26E6", "hud_rim": "#B8862E", "radius": 3,
		"file": "res://assets/fonts/SpecialElite-Regular.ttf", "fonts": ["Bahnschrift", "Arial Narrow", "Impact"], "weight": 700, "italic": false, "spacing": 2, "wdth": 75,
	},
	&"snake": {
		"name": "The Snake Eyes", "ink": "#17120F", "ink_soft": "#5A4A44", "title": "#E9C46A", "outline": "#0A1F10",
		"btn": "#FFF5E6", "btn_hover": "#FFFFFF", "btn_off": "#D8D0C8", "btn_outline": "#3A0806",
		"tab": "#17120F", "tab_sel": "#FFF5E6", "accent": "#B3261E", "gold": "#E9C46A", "good": "#2E7D32",
		"bad": "#B3261E", "dim": "#06140A99", "hud": "#F4ECDA", "bg": "#123B1E",
		"hud_bg": "#123A20E6", "hud_rim": "#E9C46A", "radius": 10,
		"file": "res://assets/fonts/Ewert-Regular.ttf", "fonts": ["Palatino Linotype", "Book Antiqua", "Georgia"], "weight": 700, "italic": true, "spacing": 1, "wdth": 0,
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
		t.set_stylebox("focus", type, empty)
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
		t.set_stylebox("tab_focus", type, empty)
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
	t.set_type_variation("TabButtonSelected", "Button")
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "TabButtonSelected", box("tab_selected"))
	_button_colors(t, "TabButtonSelected", c("tab_sel"), c("tab_sel"), c("tab_sel"))
	t.set_constant("outline_size", "TabButtonSelected", 0)
	# Labels.
	for pair: Array in [["InkLabel", "ink"], ["SoftInkLabel", "ink_soft"], ["HudLabel", "hud"], ["GoldLabel", "gold"],
			["BadLabel", "bad"], ["GoodLabel", "good"]]:
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


## The type scale: every UI font size snaps to one of these steps (fine print,
## small, body, emphasis, header, title, and three display sizes), so text
## sizes line up across every screen.
const TYPE_SCALE: Array[int] = [12, 14, 16, 18, 22, 30, 40, 54, 64]


## The nearest step of the type scale (ties go up).
static func ts(size: int) -> int:
	var best := TYPE_SCALE[0]
	for s in TYPE_SCALE:
		if absi(s - size) <= absi(best - size):
			best = s
	return best


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
	var l := label(caption, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size.x = 260
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 260)
	r.add_child(control)
	return r


## A slider with a live value readout. `fmt` formats the value for display.
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
	var readout := label(fmt % value, 15)
	readout.custom_minimum_size.x = 60
	s.value_changed.connect(func(v: float) -> void:
		readout.text = fmt % v
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

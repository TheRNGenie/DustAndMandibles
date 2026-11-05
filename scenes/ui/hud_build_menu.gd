class_name HudBuildMenu
extends Control
## The build catalog (B): a wooden panel on the left. Category tabs across the
## top, the open category as a grid of tiles (picture, name, price), and a
## detail strip for the item under the mouse: what it does and where it goes.
## Clicking a tile (or pressing its number) picks it for placing.

const WIDTH := 580.0
const COLS := 3
const TILE := Vector2(168, 128)
const ICON_SIZE := 68
## Room kept clear under the panel for the hotbar and the resources card.
const BOTTOM_CLEAR := 160.0 # clears the resource card (two lines tall in solo)

var build_mode: BuildMode
var _panel: PanelContainer
var _tabs: Array[Button] = []
var _grid: GridContainer
var _scrap: Label
var _detail_name: Label
var _detail_cost: Label
var _detail_stats: Label
var _detail_desc: Label
var _detail_where: Label
var _detail_id: StringName = &""
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.fit(self) # Theme: bigger on 1440p and up
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	var sb := UiStyle.wood_sign()
	sb.bg_color.a = 0.95 # Theme: the set's HUD card
	sb.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", sb)
	# Sized to its content (three rows of tiles), clear of the resources panel.
	_panel.offset_left = 24
	_panel.offset_right = 24 + WIDTH
	_panel.offset_top = 96
	_panel.visible = false
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	# Header: title and how much is in the team pot (shown as chitin).
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UiStyle.title("Build", 30, true) # Theme
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_scrap = KeyHints.text("", 16, UiStyle.c("hud"))
	_scrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_scrap)

	# Category tabs.
	# Category tabs: they wrap onto a second row rather than spill past the panel.
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	col.add_child(tabs)
	for c in Defs.BUILD_CATEGORIES.size():
		var b := Button.new()
		b.text = UiStyle.tc(str(Defs.BUILD_CATEGORIES[c]["name"]))
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(96, 32)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func() -> void: build_mode.show_category(c))
		tabs.add_child(b)
		_tabs.append(b)
	col.add_child(_rule())

	# The items.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = TILE.y * 3.0 + 20.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_scroll = scroll
	resized.connect(_fit_height)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	# Detail strip for the item under the mouse.
	col.add_child(_rule())
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 4)
	detail.custom_minimum_size.y = 124
	col.add_child(detail)
	var dhead := HBoxContainer.new()
	detail.add_child(dhead)
	_detail_name = KeyHints.text("", 18, UiStyle.c("hud"))
	_detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dhead.add_child(_detail_name)
	_detail_cost = KeyHints.text("", 16, UiStyle.c("title"))
	dhead.add_child(_detail_cost)
	# The key numbers on one line, like a gun's in the shop.
	_detail_stats = KeyHints.text("", 14, UiStyle.c("title"))
	_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_stats.custom_minimum_size.x = WIDTH - 40
	detail.add_child(_detail_stats)
	_detail_desc = KeyHints.text("", 14, UiStyle.c("hud"))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.custom_minimum_size.x = WIDTH - 40
	detail.add_child(_detail_desc)
	_detail_where = KeyHints.text("", 14, UiStyle.c("hud").darkened(0.18))
	detail.add_child(_detail_where)

	col.add_child(KeyHints.row([["LMB", "Choose"], ["1-9", "Quick pick"],
			[KeyHints.key_for("build_menu"), "Close"], ["RMB", "Leave"]]))


## Fits the tile list between the header and the hotbar (3 rows when there's room).
func _fit_height() -> void:
	if _scroll == null:
		return
	_scroll.custom_minimum_size.y = TILE.y * 3.0 + 20.0
	var room := size.y - _panel.offset_top - BOTTOM_CLEAR
	var over := _panel.get_combined_minimum_size().y - room
	if over > 0.0:
		_scroll.custom_minimum_size.y = maxf(TILE.y + 10.0, _scroll.custom_minimum_size.y - over)
	_panel.reset_size()


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(UiStyle.c("hud_rim"), 0.45)
	r.custom_minimum_size.y = 2
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func bind(bm: BuildMode) -> void:
	build_mode = bm
	build_mode.changed.connect(refresh)
	Economy.resources_changed.connect(func(_c: int) -> void:
		if _panel.visible:
			refresh())
	refresh()


func refresh() -> void:
	if build_mode == null:
		return
	_panel.visible = build_mode.active and build_mode.menu_open
	if not _panel.visible:
		return
	if build_mode.category < 0:
		build_mode.category = 1
	var payer := build_mode.player.cliff_id
	_scrap.text = UiStyle.cost(Economy.amount(payer, &"scrap"), "team scrap") # the shared pot
	for c in _tabs.size():
		_style_tab(_tabs[c], c == build_mode.category)
	for n in _grid.get_children():
		_grid.remove_child(n)
		n.queue_free()
	var items: Array = build_mode.category_items(build_mode.category)
	var picked: Control = null
	for i in items.size():
		var tile := _tile(i, items[i], payer)
		_grid.add_child(tile)
		if items[i] == build_mode.selected_id():
			picked = tile
	if picked != null: # the picked item stays in view (the Late ones sit at the bottom)
		var ref: WeakRef = weakref(picked) # the grid may be rebuilt before this runs
		(func() -> void:
			var c := ref.get_ref() as Control
			if c != null and _scroll.is_ancestor_of(c):
				_scroll.ensure_control_visible(c)).call_deferred()
	if not items.has(_detail_id):
		_detail_id = build_mode.selected_id() if items.has(build_mode.selected_id()) else (items[0] if not items.is_empty() else &"")
	_show_detail(_detail_id, payer)
	_fit_height.call_deferred()


func _style_tab(b: Button, on: bool) -> void:
	b.theme_type_variation = "TabButtonSelected" if on else "TabButton" # Theme
	b.custom_minimum_size.y = 32


func _tile(i: int, id: StringName, payer: int) -> Button:
	var cost := Perks.build_cost(multiplayer.get_unique_id(), id) # Perk: build discounts
	var affordable := GameState.is_solo() or Economy.can_afford(payer, {&"scrap": cost})
	var locked := not BuildMode.unlocked(id) # Tiers: Mid / Late before their wave
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = TILE
	# Theme: tiles in the set's HUD colours, the picked one rimmed in its gold.
	var normal := UiStyle.hud_flat()
	normal.bg_color = normal.bg_color.lightened(0.12)
	normal.bg_color.a = 0.9
	normal.shadow_size = 0
	normal.border_color = UiStyle.c("gold") if id == build_mode.selected_id() else normal.border_color.darkened(0.35)
	normal.set_border_width_all(3 if id == build_mode.selected_id() else 2)
	if locked:
		normal.bg_color = normal.bg_color.darkened(0.3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.15)
	hover.border_color = UiStyle.c("hud")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.15)
	b.add_theme_stylebox_override("pressed", pressed)
	b.pressed.connect(func() -> void: build_mode.choose(id))
	b.mouse_entered.connect(func() -> void:
		_detail_id = id
		_show_detail(id, payer))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 6
	col.offset_bottom = -6
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := TextureRect.new()
	icon.texture = icon_for(id)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		icon.modulate = Color(0.35, 0.35, 0.35, 0.55)
	elif not affordable:
		icon.modulate = Color(1, 1, 1, 0.45)
	col.add_child(icon)
	var name_l := KeyHints.text(Defs.name_of(id), 14, UiStyle.c("hud").darkened(0.35) if locked else UiStyle.c("hud"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	col.add_child(name_l)
	# The price; one you can't afford gets a cross as well as the red.
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 4)
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(price_row)
	if locked:
		price_row.add_child(UiStyle.mark("lock", UiStyle.hud_c("warn"), 12))
		price_row.add_child(KeyHints.text("Wave %d" % Defs.unlock_wave(id), 14, UiStyle.hud_c("warn")))
	elif not affordable:
		price_row.add_child(UiStyle.mark("bad", UiStyle.hud_c("bad"), 12))
	if not locked:
		price_row.add_child(KeyHints.text(UiStyle.held(Economy.amount(payer, id)) if CraftTable.is_item_turret(id) else UiStyle.cost(cost, "scrap"), 14, UiStyle.c("title") if affordable else UiStyle.hud_c("bad")))
	# Its quick-pick number in the corner.
	if i < 9:
		var k := KeyHints.chip(str(i + 1))
		k.position = Vector2(6, 6)
		b.add_child(k)
	# Tiers: an Early / Mid / Late tag in the other corner.
	if Defs.TURRETS.has(id):
		var tag := UiStyle.tier_chip(Defs.tier_of(id), locked)
		tag.anchor_left = 1.0
		tag.anchor_right = 1.0
		tag.offset_left = -6.0
		tag.offset_right = -6.0
		tag.offset_top = 6.0
		tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		b.add_child(tag)
	if locked:
		b.tooltip_text = Defs.lock_reason(id, GameState.tier_wave())
	return b


func _show_detail(id: StringName, payer: int) -> void:
	if id == &"":
		for l: Label in [_detail_name, _detail_cost, _detail_stats, _detail_desc, _detail_where]:
			l.text = ""
		return
	var cost := Perks.build_cost(multiplayer.get_unique_id(), id) # Perk: build discounts
	var affordable := GameState.is_solo() or Economy.can_afford(payer, {&"scrap": cost})
	_detail_name.text = Defs.name_of(id)
	_detail_cost.text = (UiStyle.held(Economy.amount(payer, id)) + "  ·  Crafted") if CraftTable.is_item_turret(id) else UiStyle.cost(cost, "scrap")
	_detail_cost.add_theme_color_override("font_color", UiStyle.c("title") if affordable else UiStyle.hud_c("bad"))
	if not affordable and not CraftTable.is_item_turret(id):
		_detail_cost.text += "  ·  Can't Afford"
	if not BuildMode.unlocked(id): # Tiers
		_detail_cost.text += "  ·  " + Defs.lock_reason(id, GameState.tier_wave())
		_detail_cost.add_theme_color_override("font_color", UiStyle.hud_c("warn"))
	_detail_stats.text = UiStyle.keep_together(Defs.turret(id).stat_line() if Defs.is_turret(id) else _structure_stats(id))
	_detail_stats.visible = _detail_stats.text != ""
	_detail_desc.text = BuildMode._description(id)
	# Turrets (Helper 3): their one job, weakness and any upkeep on a second line.
	if Defs.is_turret(id) and Defs.turret(id).role_line() != "":
		_detail_desc.text += "\n" + Defs.turret(id).role_line()
	_detail_where.text = _where(id)
	if Defs.TURRETS.has(id): # Tiers: which tier, and when it opens
		var d := Defs.turret(id)
		_detail_where.text = "%s Tier%s.  %s" % [d.era_name(), "" if d.tier == 0 else " (from Wave %d)" % d.unlock_wave(), _detail_where.text]


## Walls, traps and the like: their toughness (and reach, for traps and lights).
static func _structure_stats(id: StringName) -> String:
	var d := Defs.structure(id)
	if d == null:
		return ""
	var parts: PackedStringArray = ["%s HP" % TurretDef._num(d.max_hp)]
	match d.kind:
		StructureDef.Kind.BARBED_WIRE, StructureDef.Kind.BEAR_TRAP, StructureDef.Kind.DYNAMITE_CRATE:
			parts.append("Reach %s m" % TurretDef._num(d.radius))
		StructureDef.Kind.LANTERN:
			parts.append("Lights %s m" % TurretDef._num(d.radius))
	return "  ·  ".join(parts)


static func _where(id: StringName) -> String:
	if Defs.is_house_turret(id):
		return "Goes on the house: porch, balcony or roof deck."
	if Defs.is_crewed(id): # Crewed
		return "Takes 2 x 2 of bare ground, no scaffold. Sit in it to aim and fire it yourself."
	if Defs.is_turret(id):
		if Defs.gets_scaffold(id):
			return "Goes anywhere on your plateau, on a free scaffold."
		return "Goes anywhere on your plateau."
	return "Goes anywhere on your plateau."


## A small picture of the item, rendered once from its real 3D model.
func icon_for(id: StringName) -> Texture2D:
	var color := Palette.team_color(build_mode.player.cliff_id) if build_mode != null else Color.WHITE
	if Defs.is_turret(id):
		return IconStudio.turret(self, id, color)
	return IconStudio.structure(self, id)

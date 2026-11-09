class_name HudBuildMenu
extends Control
## The build catalog (B): a kit window on the left. The header strap holds the
## title and the team pot, underline tabs pick the category, the open category is
## a grid of tiles (picture, name, price), and a detail card beside it shows the
## item under the mouse: its numbers as chips, what it does and where it goes.
## Clicking a tile (or pressing its number) picks it for placing.
## (Units are the 1600 x 900 canvas; the window stretches it to the screen.)

const WIDTH := 840.0
const COLS := 3
const TILE := Vector2(150, 128)
const ICON_SIZE := 60
const DETAIL_WIDTH := 300.0
const TOP := 78.0
## Room kept clear under the window when the HUD status card can't be found
## (normally the window stops just above that card's live top: _status_top).
const BOTTOM_CLEAR := 280.0
## The gap kept between the window and the status card.
const STATUS_GAP := 8.0
## The window never gets shorter than this (small windows let it overlap instead).
const MIN_HEIGHT := 440.0

var build_mode: BuildMode
var _panel: PanelContainer
var _tabs: Array[Button] = []
## The kind selector (All / Standard / Crop-Fed) under the tabs.
var _kinds: Array[Button] = []
var _empty: Label
var _grid: GridContainer
var _stock: HBoxContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_price: HBoxContainer
var _detail_status: VBoxContainer
var _detail_chart: VBoxContainer
var _detail_desc: Label
var _detail_role: Label
var _detail_where: Label
var _detail_id: StringName = &""
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.fit(self) # Theme: bigger on 1440p and up
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = UiStyle.panel("FramePanel")
	_panel.offset_left = 20
	_panel.offset_right = 20 + WIDTH
	_panel.offset_top = TOP
	_panel.visible = false
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	_panel.add_child(outer)

	# Header strap: the title, and the team pot on the right.
	var head := UiStyle.strap("Build", "", 30)
	outer.add_child(head)
	_stock = HBoxContainer.new()
	_stock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.strap_row(head).add_child(_stock)

	var paper := UiStyle.panel("PaperPanel")
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiStyle.GAP_GROUP)
	paper.add_child(col)

	# Category tabs: underlined, four to a row, on a hairline.
	var tabs := GridContainer.new()
	tabs.columns = 4
	tabs.add_theme_constant_override("h_separation", 2)
	tabs.add_theme_constant_override("v_separation", 0)
	col.add_child(tabs)
	var tab_defs := Defs.build_tabs()
	for c in tab_defs.size():
		var b := Button.new()
		b.text = UiStyle.tc(str(tab_defs[c]["name"]))
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_font_size_override("font_size", UiStyle.ts(16))
		b.pressed.connect(func() -> void: build_mode.show_category(c))
		tabs.add_child(b)
		GlowRing.attach(b, str(tab_defs[c]["name"]))
		_tabs.append(b)

	# The kind selector: every tab sorts into Standard (always fires) and
	# Crop-Fed (needs a load of its crop each wave), or shows All.
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 6)
	col.add_child(kinds)
	var show := UiStyle.eyebrow("Show", 13)
	show.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	show.custom_minimum_size.x = 44
	kinds.add_child(show)
	for k in Defs.KIND_NAMES.size():
		var kb := Button.new()
		kb.focus_mode = Control.FOCUS_NONE
		kb.custom_minimum_size = Vector2(0, 30)
		kb.add_theme_font_override("font", UiStyle.font("label"))
		kb.add_theme_font_size_override("font_size", UiStyle.ts(15))
		kb.tooltip_text = ["Every build in this tab.", "Turrets that always fire, and builds that need no crop.",
			"Turrets that take a sack of any crop each wave (Q on one picks the crop).",
			"Air defense: guns that shoot fliers first. They go on the cliff edge, always at the top of a 3-high stack (the scaffold goes up free)."][k]
		if k == Defs.KIND_AIR:
			kb.add_theme_color_override("font_color", UiStyle.AIR_COLOR)
		if k == Defs.KIND_CROP_FED:
			kb.icon = UiStyle.painted_icon(&"corn")
			kb.expand_icon = true
			kb.add_theme_constant_override("icon_max_width", 18)
		kb.pressed.connect(func() -> void: build_mode.set_kind(k))
		kinds.add_child(kb)
		_kinds.append(kb)


	# The tiles on the left, the detail card on the right.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	col.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = TILE.y + 8.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_scroll = scroll
	resized.connect(_fit_height)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	body.add_child(_build_detail())

	col.add_child(UiStyle.paper_hints([["LMB", "Choose"], ["1-9", "Quick Pick"],
			[KeyHints.key_for("build_menu"), "Close"], ["RMB", "Leave"]]))
	UiStyle.notifier.changed.connect(func() -> void:
		if _panel.visible:
			refresh())


## The detail card: the picture in a well beside the name and price, the
## numbers as chips, then what it does and where it goes.
func _build_detail() -> Control:
	var card := UiStyle.panel("CardPanel")
	card.custom_minimum_size.x = DETAIL_WIDTH
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Long write-ups scroll inside the card rather than stretch the window.
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var well := UiStyle.panel("IconPanel")
	well.custom_minimum_size = Vector2(84, 84)
	well.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(well)
	_detail_icon = TextureRect.new()
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(_detail_icon)
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.alignment = BoxContainer.ALIGNMENT_CENTER
	name_col.add_theme_constant_override("separation", 6)
	top.add_child(name_col)
	_detail_name = UiStyle.label("", 20)
	_detail_name.add_theme_font_override("font", UiStyle.font("bold"))
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_col.add_child(_detail_name)
	_detail_price = HBoxContainer.new()
	name_col.add_child(_detail_price)
	_detail_status = VBoxContainer.new()
	_detail_status.add_theme_constant_override("separation", 2)
	v.add_child(_detail_status)
	# The stat chart (Logan): the numbers as a ledger, Special Characteristics
	# under, then the write-up.
	_detail_chart = VBoxContainer.new()
	v.add_child(_detail_chart)
	_detail_desc = UiStyle.label("", 15)
	_detail_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(_detail_desc)
	_detail_role = UiStyle.note("", 14)
	v.add_child(_detail_role)
	_detail_where = UiStyle.label("", 14)
	_detail_where.theme_type_variation = "FaintLabel"
	_detail_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(_detail_where)
	return card


## Fits the window between the top HUD and the status card above the hotbar
## (that card grows upward with optional rows, so its live top is read); the
## tile list takes whatever height is left.
func _fit_height() -> void:
	if _panel == null:
		return
	_panel.offset_top = TOP
	var bottom := size.y - BOTTOM_CLEAR
	var card := _status_card()
	if card != null and card.is_visible_in_tree():
		var top_here := (get_global_transform().affine_inverse() * card.get_global_rect().position).y
		bottom = top_here - STATUS_GAP
	_panel.offset_bottom = maxf(bottom, TOP + MIN_HEIGHT)


var _status_hooked := false


## The HUD's bottom-left status card (Hud.status's plate), or null.
func _status_card() -> Control:
	var hud := get_parent()
	var st: Variant = hud.get("status") if hud != null else null
	if not (st is Control) or (st as Control).get_child_count() == 0:
		return null
	var card := (st as Control).get_child(0) as Control
	if card != null and not _status_hooked:
		_status_hooked = true
		card.resized.connect(func() -> void: # a row came or went: keep clear of it
			if _panel.visible:
				_fit_height())
	return card


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
	for c in _stock.get_children():
		_stock.remove_child(c)
		c.queue_free()
	_stock.add_child(UiStyle.stock_chip(&"scrap", Economy.amount(payer, &"scrap"))) # the shared pot
	for c in _tabs.size():
		_style_tab(_tabs[c], c == build_mode.category)
	# The selector: the open tab's count of each kind; a kind with none here is greyed.
	# Cliff Turrets splits into three subsections (Logan): Standard, Crop-Fed and
	# Air Defense, no "All"; the other tabs keep All / Standard / Crop-Fed.
	var cliff_tab := str(Defs.build_tabs()[build_mode.category]["name"]) == "Cliff Turrets"
	if cliff_tab and build_mode.kind == Defs.KIND_ALL:
		build_mode.kind = Defs.KIND_STANDARD
	elif not cliff_tab and build_mode.kind == Defs.KIND_AIR:
		build_mode.kind = Defs.KIND_ALL
	for k in _kinds.size():
		var n := build_mode.category_items_of(build_mode.category, k).size()
		_kinds[k].text = "%s  %d" % [Defs.KIND_NAMES[k], n]
		_kinds[k].visible = (k != Defs.KIND_ALL) if cliff_tab else (k != Defs.KIND_AIR)
		_style_kind(_kinds[k], k == build_mode.kind, n == 0 and k != Defs.KIND_ALL)
	for n in _grid.get_children():
		_grid.remove_child(n)
		n.queue_free()
	var items: Array = build_mode.category_items(build_mode.category)
	if _empty == null:
		_empty = UiStyle.note("", 15)
		_empty.custom_minimum_size = Vector2(TILE.x * 2.0, TILE.y * 0.6)
		_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _empty.get_parent() != null:
		_empty.get_parent().remove_child(_empty)
	if items.is_empty() and build_mode.kind != Defs.KIND_ALL:
		var tab_name := UiStyle.tc(str(Defs.build_tabs()[build_mode.category]["name"]))
		_empty.text = "No %s builds in %s. Pick All, or another tab." % [Defs.KIND_NAMES[build_mode.kind].to_lower(), tab_name]
		_grid.add_child(_empty)
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
	_fit_height()


## The kind selector's look: a pill, lit when it's the one showing.
func _style_kind(b: Button, on: bool, none: bool) -> void:
	var box := KeyHints.kit_box("pill_on" if on else "pill")
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(st, KeyHints.kit_box("pill_on") if st.begins_with("hover") and not on else box)
	var col := UiStyle.c("accent_hi") if on else (UiStyle.c("faint") if none else UiStyle.c("ink_soft"))
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, col if k == "font_color" else UiStyle.c("accent_hi"))
	b.modulate.a = 0.6 if none and not on else 1.0


func _style_tab(b: Button, on: bool) -> void:
	b.theme_type_variation = "TabButtonSelected" if on else "TabButton" # Theme


func _tile(i: int, id: StringName, payer: int) -> Button:
	var cost := Perks.build_cost(multiplayer.get_unique_id(), id) # Perk: build discounts
	var affordable := GameState.is_solo() or Economy.can_afford(payer, {&"scrap": cost})
	var locked := not BuildMode.unlocked(id) # Tiers: Mid / Late before their wave
	var picked := id == build_mode.selected_id()
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = TILE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Theme: tiles are the kit's cards; the picked one is lit in the set's metal.
	var normal: StyleBox = UiStyle.box("card")
	if picked:
		var lit := UiStyle.box_for(UiStyle.current, "card_hover")
		lit.rim = UiStyle.kc("accent_hi")
		lit.rim_width = 2.0
		lit.bar_side = 2
		lit.bar_inset = 0.12
		normal = lit
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal if picked else UiStyle.box("card_hover"))
	b.add_theme_stylebox_override("pressed", UiStyle.box("card_hover"))
	b.add_theme_stylebox_override("hover_pressed", UiStyle.box("card_hover"))
	b.pressed.connect(func() -> void: build_mode.choose(id))
	b.mouse_entered.connect(func() -> void:
		_detail_id = id
		_show_detail(id, payer))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 10
	col.offset_bottom = -8
	col.offset_left = 6
	col.offset_right = -6
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := TextureRect.new()
	icon.texture = icon_for(id)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		icon.modulate = Color(0.35, 0.35, 0.35, 0.55)
	elif not affordable:
		icon.modulate = Color(1, 1, 1, 0.45)
	col.add_child(icon)
	var name_l := UiStyle.label(Defs.name_of(id), 15)
	name_l.add_theme_font_override("font", UiStyle.font("bold"))
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.clip_text = true
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		name_l.theme_type_variation = "FaintLabel"
	col.add_child(name_l)
	# The price (or the lock); one you can't afford gets a cross as well as the red.
	# Crop-fed turrets wear the crop that loads them beside it.
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 5)
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(price_row)
	if Defs.TURRETS.has(id) and Defs.turret(id).is_crop_fed() and not locked:
		price_row.add_child(UiStyle.any_crop_chip() if Defs.turret(id).universal else UiStyle.crop_chip(Defs.turret(id).crop_def()))
	if locked:
		price_row.add_child(UiStyle.mark("lock", UiStyle.c("warn"), 13))
		var wave := UiStyle.label("Wave %d" % Defs.unlock_wave(id), 14, UiStyle.c("warn"))
		wave.autowrap_mode = TextServer.AUTOWRAP_OFF
		price_row.add_child(wave)
	else:
		price_row.add_child(_price(id, cost, payer, affordable, 18))
	# Its quick-pick number in the corner.
	if i < 9:
		var k := KeyHints.chip(str(i + 1))
		k.position = Vector2(7, 7)
		b.add_child(k)
	# Tiers: an Early / Mid / Late tag in the other corner.
	if Defs.TURRETS.has(id):
		var tag := UiStyle.tier_chip(Defs.tier_of(id), locked)
		tag.anchor_left = 1.0
		tag.anchor_right = 1.0
		tag.offset_left = -7.0
		tag.offset_right = -7.0
		tag.offset_top = 7.0
		tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		b.add_child(tag)
	if locked:
		b.tooltip_text = Defs.lock_reason(id, GameState.tier_wave())
	return b


## The price as a figure with the currency's icon ("[chitin] 40"), or how many
## crafted ones you hold.
func _price(id: StringName, cost: int, payer: int, affordable: bool, size: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if CraftTable.is_item_turret(id):
		h.add_child(UiStyle.number(UiStyle.held(Economy.amount(payer, id)), size, UiStyle.c("accent_hi")))
		return h
	if not affordable:
		h.add_child(UiStyle.mark("bad", UiStyle.c("bad"), 12))
	h.add_child(UiStyle.resource_chip(&"scrap", 13))
	h.add_child(UiStyle.number(str(cost), size, UiStyle.c("accent_hi") if affordable else UiStyle.c("bad")))
	return h


func _show_detail(id: StringName, payer: int) -> void:
	for c in _detail_price.get_children():
		_detail_price.remove_child(c)
		c.queue_free()
	for box: Container in [_detail_status, _detail_chart]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	if id == &"":
		_detail_icon.texture = null
		for l: Label in [_detail_name, _detail_desc, _detail_role, _detail_where]:
			l.text = ""
		return
	var cost := Perks.build_cost(multiplayer.get_unique_id(), id) # Perk: build discounts
	var affordable := GameState.is_solo() or Economy.can_afford(payer, {&"scrap": cost})
	_detail_icon.texture = icon_for(id)
	_detail_name.text = Defs.name_of(id)
	var chip := UiStyle.panel("ChipPanel" if affordable or CraftTable.is_item_turret(id) else "ChipBadPanel")
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(_price(id, cost, payer, affordable, 22))
	_detail_price.add_child(chip)
	if CraftTable.is_item_turret(id):
		_detail_status.add_child(UiStyle.status("Crafted at the workshop: place the ones you hold.", "info", 14))
	elif not affordable:
		_detail_status.add_child(UiStyle.status("Can't afford it yet.", "bad", 14))
	if not BuildMode.unlocked(id): # Tiers
		_detail_status.add_child(UiStyle.status(Defs.lock_reason(id, GameState.tier_wave()), "lock", 14))
	_detail_status.visible = _detail_status.get_child_count() > 0
	# The numbers as a stat chart (its job, weakness, ammo and tier are rows in it).
	var chart := StatChart.turret(Defs.turret(id)) if Defs.is_turret(id) else StatChart.structure(Defs.structure(id))
	if not chart.is_empty():
		_detail_chart.add_child(StatChart.build(chart, false))
	_detail_chart.visible = _detail_chart.get_child_count() > 0
	_detail_desc.text = BuildMode._description(id)
	_detail_role.text = ""
	_detail_role.visible = false
	_detail_where.text = _where(id)
	if Defs.TURRETS.has(id):
		var d := Defs.turret(id)
		if d.anti_air:
			_detail_where.text = "Air Defense: shoots fliers first. Sits on top of a 3-high stack on the cliff edge (the scaffold goes up free).  " + _detail_where.text


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

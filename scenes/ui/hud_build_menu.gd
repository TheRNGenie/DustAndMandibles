class_name HudBuildMenu
extends Control
## The build catalog (B): a wooden panel on the left. Category tabs across the
## top, the open category as a grid of tiles (picture, name, price), and a
## detail strip for the item under the mouse: what it does and where it goes.
## Clicking a tile (or pressing its number) picks it for placing.

const WIDTH := 580.0
const COLS := 3
const TILE := Vector2(168, 150)
const ICON_SIZE := 84

var build_mode: BuildMode
var _panel: PanelContainer
var _tabs: Array[Button] = []
var _grid: GridContainer
var _scrap: Label
var _detail_name: Label
var _detail_cost: Label
var _detail_desc: Label
var _detail_where: Label
var _detail_id: StringName = &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	var sb := UiStyle.wood_sign()
	sb.bg_color = Color(Palette.WOOD_DARK, 0.95)
	sb.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", sb)
	# Sized to its content (three rows of tiles), clear of the resources panel.
	_panel.offset_left = 24
	_panel.offset_right = 24 + WIDTH
	_panel.offset_top = 100
	_panel.visible = false
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	# Header: title and how much scrap you have.
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := KeyHints.text("BUILD", 28, Palette.GLOW_YELLOW)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_scrap = KeyHints.text("", 18, Palette.BONE)
	_scrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_scrap)

	# Category tabs.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	col.add_child(tabs)
	for c in Defs.BUILD_CATEGORIES.size():
		var b := Button.new()
		b.text = str(Defs.BUILD_CATEGORIES[c]["name"])
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 34
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
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	# Detail strip for the item under the mouse.
	col.add_child(_rule())
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 4)
	detail.custom_minimum_size.y = 118
	col.add_child(detail)
	var dhead := HBoxContainer.new()
	detail.add_child(dhead)
	_detail_name = KeyHints.text("", 20, Palette.BONE)
	_detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dhead.add_child(_detail_name)
	_detail_cost = KeyHints.text("", 17, Palette.GLOW_YELLOW)
	dhead.add_child(_detail_cost)
	_detail_desc = KeyHints.text("", 14, Palette.BONE.darkened(0.12))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.custom_minimum_size.x = WIDTH - 40
	detail.add_child(_detail_desc)
	_detail_where = KeyHints.text("", 13, Palette.ROCK_C.lightened(0.3))
	detail.add_child(_detail_where)

	col.add_child(KeyHints.row([["LMB", "Choose"], ["1-9", "Quick pick"],
			[KeyHints.key_for("build_menu"), "Close"], ["RMB", "Leave"]]))


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(Palette.OUTLINE, 0.6)
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
	_scrap.text = "%d scrap" % Economy.amount(payer, &"scrap")
	for c in _tabs.size():
		_style_tab(_tabs[c], c == build_mode.category)
	for n in _grid.get_children():
		_grid.remove_child(n)
		n.queue_free()
	var items: Array = build_mode.category_items(build_mode.category)
	for i in items.size():
		_grid.add_child(_tile(i, items[i], payer))
	if not items.has(_detail_id):
		_detail_id = build_mode.selected_id() if items.has(build_mode.selected_id()) else (items[0] if not items.is_empty() else &"")
	_show_detail(_detail_id, payer)


func _style_tab(b: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.WOOD.lightened(0.12) if on else Color(Palette.WOOD, 0.7)
	sb.border_color = Palette.GLOW_YELLOW if on else Palette.OUTLINE
	sb.set_border_width_all(2)
	sb.border_width_bottom = 4 if on else 2
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(4)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.WOOD.lightened(0.18)
	for s: String in ["normal", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	for s: String in ["hover", "pressed"]:
		b.add_theme_stylebox_override(s, hover)
	b.add_theme_color_override("font_color", Palette.GLOW_YELLOW if on else Palette.BONE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)


func _tile(i: int, id: StringName, payer: int) -> Button:
	var cost := Defs.cost_of(id)
	var affordable := GameState.is_solo() or Economy.can_afford(payer, {&"scrap": cost})
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = TILE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(Palette.WOOD, 0.85)
	normal.border_color = Palette.GLOW_YELLOW if id == build_mode.selected_id() else Palette.OUTLINE
	normal.set_border_width_all(3 if id == build_mode.selected_id() else 2)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.WOOD.lightened(0.18)
	hover.border_color = Palette.BONE
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
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
	if not affordable:
		icon.modulate = Color(1, 1, 1, 0.45)
	col.add_child(icon)
	var name_l := KeyHints.text(Defs.name_of(id), 14, Palette.BONE)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	col.add_child(name_l)
	var price := KeyHints.text("%d scrap" % cost, 14, Palette.GLOW_YELLOW if affordable else Palette.TEAM_WEST.lightened(0.3))
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(price)
	# Its quick-pick number in the corner.
	if i < 9:
		var k := KeyHints.chip(str(i + 1))
		k.position = Vector2(6, 6)
		b.add_child(k)
	return b


func _show_detail(id: StringName, payer: int) -> void:
	if id == &"":
		for l: Label in [_detail_name, _detail_cost, _detail_desc, _detail_where]:
			l.text = ""
		return
	var cost := Defs.cost_of(id)
	var affordable := GameState.is_solo() or Economy.can_afford(payer, {&"scrap": cost})
	_detail_name.text = Defs.name_of(id)
	_detail_cost.text = "%d scrap" % cost
	_detail_cost.add_theme_color_override("font_color", Palette.GLOW_YELLOW if affordable else Palette.TEAM_WEST.lightened(0.3))
	_detail_desc.text = BuildMode._description(id)
	# Turrets (Helper 3): their one job, weakness and any upkeep on a second line.
	if Defs.is_turret(id) and Defs.turret(id).role_line() != "":
		_detail_desc.text += "\n" + Defs.turret(id).role_line()
	_detail_where.text = _where(id)


static func _where(id: StringName) -> String:
	if Defs.is_house_turret(id):
		return "Goes on the house: porch, balcony or roof deck"
	if Defs.is_turret(id):
		if Defs.gets_scaffold(id):
			return "Goes anywhere on your plateau, on a free scaffold"
		return "Goes anywhere on your plateau"
	return "Goes anywhere on your plateau"


## A small picture of the item, rendered once from its real 3D model.
func icon_for(id: StringName) -> Texture2D:
	var color := Palette.team_color(build_mode.player.cliff_id) if build_mode != null else Color.WHITE
	if Defs.is_turret(id):
		return IconStudio.turret(self, id, color)
	return IconStudio.structure(self, id)

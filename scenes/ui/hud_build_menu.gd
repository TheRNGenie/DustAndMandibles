class_name HudBuildMenu
extends Control
## The build menu (B): a wooden panel on the left with four category tabs
## (Farming, Cliff Turrets, Tactical, Last Resorts). The open category lists its
## items with a rendered icon, name, price and a one-line description. Clicking an
## item (or pressing its number) picks it and tucks the menu away for placing.

const WIDTH := 400.0
const ICON_SIZE := 64

var build_mode: BuildMode
var _panel: PanelContainer
var _tabs: Array[Button] = []
var _list: VBoxContainer
var _title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	var sb := UiStyle.wood_sign()
	sb.bg_color = Color(Palette.WOOD_DARK, 0.94)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 20
	_panel.offset_right = 20 + WIDTH
	_panel.offset_top = 110
	_panel.offset_bottom = -150
	_panel.visible = false
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	_title = UiStyle.label("BUILD", 26, Palette.GLOW_YELLOW)
	_title.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_title.add_theme_constant_override("outline_size", 6)
	col.add_child(_title)
	var tabs := GridContainer.new()
	tabs.columns = 2
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	col.add_child(tabs)
	for c in Defs.BUILD_CATEGORIES.size():
		var b := UiStyle.button("%d  %s" % [c + 1, Defs.BUILD_CATEGORIES[c]["name"]])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: build_mode.show_category(c))
		tabs.add_child(b)
		_tabs.append(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var hint := UiStyle.label("Click an item or press its number.  B: close   Right click: leave", 12, Palette.BONE)
	col.add_child(hint)


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
	for c in _tabs.size():
		var sb := UiStyle.wood_sign()
		sb.set_content_margin_all(6)
		if c == build_mode.category:
			sb.bg_color = Palette.WOOD.lightened(0.18)
			sb.border_color = Palette.GLOW_YELLOW
		_tabs[c].add_theme_stylebox_override("normal", sb)
	for n in _list.get_children():
		n.queue_free()
	var items: Array = build_mode.category_items(build_mode.category)
	var payer := build_mode.player.cliff_id
	for i in items.size():
		_list.add_child(_item_row(i, items[i], payer))


func _item_row(i: int, id: StringName, payer: int) -> Control:
	var cost := Defs.cost_of(id)
	var affordable := GameState.is_solo() or Economy.can_afford(payer, {&"scrap": cost})
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, ICON_SIZE + 12)
	var normal := UiStyle.wood_sign()
	normal.set_content_margin_all(6)
	if id == build_mode.selected_id():
		normal.border_color = Palette.GLOW_YELLOW
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.WOOD.lightened(0.15)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(func() -> void: build_mode.choose(id))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := TextureRect.new()
	icon.texture = icon_for(id)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name_l := UiStyle.label("%d  %s" % [i + 1, Defs.name_of(id)], 17, Palette.BONE)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(name_l)
	var desc := UiStyle.label(BuildMode._description(id), 11, Palette.BONE.darkened(0.2))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.max_lines_visible = 2
	desc.custom_minimum_size.x = 200
	text.add_child(desc)
	var price := UiStyle.label("%d scrap" % cost, 16, Palette.GLOW_YELLOW if affordable else Palette.TEAM_WEST)
	price.autowrap_mode = TextServer.AUTOWRAP_OFF
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price)
	for l: Label in [name_l, desc, price]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		l.add_theme_constant_override("outline_size", 3)
	if not affordable:
		icon.modulate = Color(1, 1, 1, 0.5)
	return b


## A small picture of the item, rendered once from its real 3D model.
func icon_for(id: StringName) -> Texture2D:
	var color := Palette.team_color(build_mode.player.cliff_id) if build_mode != null else Color.WHITE
	if Defs.is_turret(id):
		return IconStudio.turret(self, id, color)
	return IconStudio.structure(self, id)

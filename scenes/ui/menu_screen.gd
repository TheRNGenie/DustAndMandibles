class_name MenuScreen
extends CanvasLayer
## The one menu screen every shop, upgrade desk and casino game opens: a wooden
## frame around a parchment card, a plank header with the title and your
## stockpile, optional tabs, and either a list of rows (icon, name, description,
## price, buttons) or a custom body (the casino games draw cards and reels).
##
## Anything can open it with MenuScreen.instance.open(provider). The provider
## answers (all optional except menu_title):
##   menu_title() -> String            menu_tagline() -> String
##   menu_tabs() -> Array[String]      menu_items(tab) -> Array[Dictionary]
##   menu_press(id, action)            menu_build_body(parent: Control, screen)
##   signal menu_changed (or ui_changed) to redraw.
## Item dictionaries: {id, name, desc, icon (StringName for ItemIcon or Texture2D),
##   price (String), price_ok (bool), note (String), disabled (String reason),
##   buttons ([[action, label], ...]; the first is also the row click)}.

static var instance: MenuScreen

const WIDTH := 860.0
const HEIGHT := 620.0
const INK := Color("#3A2416")
const PARCHMENT := Color("#F2E3C2")
const PARCHMENT_DARK := Color("#E2CC9F")
const GOLD := Color("#FFD23F")

var provider: Object
var tab := 0
var _root: Control
var _title: Label
var _tagline: Label
var _money: Label
var _tabs: HBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _dirty := false


func _ready() -> void:
	instance = self
	layer = 45
	_build()
	_root.visible = false
	Economy.resources_changed.connect(func(_c: int) -> void: _mark_dirty())


func is_open() -> bool:
	return _root.visible


func open(p: Object) -> void:
	if provider != null and provider != p:
		_disconnect()
	provider = p
	tab = 0
	for sig: String in ["menu_changed", "ui_changed"]:
		if provider.has_signal(sig) and not provider.is_connected(sig, _mark_dirty):
			provider.connect(sig, _mark_dirty)
	_root.visible = true
	GameState.menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()


func close() -> void:
	if not _root.visible:
		return
	_disconnect()
	provider = null
	_root.visible = false
	GameState.menu_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _disconnect() -> void:
	if provider == null or not is_instance_valid(provider):
		return
	for sig: String in ["menu_changed", "ui_changed"]:
		if provider.has_signal(sig) and provider.is_connected(sig, _mark_dirty):
			provider.disconnect(sig, _mark_dirty)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible and not GameState.menu_open and event.is_action_pressed("field_guide"):
		FieldGuide.open()
		get_viewport().set_input_as_handled()


func _mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if not _root.visible:
		return
	if provider == null or not is_instance_valid(provider):
		close()
		return
	if _dirty:
		_dirty = false
		refresh()


func refresh() -> void:
	if provider == null:
		return
	_title.text = str(provider.call("menu_title")).to_upper()
	_tagline.text = str(provider.call("menu_tagline")) if provider.has_method("menu_tagline") else ""
	_tagline.visible = _tagline.text != ""
	_money.text = _money_text()
	for c in _tabs.get_children():
		c.queue_free()
	var tabs: Array = provider.call("menu_tabs") if provider.has_method("menu_tabs") else []
	_tabs.visible = not tabs.is_empty()
	for i in tabs.size():
		var b := tab_button(str(tabs[i]), i == tab)
		var index := i
		b.pressed.connect(func() -> void:
			tab = index
			refresh())
		_tabs.add_child(b)
	var keep_scroll := _scroll.scroll_vertical
	for c in _body.get_children():
		c.queue_free()
	if provider.has_method("menu_build_body"):
		provider.call("menu_build_body", _body, self)
	else:
		var items: Array = provider.call("menu_items", tab) if provider.has_method("menu_items") else []
		for item: Dictionary in items:
			_body.add_child(_row(item))
		if items.is_empty():
			_body.add_child(ink_label("Nothing here right now.", 16))
	_scroll.set_deferred("scroll_vertical", keep_scroll)


func _money_text() -> String:
	var player := _local_player()
	if player == null:
		return ""
	var cid := player.cliff_id
	return "SCRAP %d     CHITIN %d" % [Economy.amount(cid, &"scrap"), Economy.amount(cid, &"chitin")]


func _local_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority():
			return n as Player
	return null


# ------------------------------------------------------------------ layout

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.06, 0.03, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _frame_style())
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -WIDTH * 0.5
	frame.offset_right = WIDTH * 0.5
	frame.offset_top = -HEIGHT * 0.5
	frame.offset_bottom = HEIGHT * 0.5
	_root.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	frame.add_child(outer)
	# Plank header.
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _plank_style())
	outer.add_child(header)
	var hrow := HBoxContainer.new()
	header.add_child(hrow)
	var htext := VBoxContainer.new()
	htext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	htext.add_theme_constant_override("separation", 0)
	hrow.add_child(htext)
	_title = _outlined("", 32, GOLD)
	htext.add_child(_title)
	_tagline = _outlined("", 14, PARCHMENT)
	_tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	htext.add_child(_tagline)
	_money = _outlined("", 18, PARCHMENT)
	_money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(_money)
	# Parchment card.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _parchment_style())
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	card.add_child(inner)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	inner.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)
	var footer := HBoxContainer.new()
	inner.add_child(footer)
	var hint := ink_label("E or Esc: close", 13)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	footer.add_child(hint)
	var close_b := wood_button("Close")
	close_b.pressed.connect(close)
	footer.add_child(close_b)


func _row(item: Dictionary) -> Control:
	var disabled := str(item.get("disabled", ""))
	var buttons: Array = item.get("buttons", [])
	var row := PanelContainer.new()
	var sb := _card_style(false)
	row.add_theme_stylebox_override("panel", sb)
	row.custom_minimum_size.y = 74
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var icon_box := PanelContainer.new()
	icon_box.add_theme_stylebox_override("panel", _icon_style())
	icon_box.custom_minimum_size = Vector2(60, 60)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon_box)
	var ic: Variant = item.get("icon", null)
	if ic is Texture2D:
		var tr := TextureRect.new()
		tr.texture = ic
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_box.add_child(tr)
	elif ic != null:
		var draw := HudHotbar.ItemIcon.new()
		draw.item = StringName(str(ic))
		icon_box.add_child(draw)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	h.add_child(text)
	var name_l := ink_label(str(item.get("name", "")), 19)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(name_l)
	var desc := ink_label(str(item.get("desc", "")), 13, INK.lightened(0.25))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	if disabled != "":
		var why := ink_label(disabled, 12, Color("#9B3B2E"))
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text.add_child(why)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.custom_minimum_size.x = 150
	h.add_child(right)
	if str(item.get("price", "")) != "":
		var tag := price_tag(str(item["price"]), bool(item.get("price_ok", true)))
		right.add_child(tag)
	if str(item.get("note", "")) != "":
		var note := ink_label(str(item["note"]), 13, INK.lightened(0.2))
		right.add_child(note)
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_END
	brow.add_theme_constant_override("separation", 4)
	right.add_child(brow)
	for b: Array in buttons:
		var btn := wood_button(str(b[1]), true)
		btn.disabled = disabled != ""
		var action: StringName = StringName(str(b[0]))
		var id: Variant = item.get("id")
		btn.pressed.connect(func() -> void: provider.call("menu_press", id, action))
		brow.add_child(btn)
	if disabled != "":
		row.modulate = Color(1, 1, 1, 0.65)
	return row


# ------------------------------------------------------------------ shared widgets

static func ink_label(text: String, size: int = 16, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func _outlined(text: String, size: int, color: Color) -> Label:
	var l := ink_label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", 6)
	return l


static func wood_button(text: String, small: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(70 if small else 110, 30 if small else 38)
	b.add_theme_font_size_override("font_size", 14 if small else 17)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.WOOD
	normal.border_color = Palette.OUTLINE
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(6)
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(2, 2)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.WOOD.lightened(0.15)
	hover.border_color = GOLD.darkened(0.3)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Palette.WOOD_DARK
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Palette.WOOD.darkened(0.25)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", PARCHMENT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", PARCHMENT.darkened(0.4))
	return b


## A tab or toggle: lit up in gold when selected.
static func tab_button(text: String, selected: bool) -> Button:
	var b := wood_button(text, true)
	b.custom_minimum_size.x = 96
	if selected:
		var sb := (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.bg_color = Palette.WOOD_DARK
		sb.border_color = GOLD
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_color_override("font_color", GOLD)
	return b


static func price_tag(text: String, ok: bool) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3A2416") if ok else Color("#7A2E22")
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	var l := ink_label(text, 15, GOLD if ok else PARCHMENT)
	p.add_child(l)
	return p


## A row of toggles; calls on_pick(index) when one is pressed.
static func toggle_row(options: Array, selected: int, on_pick: Callable) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	for i in options.size():
		var b := tab_button(str(options[i]), i == selected)
		var index := i
		b.pressed.connect(func() -> void: on_pick.call(index))
		row.add_child(b)
	return row


## A playing card: rank and suit on a white card (0 = face down).
static func card(c: int, suit: int) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = INK
	sb.set_content_margin_all(4)
	p.custom_minimum_size = Vector2(58, 82)
	if c <= 0:
		sb.bg_color = Color("#7A2E22")
		p.add_theme_stylebox_override("panel", sb)
		var back := ink_label("~", 30, GOLD)
		back.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(back)
		return p
	sb.bg_color = Color("#FFFDF5")
	p.add_theme_stylebox_override("panel", sb)
	var red := suit % 4 == 1 or suit % 4 == 2
	var col := Color("#B3261E") if red else INK
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	v.add_child(ink_label(CasinoRules.RANKS[clampi(c, 1, 13) - 1], 26, col))
	var s := SuitIcon.new()
	s.suit = suit % 4
	s.color = col
	s.custom_minimum_size = Vector2(26, 26)
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(s)
	return p


static func _frame_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.WOOD_DARK
	sb.border_color = Palette.OUTLINE
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(6, 8)
	return sb


static func _plank_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.WOOD
	sb.border_color = Palette.OUTLINE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func _parchment_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.border_color = Palette.WOOD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(16)
	return sb


static func _card_style(hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT_DARK.lightened(0.1) if hover else PARCHMENT_DARK
	sb.border_color = Palette.WOOD
	sb.set_border_width_all(2)
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb


static func _icon_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.WOOD_DARK
	sb.border_color = Palette.OUTLINE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	return sb


## Spade, heart, diamond, club drawn with polygons (no font glyphs needed).
class SuitIcon extends Control:
	var suit := 0
	var color := Color.BLACK

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.45
		match suit:
			0: # spade
				draw_circle(c + Vector2(-r * 0.42, r * 0.1), r * 0.45, color)
				draw_circle(c + Vector2(r * 0.42, r * 0.1), r * 0.45, color)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.85, r * 0.15), c + Vector2(-r * 0.85, r * 0.15)]), color)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.2), c + Vector2(r * 0.3, r), c + Vector2(-r * 0.3, r)]), color)
			1: # heart
				draw_circle(c + Vector2(-r * 0.45, -r * 0.25), r * 0.5, color)
				draw_circle(c + Vector2(r * 0.45, -r * 0.25), r * 0.5, color)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.93, -r * 0.05), c + Vector2(r * 0.93, -r * 0.05), c + Vector2(0, r)]), color)
			2: # diamond
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]), color)
			_: # club
				draw_circle(c + Vector2(0, -r * 0.45), r * 0.4, color)
				draw_circle(c + Vector2(-r * 0.45, r * 0.1), r * 0.4, color)
				draw_circle(c + Vector2(r * 0.45, r * 0.1), r * 0.4, color)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(r * 0.3, r), c + Vector2(-r * 0.3, r)]), color)

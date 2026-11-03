class_name LedgerScreen
extends CanvasLayer
## The Rancher's Ledger (main menu and lobby): spend Brands on perks in three
## trees, pick the loadout (up to 12) you take into the next run, and buy
## wardrobe items. Same wood-and-parchment look as the shop screen (MenuScreen).
## `--ledger` opens it on start (with `--debug --menu`), `--ledgertab=1` the wardrobe.

static var INK := MenuScreen.INK # Theme: follows the set
static var GOLD := MenuScreen.GOLD
static var PARCHMENT := MenuScreen.PARCHMENT
const RED := Color("#9B3B2E")
const GREEN := Color("#3F6B2A")
const TREE_GLYPHS: Dictionary = {&"gun": "item:revolver", &"home": "house", &"eng": "gear"}

var tab := 0
var _root: Control
var _brands: Label
var _loadout: Label
var _pips: LoadoutPips
var _stats: Label
var _tabs: HBoxContainer
var _body: Control
var _clear: Button
var _hint: Label
var _scrolls: Dictionary = {}
var _dirty := false


func _ready() -> void:
	layer = 60
	_build()
	_root.visible = false
	Perks.profile_changed.connect(func() -> void: _dirty = true)
	if GameState.has_flag("--ledger"):
		tab = clampi(int(GameState.flag_value("--ledgertab")), 0, 1)
		open.call_deferred()


func open() -> void:
	_root.visible = true
	refresh()


func close() -> void:
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func _input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _dirty and _root.visible:
		_dirty = false
		refresh()


# ------------------------------------------------------------------ layout

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.fit(_root) # Theme: bigger on 1440p and up
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.06, 0.03, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", MenuScreen._frame_style())
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 36
	frame.offset_right = -36
	frame.offset_top = 22
	frame.offset_bottom = -22
	_root.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	frame.add_child(outer)

	# Plank header: title, then Brands and the loadout counter.
	var header := PanelContainer.new()
	header.theme_type_variation = "HeaderPanel" # Theme
	outer.add_child(header)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 18)
	header.add_child(hrow)
	var htext := VBoxContainer.new()
	htext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	htext.add_theme_constant_override("separation", 0)
	hrow.add_child(htext)
	var title := UiStyle.title("Rancher's Ledger", 34, true) # Theme: display title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	htext.add_child(title)
	var tag := MenuScreen._outlined("Earn Notches every run. Spend them on perks, then pick up to %d to ride out with." % PerkTable.MAX_LOADOUT, 14, PARCHMENT)
	htext.add_child(tag)
	hrow.add_child(_chip_brands())
	hrow.add_child(_chip_loadout())

	# Parchment card: tabs, body, footer.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MenuScreen._parchment_style())
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	card.add_child(inner)
	var trow := HBoxContainer.new()
	inner.add_child(trow)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(_tabs)
	_stats = MenuScreen.ink_label("", 13, INK.lightened(0.3))
	_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(_stats)
	_body = MarginContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(_body)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	inner.add_child(footer)
	var hint := MenuScreen.ink_label("", 13, INK.lightened(0.25))
	_hint = hint
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	footer.add_child(hint)
	_clear = MenuScreen.wood_button("Clear loadout")
	_clear.custom_minimum_size.x = 140
	_clear.pressed.connect(func() -> void: Perks.clear_loadout())
	footer.add_child(_clear)
	var done := MenuScreen.wood_button("Done")
	done.pressed.connect(close)
	footer.add_child(done)


func _chip(min_w: float) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.WOOD_DARK
	sb.border_color = Palette.OUTLINE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.x = min_w
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _chip_brands() -> Control:
	var p := _chip(170)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var g := PerkGlyph.new("brand", GOLD)
	g.custom_minimum_size = Vector2(34, 34)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(g)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	row.add_child(col)
	_brands = MenuScreen._outlined("0", 26, GOLD)
	col.add_child(_brands)
	col.add_child(MenuScreen._outlined("NOTCHES", 12, PARCHMENT))
	return p


func _chip_loadout() -> Control:
	var p := _chip(230)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	p.add_child(col)
	_loadout = MenuScreen._outlined("", 20, PARCHMENT)
	col.add_child(_loadout)
	_pips = LoadoutPips.new()
	_pips.custom_minimum_size = Vector2(200, 12)
	col.add_child(_pips)
	return p


# ------------------------------------------------------------------ content

func refresh() -> void:
	var prof := Perks.profile
	_brands.text = str(prof.brands)
	var n := prof.loadout.size()
	_loadout.text = "LOADOUT  %d / %d" % [n, PerkTable.MAX_LOADOUT]
	_loadout.add_theme_color_override("font_color", GOLD if n >= PerkTable.MAX_LOADOUT else PARCHMENT)
	_pips.filled = n
	_pips.queue_redraw()
	_stats.text = "%d runs  -  %d won  -  best wave %d  -  %d Notches earned in all" % [prof.runs, prof.wins, prof.best_wave, prof.lifetime_brands]
	_clear.visible = tab == 0
	_hint.text = ("Unlock with Notches, then Add a perk to your loadout. Ranked perks get stronger each rank." if tab == 0
		else "Bought looks stay yours for good.") + "   Esc: close"
	_clear.disabled = n == 0 or not Perks.loadout_editable()
	for c in _tabs.get_children():
		c.queue_free()
	for i in 2:
		var b := MenuScreen.tab_button(["Perks", "Wardrobe"][i], i == tab)
		b.custom_minimum_size.x = 120
		var index := i
		b.pressed.connect(func() -> void:
			tab = index
			refresh())
		_tabs.add_child(b)
	for key: Variant in _scrolls:
		var sc := _scrolls[key] as ScrollContainer
		if is_instance_valid(sc):
			_scrolls[key] = sc.scroll_vertical
	var keep := _scrolls.duplicate()
	_scrolls.clear()
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if tab == 0:
		_build_trees(keep)
	else:
		_build_wardrobe(keep)


func _build_trees(keep: Dictionary) -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	_body.add_child(cols)
	for tree: StringName in PerkTable.TREES:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		cols.add_child(col)
		col.add_child(_tree_header(tree))
		var scroll := _scroll(tree, keep)
		col.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 6)
		scroll.add_child(list)
		for p: Dictionary in PerkTable.in_tree(tree):
			list.add_child(_perk_card(p))


func _scroll(key: Variant, keep: Dictionary) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scrolls[key] = scroll
	if keep.has(key):
		scroll.set_deferred("scroll_vertical", int(keep[key]))
	return scroll


func _tree_header(tree: StringName) -> Control:
	var p := PanelContainer.new()
	var sb := MenuScreen._plank_style()
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.content_margin_left = 10
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var g := PerkGlyph.new(TREE_GLYPHS[tree], GOLD)
	g.custom_minimum_size = Vector2(38, 38)
	row.add_child(g)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var tree_title := UiStyle.title(str(PerkTable.TREE_NAMES[tree]), 21, true) # Theme
	tree_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(tree_title)
	text.add_child(MenuScreen._outlined(str(PerkTable.TREE_BLURBS[tree]), 12, PARCHMENT))
	var owned := 0
	var taken := 0
	var all := PerkTable.in_tree(tree)
	for perk: Dictionary in all:
		if Perks.profile.is_unlocked(perk["id"]):
			owned += 1
		if Perks.profile.in_loadout(perk["id"]):
			taken += 1
	var count := MenuScreen._outlined("%d/%d unlocked\n%d in loadout" % [owned, all.size(), taken], 12, PARCHMENT)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	return p


func _perk_card(p: Dictionary) -> Control:
	var prof := Perks.profile
	var id: StringName = p["id"]
	var r := prof.rank(id)
	var top := PerkTable.max_rank(id)
	var taken := prof.in_loadout(id)
	var card := PanelContainer.new()
	var sb := MenuScreen._card_style(taken) # Theme: taken perks sit on the lighter card
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size.y = 92
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	# Emblem.
	var icon_box := PanelContainer.new()
	var isb := MenuScreen._icon_style()
	if taken:
		isb.modulate_color = Color(1.2, 1.12, 0.9) # Theme: a warmer emblem when it's in the loadout
	icon_box.add_theme_stylebox_override("panel", isb)
	icon_box.custom_minimum_size = Vector2(56, 56)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon_box)
	var g := PerkGlyph.new(str(p["glyph"]), GOLD if taken else (PARCHMENT if r > 0 else PARCHMENT.darkened(0.45)))
	icon_box.add_child(g)
	if r == 0:
		icon_box.modulate = Color(1, 1, 1, 0.75)
	# Name, rank pips, what it does.
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 1)
	h.add_child(text)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	text.add_child(name_row)
	var name_l := MenuScreen.ink_label(str(p["name"]), 17, INK if r > 0 else INK.lightened(0.3))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_row.add_child(name_l)
	var pips := RankPips.new()
	pips.rank = r
	pips.max_rank = top
	pips.custom_minimum_size = Vector2(16 * top, 16)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(pips)
	var desc := MenuScreen.ink_label(PerkTable.describe(id, r), 13, INK.lightened(0.15))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 150
	text.add_child(desc)
	var status := ""
	var status_color := INK.lightened(0.35)
	if r > 0 and r < top and PerkTable.value_text(id, r + 1) != "":
		status = "Next rank: %s" % PerkTable.value_text(id, r + 1)
	elif r == 0:
		status = "Locked" + ("  -  up to %s at rank %d" % [PerkTable.value_text(id, top), top] if top > 1 and PerkTable.value_text(id, top) != "" else "")
	elif r >= top and top > 1:
		status = "Fully ranked"
		status_color = GREEN
	if status != "":
		var s := MenuScreen.ink_label(status, 12, status_color)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text.add_child(s)
	# Price and buttons.
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 4)
	right.custom_minimum_size.x = 112
	h.add_child(right)
	var cost := prof.next_cost(id)
	if cost >= 0:
		var afford := prof.brands >= cost
		var buy := MenuScreen.wood_button("%s  %d" % ["Unlock" if r == 0 else "Rank up", cost], true)
		buy.custom_minimum_size = Vector2(112, 30)
		buy.disabled = not afford
		buy.tooltip_text = "%d Notches" % cost + ("" if afford else " (you have %d)" % prof.brands)
		buy.pressed.connect(func() -> void:
			if Perks.unlock(id) and Audio.has_sound(&"coin"):
				Audio.play_ui(&"coin", -4.0))
		right.add_child(buy)
	if r > 0:
		var why := prof.add_block(id)
		var t := MenuScreen.tab_button("In loadout" if taken else "Add", taken)
		t.custom_minimum_size = Vector2(112, 30)
		t.disabled = (why != "" and not taken) or not Perks.loadout_editable()
		t.tooltip_text = why if why != "" else ("Leave it at home" if taken else "Take it into the next run")
		t.pressed.connect(func() -> void: Perks.toggle(id))
		right.add_child(t)
	return card


func _build_wardrobe(keep: Dictionary) -> void:
	var scroll := _scroll(&"wardrobe", keep)
	_body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var intro := MenuScreen.ink_label("Buy looks with Notches here; wear them from the Wardrobe (pause menu or the wardrobe in your house).", 14, INK.lightened(0.2))
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(intro)
	for slot: String in PerkTable.COSMETICS:
		var title := MenuScreen.ink_label(str(DummyLook.SLOTS[slot][0]), 17)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(title)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		list.add_child(flow)
		for opt: Array in DummyLook.SLOTS[slot][1]:
			var price := PerkTable.cosmetic_price(slot, str(opt[0]))
			if price > 0:
				flow.add_child(_look_card(slot, str(opt[0]), str(opt[1]), price))


func _look_card(slot: String, option: String, label: String, price: int) -> Control:
	var owned := Perks.owns_look(slot, option)
	var worn := str(Settings.look.get(slot, "")) == option
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MenuScreen._card_style(false))
	card.custom_minimum_size = Vector2(270, 64)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(text)
	var n := MenuScreen.ink_label(label, 16)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(n)
	var s := MenuScreen.ink_label(("Wearing it" if worn else "Owned") if owned else "%d Notches" % price, 12, GREEN if owned else INK.lightened(0.3))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(s)
	if owned:
		var wear := MenuScreen.tab_button("Worn" if worn else "Wear", worn)
		wear.custom_minimum_size = Vector2(84, 30)
		wear.disabled = worn
		wear.pressed.connect(func() -> void:
			Settings.set_look(slot, option)
			refresh())
		wear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(wear)
	else:
		var buy := MenuScreen.wood_button("Buy  %d" % price, true)
		buy.custom_minimum_size = Vector2(84, 30)
		buy.disabled = Perks.profile.brands < price
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.pressed.connect(func() -> void:
			if Perks.buy_cosmetic(slot, option) and Audio.has_sound(&"register"):
				Audio.play_ui(&"register", -4.0))
		h.add_child(buy)
	return card


## Filled and empty diamonds for a perk's ranks.
class RankPips extends Control:
	var rank := 0
	var max_rank := 1

	func _draw() -> void:
		for i in max_rank:
			var c := Vector2(8 + i * 16, size.y * 0.5)
			var r := 5.5
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
			if i < rank:
				draw_colored_polygon(pts, MenuScreen.GOLD.darkened(0.15))
			pts.append(pts[0])
			draw_polyline(pts, MenuScreen.INK, 1.5)


## Twelve slots in the header: how full the loadout is.
class LoadoutPips extends Control:
	var filled := 0

	func _draw() -> void:
		var n := PerkTable.MAX_LOADOUT
		var w := size.x / n
		for i in n:
			var r := Rect2(Vector2(i * w + 1.5, 0), Vector2(w - 3.0, size.y))
			draw_rect(r, MenuScreen.GOLD if i < filled else Palette.WOOD.darkened(0.3))
			draw_rect(r, Palette.OUTLINE, false, 1.5)

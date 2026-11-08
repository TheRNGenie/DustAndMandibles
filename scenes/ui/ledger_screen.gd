class_name LedgerScreen
extends CanvasLayer
## The Rancher's Ledger (main menu and lobby): spend Brands on perks in three
## trees, pick the loadout (up to 12) you take into the next run, and buy
## wardrobe items. Same wood-and-parchment look as the shop screen (MenuScreen).
## `--ledger` opens it on start (with `--debug --menu`), `--ledgertab=1` the wardrobe.

static var INK := MenuScreen.INK # Theme: follows the set
static var GOLD := MenuScreen.GOLD
static var PARCHMENT := MenuScreen.PARCHMENT
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
	var was_open := UiStyle.shown(_root)
	_root.visible = true
	refresh()
	if not was_open:
		UiStyle.fade_in(_root)


func close() -> void:
	UiStyle.fade_out(_root)


func is_open() -> bool:
	return UiStyle.shown(_root)


func _input(event: InputEvent) -> void:
	if not UiStyle.shown(_root):
		return
	if event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()
	elif _nav(event):
		get_viewport().set_input_as_handled()


## Keyboard and controller, like the shops: arrows / d-pad move between perk rows,
## buttons and tabs (the first press lands on the first row), PageUp/PageDown or
## the shoulder buttons switch tabs.
func _nav(event: InputEvent) -> bool:
	var step := UiStyle.page_step(event)
	if step != 0:
		tab = wrapi(tab + step, 0, 2)
		refresh()
		_focus_first.call_deferred()
		return true
	if UiStyle.nav_pressed(event):
		var f := get_viewport().gui_get_focus_owner()
		if f == null or not _root.is_ancestor_of(f):
			_focus_first()
			return true
	return false


## The first live button in the body, else the selected tab.
func _focus_first() -> void:
	if not UiStyle.focus_first(_body):
		var tabs := UiStyle.focusables(_tabs)
		if tab < tabs.size():
			tabs[tab].grab_focus()


func _process(_delta: float) -> void:
	if _dirty and UiStyle.shown(_root):
		_dirty = false
		refresh()


# ------------------------------------------------------------------ layout

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.fit(_root) # Theme: bigger on 1440p and up
	add_child(_root)
	_root.add_child(UiStyle.scrim())
	var frame := UiStyle.panel("FramePanel")
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
	var header := UiStyle.strap("Rancher's Ledger",
			"Earn Notches every run. Spend them on perks, then pick up to %d to ride out with." % PerkTable.MAX_LOADOUT, 30)
	outer.add_child(header)
	var hrow := UiStyle.strap_row(header)
	hrow.add_child(_chip_brands())
	hrow.add_child(_chip_loadout())

	# Parchment card: tabs, body, footer.
	var card := UiStyle.panel("PaperPanel")
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", UiStyle.GAP_GROUP)
	card.add_child(inner)
	var trow := HBoxContainer.new()
	inner.add_child(trow)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(_tabs)
	_stats = MenuScreen.ink_label("", 14, UiStyle.c("ink_soft"))
	_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(_stats)
	_body = MarginContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(_body)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	inner.add_child(footer)
	var hint := MenuScreen.ink_label("", 14, UiStyle.c("ink_soft"))
	_hint = hint
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(hint)
	var keys := UiStyle.paper_hints([["Esc", "Close"], ["Arrows", "Move"], ["PgUp/PgDn", "Switch Tab"]])
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(keys)
	_clear = MenuScreen.wood_button("Clear Loadout")
	_clear.custom_minimum_size.x = 140
	_clear.pressed.connect(func() -> void: Perks.clear_loadout())
	footer.add_child(_clear)
	var done := MenuScreen.wood_button("Done")
	done.theme_type_variation = "PrimaryButton"
	done.pressed.connect(close)
	footer.add_child(done)


func _chip(min_w: float) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiStyle.chip_flat() # Theme: the same dark chip as the shop's stock
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
	_brands = MenuScreen._outlined("0", 22, GOLD)
	col.add_child(_brands)
	col.add_child(MenuScreen._outlined("Notches", 12, PARCHMENT))
	return p


func _chip_loadout() -> Control:
	var p := _chip(230)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	p.add_child(col)
	_loadout = MenuScreen._outlined("", 18, PARCHMENT)
	col.add_child(_loadout)
	_pips = LoadoutPips.new()
	_pips.custom_minimum_size = Vector2(200, 12)
	col.add_child(_pips)
	return p


# ------------------------------------------------------------------ content

func refresh() -> void:
	# Keyboard focus survives the rebuild: same area, same place in the list.
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_area: Control = null
	var focus_at := -1
	for area: Control in [_tabs, _body]:
		if f != null and area.is_ancestor_of(f):
			focus_area = area
			focus_at = UiStyle.focusables(area).find(f)
	var prof := Perks.profile
	_brands.text = str(prof.brands)
	var n := prof.loadout.size()
	_loadout.text = "Loadout  %d / %d" % [n, PerkTable.MAX_LOADOUT]
	_loadout.add_theme_color_override("font_color", GOLD if n >= PerkTable.MAX_LOADOUT else PARCHMENT)
	_pips.filled = n
	_pips.queue_redraw()
	_stats.text = "%d Runs  ·  %d Won  ·  Best Wave %d  ·  %d Notches Earned" % [prof.runs, prof.wins, prof.best_wave, prof.lifetime_brands]
	_clear.visible = tab == 0
	_hint.text = ("Unlock with Notches, then Add a perk to your loadout. Ranked perks get stronger each rank." if tab == 0
		else "Bought looks stay yours for good.")
	_clear.disabled = n == 0 or not Perks.loadout_editable()
	for c in _tabs.get_children():
		_tabs.remove_child(c)
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
	if focus_area != null:
		var list := UiStyle.focusables(focus_area)
		if not list.is_empty():
			list[clampi(focus_at, 0, list.size() - 1)].grab_focus()
		elif focus_area == _body:
			_focus_first()


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
	scroll.follow_focus = true # arrows keep the focused row in view
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
	var blurb := UiStyle.strap_text(str(PerkTable.TREE_BLURBS[tree]), 13)
	blurb.theme_type_variation = "SoftInkLabel"
	text.add_child(blurb)
	var owned := 0
	var taken := 0
	var all := PerkTable.in_tree(tree)
	for perk: Dictionary in all:
		if Perks.profile.is_unlocked(perk["id"]):
			owned += 1
		if Perks.profile.in_loadout(perk["id"]):
			taken += 1
	var count := MenuScreen._outlined("%d / %d Unlocked\n%d in Loadout" % [owned, all.size(), taken], 12, PARCHMENT)
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
	card.theme_type_variation = "CardHoverPanel" if taken else "CardPanel" # Theme: taken perks sit on the lighter card
	card.custom_minimum_size.y = 92
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	# Emblem.
	var icon_box := UiStyle.panel("IconPanel")
	if taken: # Theme: the well rimmed in the set's metal when it's in the loadout
		var isb := UiStyle.box_for(UiStyle.current, "icon")
		isb.rim = UiStyle.kc("accent_hi")
		isb.rim_width = 1.5
		isb.glow = Color(UiStyle.kc("accent"), 0.25)
		isb.glow_size = 4.0
		icon_box.add_theme_stylebox_override("panel", isb)
	icon_box.custom_minimum_size = Vector2(60, 60)
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
	var name_l := MenuScreen.ink_label(UiStyle.tc(str(p["name"])), 18, UiStyle.c("ink") if r > 0 else UiStyle.c("ink_soft"))
	name_l.add_theme_font_override("font", UiStyle.font("bold"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_row.add_child(name_l)
	var pips := RankPips.new()
	pips.rank = r
	pips.max_rank = top
	pips.custom_minimum_size = Vector2(16 * top, 16)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(pips)
	var desc := MenuScreen.ink_label(PerkTable.describe(id, r), 14, UiStyle.c("ink_soft"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 150
	text.add_child(desc)
	var status := ""
	var kind := "info"
	if r > 0 and r < top and PerkTable.value_text(id, r + 1) != "":
		status = "Next Rank: %s" % PerkTable.value_text(id, r + 1)
	elif r == 0:
		status = "Locked" + ("  ·  Up to %s at Rank %d" % [PerkTable.value_text(id, top), top] if top > 1 and PerkTable.value_text(id, top) != "" else "")
		kind = "lock"
	elif r >= top and top > 1:
		status = "Fully Ranked"
		kind = "good"
	if status != "":
		text.add_child(UiStyle.status(status, kind, 13))
	# Price and buttons.
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 4)
	right.custom_minimum_size.x = 124
	h.add_child(right)
	var cost := prof.next_cost(id)
	if cost >= 0:
		var afford := prof.brands >= cost
		var buy := MenuScreen.wood_button("%s  %d" % ["Unlock" if r == 0 else "Rank Up", cost], true)
		buy.custom_minimum_size = Vector2(124, 32)
		buy.disabled = not afford
		buy.tooltip_text = "%d Notches" % cost + ("" if afford else " (you have %d)" % prof.brands)
		buy.pressed.connect(func() -> void:
			if Perks.unlock(id) and Audio.has_sound(&"coin"):
				Audio.play_ui(&"coin", -4.0))
		right.add_child(buy)
	if r > 0:
		var why := prof.add_block(id)
		var t := MenuScreen.tab_button("In Loadout" if taken else "Add", taken)
		t.custom_minimum_size = Vector2(124, 32)
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
	var intro := MenuScreen.ink_label("Buy looks with Notches here; wear them from the Wardrobe (pause menu or the wardrobe in your house).", 14, UiStyle.c("ink_soft"))
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(intro)
	for slot: String in PerkTable.COSMETICS:
		list.add_child(UiStyle.section(str(DummyLook.SLOTS[slot][0])))
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
	var card := UiStyle.panel("CardPanel")
	card.custom_minimum_size = Vector2(270, 64)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(text)
	var n := MenuScreen.ink_label(UiStyle.tc(label), 16)
	n.add_theme_font_override("font", UiStyle.font("bold"))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(n)
	if owned:
		text.add_child(UiStyle.status("Wearing It" if worn else "Owned", "good", 13))
	else:
		var s := MenuScreen.ink_label(UiStyle.cost(price, "Notches"), 14, UiStyle.c("accent_hi"))
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
				draw_colored_polygon(pts, UiStyle.c("accent_hi"))
			pts.append(pts[0])
			draw_polyline(pts, Color(UiStyle.c("accent"), 0.9), 1.5)


## Twelve slots in the header: how full the loadout is.
class LoadoutPips extends Control:
	var filled := 0

	func _draw() -> void:
		var n := PerkTable.MAX_LOADOUT
		var w := size.x / n
		for i in n:
			var r := Rect2(Vector2(i * w + 1.5, 0), Vector2(w - 3.0, size.y))
			draw_rect(r, UiStyle.c("accent_hi") if i < filled else UiStyle.c("well"))
			draw_rect(r, Color(UiStyle.c("accent"), 0.55), false, 1.0)

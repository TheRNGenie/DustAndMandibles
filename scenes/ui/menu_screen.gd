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
##   menu_stock() -> [[resource, amount], ...]  (header chips; scrap and chitin if absent)
##   menu_size() -> Vector2  (a bigger frame, e.g. the casino tables; fitted to the window)
##   signal menu_changed (or ui_changed) to redraw.
## Item dictionaries: {id, name, desc, icon (StringName for ItemIcon or Texture2D),
##   price (String), price_ok (bool), note (String), disabled (String reason),
##   buttons ([[action, label], ...]; the first is also the row click),
##   chart (StatChart data: a list with any charts gets a stat chart column on
##   the right, showing the row under the mouse or keyboard focus)}.

static var instance: MenuScreen

const WIDTH := 940.0
const HEIGHT := 700.0
# Theme: these follow the UI theme set (UiStyle.apply keeps them current).
static var INK := Color("#3A2416")
static var PARCHMENT := Color("#F2E3C2")
static var PARCHMENT_DARK := Color("#E2CC9F")
static var GOLD := Color("#FFD23F")

var provider: Object
var tab := 0
var _root: Control
var _title: Label
var _tagline: Label
var _money: HBoxContainer
var _tabs: HBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _dirty := false
## Money changed (every kill, mid-wave): refresh the stock chips, and rebuild the
## rows only if what they show changed, so buttons keep their hover and clicks.
var _money_dirty := false
var _items_sig := 0
var _built_ms := 0
var _hint_box: HBoxContainer
var _hint_tabs := -1
var _frame: PanelContainer
var _tab_rule: ColorRect
## The stat chart column (StatChart), shown when the list has charts.
var _chart: PanelContainer
var _chart_body: VBoxContainer
var _charted := false
## The row whose chart shows (its id, or name when it has none) and that row.
var _chart_key := ""
var _chart_row: Control


func _ready() -> void:
	instance = self
	layer = 45
	_build()
	_root.visible = false
	Economy.resources_changed.connect(func(_c: int) -> void: _money_dirty = true)
	UiStyle.notifier.changed.connect(_mark_dirty) # Theme: redraw rows in the new set


func is_open() -> bool:
	return UiStyle.shown(_root)


func open(p: Object) -> void:
	if provider != null and provider != p:
		_disconnect()
	provider = p
	tab = 0
	for sig: String in ["menu_changed", "ui_changed"]:
		if provider.has_signal(sig) and not provider.is_connected(sig, _mark_dirty):
			provider.connect(sig, _mark_dirty)
	var was_open := UiStyle.shown(_root)
	_size_frame()
	_root.visible = true
	GameState.set_menu(self, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()
	if not was_open:
		UiStyle.fade_in(_root)


func close() -> void:
	if not UiStyle.shown(_root):
		return
	_disconnect()
	provider = null
	UiStyle.fade_out(_root)
	GameState.set_menu(self, false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if GameState.menu_open else Input.MOUSE_MODE_CAPTURED # another screen may still be up


func _disconnect() -> void:
	if provider == null or not is_instance_valid(provider):
		return
	for sig: String in ["menu_changed", "ui_changed"]:
		if provider.has_signal(sig) and provider.is_connected(sig, _mark_dirty):
			provider.disconnect(sig, _mark_dirty)


func _input(event: InputEvent) -> void:
	if not UiStyle.shown(_root):
		return
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()
	elif _nav(event):
		get_viewport().set_input_as_handled()


## Keyboard and controller: arrows / d-pad move between rows and tabs (the first
## press lands on the first row), PageUp/PageDown or the shoulder buttons switch tabs.
func _nav(event: InputEvent) -> bool:
	var step := 0
	if event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_LEFT_SHOULDER: step = -1
			JOY_BUTTON_RIGHT_SHOULDER: step = 1
	if event.is_action_pressed("ui_page_up"):
		step = -1
	elif event.is_action_pressed("ui_page_down"):
		step = 1
	if step != 0:
		var n := _tabs.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion()).size()
		if n > 1:
			tab = wrapi(tab + step, 0, n)
			refresh()
			_focus_first.call_deferred()
		return true
	for a: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		if event.is_action_pressed(a):
			var f := get_viewport().gui_get_focus_owner()
			if f == null or not _root.is_ancestor_of(f):
				_focus_first()
				return true
	return false


## Focus the first live button in the list (or the selected tab if the list has none).
func _focus_first() -> void:
	var b := _first_button(_body)
	if b == null:
		var tabs := _tabs.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
		if tab < tabs.size():
			b = tabs[tab] as Button
	if b != null:
		b.grab_focus()


static func _first_button(n: Node) -> Button:
	for c: Node in n.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is Button and not (c as Button).disabled and (c as Button).focus_mode != Control.FOCUS_NONE:
			return c as Button
		var deep := _first_button(c)
		if deep != null:
			return deep
	return null


## Where keyboard focus sits, as [area, row, button] so a rebuild can put it back.
func _focus_path() -> Array:
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return []
	if _tabs.is_ancestor_of(f):
		return [&"tab", f.get_index(), 0]
	if not _body.is_ancestor_of(f):
		return []
	var row: Node = f
	while row.get_parent() != _body:
		row = row.get_parent()
	return [&"row", row.get_index(), f.get_index()]


func _restore_focus(path: Array) -> void:
	if path.is_empty():
		return
	var target: Control = null
	if path[0] == &"tab":
		var tabs := _tabs.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
		if int(path[1]) < tabs.size():
			target = tabs[int(path[1])] as Control
	else:
		var rows := _body.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
		if rows.is_empty():
			return
		var at := mini(int(path[1]), rows.size() - 1)
		var buttons := _live_buttons(rows[at])
		if buttons.is_empty():
			# That row's done (bought, fitted): the nearest row that still has a
			# button, so the list stays where it was instead of jumping to the top.
			for d in range(1, rows.size()):
				for j: int in [at + d, at - d]:
					if j >= 0 and j < rows.size() and buttons.is_empty():
						buttons = _live_buttons(rows[j])
				if not buttons.is_empty():
					break
			if buttons.is_empty():
				return
			target = buttons[0]
		else:
			target = buttons[mini(int(path[2]), buttons.size() - 1)]
	if target != null:
		target.grab_focus()


static func _live_buttons(row: Node) -> Array:
	return row.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return not b.disabled)


func _unhandled_input(event: InputEvent) -> void:
	if not UiStyle.shown(_root) and not GameState.menu_open and event.is_action_pressed("field_guide"):
		FieldGuide.open()
		get_viewport().set_input_as_handled()


func _mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if not UiStyle.shown(_root):
		return
	if provider == null or not is_instance_valid(provider):
		close()
		return
	if _dirty:
		_dirty = false
		_money_dirty = false
		refresh()
	elif _money_dirty:
		_money_dirty = false
		_money_changed()


func _money_changed() -> void:
	if provider == null:
		return
	_fill_money()
	if provider.has_method("menu_build_body"):
		# A custom body can't be compared: rebuild at most twice a second, and
		# never under a held mouse button (that would eat the click).
		if Time.get_ticks_msec() - _built_ms < 500 or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_money_dirty = true
			return
		refresh()
		return
	var items: Array = provider.call("menu_items", tab) if provider.has_method("menu_items") else []
	if hash(items) != _items_sig:
		refresh()


func refresh() -> void:
	if provider == null:
		return
	_title.text = str(provider.call("menu_title")).to_upper()
	_tagline.text = str(provider.call("menu_tagline")) if provider.has_method("menu_tagline") else ""
	_tagline.visible = _tagline.text != ""
	_fill_money()
	for c in _tabs.get_children():
		c.queue_free()
	var tabs: Array = provider.call("menu_tabs") if provider.has_method("menu_tabs") else []
	_tabs.visible = not tabs.is_empty()
	_tab_rule.visible = _tabs.visible
	_tab_rule.color = Color(UiStyle.c("accent"), 0.25)
	_fill_hints(tabs.size() > 1)
	for i in tabs.size():
		var b := tab_button(str(tabs[i]), i == tab)
		GlowRing.attach(b, str(tabs[i]))
		var index := i
		b.pressed.connect(func() -> void:
			tab = index
			refresh())
		_tabs.add_child(b)
	_built_ms = Time.get_ticks_msec()
	var keep_scroll := _scroll.scroll_vertical
	var keep_focus := _focus_path()
	for c in _body.get_children():
		c.queue_free()
	var picks: Array = [] # [row, item] for the stat chart
	if provider.has_method("menu_build_body"):
		_set_charted(false)
		provider.call("menu_build_body", _body, self)
	else:
		var items: Array = provider.call("menu_items", tab) if provider.has_method("menu_items") else []
		_items_sig = hash(items)
		_set_charted(items.any(func(it: Dictionary) -> bool: return it.has("chart")))
		for item: Dictionary in items:
			var row := _row(item)
			_body.add_child(row)
			picks.append([row, item])
		if items.is_empty():
			_body.add_child(UiStyle.status("Nothing here right now.", "info", 16))
	if _charted:
		# The chart shows the row it showed before the rebuild, else the first with one.
		_chart_row = null
		var pick: Array = []
		for p: Array in picks:
			if _key_of(p[1]) == _chart_key:
				pick = p
				break
		if pick.is_empty():
			for p: Array in picks:
				if (p[1] as Dictionary).has("chart"):
					pick = p
					break
		if not pick.is_empty():
			_pick(pick[0], pick[1], true) # (rebuilt: its numbers may have changed)
	_scroll.set_deferred("scroll_vertical", keep_scroll)
	if not keep_focus.is_empty():
		_restore_focus.call_deferred(keep_focus)


## Footer keycaps: close, and how to switch tabs when there are some.
func _fill_hints(with_tabs: bool) -> void:
	if _hint_tabs == int(with_tabs):
		return
	_hint_tabs = int(with_tabs)
	for c in _hint_box.get_children():
		c.queue_free()
	var pairs: Array = [[KeyHints.key_for("interact") + "/Esc", "Close"], ["Arrows", "Move"]]
	if with_tabs:
		pairs.append(["PgUp/PgDn", "Switch Tab"])
	_hint_box.add_child(UiStyle.paper_hints(pairs))


## Your stock as chips on the header strap ("[swatch] 370 Scrap").
func _fill_money() -> void:
	for c in _money.get_children():
		_money.remove_child(c)
		c.queue_free()
	# A provider may show its own stock instead: menu_stock() -> [[resource, amount], ...].
	if provider != null and provider.has_method("menu_stock"):
		for pair: Array in provider.call("menu_stock"):
			_money.add_child(UiStyle.stock_chip(StringName(str(pair[0])), int(pair[1])))
		return
	var player := _local_player()
	if player == null:
		return
	for r: StringName in [&"scrap", &"chitin"]:
		_money.add_child(UiStyle.stock_chip(r, Economy.amount(player.cliff_id, r)))
	if Economy.amount(player.cliff_id, AmberRules.ITEM) > 0: # Hive amber, once you have some
		_money.add_child(UiStyle.stock_chip(AmberRules.ITEM, Economy.amount(player.cliff_id, AmberRules.ITEM)))


func _local_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority():
			return n as Player
	return null


# ------------------------------------------------------------------ layout

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.fit(_root) # Theme: bigger on 1440p and up
	add_child(_root)
	_root.add_child(UiStyle.scrim())
	var frame := PanelContainer.new()
	_frame = frame
	frame.theme_type_variation = "FramePanel"
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
	# Header strap: title and tagline, your stock on the right.
	var header := UiStyle.strap("", "", 30)
	outer.add_child(header)
	_title = header.find_child("Title", true, false) as Label
	_tagline = header.find_child("Tagline", true, false) as Label
	_money = HBoxContainer.new()
	_money.add_theme_constant_override("separation", 6)
	_money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.strap_row(header).add_child(_money)
	# Parchment card.
	var card := PanelContainer.new()
	card.theme_type_variation = "PaperPanel"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", UiStyle.GAP_GROUP)
	card.add_child(inner)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 2)
	inner.add_child(_tabs)
	_tab_rule = ColorRect.new() # the line the underline tabs sit on
	_tab_rule.color = Color(UiStyle.c("accent"), 0.25)
	_tab_rule.custom_minimum_size.y = 1
	_tab_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_tab_rule)
	# The list, and beside it on the right the stat chart when the rows have one.
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 14)
	inner.add_child(mid)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	mid.add_child(_scroll)
	_chart = UiStyle.panel("CardPanel")
	_chart.custom_minimum_size.x = StatChart.WIDTH
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.visible = false
	mid.add_child(_chart)
	var chart_scroll := ScrollContainer.new()
	chart_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chart.add_child(chart_scroll)
	_chart_body = VBoxContainer.new()
	_chart_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_scroll.add_child(_chart_body)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", UiStyle.GAP_ROW)
	_scroll.add_child(_body)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", UiStyle.GAP_GROUP)
	inner.add_child(footer)
	_hint_box = HBoxContainer.new()
	_hint_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_hint_box)
	var close_b := wood_button("Close")
	close_b.theme_type_variation = "GhostButton"
	close_b.pressed.connect(close)
	footer.add_child(close_b)


## The frame's size: the provider's menu_size() (fitted inside the window) or the default.
func _size_frame() -> void:
	var want := Vector2(WIDTH, HEIGHT)
	if provider != null and provider.has_method("menu_size"):
		want = provider.call("menu_size")
	if _charted:
		want.x += StatChart.WIDTH + 14.0 # the stat chart column
	var room := _root.size - Vector2(24, 24)
	if room.x > 100.0 and room.y > 100.0:
		want = want.min(room)
	_frame.offset_left = -want.x * 0.5
	_frame.offset_right = want.x * 0.5
	_frame.offset_top = -want.y * 0.5
	_frame.offset_bottom = want.y * 0.5


## A gun rarity's colour (components/gun_rarity.gd: green, blue, purple, gold),
## clear for Common or when rarity isn't in this build. Loaded by path so this
## screen never depends on it at compile time.
static func rarity_color(r: int) -> Color:
	const PATH := "res://components/gun_rarity.gd"
	if r <= 0 or not ResourceLoader.exists(PATH):
		return Color(0, 0, 0, 0)
	var gr := load(PATH) as Script
	if gr == null or not gr.has_method("color_of"):
		return Color(0, 0, 0, 0)
	var col: Color = gr.call("color_of", r)
	return col.lerp(UiStyle.c("ink"), 0.12)


func _row(item: Dictionary) -> Control:
	var disabled := str(item.get("disabled", ""))
	var buttons: Array = item.get("buttons", [])
	var row := PanelContainer.new()
	row.theme_type_variation = "CardPanel"
	row.custom_minimum_size.y = 84
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	# The row under the mouse lifts (the kit's hover card: a lit bar on its left).
	# With a stat chart, the row it shows stays lit, and pointing at a row shows its chart.
	if disabled == "":
		row.mouse_entered.connect(func() -> void: row.theme_type_variation = "CardHoverPanel")
		row.mouse_exited.connect(func() -> void:
			if row != _chart_row:
				row.theme_type_variation = "CardPanel")
	if _charted:
		row.mouse_entered.connect(func() -> void: _pick(row, item))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)
	var icon_box := PanelContainer.new()
	icon_box.theme_type_variation = "IconPanel"
	# An item may ask for a bigger picture ("icon_px": the Field Guide's painted plates).
	var ipx := float(item.get("icon_px", 64.0))
	icon_box.custom_minimum_size = Vector2(ipx, ipx)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER if ipx <= 64.0 else Control.SIZE_SHRINK_BEGIN
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		draw.host = self # (a picture of the real model where there is one: every gun at the gunsmith)
		icon_box.add_child(draw)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 3)
	h.add_child(text)
	var name_l := ink_label(UiStyle.tc(str(item.get("name", ""))), 18)
	name_l.add_theme_font_override("font", UiStyle.font("bold"))
	var rar_col := rarity_color(int(item.get("rarity", 0))) # gun rarity: Uncommon and up wear their colour
	if rar_col.a > 0.0:
		name_l.add_theme_color_override("font_color", rar_col)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(name_l)
	# The description; a line of numbers under it ("Damage 60 · 8 Rounds") reads as chips.
	# (Kept in order: prose lines run together, each stat line becomes a row of chips.)
	var lines := str(item.get("desc", "")).split("\n")
	var prose: PackedStringArray = []
	for i in lines.size() + 1:
		var is_stats := i > 0 and i < lines.size() and lines[i].contains("·") and lines[i].length() < 260
		if i < lines.size() and not is_stats:
			prose.append(lines[i])
			continue
		if not prose.is_empty() and "\n".join(prose).strip_edges() != "":
			var desc := ink_label("\n".join(prose), 15, UiStyle.c("ink_soft"))
			desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.add_child(desc)
		prose.clear()
		if is_stats:
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 5)
			flow.add_theme_constant_override("v_separation", 5)
			flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for part: String in lines[i].split("·", false):
				if part.strip_edges() != "":
					flow.add_child(stat_chip(part.strip_edges()))
			text.add_child(flow)
	if disabled != "":
		text.add_child(UiStyle.status(disabled, str(item.get("disabled_kind", _reason_kind(disabled))), 14))
	# Right: the price as a number chip, then the actions, on one line.
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 4)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(right)
	var line_r := HBoxContainer.new()
	line_r.alignment = BoxContainer.ALIGNMENT_END
	line_r.add_theme_constant_override("separation", 8)
	line_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(line_r)
	if str(item.get("price", "")) != "":
		var tag := price_tag(str(item["price"]), bool(item.get("price_ok", true)))
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.custom_minimum_size.x = 104
		line_r.add_child(tag)
	if item.has("quantity"):
		line_r.add_child(_quantity(item, disabled != ""))
	for b: Array in buttons:
		var btn := wood_button(str(b[1]), true)
		btn.disabled = disabled != ""
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var action: StringName = StringName(str(b[0]))
		var id: Variant = item.get("id")
		btn.pressed.connect(func() -> void: provider.call("menu_press", id, action))
		if _charted: # keyboard and pad: the focused row's chart
			btn.focus_entered.connect(func() -> void: _pick(row, item))
		line_r.add_child(btn)
	if str(item.get("note", "")) != "":
		var note := ink_label(str(item["note"]), 14, UiStyle.c("ink_soft"))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(note)
	if disabled != "":
		row.modulate = Color(1, 1, 1, 0.78)
	return row


## Shows or hides the stat chart column (and widens the frame for it).
func _set_charted(on: bool) -> void:
	if on == _charted:
		return
	_charted = on
	_chart.visible = on
	if not on:
		_chart_row = null
	_size_frame()


static func _key_of(item: Dictionary) -> String:
	var id := str(item.get("id", ""))
	return id if id != "" else "name:" + str(item.get("name", ""))


## Shows `item`'s stat chart in the column and lights its row. Rows without a
## chart (the whip, the satchel) show their name and description there instead.
func _pick(row: Control, item: Dictionary, force: bool = false) -> void:
	if not _charted:
		return
	var key := _key_of(item)
	if _chart_row != null and is_instance_valid(_chart_row) and _chart_row != row:
		_chart_row.theme_type_variation = "CardPanel"
	_chart_row = row
	if is_instance_valid(row):
		row.theme_type_variation = "CardHoverPanel"
	if not force and key == _chart_key and _chart_body.get_child_count() > 0 and not _chart_body.get_child(0).is_queued_for_deletion():
		return
	_chart_key = key
	for c in _chart_body.get_children():
		_chart_body.remove_child(c)
		c.queue_free()
	if item.has("chart"):
		_chart_body.add_child(StatChart.build(item["chart"]))
	else:
		_chart_body.add_child(StatChart.build({"title": str(item.get("name", "")), "special": [],
			"note": str(item.get("desc", "")), "plain": true}))


## How many of each thing the quantity sliders were last set to (kept across the
## rows' rebuilds while the game runs).
static var _qty: Dictionary = {}


## A row's quantity picker (item "quantity": {"min", "max", "action", "verb",
## "unit_cost", "resource", "have"}): a slider with a visible bar, its count,
## and one button that buys that many ("Buy 4"), with the total under it in
## red when you can't cover it. The press is menu_press(id, "<action>:<n>").
func _quantity(item: Dictionary, off: bool) -> Control:
	var q: Dictionary = item["quantity"]
	var id: Variant = item.get("id")
	var lo := int(q.get("min", 1))
	var hi := int(q.get("max", 10))
	var n := clampi(int(_qty.get(id, lo)), lo, hi)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = n
	s.custom_minimum_size = Vector2(128, 22)
	s.focus_mode = Control.FOCUS_NONE
	s.editable = not off
	s.tooltip_text = "How many to buy at once (%d to %d)." % [lo, hi]
	var pad := MarginContainer.new() # (room for the knob at either end of the bar)
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(s)
	col.add_child(pad)
	var total := UiStyle.label("", 13)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total.add_theme_font_override("font", UiStyle.font("label"))
	col.add_child(total)
	var btn := wood_button("", true)
	btn.disabled = off
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size.x = 92
	box.add_child(btn)
	var unit := float(q.get("unit_cost", 0.0))
	var have := float(q.get("have", INF))
	var show := func(v: int) -> void:
		btn.text = "%s %d" % [str(q.get("verb", "Buy")), v]
		var cost := unit * v
		total.text = "Total " + UiStyle.cost(cost, str(q.get("resource", "scrap")))
		total.add_theme_color_override("font_color", UiStyle.c("ink_soft") if cost <= have else UiStyle.c("bad"))
	show.call(n)
	s.value_changed.connect(func(v: float) -> void:
		_qty[id] = int(v)
		show.call(int(v)))
	var action := str(q.get("action", "buy"))
	btn.pressed.connect(func() -> void: provider.call("menu_press", id, StringName("%s:%d" % [action, int(s.value)])))
	return box


## A disabled row's reason reads as done (a tick) when it is about something
## already had, otherwise as a warning; providers may pass "disabled_kind".
static func _reason_kind(reason: String) -> String:
	var r := reason.to_lower()
	for done: String in ["fitted", "fully", "owned", "maxed", "already", "golden", "worn", "built"]:
		if r.begins_with(done) or r.contains(" " + done):
			return "good"
	return "warn"


# ------------------------------------------------------------------ shared widgets

static func ink_label(text: String, size: int = 16, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UiStyle.ts(size))
	l.add_theme_color_override("font_color", color)
	return l


static func _outlined(text: String, size: int, color: Color) -> Label:
	var l := ink_label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_color_override("font_outline_color", UiStyle.c("outline"))
	l.add_theme_constant_override("outline_size", 6)
	return l


## Theme: light text on the header strap (follows the set).
static func _header_text(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "HudLabel"
	l.add_theme_font_size_override("font_size", UiStyle.ts(size))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	return l


## Theme: the set's button (no per-button colours, so it follows live swaps).
static func wood_button(text: String, small: bool = false) -> Button:
	var b := Button.new()
	b.text = UiStyle.tc(text)
	b.focus_mode = Control.FOCUS_ALL # keyboard focus shows the set's ring (never on clicks)
	b.custom_minimum_size = Vector2(84 if small else 120, 32 if small else 40)
	b.add_theme_font_size_override("font_size", UiStyle.ts(14 if small else 16))
	return b


## A tab or toggle: lit up in the set's selected style.
static func tab_button(text: String, selected: bool) -> Button:
	var b := wood_button(text, true)
	b.custom_minimum_size.x = 96
	b.theme_type_variation = "TabButtonSelected" if selected else "TabButton"
	return b


## A price chip ("60 Scrap"): the figure in the kit's number face, the word
## after it; one you can't afford also gets a cross, so it doesn't rely on red alone.
static func price_tag(text: String, ok: bool) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = "ChipPanel" if ok else "ChipBadPanel"
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	p.tooltip_text = "" if ok else "You can't afford this yet."
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	if not ok:
		h.add_child(UiStyle.mark("bad", UiStyle.c("bad"), 12))
	var words := UiStyle.tc(text).split(" ", false, 1)
	if words.size() == 2 and words[0].is_valid_float():
		var n := UiStyle.number(words[0], 20, UiStyle.c("accent_hi") if ok else UiStyle.c("bad"))
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(n)
		var w := ink_label(words[1], 14, UiStyle.c("ink_soft") if ok else UiStyle.c("bad"))
		w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(w)
	else:
		h.add_child(ink_label(UiStyle.tc(text), 15, UiStyle.c("accent_hi") if ok else UiStyle.c("bad")))
	return p


## One number of a stat line as a small chip ("Range 98 m").
static func stat_chip(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "ChipPanel"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := ink_label(text, 13, UiStyle.c("ink"))
	l.add_theme_font_override("font", UiStyle.font("bold"))
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


## A playing card: rank and suit on an ivory card (0 = face down). Real card
## stock, so its ink stays dark whatever the set (the set's "ink" is light now).
const CARD_INK := Color("#1E1A18")
const CARD_RED := Color("#B3261E")


static func card(c: int, suit: int) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = Color(CARD_INK, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.set_content_margin_all(4)
	sb.anti_aliasing = true
	p.custom_minimum_size = Vector2(62, 88)
	if c <= 0:
		sb.bg_color = Color("#7A2E22")
		sb.border_color = Color("#FFF5E6")
		sb.set_border_width_all(3)
		p.add_theme_stylebox_override("panel", sb)
		var back := UiStyle.mark("info", Color("#E9C46A"), 22)
		back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		p.add_child(back)
		return p
	sb.bg_color = Color("#FFFDF5")
	p.add_theme_stylebox_override("panel", sb)
	var red := suit % 4 == 1 or suit % 4 == 2
	var col := CARD_RED if red else CARD_INK
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var rank := UiStyle.number(CasinoRules.RANKS[clampi(c, 1, 13) - 1], 30, col)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rank)
	var s := SuitIcon.new()
	s.suit = suit % 4
	s.color = col
	s.custom_minimum_size = Vector2(26, 26)
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(s)
	return p


# Theme: the surfaces now come from the UI theme set (kept for older callers; each
# call returns a private copy, so callers may change its margins).
static func _frame_style() -> StyleBox:
	return UiStyle.box("frame").duplicate() as StyleBox


static func _plank_style() -> StyleBox:
	return UiStyle.box("header").duplicate() as StyleBox


static func _parchment_style() -> StyleBox:
	return UiStyle.box("paper").duplicate() as StyleBox


static func _card_style(hover: bool) -> StyleBox:
	return UiStyle.box("card_hover" if hover else "card").duplicate() as StyleBox


static func _icon_style() -> StyleBox:
	return UiStyle.box("icon").duplicate() as StyleBox


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

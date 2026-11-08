extends CanvasLayer
## The UI kit's style sheet (debug only, for the redesign report): every part of
## the kit in the current set, side by side. The UI gallery shows it as its
## "kit_sheet" step on the title screen; it rebuilds when the set swaps.

var _root: Control


func _ready() -> void:
	layer = 90
	_build()
	UiStyle.notifier.changed.connect(_rebuild)


func _exit_tree() -> void:
	if UiStyle.notifier.changed.is_connected(_rebuild):
		UiStyle.notifier.changed.disconnect(_rebuild)


func _rebuild() -> void:
	if _root != null:
		_root.queue_free()
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.fit(_root)
	add_child(_root)
	_root.add_child(UiStyle.backdrop())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_root.add_child(margin)
	var frame := UiStyle.panel("FramePanel")
	margin.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	frame.add_child(outer)
	var head := UiStyle.strap("The Kit: " + str(UiStyle.SETS[UiStyle.current]["name"]), "Every surface, control and type style in this set.", 34)
	outer.add_child(head)
	var stock := UiStyle.strap_row(head)
	stock.add_child(UiStyle.stock_chip(&"scrap", 550))
	var body := PanelContainer.new()
	body.theme_type_variation = "PaperPanel"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	body.add_child(cols)
	cols.add_child(_col_type())
	cols.add_child(_col_controls())
	cols.add_child(_col_surfaces())


func _column(title: String, width: float = 540.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size.x = width
	v.add_child(UiStyle.section(title))
	return v


func _col_type() -> Control:
	var v := _column("Type", 390.0)
	var t := UiStyle.title("Dust & Mandibles", 28)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(t)
	var h := UiStyle.title("Header Title", 26, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(h)
	v.add_child(UiStyle.eyebrow("Eyebrow Label  ·  Team Chitin", 14))
	var n := HBoxContainer.new()
	n.add_theme_constant_override("separation", 18)
	n.add_child(UiStyle.number("550", 40))
	n.add_child(UiStyle.number("6 / 6", 40, UiStyle.c("accent_hi")))
	n.add_child(UiStyle.number("0:45", 40, UiStyle.c("ink_soft")))
	v.add_child(n)
	var body := UiStyle.label("Body text in Barlow Semi Condensed: Gatling Post, fast, low damage. Shreds swarms, poor against armour.", 16)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(body)
	v.add_child(UiStyle.note("Soft notes and descriptions sit a step back in the muted ink.", 14))
	for k: Array in [["good", "Built: Gatling Post"], ["bad", "Not enough chitin"], ["warn", "Dust on the horizon"], ["lock", "Unlocks at wave 5"]]:
		v.add_child(UiStyle.status(str(k[1]), str(k[0]), 15))
	v.add_child(UiStyle.divider(360))
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override("separation", 6)
	for key: String in ["deep", "surface", "raised", "well", "accent", "accent_hi", "text", "soft", "title"]:
		var c := ColorRect.new()
		c.color = UiStyle.kc(key)
		c.custom_minimum_size = Vector2(34, 34)
		c.tooltip_text = key
		sw.add_child(c)
	v.add_child(sw)
	var keys := UiStyle.paper_hints([["E", "Use"], ["B", "Build"], ["Esc", "Close"]])
	v.add_child(keys)
	return v


## A control drawn in a given state (hover and press can't be held for a photo).
func _state(text: String, part: String, color: Color, variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.box(part))
	p.custom_minimum_size = Vector2(0, 44)
	var l := UiStyle.label(text, 17, color)
	l.add_theme_font_override("font", UiStyle.font("bold"))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	if variation != "":
		p.set_meta(&"variation", variation)
	return p


func _col_controls() -> Control:
	var v := _column("Controls", 520.0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for s: Array in [["Button", "button", UiStyle.c("btn")], ["Hovered", "button_hover", UiStyle.c("btn_hover")],
			["Pressed", "button_pressed", UiStyle.c("btn_hover")], ["Disabled", "button_disabled", UiStyle.c("btn_off")],
			["Ride Out", "primary", UiStyle.c("rim")], ["Ride Out", "primary_hover", UiStyle.c("rim")],
			["Back", "ghost", UiStyle.c("ink_soft")], ["Back", "ghost_hover", UiStyle.c("accent_hi")]]:
		var p := _state(str(s[0]), str(s[1]), s[2] as Color)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(p)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	for i in 4:
		var b := Button.new()
		b.text = ["Controls", "Graphics", "Audio", "Debug"][i]
		b.theme_type_variation = "TabButtonSelected" if i == 1 else "TabButton"
		tabs.add_child(b)
	v.add_child(tabs)
	v.add_child(_row("Mouse Sensitivity", UiStyle.slider(0.0, 1.0, 0.01, 0.62, "pct", func(_x: float) -> void: pass)))
	v.add_child(_row("Invert Mouse Y", UiStyle.check(true, func(_x: bool) -> void: pass)))
	v.add_child(_row("Show Subtitles", UiStyle.check(false, func(_x: bool) -> void: pass)))
	var opt := OptionButton.new()
	opt.add_item("165 FPS")
	v.add_child(_row("FPS Cap", opt))
	var field := LineEdit.new()
	field.text = "DUST-60N00-M0R4X"
	field.custom_minimum_size.y = 40
	v.add_child(_row("Invite Code", field))
	for b: Array in [[Palette.team_color(0), 72.0, "West Cliff (Rancher)"], [Color("#B3261E"), 38.0, "Iron Tumbleweed"], [Color("#3E8EBF"), 55.0, "Water Tower"]]:
		var bv := VBoxContainer.new()
		bv.add_theme_constant_override("separation", 2)
		var cap := UiStyle.eyebrow(str(b[2]), 13)
		bv.add_child(cap)
		var bar := UiStyle.bar(b[0] as Color, Vector2(500, 18))
		bar.value = float(b[1])
		bv.add_child(bar)
		v.add_child(bv)
	return v


func _col_surfaces() -> Control:
	var v := _column("Surfaces", 410.0)
	var card := UiStyle.panel("CardPanel")
	card.add_child(_card_row("Gatling Post", "Fast, low damage. Shreds swarms.", "40 Chitin"))
	v.add_child(card)
	var hover := UiStyle.panel("CardHoverPanel")
	hover.add_child(_card_row("Buffalo Rifle Nest", "Heavy single shots. Cracks armour.", "60 Chitin"))
	v.add_child(hover)
	var hud := PanelContainer.new()
	hud.add_theme_stylebox_override("panel", UiStyle.hud_box())
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hud.add_child(hv)
	hv.add_child(UiStyle.eyebrow("HUD Plate  ·  Wave 3", 13))
	hv.add_child(UiStyle.label("Dust Mites  ·  A Horde", 16, UiStyle.c("hud")))
	v.add_child(hud)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.add_child(UiStyle.tier_chip(0))
	chips.add_child(UiStyle.tier_chip(1))
	chips.add_child(UiStyle.tier_chip(2, true))
	var bad := UiStyle.panel("ChipBadPanel")
	var bl := UiStyle.label("Can't Afford", 13, UiStyle.c("bad"))
	bl.autowrap_mode = TextServer.AUTOWRAP_OFF
	bad.add_child(bl)
	chips.add_child(bad)
	v.add_child(chips)
	var wells := HBoxContainer.new()
	wells.add_theme_constant_override("separation", 10)
	for id: StringName in [&"corn", &"chili", &"herbs", &"scrap"]:
		var w := UiStyle.panel("IconPanel")
		var tex := UiStyle.painted_icon(id)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(52, 52)
		w.add_child(tr)
		wells.add_child(w)
	v.add_child(wells)
	var doc := UiStyle.panel("DocPanel")
	var dv := VBoxContainer.new()
	doc.add_child(dv)
	var dt := UiStyle.title("The Territorial Gazette", 24)
	dt.add_theme_color_override("font_color", Color("#2B1C10"))
	dt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dt.custom_minimum_size.x = 330
	dv.add_child(dt)
	var dl := UiStyle.label("Paper is kept for real documents: the Gazette, telegrams and letters.", 15)
	dl.theme_type_variation = "DocInkLabel"
	dv.add_child(dl)
	v.add_child(doc)
	var popup := UiStyle.panel("PopupPlate")
	popup.add_child(UiStyle.label("Tooltip and dropdown plate", 15))
	v.add_child(popup)
	return v


func _card_row(name: String, desc: String, price: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UiStyle.label(name, 18)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.add_theme_font_override("font", UiStyle.font("bold"))
	words.add_child(n)
	words.add_child(UiStyle.note(desc, 14))
	h.add_child(words)
	var chip := UiStyle.panel("ChipPanel")
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(UiStyle.number(price, 18, UiStyle.c("accent_hi")))
	h.add_child(chip)
	return h


func _row(caption: String, control: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	var l := UiStyle.label(caption, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = 200
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 240)
	r.add_child(control)
	return r

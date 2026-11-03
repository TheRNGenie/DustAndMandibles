class_name BrandScreen
extends CanvasLayer
## The start of every run: four branding irons glowing over a stretched
## cowhide. Pick The Sheaf, The Crossed Irons, The Snake Eyes or No Brand; each
## column is laid out on its own theme's paper so you see the look you'll ride
## with, and taking one burns it on (Brand.choose re-themes the whole UI).
## Opens itself in the lobby (MainMenu) until you've chosen; "Change Brand"
## reopens it. `--brandview=<png>` screenshots it (scenes/debug/theme_views.gd).

signal picked(id: StringName)

var _root: Control
var _irons: Array[BrandIron] = []
var _cols: Array[PanelContainer] = []
var _note: Label
var _t := 0.0


func _ready() -> void:
	layer = 70
	_build()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_root.visible = true
	_refresh()


func close() -> void:
	_root.visible = false


func _input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("pause_menu") and Brand.has_chosen():
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_t += delta
	for i in _irons.size():
		var iron := _irons[i]
		var target := 1.0 if iron.hovered or BrandTable.IDS[i] == Brand.local else 0.55
		if BrandTable.IDS[i] == BrandTable.NONE:
			target *= 0.0 # the cold iron never glows
		iron.mark.heat = lerpf(iron.mark.heat, target * (0.9 + 0.1 * sin(_t * 5.0 + i)), minf(delta * 6.0, 1.0))


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.fit(_root) # Theme: bigger on 1440p and up
	add_child(_root)
	var hide := TextureRect.new()
	hide.texture = load("res://assets/ui/theme/brand/cowhide.png")
	hide.stretch_mode = TextureRect.STRETCH_TILE
	hide.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(hide)
	var vig := TextureRect.new()
	vig.texture = UiStyle.vignette()
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(vig)
	# Embers glow up from the bottom (the fire the irons came out of).
	var fire := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.35, 0.05, 0.0))
	g.set_color(1, Color(1.0, 0.35, 0.05, 0.38))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	fire.texture = gt
	fire.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fire.stretch_mode = TextureRect.STRETCH_SCALE
	fire.anchor_left = 0.0
	fire.anchor_right = 1.0
	fire.anchor_top = 0.62
	fire.anchor_bottom = 1.0
	fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(fire)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	var banner := PanelContainer.new()
	var hb := _set_box(&"base", "header")
	hb.content_margin_left = 48
	hb.content_margin_right = 48
	hb.content_margin_top = 10
	hb.content_margin_bottom = 12
	banner.add_theme_stylebox_override("panel", hb)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	banner.custom_minimum_size.x = 980
	col.add_child(banner)
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 0)
	banner.add_child(bcol)
	bcol.add_child(_base_title("Burn Your Brand", 50))
	bcol.add_child(_plain("Every rider takes a brand for the run: it shapes how you play and how your gear looks.", 17, Color("#F2E3C2")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for id: StringName in BrandTable.IDS:
		row.add_child(_column(id))
	var note_box := PanelContainer.new()
	note_box.add_theme_stylebox_override("panel", _set_box(&"base", "hud"))
	note_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	note_box.custom_minimum_size.x = 760
	col.add_child(note_box)
	_note = _plain("", 16, Color("#F2E3C2"))
	note_box.add_child(_note)


func _column(id: StringName) -> Control:
	var set_id := BrandTable.theme_of(id)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _set_box(set_id, "poster"))
	p.custom_minimum_size = Vector2(300, 540)
	_cols.append(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var iron := BrandIron.new()
	iron.brand = id
	iron.custom_minimum_size = Vector2(0, 190)
	v.add_child(iron)
	_irons.append(iron)
	var ink := Color(str(UiStyle.SETS[set_id]["ink"]))
	var soft := Color(str(UiStyle.SETS[set_id]["ink_soft"]))
	var name_l := _set_title(set_id, BrandTable.name_of(id), 28, ink)
	v.add_child(name_l)
	var motto := _plain(str(BrandTable.BRANDS[id]["motto"]), 15, soft)
	motto.add_theme_font_override("font", _set_font(set_id))
	v.add_child(motto)
	var rule := TextureRect.new()
	rule.texture = UiStyle.texture(set_id, "divider")
	rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rule.custom_minimum_size = Vector2(240, 18)
	v.add_child(rule)
	for line: String in BrandTable.BRANDS[id]["lines"]:
		var l := _plain("-  " + line, 15, ink)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.custom_minimum_size.x = 250
		v.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var b := Button.new()
	b.text = "Ride Unbranded" if id == BrandTable.NONE else "Take %s" % BrandTable.name_of(id)
	b.custom_minimum_size = Vector2(0, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	for pair: Array in [["normal", "button"], ["hover", "button_hover"], ["pressed", "button_pressed"], ["disabled", "button_disabled"]]:
		b.add_theme_stylebox_override(pair[0], _set_box(set_id, pair[1]))
	var s: Dictionary = UiStyle.SETS[set_id]
	b.add_theme_color_override("font_color", Color(str(s["btn"])))
	b.add_theme_color_override("font_hover_color", Color(str(s["btn_hover"])))
	b.add_theme_color_override("font_outline_color", Color(str(s["btn_outline"])))
	b.pressed.connect(_pick.bind(id))
	b.mouse_entered.connect(func() -> void: iron.hovered = true)
	b.mouse_exited.connect(func() -> void: iron.hovered = false)
	p.mouse_entered.connect(func() -> void: iron.hovered = true)
	p.mouse_exited.connect(func() -> void: iron.hovered = false)
	v.add_child(b)
	return p


func _pick(id: StringName) -> void:
	if not Brand.choose(id):
		_note.text = "Brands are locked once the run is under way."
		return
	for snd: StringName in [&"brand_sizzle", &"cig_light"]:
		if Audio.has_sound(snd):
			Audio.play_ui(snd)
			break
	picked.emit(id)
	_refresh()
	get_tree().create_timer(0.45).timeout.connect(close)


func _refresh() -> void:
	for i in _cols.size():
		var id := BrandTable.IDS[i]
		_cols[i].modulate = Color.WHITE if Brand.local == &"" or Brand.local == id else Color(0.86, 0.84, 0.82)
	_note.text = ("You ride with %s. Pick again to change it before the run starts." % BrandTable.name_of(Brand.local)) if Brand.has_chosen() \
		else "Hover an iron to see what it does. You can change it in the lobby until the run starts."


# ------------------------------------------------------------------ styling from a given set

static func _set_box(set_id: StringName, part: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	UiStyle._fill_box(sb, part, set_id)
	return sb


static func _set_font(set_id: StringName) -> Font:
	var s: Dictionary = UiStyle.SETS[set_id]
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(s["fonts"])
	sf.font_weight = int(s["weight"])
	sf.font_italic = bool(s["italic"])
	var fv := FontVariation.new()
	fv.base_font = sf
	fv.spacing_glyph = int(s["spacing"])
	if int(s["wdth"]) > 0:
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wdth"): float(s["wdth"]), ts.name_to_tag("wght"): float(s["weight"])}
	return fv


static func _set_title(set_id: StringName, text: String, size: int, ink: Color) -> Label:
	var l := _plain(text.to_upper(), size, ink)
	l.add_theme_font_override("font", _set_font(set_id))
	return l


static func _base_title(text: String, size: int) -> Label:
	var l := _plain(text.to_upper(), size, Color("#F2C14E"))
	l.add_theme_font_override("font", _set_font(&"base"))
	l.add_theme_color_override("font_outline_color", Color("#1A0F07"))
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


static func _plain(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A branding iron: a dark rod rising from below with the mark glowing at its head.
class BrandIron extends Control:
	var brand: StringName = &"none"
	var hovered := false
	var mark: BrandMark

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		mark = BrandMark.new()
		mark.brand = brand
		mark.color = Color("#2B2B2B") if brand == BrandTable.NONE else Color("#3A2416")
		mark.heat = 0.5
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mark)
		mouse_entered.connect(func() -> void: hovered = true)
		mouse_exited.connect(func() -> void: hovered = false)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and mark != null:
			var d := minf(size.y * 0.72, size.x * 0.6)
			mark.size = Vector2(d, d)
			mark.position = Vector2((size.x - d) * 0.5, 4)

	func _draw() -> void:
		var cx := size.x * 0.5
		var head_bottom := minf(size.y * 0.72, size.x * 0.6) + 2.0
		var h := mark.heat if mark != null else 0.0
		# Heat haze behind the head.
		if h > 0.05:
			for i in 6:
				var r := (head_bottom * 0.55) * (1.0 + i * 0.12)
				draw_circle(Vector2(cx, head_bottom * 0.5), r, Color(1.0, 0.45, 0.1, 0.035 * h))
		# The rod: shank from the head down, glowing where it meets the mark.
		var shank_top := Vector2(cx, head_bottom - 6)
		var shank_bot := Vector2(cx, size.y)
		draw_line(shank_top, shank_bot, Color("#1E1A18"), 7.0, true)
		draw_line(shank_top + Vector2(-1.5, 0), shank_bot + Vector2(-1.5, 0), Color("#5A5550"), 1.5, true)
		draw_line(shank_top, shank_top + Vector2(0, 22), Color(1.0, 0.5, 0.15, 0.8 * h), 5.0, true)
		# A twisted handle ring near the bottom.
		draw_arc(Vector2(cx, size.y - 14), 9.0, 0.0, TAU, 20, Color("#1E1A18"), 4.0, true)

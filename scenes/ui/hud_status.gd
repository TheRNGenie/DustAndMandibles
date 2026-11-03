class_name HudStatus
extends Control
## Bottom-left: your health and your two currencies as big counters: the
## team's shared scrap pot ("Team Scrap") and your own chitin ("Your Chitin").
## Vegetables and water live on the hotbar. Top corners: both
## Homesteads' health, labelled "Yours" (left) and "Theirs" (right) for each player.

var cliff_id: int = 0
var _hp_bar: ProgressBar
var _hp_text: Label
var _smoke: Label
## Sarsaparilla tonic: on your turrets (from your partner) or on theirs (from you).
var _tonic: Label
var _scrap: Label
var _chitin: Label
## Solo on the canyon: the other cliff's chitin, on a small labelled line.
var _chitin_other: Label
var _homes: Array[ProgressBar] = []
var _captions: Array[Label] = []
var _downed: Label
## Hunger / thirst icons beside the health panel, only shown when running low.
var _food_icon: NeedIcon
var _water_icon: NeedIcon


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.wood_sign())
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24
	panel.offset_top = -132
	panel.offset_right = 300
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN # a second stockpile line grows it upward
	panel.offset_bottom = -24
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	# "Health  85 / 100" over the bar, like the Homestead captions.
	var hp_row := HBoxContainer.new()
	col.add_child(hp_row)
	var hp_caption := _hud_text("Health", 14)
	hp_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(hp_caption)
	_hp_text = _hud_text("100 / 100", 14)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(_hp_text)
	_hp_bar = _bar(Palette.TEAM_WEST, 100.0)
	col.add_child(_hp_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	_scrap = _counter(row, &"scrap", "Team Scrap")
	_scrap.tooltip_text = "Scrap is shared: everyone builds from this pot and every kill pays into it."
	_chitin = _counter(row, &"chitin", "Your Chitin")
	_chitin_other = _chitin.get_meta(&"other") as Label
	_smoke = UiStyle.label("", 13, UiStyle.c("hud"))
	_smoke.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_smoke.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_smoke.add_theme_constant_override("outline_size", 4)
	col.add_child(_smoke)
	_tonic = UiStyle.label("", 13, UiStyle.hud_c("good"))
	_tonic.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tonic.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tonic.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_tonic.add_theme_constant_override("outline_size", 4)
	_tonic.visible = false
	col.add_child(_tonic)

	var needs := VBoxContainer.new()
	needs.anchor_top = 1.0
	needs.anchor_bottom = 1.0
	needs.offset_left = 306
	needs.offset_top = -132
	needs.offset_right = 346
	needs.add_theme_constant_override("separation", 6)
	needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(needs)
	_water_icon = NeedIcon.new()
	_water_icon.kind = &"water"
	needs.add_child(_water_icon)
	_food_icon = NeedIcon.new()
	_food_icon.kind = &"food"
	needs.add_child(_food_icon)

	# Maps: one bar per cliff. Yours top-left; the others stacked top-right.
	for i in WorldLayout.cliff_count():
		var box := VBoxContainer.new()
		box.anchor_left = 0.0 if i == 0 else 1.0
		box.anchor_right = box.anchor_left
		box.offset_left = 24.0 if i == 0 else -284.0
		box.offset_right = box.offset_left + 260.0
		box.offset_top = 16 + (0 if i == 0 else (i - 1) * 50)
		add_child(box)
		var caption := UiStyle.label("", 16, UiStyle.c("hud"))
		caption.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		caption.add_theme_constant_override("outline_size", 6)
		box.add_child(caption)
		var bar := _bar(Palette.team_color(i), Defs.WAVE_CONFIG.homestead_hp)
		box.add_child(bar)
		_homes.append(bar)
		_captions.append(caption)

	_downed = UiStyle.label("", 34, UiStyle.hud_c("bad"))
	_downed.set_anchors_preset(Control.PRESET_CENTER)
	_downed.offset_left = -400
	_downed.offset_right = 400
	_downed.offset_top = -120
	_downed.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_downed.add_theme_constant_override("outline_size", 10)
	add_child(_downed)

	Economy.resources_changed.connect(func(_c: int) -> void: _refresh_resources())
	Economy.stolen_from.connect(_on_stolen)
	GameState.homestead_changed.connect(func(_c: int, _hp: float, _mx: float) -> void: _refresh_homes())
	_refresh_homes()
	_refresh_resources()


func _process(_delta: float) -> void:
	if Economy.tonic_left.is_empty():
		if _tonic.visible:
			_tonic.visible = false
		return
	var mine := Economy.tonic(cliff_id)
	var theirs := Economy.tonic(PartnerTonic.partner_of(cliff_id))
	var pct := int(round(PartnerTonic.FIRE_RATE_BONUS * 100.0))
	var paused := "" if GameState.phase == GameState.Phase.WAVE else "  ·  Paused"
	if mine > 0.0:
		_tonic.text = "Partner's Tonic  ·  +%d%% Fire  ·  %s%s" % [pct, UiStyle.clock(mine), paused]
	elif theirs > 0.0:
		_tonic.text = "Your Tonic on %s  ·  %s%s" % [WorldLayout.map().name_of(PartnerTonic.partner_of(cliff_id)), UiStyle.clock(theirs), paused]
	_tonic.visible = mine > 0.0 or theirs > 0.0


func bind_player(player: Player) -> void:
	cliff_id = player.cliff_id
	_hp_bar.add_theme_stylebox_override("fill", _fill(Palette.team_color(cliff_id)))
	player.vitals.health_changed.connect(func(hp: float, mx: float) -> void:
		_hp_bar.max_value = mx
		_hp_bar.value = hp
		_hp_text.text = "%d / %d" % [ceili(maxf(hp, 0.0)), roundi(mx)])
	if player.cigarette != null:
		player.cigarette.changed.connect(func(left: float) -> void:
			_smoke.text = ("Smoking  ·  %s  ·  Faster, Sharper Eyes" % UiStyle.clock(left)) if left > 0.0 else "")
	player.vitals.needs_changed.connect(func(f: float, w: float) -> void:
		_food_icon.set_level(f)
		_water_icon.set_level(w))
	player.vitals.downed_changed.connect(func(is_down: bool, secs: float) -> void:
		_downed.text = "Downed  ·  Back on Your Feet in %s" % UiStyle.clock(secs) if is_down else "")
	_refresh_homes()
	_refresh_resources()


## A small left-aligned HUD caption in the set's light ink, outlined.
func _hud_text(text: String, size: int) -> Label:
	var l := UiStyle.label(text, size, UiStyle.c("hud"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	return l


## Top-left bar = your Homestead, the others top-right (labelled by cliff,
## with whoever holds it).
func _refresh_homes() -> void:
	var order: Array[int] = [cliff_id]
	for cid in WorldLayout.cliff_count():
		if cid != cliff_id:
			order.append(cid)
	for i in mini(order.size(), _homes.size()):
		var cid := order[i]
		if cid >= GameState.homestead_hp.size():
			continue
		# "North Butte (Logan)": yours top-left, CPUs as "(Dusty, CPU)".
		var who := Hud.owner_name(cid).replace(" (CPU)", ", CPU")
		if who == "you" or who == "empty":
			who = "yours" if i == 0 else who
		_captions[i].text = "%s (%s)" % [WorldLayout.map().name_of(cid), who]
		_homes[i].max_value = maxf(GameState.homestead_max[cid], 1.0)
		_homes[i].value = GameState.homestead_hp[cid]
		_homes[i].add_theme_stylebox_override("fill", _fill(Palette.team_color(cid)))


func _refresh_resources() -> void:
	# Scrap is the team's one pot (the same number for everyone); chitin is yours.
	_scrap.text = str(Economy.team_scrap())
	_chitin.text = str(Economy.amount(cliff_id, &"chitin"))
	# Solo on the canyon you play both cliffs: the big chitin number is the cliff
	# you stand on, and a small labelled line under it is the other cliff's.
	var other := 1 - cliff_id
	var both := GameState.is_solo() and WorldLayout.cliff_count() == 2 and other >= 0
	_chitin_other.visible = both
	if both:
		_chitin_other.text = "%s: %d" % [WorldLayout.map().name_of(other), Economy.amount(other, &"chitin")]


## A breaching bug stole from a stockpile: a red "-N" rises off the counter and fades.
## Scrap comes out of the team pot, so everyone sees that; chitin only its owner.
func _on_stolen(cid: int, amounts: Dictionary) -> void:
	var counters := {&"scrap": _scrap, &"chitin": _chitin}
	for r: StringName in amounts:
		if not EconomyLedger.is_shared(r) and cid != cliff_id and not GameState.is_solo():
			continue
		var counter := counters.get(r) as Label
		if counter == null:
			continue
		var l := UiStyle.label("-%d" % int(amounts[r]), 20, UiStyle.hud_c("bad"))
		l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		l.add_theme_constant_override("outline_size", 6)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		var at := counter.global_position - global_position + Vector2(counter.size.x + 6.0, 0.0)
		l.position = at
		var tw := l.create_tween()
		tw.set_parallel(true)
		tw.tween_property(l, "position:y", at.y - 34.0, 1.6).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.6)
		tw.chain().tween_callback(l.queue_free)
		var flash := counter.create_tween()
		counter.modulate = Color(1.6, 0.6, 0.5)
		flash.tween_property(counter, "modulate", Color.WHITE, 0.8)


## A currency swatch, a small caption and a big number (plus a hidden small line
## for the other cliff's pile, kept on the number's "other" meta).
func _counter(parent: HBoxContainer, resource: StringName, caption: String) -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	var chip := UiStyle.swatch(UiStyle.resource_color(resource), 18)
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chip.custom_minimum_size.y = 18
	var chip_box := MarginContainer.new()
	chip_box.add_theme_constant_override("margin_top", 18)
	chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_box.add_child(chip)
	box.add_child(chip_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	box.add_child(v)
	var cap := UiStyle.label(caption, 12, Color(UiStyle.c("hud"), 0.75))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(cap)
	var num := UiStyle.label("0", 24, UiStyle.c("hud"))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	num.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(num)
	var other := UiStyle.label("", 12, Color(UiStyle.c("hud"), 0.75))
	other.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	other.autowrap_mode = TextServer.AUTOWRAP_OFF
	other.visible = false
	v.add_child(other)
	num.set_meta(&"other", other)
	return num


static func _fill(color: Color) -> StyleBoxFlat:
	return UiStyle.bar_fill(color) # one bar style everywhere (UiStyle.bar)


func _bar(color: Color, max_value: float) -> ProgressBar:
	return UiStyle.bar(color, Vector2(240, 18), max_value)


## A small rounded card with a water drop or a corn cob, shown only when that need
## runs low; it fades as the need empties and its edge pulses red when nearly out.
class NeedIcon extends Control:
	var kind := &"water"
	var level := 1.0
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(36, 36)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func set_level(v: float) -> void:
		level = v
		visible = v < PlayerVitals.NEED_LOW
		queue_redraw()

	func _process(delta: float) -> void:
		if visible and level < 0.12:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var pulse := 0.5 + 0.5 * sin(_t * 7.0) if level < 0.12 else 0.0
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(Palette.WOOD_DARK, 0.9)
		bg.border_color = Palette.OUTLINE.lerp(Palette.TEAM_WEST, pulse)
		bg.set_border_width_all(2)
		bg.set_corner_radius_all(6)
		draw_style_box(bg, r)
		var col := Color("#5FB8E8") if kind == &"water" else Color("#E8C04A")
		var c := size * 0.5
		var pts := PackedVector2Array()
		if kind == &"water":
			# A drop: a point on top, round at the bottom.
			pts.append(c + Vector2(0, -12))
			for i in 13:
				var a := PI * float(i) / 12.0
				pts.append(c + Vector2(cos(a) * 8.0, 4.0 + sin(a) * 8.0))
		else:
			# A corn cob: a tall rounded oval.
			for i in 20:
				var a := TAU * float(i) / 20.0
				pts.append(c + Vector2(cos(a) * 6.5, sin(a) * 12.0))
		# Paler the emptier it gets.
		draw_colored_polygon(pts, Color(col, lerpf(0.35, 1.0, clampf(level / PlayerVitals.NEED_LOW, 0.0, 1.0))))
		pts.append(pts[0])
		draw_polyline(pts, Palette.OUTLINE, 2.0)
		if kind == &"food":
			for k in 3:
				var x := c.x - 3.0 + 3.0 * float(k)
				draw_line(Vector2(x, c.y - 9.0), Vector2(x, c.y + 9.0), Color(Palette.OUTLINE, 0.5), 1.0)

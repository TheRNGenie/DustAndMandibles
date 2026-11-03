class_name HudStatus
extends Control
## Bottom-left: your health and your two currencies, scrap and chitin, as big
## counters (vegetables and water live on the hotbar). Top corners: both
## Homesteads' health, labelled "Yours" (left) and "Theirs" (right) for each player.

var cliff_id: int = 0
var _hp_bar: ProgressBar
var _smoke: Label
var _scrap: Label
var _chitin: Label
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
	panel.offset_bottom = -24
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	_hp_bar = _bar(Palette.TEAM_WEST, 100.0)
	col.add_child(_hp_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	_scrap = _counter(row, Palette.METAL.lightened(0.2), "SCRAP")
	_chitin = _counter(row, Palette.BEETLE_TEAL.lightened(0.15), "CHITIN")
	_smoke = UiStyle.label("", 13, Palette.BONE)
	_smoke.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_smoke.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_smoke.add_theme_constant_override("outline_size", 4)
	col.add_child(_smoke)

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
		var caption := UiStyle.label("", 16, Palette.BONE)
		caption.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		caption.add_theme_constant_override("outline_size", 6)
		box.add_child(caption)
		var bar := _bar(Palette.team_color(i), Defs.WAVE_CONFIG.homestead_hp)
		box.add_child(bar)
		_homes.append(bar)
		_captions.append(caption)

	_downed = UiStyle.label("", 34, Palette.TEAM_WEST)
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


func bind_player(player: Player) -> void:
	cliff_id = player.cliff_id
	_hp_bar.add_theme_stylebox_override("fill", _fill(Palette.team_color(cliff_id)))
	player.vitals.health_changed.connect(func(hp: float, mx: float) -> void:
		_hp_bar.max_value = mx
		_hp_bar.value = hp)
	if player.cigarette != null:
		player.cigarette.changed.connect(func(left: float) -> void:
			_smoke.text = ("SMOKING  %ds   (faster, sharper eyes)" % int(ceilf(left))) if left > 0.0 else "")
	player.vitals.needs_changed.connect(func(f: float, w: float) -> void:
		_food_icon.set_level(f)
		_water_icon.set_level(w))
	player.vitals.downed_changed.connect(func(is_down: bool, secs: float) -> void:
		_downed.text = "DOWNED - back on your feet in %d s" % int(ceilf(secs)) if is_down else "")
	_refresh_homes()
	_refresh_resources()


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
	# Maps: with the team's shared pool (CPU teammates) every cliff reads the
	# same stockpile, so show it once; on 3-4 cliff maps show your own.
	if GameState.is_solo() and not Economy.shared and WorldLayout.cliff_count() == 2:
		# Solo on the canyon builds on both cliffs, so show both stockpiles.
		_scrap.text = "%d / %d" % [Economy.amount(0, &"scrap"), Economy.amount(1, &"scrap")]
		_chitin.text = "%d / %d" % [Economy.amount(0, &"chitin"), Economy.amount(1, &"chitin")]
	else:
		_scrap.text = str(Economy.amount(cliff_id, &"scrap"))
		_chitin.text = str(Economy.amount(cliff_id, &"chitin"))


## A breaching bug stole from a stockpile: a red "-N" rises off the counter and fades.
func _on_stolen(cid: int, amounts: Dictionary) -> void:
	if cid != cliff_id and not GameState.is_solo():
		return
	var counters := {&"scrap": _scrap, &"chitin": _chitin}
	for r: StringName in amounts:
		var counter := counters.get(r) as Label
		if counter == null:
			continue
		var l := UiStyle.label("-%d" % int(amounts[r]), 20, Palette.TEAM_WEST.lightened(0.15))
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


## A coloured chip, a small caption and a big number.
func _counter(parent: HBoxContainer, color: Color, caption: String) -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(18, 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Palette.OUTLINE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	chip.add_theme_stylebox_override("panel", sb)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(chip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	box.add_child(v)
	var cap := UiStyle.label(caption, 11, Palette.BONE.darkened(0.2))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(cap)
	var num := UiStyle.label("0", 24, Palette.BONE)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	num.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(num)
	return num


static func _fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(3)
	return sb


func _bar(color: Color, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(240, 18)
	bar.max_value = max_value
	bar.value = max_value
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Palette.OUTLINE
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", _fill(color))
	return bar


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

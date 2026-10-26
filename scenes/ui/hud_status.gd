class_name HudStatus
extends Control
## Bottom-left: your health and your two currencies, scrap and chitin, as big
## counters (vegetables and water live on the hotbar). Top corners: both
## Homesteads' health, labelled "Yours" (left) and "Theirs" (right) for each player.

var cliff_id: int = 0
var _hp_bar: ProgressBar
var _scrap: Label
var _chitin: Label
var _homes: Array[ProgressBar] = []
var _captions: Array[Label] = []
var _downed: Label


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

	for i in 2:
		var box := VBoxContainer.new()
		box.anchor_left = 0.0 if i == 0 else 1.0
		box.anchor_right = box.anchor_left
		box.offset_left = 24.0 if i == 0 else -284.0
		box.offset_right = box.offset_left + 260.0
		box.offset_top = 16
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
	GameState.homestead_changed.connect(func(_c: int, _hp: float, _mx: float) -> void: _refresh_homes())
	_refresh_homes()
	_refresh_resources()


func bind_player(player: Player) -> void:
	cliff_id = player.cliff_id
	_hp_bar.add_theme_stylebox_override("fill", _fill(Palette.team_color(cliff_id)))
	player.vitals.health_changed.connect(func(hp: float, mx: float) -> void:
		_hp_bar.max_value = mx
		_hp_bar.value = hp)
	player.vitals.downed_changed.connect(func(is_down: bool, secs: float) -> void:
		_downed.text = "DOWNED - back on your feet in %d s" % int(ceilf(secs)) if is_down else "")
	_refresh_homes()
	_refresh_resources()


## Left bar = your Homestead, right bar = your partner's.
func _refresh_homes() -> void:
	var order: Array[int] = [cliff_id, WorldLayout.other_cliff(cliff_id)]
	for i in 2:
		var cid := order[i]
		_captions[i].text = "Yours" if i == 0 else "Theirs"
		_homes[i].max_value = maxf(GameState.homestead_max[cid], 1.0)
		_homes[i].value = GameState.homestead_hp[cid]
		_homes[i].add_theme_stylebox_override("fill", _fill(Palette.team_color(cid)))


func _refresh_resources() -> void:
	if GameState.is_solo():
		# Solo builds on both cliffs, so show both stockpiles.
		_scrap.text = "%d / %d" % [Economy.amount(0, &"scrap"), Economy.amount(1, &"scrap")]
		_chitin.text = "%d / %d" % [Economy.amount(0, &"chitin"), Economy.amount(1, &"chitin")]
	else:
		_scrap.text = str(Economy.amount(cliff_id, &"scrap"))
		_chitin.text = str(Economy.amount(cliff_id, &"chitin"))


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

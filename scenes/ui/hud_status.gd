class_name HudStatus
extends Control
## Bottom-left: your health and resources. Top corners: both Homesteads' health,
## so each player always sees how their partner is doing.

var cliff_id: int = 0
var _hp_bar: ProgressBar
var _resources: Label
var _hunger_bar: ProgressBar
var _thirst_bar: ProgressBar
var _homes: Array[ProgressBar] = []
var _downed: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.wood_sign())
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24
	panel.offset_top = -170
	panel.offset_right = 420
	panel.offset_bottom = -24
	add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	_hp_bar = _bar(Palette.TEAM_WEST, 100.0)
	col.add_child(_hp_bar)
	var needs := HBoxContainer.new()
	needs.add_theme_constant_override("separation", 8)
	col.add_child(needs)
	_hunger_bar = _bar(Palette.SAND.darkened(0.1), 100.0)
	_hunger_bar.custom_minimum_size = Vector2(150, 10)
	_thirst_bar = _bar(Palette.SKY_TOP, 100.0)
	_thirst_bar.custom_minimum_size = Vector2(150, 10)
	for pair: Array in [["Food", _hunger_bar], ["Water", _thirst_bar]]:
		var cap := UiStyle.label(str(pair[0]), 13, Palette.BONE)
		cap.autowrap_mode = TextServer.AUTOWRAP_OFF
		needs.add_child(cap)
		needs.add_child(pair[1] as ProgressBar)
	_resources = UiStyle.label("", 20, Palette.BONE)
	_resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_resources)

	for cid in 2:
		var box := VBoxContainer.new()
		box.anchor_left = 0.0 if cid == WorldLayout.WEST else 1.0
		box.anchor_right = box.anchor_left
		box.offset_left = 24.0 if cid == WorldLayout.WEST else -284.0
		box.offset_right = box.offset_left + 260.0
		box.offset_top = 16
		add_child(box)
		var caption := UiStyle.label("West Homestead" if cid == WorldLayout.WEST else "East Homestead", 16, Palette.BONE)
		caption.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		caption.add_theme_constant_override("outline_size", 6)
		box.add_child(caption)
		var bar := _bar(Palette.team_color(cid), Defs.WAVE_CONFIG.homestead_hp)
		box.add_child(bar)
		_homes.append(bar)

	_downed = UiStyle.label("", 34, Palette.TEAM_WEST)
	_downed.set_anchors_preset(Control.PRESET_CENTER)
	_downed.offset_left = -400
	_downed.offset_right = 400
	_downed.offset_top = -120
	_downed.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_downed.add_theme_constant_override("outline_size", 10)
	add_child(_downed)

	Economy.resources_changed.connect(func(_c: int) -> void: _refresh_resources())
	GameState.homestead_changed.connect(func(c: int, hp: float, mx: float) -> void:
		_homes[c].max_value = mx
		_homes[c].value = hp)
	for c in 2:
		_homes[c].value = GameState.homestead_hp[c]
	_refresh_resources()


func bind_player(player: Player) -> void:
	cliff_id = player.cliff_id
	_hp_bar.add_theme_stylebox_override("fill", _fill(Palette.team_color(cliff_id)))
	player.vitals.health_changed.connect(func(hp: float, mx: float) -> void:
		_hp_bar.max_value = mx
		_hp_bar.value = hp)
	player.vitals.needs_changed.connect(func(h: float, t: float) -> void:
		_hunger_bar.value = h
		_thirst_bar.value = t)
	player.vitals.downed_changed.connect(func(is_down: bool, secs: float) -> void:
		_downed.text = "DOWNED - back on your feet in %d s" % int(ceilf(secs)) if is_down else "")
	_refresh_resources()


func _refresh_resources() -> void:
	if GameState.is_solo():
		_resources.text = "West  %s\nEast  %s" % [_line(0), _line(1)]
	else:
		_resources.text = _line(cliff_id)
	_resources.add_theme_font_size_override("font_size", 16)


static func _line(cid: int) -> String:
	return "Scrap %d  Chitin %d  Water %d  Food %d  Chili %d" % [Economy.amount(cid, &"scrap"),
			Economy.amount(cid, &"chitin"), Economy.amount(cid, &"water"), Economy.amount(cid, &"food"),
			Economy.amount(cid, &"chili")]


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

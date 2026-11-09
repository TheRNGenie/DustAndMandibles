class_name HudWaveSummary
extends PanelContainer
## After each wave, under the "WAVE N HELD" ribbon: what did the killing (top
## guns by kills) and how much each of you saved the other. Teaches which
## turrets earn their keep. Fades after a few seconds.

const SHOW_FOR := 9.0
const TOP := 5

var cliff_id := 0
var _by_source: Dictionary = {}
var _saved_by_me := 0
var _saved_by_them := 0
var _total := 0
var _tween: Tween


func _ready() -> void:
	add_theme_stylebox_override("panel", KeyHints.kit_box("plate"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.3
	anchor_bottom = 0.3
	offset_top = 188 # under the title card's plate (it shows while that holds)
	visible = false
	GameState.phase_changed.connect(_on_phase)
	if GameState.has_flag("--summarytest"): # debug: the demo tally a few seconds in (with --shot)
		get_tree().create_timer(3.0).timeout.connect(demo)


func bind(bugs: BugManager, my_cliff: int) -> void:
	cliff_id = my_cliff
	bugs.bug_killed.connect(_on_killed)


func _on_killed(_bug: String, bug_cliff: int, source: String, source_cliff: int, _loot: Dictionary) -> void:
	if source_cliff == -2 or GameState.phase != GameState.Phase.WAVE:
		return
	_total += 1
	var key := source if source != "" else "Other"
	# Crop-fed turrets: a row per crop it used (Logan), "<source>|<crop>".
	var crop := StringName(_loot.get(&"crop", &""))
	if crop != &"":
		key += "|" + String(crop)
	_by_source[key] = int(_by_source.get(key, 0)) + 1
	if source_cliff >= 0 and source_cliff != bug_cliff:
		if source_cliff == cliff_id:
			_saved_by_me += 1
		else:
			_saved_by_them += 1


func _on_phase(p: GameState.Phase) -> void:
	if p == GameState.Phase.WAVE:
		_by_source.clear()
		_saved_by_me = 0
		_saved_by_them = 0
		_total = 0
	elif p == GameState.Phase.BUILD and _total > 0:
		_show()


func _show() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiStyle.GAP_ROW)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	# TOP GUNS ......................... 235 BUGS DOWN
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var title := KeyHints.eyebrow("Top Guns", 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var total := KeyHints.number(str(_total), 18)
	head.add_child(total)
	var down := KeyHints.eyebrow(" Bugs Down", 13)
	down.theme_type_variation = "SoftInkLabel"
	down.add_theme_font_override("font", UiStyle.font("label"))
	down.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(down)
	var names := _by_source.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return int(_by_source[a]) > int(_by_source[b]))
	var best := maxi(int(_by_source[names[0]]) if not names.is_empty() else 1, 1)
	for i in mini(names.size(), TOP):
		var n: String = names[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lead := UiStyle.c("accent_hi") if i == 0 else UiStyle.c("ink")
		var rank := KeyHints.number(str(i + 1), 16)
		rank.theme_type_variation = "SoftInkLabel"
		rank.add_theme_font_override("font", UiStyle.font("number"))
		rank.custom_minimum_size.x = 14
		row.add_child(rank)
		# The name, and right beside it the crop it fired (a row per crop when it
		# used several), in a fixed-width column so the bars line up.
		var crop := StringName(n.get_slice("|", 1)) if n.contains("|") else &""
		var who := HBoxContainer.new()
		who.add_theme_constant_override("separation", 6)
		who.mouse_filter = Control.MOUSE_FILTER_IGNORE
		who.custom_minimum_size.x = 220
		var l := KeyHints.ink(UiStyle.tc(n.get_slice("|", 0)), 16)
		l.add_theme_font_override("font", UiStyle.font("bold"))
		if i == 0:
			l.add_theme_color_override("font_color", lead)
		who.add_child(l)
		if crop != &"":
			who.add_child(crop_icon(crop, 24))
		row.add_child(who)
		# The shared bar, scaled to the best gun.
		var bar := UiStyle.bar(UiStyle.c("accent") if i == 0 else UiStyle.c("ink_soft"), Vector2(180, 12), best)
		bar.value = int(_by_source[n])
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var num := KeyHints.number(str(_by_source[n]), 18)
		num.custom_minimum_size.x = 40
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(num)
		col.add_child(row)
	if _saved_by_me + _saved_by_them > 0:
		var rule := ColorRect.new()
		rule.color = Color(UiStyle.c("accent"), 0.25)
		rule.custom_minimum_size = Vector2(0, 1)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(rule)
		# Cross-cover, as two figures side by side.
		var saves := HBoxContainer.new()
		saves.add_theme_constant_override("separation", UiStyle.GAP_GROUP)
		saves.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(saves)
		for pair: Array in [["Your Turrets Saved Your Partner", _saved_by_me], ["Theirs Saved You", _saved_by_them]]:
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", -4)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(KeyHints.eyebrow(str(pair[0]), 12))
			v.add_child(KeyHints.number("%d Times" % int(pair[1]) if int(pair[1]) != 1 else "Once", 22))
			saves.add_child(v)
	visible = true
	modulate.a = 0.0
	(func() -> void:
		var sz := get_combined_minimum_size()
		offset_left = -sz.x * 0.5
		offset_right = sz.x * 0.5).call_deferred()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(0.4)
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	_tween.tween_interval(SHOW_FOR)
	_tween.tween_property(self, "modulate:a", 0.0, 0.8)
	_tween.tween_callback(func() -> void: visible = false)


## A crop's round badge at `px` (the kill tallies and the turret card).
static func crop_icon(crop: StringName, px: int) -> Control:
	return CropChip.make(crop, px)


## For the debug view: fake a wave's tally and show it.
func demo() -> void:
	_by_source = {"Gatling Post": 132, "Crop Hopper|corn": 77, "Buffalo Rifle Nest": 61, "Crop Hopper|cotton": 30,
		"Harvest Mortar|sulfur_root": 24, "Your revolver": 18}
	_saved_by_me = 190
	_saved_by_them = 151
	_total = 235
	_show()

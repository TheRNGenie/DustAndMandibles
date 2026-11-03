class_name HudWaveSummary
extends PanelContainer
## After each wave, under the "WAVE N HELD" ribbon: what did the killing (top
## guns by kills) and how much each of you saved the other. Teaches which
## turrets earn their keep. Fades after a few seconds.

const SHOW_FOR := 9.0
const TOP := 4

var cliff_id := 0
var _by_source: Dictionary = {}
var _saved_by_me := 0
var _saved_by_them := 0
var _total := 0
var _tween: Tween


func _ready() -> void:
	add_theme_stylebox_override("panel", KeyHints.card_style())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.3
	anchor_bottom = 0.3
	offset_top = 152
	visible = false
	GameState.phase_changed.connect(_on_phase)


func bind(bugs: BugManager, my_cliff: int) -> void:
	cliff_id = my_cliff
	bugs.bug_killed.connect(_on_killed)


func _on_killed(_bug: String, bug_cliff: int, source: String, source_cliff: int, _loot: Dictionary) -> void:
	if source_cliff == -2 or GameState.phase != GameState.Phase.WAVE:
		return
	_total += 1
	var key := source if source != "" else "Other"
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
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head := KeyHints.text("Top Guns  ·  %d Bugs Down" % _total, 14, UiStyle.c("hud").darkened(0.2))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var names := _by_source.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return int(_by_source[a]) > int(_by_source[b]))
	var best := maxi(int(_by_source[names[0]]) if not names.is_empty() else 1, 1)
	for i in mini(names.size(), TOP):
		var n: String = names[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lead := UiStyle.c("title") if i == 0 else UiStyle.c("hud")
		var l := KeyHints.text(UiStyle.tc(n), 16, lead)
		l.custom_minimum_size.x = 200
		row.add_child(l)
		# The shared bar, scaled to the best gun.
		var bar := UiStyle.bar(lead, Vector2(160, 10), best)
		bar.value = int(_by_source[n])
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var num := KeyHints.text(str(_by_source[n]), 16, UiStyle.c("hud"))
		num.custom_minimum_size.x = 36
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(num)
		col.add_child(row)
	if _saved_by_me + _saved_by_them > 0:
		var s := KeyHints.text("Your Turrets Saved Your Partner %d Times  ·  Theirs Saved You %d" % [_saved_by_me, _saved_by_them], 14, UiStyle.c("hud").darkened(0.15))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(s)
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


## For the debug view: fake a wave's tally and show it.
func demo() -> void:
	_by_source = {"Gatling Post": 132, "Buffalo Rifle Nest": 61, "Your revolver": 24, "Chili Mortar": 18}
	_saved_by_me = 190
	_saved_by_them = 151
	_total = 235
	_show()

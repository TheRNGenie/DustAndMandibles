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
	var head := KeyHints.text("TOP GUNS  ·  %d bugs down" % _total, 13, Palette.BONE.darkened(0.25))
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
		var l := KeyHints.text(n, 16, Palette.GLOW_YELLOW if i == 0 else Palette.BONE)
		l.custom_minimum_size.x = 200
		row.add_child(l)
		# A little bar for each, scaled to the best.
		var bar := ColorRect.new()
		bar.color = Color(Palette.GLOW_YELLOW if i == 0 else Palette.BONE, 0.8)
		bar.custom_minimum_size = Vector2(160.0 * float(_by_source[n]) / best, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		row.add_child(KeyHints.text(str(_by_source[n]), 16, Palette.BONE))
		col.add_child(row)
	if _saved_by_me + _saved_by_them > 0:
		var s := KeyHints.text("Your turrets saved your partner %d times  ·  theirs saved you %d" % [_saved_by_me, _saved_by_them], 14, Palette.ROCK_C.lightened(0.35))
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

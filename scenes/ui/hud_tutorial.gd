class_name HudTutorial
extends PanelContainer
## First-day hints. On wave 1's build phase only, a small card on the left walks
## you through the loop one step at a time: open the build menu, place a turret,
## ping your partner, ready up. Each step ticks off as you do it (in any order),
## and once the first wave's build phase ends it never shows again (saved as
## Settings.tutorial_done). --tutorial forces it on; other --debug runs skip it.

const STEPS := [
	{"title": "Build a turret", "body": "Turrets on your lip shoot across the canyon.",
		"keys": [["build_menu", "Build menu"]]},
	{"title": "Place it on your plateau", "body": "Near the edge, facing the canyon. Green means it fits.",
		"keys": [["fire", "Place"], ["alt_fire", "Cancel"]]},
	{"title": "Ping your partner", "body": "Tap to mark a spot, hold for the ping wheel.",
		"keys": [["ping", "Ping"]]},
	{"title": "Throw your lever", "body": "The big breaker lever at your generator is your ready-up. Every lever thrown: the pumps start and the wave comes.",
		"keys": [["interact", "Throw lever"]]},
]

var player: Player
var _done: Array[bool] = [false, false, false, false]
var _shown := -2
var _turrets_at_start := -1
var _forced := false


func _ready() -> void:
	add_theme_stylebox_override("panel", KeyHints.kit_box("plate"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_top = 0.3
	anchor_bottom = 0.3
	offset_left = 24
	custom_minimum_size.x = 300
	visible = false
	_forced = GameState.has_flag("--tutorial")


func _active() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if GameState.tutorial: # the full tutorial (TutorialRun) teaches all of this
		return false
	if Settings.tutorial_done and not _forced:
		return false
	if GameState.has_flag("--debug") and not _forced:
		return false
	return GameState.wave == 1 and GameState.phase == GameState.Phase.BUILD


func _process(_delta: float) -> void:
	if not _active():
		if _shown >= 0 and GameState.wave >= 1 and GameState.phase != GameState.Phase.BUILD:
			_finish()
		visible = false
		return
	var turrets := get_tree().get_nodes_in_group("turrets").size()
	if _turrets_at_start < 0:
		_turrets_at_start = turrets
	var bm := player.build_mode
	if bm != null and (bm.active or bm.menu_open):
		_done[0] = true
	if turrets > _turrets_at_start:
		_done[0] = true
		_done[1] = true
	if Input.is_action_just_pressed("ping"):
		_done[2] = true
	if GameState.is_ready_local():
		_done[3] = true
	var step := _done.find(false)
	if step < 0:
		_finish()
		visible = false
		return
	if step != _shown:
		if _shown >= 0:
			Audio.play_ui(&"wheel_tick", -6.0)
		_shown = step
		_rebuild(step)
	visible = true


func _finish() -> void:
	_shown = -1
	if not Settings.tutorial_done and not _forced:
		Settings.set_value("tutorial_done", true)


func _rebuild(step: int) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var s: Dictionary = STEPS[step]
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var tag := KeyHints.eyebrow("First Day", 13)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tag)
	head.add_child(_pips(step))
	var title := KeyHints.ink(str(s["title"]), 18)
	title.add_theme_font_override("font", UiStyle.font("bold"))
	col.add_child(title)
	var body := KeyHints.ink(str(s["body"]), 15, true)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 300
	col.add_child(body)
	var pairs: Array = []
	for k: Array in s["keys"]:
		pairs.append([KeyHints.key_for(str(k[0])), str(k[1])])
	var keys := KeyHints.row(pairs)
	keys.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_child(keys)
	# A small slide-in so a new step catches the eye.
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)


## Progress dots: filled for steps done, ringed for the current one.
func _pips(step: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in STEPS.size():
		var dot := Pip.new()
		dot.state = 2 if _done[i] else (1 if i == step else 0)
		row.add_child(dot)
	return row


class Pip extends Control:
	var state := 0 # 0 to do, 1 current, 2 done

	func _init() -> void:
		custom_minimum_size = Vector2(10, 10)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 5.0, Palette.OUTLINE)
		if state == 2:
			draw_circle(c, 3.5, UiStyle.c("accent_hi"))
		elif state == 1:
			draw_circle(c, 3.5, UiStyle.c("ink"))
		else:
			draw_circle(c, 3.5, UiStyle.c("faint"))

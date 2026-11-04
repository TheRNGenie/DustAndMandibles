class_name TutorialCard
extends Control
## The tutorial's face on the HUD (TutorialRun drives it): one short card on
## the right (step count and progress pips, a title, a line or two, the sub-tasks
## with status marks that tick off, the keys to use), a marker on the thing to
## look at (a bobbing pointer with a caption chip, or an arrow at the screen edge
## when it's behind you), and at the end the "You're Ready" card with Back to
## Menu / Keep Playing. Keys come from the live input map (KeyHints); Enter or a
## controller's A carries on, and the prompt shows whichever you used last.

const WIDTH := 340.0

var run: TutorialRun
var _card: PanelContainer
var _col: VBoxContainer
var _tasks_box: VBoxContainer
var _skip_row: Control
var _pips: HBoxContainer
var _head_mark: Control
var _chip: PanelContainer
var _chip_label: Label
var _marker: Variant = null
var _bob := 0.0
var _finish: Control
var _step := 0
var _total := 1
var _def: Dictionary = {}
var _words: Array = []
var _done: Array[bool] = []
## The last input was a controller (prompts show its buttons).
static var pad := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", KeyHints.card_style())
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (Right and bottom first: an anchor can't pass its opposite one.)
	_card.set_anchor_and_offset(SIDE_RIGHT, 1.0, -24.0)
	_card.set_anchor_and_offset(SIDE_LEFT, 1.0, -24.0 - WIDTH)
	_card.set_anchor_and_offset(SIDE_BOTTOM, 0.34, 0.0)
	_card.set_anchor_and_offset(SIDE_TOP, 0.34, 0.0)
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.visible = false
	add_child(_card)
	_chip = PanelContainer.new()
	_chip.add_theme_stylebox_override("panel", UiStyle.chip_flat())
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.visible = false
	_chip_label = UiStyle.strap_text("", 14)
	_chip.add_child(_chip_label)
	add_child(_chip)
	UiStyle.notifier.changed.connect(_restyle)


func _restyle() -> void:
	if _card == null:
		return
	_card.add_theme_stylebox_override("panel", KeyHints.card_style())
	_chip.add_theme_stylebox_override("panel", UiStyle.chip_flat())
	if _card.visible:
		_rebuild()


func _input(event: InputEvent) -> void:
	var was := pad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	if was != pad and _card.visible:
		_rebuild()
	if _finish != null or GameState.menu_open:
		return
	var accept := false
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		accept = k == KEY_ENTER or k == KEY_KP_ENTER
	elif event is InputEventJoypadButton and event.pressed:
		accept = (event as InputEventJoypadButton).button_index == JOY_BUTTON_A
	if accept and run != null:
		run.accept_pressed()
		get_viewport().set_input_as_handled()


## A new step's card.
func show_step(index: int, total: int, def: Dictionary, words: Array) -> void:
	_step = index
	_total = total
	_def = def
	_words = words.duplicate()
	_done.clear()
	for w in _words:
		_done.append(false)
	_rebuild()
	_card.visible = true
	_card.offset_bottom = _card.offset_top # shrink to the new card's height
	# A short fade so a new step catches the eye.
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.25)


func set_tasks(done: Array[bool]) -> void:
	var changed := false
	for i in mini(done.size(), _done.size()):
		if done[i] and not _done[i]:
			changed = true
		_done[i] = done[i]
	if changed:
		Audio.play_ui(&"wheel_tick", -6.0)
	_fill_tasks()


## Live wording of one sub-task ("Dust Mites Shot: 2 / 3").
func set_task_text(i: int, text: String) -> void:
	if i < _words.size() and _words[i] != text:
		_words[i] = text
		_fill_tasks()


## Every task ticked: the head gets its tick too and the card glows a moment.
func tick() -> void:
	for i in _done.size():
		_done[i] = true
	_fill_tasks()
	_head_mark.visible = true
	_refresh_pips(true)
	var tw := create_tween()
	tw.tween_property(_card, "modulate", Color(1.25, 1.2, 1.0), 0.12)
	tw.tween_property(_card, "modulate", Color.WHITE, 0.35)


func show_skip(on: bool) -> void:
	if _skip_row != null and _skip_row.visible != on:
		_skip_row.visible = on


func set_marker(pos: Variant, caption: String) -> void:
	_marker = pos
	if _chip_label.text != caption:
		_chip_label.text = caption


func _rebuild() -> void:
	for c in _card.get_children():
		_card.remove_child(c)
		c.queue_free()
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 6)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_col)
	# A painted vignette across the top of the card (assets/story_art/tips.jpg).
	if ResourceLoader.exists("res://assets/story_art/tips.jpg"):
		var art := TextureRect.new()
		art.texture = load("res://assets/story_art/tips.jpg")
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size = Vector2(0, 90)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_col.add_child(art)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(head)
	var tag := KeyHints.text("Tutorial  ·  Step %d of %d" % [_step + 1, _total], 12, UiStyle.c("gold"))
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tag)
	_pips = HBoxContainer.new()
	_pips.add_theme_constant_override("separation", 4)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_pips)
	_refresh_pips(not _done.is_empty() and not _done.has(false))
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(title_row)
	var title := KeyHints.text(str(_def.get("title", "")), 18, UiStyle.c("hud"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size.x = 1
	title_row.add_child(title)
	_head_mark = UiStyle.mark("good", UiStyle.hud_c("good"), UiStyle.ts(18))
	_head_mark.visible = not _done.is_empty() and not _done.has(false)
	title_row.add_child(_head_mark)
	var body := KeyHints.text(str(_def.get("body", "")), 14, UiStyle.c("hud").darkened(0.12))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = WIDTH - 32.0
	_col.add_child(body)
	_tasks_box = VBoxContainer.new()
	_tasks_box.add_theme_constant_override("separation", 3)
	_tasks_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_tasks_box)
	_fill_tasks()
	# The keys, two to a row (rows of plain boxes keep the card's size steady).
	var pairs: Array = _def.get("keys", [])
	for i in range(0, pairs.size(), 2):
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 14)
		keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k: Array in pairs.slice(i, i + 2):
			keys.add_child(KeyHints.hint(_key(str(k[0])), str(k[1])))
		_col.add_child(keys)
	_skip_row = KeyHints.hint(_key("accept"), "Skip This Step", UiStyle.c("hud").darkened(0.3))
	_skip_row.visible = false
	_col.add_child(_skip_row)


func _fill_tasks() -> void:
	if _tasks_box == null:
		return
	for c in _tasks_box.get_children():
		_tasks_box.remove_child(c)
		c.queue_free()
	for i in _words.size():
		var ok := i < _done.size() and _done[i]
		_tasks_box.add_child(UiStyle.status(str(_words[i]), "good" if ok else "info", 14, true))


## Progress pips: filled for steps done, ringed for this one.
func _refresh_pips(this_done: bool) -> void:
	if _pips == null:
		return
	for c in _pips.get_children():
		c.queue_free()
	for i in _total:
		var dot := HudTutorial.Pip.new()
		dot.state = 2 if i < _step or (i == _step and this_done) else (1 if i == _step else 0)
		_pips.add_child(dot)


## The key or button for an action: the live keyboard binding, or the
## controller's A for "accept" when a pad was used last.
static func _key(action: String) -> String:
	match action:
		"accept":
			return "A" if pad else "Enter"
		"move":
			return "%s %s %s %s" % [KeyHints.key_for("move_forward"), KeyHints.key_for("move_left"),
					KeyHints.key_for("move_back"), KeyHints.key_for("move_right")]
	return KeyHints.key_for(action)


# ------------------------------------------------------------------ the marker

func _process(delta: float) -> void:
	_bob += delta
	_place_marker()
	queue_redraw()


## Works out where the marker goes this frame (on the spot, or an arrow on the
## screen edge) and moves its caption chip there.
var _on_spot := false
var _spot := Vector2.ZERO
var _dir := Vector2.ZERO
var _shown := false


func _place_marker() -> void:
	_shown = false
	var cam := get_viewport().get_camera_3d()
	if _marker == null or _finish != null or not _card.visible or cam == null:
		_chip.visible = false
		return
	_shown = true
	var pos := _marker as Vector3
	var vs := get_viewport_rect().size
	var behind := cam.is_position_behind(pos)
	var s := cam.unproject_position(pos)
	# The edge arrows keep clear of the phase plaque (top) and the hotbar (bottom).
	var area := Rect2(Vector2(60, 110), vs - Vector2(120, 260))
	_on_spot = not behind and area.has_point(s)
	_chip.visible = _chip_label.text != ""
	_chip.reset_size()
	if _on_spot:
		_spot = s
		_chip.position = Vector2(s.x - _chip.size.x * 0.5, s.y + 18.0)
		return
	# Off screen or behind you: an arrow on the edge, pointing the way to turn.
	var c := area.get_center()
	var dir := s - c
	if behind:
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2(0, 1)
	_dir = dir.normalized()
	var half := area.size * 0.5
	var k := minf(half.x / maxf(absf(_dir.x), 0.001), half.y / maxf(absf(_dir.y), 0.001))
	_spot = c + _dir * k
	var cp := _spot - _dir * 40.0 - _chip.size * 0.5
	_chip.position = cp.clamp(Vector2(8, 8), vs - _chip.size - Vector2(8, 8))


func _draw() -> void:
	if not _shown:
		return
	var gold := UiStyle.c("gold")
	var ink := Palette.OUTLINE
	if _on_spot:
		# A pointer bobbing over the spot and a ring on it.
		var tip := _spot - Vector2(0, 26.0 + sin(_bob * 4.0) * 5.0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 3), tip + Vector2(-16, -22), tip + Vector2(16, -22)]), ink)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-13, -20), tip + Vector2(13, -20)]), gold)
		draw_arc(_spot, 11.0, 0.0, TAU, 32, ink, 5.0, true)
		draw_arc(_spot, 11.0, 0.0, TAU, 32, gold, 2.5, true)
		return
	var at := _spot
	var o := _dir.orthogonal()
	var p0 := at + _dir * (18.0 + sin(_bob * 5.0) * 4.0)
	draw_colored_polygon(PackedVector2Array([p0 + _dir * 3.0, at - _dir * 4.0 + o * 15.0, at - _dir * 4.0 - o * 15.0]), ink)
	draw_colored_polygon(PackedVector2Array([p0, at + o * 11.0, at - o * 11.0]), gold)


# ------------------------------------------------------------------ the finish

## "You're Ready": the last card, with Back to Menu and Keep Playing.
func show_finish() -> void:
	_card.visible = false
	_chip.visible = false
	_marker = null
	GameState.menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_finish = Control.new()
	_finish.name = "Finish"
	add_child(_finish)
	UiStyle.fit(_finish)
	_finish.add_child(UiStyle.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_finish.add_child(center)
	var frame := UiStyle.panel("FramePanel")
	frame.custom_minimum_size.x = 560
	center.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	frame.add_child(outer)
	outer.add_child(UiStyle.strap("You're Ready", "Tutorial Complete", 40))
	var paper := UiStyle.panel("PaperPanel")
	outer.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiStyle.GAP_GROUP)
	paper.add_child(col)
	col.add_child(UiStyle.note("That's the loop. Each day: build, farm, throw your lever. Each night: hold the wave together.", 16))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	for line: String in ["Your Turrets Fire Across the Canyon", "Your Lever Starts the Pumps and the Wave",
			"Water From the Well and Tower Grows Food", "Guns and Seeds Up on the Airship", "Crafted Turrets From the Workshop"]:
		list.add_child(UiStyle.status(line, "good", 15))
	col.add_child(list)
	col.add_child(UiStyle.divider(420))
	col.add_child(UiStyle.note("Host a game from the main menu and send your invite code to a partner. Keep Playing carries on with practice waves; nothing here is saved.", 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiStyle.GAP_ROW)
	col.add_child(row)
	var menu_btn := UiStyle.button("Back to Menu")
	var keep_btn := UiStyle.button("Keep Playing")
	for b: Button in [menu_btn, keep_btn]:
		b.custom_minimum_size.y = 46
		b.focus_mode = Control.FOCUS_ALL # arrows and a controller's d-pad move between them
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	menu_btn.pressed.connect(func() -> void:
		if run != null:
			run.to_menu())
	keep_btn.pressed.connect(_keep_playing)
	menu_btn.focus_neighbor_right = keep_btn.get_path()
	keep_btn.focus_neighbor_left = menu_btn.get_path()
	UiStyle.fade_in(_finish)
	menu_btn.grab_focus.call_deferred()


func _keep_playing() -> void:
	if _finish != null:
		_finish.queue_free()
		_finish = null
	GameState.menu_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if run != null:
		run.keep_playing()

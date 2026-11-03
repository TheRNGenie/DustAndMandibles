class_name StoryScreen
extends CanvasLayer
## Main menu > Story: the chapters of the Dry Gulch story on the left (won,
## new, locked, or still to come), the picked chapter's page on the right
## (map, waves, goal, what it pays) with Ride Out, and Doc Whitlow's Journal:
## the pages chapters have paid so far. Ride Out hosts the chapter (main menu).

signal ride(chapter_id: String)

var _root: Control
var _list: VBoxContainer
var _page: VBoxContainer
var _picked := ""
var _journal := false
var _journal_btn: Button


func _ready() -> void:
	layer = 66
	_build()
	_root.visible = false


func is_open() -> bool:
	return UiStyle.shown(_root)


func open() -> void:
	_picked = Story.progress.next_up() if _picked == "" else _picked
	_journal = GameState.has_flag("--openjournal")
	_fill()
	_root.visible = true
	UiStyle.fade_in(_root)


func close() -> void:
	UiStyle.fade_out(_root)


func _input(event: InputEvent) -> void:
	if UiStyle.shown(_root) and event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.fit(_root)
	add_child(_root)
	_root.add_child(UiStyle.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := PanelContainer.new()
	box.theme_type_variation = "FramePanel"
	box.custom_minimum_size = Vector2(1180, 700)
	center.add_child(box)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	box.add_child(outer)
	outer.add_child(UiStyle.strap("The Dry Gulch Story", "1889. A railroad tunnel broke into the Hive. Somebody has to hold the cliffs.", 30))
	var card := PanelContainer.new()
	card.theme_type_variation = "PaperPanel"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiStyle.GAP_GROUP)
	card.add_child(col)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.custom_minimum_size.x = 470
	body.add_child(_list)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 10)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_page)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiStyle.GAP_ROW)
	col.add_child(row)
	var hints := UiStyle.paper_hints([["Esc", "Close"]])
	hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hints)
	_journal_btn = MenuScreen.wood_button("Doc Whitlow's Journal")
	_journal_btn.pressed.connect(func() -> void:
		_journal = not _journal
		_fill())
	row.add_child(_journal_btn)
	var close_b := MenuScreen.wood_button("Close")
	close_b.pressed.connect(close)
	row.add_child(close_b)


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	for c in _page.get_children():
		c.queue_free()
	_journal_btn.text = "Back to Chapters" if _journal else "Doc Whitlow's Journal"
	for ch in StoryChapter.all():
		_list.add_child(_chapter_row(ch.id, ch.number, ch.title, _state_of(ch.id)))
	for p: Array in StoryChapter.PLANNED:
		_list.add_child(_chapter_row("", int(p[0]), str(p[1]), "later"))
	if _journal:
		_fill_journal()
	else:
		_fill_page(StoryChapter.load_id(_picked))


func _state_of(cid: String) -> String:
	if Story.progress.is_done(cid):
		return "done"
	if not Story.is_unlocked(cid):
		return "locked"
	return "open"


func _chapter_row(cid: String, n: int, title: String, state: String) -> Control:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = cid != "" and cid == _picked and not _journal
	b.custom_minimum_size = Vector2(0, 52)
	b.disabled = state == "later"
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", UiStyle.ts(18))
	b.text = "  %d.  %s" % [n, title]
	b.pressed.connect(func() -> void:
		if cid == "":
			return
		_picked = cid
		_journal = false
		_fill())
	var chip_text: String = {"done": "Complete", "open": "New" if not Story.progress.tried.has(cid) else "Unfinished",
			"locked": "Locked", "later": "Coming Later"}.get(state, "")
	var kind: String = {"done": "good", "open": "warn", "locked": "lock", "later": "lock"}.get(state, "info")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	var chip := UiStyle.status(chip_text, kind, 14)
	chip.custom_minimum_size.x = 128
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(chip)
	return row


func _fill_page(ch: StoryChapter) -> void:
	if ch == null:
		return
	var state := _state_of(ch.id)
	_page.add_child(UiStyle.title("Chapter %d: %s" % [ch.number, ch.title], 34))
	var meta := UiStyle.label("%s  ·  Waves %d to %d  ·  Solo or 2-4 Riders" % [MapDef.display_name_of(ch.map), ch.first_wave, ch.last_wave], 16)
	meta.theme_type_variation = "SoftInkLabel"
	_page.add_child(meta)
	_page.add_child(UiStyle.divider(520))
	var blurb := UiStyle.label(ch.blurb, 18)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	blurb.custom_minimum_size.x = 560
	_page.add_child(blurb)
	_page.add_child(_fact("The Job", ch.objective_text()))
	if ch.first_wave > 1:
		_page.add_child(_fact("Starting Out", "Wave %d, with %s to build with. Mid tier turrets open from wave 5, Late from wave 10." % [ch.first_wave, _bonus_text(ch)]))
	var pay := "%d Notches" % ch.notches()
	if state == "done":
		pay = "%d Notches for a replay (won %d time%s)" % [StoryProgress.replay_tip(ch), int(Story.progress.done[ch.id]["wins"]), "" if int(Story.progress.done[ch.id]["wins"]) == 1 else "s"]
	elif not ch.unlock().is_empty():
		pay += "  ·  " + str(ch.unlock().get("name", ""))
	pay += "  ·  A page of Doc Whitlow's journal"
	_page.add_child(_fact("The Pay", pay))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(spacer)
	var go_row := HBoxContainer.new()
	go_row.alignment = BoxContainer.ALIGNMENT_END
	go_row.add_theme_constant_override("separation", 10)
	_page.add_child(go_row)
	if state == "locked":
		var why := UiStyle.status("Win Chapter %d first." % (ch.number - 1), "lock", 15)
		why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go_row.add_child(why)
	var go := MenuScreen.wood_button("Ride Out" if state != "done" else "Ride It Again")
	go.custom_minimum_size = Vector2(220, 52)
	go.disabled = state == "locked"
	go.pressed.connect(func() -> void:
		close()
		ride.emit(ch.id))
	go_row.add_child(go)


func _bonus_text(ch: StoryChapter) -> String:
	var parts: PackedStringArray = []
	for r: String in ch.start_bonus:
		parts.append(UiStyle.cost(int(ch.start_bonus[r]), r))
	return " and ".join(parts) + " extra" if not parts.is_empty() else "the usual stake"


func _fact(head: String, text: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var h := UiStyle.title(head, 18)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(h)
	var l := UiStyle.label(text, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size.x = 560
	v.add_child(l)
	return v


func _fill_journal() -> void:
	_page.add_child(UiStyle.title("Doc Whitlow's Journal", 34))
	var sub := UiStyle.label("Pages mailed up from Rail Car 9, one for each chapter won.", 16)
	sub.theme_type_variation = "SoftInkLabel"
	_page.add_child(sub)
	_page.add_child(UiStyle.divider(520))
	for v in journal_pages():
		_page.add_child(_journal_page(v))


## [[title, body, earned], ...] in chapter order (also the Field Guide's Journal tab).
static func journal_pages() -> Array:
	var out: Array = []
	for ch in StoryChapter.all():
		var got := Story.progress.journal.has(ch.id)
		out.append([str(ch.journal.get("title", "")) if got else "A Torn Page",
				str(ch.journal.get("body", "")) if got else "Win Chapter %d, %s, to read this page." % [ch.number, ch.title], got])
	return out


func _journal_page(v: Array) -> Control:
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#F4E9CC") if bool(v[2]) else Color("#D8C9A4")
	sb.border_color = Color("#B89A63")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(14)
	paper.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	paper.add_child(col)
	var t := TelegramView._ink(str(v[0]), 20, TelegramView.INK, UiStyle.display_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(t)
	var b := TelegramView._ink(str(v[1]), 16, TelegramView.INK if bool(v[2]) else TelegramView.FADED, TelegramView._type_font())
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 580
	col.add_child(b)
	return paper

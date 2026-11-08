class_name EpilogueView
extends CanvasLayer
## Story: the epilogue after a chapter that has one (The Reckoning), over the
## end screen. One decree card per man the story was about, typed out on
## territorial court paper (the telegram's typewriter face), then the last word
## on the wire (the chapter's `closing` line) with the speaker's portrait. Click,
## E, Space or Enter to go on (each card also moves on by itself once it's been
## read); after the last word it fades and leaves the front page. Local.
##
## Debug: --epilogue opens it at the chapter's start (screenshots);
## --epiloguecard=N starts at card N (the card count = the last word);
## --epiloguefull shows each card fully typed at once.

const PAPER := Color("#EFE4C6")
const INK := Color("#2B1D12")
const FADED := Color("#6B5638")
const RED := Color("#8C1E24")
const TYPE_FONT := "res://assets/fonts/SpecialElite-Regular.ttf"
## Characters typed a second, and seconds a card stays after it's typed.
const TYPE_RATE := 55.0
const LINGER := 7.0

var chapter: StoryChapter
var delay := 2.0
var _root: Control
var _holder: CenterContainer
var _card := -1
var _body: Label
var _typed := 0.0
var _full := ""
var _linger := 0.0
var _done := false


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyle.fit(_root)
	_root.visible = false
	add_child(_root)
	var scrim := ColorRect.new()
	scrim.color = Color(0.04, 0.03, 0.02, 0.9)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(scrim)
	_holder = CenterContainer.new()
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_holder)
	_root.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_next())
	var start := 0
	if GameState.debug_enabled() and GameState.flag_value("--epiloguecard") != "":
		start = clampi(int(GameState.flag_value("--epiloguecard")), 0, chapter.epilogue.size())
	get_tree().create_timer(delay, true, false, true).timeout.connect(func() -> void:
		_root.visible = true
		UiStyle.fade_in(_root)
		_show(start))


func is_open() -> bool:
	return _root != null and _root.visible and not _done


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		_next()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open() or _body == null:
		return
	if _typed < float(_full.length()):
		var before := int(_typed)
		_typed = minf(_typed + delta * TYPE_RATE, float(_full.length()))
		_body.visible_characters = int(_typed)
		if int(_typed) / 6 != before / 6 and _full[int(_typed) - 1] != " ":
			Audio.play_ui(&"hit_tick", -20.0, randf_range(1.6, 2.0))
		return
	_linger += delta
	if _linger >= LINGER + (4.0 if _card >= chapter.epilogue.size() else 0.0):
		_next()


## Typing: finish the card; typed: the next one; after the last word: close.
func _next() -> void:
	if _body != null and _typed < float(_full.length()):
		_typed = float(_full.length())
		_body.visible_characters = -1
		return
	if _card >= chapter.epilogue.size():
		_close()
		return
	_show(_card + 1)


func _close() -> void:
	if _done:
		return
	_done = true
	UiStyle.fade_out(_root)


func _show(i: int) -> void:
	_card = i
	_typed = 0.0
	_linger = 0.0
	for c in _holder.get_children():
		c.queue_free()
	if i < chapter.epilogue.size():
		var card: Dictionary = chapter.epilogue[i]
		_holder.add_child(_decree(str(card.get("title", "")), str(card.get("body", "")), i))
	else:
		_holder.add_child(_last_word())
	Audio.play_ui(&"scribble", -10.0)
	if GameState.debug_enabled() and GameState.has_flag("--epiloguefull") and _body != null:
		_typed = float(_full.length())
		_body.visible_characters = -1


## One card: court paper, a red seal line, the man's name typed big, his end typed out.
func _decree(title: String, body: String, i: int) -> Control:
	var paper := PanelContainer.new()
	# The kit's document paper, with a court form's inset border.
	var sb := UiStyle.box_for(&"base", "doc")
	sb.rule = Color(FADED, 0.5)
	sb.rule_inset = 9.0
	sb.rule_width = 1.2
	sb.set_content_margin_all(38)
	paper.add_theme_stylebox_override("panel", sb)
	paper.custom_minimum_size = Vector2(720, 0)
	paper.rotation_degrees = -0.8 + float(i % 2) * 1.4
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	paper.add_child(col)
	col.add_child(_ink("TERRITORY OF ARIZONA  ·  IN THE MATTER OF DRY GULCH  ·  %d / %d" % [i + 1, chapter.epilogue.size()], 13, RED, null))
	col.add_child(_rule(2))
	var t := _ink(title.to_upper(), 30, INK, _font())
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	col.add_child(_rule(1))
	_full = body
	_body = _ink(body, 21, INK, _font())
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(650, 0)
	_body.visible_characters = 0
	col.add_child(_body)
	col.add_child(_rule(1))
	# Keycaps, like every other screen's footer, in the document's ink.
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 6)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k: String in ["LMB", KeyHints.key_for("interact")]:
		var cap := KeyHints.chip(k)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_child(cap)
	foot.add_child(_ink("Go On", 13, FADED, UiStyle.font("label")))
	col.add_child(foot)
	return paper


## The last word on the wire: the speaker's portrait and the line, big.
func _last_word() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who := str(chapter.closing[0]) if chapter.closing.size() == 2 else "stroud"
	var line := str(chapter.closing[1]) if chapter.closing.size() == 2 else ""
	var ring := StoryPortrait.framed(self, who, 150.0)
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ring)
	var name_l := UiStyle.eyebrow(StoryChapter.speaker_name(who), 18, UiStyle.c("title"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)
	_full = "\"%s\"" % line
	_body = _ink(_full, 34, UiStyle.c("ink"), UiStyle.display_font())
	# A deliberate centre-screen line over the dark scrim: outlined like a title.
	_body.add_theme_color_override("font_outline_color", UiStyle.c("outline"))
	_body.add_theme_constant_override("outline_size", 6)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(900, 0)
	_body.visible_characters = 0
	col.add_child(_body)
	return col


func _font() -> Font:
	return load(TYPE_FONT) as Font


func _ink(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UiStyle.ts(size))
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rule(px: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = FADED
	r.custom_minimum_size = Vector2(0, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

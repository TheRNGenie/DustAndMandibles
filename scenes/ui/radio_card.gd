class_name RadioCard
extends Control
## Story: a radio line from the Lucky Mandible's crew (and the Board). A small
## card at the top left shows who's on the wire (a painted portrait in a brass
## ring, their name and where from), and the line itself runs as a stylized
## subtitle at the bottom of the screen. Voiced lines play their recording
## (VoiceLines, res://audio/voice) and hold as long as it runs; unvoiced ones
## hold long enough to read. Lines that come together queue up. It never stops
## play. Purely local (StoryDirector says what to say).

const WIDTH := 300.0
const PORTRAIT := 84.0
const TOP := 200.0
## The subtitle band: widest it gets, and how far up from the bottom edge (clear of the hotbar).
const SUB_WIDTH := 980.0
const SUB_BOTTOM := 150.0

var _card: PanelContainer
var _pic: TextureRect
var _name: Label
var _role: Label
var _text: Label
var _dot: Panel
var _queue: Array = []
## Seconds of quiet before a different character speaks (Logan).
const SPEAKER_GAP := 2.0
var _cur_who := ""
var _gapping := false
var _showing := false
var _t := 0.0
var _hold := 0.0
var _tween: Tween
var _sub: PanelContainer
var _sub_name: Label
var _voice: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiStyle.c("hud_bg"), 0.93)
	sb.border_color = UiStyle.c("hud_rim")
	sb.set_border_width_all(2)
	sb.border_width_left = 6
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	sb.content_margin_left = 12
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	_card.add_theme_stylebox_override("panel", sb)
	_card.position = Vector2(24, TOP)
	_card.custom_minimum_size = Vector2(WIDTH, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	row.add_child(_portrait_frame())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var wire := HBoxContainer.new()
	wire.add_theme_constant_override("separation", 6)
	wire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(wire)
	_dot = Panel.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color("#E0483C")
	dsb.set_corner_radius_all(5)
	_dot.add_theme_stylebox_override("panel", dsb)
	_dot.custom_minimum_size = Vector2(9, 9)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wire.add_child(_dot)
	var w := UiStyle.label("Lucky Mandible Wireless", 12, Color(UiStyle.c("hud"), 0.6))
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	w.autowrap_mode = TextServer.AUTOWRAP_OFF
	wire.add_child(w)
	_name = UiStyle.label("", 22, UiStyle.c("title"))
	_name.add_theme_font_override("font", UiStyle.display_font())
	_name.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_name.add_theme_constant_override("outline_size", 4)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(_name)
	_role = UiStyle.label("", 13, Color(UiStyle.c("hud"), 0.65))
	_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_role.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(_role)
	_card.visible = false
	_build_subtitle()
	_voice = AudioStreamPlayer.new()
	_voice.bus = &"Voice" if AudioServer.get_bus_index("Voice") >= 0 else &"Master"
	add_child(_voice)


## The subtitle: a soft dark band low on the screen, the speaker's name in the
## western display face over the line in a warm outlined type.
func _build_subtitle() -> void:
	_sub = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.03, 0.62)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	_sub.add_theme_stylebox_override("panel", sb)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.add_child(col)
	_sub_name = UiStyle.label("", 18, UiStyle.c("title"))
	_sub_name.add_theme_font_override("font", UiStyle.display_font())
	_sub_name.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_sub_name.add_theme_constant_override("outline_size", 4)
	_sub_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(_sub_name)
	_text = UiStyle.label("", 24, Color("#F6E7C8"))
	_text.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	_text.add_theme_constant_override("outline_size", 6)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_text.add_theme_constant_override("shadow_offset_y", 2)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_text)
	_sub.visible = false


## A round brass-rimmed frame on a warm sepia ground, the portrait clipped inside.
func _portrait_frame() -> Control:
	var ring := Panel.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color("#3A2614")
	rsb.border_color = Color("#C9A04A")
	rsb.set_border_width_all(4)
	rsb.set_corner_radius_all(int(PORTRAIT * 0.5))
	rsb.anti_aliasing = true
	ring.add_theme_stylebox_override("panel", rsb)
	ring.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := Panel.new()
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color.WHITE
	msb.set_corner_radius_all(int(PORTRAIT * 0.5) - 5)
	msb.anti_aliasing = true
	mask.add_theme_stylebox_override("panel", msb)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.offset_left = 5
	mask.offset_top = 5
	mask.offset_right = -5
	mask.offset_bottom = -5
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(mask)
	var ground := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color("#E9C98E"))
	g.set_color(1, Color("#7A4E2C"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.45, 0.35)
	gt.fill_to = Vector2(1.05, 1.0)
	gt.width = 128
	gt.height = 128
	ground.texture = gt
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(ground)
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(_pic)
	return ring


## Seconds a line stays up: its recording and a breath after, or long enough to read.
static func line_seconds(line: String, who: String = "") -> float:
	var v := VoiceLines.length_of(who, line) if who != "" else 0.0
	if v > 0.0:
		return v + 0.6
	return 3.0 + line.split(" ", false).size() * 0.3


## Seconds until everything queued has been said.
func queued_seconds() -> float:
	var t := maxf(_hold, 0.0) if _showing else 0.0
	var prev := _cur_who
	for l: Array in _queue:
		t += line_seconds(str(l[1]), str(l[0]))
		if prev != "" and str(l[0]) != prev:
			t += SPEAKER_GAP
		prev = str(l[0])
	return t


## Queues a line from `who` (StoryChapter.SPEAKERS).
func say(who: String, line: String) -> void:
	StoryPortrait.face_texture(self, who) # start rendering now, so it's ready
	_queue.append([who, line])
	if not _showing:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_gapping = false
		_cur_who = "" # (a fresh conversation later starts without a gap)
		_showing = false
		_slide(false)
		var fade := create_tween()
		fade.tween_property(_sub, "modulate:a", 0.0, 0.3)
		fade.tween_callback(func() -> void: _sub.visible = false)
		return
	_showing = true
	# A different character next: a beat of quiet on the wire first.
	if not _gapping and _cur_who != "" and str((_queue[0] as Array)[0]) != _cur_who:
		_gapping = true
		_hold = SPEAKER_GAP
		_voice.stop()
		var hush := create_tween()
		hush.tween_property(_sub, "modulate:a", 0.0, 0.25)
		return
	_gapping = false
	var l: Array = _queue.pop_front()
	var who := str(l[0])
	_cur_who = who
	_pic.texture = StoryPortrait.face_texture(self, who)
	_name.text = StoryChapter.speaker_name(who)
	_role.text = StoryChapter.speaker_role(who)
	_text.text = str(l[1])
	_sub_name.text = StoryChapter.speaker_short(who)
	_hold = line_seconds(str(l[1]), who)
	_voice.stop()
	var stream := VoiceLines.stream_for(who, str(l[1]))
	if stream != null:
		_voice.stream = stream
		_voice.play()
	_place_subtitle()
	_sub.visible = true
	_sub.modulate.a = 0.0
	create_tween().tween_property(_sub, "modulate:a", 1.0, 0.18)
	if not _card.visible:
		_slide(true)
	else:
		# Next line: a quick flicker of the wire, not a full slide.
		_card.modulate.a = 0.4
		create_tween().tween_property(_card, "modulate:a", 1.0, 0.15)
	Audio.play_ui(&"bell", -18.0)


func _slide(show: bool) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	if show:
		_card.visible = true
		_card.position.x = -WIDTH - 40
		_card.modulate.a = 1.0
		_tween.tween_property(_card, "position:x", 24.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(_card, "position:x", -WIDTH - 40, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tween.tween_callback(func() -> void: _card.visible = false)


func _process(delta: float) -> void:
	_t += delta
	# Sits just under the chapter tracker, however tall that is.
	var tracker := get_parent().get_node_or_null("StoryTracker") as Control if get_parent() != null else null
	if tracker != null and tracker.visible:
		_card.position.y = tracker.position.y + tracker.size.y + 10.0
	if _dot != null:
		_dot.modulate.a = 0.35 + 0.65 * float(int(_t * 2.5) % 2)
	if not _showing:
		return
	if _sub.visible:
		_keep_subtitle_placed()
	_hold -= delta
	if _hold <= 0.0:
		_next()


## The subtitle wraps at SUB_WIDTH (or one line, if the line is short).
func _place_subtitle() -> void:
	var w := minf(SUB_WIDTH, get_viewport_rect().size.x - 80.0)
	var font := _text.get_theme_font("font")
	var one_line := font.get_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 12.0
	_text.custom_minimum_size = Vector2(clampf(one_line, 280.0, w - 44.0), 0)
	_sub.reset_size()
	_keep_subtitle_placed()


## Centred, its bottom SUB_BOTTOM above the screen's.
func _keep_subtitle_placed() -> void:
	# (A wrapped label only knows its height once it has its width, so the band
	# shrinks back to fit a frame after a new line goes up.)
	_sub.reset_size()
	var vp := get_viewport_rect().size
	_sub.position = Vector2(roundf((vp.x - _sub.size.x) * 0.5), roundf(vp.y - SUB_BOTTOM - _sub.size.y))


## Debug (screenshots): keeps the current line up.
func freeze() -> void:
	_hold = 1e9

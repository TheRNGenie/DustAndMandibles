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

var _card: PanelContainer
var _pic: TextureRect
var _name: Label
var _role: Label
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
var _sub: Subtitle
var _voice: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	# The HUD kit's plate with the set's metal down its left edge (a radio on the wire).
	var sb := KeyHints.kit_box("plate").duplicate() as KitBox
	sb.bar_side = 1
	sb.bar = UiStyle.kc("accent")
	sb.bar_width = 4.0
	sb.bar_inset = 0.12
	_card.add_theme_stylebox_override("panel", sb)
	UiStyle.notifier.changed.connect(func() -> void:
		var fresh := KeyHints.kit_box("plate").duplicate() as KitBox
		fresh.bar_side = 1
		fresh.bar = UiStyle.kc("accent")
		fresh.bar_width = 4.0
		fresh.bar_inset = 0.12
		_card.add_theme_stylebox_override("panel", fresh)
		_restyle())
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
	var w := KeyHints.eyebrow("Lucky Mandible Wireless", 12)
	wire.add_child(w)
	_name = Label.new()
	_name.theme_type_variation = "HeaderTitle"
	_name.add_theme_font_size_override("font_size", UiStyle.ts(22))
	_name.add_theme_constant_override("outline_size", 4)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_name)
	_role = KeyHints.ink("", 14, true)
	col.add_child(_role)
	_restyle()
	_card.visible = false
	_sub = Subtitle.new()
	add_child(_sub)
	_voice = AudioStreamPlayer.new()
	_voice.bus = &"Voice" if AudioServer.get_bus_index("Voice") >= 0 else &"Master"
	add_child(_voice)


## The speaker's name in the set's display face, unless that face is too ornate
## to read at a glance (then the kit's bold UI face).
func _restyle() -> void:
	if UiStyle.display_is_decorative():
		_name.add_theme_font_override("font", UiStyle.font("bold"))
	else:
		_name.remove_theme_font_override("font")


## A round brass-rimmed frame on a warm sepia ground, the portrait clipped inside.
func _portrait_frame() -> Control:
	var ring := Panel.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = UiStyle.kc("well")
	rsb.border_color = UiStyle.kc("accent")
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
		_sub.fade_out(0.3)
		return
	_showing = true
	# A different character next: a beat of quiet on the wire first.
	if not _gapping and _cur_who != "" and str((_queue[0] as Array)[0]) != _cur_who:
		_gapping = true
		_hold = SPEAKER_GAP
		_voice.stop()
		_sub.fade_out(0.25, false)
		return
	_gapping = false
	var l: Array = _queue.pop_front()
	var who := str(l[0])
	_cur_who = who
	_pic.texture = StoryPortrait.face_texture(self, who)
	_name.text = StoryChapter.speaker_name(who)
	_role.text = StoryChapter.speaker_role(who)
	_hold = line_seconds(str(l[1]), who)
	_voice.stop()
	var stream := VoiceLines.stream_for(who, str(l[1]))
	if stream != null:
		_voice.stream = stream
		_voice.play()
	_sub.show_line(who, str(l[1]), stream != null)
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
	_hold -= delta
	if _hold <= 0.0:
		_next()


## Debug (screenshots): keeps the current line up.
func freeze() -> void:
	_hold = 1e9

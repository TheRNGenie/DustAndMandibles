class_name Subtitle
extends PanelContainer
## The spoken-line subtitle low on the screen: a soft dark band, the speaker's
## short name in the western display face over the line in warm outlined type.
## Used by the radio (RadioCard) and the tutorial (TutorialCard). Settings >
## Audio > Subtitles hides it for voiced lines; an unvoiced line always shows,
## since the words are the only way it's heard.

## Widest the band gets, and how far its bottom sits above the screen's (clear of the hotbar).
const WIDTH := 980.0
const BOTTOM := 150.0

var _name: Label
var _text: Label
var _voiced := false
var _fade: Tween


func _init() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.03, 0.62)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_name = UiStyle.label("", 18, UiStyle.c("title"))
	_name.add_theme_font_override("font", UiStyle.display_font())
	_name.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_name.add_theme_constant_override("outline_size", 4)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(_name)
	_text = UiStyle.label("", 24, Color("#F6E7C8"))
	_text.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	_text.add_theme_constant_override("outline_size", 6)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_text.add_theme_constant_override("shadow_offset_y", 2)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_text)
	visible = false


## Puts a line up (fading in). `voiced`: a recording is playing it.
func show_line(who: String, line: String, voiced: bool) -> void:
	_voiced = voiced
	_name.text = StoryChapter.speaker_short(who) if who != "" else ""
	_name.visible = _name.text != ""
	_text.text = line
	var w := minf(WIDTH, get_viewport_rect().size.x - 80.0)
	var one_line := _text.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 12.0
	_text.custom_minimum_size = Vector2(clampf(one_line, 280.0, w - 44.0), 0)
	_kill_fade()
	visible = _wanted()
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.18)
	_place()


## Fades the line out (`then_hide`: gone for good, not just a hush between speakers).
func fade_out(seconds: float = 0.3, then_hide: bool = true) -> void:
	_kill_fade()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, seconds)
	if then_hide:
		_fade.tween_callback(func() -> void: visible = false)


func clear() -> void:
	_kill_fade()
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	if not _wanted():
		visible = false # (switched off mid-line)
		return
	_place()


func _wanted() -> bool:
	return Settings.subtitles or not _voiced


## Centred, its bottom BOTTOM above the screen's. (A wrapped label only knows its
## height once it has its width, so the band shrinks back to fit each frame.)
func _place() -> void:
	reset_size()
	var vp := get_viewport_rect().size
	position = Vector2(roundf((vp.x - size.x) * 0.5), roundf(vp.y - BOTTOM - size.y))


func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null

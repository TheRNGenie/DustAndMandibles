class_name TelegramView
extends CanvasLayer
## Story: the chapter's telegram, read off the house noticeboard (E). A
## Territorial Telegraph Co. form with the message typed on pasted strips, the
## Captain's signature, and the chapter goal underneath. The same form, drawn
## into a small texture, is what's pinned on the board (paper_texture).

const PAPER := Color("#F1E4BF")
const STRIP := Color("#FBF5E1")
const INK := Color("#2B1D12")
const FADED := Color("#6B5638")
const RED := Color("#9C2A1E")
const TYPE_FONT := "res://assets/fonts/SpecialElite-Regular.ttf"

var _root: Control
var _holder: CenterContainer
var _was_captured := false

static var _tex_cache: Dictionary = {}


func _ready() -> void:
	layer = 64
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.fit(_root)
	_root.visible = false
	add_child(_root)
	_root.add_child(UiStyle.scrim())
	_holder = CenterContainer.new()
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_holder)


func is_open() -> bool:
	return UiStyle.shown(_root)


func open() -> void:
	var ch := Story.chapter()
	if ch == null:
		return
	for c in _holder.get_children():
		c.queue_free()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_holder.add_child(col)
	var paper := make_paper(ch, 1.0)
	paper.rotation_degrees = -1.2
	col.add_child(paper)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	col.add_child(foot)
	var goal := PanelContainer.new()
	goal.theme_type_variation = "HudPanel"
	goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(goal)
	var gl := UiStyle.label("Chapter %d Goal:  %s" % [ch.number, ch.objective_text()], 18)
	gl.theme_type_variation = "HudLabel"
	goal.add_child(gl)
	var close := MenuScreen.wood_button("Close")
	close.pressed.connect(close_view)
	foot.add_child(close)
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.set_menu(self, true)
	_root.visible = true
	UiStyle.fade_in(_root)


func close_view() -> void:
	if not is_open():
		return
	UiStyle.fade_out(_root)
	GameState.set_menu(self, false)
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		close_view()
		get_viewport().set_input_as_handled()


## The telegram form for chapter `ch`, `k` times its natural size (560 px wide).
static func make_paper(ch: StoryChapter, k: float) -> PanelContainer:
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = FADED
	sb.set_border_width_all(maxi(int(2 * k), 1))
	sb.set_content_margin_all(18 * k)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = int(8 * k)
	var aged := UiStyle.aged_paper(PAPER, sb.border_color, 2, sb.content_margin_left)
	paper.add_theme_stylebox_override("panel", aged if aged is StyleBoxTexture else sb)
	paper.custom_minimum_size = Vector2(560 * k, 0)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(6 * k))
	paper.add_child(col)
	var head := _ink("Territorial Telegraph Co.", int(30 * k), INK, UiStyle.display_font())
	col.add_child(head)
	col.add_child(_ink("TELEGRAM  ·  RECEIVED AT DRY GULCH STATION  ·  1889", int(12 * k), RED, null))
	col.add_child(_rule(k, 2))
	var to := _ink("TO: %s          RE: %s" % [str(ch.telegram.get("to", "THE RANCHERS ON THE CLIFFS")).to_upper(), str(ch.telegram.get("title", ch.title)).to_upper()], int(13 * k), FADED, _type_font())
	to.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	to.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(to)
	# The message, typed on pasted strips (one strip per STOP).
	var body := str(ch.telegram.get("body", ""))
	for part: String in body.split(" STOP"):
		var t := part.strip_edges()
		if t == "":
			continue
		var strip := PanelContainer.new()
		var ssb := StyleBoxFlat.new()
		ssb.bg_color = STRIP
		ssb.set_content_margin_all(5 * k)
		ssb.content_margin_left = 10 * k
		strip.add_theme_stylebox_override("panel", ssb)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _ink(t + " STOP", int(17 * k), INK, _type_font())
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		strip.add_child(l)
		col.add_child(strip)
	col.add_child(_rule(k, 1))
	var sig := _ink(str(ch.telegram.get("from", "CAPT. A. STROUD  ·  AIRSHIP LUCKY MANDIBLE")), int(14 * k), INK, _type_font())
	sig.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(sig)
	return paper


## The form drawn once into a texture for the noticeboard (cached per chapter).
static func paper_texture(host: Node, ch: StoryChapter) -> Texture2D:
	if ch == null:
		return null
	if _tex_cache.has(ch.id) and is_instance_valid(_tex_cache[ch.id]["vp"]):
		return _tex_cache[ch.id]["tex"]
	var vp := SubViewport.new()
	vp.size = Vector2i(560, 430)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var paper := make_paper(ch, 1.0)
	paper.position = Vector2.ZERO
	paper.size = Vector2(vp.size)
	vp.add_child(paper)
	var ref: WeakRef = weakref(vp)
	host.get_tree().create_timer(0.8).timeout.connect(func() -> void:
		var v := ref.get_ref() as SubViewport
		if v != null:
			v.render_target_update_mode = SubViewport.UPDATE_ONCE)
	_tex_cache[ch.id] = {"vp": vp, "tex": vp.get_texture()}
	return vp.get_texture()


static func _type_font() -> Font:
	return load(TYPE_FONT) as Font


static func _ink(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _rule(k: float, px: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = FADED
	r.custom_minimum_size = Vector2(0, maxf(px * k, 1.0))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

class_name TutorialGazette
extends Control
## The tutorial's opening page: The Territorial Gazette, April 1901, its front
## page given over to the Western Plains & Pacific's Dry Gulch Reclamation
## Charter (the land deal that brings you to the rims). It's pulled up over
## about 80% of the screen, framed by near-black bars (BARS: the blurred game
## barely shows through). The screen fades to it (FADE_IN: page and bars
## fade in over the game) and, once turned, it fades quickly away (FADE_OUT). The page is laid out at
## one design size and scaled to fit, so it reads the same at any resolution.
## Input does nothing for the first LOCK_SECS; from then on any key, mouse
## button or controller button turns the page (turned), and from HINT_SECS
## "Press any button to continue" fades in over the blurred strip below it.
## TutorialRun then holds it while the radio's still talking (set_waiting)
## and folds it away (close).
##
## Only the public story: the charter, the "regrettable mining accident of
## 1889", Pell's Law told straight (Field Guide, chapter 1's telegram).

signal turned

## The page's layout size (scaled to SCREEN_SHARE of the viewport's height or width).
const PAGE := Vector2(1180, 664)
const SCREEN_SHARE := 0.8
const PAPER := NewspaperFront.PAPER
const INK := NewspaperFront.INK
const FADED := NewspaperFront.FADED
const RED := Color("#8C2A1C")
## Seconds before any input turns the page, and before the hint shows.
const LOCK_SECS := 3.0
const HINT_SECS := 5.0
const HINT := "Press any button to continue"
## How black the bars round the page are (1 = solid), and the fades (seconds).
const BARS := 0.9
const FADE_IN := 1.0
const FADE_OUT := 0.5

const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 1.0;
uniform float black = 0.9;
void fragment() {
	// Blur and dim more toward the edges and corners; the middle (under the page) stays clearer.
	vec2 d = abs(SCREEN_UV - 0.5) * 2.0;
	float edge = clamp(max(d.x, d.y) * 0.75 + length(d) * 0.35, 0.0, 1.0);
	float lod = mix(1.5, 4.5, edge) * strength;
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	c = mix(c, c * vec3(0.55, 0.47, 0.40), (0.35 + 0.4 * edge) * strength);
	COLOR = vec4(mix(c, vec3(0.0), black), 1.0); // black bars, a faint hint of the canyon behind
}
"""

var _blur: ColorRect
var _page: PanelContainer
var _hint: Label
var _t := 0.0
var _turned := false
var _waiting := false
var _closing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_blur = ColorRect.new()
	_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BLUR_SHADER
	mat.shader = sh
	mat.set_shader_parameter("black", BARS)
	_blur.material = mat
	add_child(_blur)
	_page = _build_page()
	add_child(_page)
	_hint = UiStyle.label(HINT, 18, Color.WHITE)
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.0
	add_child(_hint)
	get_viewport().size_changed.connect(_fit)
	modulate.a = 0.0
	_fit()
	# (Wrapped text settles its height a frame after the width is set.)
	await get_tree().process_frame
	await get_tree().process_frame
	_fit()
	# The screen fades to the paper.
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE)


## Scales the page to SCREEN_SHARE of the screen and centres it.
func _fit() -> void:
	if _page == null:
		return
	var vs := get_viewport_rect().size
	_page.size = PAGE
	var want := PAGE.max(_page.get_combined_minimum_size()) # (never cut the page off)
	var k := minf(vs.x * SCREEN_SHARE / want.x, vs.y * SCREEN_SHARE / want.y)
	_page.size = want
	_page.scale = Vector2(k, k)
	_page.position = (vs - want * k) * 0.5
	# The hint sits centred in the blurred strip under the page.
	_hint.reset_size()
	var strip := vs.y - (_page.position.y + want.y * k)
	_hint.position = Vector2((vs.x - _hint.size.x) * 0.5, vs.y - strip * 0.5 - _hint.size.y * 0.5)


func _process(delta: float) -> void:
	_t += delta
	if _hint == null or _closing:
		return
	# A gentle fade in at HINT_SECS, then a slow pulse.
	var want := 0.0
	if _waiting:
		want = 0.85
	elif _t >= HINT_SECS and not _turned:
		want = minf((_t - HINT_SECS) / 0.8, 1.0) * (0.7 + 0.3 * sin((_t - HINT_SECS) * 2.2))
	_hint.modulate.a = want


## Can the page be turned yet?
func can_turn() -> bool:
	return _t >= LOCK_SECS and not _closing


## Turned, but the radio's still talking.
func set_waiting(on: bool) -> void:
	_waiting = on
	if _hint != null:
		_hint.text = "Waiting on the Radio" if on else HINT
		_fit()


func _turn() -> void:
	if not can_turn() or _turned:
		return
	_turned = true
	turned.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_turn()
		accept_event()


func _input(event: InputEvent) -> void:
	if _closing:
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var button: bool = (event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed
	var press: bool = key or button
	if press:
		_turn()
		get_viewport().set_input_as_handled() # (the page has the screen: nothing reaches the game)


## Folds the page away and frees it.
func close() -> void:
	if _closing:
		return
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(queue_free)


# ------------------------------------------------------------------ the page

func _build_page() -> PanelContainer:
	var page := PanelContainer.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.theme_type_variation = "DocPanel" # the kit's document paper: cream, fibres, a burnt edge
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(col)
	# Masthead.
	var ears := HBoxContainer.new()
	ears.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(ears)
	ears.add_child(_text("WEATHER\nFair and hot.\nDust by evening.", 12, FADED, HORIZONTAL_ALIGNMENT_LEFT, 170))
	var mast := _title("The Territorial Gazette", 40, INK)
	mast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ears.add_child(mast)
	ears.add_child(_text("ALL THE NEWS\nOF THE PLAINS\nAND THE RAILS", 12, FADED, HORIZONTAL_ALIGNMENT_RIGHT, 170))
	col.add_child(_rule(3))
	col.add_child(_text("VOL. XXXIII  ·  NO. 14  ·  TUESDAY, APRIL 2, 1901  ·  PRICE FIVE CENTS", 12, FADED, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_rule(1))
	col.add_child(_title("Dry Gulch Opens to Settlement", 30, INK))
	col.add_child(_text("Railroad Charter Offers Free Title on the Canyon Rims; Settlers Wanted at Once", 14, FADED, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_rule(1))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	body.add_child(_left_column())
	body.add_child(_vrule())
	var ad := _advert()
	ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(ad)
	body.add_child(_vrule())
	body.add_child(_right_column())
	return page


func _left_column() -> Control:
	var c := _column(220)
	c.add_child(_head("From the Gulch"))
	c.add_child(_text("Pumps, generators and well-gear went down the line to the Dry Gulch claims this week, the Company reports, with a house raised on every rim and a plot or two turned for corn.", 12, INK))
	c.add_child(_head("At the Railhead"))
	c.add_child(_text("Corn steady. Chilies dear. Seed in short supply; growers are urged to buy early from the airship market.", 12, INK))
	c.add_child(_head("Pests Reported"))
	c.add_child(_text("Settlers on the rims report dust mites of uncommon size. The Company assures readers the bounty is equal to them.", 12, INK))
	return c


func _right_column() -> Control:
	var c := _column(220)
	var notice := PanelContainer.new()
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_theme_stylebox_override("panel", _box(1, 8.0))
	var n := VBoxContainer.new()
	n.add_theme_constant_override("separation", 3)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_child(n)
	n.add_child(_title("Public Notice", 18, RED))
	n.add_child(_text("By Order of the Territorial Board of Firearms, 1871: no barrel shall dip more than thirty degrees beneath the horizon. Remember Governor Pell.", 12, INK, HORIZONTAL_ALIGNMENT_CENTER))
	c.add_child(notice)
	c.add_child(_head("Wanted"))
	c.add_child(_text("A steady pair of hands for the East Rim. Must bring own revolver and a partner. Apply at any W.P.&P. depot.", 12, INK))
	c.add_child(_head("Lost"))
	c.add_child(_text("One mule, grey, answers to Biscuit. Last seen near the arches. Reward at the livery.", 12, INK))
	return c


## The big advertisement: the Reclamation Charter.
func _advert() -> Control:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _box(3, 12.0))
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 3)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(c)
	c.add_child(_title("The Western Plains & Pacific Railroad", 18, INK))
	c.add_child(_title("Dry Gulch Reclamation Charter", 22, RED))
	c.add_child(_title("Free Title", 54, INK))
	c.add_child(_text("to every Homesteader who will Hold the Canyon Rims", 16, INK, HORIZONTAL_ALIGNMENT_CENTER))
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 12)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(mid)
	if ResourceLoader.exists("res://assets/story_art/menu.jpg"):
		var art_col := VBoxContainer.new()
		art_col.add_theme_constant_override("separation", 2)
		art_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var art := TextureRect.new()
		art.texture = load("res://assets/story_art/menu.jpg")
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size = Vector2(190, 108)
		art.modulate = Color(1.0, 0.93, 0.8) # a little sepia, as printed
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_col.add_child(art)
		art_col.add_child(_text("The Rims of Dry Gulch, as Sketched by Our Artist", 12, FADED, HORIZONTAL_ALIGNMENT_CENTER, 190))
		mid.add_child(art_col)
	var offer := VBoxContainer.new()
	offer.add_theme_constant_override("separation", 2)
	offer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	offer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(offer)
	for line: String in ["A BOUNTY PAID on every Pest brought down, and on every Night held.",
			"WATER RIGHTS: a Deep Well and a Water Tower on every Claim.",
			"PASSAGE BY AIRSHIP: the Lucky Mandible calls at the Gulch, with Market, Gunsmith and Diversions aboard.",
			"HOUSE, GENERATOR & PUMP furnished at the Company's Expense."]:
		offer.add_child(_text("★  " + line, 12, INK, HORIZONTAL_ALIGNMENT_LEFT))
	c.add_child(_title("The Frontier Rewards the Bold", 22, RED))
	c.add_child(_text("Claims are granted in pairs, one to each rim. Apply at any W.P.&P. depot.", 12, INK, HORIZONTAL_ALIGNMENT_CENTER))
	var quotes := HBoxContainer.new()
	quotes.add_theme_constant_override("separation", 16)
	quotes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(quotes)
	for q: String in ["\"Two nights on the rim and the bounty bought my seed corn.\"  Mrs. J. Pruett, West Rim",
			"\"The pests are large, but so is the land.\"  T. Halloran, East Rim"]:
		var l := _text(q, 12, FADED, HORIZONTAL_ALIGNMENT_CENTER)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quotes.add_child(l)
	c.add_child(_text("C. Vane, Chairman", 14, INK, HORIZONTAL_ALIGNMENT_RIGHT))
	c.add_child(_text("Following the regrettable mining accident of 1889 the canyon floor is closed for public safety and is to be left undisturbed. Title vests on the Charter's terms being met. The Company accepts no liability for pests, weather, falls, or acts of Providence. Firearms to be used as the Law insists.", 12, FADED, HORIZONTAL_ALIGNMENT_CENTER))
	return frame


# ------------------------------------------------------------------ type and rules

func _column(w: float) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.custom_minimum_size.x = w
	c.add_theme_constant_override("separation", 4)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _head(t: String) -> Label:
	var l := _title(t, 18, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _title(t: String, size: int, color: Color) -> Label:
	var l := UiStyle.title(t, size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 1
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _text(t: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, w: float = 0.0) -> Label:
	var l := UiStyle.label(t, size, color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w if w > 0.0 else 1.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(px: int, margin: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = INK
	sb.set_border_width_all(px)
	sb.set_content_margin_all(margin)
	return sb


func _rule(px: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = INK
	r.custom_minimum_size = Vector2(0, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _vrule() -> ColorRect:
	var r := ColorRect.new()
	r.color = INK
	r.custom_minimum_size = Vector2(1, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

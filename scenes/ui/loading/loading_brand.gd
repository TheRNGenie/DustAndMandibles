class_name LoadingBrand
extends LoadingScreen
## Brand Plate: the rider's brand filling the screen. The kit's own backdrop
## (burlap for the Sheaf, gunmetal for the Crossed Irons, felt and mahogany for
## the Snake Eyes...) washed in the brand's colour, the painted brand iron large
## and faint in the middle, the brand's name in its display face and its motto
## in small caps. The spinner is a revolver cylinder seen head on, turning a
## chamber at a time, each chamber lighting with a brass cartridge as the load
## gets another sixth of the way.

var _brand: StringName = &"none"
var _set: StringName = &"base"
var _emblem: Texture2D
var _back: TextureRect
## The drawn brand mark, for a brand with no painted iron.
var _mark: BrandMark
## Chambers loaded so far, and how far the cylinder has turned (radians).
var _loaded := 0
var _turn := 0.0
var _turn_to := 0.0


func _build() -> void:
	_brand = BrandTable.valid(ctx.get("brand", &"none"))
	_set = UiStyle.current if UiStyle.current != &"" else &"base"
	_emblem = BrandMark.painted(_brand)
	_back = UiStyle.backdrop()
	_back.show_behind_parent = true
	add_child(_back)
	if _emblem == null:
		_mark = BrandMark.make(_brand, 600.0, UiStyle.color_of(_set, "title"))
		_mark.modulate.a = 0.45
		add_child(_mark)


func _tick(delta: float) -> void:
	if _mark != null:
		var e := size.y * 0.56
		_mark.custom_minimum_size = Vector2(e, e)
		_mark.size = Vector2(e, e)
		_mark.position = size * 0.5 - Vector2(e, e) * 0.5 + Vector2(0, -size.y * 0.05)
	# A chamber lights for every sixth of the way; the cylinder turns to bring
	# the next one up, with a little overshoot like a real cylinder stop.
	var want := clampi(int(floor(shown * 6.0 + 0.001)), 0, 6)
	while _loaded < want:
		_loaded += 1
		_turn_to += TAU / 6.0
	# Idle: a slow creep, so the cylinder never sits dead still.
	_turn_to += delta * 0.18
	_turn = lerpf(_turn, _turn_to, clampf(delta * 9.0, 0.0, 1.0))


func _draw() -> void:
	var s := sc()
	var mid := size * 0.5
	var wash := UiStyle.color_of(_set, "bg")
	draw_rect(Rect2(Vector2.ZERO, size), Color(wash, 0.62))
	draw_texture_rect(grain(), Rect2(Vector2.ZERO, size), true, Color(0, 0, 0, 0.12))
	vignette(0.75)
	# The brand iron, large and faint.
	if _emblem != null:
		var e := size.y * 0.62
		draw_texture_rect(_emblem, Rect2(mid - Vector2(e, e) * 0.5 + Vector2(0, -size.y * 0.05), Vector2(e, e)), false, Color(1, 1, 1, 0.4))
	# Name and motto.
	var title_col := UiStyle.color_of(_set, "title")
	var bname := str(BrandTable.BRANDS.get(_brand, BrandTable.BRANDS[BrandTable.NONE])["name"])
	var motto := str(BrandTable.BRANDS.get(_brand, BrandTable.BRANDS[BrandTable.NONE])["motto"])
	var df: Font = UiStyle.display_font() if UiStyle.current != &"" else font(RYE)
	var px := fit_px(df, bname, 84.0, size.x * 0.8)
	text(df, mid + Vector2(0, size.y * 0.3), bname, px, title_col, HORIZONTAL_ALIGNMENT_CENTER, -1.0, int(10 * s), UiStyle.color_of(_set, "outline"))
	text(font(BARLOW_BOLD), mid + Vector2(0, size.y * 0.38), UiStyle.sc(motto).to_upper(), 26.0, Color(UiStyle.color_of(_set, "hud"), 0.92))
	# The destination, small, under a rule.
	var dest := destination()
	text(font(BARLOW_BOLD), Vector2(mid.x, size.y * 0.075), "RIDING OUT TO  ·  " + dest.to_upper() if str(ctx.get("to", "")) != "menu" else dest.to_upper(), 24.0, Color(UiStyle.color_of(_set, "hud"), 0.7))
	_cylinder(Vector2(size.x - 130.0 * s, size.y - 130.0 * s), 74.0 * s)
	text(font(BARLOW_BOLD), Vector2(size.x - 230.0 * s, size.y - 130.0 * s), note_text(), 22.0, Color(UiStyle.color_of(_set, "hud"), 0.85), HORIZONTAL_ALIGNMENT_RIGHT)


## A revolver cylinder head on: the fluted steel drum, six chambers round the
## ratchet, loaded chambers showing a brass rim and primer and glowing warm, the
## one at the top (under the hammer) ringed in light.
func _cylinder(c: Vector2, r: float) -> void:
	var steel := Color("#7F8A94")
	draw_circle(c + Vector2(0, r * 0.06), r * 1.04, Color(0, 0, 0, 0.45))
	draw_circle(c, r, steel.darkened(0.35))
	draw_circle(c, r * 0.94, steel)
	# Flutes between the chambers.
	for i in 6:
		var a := _turn + TAU * (float(i) + 0.5) / 6.0 - PI * 0.5
		var p := c + Vector2(cos(a), sin(a)) * r * 0.86
		draw_circle(p, r * 0.13, steel.darkened(0.45))
	for i in 6:
		var a := _turn + TAU * float(i) / 6.0 - PI * 0.5
		var p := c + Vector2(cos(a), sin(a)) * r * 0.56
		var loaded := i < _loaded
		draw_circle(p, r * 0.24, steel.darkened(0.55))
		if loaded:
			draw_circle(p, r * 0.215, Color("#D9A845"))
			draw_circle(p, r * 0.17, Color("#F0CC72"))
			draw_circle(p, r * 0.07, Color("#B87A3A"))
			draw_arc(p, r * 0.27, 0, TAU, 24, Color(1.0, 0.8, 0.4, 0.35), r * 0.06)
		else:
			draw_circle(p, r * 0.17, Color("#0E0C0B"))
	# Ratchet and axle in the middle.
	draw_circle(c, r * 0.22, steel.darkened(0.2))
	for i in 6:
		var a := _turn + TAU * float(i) / 6.0
		draw_line(c + Vector2(cos(a), sin(a)) * r * 0.1, c + Vector2(cos(a), sin(a)) * r * 0.22, steel.darkened(0.5), r * 0.04)
	draw_circle(c, r * 0.08, steel.lightened(0.3))
	# The firing position at the top, marked by a small brass notch.
	draw_rect(Rect2(c + Vector2(-r * 0.06, -r * 1.12), Vector2(r * 0.12, r * 0.12)), Color("#E8C06A"))
	draw_arc(c, r * 1.0, 0, TAU, 48, Color(0, 0, 0, 0.5), r * 0.03)

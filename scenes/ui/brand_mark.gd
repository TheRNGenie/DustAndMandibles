class_name BrandMark
extends Control
## A brand's mark drawn in code: the wheat sheaf, two crossed revolvers, two
## dice showing snake eyes, or (no brand) a cold, empty ring. Burned-in by
## default (one ink colour); `hot` draws it glowing like a branding iron fresh
## from the fire (the pick screen). Small ones sit next to player names.

var brand: StringName = &"":
	set(v):
		brand = v
		queue_redraw()
var color := Color("#3A2416"):
	set(v):
		color = v
		queue_redraw()
## 0 = cold ink, 1 = white-hot.
var heat := 0.0:
	set(v):
		heat = v
		queue_redraw()


static func make(id: StringName, px: float = 22.0, ink: Color = Color("#3A2416")) -> BrandMark:
	var m := BrandMark.new()
	m.brand = id
	m.color = ink
	m.custom_minimum_size = Vector2(px, px)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.tooltip_text = BrandTable.name_of(id)
	return m


## The painted brand iron (assets/brands, AI-made with fal.ai nano-banana), or null.
static func painted(id: StringName) -> Texture2D:
	var path := "res://assets/brands/%s.png" % BrandTable.valid(id)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _draw() -> void:
	if brand == &"":
		return
	var tex := painted(brand)
	if tex != null:
		# The painted iron as a child image (textures drawn straight from _draw came
		# out blank here), with a hot glow behind it when it's fresh from the fire.
		var pic := get_node_or_null("Painted") as TextureRect
		if pic == null:
			pic = TextureRect.new()
			pic.name = "Painted"
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(pic)
		pic.texture = tex
		pic.modulate = Color.WHITE.lerp(Color(0.8, 0.72, 0.66), 1.0 - clampf(heat + 0.6, 0.0, 1.0))
		if heat > 0.0:
			draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, Color(1.0, 0.45, 0.1, 0.22 * heat))
		return
	var s := minf(size.x, size.y) / 100.0
	var o := (size - Vector2.ONE * 100.0 * s) * 0.5
	if heat <= 0.0:
		paint(self, brand, o, s, color, 1.0)
		return
	# Glow: wide soft passes, then the hot core.
	var glow := Color(1.0, 0.42, 0.08)
	for i in 4:
		var w := 1.0 + (4 - i) * 0.9 * heat
		paint(self, brand, o, s, Color(glow, 0.10 * heat), w)
	var hot := clampf(heat * 2.5, 0.0, 1.0)
	paint(self, brand, o, s, color.lerp(Color(1.0, 0.55, 0.15).lerp(Color(1, 0.9, 0.6), heat * 0.6), hot), 1.0)
	paint(self, brand, o, s, Color(1.0, 0.97, 0.85, 0.85 * heat * hot), 0.45)


## Draws a brand's mark on any canvas item, centred at `center`, `px` across (the
## overview map uses this next to names). Draws nothing for "" / none.
static func paint_at(ci: CanvasItem, id: StringName, center: Vector2, px: float, col: Color) -> void:
	if id == &"" or BrandTable.valid(id) == BrandTable.NONE:
		return
	var s := px / 100.0
	paint(ci, id, center - Vector2.ONE * px * 0.5, s, Color(0, 0, 0, col.a * 0.8), 1.8)
	paint(ci, id, center - Vector2.ONE * px * 0.5, s, col, 1.0)


## Draws the mark in a 100x100 box at `o`, scale `s`; `w` widens every stroke.
static func paint(ci: CanvasItem, id: StringName, o: Vector2, s: float, col: Color, w: float) -> void:
	var lw := 7.0 * s * w
	match BrandTable.valid(id):
		BrandTable.SHEAF:
			_sheaf(ci, o, s, col, lw)
		BrandTable.IRONS:
			_irons(ci, o, s, col, lw)
		BrandTable.SNAKE:
			_snake(ci, o, s, col, lw)
		_:
			ci.draw_arc(o + Vector2(50, 50) * s, 36.0 * s, 0.0, TAU, 40, col, lw * 0.8, true)
			ci.draw_line(o + Vector2(34, 50) * s, o + Vector2(66, 50) * s, col, lw * 0.8, true)


static func _sheaf(ci: CanvasItem, o: Vector2, s: float, col: Color, lw: float) -> void:
	var tie := o + Vector2(50, 60) * s
	for k in 7:
		var f := (k - 3) / 3.0
		var top := o + Vector2(50 + f * 30, 14 + absf(f) * 10) * s
		var bot := o + Vector2(50 + f * 16, 94) * s
		var mid := tie + Vector2(f * 3.0, 0) * s
		ci.draw_polyline(PackedVector2Array([bot, mid, top]), col, lw * 0.45, true)
		# The ear: grains along the top of each stalk.
		var dir := (top - mid).normalized()
		var side := Vector2(-dir.y, dir.x)
		for g in 3:
			var p := top - dir * (g * 6.0 + 3.0) * s
			ci.draw_circle(p + side * 3.2 * s, lw * 0.36 * (1.0 if lw > 0 else 1.0), col)
			ci.draw_circle(p - side * 3.2 * s, lw * 0.36, col)
		ci.draw_circle(top + dir * 2.0 * s, lw * 0.3, col)
	ci.draw_line(tie + Vector2(-17, 0) * s, tie + Vector2(17, 0) * s, col, lw * 1.1, true)


static func _irons(ci: CanvasItem, o: Vector2, s: float, col: Color, lw: float) -> void:
	for side: float in [-1.0, 1.0]:
		# A revolver, muzzle up: the two barrels cross above, the grips flare out below.
		var xf := Transform2D(-side * deg_to_rad(34.0), o + Vector2(50 + side * 15.0, 60) * s)
		ci.draw_polyline(_tx(xf, PackedVector2Array([Vector2(0, -50), Vector2(0, -14)]), s), col, lw * 0.7, true)
		ci.draw_polyline(_tx(xf, PackedVector2Array([Vector2(0, -16), Vector2(0, 2)]), s), col, lw * 1.8, true)
		ci.draw_polyline(_tx(xf, PackedVector2Array([Vector2(0, 2), Vector2(side * 6.0, -1)]), s), col, lw * 0.45, true)
		ci.draw_polyline(_tx(xf, PackedVector2Array([Vector2(side * 0.5, 3), Vector2(side * 3.0, 14), Vector2(side * 8.0, 25),
				Vector2(side * 10.0, 34)]), s), col, lw * 1.4, true)
		var guard := PackedVector2Array()
		for k in 9:
			var a := k / 8.0 * PI
			guard.append(Vector2(-side * (3.0 + sin(a) * 6.0), 4.0 + (1.0 - cos(a)) * 4.5))
		ci.draw_polyline(_tx(xf, guard, s), col, lw * 0.35, true)


static func _snake(ci: CanvasItem, o: Vector2, s: float, col: Color, lw: float) -> void:
	for d: Array in [[Vector2(32, 56), -14.0], [Vector2(68, 44), 12.0]]:
		var xf := Transform2D(deg_to_rad(d[1]), o + (d[0] as Vector2) * s)
		var h := 20.0
		var r := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h), Vector2(-h, -h)])
		ci.draw_polyline(_tx(xf, r, s), col, lw * 0.6, true)
		ci.draw_circle(xf * Vector2.ZERO, 6.0 * s * maxf(lw / (7.0 * s), 0.6), col)


static func _tx(xf: Transform2D, pts: PackedVector2Array, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(xf * (p * s))
	return out

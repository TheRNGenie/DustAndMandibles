class_name KitIcon
extends Texture2D
## Small vector icons for the theme (check boxes, slider knobs, dropdown arrows),
## drawn at the size they're shown so they stay sharp at every UI scale.
## kind: check_on, check_off, knob, knob_hl, arrow, radio_on, radio_off.
## knob style: star (Frontier), seed (Sheaf), rivet (Irons), chip (Snake Eyes), hex (Mandibles).

var kind := "check_off"
var px := 22.0
var main := Color(0.85, 0.66, 0.31) ## accent (brass, gold, wheat...)
var ink := Color(0.95, 0.9, 0.8) ## the mark's light colour
var well := Color(0.06, 0.04, 0.03) ## the box's dark inside
var rim := Color(0.0, 0.0, 0.0)
var knob := "star"
var round_box := false


static func make(kind_: String, px_: float, main_: Color, ink_: Color, well_: Color, rim_: Color, knob_: String = "star", round_: bool = false) -> KitIcon:
	var k := KitIcon.new()
	k.kind = kind_
	k.px = px_
	k.main = main_
	k.ink = ink_
	k.well = well_
	k.rim = rim_
	k.knob = knob_
	k.round_box = round_
	return k


func _get_width() -> int:
	return int(px)


func _get_height() -> int:
	return int(px)


func _has_alpha() -> bool:
	return true


func _is_pixel_opaque(_x: int, _y: int) -> bool:
	return true


func _draw(item: RID, pos: Vector2, modulate: Color, _transpose: bool) -> void:
	_paint(item, Rect2(pos, Vector2(px, px)), modulate)


func _draw_rect(item: RID, rect: Rect2, _tile: bool, modulate: Color, _transpose: bool) -> void:
	_paint(item, rect, modulate)


func _draw_rect_region(item: RID, rect: Rect2, _src: Rect2, modulate: Color, _transpose: bool, _clip_uv: bool) -> void:
	_paint(item, rect, modulate)


func _paint(item: RID, r: Rect2, m: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var o := r.position + (r.size - Vector2(s, s)) * 0.5
	var c := o + Vector2(s, s) * 0.5
	match kind:
		"check_on", "check_off":
			var box := Rect2(o + Vector2(s, s) * 0.08, Vector2(s, s) * 0.84)
			var kb := KitBox.make({"corner": KitBox.Corner.ROUND if round_box else KitBox.Corner.CUT, "corner_size": s * 0.18,
				"fill_top": well * m, "fill_bottom": well.lightened(0.04) * m, "rim": (main if kind == "check_on" else main.darkened(0.35)) * m, "rim_width": 1.6,
				"burn": Color(0, 0, 0, 0.35), "burn_size": s * 0.12})
			kb._draw(item, box)
			if kind == "check_on":
				var w := maxf(s * 0.13, 2.0)
				var pts := PackedVector2Array([o + Vector2(s * 0.26, s * 0.52), o + Vector2(s * 0.43, s * 0.69), o + Vector2(s * 0.76, s * 0.3)])
				RenderingServer.canvas_item_add_polyline(item, pts, PackedColorArray([main.lightened(0.25) * m]), w, true)
		"radio_on", "radio_off":
			RenderingServer.canvas_item_add_circle(item, c, s * 0.42, rim * m, true)
			RenderingServer.canvas_item_add_circle(item, c, s * 0.36, well * m, true)
			if kind == "radio_on":
				RenderingServer.canvas_item_add_circle(item, c, s * 0.2, main * m, true)
		"knob", "knob_hl":
			_knob(item, c, s * 0.5, m, kind == "knob_hl")
		"arrow":
			var w2 := maxf(s * 0.12, 1.8)
			var pts2 := PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.1), c + Vector2(0, s * 0.16), c + Vector2(s * 0.26, -s * 0.1)])
			RenderingServer.canvas_item_add_polyline(item, pts2, PackedColorArray([main * m]), w2, true)


## The slider knob in the set's motif, with a soft shadow and a lit face.
func _knob(item: RID, c: Vector2, rad: float, m: Color, hl: bool) -> void:
	var face := (main.lightened(0.18) if hl else main) * m
	var dark := main.darkened(0.55) * m
	RenderingServer.canvas_item_add_circle(item, c + Vector2(0, rad * 0.14), rad * 0.92, Color(0, 0, 0, 0.45 * m.a), true)
	match knob:
		"star":
			RenderingServer.canvas_item_add_circle(item, c, rad * 0.86, dark, true)
			RenderingServer.canvas_item_add_circle(item, c, rad * 0.74, face, true)
			RenderingServer.canvas_item_add_polygon(item, _star(c, rad * 0.56, rad * 0.24, 5), PackedColorArray([dark]))
		"seed":
			var pts := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				pts.append(c + Vector2(cos(a) * rad * 0.62, sin(a) * rad * 0.86))
			RenderingServer.canvas_item_add_polygon(item, pts, PackedColorArray([dark]))
			var inner := PackedVector2Array()
			for p: Vector2 in pts:
				inner.append(c + (p - c) * 0.8)
			RenderingServer.canvas_item_add_polygon(item, inner, PackedColorArray([face]))
			RenderingServer.canvas_item_add_line(item, c + Vector2(0, -rad * 0.5), c + Vector2(0, rad * 0.5), dark, maxf(rad * 0.1, 1.2), true)
		"rivet":
			RenderingServer.canvas_item_add_polygon(item, _ngon(c, rad * 0.88, 6, PI / 6.0), PackedColorArray([dark]))
			RenderingServer.canvas_item_add_polygon(item, _ngon(c, rad * 0.72, 6, PI / 6.0), PackedColorArray([face]))
			RenderingServer.canvas_item_add_circle(item, c, rad * 0.3, dark, true)
		"chip":
			RenderingServer.canvas_item_add_circle(item, c, rad * 0.88, Color("#B3261E") * m, true)
			for i in 6:
				var a := TAU * i / 6.0
				RenderingServer.canvas_item_add_line(item, c + Vector2.from_angle(a) * rad * 0.62, c + Vector2.from_angle(a) * rad * 0.86, Color("#FFF5E6") * m, maxf(rad * 0.22, 2.0))
			RenderingServer.canvas_item_add_circle(item, c, rad * 0.5, face, true)
		"hex":
			RenderingServer.canvas_item_add_polygon(item, _ngon(c, rad * 0.9, 6, 0.0), PackedColorArray([dark]))
			RenderingServer.canvas_item_add_polygon(item, _ngon(c, rad * 0.74, 6, 0.0), PackedColorArray([face]))
			RenderingServer.canvas_item_add_polygon(item, _ngon(c + Vector2(0, -rad * 0.08), rad * 0.34, 6, 0.0), PackedColorArray([face.lightened(0.3)]))
	# A small highlight dot (lit from the top left).
	RenderingServer.canvas_item_add_circle(item, c + Vector2(-rad * 0.3, -rad * 0.34), rad * 0.13, Color(1, 1, 1, 0.55 * m.a), true)


static func _star(c: Vector2, r_out: float, r_in: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := -PI / 2.0 + PI * i / n
		pts.append(c + Vector2.from_angle(a) * (r_out if i % 2 == 0 else r_in))
	return pts


static func _ngon(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(c + Vector2.from_angle(rot + TAU * i / n) * r)
	return pts

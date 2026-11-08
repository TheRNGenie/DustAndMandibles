class_name KitBox
extends StyleBox
## The one panel / button / chip shape of the UI kit, drawn as vectors so it stays
## sharp at every UI scale (menus grow 1.33x at 1440p, 2x at 4K):
##   a plate with cut ("ticket"), round or notched corners, a top-to-bottom
##   gradient fill, an optional tinted grain tile, an inner edge burn, a top lip
##   highlight, an outer rim, an inset rule (solid or stitched), corner studs, a
##   soft drop shadow or glow, an accent bar along one edge, and ornamental
##   "mandible" braces (the selection mark on hovered and focused buttons).
## Nothing here runs per frame: Godot keeps the drawn commands until the control
## changes size or theme. Layers are kept few (2 shadow, 3 glow, 2 burn passes)
## so a HUD full of plates stays cheap in draw calls.

enum Corner { CUT, ROUND, NOTCH, SQUARE }

@export var fill_top := Color(0.17, 0.12, 0.09)
@export var fill_bottom := Color(0.11, 0.08, 0.06)
@export var draw_fill := true
@export var corner: int = Corner.CUT
@export var corner_size := 8.0
## Which corners take the shape: bits TL=1, TR=2, BR=4, BL=8.
@export var corner_mask := 15
@export var grain: Texture2D
@export var grain_color := Color(0, 0, 0, 0.0)
@export var grain_scale := 1.0
@export var burn := Color(0, 0, 0, 0.0) ## inner edge darkening
@export var burn_size := 6.0
@export var lip := Color(1, 1, 1, 0.0) ## a lighter line just inside the top edge
@export var rim := Color(0, 0, 0, 0.0)
@export var rim_width := 1.5
@export var rule := Color(0, 0, 0, 0.0) ## inset line
@export var rule_inset := 4.0
@export var rule_width := 1.0
@export var rule_dash := 0.0 ## > 0: a stitched line (dash length; gap = dash * 0.8)
@export var studs := Color(0, 0, 0, 0.0) ## round studs in the four corners
@export var stud_radius := 2.2
@export var shadow := Color(0, 0, 0, 0.0)
@export var shadow_offset := Vector2(0, 3)
@export var shadow_size := 6.0
@export var glow := Color(0, 0, 0, 0.0) ## an outer glow (hover, the selected card)
@export var glow_size := 6.0
## A solid bar along one edge: 0 none, 1 left, 2 bottom, 3 top.
@export var bar_side := 0
@export var bar := Color(0, 0, 0, 0.0)
@export var bar_width := 3.0
@export var bar_inset := 0.0 ## how far the bar stops short of the ends (0..0.5 of the edge)
## The selection braces drawn just inside the left and right edges.
@export var braces := Color(0, 0, 0, 0.0)
@export var brace_width := 2.0
@export var expand := 0.0 ## draw this much outside the control's rect (focus marks)


func _draw(item: RID, rect: Rect2) -> void:
	var r := rect.grow(expand)
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	var cs := maxf(minf(corner_size, minf(r.size.x, r.size.y) * 0.5 - 0.5), 0.0) # (a full half would stack two points)
	if glow.a > 0.0:
		for i in 3:
			var g := glow_size * (3 - i) / 3.0
			var gc := glow
			gc.a = glow.a * 0.3
			var gr := r.grow(g)
			RenderingServer.canvas_item_add_polygon(item, outline(gr, minf(_grown(cs, g), minf(gr.size.x, gr.size.y) * 0.5 - 0.01)), PackedColorArray([gc]))
	if shadow.a > 0.0:
		for i in 2:
			var g := shadow_size * (2 - i) / 2.0 - shadow_size * 0.35
			var sc := shadow
			sc.a = shadow.a * 0.5
			var sr := Rect2(r.position + shadow_offset, r.size).grow(g)
			if sr.size.x < 2.0 or sr.size.y < 2.0:
				continue
			RenderingServer.canvas_item_add_polygon(item, outline(sr, minf(_grown(cs, g), minf(sr.size.x, sr.size.y) * 0.5 - 0.01)), PackedColorArray([sc]))
	var pts := outline(r, cs)
	if draw_fill:
		var cols := PackedColorArray()
		cols.resize(pts.size())
		for i in pts.size():
			cols[i] = fill_top.lerp(fill_bottom, clampf((pts[i].y - r.position.y) / r.size.y, 0.0, 1.0))
		RenderingServer.canvas_item_add_polygon(item, pts, cols)
		if grain != null and grain_color.a > 0.0:
			var px := grain.get_size() * grain_scale
			var uvs := PackedVector2Array()
			uvs.resize(pts.size())
			for i in pts.size():
				uvs[i] = (pts[i] - r.position) / px
			RenderingServer.canvas_item_set_default_texture_repeat(item, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
			RenderingServer.canvas_item_add_polygon(item, pts, PackedColorArray([grain_color]), uvs, grain.get_rid())
		if burn.a > 0.0:
			for i in 2:
				var d := burn_size * (0.3 + i * 0.6)
				var bc := burn
				bc.a = burn.a * (0.6 - i * 0.25)
				var br := r.grow(-d)
				if br.size.x > 2.0 and br.size.y > 2.0:
					_loop(item, outline(br, minf(_grown(cs, -d), minf(br.size.x, br.size.y) * 0.5 - 0.01)), bc, burn_size * 0.6)
		if lip.a > 0.0:
			var ly := r.position.y + 1.5
			var inset := cs if corner != Corner.SQUARE else 0.0
			RenderingServer.canvas_item_add_line(item, Vector2(r.position.x + inset + 1.0, ly), Vector2(r.end.x - inset - 1.0, ly), lip, 1.0, true)
	if bar_side > 0 and bar.a > 0.0:
		_bar(item, r, cs)
	if rim.a > 0.0:
		_loop(item, pts, rim, rim_width)
	elif draw_fill:
		_loop(item, pts, fill_top.lerp(fill_bottom, 0.5), 1.0) # smooths the cut edges
	if rule.a > 0.0:
		var ri := outline(r.grow(-rule_inset), _grown(cs, -rule_inset))
		if rule_dash > 0.0:
			_dashes(item, ri, rule, rule_width, rule_dash)
		else:
			_loop(item, ri, rule, rule_width)
	if studs.a > 0.0:
		var k := rule_inset + stud_radius + 1.5 + (cs * 0.35 if corner != Corner.SQUARE else 0.0)
		for p: Vector2 in [r.position + Vector2(k, k), Vector2(r.end.x - k, r.position.y + k), r.end - Vector2(k, k), Vector2(r.position.x + k, r.end.y - k)]:
			RenderingServer.canvas_item_add_circle(item, p, stud_radius, studs, true)
			RenderingServer.canvas_item_add_circle(item, p - Vector2(stud_radius, stud_radius) * 0.3, stud_radius * 0.38, studs.lightened(0.55), true)
	if braces.a > 0.0:
		_braces(item, r)


## The plate's outline, clockwise from the top-left, for a rect and corner size.
func outline(r: Rect2, cs: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cornerpts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var outs := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	for i in 4:
		var p: Vector2 = cornerpts[i]
		var out_d: Vector2 = outs[i]
		var in_d: Vector2 = outs[(i + 3) % 4]
		if corner == Corner.SQUARE or cs <= 0.5 or (corner_mask & (1 << i)) == 0:
			pts.append(p)
			continue
		var a := p - in_d * cs
		var b := p + out_d * cs
		match corner:
			Corner.CUT:
				pts.append(a)
				pts.append(b)
			Corner.ROUND:
				var ctr := a + out_d * cs
				var a0 := (-out_d).angle()
				var dl := wrapf(in_d.angle() - a0, -PI, PI)
				var seg := clampi(int(cs * 0.6), 3, 10)
				for s in seg + 1:
					pts.append(ctr + Vector2.from_angle(a0 + dl * s / seg) * cs)
			Corner.NOTCH:
				var a1 := (-in_d).angle()
				var dl2 := wrapf(out_d.angle() - a1, -PI, PI)
				var seg2 := clampi(int(cs * 0.6), 3, 10)
				for s in seg2 + 1:
					pts.append(p + Vector2.from_angle(a1 + dl2 * s / seg2) * cs)
	return pts


## The corner size of the same shape grown by `g` (negative: inset).
func _grown(cs: float, g: float) -> float:
	match corner:
		Corner.CUT: return maxf(cs + g * 0.586, 0.0)
		Corner.ROUND: return maxf(cs + g, 0.0)
		Corner.NOTCH: return maxf(cs - g, 0.0)
	return 0.0


func _loop(item: RID, pts: PackedVector2Array, col: Color, width: float) -> void:
	if pts.size() < 3:
		return
	var closed := pts.duplicate()
	closed.append(pts[0])
	if pts.size() > 1:
		closed.append(pts[1]) # (one segment past the start closes the joint cleanly)
	RenderingServer.canvas_item_add_polyline(item, closed, PackedColorArray([col]), width, true)


func _dashes(item: RID, pts: PackedVector2Array, col: Color, width: float, dash: float) -> void:
	var segs := PackedVector2Array()
	var gap := dash * 0.8
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var len := a.distance_to(b)
		if len < 0.5:
			continue
		var dir := (b - a) / len
		var t := gap * 0.5
		while t < len:
			var e := minf(t + dash, len)
			segs.append(a + dir * t)
			segs.append(a + dir * e)
			t = e + gap
	if not segs.is_empty():
		RenderingServer.canvas_item_add_multiline(item, segs, PackedColorArray([col]), width, true)


func _bar(item: RID, r: Rect2, cs: float) -> void:
	var w := bar_width
	var q: Rect2
	match bar_side:
		1: q = Rect2(r.position.x, r.position.y + r.size.y * bar_inset, w, r.size.y * (1.0 - bar_inset * 2.0))
		2: q = Rect2(r.position.x + r.size.x * bar_inset + (cs if bar_inset == 0.0 else 0.0) * 0.6, r.end.y - w, r.size.x * (1.0 - bar_inset * 2.0) - (cs * 1.2 if bar_inset == 0.0 else 0.0), w)
		3: q = Rect2(r.position.x + r.size.x * bar_inset + (cs if bar_inset == 0.0 else 0.0) * 0.6, r.position.y, r.size.x * (1.0 - bar_inset * 2.0) - (cs * 1.2 if bar_inset == 0.0 else 0.0), w)
		_: return
	RenderingServer.canvas_item_add_rect(item, q, bar)


## Two ornamental braces facing the content: curved jaws that meet in a point,
## like a beetle's mandibles (the kit's selection mark).
func _braces(item: RID, r: Rect2) -> void:
	var h := clampf(r.size.y * 0.62, 12.0, 44.0)
	var w := clampf(h * 0.24, 4.0, 9.0)
	var cy := r.get_center().y
	var inset := 6.0 + brace_width
	for side: int in [-1, 1]:
		var x0 := (r.position.x + inset) if side < 0 else (r.end.x - inset)
		var dir := float(-side) # +1 points right (into the box) on the left side
		var pts := PackedVector2Array()
		var steps := 10
		for i in steps + 1:
			var t := float(i) / steps # 0 top .. 1 bottom
			var yy := cy + (t - 0.5) * h
			# A jaw: bulges outward at the ends, comes to a point inward at the middle.
			var k := absf(t - 0.5) * 2.0 # 1 at the ends, 0 at the middle
			var xx := x0 + dir * (w * k * k * 0.9 - w * 0.35)
			pts.append(Vector2(xx, yy))
		RenderingServer.canvas_item_add_polyline(item, pts, PackedColorArray([braces]), brace_width, true)
		# The jaw's tooth: a small solid point from the middle of the curve, inward.
		var base := Vector2(x0 - dir * (w * 0.35 + brace_width * 0.3), cy)
		var tip := Vector2(x0 + dir * (w * 0.35 + 3.0), cy)
		RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([base + Vector2(0, -3.0), tip, base + Vector2(0, 3.0)]), PackedColorArray([braces]))
		# Barbed tips at both ends (the jaws close on what you picked).
		for e: int in [0, steps]:
			var p := pts[e]
			var inward := Vector2(dir, 0.0)
			var along := Vector2(0, -1.0 if e == 0 else 1.0)
			RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([p - along * 1.5, p + inward * 3.2 - along * 2.2, p + along * 1.2]), PackedColorArray([braces]))


## A copy with every setting (shared boxes are filled in place from these).
func copy_from(o: KitBox) -> void:
	for p: Dictionary in o.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			set(StringName(p["name"]), o.get(StringName(p["name"])))
	content_margin_left = o.content_margin_left
	content_margin_right = o.content_margin_right
	content_margin_top = o.content_margin_top
	content_margin_bottom = o.content_margin_bottom
	emit_changed()


## Settings from a dictionary of the exported names above (plus "margin":
## [h, v] or [left, top, right, bottom]); unnamed ones keep their defaults.
static func make(spec: Dictionary) -> KitBox:
	var b := KitBox.new()
	b.apply_spec(spec)
	return b


func apply_spec(spec: Dictionary) -> void:
	for k: String in spec:
		if k == "margin":
			var m: Array = spec[k]
			if m.size() == 2:
				content_margin_left = m[0]
				content_margin_right = m[0]
				content_margin_top = m[1]
				content_margin_bottom = m[1]
			else:
				content_margin_left = m[0]
				content_margin_top = m[1]
				content_margin_right = m[2]
				content_margin_bottom = m[3]
		else:
			set(StringName(k), spec[k])
	emit_changed()

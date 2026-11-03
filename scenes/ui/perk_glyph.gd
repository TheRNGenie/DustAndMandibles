class_name PerkGlyph
extends Control
## A small drawn emblem for a perk (no textures or font glyphs): simple shapes
## in one ink colour, like a brand burned into wood. "item:<id>" draws the
## hotbar's item icon instead (revolver, corn, herbs...). "brand" is the
## Rancher's Ledger's own mark (Brands).

var glyph := ""
var ink := Color("#F2E3C2")
var _item: Control


func _init(g: String = "", color: Color = Color("#F2E3C2")) -> void:
	glyph = g
	ink = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if glyph.begins_with("item:"):
		var ic := HudHotbar.ItemIcon.new()
		ic.item = StringName(glyph.substr(5))
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ic)
		_item = ic


func _draw() -> void:
	if _item != null:
		return
	var c := size * 0.5
	var s := minf(size.x, size.y) * 0.42
	var w := maxf(s * 0.13, 2.0)
	var k := ink
	match glyph:
		"hourglass":
			_poly([c + Vector2(-s * 0.6, -s), c + Vector2(s * 0.6, -s), c + Vector2(0, 0)], k)
			_poly([c + Vector2(-s * 0.6, s), c + Vector2(s * 0.6, s), c + Vector2(0, 0)], k.darkened(0.25))
			draw_line(c + Vector2(-s * 0.75, -s), c + Vector2(s * 0.75, -s), k, w)
			draw_line(c + Vector2(-s * 0.75, s), c + Vector2(s * 0.75, s), k, w)
		"crosshair":
			draw_arc(c, s * 0.75, 0, TAU, 32, k, w)
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * s * 0.3, c + d * s, k, w)
			draw_circle(c, w * 0.7, k)
		"bolt":
			_poly([c + Vector2(s * 0.2, -s), c + Vector2(-s * 0.5, s * 0.1), c + Vector2(-s * 0.05, s * 0.1),
				c + Vector2(-s * 0.25, s), c + Vector2(s * 0.5, -s * 0.15), c + Vector2(s * 0.05, -s * 0.15)], k)
		"bullets":
			for i in 3:
				var x := (i - 1) * s * 0.55
				draw_rect(Rect2(c + Vector2(x - s * 0.17, -s * 0.2), Vector2(s * 0.34, s * 1.1)), k.darkened(0.2))
				_poly([c + Vector2(x - s * 0.17, -s * 0.2), c + Vector2(x + s * 0.17, -s * 0.2), c + Vector2(x, -s * 0.85)], k)
		"eye":
			var pts: Array[Vector2] = []
			for i in 17:
				var t := float(i) / 16.0
				pts.append(c + Vector2(lerpf(-s, s, t), -sin(t * PI) * s * 0.55))
			for i in range(15, 0, -1):
				var t := float(i) / 16.0
				pts.append(c + Vector2(lerpf(-s, s, t), sin(t * PI) * s * 0.55))
			_poly(pts, k)
			draw_circle(c, s * 0.3, Palette.WOOD_DARK)
			draw_circle(c, s * 0.14, k)
		"refund":
			draw_arc(c, s * 0.75, -PI * 0.15, PI * 1.45, 28, k, w * 1.2)
			var tip := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * s * 0.75
			_poly([tip + Vector2(-s * 0.32, -s * 0.05), tip + Vector2(s * 0.12, -s * 0.38), tip + Vector2(s * 0.18, s * 0.12)], k)
			draw_rect(Rect2(c + Vector2(-s * 0.12, -s * 0.25), Vector2(s * 0.24, s * 0.55)), k)
		"whip":
			var prev := c + Vector2(-s * 0.8, s * 0.8)
			draw_line(prev, prev + Vector2(s * 0.35, -s * 0.35), k, w * 2.0)
			prev += Vector2(s * 0.35, -s * 0.35)
			for i in 12:
				var t := float(i + 1) / 12.0
				var p := c + Vector2(-s * 0.45 + t * s * 1.4, -s * 0.45 + sin(t * 5.0) * s * 0.45 - t * s * 0.3)
				draw_line(prev, p, k, lerpf(w * 1.4, w * 0.5, t))
				prev = p
		"tag":
			_poly([c + Vector2(-s, -s * 0.45), c + Vector2(s * 0.45, -s * 0.45), c + Vector2(s, 0), c + Vector2(s * 0.45, s * 0.45),
				c + Vector2(-s, s * 0.45)], k)
			draw_circle(c + Vector2(s * 0.42, 0), s * 0.12, Palette.WOOD_DARK)
			draw_line(c + Vector2(-s * 0.7, -s * 0.15), c + Vector2(-s * 0.1, -s * 0.15), Palette.WOOD_DARK, w)
			draw_line(c + Vector2(-s * 0.7, s * 0.15), c + Vector2(-s * 0.25, s * 0.15), Palette.WOOD_DARK, w)
		"sprout":
			draw_line(c + Vector2(0, s), c + Vector2(0, -s * 0.2), k, w * 1.2)
			_leaf(c + Vector2(0, -s * 0.1), Vector2(-s * 0.85, -s * 0.55), k)
			_leaf(c + Vector2(0, -s * 0.3), Vector2(s * 0.75, -s * 0.75), k)
			draw_line(c + Vector2(-s * 0.7, s), c + Vector2(s * 0.7, s), k.darkened(0.2), w)
		"drop":
			var pts: Array[Vector2] = [c + Vector2(0, -s)]
			for i in 13:
				var a := PI * 0.15 - float(i) / 12.0 * PI * 1.3
				pts.append(c + Vector2(0, s * 0.3) + Vector2(cos(a), -sin(a)) * s * 0.6)
			_poly(pts, k)
			draw_arc(c + Vector2(0, s * 0.3), s * 0.35, PI * 0.55, PI * 0.95, 8, Palette.WOOD_DARK, w * 0.8)
		"plot":
			_poly([c + Vector2(-s, s * 0.1), c + Vector2(0, -s * 0.5), c + Vector2(s, s * 0.1), c + Vector2(0, s * 0.7)], k.darkened(0.3))
			for i in 3:
				var o := (i - 1) * s * 0.4
				draw_line(c + Vector2(-s * 0.55 + o, s * 0.1 - o * 0.6 + s * 0.05), c + Vector2(s * 0.05 + o, s * 0.45 - o * 0.6 - s * 0.3), k, w)
			_leaf(c + Vector2(0, -s * 0.3), Vector2(-s * 0.4, -s * 0.5), k)
			_leaf(c + Vector2(0, -s * 0.3), Vector2(s * 0.4, -s * 0.5), k)
		"sack":
			_poly([c + Vector2(-s * 0.25, -s * 0.55), c + Vector2(s * 0.25, -s * 0.55), c + Vector2(s * 0.8, s * 0.3), c + Vector2(s * 0.6, s),
				c + Vector2(-s * 0.6, s), c + Vector2(-s * 0.8, s * 0.3)], k)
			_poly([c + Vector2(-s * 0.35, -s * 0.95), c + Vector2(s * 0.35, -s * 0.95), c + Vector2(s * 0.2, -s * 0.55), c + Vector2(-s * 0.2, -s * 0.55)], k.darkened(0.2))
			draw_line(c + Vector2(-s * 0.3, -s * 0.55), c + Vector2(s * 0.3, -s * 0.55), Palette.WOOD_DARK, w)
		"house":
			_poly([c + Vector2(-s, -s * 0.05), c + Vector2(0, -s), c + Vector2(s, -s * 0.05)], k)
			draw_rect(Rect2(c + Vector2(-s * 0.72, -s * 0.05), Vector2(s * 1.44, s * 1.0)), k.darkened(0.15))
			draw_rect(Rect2(c + Vector2(-s * 0.18, s * 0.35), Vector2(s * 0.36, s * 0.6)), Palette.WOOD_DARK)
		"shield":
			_poly([c + Vector2(-s * 0.8, -s * 0.8), c + Vector2(s * 0.8, -s * 0.8), c + Vector2(s * 0.75, s * 0.1), c + Vector2(0, s),
				c + Vector2(-s * 0.75, s * 0.1)], k)
			draw_line(c + Vector2(0, -s * 0.6), c + Vector2(0, s * 0.65), Palette.WOOD_DARK, w)
			draw_line(c + Vector2(-s * 0.55, -s * 0.15), c + Vector2(s * 0.55, -s * 0.15), Palette.WOOD_DARK, w)
		"canteen":
			draw_circle(c + Vector2(0, s * 0.15), s * 0.75, k)
			draw_circle(c + Vector2(0, s * 0.15), s * 0.5, k.darkened(0.2))
			draw_rect(Rect2(c + Vector2(-s * 0.15, -s), Vector2(s * 0.3, s * 0.4)), k)
			draw_arc(c + Vector2(0, -s * 0.2), s * 0.95, PI * 1.15, PI * 1.85, 12, k, w * 0.8)
		"heart":
			draw_circle(c + Vector2(-s * 0.42, -s * 0.25), s * 0.48, k)
			draw_circle(c + Vector2(s * 0.42, -s * 0.25), s * 0.48, k)
			_poly([c + Vector2(-s * 0.88, -s * 0.1), c + Vector2(s * 0.88, -s * 0.1), c + Vector2(0, s * 0.95)], k)
			draw_line(c + Vector2(-s * 0.5, s * 0.05), c + Vector2(s * 0.3, -s * 0.35), Palette.WOOD_DARK, w)
		"spur":
			for i in 8:
				var a := TAU * i / 8.0
				_poly([c + Vector2(cos(a), sin(a)) * s, c + Vector2(cos(a + 0.35), sin(a + 0.35)) * s * 0.35,
					c + Vector2(cos(a - 0.35), sin(a - 0.35)) * s * 0.35], k)
			draw_circle(c, s * 0.3, k)
			draw_circle(c, s * 0.13, Palette.WOOD_DARK)
		"boot":
			_poly([c + Vector2(-s * 0.35, -s), c + Vector2(s * 0.25, -s), c + Vector2(s * 0.25, s * 0.25), c + Vector2(s * 0.95, s * 0.45),
				c + Vector2(s * 0.95, s * 0.8), c + Vector2(-s * 0.45, s * 0.8)], k)
			draw_line(c + Vector2(-s * 0.95, -s * 0.3), c + Vector2(-s * 0.55, -s * 0.3), k, w)
			draw_line(c + Vector2(-s * 1.0, 0), c + Vector2(-s * 0.55, 0), k, w)
			draw_line(c + Vector2(-s * 0.9, s * 0.3), c + Vector2(-s * 0.55, s * 0.3), k, w)
		"star", "brand":
			var pts: Array[Vector2] = []
			for i in 10:
				var a := -PI * 0.5 + TAU * i / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else s * 0.45))
			_poly(pts, k)
			if glyph == "brand":
				draw_arc(c, s * 1.05, 0, TAU, 32, k, w)
		"planks":
			for i in 3:
				var y := (i - 1) * s * 0.62
				draw_rect(Rect2(c + Vector2(-s, y - s * 0.24), Vector2(s * 2.0, s * 0.48)), k if i != 1 else k.darkened(0.15))
				draw_circle(c + Vector2(-s * 0.75, y), w * 0.6, Palette.WOOD_DARK)
				draw_circle(c + Vector2(s * 0.75, y), w * 0.6, Palette.WOOD_DARK)
		"chevrons":
			for i in 3:
				var y := s * 0.6 - i * s * 0.55
				_poly([c + Vector2(-s * 0.85, y + s * 0.25), c + Vector2(0, y - s * 0.3), c + Vector2(s * 0.85, y + s * 0.25),
					c + Vector2(s * 0.85, y + s * 0.5), c + Vector2(0, y - s * 0.05), c + Vector2(-s * 0.85, y + s * 0.5)], k)
		"scaffold":
			for x: float in [-0.65, 0.65]:
				draw_line(c + Vector2(s * x, -s), c + Vector2(s * x, s), k, w * 1.3)
			for y: float in [-0.85, 0.0, 0.85]:
				draw_line(c + Vector2(-s * 0.8, s * y), c + Vector2(s * 0.8, s * y), k, w * 1.3)
			draw_line(c + Vector2(-s * 0.65, -s * 0.85), c + Vector2(s * 0.65, 0), k, w * 0.8)
			draw_line(c + Vector2(-s * 0.65, s * 0.85), c + Vector2(s * 0.65, 0), k, w * 0.8)
		"spyglass":
			var a := Vector2(-s * 0.9, s * 0.55)
			var b := Vector2(s * 0.9, -s * 0.55)
			var dir := (b - a).normalized()
			var n := Vector2(-dir.y, dir.x)
			_poly([c + a + n * s * 0.16, c + a + dir * s * 0.7 + n * s * 0.16, c + a + dir * s * 0.7 - n * s * 0.16, c + a - n * s * 0.16], k.darkened(0.2))
			_poly([c + a + dir * s * 0.7 + n * s * 0.24, c + b + n * s * 0.34, c + b - n * s * 0.34, c + a + dir * s * 0.7 - n * s * 0.24], k)
			draw_line(c + a + dir * s * 1.2 + n * s * 0.3, c + a + dir * s * 1.2 - n * s * 0.3, Palette.WOOD_DARK, w)
		"gear":
			for i in 8:
				var ang := TAU * i / 8.0
				var d := Vector2(cos(ang), sin(ang))
				var t := Vector2(-d.y, d.x)
				_poly([c + d * s * 0.6 + t * s * 0.17, c + d * s + t * s * 0.12, c + d * s - t * s * 0.12, c + d * s * 0.6 - t * s * 0.17], k)
			draw_circle(c, s * 0.68, k)
			draw_circle(c, s * 0.25, Palette.WOOD_DARK)
		"bolts":
			for p: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
				var at := c + p * s * 1.15
				var hex: Array[Vector2] = []
				for i in 6:
					var ang := TAU * i / 6.0
					hex.append(at + Vector2(cos(ang), sin(ang)) * s * 0.36)
				_poly(hex, k)
				draw_circle(at, s * 0.12, Palette.WOOD_DARK)
		"wrench":
			draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.35, -s * 0.35), k, w * 2.4)
			draw_circle(c + Vector2(s * 0.5, -s * 0.5), s * 0.42, k)
			_poly([c + Vector2(s * 0.5, -s * 0.5), c + Vector2(s * 1.0, -s * 0.75), c + Vector2(s * 0.75, -s * 1.0)], Palette.WOOD_DARK)
			draw_circle(c + Vector2(-s * 0.7, s * 0.7), s * 0.2, k)
		"hammer":
			draw_line(c + Vector2(-s * 0.7, s * 0.85), c + Vector2(s * 0.25, -s * 0.15), k.darkened(0.2), w * 2.0)
			var hd := Vector2(s * 0.35, -s * 0.3)
			_poly([c + hd + Vector2(-s * 0.75, -s * 0.15), c + hd + Vector2(-s * 0.15, -s * 0.75), c + hd + Vector2(s * 0.25, -s * 0.35),
				c + hd + Vector2(-s * 0.35, s * 0.25)], k)
		"crate":
			draw_rect(Rect2(c - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), k)
			draw_rect(Rect2(c - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), Palette.WOOD_DARK, false, w)
			draw_line(c + Vector2(-s * 0.85, -s * 0.85), c + Vector2(s * 0.85, s * 0.85), Palette.WOOD_DARK, w)
			draw_line(c + Vector2(-s * 0.85, s * 0.85), c + Vector2(s * 0.85, -s * 0.85), Palette.WOOD_DARK, w)
		"horseshoe":
			draw_arc(c + Vector2(0, -s * 0.1), s * 0.72, PI * 0.82, PI * 2.18, 24, k, w * 2.6)
			for x: float in [-0.66, 0.66]:
				draw_line(c + Vector2(s * x, s * 0.2), c + Vector2(s * x * 0.95, s * 0.9), k, w * 2.6)
			for i in 5:
				var ang := PI * (0.95 + 0.275 * i)
				draw_circle(c + Vector2(0, -s * 0.1) + Vector2(cos(ang), sin(ang)) * s * 0.72, w * 0.45, Palette.WOOD_DARK)
		"moon":
			draw_circle(c, s * 0.9, k)
			draw_circle(c + Vector2(s * 0.42, -s * 0.3), s * 0.75, Palette.WOOD_DARK)
			draw_circle(c + Vector2(s * 0.75, s * 0.55), s * 0.1, k)
		"magnet":
			draw_arc(c + Vector2(0, -s * 0.15), s * 0.6, PI, TAU, 18, k, w * 3.0)
			for x: float in [-0.6, 0.6]:
				draw_line(c + Vector2(s * x, -s * 0.15), c + Vector2(s * x, s * 0.55), k, w * 3.0)
				draw_line(c + Vector2(s * x, s * 0.55), c + Vector2(s * x, s * 0.95), k.darkened(0.35), w * 3.0)
		_:
			draw_circle(c, s * 0.6, k)


func _poly(pts: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), color)


func _leaf(base: Vector2, tip: Vector2, color: Color) -> void:
	var n := Vector2(-tip.y, tip.x).normalized() * tip.length() * 0.28
	_poly([base, base + tip * 0.5 + n, base + tip, base + tip * 0.5 - n], color)

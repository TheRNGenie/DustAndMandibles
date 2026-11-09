class_name CropChip
extends Control
## A crop's small round badge: a dark disc ringed in the crop's colour with the
## crop inside. Corn, chili, pear and herbs use their painted icons; the other
## five are drawn here, since their sack icons blur together at this size.
## Used beside a turret's name for the kills it made with that crop (the turret
## card and the wave summary).

## Painted produce icons (assets/icons) by crop.
const PAINTED: Dictionary = {&"corn": "corn", &"firecracker_chili": "chili", &"prickly_pear": "prickly_pear", &"herbs": "herbs"}
const INK := Color(0.12, 0.08, 0.05)

var crop: StringName = &""
var _tex: Texture2D


static func make(crop_id: StringName, px: int) -> CropChip:
	var c := CropChip.new()
	c.crop = crop_id
	c.custom_minimum_size = Vector2(px, px)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.tooltip_text = CropEffects.short_name(crop_id)
	var path := "res://assets/icons/%s.png" % PAINTED.get(crop_id, "")
	if PAINTED.has(crop_id) and ResourceLoader.exists(path):
		c._tex = load(path)
	return c


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var col := CropEffects.color_of(crop)
	draw_circle(c, s * 0.5, Color(0, 0, 0, 0.45))
	draw_circle(c, s * 0.5 - 1.0, col.darkened(0.62))
	draw_arc(c, s * 0.5 - 1.6, 0, TAU, 32, col, maxf(1.5, s * 0.08), true)
	if _tex != null:
		var inner := s * 0.74
		draw_texture_rect(_tex, Rect2(c - Vector2(inner, inner) * 0.5, Vector2(inner, inner)), false)
		return
	# Drawn on a 26 px grid, scaled to the chip.
	draw_set_transform(c, 0.0, Vector2(s / 26.0, s / 26.0))
	match crop:
		&"cotton":
			draw_line(Vector2(0, 3), Vector2(0, 8), Color("#6B4A2A"), 1.6, true)
			for p: Vector2 in [Vector2(-3.6, 4.4), Vector2(3.6, 4.4)]:
				_blob(p + Vector2(0, -1), 2.2, Color("#5E7A3A"))
			for p: Vector2 in [Vector2(-3.4, -0.6), Vector2(3.4, -0.6), Vector2(0, -3.6), Vector2(0, 1.2)]:
				_blob(p, 3.7, Color("#F7F3E3"))
		&"sulfur_root":
			# A knobbly ochre root under a pale crystal.
			var root := PackedVector2Array([Vector2(-4.5, -1), Vector2(4.5, -1), Vector2(1.2, 9), Vector2(-0.6, 9)])
			_poly(root, Color("#B8860B"))
			draw_line(Vector2(-2, 2.5), Vector2(2.4, 3.4), INK, 0.9, true)
			draw_line(Vector2(-1, 5.5), Vector2(1.4, 6.2), INK, 0.9, true)
			var gem := PackedVector2Array([Vector2(0, -9), Vector2(4.2, -4.5), Vector2(2.4, -0.5), Vector2(-2.4, -0.5), Vector2(-4.2, -4.5)])
			_poly(gem, Color("#F2E64B"))
			draw_line(Vector2(0, -9), Vector2(0, -0.5), Color("#C9B92A"), 1.0, true)
		&"barrel_cactus":
			# A ribbed green barrel with a flower on top.
			_blob(Vector2(0, 1.5), 7.2, Color("#3E8E3E"))
			for x: float in [-3.5, 0.0, 3.5]:
				draw_line(Vector2(x * 0.9, -4.4), Vector2(x, 7.6), Color("#245C27"), 1.1, true)
			for a in 5:
				var d := Vector2.from_angle(TAU * a / 5.0 - PI * 0.5) * 2.0
				_blob(Vector2(0, -6.2) + d, 1.5, Color("#F06AA8"))
			draw_circle(Vector2(0, -6.2), 1.1, Color("#FFD84A"))
		&"tumbleweed_vine":
			# A dry tangle ball with a green sprig.
			_blob(Vector2(0, 0.5), 7.6, Color("#C9A26B"))
			for k in 5:
				var a := float(k) * 1.37
				draw_arc(Vector2(cos(a), sin(a)) * 2.2 + Vector2(0, 0.5), 4.6, a, a + 3.6, 10, Color("#7A5A32"), 1.0, true)
			_poly(PackedVector2Array([Vector2(4.5, -6.5), Vector2(9, -9.5), Vector2(7.5, -4.5)]), Color("#6BAE3C"))
		&"sarsaparilla":
			# A heart leaf on a knobbly root.
			draw_line(Vector2(0, 0), Vector2(1.5, 9), Color("#7A4A26"), 2.4, true)
			draw_circle(Vector2(1.0, 5.5), 1.4, Color("#7A4A26"))
			var leaf := PackedVector2Array()
			for i in 24:
				var t := TAU * float(i) / 24.0
				leaf.append(Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * 0.42 + Vector2(0, -3))
			_poly(leaf, Color("#3FA34D"))
			draw_line(Vector2(0, -6.5), Vector2(0, 2.0), Color("#2A7334"), 0.9, true)
		_:
			_blob(Vector2.ZERO, 5.0, col)
	draw_set_transform(Vector2.ZERO)


## A filled circle with an ink rim.
func _blob(at: Vector2, r: float, fill: Color) -> void:
	draw_circle(at, r + 0.8, INK)
	draw_circle(at, r, fill)


## A filled polygon with an ink rim.
func _poly(pts: PackedVector2Array, fill: Color) -> void:
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, INK, 1.6, true)
	draw_colored_polygon(pts, fill)

class_name ChipIcon
extends Control
## A casino chip drawn flat (CasinoBoard's colours), with a number in the
## middle: on the HUD it's how many of that chip you hold.

var value := 10
var count := 0


func _init() -> void:
	custom_minimum_size = Vector2(34, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_count(n: int) -> void:
	if n != count:
		count = n
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.46
	var col := CasinoBoard.chip_color(value)
	draw_circle(c + Vector2(1, 2), r, Color(0, 0, 0, 0.4))
	draw_circle(c, r, col)
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := c + Vector2(cos(a), sin(a)) * r * 0.8
		draw_set_transform(p, a, Vector2.ONE)
		draw_rect(Rect2(-r * 0.12, -r * 0.2, r * 0.24, r * 0.4), Color(1, 1, 1, 0.9))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_circle(c, r * 0.6, Color(1, 1, 1, 0.95) if value < 100 else Color("#E9C46A"))
	draw_arc(c, r, 0, TAU, 28, Palette.OUTLINE, 1.5, true)
	var font := get_theme_default_font()
	var fs := int(r * (0.85 if count < 100 else 0.62))
	var txt := str(count)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#1E1A18"))


## The chip as a texture (menu rows), drawn once per value.
static var _tex: Dictionary = {}


static func texture(v: int) -> Texture2D:
	if _tex.has(v):
		return _tex[v]
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var col := CasinoBoard.chip_color(v)
	var inner := Color(1, 1, 1, 0.95) if v < 100 else Color("#E9C46A")
	var c := Vector2(n, n) * 0.5
	var r := n * 0.46
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var d := p.length()
			if d > r + 1.0:
				continue
			var px := col
			if d < r * 0.6:
				px = inner
			elif d > r * 0.62 and d < r * 0.95:
				var a := fposmod(p.angle() - 0.3, TAU / 6.0)
				if a < 0.18 or a > TAU / 6.0 - 0.18:
					px = Color(1, 1, 1, 0.9)
			if d > r - 1.5:
				px = Palette.OUTLINE
			px.a *= clampf(r + 1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, px)
	var t := ImageTexture.create_from_image(img)
	_tex[v] = t
	return t

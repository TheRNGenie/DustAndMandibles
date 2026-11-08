class_name LoadingVista
extends LoadingScreen
## Canyon Silhouette Vista: four planes of canyon country (far mesas, buttes,
## the near rim, a foreground ledge with a dead tree), each drifting sideways
## at its own pace, under a sky in one of four palettes: amber sunset, purple
## dusk, pale dawn, or blood-red dust storm. Dust motes float across the front.
## The loading indicator is a lit dynamite fuse burning left to right along the
## bottom toward a bundle of dynamite, sparks spitting off the flame.

## [sky top, sky horizon, sun, far, mid, near, front, haze]
const PALETTES: Dictionary = {
	&"sunset": [Color("#3A1E3A"), Color("#F29A4A"), Color("#FFE0A0"), Color("#B0604A"), Color("#7A3A34"), Color("#4A2228"), Color("#1E1014"), Color("#F2A060")],
	&"dusk": [Color("#1E1838"), Color("#8A5A8A"), Color("#F0B8C0"), Color("#5E4670"), Color("#3E2E54"), Color("#281E3C"), Color("#120E1E"), Color("#9A6A9A")],
	&"dawn": [Color("#7A9AC0"), Color("#F4DCC0"), Color("#FFF6E0"), Color("#C4A8A0"), Color("#9A7A78"), Color("#6A5054"), Color("#2E2226"), Color("#F0D8C8")],
	&"storm": [Color("#3A120E"), Color("#C2502E"), Color("#FFB070"), Color("#8A3424"), Color("#5E2018"), Color("#3A140E"), Color("#1A0806"), Color("#D06A3A")],
}

var _pal: Array = []
var _layers: Array = [] # [PackedFloat32Array heights, speed, colour index, base y]
var _motes: Array[Vector3] = []
var _sparks: Array = [] # [pos, vel, life]
var _palette_id: StringName = &"sunset"


func _build() -> void:
	_palette_id = _choose_palette()
	_pal = PALETTES[_palette_id]
	# Each plane: a long strip of heights (it scrolls and wraps), mesa-topped
	# far away, buttes and spires in the middle, a broken rim up close.
	_layers = [
		[_ridge(240, 0.012, 0.35, true), 4.0, 3, 0.6],
		[_ridge(200, 0.03, 0.5, true), 9.0, 4, 0.68],
		[_ridge(160, 0.05, 0.6, false), 18.0, 5, 0.78],
		[_ridge(120, 0.08, 0.4, false), 34.0, 6, 0.9],
	]
	for i in 70:
		_motes.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.4, 1.0)))


## Sky by what's loading: a story chapter keeps its own hour, the menu gets
## dawn, a dust or storm wave the red storm sky, otherwise a sunset or dusk.
func _choose_palette() -> StringName:
	match str(ctx.get("to", "")):
		"first":
			return &"dawn"
		"menu":
			return &"dusk"
	var ch := int(ctx.get("chapter", 0))
	if ch > 0:
		return [&"dawn", &"sunset", &"dusk", &"storm"][(ch - 1) % 4]
	return [&"sunset", &"dusk", &"storm", &"sunset"][rng.randi() % 4]


## Heights (0..1 of the plane's height) along a strip of `n` samples: flat-topped
## mesas when `mesa`, steps and spires otherwise.
func _ridge(n: int, rough: float, amp: float, mesa: bool) -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.035 if mesa else 0.06
	var h := PackedFloat32Array()
	h.resize(n)
	for i in n:
		# Sample round a circle so the strip wraps seamlessly.
		var a := TAU * float(i) / n
		var v := noise.get_noise_2d(cos(a) * n / TAU, sin(a) * n / TAU) * 0.5 + 0.5
		if mesa:
			v = 0.25 + 0.75 * smoothstep(0.42, 0.55, v) # flat tops, steep sides
			v = floor(v * 4.0) / 4.0 * 0.85 + v * 0.15
		else:
			v = pow(v, 1.6)
		h[i] = clampf(v * amp + noise.get_noise_1d(i * 7.0) * rough, 0.0, 1.0)
	return h


func _tick(delta: float) -> void:
	# Sparks off the fuse's flame.
	var flame := _flame_pos()
	for i in 2:
		_sparks.append([flame, Vector2(rng.randf_range(-120, 60), rng.randf_range(-220, -60)) * sc(), rng.randf_range(0.25, 0.6)])
	for sp: Array in _sparks:
		sp[1] = (sp[1] as Vector2) + Vector2(0, 520.0 * sc()) * delta
		sp[0] = (sp[0] as Vector2) + (sp[1] as Vector2) * delta
		sp[2] = float(sp[2]) - delta
	_sparks = _sparks.filter(func(sp: Array) -> bool: return float(sp[2]) > 0.0)


func _fuse_y() -> float:
	return size.y - 70.0 * sc()


func _fuse_x(k: float) -> float:
	return lerpf(110.0 * sc(), size.x - 230.0 * sc(), k)


func _fuse_at(x: float) -> float:
	return _fuse_y() + sin(x * 0.02 / sc()) * 6.0 * sc() + sin(x * 0.007 / sc() + 1.0) * 4.0 * sc()


func _flame_pos() -> Vector2:
	var x := _fuse_x(shown)
	return Vector2(x, _fuse_at(x))


func _draw() -> void:
	var s := sc()
	# Sky: a vertical gradient, the sun low on the horizon, haze above the land.
	var bands := 24
	for i in bands:
		var k := float(i) / bands
		draw_rect(Rect2(0, size.y * 0.75 * k, size.x, size.y * 0.75 / bands + 1.0), (_pal[0] as Color).lerp(_pal[1], pow(k, 1.4)))
	var sun := Vector2(size.x * 0.66, size.y * 0.56)
	for i in 6:
		draw_circle(sun, size.y * (0.06 + 0.05 * i), Color(_pal[2], 0.08))
	draw_circle(sun, size.y * 0.075, _pal[2])
	draw_rect(Rect2(0, size.y * 0.75, size.x, size.y * 0.25), _pal[6])
	# The planes, back to front, each drifting at its own pace.
	for li in _layers.size():
		var layer: Array = _layers[li]
		var h: PackedFloat32Array = layer[0]
		var col: Color = _pal[int(layer[2])]
		var base_y: float = float(layer[3]) * size.y
		var tall := size.y * (0.32 - li * 0.04)
		var step := size.x / float(h.size() - 40)
		var off := fposmod(t * float(layer[1]) * s, step * h.size())
		# (The strip wraps: sample it at the scrolled place.) Drawn as one quad
		# per sample down to the bottom edge, which always triangulates.
		var prev := Vector2.ZERO
		var cols := PackedColorArray([col, col, col, col])
		for i in h.size() + 1:
			var hi := h[(i + int(off / step)) % h.size()]
			var p := Vector2(i * step - fposmod(off, step), base_y - hi * tall)
			if i > 0 and p.x > 0.0 and prev.x < size.x:
				draw_polygon(PackedVector2Array([prev, p, Vector2(p.x, size.y), Vector2(prev.x, size.y)]), cols)
			prev = p
		# Haze between the planes.
		draw_rect(Rect2(0, base_y - tall * 0.2, size.x, size.y - base_y + tall * 0.2), Color(_pal[7], 0.1 - li * 0.02))
	# A dead tree on the front ledge.
	_tree(Vector2(size.x * 0.14, size.y * 0.86), 150.0 * s)
	# Dust motes drifting with the wind.
	for m: Vector3 in _motes:
		var p := Vector2(fposmod(m.x * size.x + t * 40.0 * m.z * s, size.x), m.y * size.y * 0.85 + sin(t * 0.7 + m.x * 20.0) * 8.0 * s)
		draw_circle(p, 1.6 * s * m.z, Color(_pal[2], 0.35 * m.z))
	vignette(0.6)
	# Where we're going.
	var title := destination()
	var sub := ""
	if int(ctx.get("chapter", 0)) > 0:
		sub = "Chapter %s  ·  %s" % [roman(int(ctx["chapter"])), str(ctx.get("chapter_title", ""))]
	elif str(ctx.get("to", "")) == "first":
		title = "Dust & Mandibles"
		sub = "Morning comes to the canyon"
	elif bool(ctx.get("endless", false)):
		sub = "Endless  ·  hold the cliffs as long as you can"
	elif bool(ctx.get("tutorial", false)):
		sub = "Tutorial  ·  learning the ropes"
	elif str(ctx.get("to", "")) == "menu":
		sub = "Riding back to town"
	var rye := font(RYE)
	text(rye, Vector2(size.x * 0.5, size.y * 0.2), title, fit_px(rye, title, 88.0, size.x * 0.8), Color("#F6E6C4"), HORIZONTAL_ALIGNMENT_CENTER, -1.0, int(10 * s), Color(0.08, 0.04, 0.03, 0.85))
	if sub != "":
		text(font(BARLOW_BOLD), Vector2(size.x * 0.5, size.y * 0.29), sub.to_upper(), 28.0, Color("#F6E6C4", 0.85), HORIZONTAL_ALIGNMENT_CENTER, -1.0, int(6 * s), Color(0, 0, 0, 0.6))
	_fuse()


## A bare dead tree in silhouette, its roots on the ledge at `g`.
func _tree(g: Vector2, hgt: float) -> void:
	var col: Color = _pal[6]
	var s := sc()
	var trng := RandomNumberGenerator.new()
	trng.seed = 77
	var branches: Array = [[g, g + Vector2(6, -hgt), 9.0 * s]]
	var tip := g + Vector2(6, -hgt)
	for i in 6:
		var from := g.lerp(tip, trng.randf_range(0.35, 0.9))
		var dir := Vector2(trng.randf_range(-1.0, 1.0), -trng.randf_range(0.4, 1.0)).normalized()
		var end := from + dir * hgt * trng.randf_range(0.25, 0.45)
		branches.append([from, end, 5.0 * s])
		branches.append([end, end + Vector2(dir.x * 0.6, -0.8).normalized() * hgt * 0.15, 2.5 * s])
	for b: Array in branches:
		draw_line(b[0], b[1], col, float(b[2]))
	# The ledge it grows from: a rounded shoulder of rock falling away to the right.
	var ledge := PackedVector2Array([Vector2(0, g.y + 10.0 * s), Vector2(g.x - 60.0 * s, g.y - 6.0 * s), Vector2(g.x + 40.0 * s, g.y - 4.0 * s),
		Vector2(g.x + 120.0 * s, g.y + 12.0 * s), Vector2(g.x + 210.0 * s, g.y + 50.0 * s), Vector2(g.x + 300.0 * s, size.y), Vector2(0, size.y)])
	draw_colored_polygon(ledge, col)


## The fuse: burnt black behind the flame, rope ahead of it, ending in three
## sticks of dynamite bound with wire; the flame and its sparks at the burn.
func _fuse() -> void:
	var s := sc()
	var x0 := _fuse_x(0.0)
	var x1 := _fuse_x(1.0)
	var fx := _fuse_x(shown)
	var rope := Color("#C8A46A")
	var pts_burnt := PackedVector2Array()
	var pts_rope := PackedVector2Array()
	var n := 90
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		var p := Vector2(x, _fuse_at(x))
		if x <= fx:
			pts_burnt.append(p)
		if x >= fx - 2.0:
			pts_rope.append(p)
	if pts_rope.size() > 1:
		draw_polyline(pts_rope, Color(0, 0, 0, 0.5), 9.0 * s)
		draw_polyline(pts_rope, rope, 6.0 * s)
		# Twist marks along the rope.
		for i in range(0, pts_rope.size(), 2):
			var p: Vector2 = pts_rope[i]
			draw_line(p + Vector2(-2, -3) * s, p + Vector2(2, 3) * s, rope.darkened(0.35), 1.5 * s)
	if pts_burnt.size() > 1:
		draw_polyline(pts_burnt, Color("#2A2220"), 4.0 * s)
		draw_polyline(pts_burnt, Color("#5A4A44", 0.6), 1.5 * s)
	# The dynamite at the end.
	var d := Vector2(x1 + 26.0 * s, _fuse_y())
	for i in 3:
		var r := Rect2(d + Vector2(0, (i - 1) * 24.0 * s - 11.0 * s), Vector2(120.0 * s, 22.0 * s))
		draw_rect(r, Color("#B3302A").darkened(0.1 * i))
		draw_rect(Rect2(r.position + Vector2(0, 3.0 * s), Vector2(r.size.x, 4.0 * s)), Color(1, 1, 1, 0.12))
	for x: float in [20.0, 96.0]:
		draw_rect(Rect2(d + Vector2(x * s, -38.0 * s), Vector2(6.0 * s, 74.0 * s)), Color("#9AA4AD"))
	text(font(BARLOW_XB), d + Vector2(60.0 * s, 0), "TNT", 18.0, Color("#F6E6C4", 0.8))
	text(font(BARLOW_BOLD), Vector2(x0, _fuse_y() - 40.0 * s), note_text(), 22.0, Color("#F6E6C4", 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	# Flame and sparks.
	var f := _flame_pos()
	var flick := 1.0 + 0.25 * sin(t * 31.0) + 0.15 * sin(t * 17.0)
	draw_circle(f, 16.0 * s * flick, Color(1.0, 0.55, 0.15, 0.25))
	draw_circle(f, 9.0 * s * flick, Color(1.0, 0.7, 0.25, 0.8))
	draw_circle(f, 4.5 * s, Color(1.0, 0.95, 0.75))
	for sp: Array in _sparks:
		var life := float(sp[2])
		var p: Vector2 = sp[0]
		var v: Vector2 = sp[1]
		draw_line(p, p - v * 0.02, Color(1.0, 0.8, 0.35, clampf(life * 2.0, 0.0, 1.0)), 2.0 * s)

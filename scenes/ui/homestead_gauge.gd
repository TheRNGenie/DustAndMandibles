extends RefCounted
## The Homestead plates' gauge (Logan: "something more interesting and on theme
## than just bars"): a little cabin that cracks, smokes and burns as it's hurt,
## and a painted picket fence, one picket per tenth of its health, that gets
## knocked flat as the place takes damage and stands back up as it's mended.
## Both are drawn (no textures), in the cliff's team colour, and only redraw
## while something moves.


## Ten painted pickets on two rails. Health drains from the right: whole tenths
## stand, the next is snapped off at what's left of its tenth, and the rest lie
## flat on the ground. A hit topples pickets one after another with a puff of
## dust and shudders the fence; mending stands them back up.
class Fence extends Control:
	const COUNT := 10
	## The cliff's team colour: the paint on the pickets.
	var color := Color("#C0503A")
	var ratio := 1.0
	## Per picket: 0 standing .. 1 flat on the ground, and how fast it's falling.
	var _tilt := PackedFloat32Array()
	var _fall := PackedFloat32Array()
	## Dust puffs where a picket hit the ground: [picket, age].
	var _puffs: Array = []
	var _shake := 0.0
	var _flash := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(120, 21)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tilt.resize(COUNT)
		_fall.resize(COUNT)
		set_process(false)

	## The share of health left (0..1). animate = false snaps (a new cliff in
	## this slot, the first fill).
	func set_ratio(r: float, animate: bool = true) -> void:
		r = clampf(r, 0.0, 1.0)
		if is_equal_approx(r, ratio) and animate:
			return
		var hit := r < ratio
		ratio = r
		if not animate or not is_inside_tree():
			for i in COUNT:
				_tilt[i] = _want(i)
				_fall[i] = 0.0
			_puffs.clear()
			queue_redraw()
			return
		if hit:
			_shake = 0.3
			_flash = 1.0
		set_process(true)
		queue_redraw()

	## 0 while any of picket i's tenth is left, else 1 (flat).
	func _want(i: int) -> float:
		return 0.0 if ratio * COUNT > float(i) + 0.001 else 1.0

	func _process(delta: float) -> void:
		var busy := false
		for i in COUNT:
			var w := _want(i)
			if w > _tilt[i]:
				# Felled: right to left, each one once its right-hand neighbour is
				# well on its way, speeding up as it goes over.
				if i < COUNT - 1 and _want(i + 1) > 0.5 and _tilt[i + 1] < 0.45:
					busy = true
					continue
				_fall[i] += delta * 14.0
				_tilt[i] = minf(_tilt[i] + _fall[i] * delta, 1.0)
				if _tilt[i] >= 1.0:
					_fall[i] = 0.0
					_puffs.append([i, 0.0])
				busy = true
			elif w < _tilt[i]:
				_tilt[i] = maxf(_tilt[i] - delta * 3.5, 0.0) # mended: back up
				busy = true
		for p: Array in _puffs:
			p[1] = float(p[1]) + delta
		_puffs = _puffs.filter(func(p: Array) -> bool: return float(p[1]) < 0.6)
		_shake = maxf(_shake - delta, 0.0)
		_flash = maxf(_flash - delta * 3.0, 0.0)
		queue_redraw()
		if not busy and _puffs.is_empty() and _shake <= 0.0 and _flash <= 0.0:
			set_process(false)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var ox := sin(_shake * 90.0) * 2.0 * clampf(_shake / 0.3, 0.0, 1.0)
		var step := w / float(COUNT)
		var pw := minf(step * 0.36, 8.0) # tall and narrow: pickets, not little houses
		var ph := h - 2.0
		var ground := h - 1.0
		var rim := UiStyle.kc("rim")
		var rail := Color("#6B4A30")
		# Two weathered rails behind the pickets, nailed along their length.
		for k: float in [0.68, 0.3]:
			var y := ground - ph * k
			draw_rect(Rect2(ox, y - 1.5, w, 3.0), rail.darkened(0.25))
			draw_line(Vector2(ox, y - 1.5), Vector2(ox + w, y - 1.5), Color(1, 1, 1, 0.08), 1.0)
		draw_line(Vector2(0, ground), Vector2(w, ground), rim, 2.0)
		var paint := color.lerp(Color("#F2E6D0"), 0.12)
		var lit := paint.lightened(0.28)
		var flat := paint.darkened(0.5)
		var hurt := Color(1.0, 0.85, 0.7)
		for i in COUNT:
			var left := ratio * COUNT - float(i) # >= 1 whole; (0, 1) snapped; <= 0 gone
			var t := _tilt[i]
			var base := Vector2(ox + step * (float(i) + 0.5) + pw * 0.5, ground)
			var hh := ph
			# (snapped once the pickets to its right are down: not mid-topple)
			var snapped := left > 0.0 and left < 1.0 and t < 0.01 and (i == COUNT - 1 or _tilt[i + 1] >= 0.99)
			if snapped:
				hh = maxf(ph * left, 3.0)
			var pts := _picket(pw, hh, snapped)
			draw_set_transform(base, t * PI * 0.5, Vector2.ONE)
			var fill := paint.lerp(flat, t)
			if t < 0.01 and _flash > 0.0:
				fill = fill.lerp(hurt, _flash * 0.45)
			draw_colored_polygon(pts, fill)
			draw_line(Vector2(-pw + 1.2, -1.0), Vector2(-pw + 1.2, -hh + pw * 0.5), Color(lit, 0.9 * (1.0 - t)), 1.5)
			# Nails where it meets the rails.
			if t < 0.01:
				for k: float in [0.68, 0.3]:
					if hh > ph * k + 1.0:
						draw_rect(Rect2(-pw * 0.5 - 1.0, -ph * k - 1.0, 2.0, 2.0), Color(rim, 0.7))
			var outline := pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, rim, 1.5)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		# Dust where pickets landed.
		for p: Array in _puffs:
			var a := float(p[1]) / 0.6
			var at := Vector2(ox + step * (float(p[0]) + 0.5) + pw * 0.5 + ph * 0.7, ground - 2.0)
			for k in 3:
				var off := Vector2((float(k) - 1.0) * 5.0 * (0.5 + a), -a * 5.0 - float(k % 2) * 2.0)
				draw_circle(at + off, 2.0 + a * 4.0, Color(0.85, 0.74, 0.58, 0.55 * (1.0 - a)))

	## A picket with its base's right corner at the origin, standing up (-y): a
	## pointed top, or a jagged snapped one.
	static func _picket(pw: float, hh: float, snapped: bool) -> PackedVector2Array:
		if snapped:
			return PackedVector2Array([Vector2(-pw, 0), Vector2(-pw, -hh + 1.5), Vector2(-pw * 0.72, -hh - 1.5),
				Vector2(-pw * 0.48, -hh + 1.0), Vector2(-pw * 0.22, -hh - 2.0), Vector2(0, -hh + 2.0), Vector2(0, 0)])
		return PackedVector2Array([Vector2(-pw, 0), Vector2(-pw, -hh + pw * 0.5), Vector2(-pw * 0.5, -hh),
			Vector2(0, -hh + pw * 0.5), Vector2(0, 0)])


## The Homestead itself, small: a plank cabin with a roof in the cliff's colour,
## a lit window and a chimney. Below two thirds of its health the roof is holed,
## the window cracked and smoke pours out; below a third it's on fire; at zero
## it's a heap of boards round a standing chimney. A hit jolts it.
class Cabin extends Control:
	var color := Color("#C0503A")
	var ratio := 1.0
	var _t := 0.0
	var _hit := 0.0
	var _since := 0.0
	## The drawing's scale and offset (it's laid out on a 42 x 40 grid).
	var _k := 1.0
	var _o := Vector2.ZERO

	func _init() -> void:
		custom_minimum_size = Vector2(42, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		set_process(false)

	func set_ratio(r: float, animate: bool = true) -> void:
		r = clampf(r, 0.0, 1.0)
		if animate and r < ratio - 0.0001:
			_hit = 0.35
		ratio = r
		set_process(_moving())
		queue_redraw()

	## Smoke and flames move; a healthy cabin and a ruin hold still.
	func _moving() -> bool:
		return (ratio > 0.0 and ratio < 0.67) or _hit > 0.0

	func _process(delta: float) -> void:
		_t += delta
		_hit = maxf(_hit - delta, 0.0)
		_since += delta
		if _since >= 0.05: # (20 frames a second is plenty for smoke and fire)
			_since = 0.0
			queue_redraw()
		if not _moving():
			set_process(false)
			queue_redraw()

	func _draw() -> void:
		_k = minf(size.x / 42.0, size.y / 40.0)
		var jolt := sin(_hit * 70.0) * 1.6 * (_hit / 0.35)
		_o = (size - Vector2(42, 40) * _k) * 0.5 + Vector2(jolt, 0)
		_at(Vector2.ZERO, 0.0)
		var rim := UiStyle.kc("rim")
		var flash := _hit / 0.35
		var wood := Color("#9A6A3E").lerp(Color(1, 0.86, 0.72), flash * 0.4)
		var roof := color.darkened(0.12).lerp(Color(1, 0.86, 0.72), flash * 0.4)
		var brick := Color("#8A4A34")
		var r := ratio
		if r <= 0.0:
			_ruin(rim, wood, brick)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			return
		# Ground and a scrap of yard.
		draw_line(Vector2(2, 37), Vector2(40, 37), rim, 2.0)
		# Chimney (behind the roof).
		draw_rect(Rect2(27, 7, 5, 10), brick)
		draw_rect(Rect2(26.5, 6, 6, 2), brick.darkened(0.2))
		draw_rect(Rect2(27, 7, 5, 10), rim, false, 1.2)
		# Walls: planks.
		draw_rect(Rect2(7, 19, 28, 18), wood)
		for y in [23.0, 27.0, 31.0, 35.0]:
			draw_line(Vector2(7.5, y), Vector2(34.5, y), wood.darkened(0.3), 1.0)
		if r < 0.34: # scorched
			draw_colored_polygon(PackedVector2Array([Vector2(7, 37), Vector2(7, 26), Vector2(13, 30), Vector2(19, 25),
				Vector2(24, 31), Vector2(35, 27), Vector2(35, 37)]), Color(0.1, 0.06, 0.04, 0.5))
		draw_rect(Rect2(7, 19, 28, 18), rim, false, 1.5)
		# Door and window.
		draw_rect(Rect2(12, 26, 6, 11), wood.darkened(0.5))
		draw_circle(Vector2(16.6, 32), 0.8, Color("#E8C066"))
		var glow := Color("#FFD27A") if r >= 0.34 else Color("#FF8A3A")
		draw_rect(Rect2(23, 24, 8, 6), glow)
		draw_line(Vector2(27, 24), Vector2(27, 30), rim, 1.0)
		draw_line(Vector2(23, 27), Vector2(31, 27), rim, 1.0)
		if r < 0.67: # cracked panes
			draw_line(Vector2(23.5, 24.5), Vector2(26, 28.5), Color(rim, 0.9), 1.0)
			draw_line(Vector2(28, 24.5), Vector2(30.5, 29), Color(rim, 0.9), 1.0)
		draw_rect(Rect2(23, 24, 8, 6), rim, false, 1.2)
		# Roof: painted boards with a lit ridge.
		var roof_pts := PackedVector2Array([Vector2(3, 20.5), Vector2(21, 7), Vector2(39, 20.5)])
		draw_colored_polygon(roof_pts, roof)
		for i in 3:
			var f := 0.3 + 0.22 * float(i)
			draw_line(Vector2(21 - 18 * f, 7 + 13.5 * f), Vector2(21 + 18 * f, 7 + 13.5 * f), roof.darkened(0.25), 1.0)
		draw_line(Vector2(5, 19.5), Vector2(21, 7.8), Color(roof.lightened(0.35), 0.9), 1.4)
		if r < 0.67: # a hole torn in the roof, and a board hanging off the wall
			draw_colored_polygon(PackedVector2Array([Vector2(10, 15.5), Vector2(14.5, 12.5), Vector2(17, 15),
				Vector2(15.5, 17.5), Vector2(11.5, 18.5)]), Color(0.08, 0.05, 0.04))
			_at(Vector2(33, 21), 0.5)
			draw_rect(Rect2(-1, 0, 2.5, 8), wood.darkened(0.15))
			draw_rect(Rect2(-1, 0, 2.5, 8), rim, false, 1.0)
			_at(Vector2.ZERO, 0.0)
		var outline := roof_pts.duplicate()
		outline.append(roof_pts[0])
		draw_polyline(outline, rim, 1.5)
		if r >= 0.67:
			# A thread of chimney smoke: home's fine.
			for i in 3:
				draw_circle(Vector2(30 + float(i) * 1.6, 4.0 - float(i) * 2.2), 1.6 + float(i) * 0.5, Color(0.9, 0.88, 0.84, 0.45 - 0.1 * float(i)))
		elif r >= 0.34:
			_smoke(Vector2(13, 14), Color(0.42, 0.4, 0.38))
		else:
			_smoke(Vector2(13, 12), Color(0.22, 0.2, 0.2))
			_flames(Vector2(13.5, 15.5), 1.0)
			_flames(Vector2(27, 25), 0.6)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	## Draws from here on at a point of the 42 x 40 grid, turned by angle.
	func _at(p: Vector2, angle: float) -> void:
		draw_set_transform(_o + p * _k, angle, Vector2(_k, _k))

	## Puffs rising from a point, drifting right, swelling and fading.
	func _smoke(at: Vector2, c: Color) -> void:
		for i in 4:
			var a := fposmod(_t * 0.7 + float(i) * 0.25, 1.0)
			var p := at + Vector2(a * 7.0 + sin(_t * 2.0 + float(i)) * 1.0, -a * 15.0)
			draw_circle(p, 1.8 + a * 3.2, Color(c, 0.7 * (1.0 - a)))

	## Licking toon flames: an orange tongue over a yellow core, flickering.
	func _flames(at: Vector2, s: float) -> void:
		draw_circle(at + Vector2(0, -2) * s, 7.0 * s, Color(1.0, 0.45, 0.15, 0.18))
		for layer in 2:
			var c := Color("#FF7A26") if layer == 0 else Color("#FFD24A")
			var sc := s * (1.0 if layer == 0 else 0.55)
			var pts := PackedVector2Array()
			pts.append(at + Vector2(-5, 0) * sc)
			for j in 3:
				var x := (-3.0 + 3.0 * float(j)) * sc
				var tip := (8.0 + 3.0 * sin(_t * (9.0 + float(j) * 2.3) + float(j) * 1.7)) * sc
				pts.append(at + Vector2(x - 1.2 * sc, -tip * 0.45))
				pts.append(at + Vector2(x, -tip))
			pts.append(at + Vector2(5, 0) * sc)
			draw_colored_polygon(pts, c)

	## Burnt down: charred stumps, a heap of boards and the chimney still up.
	func _ruin(rim: Color, wood: Color, brick: Color) -> void:
		draw_line(Vector2(2, 37), Vector2(40, 37), rim, 2.0)
		var burnt := wood.darkened(0.6)
		draw_rect(Rect2(27, 13, 5, 24), brick.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(27, 13), Vector2(29, 10.5), Vector2(32, 12), Vector2(32, 13)]), brick.darkened(0.25))
		draw_rect(Rect2(27, 13, 5, 24), rim, false, 1.2)
		draw_colored_polygon(PackedVector2Array([Vector2(6, 37), Vector2(7, 28), Vector2(9, 31), Vector2(11, 26),
			Vector2(13, 37)]), burnt)
		for b: Array in [[Vector2(10, 35), -0.25], [Vector2(18, 33.5), 0.15], [Vector2(24, 35), -0.1], [Vector2(15, 31.5), 0.6]]:
			_at(b[0], float(b[1]))
			draw_rect(Rect2(-6, -1.2, 12, 2.6), burnt.lightened(0.15))
			draw_rect(Rect2(-6, -1.2, 12, 2.6), rim, false, 1.0)
		_at(Vector2.ZERO, 0.0)
		for i in 3:
			draw_circle(Vector2(18 + float(i) * 2.0, 26.0 - float(i) * 3.5), 1.8 + float(i) * 0.8, Color(0.5, 0.48, 0.46, 0.35 - 0.08 * float(i)))

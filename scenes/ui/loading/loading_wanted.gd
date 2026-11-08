class_name LoadingWanted
extends LoadingScreen
## Wanted Poster: a weathered parchment poster nailed over dark stitched
## leather, its edges torn and burnt, two bullet holes through it. WANTED up
## top, what's wanted and where in a big slab face ("BRAVE SOULS FOR THE
## CANYON"), the reward, and DEAD OR ALIVE in small print. A brass sheriff's
## star spins in the bottom corner inside a ring that fills as the load goes.

const PAPER := Color("#E6D3A6")
const PAPER_DARK := Color("#B8955E")
const INK := Color("#2B1A0E")
const LEATHER := Color("#3B2416")
const RED := Color("#8E2A1C")

var _edge: PackedVector2Array = PackedVector2Array()
var _holes: Array[Vector2] = []
var _lines: Array = []


func _build() -> void:
	_lines = _copy()
	# Bullet holes, somewhere on the paper (normalised poster coords).
	for i in 2:
		_holes.append(Vector2(rng.randf_range(0.12, 0.88), rng.randf_range(0.6, 0.92)))


## The poster's words for this load: [kicker, wanted, place, reward, small].
func _copy() -> Array:
	var place := destination().to_upper()
	if str(ctx.get("to", "")) == "menu":
		return ["WANTED", "TIRED RIDERS", "BACK IN TOWN", "REWARD: A HOT BATH", "NO QUESTIONS ASKED"]
	if bool(ctx.get("tutorial", false)):
		return ["WANTED", "GREENHORNS", "FOR " + place, "REWARD: SCHOOLING", "NO EXPERIENCE NEEDED"]
	if int(ctx.get("chapter", 0)) > 0:
		return ["WANTED", "HIRED GUNS", "CHAPTER %s: %s" % [roman(int(ctx["chapter"])), str(ctx.get("chapter_title", "")).to_upper()],
			"REWARD: %d CHITIN" % (100 * int(ctx["chapter"])), "DEAD OR ALIVE"]
	if bool(ctx.get("endless", false)):
		return ["WANTED", "BRAVE SOULS", "FOR " + place, "REWARD: GLORY", "DEAD OR ALIVE"]
	var rewards := ["REWARD: GLORY", "REWARD: $500 IN SCRAP", "REWARD: A SQUARE MEAL", "REWARD: BRAGGING RIGHTS"]
	return ["WANTED", "BRAVE SOULS", "FOR " + place, str(rewards[rng.randi() % rewards.size()]), "DEAD OR ALIVE"]


func _poster_rect() -> Rect2:
	var h := size.y * 0.82
	var w := h * 0.74
	return Rect2(size * 0.5 - Vector2(w, h) * 0.5 + Vector2(0, size.y * 0.01), Vector2(w, h))


func _on_resized() -> void:
	_edge = PackedVector2Array()


## A torn outline round the poster: jagged little steps on every side, a
## couple of bigger bites out of the edges.
func _torn(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var trng := RandomNumberGenerator.new()
	trng.seed = 1873
	var n := 40
	var j := r.size.x * 0.012
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var nrm := (b - a).orthogonal().normalized()
		for i in n:
			var t := float(i) / n
			var bite := 0.0
			if (side == 1 and absf(t - 0.7) < 0.05) or (side == 3 and absf(t - 0.3) < 0.04):
				bite = j * 3.0 * (1.0 - absf(t - (0.7 if side == 1 else 0.3)) / 0.05)
			pts.append(a.lerp(b, t) + nrm * (trng.randf_range(-j, j) * 0.6 - bite))
	return pts


func _draw() -> void:
	var s := sc()
	# Leather with stitching round the edge.
	draw_rect(Rect2(Vector2.ZERO, size), LEATHER)
	draw_texture_rect(grain(), Rect2(Vector2.ZERO, size), true, Color(0.08, 0.04, 0.02, 0.5))
	var inset := 34.0 * s
	var stitch := Color("#C9A46A")
	for k in 2:
		var r := Rect2(Vector2(inset, inset) * (1.0 + k * 0.5), size - Vector2(inset, inset) * 2.0 * (1.0 + k * 0.5))
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
		for i in 4:
			draw_dashed_line(pts[i] + Vector2(0, 1.5 * s), pts[i + 1] + Vector2(0, 1.5 * s), Color(0, 0, 0, 0.5), 3.0 * s, 14.0 * s)
			draw_dashed_line(pts[i], pts[i + 1], Color(stitch, 0.85 - k * 0.3), 3.0 * s, 14.0 * s)
	vignette(0.8)
	# The poster.
	var pr := _poster_rect()
	if _edge.is_empty():
		_edge = _torn(pr)
	var shadow := PackedVector2Array()
	for p: Vector2 in _edge:
		shadow.append(p + Vector2(10, 16) * s)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	draw_colored_polygon(_edge, PAPER)
	draw_texture_rect(grain(), pr, true, Color(0.45, 0.3, 0.12, 0.25))
	# Burnt, darker edges: the outline drawn thick and soft.
	var ring := _edge.duplicate()
	ring.append(_edge[0])
	draw_polyline(ring, Color(PAPER_DARK, 0.9), 22.0 * s)
	draw_polyline(ring, Color(0.35, 0.2, 0.08, 0.7), 6.0 * s)
	# Nails at the top corners.
	for x: float in [0.08, 0.92]:
		var n := pr.position + Vector2(pr.size.x * x, pr.size.y * 0.035)
		draw_circle(n + Vector2(2, 3) * s, 9.0 * s, Color(0, 0, 0, 0.4))
		draw_circle(n, 9.0 * s, Color("#8A6A3A"))
		draw_circle(n + Vector2(-2, -2) * s, 4.0 * s, Color("#D9B26A"))
	# The words.
	var cx := pr.position.x + pr.size.x * 0.5
	var y := pr.position.y
	var h := pr.size.y
	var rye := font(RYE)
	var ewert := font(EWERT)
	text(rye, Vector2(cx, y + h * 0.13), str(_lines[0]), fit_px(rye, str(_lines[0]), 132.0, pr.size.x * 0.84), INK)
	draw_line(Vector2(pr.position.x + pr.size.x * 0.1, y + h * 0.215), Vector2(pr.end.x - pr.size.x * 0.1, y + h * 0.215), INK, 3.0 * s)
	draw_line(Vector2(pr.position.x + pr.size.x * 0.1, y + h * 0.225), Vector2(pr.end.x - pr.size.x * 0.1, y + h * 0.225), INK, 1.5 * s)
	text(ewert, Vector2(cx, y + h * 0.32), str(_lines[1]), fit_px(ewert, str(_lines[1]), 74.0, pr.size.x * 0.84), INK)
	# The place, in a slab face, as large as it will fit.
	var place := str(_lines[2])
	text(rye, Vector2(cx, y + h * 0.45), place, fit_px(rye, place, 66.0, pr.size.x * 0.86), RED)
	# A framed "portrait" panel: a silhouette of a rider against the sun.
	var pan := Rect2(pr.position + Vector2(pr.size.x * 0.22, h * 0.52), Vector2(pr.size.x * 0.56, h * 0.2))
	draw_rect(pan, Color(PAPER_DARK, 0.35))
	draw_rect(pan, INK, false, 2.5 * s)
	_rider(pan)
	text(ewert, Vector2(cx, y + h * 0.8), str(_lines[3]), fit_px(ewert, str(_lines[3]), 52.0, pr.size.x * 0.84), INK)
	text(font(BARLOW_XB), Vector2(cx, y + h * 0.88), str(_lines[4]), 30.0, Color(INK, 0.8))
	text(font(TYPE), Vector2(cx, y + h * 0.93), "Apply at the Sheriff's office. Bring your own guns.", 17.0, Color(INK, 0.65))
	# Bullet holes: dark punched centres with torn, lighter rims.
	for hole: Vector2 in _holes:
		var c := pr.position + pr.size * hole
		draw_circle(c, 13.0 * s, Color(PAPER_DARK, 0.9))
		draw_circle(c, 8.0 * s, Color("#1A0F07"))
		for i in 7:
			var a := TAU * float(i) / 7.0 + hole.x * 9.0
			draw_line(c + Vector2(cos(a), sin(a)) * 8.0 * s, c + Vector2(cos(a), sin(a)) * 17.0 * s, Color(0.3, 0.18, 0.08, 0.7), 2.0 * s)
	_star(Vector2(size.x - 120.0 * s, size.y - 120.0 * s), 52.0 * s)
	text(font(BARLOW_BOLD), Vector2(size.x - 210.0 * s, size.y - 120.0 * s), note_text(), 22.0, Color("#E6D3A6", 0.85), HORIZONTAL_ALIGNMENT_RIGHT)


## A rider on horseback against a low sun, in ink, inside the poster's panel.
func _rider(r: Rect2) -> void:
	var s := sc()
	var g := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.86)
	draw_circle(r.position + Vector2(r.size.x * 0.68, r.size.y * 0.42), r.size.y * 0.24, Color(RED, 0.5))
	draw_line(Vector2(r.position.x + 4.0 * s, g.y), Vector2(r.end.x - 4.0 * s, g.y), INK, 2.0 * s)
	var u := r.size.y / 100.0
	var horse := PackedVector2Array([g + Vector2(-34, -6) * u, g + Vector2(-30, -34) * u, g + Vector2(14, -36) * u, g + Vector2(24, -50) * u,
		g + Vector2(34, -48) * u, g + Vector2(30, -38) * u, g + Vector2(22, -28) * u, g + Vector2(20, -6) * u, g + Vector2(16, -6) * u,
		g + Vector2(14, -22) * u, g + Vector2(-22, -22) * u, g + Vector2(-26, -6) * u])
	draw_colored_polygon(horse, INK)
	for x: float in [-30.0, -22.0, 12.0, 19.0]:
		draw_line(g + Vector2(x, -22) * u, g + Vector2(x + 2.0, 0) * u, INK, 3.0 * s)
	draw_line(g + Vector2(-32, -32) * u, g + Vector2(-44, -18) * u, INK, 3.0 * s)
	var rider := PackedVector2Array([g + Vector2(-8, -36) * u, g + Vector2(-6, -60) * u, g + Vector2(4, -60) * u, g + Vector2(4, -36) * u])
	draw_colored_polygon(rider, INK)
	draw_circle(g + Vector2(-1, -66) * u, 5.0 * u, INK)
	draw_rect(Rect2(g + Vector2(-11, -72) * u, Vector2(20, 3) * u), INK)
	draw_rect(Rect2(g + Vector2(-6, -78) * u, Vector2(10, 7) * u), INK)


## A brass sheriff's star (six points, ball tips), spinning, inside a ring
## that fills with the load.
func _star(c: Vector2, r: float) -> void:
	var brass := Color("#D9A845")
	draw_circle(c, r * 1.42, Color(0, 0, 0, 0.45))
	draw_arc(c, r * 1.3, 0, TAU, 64, Color(brass, 0.25), r * 0.1)
	draw_arc(c, r * 1.3, -PI * 0.5, -PI * 0.5 + TAU * shown, 64, brass.lightened(0.2), r * 0.12)
	var spin := t * 2.4 + shown * TAU
	var pts := PackedVector2Array()
	for i in 12:
		var a := spin + TAU * float(i) / 12.0 - PI * 0.5
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.55))
	var shadow := PackedVector2Array()
	for p: Vector2 in pts:
		shadow.append(p + Vector2(3, 4) * sc())
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.5))
	draw_colored_polygon(pts, brass)
	# Bevel: the half facing the light lighter.
	for i in 12:
		if i % 2 == 0:
			var a := spin + TAU * float(i) / 12.0 - PI * 0.5
			var tip := c + Vector2(cos(a), sin(a)) * r
			draw_line(c, tip, brass.lightened(0.25) if cos(a + 0.8) > 0.0 else brass.darkened(0.2), r * 0.06)
			draw_circle(tip, r * 0.13, brass.lightened(0.15))
	draw_circle(c, r * 0.36, brass.darkened(0.15))
	draw_circle(c, r * 0.28, brass.lightened(0.1))
	for i in 5:
		var a := spin * 0.0 + TAU * float(i) / 5.0 - PI * 0.5
		draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.2, r * 0.035, Color("#7A5520"))

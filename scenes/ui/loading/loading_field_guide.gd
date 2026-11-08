class_name LoadingFieldGuide
extends LoadingScreen
## Bug Field Guide: an aged naturalist's journal page (stained cream paper,
## faded grid, the binding's shadow, coffee rings and ink blots) with an ink
## drawing of a bug you're about to meet: hatched in crosshatch, annotation
## arrows to its weak spots, its name in a slanted hand and a made-up Latin
## binomial under it. Bosses get EXTREMELY DANGEROUS stamped across in red.
## The spinner is a pen nib in the margin drawing a circle, ink pooling at its tip.

const PAPER := Color("#ECE0C2")
const GRID := Color("#8FA3B0")
const INK := Color("#1E1A2A")
const SEPIA := Color("#6B4A2A")
const STAMP := Color("#B0281E")

## Bugs worth a page when nothing better is known (iconic ones from each family).
const FEATURED: Array[StringName] = [&"rattler_beetle", &"wolf_spider", &"spitter_scorpion", &"brood_mother",
	&"dragonfly_bandit", &"queen_spider", &"burrow_beetle", &"mirage_mantis", &"thunder_cicada", &"crop_weevil"]
const LATIN_A := ["Scarabaeus", "Lycosa", "Buthus", "Formica", "Mantis", "Cicada", "Coleoptera", "Arachne", "Ixodes", "Libellula"]
const LATIN_B := ["horribilis", "canyonensis", "rapax", "ferox", "pulverulentus", "aridus", "voracissimus", "ossifragus", "texanus", "insatiabilis"]

var _bug: BugDef
var _plan := "beetle"
var _notes: Array = [] # [text, at (bug space -1..1), side]
var _stains: Array = []


func _build() -> void:
	var id := StringName(str(ctx.get("bug", "")))
	if id == &"" or Defs.bug(id) == null:
		var wave := int(ctx.get("wave", 0))
		var pool: Array[StringName] = []
		if wave > 0:
			for b: StringName in Defs.active_bug_ids():
				var d := Defs.bug(b)
				if d != null and d.first_wave <= wave + 2 and d.variant_of == &"":
					pool.append(b)
		if pool.is_empty():
			pool = FEATURED
		id = pool[rng.randi() % pool.size()]
	_bug = Defs.bug(id)
	var sid := String(id)
	if "spider" in sid or "brood" in sid:
		_plan = "spider"
	elif "scorpion" in sid or "matriarch" in sid:
		_plan = "scorpion"
	elif "dragonfly" in sid or "locust" in sid or "cicada" in sid or "drone" in sid:
		_plan = "flier"
	elif "mite" in sid or "tick" in sid:
		_plan = "mite"
	elif "mantis" in sid or "strider" in sid:
		_plan = "mantis"
	_notes = _annotations()
	for i in 3:
		_stains.append([Vector2(rng.randf_range(0.1, 0.95), rng.randf_range(0.1, 0.9)), rng.randf_range(50, 110), rng.randf()])


## What the arrows point at: a couple of weak spots by body plan, and the
## bug's own counter tip (its first sentence) as the main note.
func _annotations() -> Array:
	var out: Array = []
	match _plan:
		"spider":
			out = [["eight eyes: blind behind", Vector2(0.0, -0.62), -1], ["soft abdomen", Vector2(0.1, 0.45), 1]]
		"scorpion":
			out = [["the tail spits: keep moving", Vector2(0.2, -0.8), 1], ["belly plates thin", Vector2(0.0, 0.25), -1]]
		"flier":
			out = [["wing roots: one shot drops it", Vector2(-0.25, -0.1), -1], ["body hollow", Vector2(0.0, 0.4), 1]]
		"mite":
			out = [["no armour to speak of", Vector2(0.2, 0.1), 1], ["comes in hundreds", Vector2(-0.4, -0.3), -1]]
		"mantis":
			out = [["arms: stay out of reach", Vector2(-0.3, -0.5), -1], ["thin neck", Vector2(0.0, -0.3), 1]]
		_:
			out = [["shell turns shot: from the front", Vector2(0.0, -0.5), -1], ["soft joints, underside", Vector2(0.45, 0.3), 1]]
	if _bug != null and _bug.counter != "":
		var first := _bug.counter.split(".")[0].split(":")[0].strip_edges()
		if first.length() > 34:
			first = first.substr(0, 32).rsplit(" ", true, 1)[0] + "..."
		out.append([first, Vector2(-0.15, 0.3), -1])
	return out


func _draw() -> void:
	var s := sc()
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	draw_texture_rect(grain(), Rect2(Vector2.ZERO, size), true, Color(0.5, 0.36, 0.16, 0.22))
	# Faded grid.
	var g := 36.0 * s
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(GRID, 0.16 if int(round(x / g)) % 5 else 0.3), 1.0)
		x += g
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(GRID, 0.16 if int(round(y / g)) % 5 else 0.3), 1.0)
		y += g
	# Coffee rings.
	for st: Array in _stains:
		var c := size * (st[0] as Vector2)
		var r := float(st[1]) * s
		draw_arc(c, r, float(st[2]) * TAU, float(st[2]) * TAU + 5.2, 64, Color(0.45, 0.28, 0.1, 0.18), 7.0 * s)
		draw_arc(c, r * 0.97, 0, TAU, 64, Color(0.45, 0.28, 0.1, 0.08), 3.0 * s)
	# The binding: a soft dark fold down the left.
	for i in 12:
		draw_rect(Rect2(i * 6.0 * s, 0, 6.0 * s, size.y), Color(0.2, 0.12, 0.05, 0.22 * (1.0 - i / 12.0)))
	draw_line(Vector2(70.0 * s, 0), Vector2(70.0 * s, size.y), Color(STAMP, 0.35), 2.0 * s) # margin rule
	vignette(0.35, Color(0.3, 0.18, 0.06))
	# Header.
	var tf := font(TYPE)
	text(tf, Vector2(130.0 * s, 70.0 * s), "FIELD NOTES  ·  INSECTS OF THE BADLANDS", 24.0, Color(SEPIA, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	text(tf, Vector2(size.x - 90.0 * s, 70.0 * s), "No. %d" % (11 + absi(rng.seed) % 80), 24.0, Color(SEPIA, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
	draw_line(Vector2(130.0 * s, 92.0 * s), Vector2(size.x - 90.0 * s, 92.0 * s), Color(SEPIA, 0.5), 1.5 * s)
	# The drawing.
	var centre := Vector2(size.x * 0.46, size.y * 0.5)
	var k_px := size.y * 0.27 * (1.25 if _bug != null and _bug.behavior == BugDef.Behavior.BOSS else 1.0)
	_ink_bug(centre, k_px)
	_arrows(centre, k_px)
	# Name, Latin, place.
	var nm := _bug.display_name if _bug != null else "Unknown Beetle"
	var hand := slanted(BARLOW, 0.26)
	text(hand, Vector2(size.x * 0.46, size.y * 0.87), nm, fit_px(hand, nm, 64.0, size.x * 0.5), INK)
	var h := hash(nm)
	var latin := "%s %s" % [LATIN_A[absi(h) % LATIN_A.size()], LATIN_B[absi(h >> 5) % LATIN_B.size()]]
	text(slanted(TYPE, 0.18), Vector2(size.x * 0.46, size.y * 0.93), latin, 26.0, Color(SEPIA, 0.9))
	text(tf, Vector2(130.0 * s, size.y - 46.0 * s), "Observed: %s" % destination(), 20.0, Color(SEPIA, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	if _bug != null and _bug.behavior == BugDef.Behavior.BOSS:
		_stamp(Vector2(size.x * 0.72, size.y * 0.2), "EXTREMELY DANGEROUS")
	_nib(Vector2(size.x - 130.0 * s, size.y - 140.0 * s), 46.0 * s)


# ------------------------------------------------------------------ ink drawing

## An inked ellipse at c (radii r, turned `rot`): pale wash, a doubled shaky
## outline, hatching on the side away from the light, crosshatch in the dark.
func _ink_ellipse(c: Vector2, r: Vector2, rot: float, dark: float = 1.0) -> void:
	var s := sc()
	var basis := Transform2D(rot, Vector2.ZERO)
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * float(i) / 40.0
		pts.append(c + basis * Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, Color(0.86, 0.8, 0.66, 0.9))
	var light := Vector2(-0.6, -0.8)
	for pass_i in 2:
		var th := 0.12 + 0.38 * pass_i
		if pass_i == 1 and dark < 0.6:
			break
		var dir := Vector2(1, 1).normalized() if pass_i == 0 else Vector2(1, -1).normalized()
		var nrm := dir.orthogonal()
		var shade := -light.normalized()
		var spacing := 0.11 / dark
		var d := -1.0
		while d <= 1.0:
			var half := sqrt(maxf(1.0 - d * d, 0.0))
			var lo := -half
			var hi := half
			# Keep the part of the chord on the shadow side (q . shade > th).
			var un := dir.dot(shade)
			var base := d * nrm.dot(shade)
			if absf(un) > 0.001:
				var s0 := (th - base) / un
				if un > 0.0:
					lo = maxf(lo, s0)
				else:
					hi = minf(hi, s0)
			elif base < th:
				hi = lo
			if hi > lo:
				var qa := nrm * d + dir * lo
				var qb := nrm * d + dir * hi
				draw_line(c + basis * (qa * r), c + basis * (qb * r), Color(INK, 0.55), 1.3 * s)
			d += spacing
	pts.append(pts[0])
	draw_polyline(pts, INK, 2.6 * s)
	var wob := PackedVector2Array()
	for i in 41:
		var a := TAU * float(i) / 40.0 + 0.1
		wob.append(c + basis * Vector2(cos(a) * r.x * 1.015, sin(a) * r.y * 0.99))
	draw_polyline(wob, Color(INK, 0.45), 1.2 * s)


## A jointed leg in ink from `a` through knee and ankle, with little spurs.
func _leg(a: Vector2, knee: Vector2, foot: Vector2, w: float) -> void:
	var s := sc()
	var ankle := knee.lerp(foot, 0.62)
	draw_polyline(PackedVector2Array([a, knee, ankle, foot]), INK, w * s)
	for p: Vector2 in [knee, ankle]:
		draw_circle(p, w * 0.9 * s, INK)
	var spur := (foot - ankle).orthogonal().normalized() * 6.0 * s
	draw_line(ankle.lerp(foot, 0.5), ankle.lerp(foot, 0.5) + spur, INK, 1.2 * s)


func _ink_bug(c: Vector2, k: float) -> void:
	var s := sc()
	match _plan:
		"spider":
			for side: float in [-1.0, 1.0]:
				for i in 4:
					var a := c + Vector2(side * 0.12, -0.32 + i * 0.07) * k
					var ang := lerpf(-1.1, 1.1, i / 3.0)
					var knee := a + Vector2(side * cos(ang * 0.6) * 0.55, -0.35 + i * 0.22) * k
					var foot := knee + Vector2(side * 0.32, 0.3 + i * 0.05) * k
					_leg(a, knee, foot, 3.4)
			_ink_ellipse(c + Vector2(0, 0.42) * k, Vector2(0.36, 0.48) * k, 0.0, 1.2)
			_ink_ellipse(c + Vector2(0, -0.26) * k, Vector2(0.24, 0.26) * k, 0.0, 0.8)
			for i in 4:
				draw_circle(c + Vector2(-0.09 + i * 0.06, -0.44) * k, 0.025 * k, INK)
			for side: float in [-1.0, 1.0]:
				_leg(c + Vector2(side * 0.06, -0.46) * k, c + Vector2(side * 0.1, -0.56) * k, c + Vector2(side * 0.05, -0.62) * k, 3.0)
			# Markings on the abdomen.
			for i in 3:
				draw_arc(c + Vector2(0, 0.3 + i * 0.13) * k, (0.2 - i * 0.04) * k, PI * 1.15, PI * 1.85, 16, INK, 2.0 * s)
		"scorpion":
			for side: float in [-1.0, 1.0]:
				for i in 4:
					var a := c + Vector2(side * 0.14, -0.05 + i * 0.12) * k
					_leg(a, a + Vector2(side * 0.32, -0.08) * k, a + Vector2(side * 0.5, 0.18) * k, 3.0)
				# Claws.
				var sh := c + Vector2(side * 0.12, -0.32) * k
				var el := sh + Vector2(side * 0.3, -0.18) * k
				_leg(sh, el, el + Vector2(side * 0.05, -0.2) * k, 4.0)
				_ink_ellipse(el + Vector2(side * 0.08, -0.32) * k, Vector2(0.11, 0.17) * k, side * 0.3, 1.0)
			_ink_ellipse(c + Vector2(0, 0.08) * k, Vector2(0.2, 0.42) * k, 0.0, 1.1)
			# The tail: segments curling up and over, a stinger at the end.
			var prev := c + Vector2(0, 0.48) * k
			for i in 6:
				var a := PI * 0.5 - i * 0.42
				var p := c + Vector2(0.22 + cos(a) * 0.28, 0.38 - sin(a) * 0.5) * k
				_ink_ellipse((prev + p) * 0.5, Vector2(0.07, 0.05) * k, (p - prev).angle(), 0.7)
				prev = p
			draw_colored_polygon(PackedVector2Array([prev, prev + Vector2(-0.12, -0.04) * k, prev + Vector2(-0.02, 0.08) * k]), INK)
		"flier":
			for side: float in [-1.0, 1.0]:
				for w in 2:
					var root := c + Vector2(side * 0.06, -0.15 + w * 0.12) * k
					var tip := root + Vector2(side * (0.85 - w * 0.12), -0.12 + w * 0.2) * k
					var wing := PackedVector2Array()
					for i in 21:
						var tt := float(i) / 20.0
						var p := root.lerp(tip, tt)
						wing.append(p + Vector2(0, -sin(tt * PI) * 0.1 * k))
					for i in 21:
						var tt := 1.0 - float(i) / 20.0
						var p := root.lerp(tip, tt)
						wing.append(p + Vector2(0, sin(tt * PI) * 0.07 * k))
					draw_colored_polygon(wing, Color(0.8, 0.84, 0.86, 0.5))
					wing.append(wing[0])
					draw_polyline(wing, INK, 1.8 * s)
					for v in 5:
						draw_line(root, root.lerp(tip, 0.4 + v * 0.14) + Vector2(0, (v - 2) * 0.02 * k), Color(INK, 0.5), 1.0 * s)
			for i in 6:
				_ink_ellipse(c + Vector2(0, 0.05 + i * 0.12) * k, Vector2(0.07 - i * 0.004, 0.07) * k, 0.0, 0.9)
			_ink_ellipse(c + Vector2(0, -0.16) * k, Vector2(0.12, 0.13) * k, 0.0, 0.9)
			for side: float in [-1.0, 1.0]:
				_ink_ellipse(c + Vector2(side * 0.08, -0.32) * k, Vector2(0.075, 0.07) * k, 0.0, 1.3)
				for i in 3:
					var a := c + Vector2(side * 0.08, -0.12 + i * 0.07) * k
					_leg(a, a + Vector2(side * 0.18, 0.08) * k, a + Vector2(side * 0.2, 0.25) * k, 2.4)
		"mite":
			for side: float in [-1.0, 1.0]:
				for i in 4:
					var a := c + Vector2(side * 0.3, -0.2 + i * 0.14) * k
					_leg(a, a + Vector2(side * 0.2, -0.06) * k, a + Vector2(side * 0.32, 0.12) * k, 3.0)
			_ink_ellipse(c + Vector2(0, 0.05) * k, Vector2(0.42, 0.4) * k, 0.0, 1.2)
			_ink_ellipse(c + Vector2(0, -0.38) * k, Vector2(0.12, 0.08) * k, 0.0, 1.0)
		"mantis":
			for side: float in [-1.0, 1.0]:
				for i in 2:
					var a := c + Vector2(side * 0.06, 0.1 + i * 0.12) * k
					_leg(a, a + Vector2(side * 0.36, -0.1) * k, a + Vector2(side * 0.46, 0.34) * k, 2.6)
				var sh := c + Vector2(side * 0.06, -0.28) * k
				var el := sh + Vector2(side * 0.22, 0.1) * k
				_leg(sh, el, el + Vector2(side * -0.04, -0.3) * k, 4.0)
			_ink_ellipse(c + Vector2(0, 0.42) * k, Vector2(0.12, 0.34) * k, 0.0, 1.0)
			_ink_ellipse(c + Vector2(0, -0.08) * k, Vector2(0.06, 0.26) * k, 0.0, 0.8)
			_ink_ellipse(c + Vector2(0, -0.42) * k, Vector2(0.13, 0.08) * k, 0.0, 0.9)
		_:
			# Beetle: six legs, head with mandibles and antennae, pronotum, split elytra.
			for side: float in [-1.0, 1.0]:
				for i in 3:
					var a := c + Vector2(side * 0.2, -0.12 + i * 0.2) * k
					var knee := a + Vector2(side * 0.32, -0.12 + i * 0.06) * k
					_leg(a, knee, knee + Vector2(side * 0.2, 0.22 + i * 0.05) * k, 3.6)
				_leg(c + Vector2(side * 0.08, -0.58) * k, c + Vector2(side * 0.22, -0.82) * k, c + Vector2(side * 0.36, -0.9) * k, 1.8)
				draw_polyline(PackedVector2Array([c + Vector2(side * 0.05, -0.62) * k, c + Vector2(side * 0.12, -0.74) * k, c + Vector2(side * 0.03, -0.8) * k]), INK, 4.0 * s)
			_ink_ellipse(c + Vector2(0, 0.25) * k, Vector2(0.34, 0.5) * k, 0.0, 1.2)
			draw_line(c + Vector2(0, -0.22) * k, c + Vector2(0, 0.74) * k, INK, 2.4 * s)
			_ink_ellipse(c + Vector2(0, -0.32) * k, Vector2(0.27, 0.15) * k, 0.0, 0.9)
			_ink_ellipse(c + Vector2(0, -0.53) * k, Vector2(0.12, 0.09) * k, 0.0, 1.0)
			for side: float in [-1.0, 1.0]:
				for i in 4:
					draw_arc(c + Vector2(side * 0.16, 0.0 + i * 0.16) * k, 0.03 * k, 0, TAU, 10, Color(INK, 0.7), 1.2 * s)


## Annotation arrows from labels in the margins to the spots they name.
func _arrows(c: Vector2, k: float) -> void:
	var s := sc()
	var hand := slanted(BARLOW, 0.26)
	var left_y := c.y - k * 0.6
	var right_y := c.y - k * 0.5
	for n: Array in _notes:
		var side := int(n[2])
		var target := c + (n[1] as Vector2) * k
		var lx := c.x + side * k * 1.25
		var ly := left_y if side < 0 else right_y
		if side < 0:
			left_y += k * 0.5
		else:
			right_y += k * 0.55
		var label := str(n[0])
		var px := fit_px(hand, label, 30.0, k * 1.1)
		text(hand, Vector2(lx, ly), label, px, SEPIA, HORIZONTAL_ALIGNMENT_RIGHT if side < 0 else HORIZONTAL_ALIGNMENT_LEFT)
		var from := Vector2(lx + (12.0 if side < 0 else -12.0) * s, ly + 14.0 * s)
		var mid := from.lerp(target, 0.5) + Vector2(0, -30.0 * s)
		var curve := PackedVector2Array()
		for i in 13:
			var tt := float(i) / 12.0
			curve.append(from.lerp(mid, tt).lerp(mid.lerp(target, tt), tt))
		draw_polyline(curve, Color(SEPIA, 0.9), 2.0 * s)
		var dir := (target - curve[curve.size() - 2]).normalized()
		var side_v := dir.orthogonal() * 7.0 * s
		draw_colored_polygon(PackedVector2Array([target, target - dir * 16.0 * s + side_v, target - dir * 16.0 * s - side_v]), SEPIA)


## A red rubber stamp, crooked, its ink patchy.
func _stamp(c: Vector2, word: String) -> void:
	var s := sc()
	draw_set_transform(c, -0.18, Vector2.ONE)
	var f := font(BARLOW_XB)
	var px := 46.0
	var w := text_w(f, word, px) + 40.0 * s
	var r := Rect2(Vector2(-w * 0.5, -40.0 * s), Vector2(w, 80.0 * s))
	draw_rect(r, Color(STAMP, 0.85), false, 5.0 * s)
	draw_rect(r.grow(-9.0 * s), Color(STAMP, 0.6), false, 2.0 * s)
	text(f, Vector2.ZERO, word, px, Color(STAMP, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The pen nib drawing a circle round and round in the margin, ink pooling.
func _nib(c: Vector2, r: float) -> void:
	var s := sc()
	var period := 1.5
	var k := fposmod(t, period) / period
	var start := -PI * 0.5
	var end := start + TAU * k
	draw_arc(c, r, start, end, 48, Color(INK, 0.85), 3.4 * s)
	# The finished rings left behind, fainter each lap (one per lap, three at most).
	var laps := mini(int(t / period), 3)
	for i in laps:
		draw_arc(c, r + (i + 1) * 5.0 * s, 0, TAU, 48, Color(INK, 0.18 - i * 0.05), 1.6 * s)
	var tip := c + Vector2(cos(end), sin(end)) * r
	var pool := 4.0 + 2.0 * sin(t * 6.0)
	draw_circle(tip, pool * s, INK)
	# The nib: a steel tapered point with its slit and breather hole, angled up and out.
	var dir := Vector2(cos(end + 0.6), sin(end + 0.6) - 1.2).normalized()
	var side := dir.orthogonal()
	var nib := PackedVector2Array([tip, tip + dir * 36.0 * s + side * 9.0 * s, tip + dir * 58.0 * s + side * 8.0 * s,
		tip + dir * 58.0 * s - side * 8.0 * s, tip + dir * 36.0 * s - side * 9.0 * s])
	draw_colored_polygon(nib, Color("#8A96A0"))
	draw_polyline(PackedVector2Array(Array(nib) + [tip]), INK, 1.5 * s)
	draw_line(tip, tip + dir * 30.0 * s, INK, 1.2 * s)
	draw_circle(tip + dir * 32.0 * s, 2.4 * s, INK)
	draw_line(tip + dir * 58.0 * s, tip + dir * 120.0 * s, Color("#5A3A22"), 12.0 * s)
	text(font(TYPE), c + Vector2(0, r + 34.0 * s), note_text("sketching..."), 18.0, Color(SEPIA, 0.7))

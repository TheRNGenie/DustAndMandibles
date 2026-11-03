class_name StoryPortrait
extends RefCounted
## Radio portraits of the Lucky Mandible's crew: painted busts in a western
## poster style, drawn in code (StoryPortrait.Painter: layered flat shapes with
## cel shadows cut by shifting each shape toward the light, ink outlines,
## tapered strokes for brows, wrinkles and hair, a sunburst card behind). Each
## renders once into its own SubViewport (cached per host).
##   Captain Ada Stroud: weathered, auburn hair tied back, a scar, a smirk,
##     a leather flying hat with brass goggles on the band, red silk scarf,
##     sheepskin collar. Sky-teal card.
##   Silas Kettle: old, bald and furious, a grey walrus moustache, bushy brows,
##     a monocle on a chain, a bulb of a nose, leather apron. Forge-orange card.
##   Pearl "Snake Eyes" Doyle: sly, sharp-eyed, black bob, a flat gambler's
##     hat with the ace of hearts in the band, pearl drop earrings, red lips,
##     a beauty mark, a lace choker. Casino-green card.
##   Doc Whitlow: frazzled, wild white hair, round thick spectacles, mutton
##     chops, worried brows, bow tie, an ink smudge, a pencil behind his ear.
##     Lab-green card.
## The Board and its hangers-on (the railroad story):
##   Cornelius Vane, Chairman: gaunt and cold, slicked silver hair, long grey
##     sideburns, pale eyes, thin lips, a silk top hat, starched collar, black
##     cravat with an amber pin. Oxblood card.
##   Ashby Crane, the Board's agent: a big gold-toothed grin, pomaded centre
##     parting, pencil moustache, a bowler and a mustard check suit. Brass card.
##   Ezra Kettle, director: very old, Silas's bulb nose and walrus moustache gone
##     white, deep-set eyes behind pince-nez, hollow cheeks, a fur collar and a
##     gold watch chain. Slate card.
##   Lucky Moreau, the amber fence: dark-skinned, a sly half-grin, a slouch hat
##     with a hawk feather, a gold hoop, a red bandana and an amber pendant,
##     a cigarillo. Amber card.

## speaker -> [card colour, card ray colour]
const CAST: Dictionary = {
	"stroud": [Color("#5E8C8F"), Color("#7FAFAE")],
	"kettle": [Color("#B5582C"), Color("#D9803F")],
	"pearl": [Color("#2F5E4A"), Color("#3F7A5E")],
	"doc": [Color("#6E7F4E"), Color("#93A36A")],
	"vane": [Color("#4E1A1E"), Color("#74282C")],
	"crane": [Color("#7E6326"), Color("#A88838")],
	"ezra": [Color("#3A424C"), Color("#566170")],
	"lucky": [Color("#8A4E12"), Color("#C07A24")],
}
const SIZE := Vector2i(512, 512)

static var _cache: Dictionary = {}


static func texture(host: Node, who: String) -> Texture2D:
	if _cache.has(who) and is_instance_valid(_cache[who]["vp"]):
		return _cache[who]["tex"]
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.msaa_2d = Viewport.MSAA_4X
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var p := Painter.new()
	p.who = who if CAST.has(who) else "stroud"
	vp.add_child(p)
	host.add_child(vp)
	_cache[who] = {"vp": vp, "tex": vp.get_texture()}
	return vp.get_texture()


## A round brass-rimmed frame `px` across with this speaker's face in it.
static func framed(host: Node, who: String, px: float) -> Control:
	var ring := Panel.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color("#3A2614")
	rsb.border_color = Color("#C9A04A")
	rsb.set_border_width_all(maxi(int(px / 28.0), 2))
	rsb.set_corner_radius_all(int(px * 0.5))
	rsb.anti_aliasing = true
	ring.add_theme_stylebox_override("panel", rsb)
	ring.custom_minimum_size = Vector2(px, px)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := maxf(px / 28.0, 2.0) + 1.0
	var mask := Panel.new()
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color.WHITE
	msb.set_corner_radius_all(int(px * 0.5 - inset))
	msb.anti_aliasing = true
	mask.add_theme_stylebox_override("panel", msb)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.offset_left = inset
	mask.offset_top = inset
	mask.offset_right = -inset
	mask.offset_bottom = -inset
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(mask)
	var pic := TextureRect.new()
	pic.texture = face_texture(host, who)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(pic)
	return ring


## The head and shoulders only (for small round frames: the radio card).
static func face_texture(host: Node, who: String) -> Texture2D:
	var key := who + ":face"
	if _cache.has(key) and is_instance_valid(_cache[key]["vp"]):
		return _cache[key]["tex"]
	var a := AtlasTexture.new()
	a.atlas = texture(host, who)
	a.region = Rect2(96, 90, 320, 320)
	_cache[key] = {"vp": _cache[who]["vp"], "tex": a}
	return a


## Draws one portrait (512 x 512). Light comes from the upper left.
class Painter extends Node2D:
	const INK := Color("#2B1B17")
	## Shadows fall this way (down and right).
	const SHADE := Vector2(13, 9)

	var who := "stroud"

	func _draw() -> void:
		var spec: Array = CAST[who]
		_card(spec[0], spec[1])
		match who:
			"stroud":
				_stroud()
			"kettle":
				_kettle()
			"pearl":
				_pearl()
			"doc":
				_doc()
			"vane":
				_vane()
			"crane":
				_crane()
			"ezra":
				_ezra()
			"lucky":
				_lucky()
		_vignette()

	# ------------------------------------------------------------------ the card

	func _card(base: Color, ray: Color) -> void:
		draw_rect(Rect2(0, 0, 512, 512), base)
		# A sunburst behind the head, like a poster.
		var c := Vector2(256, 230)
		for k in 18:
			var a0 := TAU * k / 18.0
			var a1 := a0 + TAU / 36.0
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * 520.0, c + Vector2.from_angle(a1) * 520.0]), Color(ray, 0.55))
		# A soft glow round the head.
		for i in 6:
			draw_circle(c, 230.0 - i * 30.0, Color(1.0, 0.95, 0.8, 0.05))
		# Paper grain.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(who)
		for i in 500:
			draw_circle(Vector2(rng.randf() * 512.0, rng.randf() * 512.0), rng.randf_range(0.6, 1.8), Color(0, 0, 0, rng.randf_range(0.03, 0.08)))

	func _vignette() -> void:
		for i in 10:
			var w := 10.0 + i * 7.0
			draw_arc(Vector2(256, 256), 256.0 + 40.0 - i * 6.0, 0.0, TAU, 96, Color(0.1, 0.05, 0.02, 0.05), w, true)

	# ------------------------------------------------------------------ helpers

	## A smooth closed outline through control points (Catmull-Rom).
	func blob(ctrl: Array, per: int = 8) -> PackedVector2Array:
		var out := PackedVector2Array()
		var n := ctrl.size()
		for i in n:
			var p0: Vector2 = ctrl[(i - 1 + n) % n]
			var p1: Vector2 = ctrl[i]
			var p2: Vector2 = ctrl[(i + 1) % n]
			var p3: Vector2 = ctrl[(i + 2) % n]
			for s in per:
				out.append(_cr(p0, p1, p2, p3, float(s) / per))
		return out

	## A smooth open line through control points.
	func curve(ctrl: Array, per: int = 8) -> PackedVector2Array:
		var out := PackedVector2Array()
		var n := ctrl.size()
		for i in n - 1:
			var p0: Vector2 = ctrl[maxi(i - 1, 0)]
			var p1: Vector2 = ctrl[i]
			var p2: Vector2 = ctrl[i + 1]
			var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
			for s in per:
				out.append(_cr(p0, p1, p2, p3, float(s) / per))
		out.append(ctrl[n - 1])
		return out

	func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
		var t2 := t * t
		var t3 := t2 * t
		return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

	func ell(c: Vector2, r: Vector2, rot: float = 0.0, n: int = 40) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in n:
			var a := TAU * i / n
			out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
		return out

	func fill(poly: PackedVector2Array, col: Color) -> void:
		if poly.size() >= 3:
			draw_colored_polygon(poly, col)

	func ink(poly: PackedVector2Array, w: float = 4.0, col: Color = INK) -> void:
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, col, w, true)

	## A flat shape with a cel shadow on its far side from the light, and an ink line.
	func shape(poly: PackedVector2Array, lit: Color, dark: Color = Color(), w: float = 4.0, shade: Vector2 = SHADE) -> void:
		if dark == Color():
			dark = lit.darkened(0.25)
		fill(poly, dark)
		var moved := PackedVector2Array()
		for p in poly:
			moved.append(p - shade)
		for part in Geometry2D.intersect_polygons(poly, moved):
			fill(part, lit)
		if w > 0.0:
			ink(poly, w)

	## Fills only the part of `poly` that lies inside `clip`.
	func clipped(poly: PackedVector2Array, clip: PackedVector2Array, col: Color) -> void:
		for part in Geometry2D.intersect_polygons(poly, clip):
			fill(part, col)

	## A tapered stroke along `ctrl`: width w0 at the start, w1 at the end (brows, wrinkles, locks).
	func taper(ctrl: Array, w0: float, w1: float, col: Color, mid: float = -1.0) -> void:
		var pts := curve(ctrl, 10)
		var n := pts.size()
		if n < 2:
			return
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in n:
			var t := float(i) / (n - 1)
			var d := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var nrm := Vector2(-d.y, d.x)
			var w := lerpf(w0, w1, t)
			if mid >= 0.0:
				w = lerpf(w0, mid, t * 2.0) if t < 0.5 else lerpf(mid, w1, (t - 0.5) * 2.0)
			left.append(pts[i] + nrm * w * 0.5)
			right.append(pts[i] - nrm * w * 0.5)
		right.reverse()
		left.append_array(right)
		fill(left, col)

	func line(ctrl: Array, w: float, col: Color = INK) -> void:
		draw_polyline(curve(ctrl, 8), col, w, true)

	## A face outline: forehead, temples, cheekbones, jaw and chin.
	func face(c: Vector2, w: float, h: float, jaw: float = 1.0, chin: float = 1.0) -> PackedVector2Array:
		var hw := w * 0.5
		var hh := h * 0.5
		return blob([
			c + Vector2(0, -hh), c + Vector2(hw * 0.72, -hh * 0.86), c + Vector2(hw * 0.98, -hh * 0.35),
			c + Vector2(hw * 1.0, hh * 0.1), c + Vector2(hw * 0.86 * jaw, hh * 0.55), c + Vector2(hw * 0.42 * chin, hh * 0.92),
			c + Vector2(0, hh), c + Vector2(-hw * 0.42 * chin, hh * 0.92), c + Vector2(-hw * 0.86 * jaw, hh * 0.55),
			c + Vector2(-hw * 1.0, hh * 0.1), c + Vector2(-hw * 0.98, -hh * 0.35), c + Vector2(-hw * 0.72, -hh * 0.86),
		], 10)

	## An eye: almond white, iris, pupil and glint, the upper lid down `lid` of the
	## way (tilted by `tilt`), a heavy lash line. `look` moves the iris.
	func eye(c: Vector2, w: float, h: float, iris: Color, skin: Color, look: Vector2 = Vector2.ZERO,
			lid: float = 0.15, tilt: float = 0.0, lash: float = 4.0, lower: float = 0.0) -> void:
		var hw := w * 0.5
		var al := blob([c + Vector2(-hw, 0.0), c + Vector2(-hw * 0.4, -h * 0.55), c + Vector2(hw * 0.35, -h * 0.58),
				c + Vector2(hw, -h * 0.05), c + Vector2(hw * 0.35, h * 0.42), c + Vector2(-hw * 0.4, h * 0.4)], 8)
		fill(al, Color("#F3EADB"))
		var ic := c + look + Vector2(0, h * 0.04)
		var ir := h * 0.46
		clipped(ell(ic, Vector2(ir, ir)), al, iris)
		clipped(ell(ic + Vector2(0, ir * 0.25), Vector2(ir * 0.8, ir * 0.7)), al, iris.darkened(0.3))
		clipped(ell(ic, Vector2(ir * 0.48, ir * 0.48)), al, Color("#120C0A"))
		draw_circle(ic + Vector2(-ir * 0.35, -ir * 0.38), ir * 0.24, Color(1, 1, 1, 0.95))
		# The upper lid comes down over the eye (skin), tilted.
		var lid_y := -h * 0.6 + h * 1.1 * lid
		var lid_poly := PackedVector2Array([c + Vector2(-hw * 1.3, -h * 2.0), c + Vector2(hw * 1.3, -h * 2.0),
				c + Vector2(hw * 1.3, lid_y + tilt * hw), c + Vector2(-hw * 1.3, lid_y - tilt * hw)])
		clipped(lid_poly, al, skin.darkened(0.12))
		if lower > 0.0:
			var low := PackedVector2Array([c + Vector2(-hw * 1.3, h * 0.5 - h * lower), c + Vector2(hw * 1.3, h * 0.5 - h * lower),
					c + Vector2(hw * 1.3, h * 2.0), c + Vector2(-hw * 1.3, h * 2.0)])
			clipped(low, al, skin.darkened(0.08))
		# Lash line along the lid's edge, heavier at the outer corner.
		taper([c + Vector2(-hw * 1.02, lid_y * 0.25 - tilt * hw * 0.5 + h * 0.05), c + Vector2(-hw * 0.4, lid_y - tilt * hw * 0.3),
				c + Vector2(hw * 0.35, lid_y + tilt * hw * 0.3), c + Vector2(hw * 1.08, lid_y * 0.2 + tilt * hw + h * 0.02)], lash * 0.6, lash * 1.2, INK)
		ink(al, 2.0, Color(INK, 0.7))

	# ------------------------------------------------------------------ Captain Ada Stroud

	func _stroud() -> void:
		var skin := Color("#E2A37E")
		var skin_d := Color("#B87358")
		var hair := Color("#A4492A")
		var hair_d := Color("#6E2A18")
		var c := Vector2(256, 262)
		# Hair tied back: the ponytail and loose locks behind the head.
		shape(blob([Vector2(330, 200), Vector2(372, 260), Vector2(380, 340), Vector2(352, 392), Vector2(330, 330), Vector2(318, 250)]), hair, hair_d)
		# Flight jacket and sheepskin collar.
		shape(blob([Vector2(40, 512), Vector2(70, 420), Vector2(150, 378), Vector2(256, 372), Vector2(362, 378), Vector2(442, 420), Vector2(472, 512)]), Color("#6B4228"), Color("#4A2C1A"))
		line([Vector2(256, 420), Vector2(250, 470), Vector2(246, 512)], 4.0)
		for sd: float in [-1.0, 1.0]:
			shape(blob([Vector2(256 + sd * 30, 392), Vector2(256 + sd * 110, 378), Vector2(256 + sd * 170, 412),
					Vector2(256 + sd * 130, 470), Vector2(256 + sd * 60, 440)]), Color("#EBDDBE"), Color("#C6B18C"))
			for k in 5:
				var p := Vector2(256 + sd * (60 + k * 22), 400 + k * 8)
				draw_arc(p, 9.0, 0.0, PI, 8, Color("#C6B18C"), 2.5, true)
		# Neck.
		shape(blob([Vector2(214, 330), Vector2(298, 330), Vector2(300, 392), Vector2(256, 404), Vector2(212, 392)]), skin_d.lightened(0.1), skin_d.darkened(0.1))
		# The red silk scarf, knotted, one tail blowing out.
		shape(blob([Vector2(196, 372), Vector2(256, 360), Vector2(318, 372), Vector2(314, 404), Vector2(256, 414), Vector2(198, 402)]), Color("#B8322A"), Color("#7E1E1A"))
		shape(blob([Vector2(268, 396), Vector2(312, 410), Vector2(350, 448), Vector2(336, 470), Vector2(300, 444), Vector2(262, 420)]), Color("#C93D32"), Color("#86221D"))
		shape(ell(Vector2(262, 404), Vector2(20, 16)), Color("#C93D32"), Color("#86221D"))
		# Ears.
		shape(ell(Vector2(178, 270), Vector2(14, 24)), skin, skin_d)
		shape(ell(Vector2(334, 270), Vector2(14, 24)), skin, skin_d)
		# The face: lean, a strong jaw.
		var f := face(c, 156, 196, 0.98, 1.05)
		shape(f, skin, skin_d, 4.0, Vector2(16, 6))
		# Weathering: cheek hollows, a jaw line, crow's feet, a scar.
		taper([Vector2(304, 280), Vector2(298, 312), Vector2(282, 338)], 3.0, 1.0, Color(skin_d, 0.8))
		taper([Vector2(212, 288), Vector2(214, 316)], 2.5, 0.5, Color(skin_d, 0.7))
		for sd: float in [-1.0, 1.0]:
			var ec := Vector2(256 + sd * 36, 254)
			for k in 3:
				taper([ec + Vector2(sd * 30, -4 + k * 6), ec + Vector2(sd * 42, -8 + k * 9)], 1.8, 0.4, Color(skin_d, 0.75))
		taper([Vector2(300, 268), Vector2(290, 292)], 3.0, 1.5, Color("#E9C3A6"))
		# Eyes: narrowed, steady, grey-green; one brow up.
		eye(Vector2(220, 256), 40, 22, Color("#5F7F68"), skin, Vector2(3, 0), 0.32, 0.06, 4.0, 0.12)
		eye(Vector2(292, 256), 40, 22, Color("#5F7F68"), skin, Vector2(3, 0), 0.3, -0.06, 4.0, 0.12)
		taper([Vector2(196, 234), Vector2(220, 226), Vector2(244, 232)], 9.0, 4.0, hair_d, 9.5)
		taper([Vector2(270, 228), Vector2(294, 216), Vector2(318, 226)], 4.0, 8.0, hair_d, 9.5)
		# Nose: straight, shadow down the right.
		taper([Vector2(262, 250), Vector2(266, 280), Vector2(270, 296)], 4.0, 7.0, Color(skin_d, 0.75))
		fill(blob([Vector2(248, 300), Vector2(258, 292), Vector2(274, 296), Vector2(270, 306), Vector2(256, 308)]), skin_d.lightened(0.05))
		draw_circle(Vector2(250, 288), 3.0, Color(1, 0.92, 0.85, 0.7))
		# The smirk: one corner up.
		taper([Vector2(232, 330), Vector2(252, 334), Vector2(272, 330), Vector2(288, 320)], 3.0, 4.0, Color("#7A3A2E"))
		taper([Vector2(282, 318), Vector2(292, 314)], 2.0, 1.0, Color(skin_d, 0.8))
		fill(blob([Vector2(240, 336), Vector2(258, 334), Vector2(274, 336), Vector2(258, 342)]), Color("#B76A5A"))
		# Hair: swept back under the hat, loose strands at the temples.
		shape(blob([Vector2(180, 214), Vector2(200, 186), Vector2(256, 172), Vector2(316, 184), Vector2(336, 216), Vector2(326, 236), Vector2(300, 210), Vector2(240, 204), Vector2(190, 230)]), hair, hair_d)
		taper([Vector2(184, 218), Vector2(176, 252), Vector2(184, 282)], 9.0, 2.0, hair)
		taper([Vector2(330, 222), Vector2(342, 256), Vector2(336, 286)], 8.0, 2.0, hair_d)
		taper([Vector2(204, 210), Vector2(196, 240)], 5.0, 1.0, hair_d)
		# The leather flying hat: a crown with a flat brim, the goggles on the band.
		var brim := blob([Vector2(118, 214), Vector2(170, 194), Vector2(256, 186), Vector2(346, 192), Vector2(398, 212), Vector2(350, 226), Vector2(256, 222), Vector2(160, 228)])
		shape(brim, Color("#5B3A22"), Color("#3D2615"))
		shape(blob([Vector2(176, 204), Vector2(184, 140), Vector2(222, 108), Vector2(256, 116), Vector2(292, 106), Vector2(330, 138), Vector2(338, 204), Vector2(256, 212)]), Color("#7A5132"), Color("#55361F"))
		line([Vector2(226, 112), Vector2(256, 130), Vector2(288, 110)], 3.0)
		shape(blob([Vector2(178, 196), Vector2(256, 204), Vector2(336, 196), Vector2(338, 182), Vector2(256, 188), Vector2(178, 180)]), Color("#3B2416"), Color("#2A190F"), 3.0)
		# Brass goggles on the band, lenses catching the sky.
		var strap := Color("#4A2F1C")
		taper([Vector2(176, 186), Vector2(336, 184)], 10.0, 10.0, strap)
		for gx: float in [222.0, 290.0]:
			var g := Vector2(gx, 176)
			shape(ell(g, Vector2(30, 26)), Color("#D9A83A"), Color("#9C7322"), 4.0, Vector2(5, 4))
			fill(ell(g, Vector2(21, 18)), Color("#2E4F57"))
			fill(ell(g + Vector2(-4, -3), Vector2(16, 13)), Color("#7FB8C8"))
			fill(blob([g + Vector2(-14, -6), g + Vector2(-6, -14), g + Vector2(-2, -10), g + Vector2(-10, -2)]), Color(1, 1, 1, 0.85))
			draw_circle(g + Vector2(26, 0), 3.0, Color("#6E5016"))
		shape(blob([Vector2(248, 172), Vector2(264, 172), Vector2(264, 182), Vector2(248, 182)]), Color("#B98A2E"), Color("#8A6420"), 2.5)

	# ------------------------------------------------------------------ Silas Kettle

	func _kettle() -> void:
		var skin := Color("#E0A288")
		var skin_d := Color("#B06D5A")
		var grey := Color("#D8D4CC")
		var grey_d := Color("#9C978F")
		var c := Vector2(256, 252)
		# Grey work shirt, leather apron with a bib pocket and brass rivets.
		shape(blob([Vector2(30, 512), Vector2(56, 418), Vector2(150, 372), Vector2(256, 366), Vector2(362, 372), Vector2(456, 418), Vector2(482, 512)]), Color("#8C8A84"), Color("#66645F"))
		shape(blob([Vector2(160, 512), Vector2(170, 410), Vector2(200, 392), Vector2(312, 392), Vector2(342, 410), Vector2(352, 512)]), Color("#7A4A28"), Color("#55321A"))
		taper([Vector2(180, 394), Vector2(150, 370), Vector2(120, 368)], 12.0, 10.0, Color("#55321A"))
		taper([Vector2(332, 394), Vector2(362, 370), Vector2(392, 368)], 12.0, 10.0, Color("#55321A"))
		shape(blob([Vector2(218, 440), Vector2(294, 440), Vector2(292, 488), Vector2(220, 488)], 2), Color("#8A5630"), Color("#663E22"), 3.0)
		for p: Vector2 in [Vector2(184, 404), Vector2(328, 404), Vector2(224, 446), Vector2(288, 446)]:
			draw_circle(p, 5.0, Color("#D9A83A"))
			draw_arc(p, 5.0, 0.0, TAU, 12, INK, 2.0, true)
		# A screwdriver and pencil in the pocket.
		taper([Vector2(236, 444), Vector2(232, 410)], 7.0, 6.0, Color("#C0392B"))
		taper([Vector2(270, 444), Vector2(276, 414)], 5.0, 2.0, Color("#E8C55A"))
		# Thick neck.
		shape(blob([Vector2(196, 320), Vector2(316, 320), Vector2(322, 384), Vector2(256, 398), Vector2(190, 384)]), skin_d.lightened(0.1), skin_d.darkened(0.08))
		# Ears, big.
		shape(ell(Vector2(166, 262), Vector2(18, 30)), skin, skin_d)
		shape(ell(Vector2(346, 262), Vector2(18, 30)), skin, skin_d)
		# A round, heavy face, jowly.
		var f := face(c, 180, 206, 1.12, 1.25)
		shape(f, skin, skin_d, 4.0, Vector2(16, 7))
		# The bald dome's shine and grey fringe over the ears.
		fill(ell(Vector2(222, 176), Vector2(26, 12), -0.3), Color(1, 0.95, 0.9, 0.55))
		for sd: float in [-1.0, 1.0]:
			shape(blob([Vector2(256 + sd * 76, 196), Vector2(256 + sd * 100, 214), Vector2(256 + sd * 104, 262),
					Vector2(256 + sd * 92, 290), Vector2(256 + sd * 82, 240)]), grey, grey_d, 3.0)
			for k in 3:
				taper([Vector2(256 + sd * 82, 208 + k * 20), Vector2(256 + sd * 106, 214 + k * 22)], 4.0, 1.0, grey)
		# Forehead furrows, scowl lines.
		for k in 3:
			line([Vector2(214 + k * 4, 182 + k * 12), Vector2(256, 176 + k * 12), Vector2(298 - k * 4, 182 + k * 12)], 2.5, Color(skin_d, 0.85))
		taper([Vector2(248, 222), Vector2(252, 238)], 3.0, 1.0, Color(skin_d, 0.9))
		taper([Vector2(264, 222), Vector2(260, 238)], 3.0, 1.0, Color(skin_d, 0.9))
		# Eyes: small and glaring, the right one behind a monocle.
		eye(Vector2(216, 246), 32, 18, Color("#5C6E8A"), skin, Vector2(4, 1), 0.38, 0.12, 4.0, 0.2)
		eye(Vector2(296, 246), 34, 20, Color("#5C6E8A"), skin, Vector2(2, 1), 0.34, -0.12, 4.0, 0.18)
		for sd: float in [-1.0, 1.0]:
			taper([Vector2(256 + sd * 26, 264), Vector2(256 + sd * 48, 272), Vector2(256 + sd * 62, 266)], 2.5, 1.0, Color(skin_d, 0.85))
		# Bushy grey brows, slammed down in the middle.
		for sd: float in [-1.0, 1.0]:
			var a := Vector2(256 + sd * 12, 232)
			var b := Vector2(256 + sd * 44, 218)
			var e := Vector2(256 + sd * 74, 222)
			taper([a, b, e], 13.0, 6.0, grey_d, 15.0)
			taper([a + Vector2(0, -3), b + Vector2(0, -4), e + Vector2(sd * 4, -6)], 9.0, 3.0, grey, 11.0)
			for k in 3:
				taper([b + Vector2(sd * (k * 10 - 8), -2), b + Vector2(sd * (k * 12 - 2), -14 + k * 2)], 3.5, 0.5, grey)
		# The monocle: brass ring, glass, a gleam and the chain.
		var mono := Vector2(296, 248)
		draw_circle(mono, 26.0, Color(0.75, 0.9, 1.0, 0.18))
		draw_arc(mono, 26.0, 0.0, TAU, 40, Color("#D9A83A"), 6.0, true)
		draw_arc(mono, 29.0, 0.0, TAU, 40, INK, 2.0, true)
		draw_arc(mono, 20.0, PI * 1.1, PI * 1.45, 10, Color(1, 1, 1, 0.8), 3.0, true)
		line([Vector2(318, 262), Vector2(338, 300), Vector2(330, 348), Vector2(312, 396)], 2.5, Color("#B98A2E"))
		# A big red bulb of a nose.
		shape(blob([Vector2(240, 270), Vector2(256, 256), Vector2(274, 270), Vector2(282, 298), Vector2(268, 314), Vector2(244, 314), Vector2(230, 298)]), Color("#D9826C"), Color("#A85A48"), 3.5)
		draw_circle(Vector2(248, 280), 5.0, Color(1, 0.92, 0.88, 0.75))
		# The walrus moustache: a great grey sweep over the mouth.
		var stache := blob([Vector2(256, 304), Vector2(282, 300), Vector2(320, 316), Vector2(338, 350), Vector2(316, 352), Vector2(290, 338),
				Vector2(256, 342), Vector2(222, 338), Vector2(196, 352), Vector2(174, 350), Vector2(192, 316), Vector2(230, 300)])
		shape(stache, grey, grey_d, 4.0, Vector2(8, 7))
		for k in 9:
			var x := 196.0 + k * 15.0
			taper([Vector2(x + 4, 312), Vector2(x + (k - 4) * 2.0, 344)], 3.0, 0.5, Color(grey_d, 0.8))
		# A sliver of a grumpy lower lip and the jowls.
		fill(blob([Vector2(238, 350), Vector2(256, 346), Vector2(274, 350), Vector2(256, 358)]), Color("#A85A48"))
		taper([Vector2(204, 330), Vector2(212, 358), Vector2(228, 372)], 3.0, 1.0, Color(skin_d, 0.9))
		taper([Vector2(308, 330), Vector2(300, 358), Vector2(284, 372)], 3.0, 1.0, Color(skin_d, 0.9))

	# ------------------------------------------------------------------ Pearl "Snake Eyes" Doyle

	func _pearl() -> void:
		var skin := Color("#F0C7A8")
		var skin_d := Color("#C98F74")
		var hair := Color("#1E1A22")
		var hair_d := Color("#0E0C12")
		var c := Vector2(256, 262)
		# Hair behind: a sleek black bob.
		shape(blob([Vector2(168, 230), Vector2(184, 174), Vector2(256, 160), Vector2(330, 176), Vector2(346, 236), Vector2(352, 330), Vector2(326, 352), Vector2(186, 352), Vector2(160, 330)]), hair, hair_d)
		# A high-collared plum dress with gold piping.
		shape(blob([Vector2(44, 512), Vector2(72, 424), Vector2(160, 386), Vector2(256, 380), Vector2(352, 386), Vector2(440, 424), Vector2(468, 512)]), Color("#5B2A57"), Color("#3B1A3A"))
		for sd: float in [-1.0, 1.0]:
			line([Vector2(256 + sd * 40, 400), Vector2(256 + sd * 90, 450), Vector2(256 + sd * 104, 512)], 3.0, Color("#D9A83A"))
		# Neck and the lace choker with a cameo.
		shape(blob([Vector2(222, 330), Vector2(290, 330), Vector2(294, 392), Vector2(256, 402), Vector2(218, 392)]), skin_d.lightened(0.12), skin_d)
		shape(blob([Vector2(218, 362), Vector2(294, 362), Vector2(296, 378), Vector2(256, 384), Vector2(216, 378)]), Color("#F2EDE4"), Color("#CFC6B8"), 3.0)
		for k in 9:
			draw_circle(Vector2(222 + k * 8.5, 384), 3.5, Color("#F2EDE4"))
		shape(ell(Vector2(256, 382), Vector2(12, 15)), Color("#E8C55A"), Color("#B38A2C"), 3.0, Vector2(3, 2))
		fill(ell(Vector2(256, 382), Vector2(7, 10)), Color("#F4E3D3"))
		# Ears with pearl drops on gold.
		for sd: float in [-1.0, 1.0]:
			var ear := Vector2(256 + sd * 76, 268)
			shape(ell(ear, Vector2(12, 20)), skin, skin_d)
			line([ear + Vector2(0, 16), ear + Vector2(sd * 2, 34)], 3.0, Color("#D9A83A"))
			shape(ell(ear + Vector2(sd * 2, 44), Vector2(9, 11)), Color("#FBF6EE"), Color("#D6CCBF"), 3.0, Vector2(3, 3))
			draw_circle(ear + Vector2(sd * 2 - 3, 40), 2.5, Color.WHITE)
		# A fine oval face with a pointed chin.
		var f := face(c, 146, 188, 0.86, 0.8)
		shape(f, skin, skin_d, 4.0, Vector2(14, 6))
		draw_circle(Vector2(214, 300), 14.0, Color(0.95, 0.5, 0.5, 0.18))
		draw_circle(Vector2(300, 300), 14.0, Color(0.95, 0.5, 0.5, 0.18))
		# Snake eyes: narrowed, knowing, green with heavy lashes and shadow.
		for sd: float in [-1.0, 1.0]:
			fill(ell(Vector2(256 + sd * 36, 250), Vector2(26, 14), sd * -0.12), Color("#8E5A86", 0.35))
		eye(Vector2(220, 256), 42, 22, Color("#3E9A5A"), skin, Vector2(5, 1), 0.42, 0.14, 6.0, 0.1)
		eye(Vector2(292, 256), 42, 22, Color("#3E9A5A"), skin, Vector2(5, 1), 0.42, -0.14, 6.0, 0.1)
		for sd: float in [-1.0, 1.0]:
			var outer := Vector2(256 + sd * 58, 250)
			taper([outer, outer + Vector2(sd * 12, -10)], 3.0, 0.5, INK)
			taper([outer + Vector2(-sd * 4, 2), outer + Vector2(sd * 10, -2)], 3.0, 0.5, INK)
		# Brows: thin, arched, the left one raised.
		taper([Vector2(196, 232), Vector2(218, 216), Vector2(242, 226)], 3.0, 2.0, hair, 5.0)
		taper([Vector2(270, 230), Vector2(294, 224), Vector2(318, 230)], 2.0, 3.0, hair, 5.0)
		# A neat nose.
		taper([Vector2(262, 262), Vector2(266, 288)], 2.0, 4.0, Color(skin_d, 0.6))
		fill(blob([Vector2(250, 296), Vector2(260, 290), Vector2(270, 296), Vector2(260, 300)]), Color(skin_d, 0.8))
		# The sly smile: red lips, one corner tucked up.
		var lips := blob([Vector2(234, 326), Vector2(247, 320), Vector2(256, 323), Vector2(267, 319), Vector2(284, 319),
				Vector2(276, 330), Vector2(258, 334), Vector2(240, 332)])
		shape(lips, Color("#C0283A"), Color("#8A1A28"), 3.0, Vector2(4, 4))
		line([Vector2(232, 326), Vector2(256, 328), Vector2(286, 320)], 2.5, Color("#5A0E18"))
		draw_circle(Vector2(246, 330), 2.5, Color(1, 1, 1, 0.6))
		# A beauty mark.
		draw_circle(Vector2(300, 314), 3.5, INK)
		# Bob fringe, sharp.
		shape(blob([Vector2(176, 250), Vector2(180, 196), Vector2(226, 168), Vector2(290, 168), Vector2(334, 196), Vector2(340, 248),
				Vector2(318, 214), Vector2(270, 202), Vector2(220, 206), Vector2(190, 226)]), hair, hair_d)
		taper([Vector2(300, 176), Vector2(326, 206), Vector2(334, 240)], 4.0, 1.0, Color("#4A4458"))
		# The flat-brimmed gambler's hat, tilted, the ace of hearts in its band.
		var tilt := -0.08
		var hc := Vector2(256, 168)
		shape(ell(hc + Vector2(0, 12), Vector2(150, 26), tilt), Color("#26222A"), Color("#141216"))
		shape(blob([hc + Vector2(-84, 14), hc + Vector2(-82, -38), hc + Vector2(-60, -54), hc + Vector2(60, -60), hc + Vector2(84, -44), hc + Vector2(80, 8), hc + Vector2(0, 2)]), Color("#2E2A33"), Color("#19171C"))
		shape(blob([hc + Vector2(-84, 12), hc + Vector2(0, 2), hc + Vector2(80, 6), hc + Vector2(81, -10), hc + Vector2(0, -14), hc + Vector2(-83, -4)]), Color("#7A1E2C"), Color("#561420"), 3.0)
		var card := hc + Vector2(48, -34)
		var cr := PackedVector2Array([card + Vector2(-16, -26).rotated(0.32), card + Vector2(16, -26).rotated(0.32), card + Vector2(16, 26).rotated(0.32), card + Vector2(-16, 26).rotated(0.32)])
		shape(cr, Color("#FBF6EE"), Color("#D6CCBF"), 3.0, Vector2(3, 3))
		var hp := card + Vector2(0, 2).rotated(0.32)
		fill(blob([hp + Vector2(0, 9), hp + Vector2(-9, -1), hp + Vector2(-5, -8), hp + Vector2(0, -4), hp + Vector2(5, -8), hp + Vector2(9, -1)]), Color("#C0283A"))
		draw_string(ThemeDB.fallback_font, card + Vector2(-13, -12).rotated(0.32), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#C0283A"))

	# ------------------------------------------------------------------ Doc Whitlow

	func _doc() -> void:
		var skin := Color("#EDC0A0")
		var skin_d := Color("#C08A70")
		var white := Color("#F4F1EA")
		var white_d := Color("#BDB7AD")
		var c := Vector2(256, 268)
		# Wild white hair behind: tufts in every direction.
		var tufts: Array = []
		for k in 15:
			var a := lerpf(-PI * 1.05, PI * 0.05, float(k) / 14.0) + sin(k * 3.7) * 0.06
			var side := absf(cos(a))
			var r := 96.0 + side * 34.0 + sin(k * 2.3) * 14.0
			tufts.append(Vector2(256, 236) + Vector2.from_angle(a) * r)
			tufts.append(Vector2(256, 236) + Vector2.from_angle(a + 0.11) * (r * 0.74))
		tufts.append(Vector2(350, 290))
		tufts.append(Vector2(162, 290))
		shape(blob(tufts, 5), white, white_d)
		# Lab coat over a waistcoat, a crooked bow tie.
		shape(blob([Vector2(36, 512), Vector2(66, 422), Vector2(150, 384), Vector2(256, 378), Vector2(362, 384), Vector2(446, 422), Vector2(476, 512)]), Color("#ECE6D8"), Color("#BDB4A2"))
		shape(blob([Vector2(196, 512), Vector2(206, 404), Vector2(256, 392), Vector2(306, 404), Vector2(316, 512)]), Color("#5D6B47"), Color("#3E4A2E"))
		for sd: float in [-1.0, 1.0]:
			shape(PackedVector2Array([Vector2(256 + sd * 18, 394), Vector2(256 + sd * 70, 392), Vector2(256 + sd * 60, 512), Vector2(256 + sd * 40, 512)]), Color("#E2DBCA"), Color("#B5AC98"), 3.0)
		draw_circle(Vector2(252, 440), 4.0, Color("#D9A83A"))
		draw_circle(Vector2(254, 470), 4.0, Color("#D9A83A"))
		# Neck and collar.
		shape(blob([Vector2(222, 334), Vector2(292, 334), Vector2(296, 388), Vector2(256, 398), Vector2(216, 388)]), skin_d.lightened(0.1), skin_d)
		shape(blob([Vector2(214, 372), Vector2(256, 392), Vector2(298, 372), Vector2(300, 392), Vector2(256, 406), Vector2(212, 392)]), Color("#FBF8F1"), Color("#D6D0C4"), 3.0)
		var bt := Vector2(256, 398)
		shape(blob([bt, bt + Vector2(-30, -16), bt + Vector2(-34, 8), bt + Vector2(-6, 6)]), Color("#8A2A3A"), Color("#5E1A27"), 3.0)
		shape(blob([bt, bt + Vector2(28, -6), bt + Vector2(34, 18), bt + Vector2(6, 6)]), Color("#8A2A3A"), Color("#5E1A27"), 3.0)
		shape(ell(bt, Vector2(8, 8)), Color("#A23446"), Color("#6E2030"), 3.0)
		# Ears and the pencil behind the right one.
		shape(ell(Vector2(182, 276), Vector2(14, 22)), skin, skin_d)
		taper([Vector2(318, 238), Vector2(366, 230)], 8.0, 8.0, Color("#E8C55A"))
		taper([Vector2(366, 230), Vector2(378, 228)], 7.0, 1.0, Color("#E3C6A0"))
		taper([Vector2(312, 239), Vector2(318, 238)], 8.0, 8.0, Color("#D98AA0"))
		shape(ell(Vector2(330, 276), Vector2(14, 22)), skin, skin_d)
		# A long, kindly, anxious face.
		var f := face(c, 148, 196, 0.92, 0.95)
		shape(f, skin, skin_d, 4.0, Vector2(14, 6))
		# Worry lines on the brow, an ink smudge on the cheek.
		for k in 3:
			line([Vector2(226, 196 + k * 10), Vector2(244, 190 + k * 10), Vector2(256, 194 + k * 10), Vector2(268, 190 + k * 10), Vector2(286, 196 + k * 10)], 2.0, Color(skin_d, 0.8))
		fill(blob([Vector2(206, 304), Vector2(222, 298), Vector2(228, 310), Vector2(214, 316)]), Color("#2E3A5A", 0.75))
		# Mutton chops, white and bushy, hugging the cheeks down to the jaw.
		for sd: float in [-1.0, 1.0]:
			var o := Vector2(256, 0)
			var pts := [o + Vector2(sd * 70, 246), o + Vector2(sd * 76, 282), o + Vector2(sd * 66, 322), o + Vector2(sd * 44, 344),
					o + Vector2(sd * 30, 336), o + Vector2(sd * 44, 310), o + Vector2(sd * 54, 276), o + Vector2(sd * 58, 250)]
			shape(blob(pts), white, white_d, 3.5, Vector2(5 * sd + 4, 5))
			for k in 5:
				taper([o + Vector2(sd * (66 - k * 4), 262 + k * 14), o + Vector2(sd * (56 - k * 5), 278 + k * 14)], 2.5, 0.5, white_d)
		# Big round spectacles; the eyes behind them wide and magnified.
		eye(Vector2(222, 258), 40, 30, Color("#6B4A2E"), skin, Vector2(-1, 0), 0.06, 0.0, 3.5)
		eye(Vector2(292, 258), 40, 30, Color("#6B4A2E"), skin, Vector2(-1, 0), 0.06, 0.0, 3.5)
		for gx: float in [222.0, 292.0]:
			var g := Vector2(gx, 258)
			draw_circle(g, 30.0, Color(0.8, 0.92, 1.0, 0.16))
			draw_arc(g, 31.0, 0.0, TAU, 44, INK, 7.0, true)
			draw_arc(g, 31.0, 0.0, TAU, 44, Color("#B98A2E"), 3.5, true)
			draw_arc(g, 22.0, PI * 1.05, PI * 1.4, 10, Color(1, 1, 1, 0.75), 3.0, true)
		line([Vector2(250, 256), Vector2(257, 250), Vector2(264, 256)], 4.0, Color("#B98A2E"))
		line([Vector2(191, 256), Vector2(182, 262)], 4.0, Color("#B98A2E"))
		line([Vector2(323, 256), Vector2(330, 262)], 4.0, Color("#B98A2E"))
		# Brows up in the middle: alarmed.
		taper([Vector2(192, 222), Vector2(220, 210), Vector2(246, 196)], 6.0, 10.0, Color("#8A847A"), 12.0)
		taper([Vector2(266, 196), Vector2(292, 210), Vector2(320, 222)], 10.0, 6.0, Color("#8A847A"), 12.0)
		taper([Vector2(196, 218), Vector2(222, 207), Vector2(244, 196)], 3.0, 5.0, white, 6.0)
		taper([Vector2(268, 196), Vector2(290, 207), Vector2(316, 218)], 5.0, 3.0, white, 6.0)
		# Long nose.
		taper([Vector2(260, 270), Vector2(268, 300), Vector2(270, 314)], 3.0, 7.0, Color(skin_d, 0.75))
		fill(blob([Vector2(246, 318), Vector2(258, 308), Vector2(276, 314), Vector2(270, 324), Vector2(254, 326)]), skin_d.lightened(0.05))
		draw_circle(Vector2(254, 300), 3.0, Color(1, 0.95, 0.9, 0.7))
		# An "oh dear" mouth, a little open.
		shape(blob([Vector2(242, 346), Vector2(256, 340), Vector2(272, 346), Vector2(268, 360), Vector2(256, 364), Vector2(244, 358)]), Color("#6A2A26"), Color("#4A1A18"), 3.0, Vector2(2, 2))
		fill(blob([Vector2(248, 344), Vector2(264, 344), Vector2(262, 348), Vector2(250, 348)]), Color("#F4F1EA"))
		# A bead of sweat.
		var sw := Vector2(320, 214)
		shape(blob([sw + Vector2(0, -12), sw + Vector2(7, 4), sw + Vector2(0, 10), sw + Vector2(-7, 4)]), Color("#CFEAF2"), Color("#8FC3D3"), 2.5, Vector2(2, 2))
		# Front tufts over the brow.
		for k in 5:
			var x := 214.0 + k * 22.0
			taper([Vector2(x, 186), Vector2(x + 6 + sin(k * 2.1) * 10.0, 166), Vector2(x + 14 + sin(k * 1.3) * 14.0, 150)], 14.0, 1.0, white)
			taper([Vector2(x + 2, 186), Vector2(x + 8, 170)], 3.0, 0.5, white_d)

	# ------------------------------------------------------------------ shared bits for the Board

	## A dark coat over the shoulders with lapels and a white shirt front.
	func _coat(col: Color, shirt: Color = Color("#F4F0E6")) -> void:
		shape(blob([Vector2(34, 512), Vector2(62, 420), Vector2(150, 380), Vector2(256, 374), Vector2(362, 380), Vector2(450, 420), Vector2(478, 512)]), col, col.darkened(0.35))
		shape(blob([Vector2(206, 512), Vector2(214, 400), Vector2(256, 388), Vector2(298, 400), Vector2(306, 512)]), shirt, shirt.darkened(0.18))
		for sd: float in [-1.0, 1.0]:
			shape(PackedVector2Array([Vector2(256 + sd * 22, 396), Vector2(256 + sd * 84, 392), Vector2(256 + sd * 66, 470), Vector2(256 + sd * 44, 512), Vector2(256 + sd * 30, 512)]),
					col.lightened(0.08), col.darkened(0.25), 3.0)

	# ------------------------------------------------------------------ Cornelius Vane

	func _vane() -> void:
		var skin := Color("#E4BFA6")
		var skin_d := Color("#B48C78")
		var silver := Color("#C9CCD0")
		var silver_d := Color("#8C9096")
		var c := Vector2(256, 266)
		_coat(Color("#1C1A20"))
		# Neck, a tall starched collar and a black cravat with an amber pin.
		shape(blob([Vector2(224, 330), Vector2(288, 330), Vector2(292, 380), Vector2(256, 390), Vector2(220, 380)]), skin_d.lightened(0.1), skin_d)
		for sd: float in [-1.0, 1.0]:
			shape(PackedVector2Array([Vector2(256 + sd * 4, 384), Vector2(256 + sd * 44, 350), Vector2(256 + sd * 52, 382), Vector2(256 + sd * 20, 396)]), Color("#FBF8F1"), Color("#D6D0C4"), 3.0)
		shape(blob([Vector2(230, 392), Vector2(256, 384), Vector2(282, 392), Vector2(270, 440), Vector2(256, 448), Vector2(242, 440)]), Color("#141216"), Color("#08070A"))
		shape(ell(Vector2(256, 412), Vector2(9, 12)), Color("#E89A2A"), Color("#A85E12"), 2.5, Vector2(3, 3))
		draw_circle(Vector2(253, 408), 3.0, Color(1, 0.95, 0.75, 0.9))
		# Ears.
		shape(ell(Vector2(182, 272), Vector2(13, 24)), skin, skin_d)
		shape(ell(Vector2(330, 272), Vector2(13, 24)), skin, skin_d)
		# A long, gaunt face, hollow cheeks.
		var f := face(c, 142, 206, 0.86, 0.9)
		shape(f, skin, skin_d, 4.0, Vector2(14, 6))
		taper([Vector2(206, 292), Vector2(214, 322), Vector2(226, 340)], 4.0, 1.0, Color(skin_d, 0.85))
		taper([Vector2(306, 292), Vector2(298, 322), Vector2(286, 340)], 4.0, 1.0, Color(skin_d, 0.85))
		# Long grey sideburns.
		for sd: float in [-1.0, 1.0]:
			shape(blob([Vector2(256 + sd * 66, 220), Vector2(256 + sd * 74, 262), Vector2(256 + sd * 70, 314), Vector2(256 + sd * 60, 318), Vector2(256 + sd * 58, 262)]), silver, silver_d, 3.0)
		# Pale, cold eyes, heavy-lidded; straight hard brows.
		eye(Vector2(222, 256), 36, 18, Color("#9FB6C4"), skin, Vector2(1, 1), 0.42, 0.0, 4.0, 0.14)
		eye(Vector2(290, 256), 36, 18, Color("#9FB6C4"), skin, Vector2(1, 1), 0.42, 0.0, 4.0, 0.14)
		taper([Vector2(196, 236), Vector2(222, 232), Vector2(246, 238)], 7.0, 4.0, silver_d)
		taper([Vector2(266, 238), Vector2(290, 232), Vector2(316, 236)], 4.0, 7.0, silver_d)
		taper([Vector2(250, 234), Vector2(254, 248)], 2.5, 1.0, Color(skin_d, 0.9))
		# A long sharp nose.
		taper([Vector2(258, 252), Vector2(264, 288), Vector2(266, 306)], 3.0, 7.0, Color(skin_d, 0.8))
		fill(blob([Vector2(248, 308), Vector2(260, 300), Vector2(274, 306), Vector2(268, 314), Vector2(254, 314)]), skin_d.lightened(0.05))
		# Thin, flat lips, turned down.
		taper([Vector2(232, 340), Vector2(256, 336), Vector2(280, 340)], 3.0, 3.0, Color("#6E3A34"))
		taper([Vector2(232, 340), Vector2(226, 348)], 2.0, 0.8, Color(skin_d, 0.9))
		taper([Vector2(280, 340), Vector2(286, 348)], 2.0, 0.8, Color(skin_d, 0.9))
		# Slicked silver hair under the hat.
		shape(blob([Vector2(186, 226), Vector2(196, 196), Vector2(256, 186), Vector2(316, 196), Vector2(326, 226), Vector2(256, 206)]), silver, silver_d, 3.0)
		# The silk top hat, tall, with a band.
		shape(ell(Vector2(256, 196), Vector2(124, 20), -0.02), Color("#121014"), Color("#060507"))
		shape(blob([Vector2(184, 198), Vector2(180, 70), Vector2(186, 52), Vector2(326, 52), Vector2(332, 70), Vector2(328, 198), Vector2(256, 204)], 4), Color("#1E1B22"), Color("#0C0B0E"))
		shape(blob([Vector2(182, 196), Vector2(256, 202), Vector2(330, 196), Vector2(330, 172), Vector2(256, 178), Vector2(182, 172)], 4), Color("#3A1418"), Color("#24090C"), 3.0)
		taper([Vector2(204, 70), Vector2(202, 180)], 6.0, 3.0, Color(1, 1, 1, 0.12))

	# ------------------------------------------------------------------ Ashby Crane

	func _crane() -> void:
		var skin := Color("#EBB792")
		var skin_d := Color("#C08262")
		var hair := Color("#2A1E16")
		var hair_d := Color("#120C08")
		var c := Vector2(256, 268)
		# Mustard check suit, a red carnation.
		var suit := Color("#B08A3A")
		_coat(suit)
		for k in 9:
			line([Vector2(70 + k * 46, 512), Vector2(110 + k * 34, 400)], 2.0, Color(suit.darkened(0.35), 0.5))
		shape(ell(Vector2(186, 432), Vector2(14, 13)), Color("#C0283A"), Color("#7E1824"), 2.5, Vector2(3, 3))
		# Neck, collar and a striped bow tie.
		shape(blob([Vector2(222, 334), Vector2(290, 334), Vector2(294, 386), Vector2(256, 396), Vector2(218, 386)]), skin_d.lightened(0.1), skin_d)
		var bt := Vector2(256, 396)
		shape(blob([bt, bt + Vector2(-32, -14), bt + Vector2(-32, 14)]), Color("#3A6E8A"), Color("#244C60"), 3.0)
		shape(blob([bt, bt + Vector2(32, -14), bt + Vector2(32, 14)]), Color("#3A6E8A"), Color("#244C60"), 3.0)
		shape(ell(bt, Vector2(8, 9)), Color("#4A84A2"), Color("#2C5C74"), 3.0)
		# Ears.
		shape(ell(Vector2(180, 272), Vector2(14, 22)), skin, skin_d)
		shape(ell(Vector2(332, 272), Vector2(14, 22)), skin, skin_d)
		# A round, well-fed face.
		var f := face(c, 158, 190, 1.06, 1.0)
		shape(f, skin, skin_d, 4.0, Vector2(14, 6))
		draw_circle(Vector2(208, 302), 16.0, Color(0.95, 0.45, 0.4, 0.22))
		draw_circle(Vector2(304, 302), 16.0, Color(0.95, 0.45, 0.4, 0.22))
		# Squinting smile-eyes and arched brows.
		for sd: float in [-1.0, 1.0]:
			var e := Vector2(256 + sd * 36, 260)
			taper([e + Vector2(-16, 4), e + Vector2(0, -6), e + Vector2(16, 4)], 4.5, 4.5, INK)
			taper([e + Vector2(sd * 18, 4), e + Vector2(sd * 28, 10)], 2.0, 0.5, Color(skin_d, 0.9))
			taper([e + Vector2(-22, -24), e + Vector2(0, -34), e + Vector2(22, -26)], 6.0, 4.0, hair, 8.0)
		# A button nose.
		fill(ell(Vector2(258, 292), Vector2(14, 11)), skin_d.lightened(0.08))
		draw_circle(Vector2(254, 287), 3.0, Color(1, 0.95, 0.9, 0.7))
		# The big grin, with a gold tooth.
		var grin := blob([Vector2(214, 322), Vector2(256, 330), Vector2(298, 322), Vector2(288, 348), Vector2(256, 358), Vector2(224, 348)])
		shape(grin, Color("#5A1E1A"), Color("#3A1210"), 3.5, Vector2(2, 2))
		clipped(blob([Vector2(214, 322), Vector2(256, 330), Vector2(298, 322), Vector2(294, 336), Vector2(256, 340), Vector2(218, 336)]), grin, Color("#F6F0E2"))
		clipped(PackedVector2Array([Vector2(266, 326), Vector2(278, 324), Vector2(278, 340), Vector2(266, 340)]), grin, Color("#E8C04A"))
		for k in 5:
			line([Vector2(234 + k * 12, 330), Vector2(234 + k * 12, 338)], 1.5, Color(INK, 0.5))
		# Pencil moustache.
		taper([Vector2(226, 314), Vector2(256, 310), Vector2(286, 314)], 2.0, 2.0, hair_d, 4.0)
		# Pomaded hair, centre parting, shining.
		shape(blob([Vector2(180, 238), Vector2(186, 196), Vector2(226, 176), Vector2(256, 190), Vector2(286, 176), Vector2(326, 196), Vector2(332, 238), Vector2(306, 210), Vector2(256, 200), Vector2(206, 210)]), hair, hair_d)
		taper([Vector2(206, 196), Vector2(232, 186)], 4.0, 1.0, Color(1, 1, 1, 0.45))
		taper([Vector2(282, 186), Vector2(306, 196)], 1.0, 4.0, Color(1, 1, 1, 0.45))
		# The bowler, tipped back.
		shape(ell(Vector2(256, 182), Vector2(116, 18), 0.05), Color("#3A2A1E"), Color("#22170F"))
		shape(blob([Vector2(184, 182), Vector2(192, 128), Vector2(226, 100), Vector2(286, 100), Vector2(320, 128), Vector2(328, 182), Vector2(256, 188)]), Color("#4A3626"), Color("#2C1F14"))
		shape(blob([Vector2(186, 180), Vector2(256, 186), Vector2(326, 180), Vector2(326, 164), Vector2(256, 170), Vector2(186, 164)], 4), Color("#1E140C"), Color("#100A06"), 3.0)
		taper([Vector2(214, 120), Vector2(206, 160)], 6.0, 2.0, Color(1, 1, 1, 0.15))

	# ------------------------------------------------------------------ Ezra Kettle

	func _ezra() -> void:
		var skin := Color("#DDB09A")
		var skin_d := Color("#A87C68")
		var white := Color("#EDEAE4")
		var white_d := Color("#ADA89F")
		var c := Vector2(256, 262)
		# Black frock coat with a fur collar, a gold watch chain.
		_coat(Color("#26222A"), Color("#E8E4DA"))
		for sd: float in [-1.0, 1.0]:
			shape(blob([Vector2(256 + sd * 34, 388), Vector2(256 + sd * 120, 372), Vector2(256 + sd * 190, 420), Vector2(256 + sd * 150, 476), Vector2(256 + sd * 70, 444)]), Color("#6A5444"), Color("#433428"))
			for k in 6:
				taper([Vector2(256 + sd * (70 + k * 20), 396 + k * 9), Vector2(256 + sd * (80 + k * 20), 412 + k * 9)], 4.0, 0.5, Color("#8A7262"))
		line([Vector2(236, 470), Vector2(270, 490), Vector2(300, 476)], 3.0, Color("#D9A83A"))
		# A thin old neck, a high collar.
		shape(blob([Vector2(226, 326), Vector2(286, 326), Vector2(290, 384), Vector2(256, 394), Vector2(222, 384)]), skin_d.lightened(0.08), skin_d)
		taper([Vector2(244, 340), Vector2(248, 380)], 2.5, 1.0, Color(skin_d.darkened(0.2), 0.7))
		taper([Vector2(268, 340), Vector2(264, 380)], 2.5, 1.0, Color(skin_d.darkened(0.2), 0.7))
		# Big old ears.
		shape(ell(Vector2(170, 266), Vector2(17, 30)), skin, skin_d)
		shape(ell(Vector2(342, 266), Vector2(17, 30)), skin, skin_d)
		# A skull-like old face: Silas's shape, gone hollow.
		var f := face(c, 166, 204, 1.0, 1.1)
		shape(f, skin, skin_d, 4.0, Vector2(15, 7))
		fill(ell(Vector2(216, 304), Vector2(16, 22)), Color(skin_d, 0.45))
		fill(ell(Vector2(300, 304), Vector2(16, 22)), Color(skin_d, 0.45))
		# Liver spots and a thin white combover.
		for p: Vector2 in [Vector2(226, 186), Vector2(290, 196), Vector2(310, 220), Vector2(206, 214)]:
			draw_circle(p, 5.0, Color(skin_d, 0.55))
		for k in 5:
			taper([Vector2(200 + k * 6, 210 - k * 6), Vector2(256, 176 + k * 3), Vector2(320 - k * 4, 196 + k * 4)], 3.0, 1.0, white)
		# Deep-set eyes, cruel and small, behind pince-nez.
		for sd: float in [-1.0, 1.0]:
			fill(ell(Vector2(256 + sd * 38, 250), Vector2(26, 18)), Color(skin_d.darkened(0.15), 0.6))
		eye(Vector2(218, 252), 30, 16, Color("#5C6E8A"), skin, Vector2(2, 1), 0.4, 0.14, 3.5, 0.2)
		eye(Vector2(294, 252), 30, 16, Color("#5C6E8A"), skin, Vector2(2, 1), 0.4, -0.14, 3.5, 0.2)
		for gx: float in [218.0, 294.0]:
			draw_arc(Vector2(gx, 252), 21.0, 0.0, TAU, 32, Color("#B98A2E"), 3.0, true)
			draw_arc(Vector2(gx, 252), 15.0, PI * 1.05, PI * 1.4, 8, Color(1, 1, 1, 0.7), 2.5, true)
		line([Vector2(239, 250), Vector2(256, 244), Vector2(273, 250)], 3.0, Color("#B98A2E"))
		line([Vector2(197, 254), Vector2(186, 300), Vector2(196, 360)], 1.5, Color("#B98A2E"))
		# White brows drawn down in a hard frown.
		for sd: float in [-1.0, 1.0]:
			taper([Vector2(256 + sd * 12, 232), Vector2(256 + sd * 40, 222), Vector2(256 + sd * 66, 228)], 10.0, 4.0, white_d, 11.0)
			taper([Vector2(256 + sd * 12, 229), Vector2(256 + sd * 40, 219), Vector2(256 + sd * 64, 224)], 6.0, 2.0, white, 7.0)
		for k in 3:
			line([Vector2(226, 200 + k * 9), Vector2(256, 196 + k * 9), Vector2(286, 200 + k * 9)], 2.0, Color(skin_d, 0.85))
		# The Kettle nose, sharper and bonier.
		shape(blob([Vector2(242, 266), Vector2(256, 254), Vector2(272, 266), Vector2(278, 296), Vector2(264, 310), Vector2(246, 310), Vector2(234, 296)]), Color("#C99480"), Color("#97685A"), 3.5)
		# The walrus moustache, white, waxed to points.
		var stache := blob([Vector2(256, 304), Vector2(280, 302), Vector2(316, 312), Vector2(348, 300), Vector2(330, 330), Vector2(290, 332),
				Vector2(256, 334), Vector2(222, 332), Vector2(182, 330), Vector2(164, 300), Vector2(196, 312), Vector2(232, 302)])
		shape(stache, white, white_d, 4.0, Vector2(7, 6))
		# A thin, downturned mouth and deep lines either side.
		taper([Vector2(236, 348), Vector2(256, 344), Vector2(276, 348)], 3.0, 3.0, Color("#6E3A34"))
		taper([Vector2(214, 322), Vector2(220, 352), Vector2(232, 372)], 3.0, 1.0, Color(skin_d, 0.9))
		taper([Vector2(298, 322), Vector2(292, 352), Vector2(280, 372)], 3.0, 1.0, Color(skin_d, 0.9))

	# ------------------------------------------------------------------ Lucky Moreau

	func _lucky() -> void:
		var skin := Color("#8A5A3C")
		var skin_d := Color("#5E3B26")
		var hair := Color("#1A1412")
		var c := Vector2(256, 266)
		# Long duster over a waistcoat.
		shape(blob([Vector2(34, 512), Vector2(64, 420), Vector2(150, 382), Vector2(256, 376), Vector2(362, 382), Vector2(448, 420), Vector2(478, 512)]), Color("#6A5240"), Color("#46352A"))
		shape(blob([Vector2(200, 512), Vector2(210, 404), Vector2(256, 394), Vector2(302, 404), Vector2(312, 512)]), Color("#2E3A44"), Color("#1C252C"))
		# Neck, a red bandana, an amber pendant on a cord.
		shape(blob([Vector2(224, 332), Vector2(290, 332), Vector2(294, 386), Vector2(256, 396), Vector2(218, 386)]), skin_d.lightened(0.1), skin_d)
		shape(blob([Vector2(204, 374), Vector2(256, 366), Vector2(310, 374), Vector2(290, 420), Vector2(256, 440), Vector2(222, 420)]), Color("#B8322A"), Color("#7E1E1A"))
		for p: Vector2 in [Vector2(236, 396), Vector2(270, 404), Vector2(254, 422)]:
			draw_circle(p, 3.0, Color("#F2E3C2"))
		line([Vector2(226, 378), Vector2(256, 452), Vector2(286, 378)], 2.0, INK)
		shape(blob([Vector2(256, 444), Vector2(270, 460), Vector2(256, 484), Vector2(242, 460)]), Color("#F0A030"), Color("#B0660E"), 3.0, Vector2(3, 3))
		fill(ell(Vector2(254, 462), Vector2(4, 6)), Color("#5A3008", 0.8))
		draw_circle(Vector2(250, 454), 3.0, Color(1, 0.95, 0.7, 0.9))
		# Ears, a gold hoop in the left.
		shape(ell(Vector2(180, 270), Vector2(13, 22)), skin, skin_d)
		shape(ell(Vector2(332, 270), Vector2(13, 22)), skin, skin_d)
		draw_arc(Vector2(178, 300), 11.0, 0.0, TAU, 24, Color("#E8C04A"), 4.0, true)
		# A lean, angular face with stubble.
		var f := face(c, 150, 194, 1.0, 0.95)
		shape(f, skin, skin_d, 4.0, Vector2(14, 6))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 140:
			var p := Vector2(rng.randf_range(196, 316), rng.randf_range(300, 360))
			if Geometry2D.is_point_in_polygon(p, f):
				draw_circle(p, 1.2, Color(hair, 0.35))
		# One eye narrowed, one brow up: the look of a man pricing you.
		eye(Vector2(222, 256), 38, 20, Color("#3A2416"), skin, Vector2(4, 0), 0.5, 0.1, 4.5, 0.15)
		eye(Vector2(290, 256), 38, 22, Color("#3A2416"), skin, Vector2(4, 0), 0.26, -0.04, 4.5, 0.1)
		taper([Vector2(198, 238), Vector2(222, 236), Vector2(246, 240)], 8.0, 5.0, hair)
		taper([Vector2(268, 232), Vector2(292, 218), Vector2(316, 226)], 5.0, 8.0, hair, 9.0)
		# Nose, broad.
		taper([Vector2(262, 256), Vector2(266, 286)], 3.0, 6.0, Color(skin_d, 0.8))
		fill(blob([Vector2(242, 300), Vector2(258, 290), Vector2(276, 300), Vector2(268, 310), Vector2(248, 310)]), skin_d.lightened(0.05))
		# A sly half-grin, the cigarillo in the other corner, smoke curling up.
		taper([Vector2(228, 334), Vector2(256, 338), Vector2(282, 330), Vector2(296, 318)], 3.5, 4.0, Color("#3A1E14"))
		fill(blob([Vector2(240, 340), Vector2(260, 338), Vector2(280, 334), Vector2(262, 346)]), Color("#7A4232"))
		taper([Vector2(222, 336), Vector2(176, 352)], 9.0, 8.0, Color("#6A3E22"))
		draw_circle(Vector2(174, 353), 5.0, Color("#E8602A"))
		taper([Vector2(170, 344), Vector2(160, 310), Vector2(172, 280), Vector2(158, 240)], 5.0, 1.0, Color(0.9, 0.9, 0.88, 0.35))
		# Thin moustache and a chin tuft.
		taper([Vector2(232, 318), Vector2(256, 314), Vector2(282, 316)], 3.0, 3.0, hair, 5.0)
		taper([Vector2(252, 356), Vector2(256, 372)], 6.0, 1.0, hair)
		# The slouch hat, brim pulled low on one side, a hawk feather in the band.
		shape(blob([Vector2(102, 214), Vector2(160, 186), Vector2(256, 176), Vector2(352, 182), Vector2(410, 196), Vector2(360, 214), Vector2(256, 216), Vector2(150, 232)]), Color("#3E2C20"), Color("#24180F"))
		shape(blob([Vector2(176, 196), Vector2(188, 136), Vector2(232, 112), Vector2(282, 112), Vector2(326, 132), Vector2(336, 192), Vector2(256, 200)]), Color("#54402E"), Color("#33251A"))
		line([Vector2(230, 116), Vector2(256, 136), Vector2(284, 116)], 3.0)
		shape(blob([Vector2(178, 192), Vector2(256, 198), Vector2(334, 190), Vector2(334, 174), Vector2(256, 182), Vector2(178, 176)], 4), Color("#8A2A1E"), Color("#5A1A12"), 3.0)
		var fe := Vector2(318, 180)
		shape(blob([fe, fe + Vector2(30, -60), fe + Vector2(46, -96), fe + Vector2(36, -58), fe + Vector2(8, -4)]), Color("#B87A42"), Color("#7A4E26"), 2.5, Vector2(3, 2))
		for k in 5:
			line([fe + Vector2(10 + k * 6, -14 - k * 14), fe + Vector2(22 + k * 6, -10 - k * 14)], 1.5, Color("#3A2414"))

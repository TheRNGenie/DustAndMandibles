class_name CasinoBoard
extends Control
## The live table on a casino game's screen: a Control that draws the game
## (felt, cards, reels, wheel, track) every frame from its game's `view` and how
## long ago that view arrived, so it can be rebuilt at any time (the menu redraws
## on every stock change) without losing its place in an animation. Subclasses
## draw in _draw_game() and take clicks in _click(). Also holds the shared
## drawing kit: felt, playing cards, chips and outlined text.

const RED := Color("#B3261E")
const INK := Color("#1E1A18")
const CREAM := Color("#FFFDF5")
const FELT := Color("#1F6B3A")
const FELT_DARK := Color("#14502A")
const GOLD := Color("#E9C46A")
const GOLD_DARK := Color("#9C7440")
const WOOD := Color("#6B3F22")
const WOOD_DARK := Color("#3B2312")

var game: CasinoGame
var _was_busy := false
var _mouse := Vector2(-1, -1)

static var _sign_font: Font
static var _rect_box: StyleBoxFlat


func _init(g: CasinoGame = null) -> void:
	game = g
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or game == null or not is_instance_valid(game):
		return
	queue_redraw()
	var busy := game.ui_busy()
	if _was_busy and not busy:
		game.ui_changed.emit() # the result is in: put the buttons back
	_was_busy = busy
	_tick()


## Per-frame hook (sounds that follow the animation, like ticks and thunks).
func _tick() -> void:
	pass


func _draw() -> void:
	if game == null or not is_instance_valid(game):
		return
	_draw_game()


func _draw_game() -> void:
	pass


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		_hover(_mouse)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			if _click(mb.position, mb.button_index == MOUSE_BUTTON_RIGHT):
				accept_event()
		elif not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_release(mb.position)


func _hover(_p: Vector2) -> void:
	pass


## A click on the table; true when it did something.
func _click(_p: Vector2, _right: bool) -> bool:
	return false


func _release(_p: Vector2) -> void:
	pass


## Seconds since the table's current view arrived.
func age() -> float:
	return game.view_age()


func mine() -> bool:
	return int(game.view.get("peer", 0)) == multiplayer.get_unique_id()


# ------------------------------------------------------------------ sounds

func sfx(sound: StringName, db: float = 0.0, pitch: float = 1.0) -> void:
	Audio.play_ui(sound, db, pitch)


## True the first time it is asked for `key` in the current view (sounds fired once).
## True once when the animation passes time `t` (not for a moment long gone, if the screen opened late).
func due(key: String, t: float) -> bool:
	var a := age()
	return a >= t and a - t < 0.35 and once(key)


func once(key: String) -> bool:
	if game.fx_done.has(key):
		return false
	game.fx_done[key] = true
	return true


# ------------------------------------------------------------------ text

static func sign_font() -> Font:
	if _sign_font == null:
		_sign_font = load("res://assets/fonts/Rye-Regular.ttf") as Font
		if _sign_font == null:
			_sign_font = ThemeDB.fallback_font
	return _sign_font


func body_font() -> Font:
	var f := get_theme_default_font()
	return f if f != null else ThemeDB.fallback_font


## Text centred on `at` (align 0), or starting at it (-1) or ending at it (1),
## vertically centred on at.y. outline > 0 draws a dark rim.
func text(at: Vector2, s: String, px: int, col: Color, align: int = 0, outline: int = 0, deco: bool = false, out_col: Color = Color(0, 0, 0, 0.85)) -> void:
	var f := sign_font() if deco else body_font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := at.x - w * 0.5 if align == 0 else (at.x if align < 0 else at.x - w)
	var base := at.y + (f.get_ascent(px) - f.get_descent(px)) * 0.5
	if outline > 0:
		draw_string_outline(f, Vector2(x, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, out_col)
	draw_string(f, Vector2(x, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func text_width(s: String, px: int, deco: bool = false) -> float:
	return (sign_font() if deco else body_font()).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


## Text bent along an arc (centre c, radius r), centred on angle `mid` (0 = straight down).
func arc_text(c: Vector2, r: float, mid: float, s: String, px: int, col: Color, deco: bool = true) -> void:
	var f := sign_font() if deco else body_font()
	var total := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var a := mid - total * 0.5 / r
	for i in s.length():
		var ch := s[i]
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var ang := a + w * 0.5 / r
		var p := c + Vector2(sin(ang), cos(ang)) * r
		draw_set_transform(p, -ang, Vector2.ONE)
		draw_string(f, Vector2(-w * 0.5, (f.get_ascent(px) - f.get_descent(px)) * 0.5), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		a += w / r
	draw_set_transform_matrix(Transform2D.IDENTITY)


# ------------------------------------------------------------------ shapes

func rrect(r: Rect2, col: Color, radius: float = 6.0, border: float = 0.0, border_col: Color = INK) -> void:
	if _rect_box == null:
		_rect_box = StyleBoxFlat.new()
		_rect_box.anti_aliasing = true
	_rect_box.bg_color = col
	_rect_box.set_corner_radius_all(int(radius))
	_rect_box.set_border_width_all(int(border))
	_rect_box.border_color = border_col
	_rect_box.draw_center = col.a > 0.0
	draw_style_box(_rect_box, r)


func ring(c: Vector2, r: float, col: Color, w: float = 2.0) -> void:
	draw_arc(c, r, 0.0, TAU, maxi(24, int(r * 0.8)), col, w, true)


func poly(points: PackedVector2Array, col: Color) -> void:
	if points.size() >= 3:
		draw_colored_polygon(points, col)


static func star_points(c: Vector2, r_out: float, r_in: float, n: int = 5, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := rot + PI * i / n - PI * 0.5
		pts.append(c + Vector2(cos(a), sin(a)) * (r_out if i % 2 == 0 else r_in))
	return pts


## The table: baize inside a padded wooden rail with a gold bead.
func felt(r: Rect2, radius: float = 18.0, felt_col: Color = FELT) -> void:
	rrect(r, WOOD_DARK, radius + 6)
	rrect(r.grow(-5), WOOD, radius + 2)
	rrect(r.grow(-12), felt_col, radius)
	draw_texture_rect(UiStyle.vignette(), r.grow(-12), false, Color(1, 1, 1, 0.55))
	rrect(r.grow(-12), Color(0, 0, 0, 0), radius, 2, GOLD.darkened(0.15))


# ------------------------------------------------------------------ cards

const CARD := Vector2(66, 94)

## A playing card centred on `c`: rank 1-13 (0 = face down), suit 0-3
## (spades, hearts, diamonds, clubs). `turn` 1 shows the face, -1 the back, and
## anything between is mid-flip (squashed); `rot` turns the card.
func card(c: Vector2, rank: int, suit: int, turn: float = 1.0, rot: float = 0.0, k: float = 1.0) -> void:
	var sz := CARD * k
	var sx := maxf(absf(turn), 0.04)
	draw_set_transform(c + Vector2(3, 4) * k, rot, Vector2(sx, 1.0))
	rrect(Rect2(-sz * 0.5, sz), Color(0, 0, 0, 0.3), 7 * k)
	_card_xf = Transform2D(rot, Vector2(sx, 1.0), 0.0, c)
	draw_set_transform_matrix(_card_xf)
	if rank <= 0 or turn < 0.0:
		_card_back(sz, k)
	else:
		_card_face(sz, rank, suit, k)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _card_back(sz: Vector2, k: float) -> void:
	var r := Rect2(-sz * 0.5, sz)
	rrect(r, CREAM, 7 * k, 1, Color(0, 0, 0, 0.4))
	var inner := r.grow(-5 * k)
	rrect(inner, Color("#7A1E18"), 4 * k)
	# Diamond lattice.
	var step := 9.0 * k
	var y := inner.position.y
	var row := 0
	while y < inner.end.y:
		var x := inner.position.x + (step * 0.5 if row % 2 == 1 else 0.0)
		while x < inner.end.x:
			var d := PackedVector2Array([Vector2(x, y - 3 * k), Vector2(x + 3 * k, y), Vector2(x, y + 3 * k), Vector2(x - 3 * k, y)])
			poly(d, Color("#A8322A"))
			x += step
		y += step * 0.5
		row += 1
	rrect(inner, Color(0, 0, 0, 0), 4 * k, int(maxf(1.0, 2 * k)), GOLD)
	rrect(Rect2(-9 * k, -9 * k, 18 * k, 18 * k), GOLD, 9 * k)
	poly(star_points(Vector2.ZERO, 7 * k, 3 * k), Color("#7A1E18"))


func _card_face(sz: Vector2, rank: int, suit: int, k: float) -> void:
	var r := Rect2(-sz * 0.5, sz)
	rrect(r, CREAM, 7 * k, 1, Color(0, 0, 0, 0.45))
	var col := RED if suit == 1 or suit == 2 else INK
	var label: String = CasinoRules.RANKS[clampi(rank, 1, 13) - 1]
	var px := int(17 * k)
	var tl := r.position + Vector2(10, 11) * k
	text(tl + Vector2(label.length() * 1.5 * k - 1 * k, 0), label, px, col, 0, 0, true)
	suit_pip(tl + Vector2(0, 15 * k), 5.5 * k, suit, col)
	# Bottom-right corner, upside down.
	var br := r.end - Vector2(10, 11) * k
	_corner_flipped(br, label, px, suit, col, k)
	if rank == 1:
		suit_pip(Vector2.ZERO, (16 if suit != 0 else 19) * k, suit, col)
	elif rank >= 11:
		_face_art(sz, rank, suit, col, k)
	else:
		for p: Vector2 in PIPS[rank]:
			var at := Vector2(p.x * sz.x * 0.21, p.y * sz.y * 0.31)
			suit_pip(at, 7.5 * k, suit, col, p.y > 0.05)


func _corner_flipped(at: Vector2, label: String, px: int, suit: int, col: Color, k: float) -> void:
	var f := sign_font()
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	# Text rotated half a turn about its own spot.
	var base := (f.get_ascent(px) - f.get_descent(px)) * 0.5
	var p := at - Vector2(label.length() * 1.5 * k - 1 * k, 0)
	var card_xf := _card_xf
	draw_set_transform_matrix(card_xf * Transform2D(PI, p))
	draw_string(f, Vector2(-w * 0.5, base), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	draw_set_transform_matrix(card_xf)
	suit_pip(at - Vector2(0, 15 * k), 5.5 * k, suit, col, true)


var _card_xf := Transform2D.IDENTITY


## Pip spots for 2-10 (x in -1..1, y in -1..1 over the card's middle).
const PIPS := {
	2: [Vector2(0, -1), Vector2(0, 1)],
	3: [Vector2(0, -1), Vector2(0, 0), Vector2(0, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
	7: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, -0.5), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
	8: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, -0.5), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 0.5), Vector2(-1, 1), Vector2(1, 1)],
	9: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, -0.333), Vector2(1, -0.333), Vector2(0, 0), Vector2(-1, 0.333), Vector2(1, 0.333), Vector2(-1, 1), Vector2(1, 1)],
	10: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, -0.667), Vector2(-1, -0.333), Vector2(1, -0.333), Vector2(-1, 0.333), Vector2(1, 0.333), Vector2(0, 0.667), Vector2(-1, 1), Vector2(1, 1)],
}


## Jack, queen, king: a framed figure (hat, crown or tiara) over the suit.
func _face_art(sz: Vector2, rank: int, suit: int, col: Color, k: float) -> void:
	var fr := Rect2(-sz.x * 0.5 + 15 * k, -sz.y * 0.5 + 9 * k, sz.x - 30 * k, sz.y - 18 * k)
	rrect(fr, Color("#F3E2B8"), 3 * k, 1, col)
	var robe: Color = [Color("#2E5FA3"), Color("#B3261E"), Color("#2E7D32")][rank - 11]
	var skin := Color("#E8B98C")
	var head := Vector2(0, -sz.y * 0.1)
	# Shoulders / robe.
	poly(PackedVector2Array([Vector2(-fr.size.x * 0.42, fr.end.y - 2 * k), Vector2(-fr.size.x * 0.28, head.y + 11 * k),
			Vector2(fr.size.x * 0.28, head.y + 11 * k), Vector2(fr.size.x * 0.42, fr.end.y - 2 * k)]), robe)
	poly(PackedVector2Array([Vector2(-4 * k, head.y + 11 * k), Vector2(4 * k, head.y + 11 * k), Vector2(0, head.y + 22 * k)]), CREAM)
	draw_circle(head, 8 * k, skin)
	draw_arc(head, 8 * k, 0, TAU, 20, Color(0, 0, 0, 0.5), 1.0, true)
	# Eyes and a moustache for the jack and king.
	draw_circle(head + Vector2(-3, -1) * k, 1.1 * k, INK)
	draw_circle(head + Vector2(3, -1) * k, 1.1 * k, INK)
	if rank != 12:
		draw_line(head + Vector2(-4, 3) * k, head + Vector2(4, 3) * k, Color("#5A3A1E"), 1.6 * k, true)
	match rank:
		11: # a cowboy hat
			rrect(Rect2(head + Vector2(-12, -9) * k, Vector2(24, 3.5) * k), Color("#6B4423"), 2 * k)
			rrect(Rect2(head + Vector2(-6, -16) * k, Vector2(12, 8) * k), Color("#6B4423"), 3 * k)
			draw_line(head + Vector2(-6, -10) * k, head + Vector2(6, -10) * k, col, 1.5 * k)
		12: # a tiara
			poly(PackedVector2Array([head + Vector2(-7, -6) * k, head + Vector2(-4, -12) * k, head + Vector2(0, -8) * k,
					head + Vector2(4, -12) * k, head + Vector2(7, -6) * k]), GOLD)
			draw_circle(head + Vector2(0, -10) * k, 1.6 * k, RED)
			# Long hair.
			draw_arc(head, 9 * k, PI * 0.15, PI * 0.85, 10, Color("#5A3A1E"), 3 * k)
		13: # a crown
			poly(PackedVector2Array([head + Vector2(-8, -6) * k, head + Vector2(-8, -15) * k, head + Vector2(-4, -10) * k,
					head + Vector2(0, -16) * k, head + Vector2(4, -10) * k, head + Vector2(8, -15) * k, head + Vector2(8, -6) * k]), GOLD)
			draw_line(head + Vector2(-6, 5) * k, head + Vector2(0, 8) * k, Color("#5A3A1E"), 2 * k)
			draw_line(head + Vector2(6, 5) * k, head + Vector2(0, 8) * k, Color("#5A3A1E"), 2 * k)
	suit_pip(Vector2(0, fr.end.y - 10 * k), 5.5 * k, suit, Color(1, 1, 1) if suit == 0 or suit == 3 else CREAM)
	suit_pip(Vector2(0, fr.end.y - 10 * k), 4.5 * k, suit, col)


## Spade, heart, diamond, club centred on c (radius r); `flip` draws it upside down.
func suit_pip(c: Vector2, r: float, suit: int, col: Color, flip: bool = false) -> void:
	var s := -1.0 if flip else 1.0
	match suit:
		0: # spade
			draw_circle(c + Vector2(-r * 0.45, r * 0.18 * s), r * 0.5, col)
			draw_circle(c + Vector2(r * 0.45, r * 0.18 * s), r * 0.5, col)
			poly(PackedVector2Array([c + Vector2(0, -r * s), c + Vector2(r * 0.93, r * 0.2 * s), c + Vector2(-r * 0.93, r * 0.2 * s)]), col)
			poly(PackedVector2Array([c + Vector2(0, r * 0.2 * s), c + Vector2(r * 0.35, r * s), c + Vector2(-r * 0.35, r * s)]), col)
		1: # heart
			draw_circle(c + Vector2(-r * 0.45, -r * 0.28 * s), r * 0.52, col)
			draw_circle(c + Vector2(r * 0.45, -r * 0.28 * s), r * 0.52, col)
			poly(PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.1 * s), c + Vector2(r * 0.95, -r * 0.1 * s), c + Vector2(0, r * s)]), col)
		2: # diamond
			poly(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.72, 0), c + Vector2(0, r), c + Vector2(-r * 0.72, 0)]), col)
		_: # club
			draw_circle(c + Vector2(0, -r * 0.45 * s), r * 0.42, col)
			draw_circle(c + Vector2(-r * 0.47, r * 0.1 * s), r * 0.42, col)
			draw_circle(c + Vector2(r * 0.47, r * 0.1 * s), r * 0.42, col)
			poly(PackedVector2Array([c + Vector2(0, -r * 0.1 * s), c + Vector2(r * 0.32, r * s), c + Vector2(-r * 0.32, r * s)]), col)


## A card dealt from `shoe` to `at`, timed by the table's deal_times[key]: it
## slides out face down and turns over as it lands (`hole` stays face down
## until the table's "flip" time). Returns false while it is still in the shoe.
func deal_card(table: CasinoTable, key: String, at: Vector2, rank: int, suit: int, shoe: Vector2, rot: float = 0.0, k: float = 1.0, hole: bool = false) -> bool:
	if not table.deal_times.has(key):
		card(at, rank, suit, 1.0 if rank > 0 else -1.0, rot, k)
		return true
	var now := Time.get_ticks_msec() / 1000.0
	var p := (now - float(table.deal_times[key])) / 0.34
	if p < 0.0:
		return false
	var e := 1.0 - pow(1.0 - clampf(p, 0.0, 1.0), 3.0)
	var pos := shoe.lerp(at, e)
	var r := lerpf(-1.1, rot, e)
	var turn := -1.0
	if rank > 0 and not hole:
		turn = -1.0 if p < 0.6 else clampf((p - 0.6) / 0.4 * 2.0 - 1.0, -1.0, 1.0)
	elif rank > 0 and hole and table.deal_times.has("flip"):
		var f := (now - float(table.deal_times["flip"])) / 0.3
		turn = clampf(f * 2.0 - 1.0, -1.0, 1.0)
	card(pos, rank, suit, turn, r, k)
	return true


## The card shoe: a wooden box with the deck showing at its mouth.
func shoe_box(at: Vector2) -> void:
	draw_set_transform(at, -0.25, Vector2.ONE)
	rrect(Rect2(-52, -34, 104, 68), WOOD_DARK, 8, 2, Color(0, 0, 0, 0.6))
	rrect(Rect2(-46, -28, 80, 56), Color("#7A1E18"), 4)
	for i in 5:
		rrect(Rect2(-40 + i * 2, -24, 66, 48), Color("#A8322A") if i % 2 == 0 else CREAM, 3)
	rrect(Rect2(28, -34, 24, 68), WOOD, 6)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	text(at + Vector2(0, 46), "SHOE", 11, Color(1, 1, 1, 0.5), 0, 0, true)


## The dealer's chip rack: rows of chip stacks seen edge-on.
func chip_rack(r: Rect2) -> void:
	rrect(r.grow(4), WOOD_DARK, 6)
	rrect(r, Color("#14100C"), 4)
	var cols := [Color("#1E1A18"), Color("#2E5FA3"), Color("#2E7D32"), Color("#B3261E"), Color("#B3261E"), Color("#2E7D32"), Color("#2E5FA3"), Color("#1E1A18")]
	var w := r.size.x / cols.size()
	for i in cols.size():
		var cr := Rect2(r.position.x + i * w + 3, r.position.y + 4, w - 6, r.size.y - 8)
		rrect(cr, cols[i], 3)
		var y := cr.position.y + 3.0
		while y < cr.end.y - 2:
			draw_line(Vector2(cr.position.x + 2, y), Vector2(cr.end.x - 2, y), Color(1, 1, 1, 0.35), 1.0)
			y += 5.0


## A hand's total on a small dark plaque.
func plaque(at: Vector2, s: String, col: Color = Color("#F2E3C2")) -> void:
	var w := text_width(s, 17, true) + 22
	rrect(Rect2(at.x - w * 0.5, at.y - 15, w, 30), Color(0.05, 0.04, 0.03, 0.85), 15, 2, GOLD_DARK)
	text(at, s, 17, col, 0, 0, true)


# ------------------------------------------------------------------ chips

static func chip_color(v: int) -> Color:
	if v >= 100:
		return Color("#1E1A18")
	if v >= 50:
		return Color("#2E5FA3")
	if v >= 20:
		return Color("#2E7D32")
	return Color("#B3261E")


## One casino chip seen from above: a coloured disc with edge spots and its value.
func chip(c: Vector2, r: float, v: int, alpha: float = 1.0, show_value: bool = true) -> void:
	var col := chip_color(v)
	col.a = alpha
	draw_circle(c + Vector2(1.5, 2.5), r, Color(0, 0, 0, 0.35 * alpha))
	draw_circle(c, r, col)
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := c + Vector2(cos(a), sin(a)) * r * 0.8
		draw_set_transform(p, a, Vector2.ONE)
		rrect(Rect2(-r * 0.12, -r * 0.2, r * 0.24, r * 0.4), Color(1, 1, 1, 0.9 * alpha), 1)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_circle(c, r * 0.6, Color(1, 1, 1, 0.92 * alpha) if v < 100 else Color(GOLD, alpha))
	draw_arc(c, r * 0.6, 0, TAU, 20, Color(col, alpha), maxf(1.0, r * 0.08), true)
	draw_arc(c, r, 0, TAU, 28, Color(0, 0, 0, 0.45 * alpha), 1.0, true)
	if show_value:
		text(c, str(v), int(maxf(9.0, r * 0.62)), Color(INK, alpha), 0, 0, true)


## A short stack of chips making up `amount` (biggest chips at the bottom).
func chip_stack(c: Vector2, r: float, amount: int, alpha: float = 1.0) -> void:
	var chips: Array[int] = []
	var left := amount
	for d: int in [100, 50, 20, 10]:
		while left >= d and chips.size() < 9:
			chips.append(d)
			left -= d
	if chips.is_empty() and amount > 0:
		chips.append(10)
	for i in chips.size():
		var p := c - Vector2(0, i * r * 0.28)
		if i < chips.size() - 1:
			# Side of a chip under the top one.
			draw_circle(p + Vector2(0, 1), r, chip_color(chips[i]).darkened(0.35))
			draw_circle(p, r, chip_color(chips[i]))
			draw_arc(p, r, 0, TAU, 24, Color(1, 1, 1, 0.5 * alpha), 1.0, true)
		else:
			chip(p, r, chips[i], alpha, false)
	if amount > 0:
		var top := c - Vector2(0, (chips.size() - 1) * r * 0.28)
		text(top, str(amount), int(maxf(10.0, r * 0.62)), INK, 0, 0, true)

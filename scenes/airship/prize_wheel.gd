class_name PrizeWheel
extends CasinoGame
## A big painted prize wheel: Spin for 5 chitin. The host picks the prize and
## every peer sees the wheel spin to it. On the screen it is the real thing:
## pegs round the rim, a leather flapper that clacks over them, and friction
## slowing it so the last few pegs crawl past.

const COST := 5
## A spin can be paid in scrap instead (worse odds on the rare wedges).
const COST_SCRAP := 25
## Label, prize. One wedge each (in CasinoRules, unit tested).
const WEDGES: Array[Array] = CasinoRules.WHEEL_WEDGES
const SPIN_TIME := 6.0

var _wheel: Node3D
var _from := 0.0
var _to := 0.0
var _t := SPIN_TIME
## The screen wheel: where it rested before this spin and where it stops.
var rest_from := 0.0
var rest_to := 0.0


func _ready() -> void:
	super._ready()
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.15, 0)), Vector3(1.4, 0.3, 0.8), Palette.WOOD_DARK)
	for sx: float in [-0.5, 0.5]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, 1.0, 0.1)), Vector3(0.1, 1.8, 0.1), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(0, 2.62, -0.12)), Vector3(0.18, 0.18, 0.05), Palette.GLOW_YELLOW, 0.0, null, 0.6)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.015)
	add_child(mi)
	_wheel = Node3D.new()
	_wheel.position = Vector3(0, 1.75, -0.05)
	add_child(_wheel)
	var wst := MeshKit.begin()
	var n := WEDGES.size()
	var colors: Array[Color] = [Color("#C9302C"), Palette.BONE, Color("#2E6FA8"), Palette.GLOW_YELLOW.darkened(0.2)]
	for i in n:
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		var c := Palette.OUTLINE if String(WEDGES[i][0]) == "BUST" else colors[i % colors.size()]
		var p1 := Vector3(sin(a0), cos(a0), 0) * 0.8
		var p2 := Vector3(sin(a1), cos(a1), 0) * 0.8
		var nrm := Vector3(0, 0, -1)
		MeshKit.tri(wst, Vector3.ZERO, p2, p1, nrm, nrm, nrm, MeshKit.vcol(c), nrm)
		MeshKit.tri(wst, Vector3.ZERO, p1, p2, -nrm, -nrm, -nrm, MeshKit.vcol(c), -nrm)
	MeshKit.add_cylinder(wst, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.03)), 0.12, 0.12, 0.08, 10, Palette.METAL)
	var wmi := MeshInstance3D.new()
	wmi.mesh = MeshKit.finish(wst)
	wmi.material_override = Materials.toon(0.01)
	_wheel.add_child(wmi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 2.6, 0.5)
	col.shape = shape
	col.position.y = 1.3
	add_child(col)


func _process(delta: float) -> void:
	if _t >= SPIN_TIME:
		return
	_t += delta
	var k := 1.0 - pow(1.0 - clampf(_t / SPIN_TIME, 0.0, 1.0), 2.0)
	_wheel.rotation.z = lerpf(_from, _to, k)
	if _t >= SPIN_TIME:
		view["spinning"] = false
		Audio.play_at(&"coin", global_position + Vector3.UP * 1.5, -2.0)
		ui_changed.emit()


func ui_anim() -> StringName:
	return &"roulette"


func ui_title() -> String:
	return "Prize Wheel"


func ui_tagline() -> String:
	return "%d chitin or %d scrap a spin. Round and round she goes..." % [COST, COST_SCRAP]


func ui_rules() -> String:
	return "%d chitin or %d scrap a spin. Scrap, chili seeds, herbs, a turret upgrade token, a turret part, or the 25-chitin jackpot. Three wedges bust. Chitin spins hit the rare wedges far more often (%d%% vs %d%%)." % [COST, COST_SCRAP,
			roundi(CasinoRules.wheel_rare_chance(&"chitin") * 100.0), roundi(CasinoRules.wheel_rare_chance(&"scrap") * 100.0)]


func ui_currency() -> StringName:
	return &"chitin"


func ui_actions() -> Array:
	return [] if _t < SPIN_TIME else [[&"spin", "Spin (%d Chitin)" % COST], [&"spin_scrap", "Spin (%d Scrap)" % COST_SCRAP]]


func make_board() -> CasinoBoard:
	return WheelBoard.new(self)


func anim_length() -> float:
	return SPIN_TIME + 0.2 if str(view.get("kind", "")) == "wheel" else 0.0


func busy_text() -> String:
	return "Round and round..."


func result_text() -> String:
	if str(view.get("kind", "")) != "wheel":
		return "Give her a spin: click the wheel or press Spin."
	return result_line()


func _act(peer_id: int, action: StringName, _choice: int, _bet: int) -> void:
	if (action != &"spin" and action != &"spin_scrap") or _t < SPIN_TIME:
		return
	var currency: StringName = &"scrap" if action == &"spin_scrap" else &"chitin"
	if not _take_in(peer_id, currency, COST_SCRAP if currency == &"scrap" else COST):
		return
	var i := CasinoRules.wheel_pick(_rng, currency)
	var prize: Dictionary = WEDGES[i][1]
	var label := String(WEDGES[i][0])
	var won_text := label.to_lower()
	if prize.has(CasinoRules.WHEEL_PART): # one random turret part for the Workshop
		var key := CraftTable.random_part(_rng)
		prize = {key: 1}
		won_text = "a %s for the Workshop" % CraftTable.part_name(key)
	# Paid when the wheel stops, so the stock chips don't give it away.
	if not prize.is_empty():
		get_tree().create_timer(SPIN_TIME, false).timeout.connect(_pay.bind(peer_id, prize))
	_broadcast({"kind": "wheel", "peer": peer_id, "wedge": i, "spinning": true, "seed": _rng.randi(),
			"result": "Bust! Better luck next spin." if label == "BUST" else "You won %s!" % won_text})


## Every peer: the screen wheel starts where it rested and turns 4-5 times to the wedge.
func _on_view_change(_before: Dictionary) -> void:
	if str(view.get("kind", "")) != "wheel":
		return
	var n := WEDGES.size()
	var w := TAU / n
	var i := int(view.get("wedge", 0))
	rest_from = fposmod(rest_to, TAU)
	# Land inside the wedge, not always dead centre (from the shared seed).
	var inside := (float(int(view.get("seed", 0)) % 1000) / 1000.0 - 0.5) * 0.7
	var target := -PI * 0.5 - (float(i) + 0.5 + inside) * w
	rest_to = rest_from + TAU * 4.0 + fposmod(target - rest_from, TAU)


## The screen wheel's angle t seconds into the spin: constant friction, so it slows evenly to a crawl.
func wheel_angle(t: float) -> float:
	var u := clampf(t / SPIN_TIME, 0.0, 1.0)
	return lerpf(rest_from, rest_to, 1.0 - (1.0 - u) * (1.0 - u))


func _on_view() -> void:
	var n := WEDGES.size()
	var i := int(view.get("wedge", 0))
	_from = fmod(_wheel.rotation.z, TAU)
	var target := (float(i) + 0.5) / n * TAU
	_to = _from + TAU * 4.0 + fposmod(target - _from, TAU)
	_t = 0.0
	Audio.play_at(&"wheel_tick", global_position + Vector3.UP * 1.5, -2.0)


# ------------------------------------------------------------------ the wheel

class WheelBoard extends CasinoBoard:
	const R := 182.0
	const COLORS := [Color("#C9302C"), Color("#F2E3C2"), Color("#2E6FA8"), Color("#E0A526")]
	var wheel: PrizeWheel

	func _init(g: CasinoGame) -> void:
		super._init(g)
		wheel = g as PrizeWheel
		custom_minimum_size = Vector2(0, 452)

	func _c() -> Vector2:
		return Vector2(R + 80, 240)

	func _spinning() -> bool:
		return str(game.view.get("kind", "")) == "wheel"

	func _angle() -> float:
		return wheel.wheel_angle(age()) if _spinning() else wheel.rest_to

	## Pegs passed under the flapper so far (fractional).
	func _pegs(a: float) -> float:
		return (a + PI * 0.5) / (TAU / PrizeWheel.WEDGES.size())

	func _tick() -> void:
		if not _spinning() or not game.ui_busy():
			return
		var passed := floori(_pegs(_angle()) - _pegs(wheel.rest_from))
		var last := int(game.fx_done.get("pegs", 0))
		if passed > last:
			game.fx_done["pegs"] = passed
			var speed := 1.0 - clampf(age() / PrizeWheel.SPIN_TIME, 0.0, 1.0)
			sfx(&"wheel_tick", -6.0 - speed * 6.0, 1.0 + speed * 0.4)
		if due("stop", PrizeWheel.SPIN_TIME):
			var won := str(PrizeWheel.WEDGES[int(game.view.get("wedge", 0))][0]) != "BUST"
			sfx(&"bell" if won else &"hit_tick", -6.0, 1.2 if won else 0.8)
			if won:
				sfx(&"coin", -6.0)

	func _draw_game() -> void:
		var r := Rect2(Vector2.ZERO, size)
		rrect(r, Color("#3A1712"), 22)
		draw_texture_rect(UiStyle.vignette(), r, false, Color(1, 1, 1, 0.6))
		# Sunburst behind the wheel.
		var c := _c()
		for k in 24:
			var a0 := TAU * k / 24.0 + Time.get_ticks_msec() / 9000.0
			var a1 := a0 + TAU / 48.0
			poly(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 600, c + Vector2(cos(a1), sin(a1)) * 600]), Color(1, 0.8, 0.4, 0.05))
		var a := _angle()
		var done := _spinning() and not game.ui_busy()
		var landed := int(game.view.get("wedge", -1)) if done else -1
		# Rim with bulbs.
		draw_circle(c + Vector2(5, 7), R + 26, Color(0, 0, 0, 0.4))
		draw_circle(c, R + 26, Color("#5A3418"))
		draw_circle(c, R + 20, Color("#C9A04A"))
		draw_circle(c, R + 12, Color("#5A3418"))
		var chase := int(Time.get_ticks_msec() / (70 if done and landed >= 0 else 160))
		for k in 32:
			var ba := TAU * k / 32.0
			var on := (k + chase) % 4 == 0 if not done else chase % 2 == k % 2
			draw_circle(c + Vector2(cos(ba), sin(ba)) * (R + 19), 4.0, Color("#FFF1B0") if on else Color("#8A6A30"))
		# Wedges.
		var n := PrizeWheel.WEDGES.size()
		var w := TAU / n
		for i in n:
			var label := str(PrizeWheel.WEDGES[i][0])
			var col: Color = Color("#1E1A18") if label == "BUST" else COLORS[i % COLORS.size()]
			if i == landed and int(Time.get_ticks_msec() / 150.0) % 2 == 0:
				col = col.lightened(0.35)
			var pts := PackedVector2Array([c])
			for k in 9:
				var wa := a + (i + k / 8.0) * w
				pts.append(c + Vector2(cos(wa), sin(wa)) * R)
			poly(pts, col)
			var mid := a + (i + 0.5) * w
			var dark := label == "BUST" or col.get_luminance() < 0.45
			_wedge_label(c, mid, label, CREAM if dark else INK)
		# Spokes and pegs at every wedge edge.
		for i in n:
			var ea := a + i * w
			draw_line(c, c + Vector2(cos(ea), sin(ea)) * R, Color("#C9A04A"), 2.0, true)
			var pp := c + Vector2(cos(ea), sin(ea)) * (R - 6)
			draw_circle(pp + Vector2(1, 2), 5.5, Color(0, 0, 0, 0.4))
			draw_circle(pp, 5.5, Color("#D9DDE1"))
			draw_circle(pp + Vector2(-1.5, -1.5), 2.0, Color(1, 1, 1))
		# The hub.
		draw_circle(c, 46, Color("#C9A04A"))
		draw_circle(c, 40, Color("#7A1E18"))
		poly(star_points(c, 30, 13, 5, a), Color("#E9C46A"))
		draw_circle(c, 8, Color("#5A3418"))
		_flapper(c, a)
		_prize_card(Rect2(c.x + R + 60, 18, size.x - c.x - R - 78, 416))

	func _wedge_label(c: Vector2, ang: float, label: String, col: Color) -> void:
		var words := label.split(" ")
		var lines: Array[String] = []
		if words.size() >= 3:
			lines = [words[0], " ".join(words.slice(1))]
		else:
			lines = [label]
		draw_set_transform(c + Vector2(cos(ang), sin(ang)) * R * 0.62, ang + (PI if cos(ang) < 0.0 else 0.0), Vector2.ONE)
		var f := sign_font()
		for li in lines.size():
			var s := lines[li]
			var px := 15 if s.length() <= 9 else 12
			var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var y := (li - (lines.size() - 1) * 0.5) * 16.0 + 5.0
			draw_string(f, Vector2(-tw * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	## The leather flapper at the top: pushed aside by each peg, then snapping back.
	func _flapper(c: Vector2, a: float) -> void:
		var pivot := c + Vector2(0, -R - 28)
		var p := _pegs(a)
		var frac := fposmod(p, 1.0)
		var speed := 1.0 - clampf(age() / PrizeWheel.SPIN_TIME, 0.0, 1.0) if _spinning() and game.ui_busy() else 0.0
		var bend := 0.0
		if frac > 0.82:
			bend = -(frac - 0.82) / 0.18 * 0.42 # a peg pushes it aside
		elif frac < 0.4 and (speed > 0.0 or p > 0.5):
			var s := frac / 0.4
			bend = -0.42 * exp(-6.0 * s) * cos(s * 11.0) * (1.0 if speed > 0.0 else 0.0)
		var tip := pivot + Vector2(0, 46).rotated(bend)
		rrect(Rect2(pivot.x - 26, pivot.y - 16, 52, 22), Color("#5A3418"), 6, 2, Color("#C9A04A"))
		var dir := (tip - pivot).normalized()
		var side := Vector2(-dir.y, dir.x)
		poly(PackedVector2Array([pivot + side * 11, pivot - side * 11, tip - side * 3, tip + dir * 10, tip + side * 3]), Color("#7A1E18"))
		draw_polyline(PackedVector2Array([pivot + side * 11, tip + side * 3, tip + dir * 10, tip - side * 3, pivot - side * 11]), Color("#3A0806"), 2.0, true)
		draw_circle(pivot, 7, Color("#C9A04A"))

	func _prize_card(r: Rect2) -> void:
		rrect(r, CREAM, 8, 3, WOOD)
		text(Vector2(r.get_center().x, r.position.y + 26), "PRIZES", 24, Color("#7A1E18"), 0, 0, true)
		text(Vector2(r.get_center().x, r.position.y + 50), "%d Chitin or %d Scrap a Spin" % [PrizeWheel.COST, PrizeWheel.COST_SCRAP], 14, INK, 0)
		draw_line(Vector2(r.position.x + 14, r.position.y + 64), Vector2(r.end.x - 14, r.position.y + 64), WOOD, 2.0)
		var seen := {}
		var y := r.position.y + 86
		for i in PrizeWheel.WEDGES.size():
			var label := str(PrizeWheel.WEDGES[i][0])
			if seen.has(label):
				seen[label] = int(seen[label]) + 1
				continue
			seen[label] = 1
		for i in PrizeWheel.WEDGES.size():
			var label := str(PrizeWheel.WEDGES[i][0])
			if not seen.has(label):
				continue
			var count := int(seen[label])
			seen.erase(label)
			var col: Color = Color("#1E1A18") if label == "BUST" else COLORS[i % COLORS.size()]
			rrect(Rect2(r.position.x + 16, y - 9, 18, 18), col, 4, 1, INK)
			var lit := _spinning() and not game.ui_busy() and str(PrizeWheel.WEDGES[int(game.view.get("wedge", 0))][0]) == label
			text(Vector2(r.position.x + 44, y), label.capitalize() if label != "BUST" else "Bust", 15, Color("#7A1E18") if lit else INK, -1, 0, lit)
			if count > 1:
				text(Vector2(r.end.x - 14, y), "x%d" % count, 13, Color("#6B5034"), 1)
			elif CasinoRules.wheel_is_rare(i):
				text(Vector2(r.end.x - 14, y), "Rare", 13, Color("#B8862B"), 1, 0, true)
			y += 34
		# Paying in chitin tips the wheel toward the rare wedges.
		text(Vector2(r.get_center().x, r.end.y - 18), "Rare: %d%% on Chitin, %d%% on Scrap" % [
				roundi(CasinoRules.wheel_rare_chance(&"chitin") * 100.0), roundi(CasinoRules.wheel_rare_chance(&"scrap") * 100.0)], 12, Color("#6B5034"), 0)

	func _click(p: Vector2, right: bool) -> bool:
		if right or game.ui_busy() or p.distance_to(_c()) > R + 20 or Brand.local_banned():
			return false
		sfx(&"wheel_tick", -4.0)
		game.ui_press(&"spin")
		return true

	func _hover(p: Vector2) -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if p.distance_to(_c()) < R + 20 and not game.ui_busy() else Control.CURSOR_ARROW


## Host: take a spin's price in chitin or scrap (the shared pot), like _take.
func _take_in(peer_id: int, currency: StringName, amount: int) -> bool:
	if Brand.is_banned(peer_id): # Brand: caught cheats are barred for a wave
		Economy.notify(peer_id, "The pit boss won't take your bets until wave %d." % Brand.ban_wave(peer_id))
		return false
	if Economy.spend(_cliff(peer_id), {currency: amount}):
		return true
	Economy.notify(peer_id, "You need %d %s for a spin." % [amount, String(currency)])
	return false

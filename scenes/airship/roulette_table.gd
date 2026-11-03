class_name RouletteTable
extends CasinoTable
## Single-zero roulette. Click the layout to lay chips (any number 35:1, dozens
## and columns 2:1, red/black, odd/even and halves 1:1; straight up on 7 also
## wins a turret upgrade token), then Spin. The wheel spins, the ball runs the
## track, drops and rattles into a pocket; every peer sees the same spin, and
## the little wheel on the deck table turns with it.

const SPIN_TIME := 5.6
## When the ball has come to rest (seconds into the spin).
const SETTLE := 4.8
const HISTORY := 12
## The old one-choice bets (CasinoRules.ROULETTE_BETS) as layout spots.
const OLD_SPOTS := ["red", "black", "odd", "even", "low", "high", "dozen1", "n7"]

var _wheel: MeshInstance3D
var _t := SPIN_TIME
var _history: Array = [] # host
## This peer's chips on the layout before the spin: {spot: amount}.
var pending: Dictionary = {}
## The wheel's angle when the current spin began (every peer works it out the same way).
var wheel_from := 0.0
var ball_from := 0.0


func ui_anim() -> StringName:
	return &"roulette"


func ui_title() -> String:
	return "Roulette"


func ui_tagline() -> String:
	return "Lay your chips on the layout and spin. Straight up on 7 adds a turret upgrade token."


func ui_rules() -> String:
	return "Single zero. Colours, odd/even and halves pay 1:1, dozens and columns 2:1, a single number 35:1. Lucky 7 straight up also pays a turret upgrade token."


func _ready() -> void:
	super._ready()
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(), 0.38, 0.38, 0.06, 37, Palette.WOOD_DARK)
	for i in 37:
		var a := TAU * i / 37.0
		var n: int = CasinoRules.WHEEL_ORDER[i]
		var c := Color("#2E7D32") if n == 0 else (Color("#C9302C") if CasinoRules.RED_NUMBERS.has(n) else Palette.OUTLINE)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -a), Vector3(sin(a), 0.035, cos(a)) * 0.3), Vector3(0.05, 0.01, 0.12), c)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.06, 0)), 0.08, 0.05, 0.08, 8, Palette.GLOW_YELLOW.darkened(0.2))
	_wheel = MeshInstance3D.new()
	_wheel.mesh = MeshKit.finish(st)
	_wheel.material_override = Materials.toon(0.01)
	_wheel.position = Vector3(-0.45, 1.02, 0)
	add_child(_wheel)


func _process(delta: float) -> void:
	if _t >= SPIN_TIME:
		return
	_t += delta
	_wheel.rotation.y += delta * lerpf(14.0, 0.5, clampf(_t / SPIN_TIME, 0.0, 1.0))
	if _t >= SPIN_TIME:
		view["spinning"] = false
		Audio.play_at(&"coin", global_position + Vector3.UP, -4.0)
		ui_changed.emit()


func ui_bets() -> Array:
	return BETS


func board_picks() -> bool:
	return true


func ui_actions() -> Array:
	if _t < SPIN_TIME:
		return []
	return [[&"clear", "Clear Bets"], [&"spin", "Spin"]]


func ui_cheat() -> Array:
	return ["Load the Ball", "roulette"]


func make_board() -> CasinoBoard:
	return RouletteBoard.new(self)


func anim_length() -> float:
	return SETTLE + 0.6 if str(view.get("kind", "")) == "wheel" else 0.0


func busy_text() -> String:
	return "No more bets!"


func result_text() -> String:
	if str(view.get("kind", "")) != "wheel":
		return "Place your chips: click to lay one, right-click to take it back."
	return result_line()


func pending_total() -> int:
	var t := 0
	for k: Variant in pending.keys():
		t += int(pending[k])
	return t


## Lays one chip of the picked stake on a spot (or takes one back).
func lay(spot: String, take: bool) -> void:
	if take:
		if pending.has(spot):
			pending[spot] = int(pending[spot]) - stake()
			if int(pending[spot]) <= 0:
				pending.erase(spot)
			Audio.play_ui(&"dice", -10.0, 1.5)
	elif pending_total() + stake() <= CasinoRules.ROULETTE_MAX_TOTAL:
		pending[spot] = int(pending.get(spot, 0)) + stake()
		Audio.play_ui(&"dice", -8.0, 1.8)
	else:
		Audio.play_ui(&"hit_tick", -6.0)
	ui_changed.emit()


func ui_press(id: StringName) -> void:
	if id == &"clear":
		pending.clear()
		ui_changed.emit()
		return
	if pending.is_empty():
		pending = {"red": stake()} # a bare Spin: a chip on red, like the old table
	ui_act_data(id, pending)


## Debug (--casinobets=red:20,n17:10): lays chips before the screenshot.
func debug_bets(spots: PackedStringArray) -> void:
	for s in spots:
		var p := s.split(":")
		pending[p[0]] = int(p[1]) if p.size() > 1 else 10


## The old single-bet call (debug runs): one chip on the matching spot.
func _act(peer_id: int, action: StringName, choice: int, bet: int) -> void:
	_act_data(peer_id, action, {OLD_SPOTS[clampi(choice, 0, OLD_SPOTS.size() - 1)]: _valid_bet(bet)})


func _act_data(peer_id: int, action: StringName, data: Dictionary) -> void:
	if (action != &"spin" and action != &"cheat") or _t < SPIN_TIME:
		return
	var bets := CasinoRules.roulette_clean(data)
	var total := 0
	for k: Variant in bets.keys():
		total += int(bets[k])
	if total <= 0:
		return
	if action == &"cheat" and _cheat(peer_id, "roulette", total) <= 0: # Brand: Snake Eyes loaded ball
		return
	if not _take(peer_id, total):
		return
	var n := _rng.randi_range(0, 36)
	if action == &"cheat" and CasinoRules.roulette_settle(bets, n) <= 0:
		n = _rng.randi_range(0, 36) # the loaded ball gets a second bounce
	var won := CasinoRules.roulette_settle(bets, n)
	var prize: Dictionary = {&"scrap": won} if won > 0 else {}
	if n == 7 and bets.has("n7"):
		prize[&"upgrade_token"] = 1
	var bonus := ""
	if won > 0:
		var key := CasinoRules.part_bonus(_rng)
		if key != &"":
			prize[key] = int(prize.get(key, 0)) + 1
			bonus = " The house throws in a %s for the Workshop!" % CraftTable.part_name(key)
	_pay_later(peer_id, prize, SETTLE + 0.3)
	_history.push_front(n)
	_history.resize(mini(_history.size(), HISTORY))
	var colour := CasinoRules.roulette_colour(n)
	var line := "%d %s." % [n, colour.capitalize()]
	if won > total:
		line += " You win %s!" % CasinoRules.prize_text(prize) + bonus
	elif won > 0:
		line += " %d scrap back on %d staked." % [won, total] + bonus
	else:
		line += " The house sweeps the table."
	_broadcast({"kind": "wheel", "peer": peer_id, "number": n, "colour": colour, "bets": bets, "win": won, "staked": total,
			"history": _history.duplicate(), "seed": _rng.randi(), "spinning": true, "result": line})


## Every peer: the wheel picks up where it was; the ball is launched opposite.
func _on_view_change(before: Dictionary) -> void:
	if str(view.get("kind", "")) != "wheel":
		return
	var now := Time.get_ticks_msec() / 1000.0
	var old_age := now - _prev_view_at
	wheel_from = wheel_angle(old_age, wheel_from) if not before.is_empty() else 0.0
	ball_from = float(int(view.get("seed", 0)) % 628) / 100.0
	_prev_view_at = now


var _prev_view_at := -1000.0


func _on_view() -> void:
	_t = 0.0
	Audio.play_at(&"roulette_spin", global_position + Vector3.UP, -4.0)


## The wheel's angle t seconds into a spin that began at `from` (slows over 14 s).
static func wheel_angle(t: float, from: float) -> float:
	var tw := 14.0
	var w0 := 2.0
	var tt := minf(maxf(t, 0.0), tw)
	return from + w0 * (tt - tt * tt / (2.0 * tw))


## The pocket angle (from the wheel's zero) of number n.
static func pocket_angle(n: int) -> float:
	return TAU * CasinoRules.WHEEL_ORDER.find(n) / 37.0


## The ball: [angle on screen, distance from the centre as a share of the
## track radius], t seconds into the spin. It runs against the wheel, slows,
## drops off the track, rattles over the pockets and settles in n's.
func ball_at(t: float, n: int) -> Vector2:
	var land := wheel_angle(SETTLE, wheel_from) + pocket_angle(n)
	if t >= SETTLE:
		return Vector2(wheel_angle(t, wheel_from) + pocket_angle(n), 0.0)
	var om := 11.0
	var tb := 5.2
	var base := -om * (t - t * t / (2.0 * tb))
	var base_end := -om * (SETTLE - SETTLE * SETTLE / (2.0 * tb))
	var corr := wrapf(land - (ball_from + base_end), -PI, PI)
	var k := t / SETTLE
	var ang := ball_from + base + corr * k * k * (3.0 - 2.0 * k)
	# Radius: 1 = the ball track, 0 = resting in the pocket.
	var drop := 2.6
	var r := 1.0
	if t > drop:
		var u := (t - drop) / (SETTLE - drop)
		r = (1.0 - u) * (1.0 - u) + absf(sin((t - drop) * 9.0)) * 0.35 * exp(-2.5 * (t - drop)) * (1.0 - u)
	return Vector2(ang, clampf(r, 0.0, 1.0))


# ------------------------------------------------------------------ the wheel and layout

class RouletteBoard extends CasinoBoard:
	const R := 196.0
	var table: RouletteTable
	var _hover_spot := ""

	func _init(g: CasinoGame) -> void:
		super._init(g)
		table = g as RouletteTable
		custom_minimum_size = Vector2(0, 452)

	func _spinning() -> bool:
		return str(game.view.get("kind", "")) == "wheel"

	func _tick() -> void:
		if not _spinning():
			return
		if due("launch", 0.0):
			sfx(&"roulette_spin", -6.0)
		# The ball clatters as it bounces over the frets.
		for k in 9:
			if due("b%d" % k, 2.6 + (k + 0.5) * PI / 9.0):
				sfx(&"wheel_tick", -8.0 - k, 1.9 - k * 0.05)
		if due("drop", RouletteTable.SETTLE):
			sfx(&"dice", -6.0, 1.4)
		if due("pay", RouletteTable.SETTLE + 0.5) and int(game.view.get("win", 0)) > 0:
			sfx(&"coin", -4.0, 1.1)

	func _wheel_c() -> Vector2:
		return Vector2(R + 22, size.y * 0.5)

	func _draw_game() -> void:
		felt(Rect2(Vector2.ZERO, size), 26)
		var t := age() if _spinning() else 99.0
		var n := int(game.view.get("number", 0))
		var ang := RouletteTable.wheel_angle(t, table.wheel_from) if _spinning() else table.wheel_from + RouletteTable.wheel_angle(99.0, 0.0)
		_wheel(_wheel_c(), ang)
		if _spinning():
			var b := table.ball_at(t, n)
			var rad := lerpf(R * 0.6, R * 0.8, b.y)
			var bp := _wheel_c() + Vector2(cos(b.x), sin(b.x)) * rad
			draw_circle(bp + Vector2(2, 3), 7, Color(0, 0, 0, 0.35))
			draw_circle(bp, 7, Color("#F4F1EA"))
			draw_circle(bp + Vector2(-2, -2), 2.5, Color(1, 1, 1))
		_history()
		_layout()

	func _wheel(c: Vector2, w: float) -> void:
		# Bowl and ball track.
		draw_circle(c + Vector2(4, 6), R + 6, Color(0, 0, 0, 0.35))
		draw_circle(c, R + 6, WOOD_DARK)
		draw_circle(c, R, Color("#8A5A32"))
		draw_circle(c, R * 0.86, Color("#B07A45"))
		draw_arc(c, R * 0.86, 0, TAU, 64, Color(0, 0, 0, 0.35), 2.0, true)
		draw_circle(c, R * 0.78, Color("#4A2C16"))
		# Deflectors on the track.
		for k in 8:
			var a := TAU * k / 8.0 + 0.2
			var p := c + Vector2(cos(a), sin(a)) * R * 0.72
			draw_set_transform(p, a, Vector2.ONE)
			poly(PackedVector2Array([Vector2(-6, 0), Vector2(0, -3.5), Vector2(6, 0), Vector2(0, 3.5)]), Color("#D9DDE1"))
			draw_set_transform_matrix(Transform2D.IDENTITY)
		# Pockets, turning with the wheel.
		var r_out := R * 0.68
		var r_in := R * 0.5
		var step := TAU / 37.0
		var dark_won := not game.ui_busy() and _spinning()
		for i in 37:
			var num: int = CasinoRules.WHEEL_ORDER[i]
			var a0 := w + (i - 0.5) * step
			var a1 := w + (i + 0.5) * step
			var col := Color("#1F7A36") if num == 0 else (Color("#B3261E") if CasinoRules.RED_NUMBERS.has(num) else Color("#1E1A18"))
			if dark_won and num == int(game.view.get("number", -1)):
				col = col.lightened(0.25 + 0.15 * sin(Time.get_ticks_msec() / 120.0))
			var pts := PackedVector2Array()
			for k in 4:
				var a := lerpf(a0, a1, k / 3.0)
				pts.append(c + Vector2(cos(a), sin(a)) * r_out)
			for k in range(3, -1, -1):
				var a := lerpf(a0, a1, k / 3.0)
				pts.append(c + Vector2(cos(a), sin(a)) * r_in)
			poly(pts, col)
			draw_line(c + Vector2(cos(a0), sin(a0)) * r_in, c + Vector2(cos(a0), sin(a0)) * r_out, GOLD, 1.5, true)
			var am := w + i * step
			var tp := c + Vector2(cos(am), sin(am)) * (r_out - 11)
			draw_set_transform(tp, am + PI * 0.5, Vector2.ONE)
			var f := sign_font()
			var s := str(num)
			var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(f, Vector2(-tw * 0.5, 4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CREAM)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_arc(c, r_out, 0, TAU, 74, GOLD, 2.0, true)
		draw_arc(c, r_in, 0, TAU, 74, GOLD, 2.0, true)
		# The cone and the turret.
		draw_circle(c, r_in - 1, Color("#7A4A26"))
		draw_circle(c, r_in * 0.72, Color("#8E5A30"))
		for k in 4:
			var a := w + k * PI * 0.5
			draw_line(c, c + Vector2(cos(a), sin(a)) * r_in * 0.62, Color("#D9B25A"), 6.0, true)
			draw_circle(c + Vector2(cos(a), sin(a)) * r_in * 0.62, 6, Color("#E9C46A"))
		draw_circle(c, 16, Color("#C9A04A"))
		draw_circle(c, 9, Color("#F2D27A"))

	func _history() -> void:
		var hist: Array = game.view.get("history", [])
		var x0 := _wheel_c().x + R + 34
		var r := Rect2(x0, 14, size.x - x0 - 18, 44)
		rrect(r, Color("#14100C"), 8, 2, GOLD_DARK)
		text(Vector2(r.position.x + 12, r.get_center().y), "LAST", 12, GOLD, -1, 0, true)
		var shown := hist if not game.ui_busy() else hist.slice(1)
		var x := r.position.x + 72
		for i in mini(shown.size(), 12):
			var num := int(shown[i])
			var col := Color("#1F7A36") if num == 0 else (Color("#C9302C") if CasinoRules.RED_NUMBERS.has(num) else Color("#3A3330"))
			var rad := 15.0 if i == 0 else 12.0
			draw_circle(Vector2(x, r.get_center().y), rad, col)
			draw_arc(Vector2(x, r.get_center().y), rad, 0, TAU, 20, GOLD if i == 0 else Color(1, 1, 1, 0.3), 1.5, true)
			text(Vector2(x, r.get_center().y), str(num), 13 if i == 0 else 11, CREAM, 0, 0, true)
			x += rad + 16.0
			if x > r.end.x - 12:
				break

	# ---- the layout

	func _grid() -> Dictionary:
		var x0 := _wheel_c().x + R + 34
		var zero_w := 40.0
		var col_w := 46.0
		var cw := (size.x - 18 - x0 - zero_w - col_w) / 12.0
		return {"x0": x0, "y0": 74.0, "zw": zero_w, "cw": cw, "ch": 56.0, "colw": col_w, "rh": 44.0}

	func spot_rect(spot: String) -> Rect2:
		var g := _grid()
		var x0: float = g["x0"]
		var y0: float = g["y0"]
		var cw: float = g["cw"]
		var ch: float = g["ch"]
		var nx: float = x0 + float(g["zw"])
		if spot == "n0":
			return Rect2(x0, y0, g["zw"], ch * 3)
		if spot.begins_with("n"):
			var n := spot.substr(1).to_int()
			var col := floori((n - 1) / 3.0)
			var row := 2 - (n - 1) % 3
			return Rect2(nx + col * cw, y0 + row * ch, cw, ch)
		if spot.begins_with("col"):
			var k := spot.substr(3).to_int()
			return Rect2(nx + 12 * cw, y0 + (3 - k) * ch, g["colw"], ch)
		if spot.begins_with("dozen"):
			var k := spot.substr(5).to_int() - 1
			return Rect2(nx + k * 4 * cw, y0 + 3 * ch, cw * 4, g["rh"])
		var order := ["low", "even", "red", "black", "odd", "high"]
		var i := order.find(spot)
		return Rect2(nx + i * 2 * cw, y0 + 3 * ch + float(g["rh"]), cw * 2, g["rh"])

	static func all_spots() -> Array[String]:
		var out: Array[String] = []
		for n in 37:
			out.append("n%d" % n)
		out.append_array(["col1", "col2", "col3", "dozen1", "dozen2", "dozen3", "low", "even", "red", "black", "odd", "high"])
		return out

	func _layout() -> void:
		var spinning := _spinning()
		var settled := spinning and not game.ui_busy()
		var n := int(game.view.get("number", -1))
		var showing: Dictionary = game.view.get("bets", {}) if spinning and (game.ui_busy() or table.pending.is_empty() or not mine()) else table.pending
		if settled and mine() and age() < 3.5:
			showing = game.view.get("bets", {})
		for spot in all_spots():
			var r := spot_rect(spot)
			var bg := Color(0, 0, 0, 0)
			if spot.begins_with("n"):
				var num := spot.substr(1).to_int()
				bg = Color("#1F7A36") if num == 0 else (Color("#B3261E") if CasinoRules.RED_NUMBERS.has(num) else Color("#1E1A18"))
			var win := settled and n >= 0 and CasinoRules.roulette_spot_wins(spot, n)
			if win:
				bg = bg.lightened(0.15) if bg.a > 0 else Color(1, 0.85, 0.3, 0.25)
			if spot == _hover_spot and not game.ui_busy():
				bg = bg.lightened(0.2) if bg.a > 0 else Color(1, 1, 1, 0.12)
			if bg.a > 0:
				draw_rect(r.grow(-3), bg)
			draw_rect(r, Color(1, 1, 1, 0.85), false, 1.5)
			_spot_label(spot, r)
		for spot: Variant in showing.keys():
			var r := spot_rect(str(spot))
			var lost := settled and n >= 0 and not CasinoRules.roulette_spot_wins(str(spot), n)
			var a := clampf(1.0 - (age() - RouletteTable.SETTLE - 0.8) / 0.8, 0.0, 1.0) if lost else 1.0
			if a > 0.0:
				chip(r.get_center() + Vector2(0, 2), 16.0, int(showing[spot]), a)
		# The dolly on the winning number.
		if settled and n >= 0:
			var r := spot_rect("n%d" % n)
			var dp := Vector2(r.get_center().x, r.position.y + 10)
			draw_circle(dp + Vector2(1, 2), 9, Color(0, 0, 0, 0.4))
			draw_circle(dp, 9, Color("#E9EEF2"))
			draw_circle(dp, 5, GOLD)
		# Under the layout: what is down and the table limit.
		var g := _grid()
		var y := float(g["y0"]) + float(g["ch"]) * 3 + float(g["rh"]) * 2 + 26
		var x0: float = g["x0"]
		var total := 0
		for k: Variant in showing.keys():
			total += int(showing[k])
		text(Vector2(x0, y), "On the Table: %d Scrap" % total, 17, CREAM, -1, 3, true)
		text(Vector2(size.x - 20, y), "Table Limit %d" % CasinoRules.ROULETTE_MAX_TOTAL, 13, Color(1, 1, 1, 0.6), 1)
		text(Vector2(x0, y + 28), "Straight Up 35 to 1   Columns & Dozens 2 to 1   Even Money 1 to 1", 12, Color(1, 1, 1, 0.6), -1)
		if spinning and settled and int(game.view.get("win", 0)) > 0:
			text(Vector2(size.x - 20, y + 28), "Paid %d" % int(game.view.get("win", 0)), 18, GOLD, 1, 4, true)

	func _spot_label(spot: String, r: Rect2) -> void:
		var c := r.get_center()
		if spot.begins_with("n"):
			var num := spot.substr(1)
			if spot == "n0":
				text(c, "0", 20, CREAM, 0, 0, true)
				return
			text(c, num, 18, CREAM, 0, 0, true)
			return
		match spot:
			"red":
				poly(PackedVector2Array([c + Vector2(0, -13), c + Vector2(22, 0), c + Vector2(0, 13), c + Vector2(-22, 0)]), Color("#B3261E"))
			"black":
				poly(PackedVector2Array([c + Vector2(0, -13), c + Vector2(22, 0), c + Vector2(0, 13), c + Vector2(-22, 0)]), Color("#1E1A18"))
			"low":
				text(c, "1 to 18", 14, CREAM, 0, 0, true)
			"high":
				text(c, "19 to 36", 14, CREAM, 0, 0, true)
			"even":
				text(c, "EVEN", 14, CREAM, 0, 0, true)
			"odd":
				text(c, "ODD", 14, CREAM, 0, 0, true)
			"dozen1":
				text(c, "1st 12", 15, CREAM, 0, 0, true)
			"dozen2":
				text(c, "2nd 12", 15, CREAM, 0, 0, true)
			"dozen3":
				text(c, "3rd 12", 15, CREAM, 0, 0, true)
			_:
				draw_set_transform(c, -PI * 0.5, Vector2.ONE)
				text(Vector2.ZERO, "2 to 1", 12, CREAM, 0, 0, true)
				draw_set_transform_matrix(Transform2D.IDENTITY)

	func _spot_at(p: Vector2) -> String:
		for spot in all_spots():
			if spot_rect(spot).has_point(p):
				return spot
		return ""

	func _hover(p: Vector2) -> void:
		_hover_spot = _spot_at(p)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover_spot != "" else Control.CURSOR_ARROW

	func _click(p: Vector2, right: bool) -> bool:
		if game.ui_busy() or Brand.local_banned():
			return false
		var spot := _spot_at(p)
		if spot == "":
			return false
		table.lay(spot, right)
		return true

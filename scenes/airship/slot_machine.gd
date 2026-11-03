class_name SlotMachine
extends CasinoGame
## A one-armed bandit on the casino deck. Pick a stake and pull the lever. The
## host rolls three reels; three of a kind pays (chilis add seeds, stars add a
## turret upgrade token), a pair returns the stake. Pays back about 82% of stakes
## in scrap. The screen is the cabinet's face: three reels that spin and thunk
## to a stop one by one, a lever to drag, the payline, a coin tray and paytable.

const BETS: Array = [10, 25, 50]
## Reel symbols and prizes live in CasinoRules (unit tested).
const SYMBOLS: Array[Array] = CasinoRules.SLOT_SYMBOLS
## The printed reel strips (20 stops each, weighted like the roll: 6 bugs, 5 cacti,
## 4 chilis, 3 horseshoes, 2 stars). Only the look: the host's roll decides the stop.
const STRIPS: Array = [
	[0, 1, 2, 0, 3, 1, 0, 4, 2, 1, 0, 3, 2, 0, 1, 4, 0, 2, 1, 3],
	[1, 0, 2, 3, 0, 1, 4, 0, 2, 1, 3, 0, 2, 1, 0, 4, 2, 0, 1, 3],
	[2, 0, 1, 4, 0, 3, 1, 0, 2, 1, 0, 3, 4, 0, 2, 1, 0, 3, 2, 1],
]
## When each reel stops (seconds after the pull); the last one hangs on when the first two match.
const STOPS: Array[float] = [1.0, 1.45, 1.9]
const TEASE := 0.8
const COUNT_TIME := 1.3

var _arm: MeshInstance3D
var _arm_t := 9.0
## Where each reel rests (strip index at the payline) and this spin's travel.
var stops: Array[int] = [3, 8, 14]
var spin_from: Array[float] = [3.0, 8.0, 14.0]
var spin_dist: Array[float] = [0.0, 0.0, 0.0]


func _ready() -> void:
	super._ready()
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.75, 0)), Vector3(0.9, 1.5, 0.7), Color("#7A2E22"))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.6, 0)), Vector3(0.95, 0.25, 0.75), Palette.GLOW_YELLOW.darkened(0.3))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.05, -0.36)), Vector3(0.7, 0.35, 0.03), Palette.BONE)
	for k in 3:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.22 + k * 0.22, 1.05, -0.38)), Vector3(0.16, 0.26, 0.02), [Color("#B3261E"), Palette.CACTUS, Palette.GLOW_YELLOW][k])
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.5, -0.36)), Vector3(0.5, 0.12, 0.05), Palette.METAL)
	for k in 5:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(-0.36 + k * 0.18, 1.78, -0.3)), Vector3.ONE * 0.05, 3, 6, Palette.GLOW_YELLOW, 0.0, null, 0.9)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.015)
	add_child(mi)
	var arm_st := MeshKit.begin()
	MeshKit.add_cylinder(arm_st, Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.03, 0.03, 0.6, 6, Palette.METAL)
	MeshKit.add_ellipsoid(arm_st, Transform3D(Basis(), Vector3(0, 0.62, 0)), Vector3.ONE * 0.08, 4, 8, Color("#C9302C"))
	_arm = MeshInstance3D.new()
	_arm.mesh = MeshKit.finish(arm_st)
	_arm.material_override = Materials.toon(0.01)
	_arm.position = Vector3(0.5, 1.0, 0)
	add_child(_arm)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.8, 0.7)
	col.shape = shape
	col.position.y = 0.9
	add_child(col)


## The in-world arm: yanked down fast, then springs back up with a wobble.
func _process(delta: float) -> void:
	_arm_t += delta
	_arm.rotation.x = -lever_pull(_arm_t) * 1.5


## How far the lever is down (0..1) `t` seconds after a pull.
static func lever_pull(t: float) -> float:
	if t < 0.0 or t > 1.2:
		return 0.0
	if t < 0.16:
		return t / 0.16
	var u := (t - 0.16) / 1.0
	return maxf(0.0, (1.0 - u) * (1.0 - u) * cos(u * 9.0))


func ui_anim() -> StringName:
	return &"slots"


func ui_title() -> String:
	return "Slot Machine"


func ui_tagline() -> String:
	return "Pull the lever and line up three of a kind on the payline."


func ui_rules() -> String:
	return "Three of a kind: cactus x10, chili x15 + 3 chili seeds, horseshoe x25, star x60 + a turret upgrade token. A pair returns your stake (horseshoes or stars pay double); bugs pay nothing."


func ui_bets() -> Array:
	return BETS


func ui_actions() -> Array:
	return [[&"pull", "Pull the Lever"]]


func ui_cheat() -> Array:
	return ["Pull and Nudge a Reel", "slots"]


func busy_text() -> String:
	return "The reels are spinning..."


func make_board() -> CasinoBoard:
	return SlotBoard.new(self)


func anim_length() -> float:
	if str(view.get("kind", "")) != "reels" or not view.has("idx"):
		return 0.0
	return last_stop() + 0.3 + (COUNT_TIME if int(view.get("win", 0)) > 0 else 0.0)


## When the last reel stops in this view's spin.
func last_stop() -> float:
	var idx: Array = view.get("idx", [0, 1, 2])
	return STOPS[2] + (TEASE if int(idx[0]) == int(idx[1]) else 0.0)


static func roll(rng: RandomNumberGenerator) -> int:
	var total := 0
	for s: Array in SYMBOLS:
		total += int(s[1])
	var r := rng.randi_range(1, total)
	for i in SYMBOLS.size():
		r -= int(SYMBOLS[i][1])
		if r <= 0:
			return i
	return 0


func _act(peer_id: int, action: StringName, _choice: int, bet: int) -> void:
	if action != &"pull" and action != &"cheat":
		return
	bet = _valid_bet(bet)
	if action == &"cheat" and _cheat(peer_id, "slots", bet) <= 0: # Brand: Snake Eyes nudge
		return
	if not _take(peer_id, bet):
		return
	var reels := [roll(_rng), roll(_rng), roll(_rng)]
	if action == &"cheat":
		reels = BrandTable.nudge_reels(reels, SYMBOLS.size(), func(r: Array) -> int: return CasinoRules.slot_payout(r))
	var won := CasinoRules.slot_prize(reels, bet)
	# Paid when the last reel lands, so the stock chips don't give the result away.
	var land := STOPS[2] + (TEASE if reels[0] == reels[1] else 0.0)
	var bonus := _part_bonus_later(peer_id, land) if not won.is_empty() else ""
	_pay_after(peer_id, won, land)
	_broadcast({"kind": "reels", "peer": peer_id, "bet": bet, "idx": reels, "seed": _rng.randi(), "win": int(won.get(&"scrap", 0)),
			"reels": [SYMBOLS[reels[0]][0], SYMBOLS[reels[1]][0], SYMBOLS[reels[2]][0]],
			"result": (("You win %s!" % CasinoRules.prize_text(won)) + bonus) if not won.is_empty() else "No luck this time."})


## Host: a turret part rolled now but paid with the rest (returns its line, or "").
func _part_bonus_later(peer_id: int, seconds: float) -> String:
	var key := CasinoRules.part_bonus(_rng)
	if key == &"":
		return ""
	_pay_after(peer_id, {key: 1}, seconds)
	return " The house throws in a %s for the Workshop!" % CraftTable.part_name(key)


func _pay_after(peer_id: int, amounts: Dictionary, seconds: float) -> void:
	if amounts.is_empty():
		return
	get_tree().create_timer(seconds, false).timeout.connect(_pay.bind(peer_id, amounts))


## Every peer: where each reel starts and how far it travels to the rolled stop.
func _on_view_change(_before: Dictionary) -> void:
	if not view.has("idx"):
		return
	var idx: Array = view["idx"]
	var seed_v := int(view.get("seed", 0))
	for i in 3:
		var strip: Array = STRIPS[i]
		var spots: Array[int] = []
		for q in strip.size():
			if int(strip[q]) == int(idx[i]):
				spots.append(q)
		var q: int = spots[(seed_v >> (i * 4)) % spots.size()] if not spots.is_empty() else 0
		spin_from[i] = float(stops[i])
		spin_dist[i] = float(strip.size() * (3 + i) + posmod(q - stops[i], strip.size()))
		stops[i] = q


func _on_view() -> void:
	_arm_t = 0.0
	Audio.play_at(&"slot_lever", global_position + Vector3.UP, -4.0)


## Strip position (fractional stop index at the payline) of reel i `t` seconds into the spin.
func reel_pos(i: int, t: float) -> float:
	var stop_t := STOPS[i] if i < 2 else last_stop()
	if not view.has("idx") or t >= stop_t + 0.6:
		return float(stops[i])
	var d := spin_dist[i]
	var ramp := 0.25
	var v := d / (stop_t - ramp * 0.5)
	if t < 0.0:
		return spin_from[i]
	if t < stop_t:
		# A little kick back as the reel lets go, then up to speed.
		var kick := -0.18 * sin(PI * clampf(t / 0.14, 0.0, 1.0)) if t < 0.14 else 0.0
		var run := v * t * t / (2.0 * ramp) if t < ramp else v * (t - ramp * 0.5)
		# The teased last reel slows over its final second.
		if i == 2 and stop_t > STOPS[2] and t > stop_t - 1.0:
			var u := t - (stop_t - 1.0) # 0..1 over the last second
			var at := v * (stop_t - 1.0 - ramp * 0.5)
			var rest := d - at
			run = at + rest * (1.0 - (1.0 - u) * (1.0 - u))
		return spin_from[i] + run + kick
	# Thunk: overshoots and settles.
	var a := t - stop_t
	return spin_from[i] + d + 0.22 * exp(-9.0 * a) * sin(a * 26.0)


func reel_speed(i: int, t: float) -> float:
	return absf(reel_pos(i, t + 0.02) - reel_pos(i, t)) / 0.02


# ------------------------------------------------------------------ the cabinet face

class SlotBoard extends CasinoBoard:
	const ROW_H := 64.0
	const REEL_W := 150.0
	var slot: SlotMachine
	var _drag := false
	var _drag_u := 0.0
	var _pulled := false

	func _init(g: CasinoGame) -> void:
		super._init(g)
		slot = g as SlotMachine
		custom_minimum_size = Vector2(0, 446)

	func _cab() -> Rect2:
		return Rect2(24, 4, 620, 436)

	func _pivot() -> Vector2:
		var cab := _cab()
		return Vector2(cab.end.x + 34, cab.position.y + 236)

	## The lever's travel: dragging, or the pull animation after a spin starts.
	func _lever_u() -> float:
		if _drag:
			return _drag_u
		return SlotMachine.lever_pull(age()) if str(game.view.get("kind", "")) == "reels" else 0.0

	func _knob() -> Vector2:
		var u := _lever_u()
		var p := _pivot()
		return p + Vector2(0, -cos(u * PI * 0.92) * 170.0)

	func _tick() -> void:
		if str(game.view.get("kind", "")) != "reels" or not game.view.has("idx"):
			return
		for i in 3:
			var stop_t: float = SlotMachine.STOPS[i] if i < 2 else slot.last_stop()
			if due("stop%d" % i, stop_t):
				sfx(&"dice", -2.0, 0.55 + i * 0.06)
				sfx(&"hammer_hit", -14.0, 1.6)
		if due("whir", 0.05):
			sfx(&"roulette_spin", -12.0, 1.7)
		var win := int(game.view.get("win", 0))
		var t0 := slot.last_stop() + 0.3
		if win > 0:
			for k in 12:
				if due("coin%d" % k, t0 + k * SlotMachine.COUNT_TIME / 12.0):
					sfx(&"coin", -8.0, 1.0 + k * 0.05)
			if due("bell", t0):
				sfx(&"bell", -10.0, 1.3)

	func _draw_game() -> void:
		var cab := _cab()
		var t := age()
		var spinning := str(game.view.get("kind", "")) == "reels" and game.view.has("idx")
		var win := int(game.view.get("win", 0)) if spinning else 0
		var settled := not spinning or t >= slot.last_stop() + 0.3
		var lit := settled and win > 0 and spinning
		# Cabinet: lacquered red body with gold trim and a rounded top.
		rrect(cab.grow(4), Color("#2A0E0A"), 30)
		rrect(cab, Color("#8E2A1F"), 28)
		rrect(cab.grow(-10), Color("#6E1D15"), 22, 3, GOLD_DARK)
		# Reel window.
		var win_r := Rect2(cab.position.x + 60, cab.position.y + 114, REEL_W * 3 + 28, ROW_H * 3)
		rrect(win_r.grow(6), Color("#2A1A0F"), 10)
		for i in 3:
			var rx := win_r.position.x + i * (REEL_W + 14)
			_reel(i, Rect2(rx, win_r.position.y, REEL_W, ROW_H * 3), t if spinning else 99.0, lit)
		# Cover what spins past the window, then its gold frame on top.
		for band: Rect2 in [Rect2(win_r.position.x - 30, win_r.position.y - 80, win_r.size.x + 60, 74), Rect2(win_r.position.x - 30, win_r.end.y + 6, win_r.size.x + 60, 74)]:
			draw_rect(band, Color("#6E1D15"))
		rrect(win_r.grow(10), Color(0, 0, 0, 0), 12, 5, Color("#C9A04A"))
		# Marquee with chasing bulbs.
		var mq := Rect2(cab.position.x + 26, cab.position.y + 18, cab.size.x - 52, 78)
		rrect(mq, WOOD_DARK, 14, 3, GOLD)
		var n_bulbs := 26
		var chase := int(Time.get_ticks_msec() / (60 if lit else 140))
		for k in n_bulbs:
			var f := float(k) / n_bulbs
			var p := _perimeter(mq.grow(-7), f)
			var on := (k + chase) % 3 == 0 if not lit else (chase % 2 == 0)
			draw_circle(p, 4.5, Color("#FFE9A0") if on else Color("#7A5A20"))
			if on:
				draw_circle(p, 8, Color(1, 0.9, 0.5, 0.18))
		text(mq.get_center() + Vector2(0, -4), "LUCKY MANDIBLE", 34, Color("#FFD23F"), 0, 6, true, Color("#3A0806"))
		text(mq.get_center() + Vector2(0, 26), "~ One-Armed Bandit ~", 13, Color("#F2E3C2"), 0, 3, true)
		# Payline across the middle row.
		var py := win_r.position.y + ROW_H * 1.5
		var flash := lit and int(t * 6.0) % 2 == 0
		var line_col := Color("#FFE14D") if flash else (Color("#E04A3A") if lit else Color(0.85, 0.15, 0.1, 0.55))
		draw_line(Vector2(win_r.position.x - 4, py), Vector2(win_r.end.x + 4, py), line_col, 4.0 if lit else 2.0, true)
		for side: float in [-1.0, 1.0]:
			var x := win_r.position.x - 18 if side < 0 else win_r.end.x + 18
			poly(PackedVector2Array([Vector2(x - 8 * side, py - 9), Vector2(x + 6 * side, py), Vector2(x - 8 * side, py + 9)]), line_col)
		# Meters: the stake and the win, in amber lamps.
		var my := win_r.end.y + 20
		_meter(Rect2(cab.position.x + 60, my, 150, 40), "BET", str(int(game.view.get("bet", game.stake())) if spinning else game.stake()))
		var shown := win
		if spinning and win > 0:
			shown = int(round(win * clampf((t - slot.last_stop() - 0.3) / SlotMachine.COUNT_TIME, 0.0, 1.0)))
		elif not settled:
			shown = 0
		_meter(Rect2(cab.end.x - 210, my, 150, 40), "WIN", str(shown), lit)
		text(Vector2(cab.get_center().x, my + 20), "PAYLINE 1", 13, GOLD, 0, 3, true)
		# The coin tray.
		var tray := Rect2(cab.position.x + 120, cab.end.y - 54, cab.size.x - 240, 38)
		poly(PackedVector2Array([tray.position, Vector2(tray.end.x, tray.position.y), Vector2(tray.end.x - 18, tray.end.y), Vector2(tray.position.x + 18, tray.end.y)]), Color("#5A6068"))
		poly(PackedVector2Array([tray.position + Vector2(8, 6), Vector2(tray.end.x - 8, tray.position.y + 6), Vector2(tray.end.x - 22, tray.end.y - 6), Vector2(tray.position.x + 22, tray.end.y - 6)]), Color("#1E2226"))
		var coins := mini(int(shown / 10.0 * 1.5), 40)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(game.view.get("seed", 1))
		for k in coins:
			var cp := Vector2(tray.get_center().x + rng.randf_range(-tray.size.x * 0.36, tray.size.x * 0.36), tray.end.y - 12 - rng.randf_range(0, 14))
			draw_set_transform(cp, rng.randf_range(-0.3, 0.3), Vector2(1, 0.55))
			draw_circle(Vector2.ZERO, 9, Color("#C9971F"))
			draw_circle(Vector2.ZERO, 6.5, Color("#F2C14E"))
			draw_set_transform_matrix(Transform2D.IDENTITY)
		_lever()
		_paytable(Rect2(_pivot().x + 50, 6, size.x - _pivot().x - 58, 432))

	func _perimeter(r: Rect2, f: float) -> Vector2:
		var per := 2.0 * (r.size.x + r.size.y)
		var d := f * per
		if d < r.size.x:
			return r.position + Vector2(d, 0)
		d -= r.size.x
		if d < r.size.y:
			return Vector2(r.end.x, r.position.y + d)
		d -= r.size.y
		if d < r.size.x:
			return Vector2(r.end.x - d, r.end.y)
		d -= r.size.x
		return Vector2(r.position.x, r.end.y - d)

	func _meter(r: Rect2, label: String, value: String, glow: bool = false) -> void:
		rrect(r, Color("#14100C"), 6, 2, GOLD_DARK)
		text(r.position + Vector2(10, 12), label, 11, GOLD, -1, 0, true)
		text(Vector2(r.end.x - 10, r.get_center().y + 5), value, 24, Color("#FFB347") if not glow else Color("#FFE14D"), 1, 0, true)

	func _reel(i: int, r: Rect2, t: float, lit: bool) -> void:
		rrect(r, CREAM, 4)
		var strip: Array = SlotMachine.STRIPS[i]
		var pos := slot.reel_pos(i, t)
		var speed := slot.reel_speed(i, t) if t < 50.0 else 0.0
		var blur := clampf((speed - 6.0) / 30.0, 0.0, 1.0)
		var cy := r.get_center().y
		var base := floori(pos)
		var idx_won: Array = game.view.get("idx", [-1, -1, -1])
		var winners := _winning_reels(idx_won) if lit else []
		for j in range(-2, 3):
			var idx := base + j
			var y := cy - (float(idx) - pos) * ROW_H
			if y < r.position.y - ROW_H * 0.5 or y > r.end.y + ROW_H * 0.5:
				continue
			var sym := int(strip[posmod(idx, strip.size())])
			var c := Vector2(r.get_center().x, y)
			if blur > 0.05:
				for k in 4:
					symbol(c + Vector2(0, (k - 1.5) * 9.0 * blur), sym, 26.0, (1.0 - blur) * 0.6 + 0.12)
			else:
				var on_line := absf(y - cy) < 2.0
				if on_line and winners.has(i):
					var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
					rrect(Rect2(r.position.x + 6, cy - ROW_H * 0.5 + 4, r.size.x - 12, ROW_H - 8), Color(1, 0.85, 0.2, 0.25 + 0.3 * pulse), 8, 3, Color("#E9A100"))
				symbol(c, sym, 27.0, 1.0)
		if blur > 0.05:
			for k in 6:
				var ly := r.position.y + fmod(pos * 37.0 + k * 41.0, r.size.y)
				draw_line(Vector2(r.position.x + 8, ly), Vector2(r.end.x - 8, ly), Color(0, 0, 0, 0.08 * blur), 2.0)
		# Curve of the drum: shaded top and bottom.
		for k in 8:
			var a := 0.32 * (1.0 - k / 8.0)
			var h := 6.0
			draw_rect(Rect2(r.position.x, r.position.y + k * h, r.size.x, h), Color(0, 0, 0, a))
			draw_rect(Rect2(r.position.x, r.end.y - (k + 1) * h, r.size.x, h), Color(0, 0, 0, a))
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y), Color(0, 0, 0, 0.6), false, 2.0)

	## Reels that make the win: all three, or the matching pair.
	func _winning_reels(idx: Array) -> Array:
		if idx.size() < 3:
			return []
		if idx[0] == idx[1] and idx[1] == idx[2]:
			return [0, 1, 2]
		for i in 3:
			var j := (i + 1) % 3
			if idx[i] == idx[j] and int(CasinoRules.SLOT_SYMBOLS[int(idx[i])][3]) > 0:
				return [i, j]
		return []

	func _lever() -> void:
		var p := _pivot()
		var u := _lever_u()
		var knob := _knob()
		# Side mount on the cabinet.
		rrect(Rect2(p.x - 34, p.y - 30, 30, 60), Color("#8C949C"), 6, 2, Color("#3A3F44"))
		draw_circle(p, 16, Color("#A9B1B9"))
		draw_circle(p, 9, Color("#5C646B"))
		# The arm comes toward you as it swings down: thicker, bigger knob.
		var near := sin(u * PI * 0.92)
		draw_line(p, knob, Color("#3A3F44"), 11.0 + near * 5.0, true)
		draw_line(p, knob, Color("#C8CED4"), 7.0 + near * 4.0, true)
		var kr := 20.0 + near * 9.0
		draw_circle(knob + Vector2(3, 4), kr, Color(0, 0, 0, 0.3))
		draw_circle(knob, kr, Color("#C9302C"))
		draw_circle(knob + Vector2(-kr * 0.35, -kr * 0.35), kr * 0.3, Color(1, 1, 1, 0.45))
		if not game.ui_busy() and u < 0.05 and not Brand.local_banned():
			var bob := sin(Time.get_ticks_msec() / 300.0) * 4.0
			text(knob + Vector2(0, -kr - 16 + bob), "PULL", 13, GOLD, 0, 4, true)

	func _paytable(r: Rect2) -> void:
		rrect(r, Color("#F2E3C2"), 8, 3, WOOD)
		text(Vector2(r.get_center().x, r.position.y + 24), "PAYS", 24, Color("#7A1E18"), 0, 0, true)
		draw_line(Vector2(r.position.x + 16, r.position.y + 44), Vector2(r.end.x - 16, r.position.y + 44), WOOD, 2.0)
		var rows := [[4, "x60", "+ Upgrade Token"], [3, "x25", ""], [2, "x15", "+ 3 Chili Seeds"], [1, "x10", ""]]
		var y := r.position.y + 72
		for row: Array in rows:
			for k in 3:
				symbol(Vector2(r.position.x + 30 + k * 34, y), int(row[0]), 14.0, 1.0)
			text(Vector2(r.end.x - 14, y - (6 if str(row[2]) != "" else 0)), str(row[1]), 22, INK, 1, 0, true)
			if str(row[2]) != "":
				text(Vector2(r.end.x - 14, y + 14), str(row[2]), 11, Color("#7A1E18"), 1)
			y += 56
		draw_line(Vector2(r.position.x + 16, y - 26), Vector2(r.end.x - 16, y - 26), Color(WOOD, 0.5), 1.0)
		text(Vector2(r.get_center().x, y - 8), "Any Pair Side by Side", 13, INK, 0)
		for row: Array in [[3, 4, "x2"], [1, 2, "x1"]]:
			y += 30
			for k in 2:
				symbol(Vector2(r.position.x + 26 + k * 26, y), int(row[0]), 11.0, 1.0)
				symbol(Vector2(r.position.x + 106 + k * 26, y), int(row[1]), 11.0, 1.0)
			text(Vector2(r.position.x + 79, y), "or", 12, Color("#6B5034"))
			text(Vector2(r.end.x - 14, y), str(row[2]), 20, INK, 1, 0, true)
		y -= 30
		symbol(Vector2(r.position.x + 30, y + 64), 0, 12.0, 1.0)
		text(Vector2(r.position.x + 50, y + 64), "Bugs Pay Nothing", 12, Color("#6B5034"), -1)

	## A reel symbol centred on c, about `s` across in each direction.
	func symbol(c: Vector2, sym: int, s: float, alpha: float) -> void:
		var a := alpha
		match sym:
			0: # a dung beetle
				var shell := Color(0.32, 0.2, 0.12, a)
				var leg := Color(0.12, 0.08, 0.05, a)
				for side: float in [-1.0, 1.0]:
					for k in 3:
						var hip := c + Vector2(side * s * 0.3, (k - 1) * s * 0.3)
						draw_line(hip, hip + Vector2(side * s * 0.45, (k - 1) * s * 0.35 - s * 0.05), leg, maxf(1.5, s * 0.08), true)
				draw_circle(c + Vector2(0, -s * 0.55), s * 0.22, leg)
				draw_set_transform(c + Vector2(0, s * 0.08), 0.0, Vector2(0.78, 1.0))
				draw_circle(Vector2.ZERO, s * 0.55, shell)
				draw_set_transform_matrix(Transform2D.IDENTITY)
				draw_line(c + Vector2(0, -s * 0.38), c + Vector2(0, s * 0.62), Color(0, 0, 0, 0.5 * a), maxf(1.0, s * 0.05))
				draw_circle(c + Vector2(-s * 0.18, -s * 0.12), s * 0.09, Color(1, 1, 1, 0.35 * a))
			1: # a saguaro
				var g := Color(0.24, 0.55, 0.24, a)
				var gd := Color(0.14, 0.38, 0.16, a)
				rrect(Rect2(c.x - s * 0.17, c.y - s * 0.85, s * 0.34, s * 1.6), g, s * 0.17)
				rrect(Rect2(c.x - s * 0.62, c.y - s * 0.35, s * 0.24, s * 0.62), g, s * 0.12)
				rrect(Rect2(c.x - s * 0.62, c.y + s * 0.08, s * 0.5, s * 0.2), g, s * 0.1)
				rrect(Rect2(c.x + s * 0.38, c.y - s * 0.6, s * 0.24, s * 0.6), g, s * 0.12)
				rrect(Rect2(c.x + s * 0.12, c.y - s * 0.18, s * 0.5, s * 0.2), g, s * 0.1)
				draw_line(c + Vector2(0, -s * 0.7), c + Vector2(0, s * 0.7), gd, maxf(1.0, s * 0.05))
				rrect(Rect2(c.x - s * 0.5, c.y + s * 0.72, s, s * 0.14), Color(0.8, 0.62, 0.35, a), s * 0.07)
			2: # a chili
				var pts := PackedVector2Array()
				for k in 13:
					var f := float(k) / 12.0
					var ang := lerpf(-0.9, 1.3, f)
					pts.append(c + Vector2(cos(ang) * s * 0.7 - s * 0.2, sin(ang) * s * 0.7 - s * 0.1))
				for k in range(12, -1, -1):
					var f := float(k) / 12.0
					var ang := lerpf(-0.9, 1.3, f)
					var rr := s * (0.7 - 0.38 * (1.0 - absf(f - 0.35) * 1.4))
					pts.append(c + Vector2(cos(ang) * rr - s * 0.2, sin(ang) * rr - s * 0.1))
				poly(pts, Color(0.8, 0.12, 0.08, a))
				draw_line(c + Vector2(s * 0.2, -s * 0.62), c + Vector2(s * 0.05, -s * 0.85), Color(0.2, 0.5, 0.15, a), maxf(2.0, s * 0.14), true)
				draw_circle(c + Vector2(s * 0.3, -s * 0.5), s * 0.13, Color(0.2, 0.5, 0.15, a))
				draw_circle(c + Vector2(s * 0.42, -s * 0.15), s * 0.08, Color(1, 1, 1, 0.4 * a))
			3: # a horseshoe, opening up for luck
				draw_arc(c + Vector2(0, s * 0.1), s * 0.58, -PI * 0.5 + 0.55, PI * 1.5 - 0.55, 24, Color(0.45, 0.47, 0.5, a), s * 0.3, true)
				draw_arc(c + Vector2(0, s * 0.1), s * 0.58, -PI * 0.5 + 0.55, PI * 1.5 - 0.55, 24, Color(0.72, 0.74, 0.78, a), s * 0.16, true)
				for k in 6:
					var ang := lerpf(-PI * 0.5 + 0.8, PI * 1.5 - 0.8, k / 5.0)
					draw_circle(c + Vector2(0, s * 0.1) + Vector2(cos(ang), sin(ang)) * s * 0.58, s * 0.05, Color(0.15, 0.15, 0.15, a))
			_: # the sheriff's star
				var gold := Color(0.95, 0.75, 0.2, a)
				poly(star_points(c, s * 0.9, s * 0.45, 6), Color(0.6, 0.42, 0.08, a))
				poly(star_points(c, s * 0.8, s * 0.4, 6), gold)
				for k in 6:
					var ang := PI * k / 3.0 - PI * 0.5
					draw_circle(c + Vector2(cos(ang), sin(ang)) * s * 0.84, s * 0.1, gold)
				draw_circle(c, s * 0.3, Color(0.75, 0.55, 0.1, a))
				poly(star_points(c, s * 0.24, s * 0.1, 5), Color(0.98, 0.9, 0.55, a))

	# ---- dragging the lever

	func _click(p: Vector2, right: bool) -> bool:
		if right or game.ui_busy() or Brand.local_banned():
			return false
		var knob := _knob()
		var arm := Geometry2D.get_closest_point_to_segment(p, _pivot(), knob)
		if p.distance_to(knob) < 36.0 or p.distance_to(arm) < 16.0:
			_drag = true
			_drag_u = 0.0
			_pulled = false
			return true
		return false

	func _hover(p: Vector2) -> void:
		if not _drag:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if p.distance_to(_knob()) < 36.0 else Control.CURSOR_ARROW
			return
		var top := _pivot().y - 170.0
		_drag_u = clampf((p.y - top) / 300.0, 0.0, 1.0)
		if _drag_u > 0.8 and not _pulled:
			_pull()

	func _release(_p: Vector2) -> void:
		if not _drag:
			return
		_drag = false
		if not _pulled and not game.ui_busy():
			_pull() # a plain click pulls it all the way

	func _pull() -> void:
		_pulled = true
		_drag = false
		sfx(&"slot_lever", -2.0)
		game.ui_press(&"pull")
